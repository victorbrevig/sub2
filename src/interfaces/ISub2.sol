// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISub2 {
    /// @dev Requires that the msg.sender has approved the contract for the amount of tokens.
    /// @param _recipient Recipient of the subscription.
    /// @param _amount Amount of tokens that the recipient will receive.
    /// @param _token Address of ERC20 token that will be used for the subscription.
    /// @param _cooldown Amount of time in seconds that must pass between payments.
    /// @param _maxExecutorFeeBasisPoints The maximum fee in basis points (e.g. 3000 = 0.3%) that an executor can charge.
    /// @return subscriptionIndex The index of the subscription created in Subscriptions.
    function createSubscription(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint16 _maxExecutorFeeBasisPoints
    ) external returns (uint256 subscriptionIndex);

    /// @param _recipient Recipient of the subscription
    /// @param _amount Amount of tokens that the recipient will receive
    /// @param _token Address of ERC20 token that will be used for the subscription
    /// @param _cooldown Amount of time in seconds that must pass between payments
    /// @param _maxExecutorFeeBasisPoints The maximum fee in basis points (e.g. 3000 = 0.3%) that an executor can charge
    /// @param _delay Amount of time in seconds that must pass before the first payment
    /// @return subscriptionIndex The index of the subscription created in Subscriptions
    function createSubscriptionWithDelay(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint16 _maxExecutorFeeBasisPoints,
        uint256 _delay
    ) external returns (uint256 subscriptionIndex);

    /// @notice Can be called by both the sender and the recipient.
    /// @param _subscriptionIndex The index in the Subscriptions array of the subscription to cancel.
    function cancelSubscription(uint256 _subscriptionIndex) external;

    /// @param _subscriptionIndex The index in the Subscriptions array of the subscription to redeem.
    /// @param _feeRecipient The address that will receive the executor fee.
    /// @return executorFee The the total amount of tokens claimed by the executor.
    /// @return token The address of the token that was redeemed.
    function redeemPayment(uint256 _subscriptionIndex, address _feeRecipient)
        external
        returns (uint256 executorFee, address token);

    /// @notice Can only be called by the owner of the subscription.
    /// @param _subscriptionIndex The index in the Subscriptions array of the subscription to update.
    /// @param _maxExecutorFeeBasisPoints The new maximum fee in basis points (e.g. 3000 = 0.3%) that an executor can charge.
    function updateMaxExecutorFee(uint256 _subscriptionIndex, uint16 _maxExecutorFeeBasisPoints) external;

    function getSubscriptionsSender(address _sender) external view returns (IndexedSubscription[] memory);
    function getSubscriptionsRecipient(address _recipient) external view returns (IndexedSubscription[] memory);
    function getNumberOfSubscriptions() external view returns (uint256);

    /// @notice Can only be called by the owner of the subscription.
    /// @param _subscriptionIndex The index in the Subscriptions array of the subscription to prepay.
    /// @param _terms The number of terms to prepay.
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

    /// @notice Thrown when trying to look up a subscription that does not exist
    error SubscriptionDoesNotExist();

    /// @notice Thrown when trying to look interact with a subscription that has been canceled
    error SubscriptionIsCanceled();

    /// @notice Thrown when the fee basis points are invalid
    error InvalidFeeBasisPoints();

    /// @notice Thrown when the caller is not the sender or recipient of the subscription
    error NotSenderOrRecipient();

    /// @notice Thrown when the subscription is in auction period
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
