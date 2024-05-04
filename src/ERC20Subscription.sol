// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20Subscription} from "./interfaces/IERC20Subscription.sol";
import {ISignatureTransfer} from "./interfaces/ISignatureTransfer.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {SignatureVerification} from "./libraries/SignatureVerification.sol";
import {PermitHash} from "./libraries/PermitHash.sol";
import {EIP712} from "./EIP712.sol";

contract ERC20Subscription is IERC20Subscription, EIP712 {
    using SignatureVerification for bytes;
    using SafeTransferLib for ERC20;
    using PermitHash for PermitTransferFrom;

    // returns the last block timestamp the signature was used
    mapping(bytes => uint256) private sigToLastPaymentTimestamp;

    // returns true if the signature is blocked by user (user has unsibscribed)
    mapping(address => mapping(bytes => bool)) private sigToIsBlocked;

    // same as unsubcribing, but can be done before subscription is initialized (before first payment)
    /// @inheritdoc IERC20Subscription
    function blockSubscription(bytes calldata _signature) external override {
        sigToIsBlocked[msg.sender][_signature] = true;
    }

    /// @inheritdoc IERC20Subscription
    function collectPayment(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external override {
        // if subscription has been blocked by user, revert
        if (sigToIsBlocked[owner][signature]) revert SubscriptionBlocked();

        uint256 timeOfLastPayment = sigToLastPaymentTimestamp[signature];

        if (timeOfLastPayment == 0) {
            // first payment
            _permitTransferFrom(permit, transferDetails, owner, permit.hash(), signature);
            // new latest payment timestamp is set if _permitTransferFrom didnt revert
            sigToLastPaymentTimestamp[signature] = block.timestamp;
        } else {
            // not enough time has past since last payment
            if (block.timestamp < sigToLastPaymentTimestamp[signature] + permit.timeInterval) {
                revert NotEnoughTimePast();
            }

            _permitTransferFrom(permit, transferDetails, owner, permit.hash(), signature);
            // new latest payment timestamp is set if _permitTransferFrom didnt revert
            sigToLastPaymentTimestamp[signature] = block.timestamp;
        }

        emit SuccessfulPayment(owner, transferDetails.to, transferDetails.requestedAmount, permit.permitted.token);
    }

    /// @notice Transfers a token using a signed permit message.
    /// @param permit The permit data signed over by the owner
    /// @param dataHash The EIP-712 hash of permit data to include when checking signature
    /// @param owner The owner of the tokens to transfer
    /// @param transferDetails The spender's requested transfer details for the permitted token
    /// @param signature The signature to verify
    function _permitTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes32 dataHash,
        bytes calldata signature
    ) private {
        uint256 requestedAmount = transferDetails.requestedAmount;

        if (requestedAmount > permit.permitted.amount) revert InvalidAmount(permit.permitted.amount);

        signature.verify(_hashTypedData(dataHash), owner);

        ERC20(permit.permitted.token).safeTransferFrom(owner, transferDetails.to, requestedAmount);
    }
}
