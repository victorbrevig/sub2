// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEIP712} from "./IEIP712.sol";

interface IERC20Subscription is IEIP712 {
    function blockSubscription(Subscription calldata subscription) external;

    event SuccessfulPayment(address from, address to, uint256 amount, address token);

    /// @notice Thrown when the requested amount for a transfer is larger than the permissioned amount
    /// @param maxAmount The maximum amount a spender can request to transfer
    error InvalidAmount(uint256 maxAmount);

    /// @notice Thrown when when the subscription (given by the signature) has been blocked by the user
    error SubscriptionBlocked();

    /// @notice Thrown when when there has not been enough time past since the last payment
    error NotEnoughTimePast();

    /// @notice The token and amount details for a transfer signed in the permit transfer signature
    struct TokenPermissions {
        // ERC20 token address
        address token;
        // the maximum amount that can be spent
        uint256 amount;
        // receiver
        address to;
    }

    /// @notice The signed permit message for a single token transfer
    struct PermitTransferFrom {
        TokenPermissions permitted;
        // salt to create unique subscriptions with same specification
        uint256 salt;
        // time interval inbetween subscribtions
        uint256 cooldownTime;
    }

    struct Subscription {
        PermitTransferFrom permit;
        address owner;
        bytes signature;
    }

    function collectPayment(Subscription calldata _subscription) external;
}
