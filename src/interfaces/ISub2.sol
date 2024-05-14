// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISub2 {
    function createSubscription(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint16 _executerFeeBasisPoints
    ) external;
    function createSubscriptionWithoutFirstPayment(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint16 _executorFeeBasisPoints
    ) external;
    function cancelSubscription(uint256 _subscriptionIndex) external;
    function redeemPayment(uint256 _subscriptionIndex, address _feeRecipient) external;
    function updateExecutorFee(uint256 _subscriptionIndex, uint16 _executorFeeBasisPoints) external;
    function getSubscriptionsSender(address _sender) external view returns (IndexedSubscription[] memory);
    function getSubscriptionsRecipient(address _recipient) external view returns (IndexedSubscription[] memory);
    function getNumberOfSubscriptions() external view returns (uint256);

    event SuccessfulPayment(address indexed from, address indexed to, uint256 amount, address token, uint256 totalFee);
    event SubscriptionCreated(Subscription subscription);
    event SubscriptionCanceled(Subscription subscription);

    /// @notice Thrown when there has not been enough time past since the last payment
    error NotEnoughTimePast();

    /// @notice Thrown when the caller is not the owner of the subscription
    error NotOwnerOfSubscription();

    /// @notice Thrown when the authSignature is not valid
    error InvalidAuthSignature();

    /// @notice Thrown when tried to look up a subscription that does not exist
    error SubscriptionDoesNotExist();

    error SubscriptionIsCanceled();

    error InvalidFeeBasisPoints();

    error NotSenderOrRecipient();

    struct Subscription {
        address sender;
        address recipient;
        uint256 amount;
        address token;
        uint256 cooldown;
        uint256 lastPayment;
        uint16 executorFeeBasisPoints;
    }

    struct IndexedSubscription {
        uint256 index;
        Subscription subscription;
    }
}
