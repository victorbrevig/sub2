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
    function redeemPayment(uint256 _subscriptionIndex, address _feeRecipient)
        external
        returns (uint256, uint256, uint16, address);
    function updateMaxExecutorFeeSender(uint256 _subscriptionIndex, uint16 _maxExecutorFeeBasisPoints) external;
    function updateMaxExecutorFeeRecipient(uint256 _subscriptionIndex, uint16 _maxExecutorFeeBasisPoints) external;
    function getSubscriptionsSender(address _sender) external view returns (IndexedSubscription[] memory);
    function getSubscriptionsRecipient(address _recipient) external view returns (IndexedSubscription[] memory);
    function getNumberOfSubscriptions() external view returns (uint256);
    function prePay(uint256 _subscriptionIndex, uint256 _terms) external;

    event SuccessfulPayment(
        address indexed from,
        address indexed to,
        uint256 indexed subscriptionIndex,
        uint256 amount,
        address token,
        uint256 totalFee,
        uint256 terms
    );
    event SubscriptionCreated(uint256 subscriptionIndex);
    event SubscriptionCanceled(uint256 subscriptionIndex);
    event ExecutorFeeUpdated(uint256 subscriptionIndex, uint16 newBasisPoints);

    /// @notice Thrown when there has not been enough time past since the last payment
    error NotEnoughTimePast();

    /// @notice Thrown when the caller is not the owner of the subscription
    error NotOwnerOfSubscription();

    /// @notice Thrown when the caller is not the recipient of the subscription
    error NotRecipientOfSubscription();

    /// @notice Thrown when the authSignature is not valid
    error InvalidAuthSignature();

    /// @notice Thrown when tried to look up a subscription that does not exist
    error SubscriptionDoesNotExist();

    error SubscriptionIsCanceled();

    error InvalidFeeBasisPoints();

    error NotSenderOrRecipient();

    error InFeeAuctionPeriod();

    struct Subscription {
        address sender;
        address recipient;
        uint256 amount;
        address token;
        uint256 cooldown;
        uint256 lastPayment;
        uint16 maxExecutorFeeBasisPoints;
    }

    struct IndexedSubscription {
        uint256 index;
        Subscription subscription;
    }
}
