// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20Subscription2 {
    function createSubscription(address _recipient, uint256 _amount, address _token, uint256 _cooldown) external;
    function cancelSubscription(uint16 _subscriptionId) external;
    function redeemPayment(address _from, uint16 _subscriptionId, address _feeRecipient) external;
    function getSubscriptions(address _user) external view returns (Subscription[] memory);

    event SuccessfulPayment(address from, address to, uint256 amount, address token);

    /// @notice Thrown when there has not been enough time past since the last payment
    error NotEnoughTimePast();

    /// @notice Thrown when the caller is not the owner of the subscription
    error NotOwnerOfSubscription();

    /// @notice Thrown when the authSignature is not valid
    error InvalidAuthSignature();

    /// @notice Thrown when tried to look up a subscription that does not exist
    error SubscriptionDoesNotExist();

    error SubscriptionCanceled();

    event SuccessfulPayment(
        address from, address to, uint16 nonce, uint256 amount, address token, uint256 totalFeePaid
    );

    struct Subscription {
        address recipient;
        uint256 amount;
        address token;
        uint256 cooldown;
        uint256 lastPayment;
    }
}
