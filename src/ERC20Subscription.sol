// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20Subscription} from "./interfaces/IERC20Subscription.sol";
import {ISignatureTransfer} from "./interfaces/ISignatureTransfer.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {SignatureVerification} from "./libraries/SignatureVerification.sol";
import {PermitHash} from "./libraries/PermitHash.sol";
import {EIP712} from "./EIP712.sol";
import {FeeManager} from "./FeeManager.sol";

contract ERC20Subscription is IERC20Subscription, EIP712, FeeManager {
    using SignatureVerification for bytes;
    using SafeTransferLib for ERC20;
    using PermitHash for PermitTransferFrom;

    // returns the last block timestamp the signature was used
    mapping(bytes => uint256) private sigToLastPaymentTimestamp;

    // returns true if the signature is blocked by user (user has unsibscribed)
    mapping(bytes => bool) private sigToIsBlocked;

    constructor(address _feeRecipient, uint16 _feeBasisPoints) FeeManager(_feeRecipient, _feeBasisPoints) {}

    // same as unsubcribing, but can be done before subscription is initialized (before first payment)
    // checks if the signature is valid meaning that the signature came from the owner of the subscription
    /// @inheritdoc IERC20Subscription
    function blockSubscription(Subscription calldata _subscription) external override {
        if (_subscription.owner != msg.sender) revert NotOwnerOfSubscription();
        _subscription.signature.verify(_hashTypedData(_subscription.permit.hash()), _subscription.owner);
        sigToIsBlocked[_subscription.signature] = true;
    }

    /// @inheritdoc IERC20Subscription
    function collectPayment(Subscription calldata _subscription) external override {
        // if subscription has been blocked by user, revert
        if (sigToIsBlocked[_subscription.signature]) revert SubscriptionBlocked();

        uint256 timeOfLastPayment = sigToLastPaymentTimestamp[_subscription.signature];

        if (timeOfLastPayment == 0) {
            // first payment
            _permitTransferFrom(
                _subscription.permit, _subscription.owner, _subscription.permit.hash(), _subscription.signature
            );
            // new latest payment timestamp is set if _permitTransferFrom didnt revert
            sigToLastPaymentTimestamp[_subscription.signature] = block.timestamp;
        } else {
            // not enough time has past since last payment
            if (
                block.timestamp < sigToLastPaymentTimestamp[_subscription.signature] + _subscription.permit.cooldownTime
            ) {
                revert NotEnoughTimePast();
            }

            _permitTransferFrom(
                _subscription.permit, _subscription.owner, _subscription.permit.hash(), _subscription.signature
            );
            // new latest payment timestamp is set if _permitTransferFrom didnt revert
            sigToLastPaymentTimestamp[_subscription.signature] = block.timestamp;
        }

        emit SuccessfulPayment(
            _subscription.owner,
            _subscription.permit.permitted.to,
            _subscription.permit.permitted.amount,
            _subscription.permit.permitted.token
        );
    }

    /// @notice Transfers a token using a signed permit message.
    /// @param permit The permit data signed over by the owner
    /// @param dataHash The EIP-712 hash of permit data to include when checking signature
    /// @param owner The owner of the tokens to transfer
    /// @param signature The signature to verify
    function _permitTransferFrom(
        PermitTransferFrom memory permit,
        address owner,
        bytes32 dataHash,
        bytes calldata signature
    ) private {
        signature.verify(_hashTypedData(dataHash), owner);

        // take fee
        (uint256 fee, uint256 remainingAmount) = calculateFee(permit.permitted.amount);
        ERC20(permit.permitted.token).safeTransferFrom(owner, feeRecipient, fee);

        // transfer remaining amount
        ERC20(permit.permitted.token).safeTransferFrom(owner, permit.permitted.to, remainingAmount);
    }
}
