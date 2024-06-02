// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISub2 {
    /// @dev Requires that the msg.sender has approved the contract for the amount of tokens.
    /// @dev If _index is smaller than the length of Subscriptions, the function will update the subscription at that index if it has been canceled. Otherwise it will revert. This can cause unexpected reverts if the same index is used at the same time. type(uint256).max can be used to always ensure a new subscription slot is created.
    /// @param _recipient Recipient of the subscription.
    /// @param _amount Amount of tokens that the recipient will receive.
    /// @param _token Address of ERC20 token that will be used for the subscription.
    /// @param _cooldown Amount of time in seconds that must pass between payments.
    /// @param _maxTip The maximum amount of _timToken that can be sent as a tip to an executor.
    /// @param _tipToken Address of ERC20 token that will be used for the tip.
    /// @param _auctionDuration The duration of the auction period in seconds.
    /// @param _delay Amount of time in seconds that must pass before the first payment.
    /// @param _terms The number of terms to pay initially.
    /// @param _index The index of the subscription created in Subscriptions.
    /// @return subscriptionIndex The index of the subscription created in Subscriptions.
    function createSubscription(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint256 _maxTip,
        address _tipToken,
        uint256 _auctionDuration,
        uint256 _delay,
        uint256 _terms,
        uint256 _index
    ) external returns (uint256 subscriptionIndex);

    function createSubscriptionWithSponsor(
        SponsorPermit calldata _permit,
        address _sponsor,
        bytes calldata _signature,
        uint256 _index
    ) external returns (uint256 subscriptionIndex);

    /// @notice Can be called by both the sender and the recipient.
    /// @param _subscriptionIndex The index in the Subscriptions array of the subscription to cancel.
    function cancelSubscription(uint256 _subscriptionIndex) external;

    /// @notice Can be called by anyone once cooldown + auctionDuration has passed since the last payment.
    /// @param _subscriptionIndex The index in the Subscriptions array of the subscription to cancel.
    function cancelExpiredSubscription(uint256 _subscriptionIndex) external;

    /// @notice Can only be called by sponsor of the subscription.
    /// @param _subscriptionIndex The index in the Subscriptions array of the subscription to cancel.
    function revokeSponsorship(uint256 _subscriptionIndex) external;

    /// @param _subscriptionIndex The index in the Subscriptions array of the subscription to redeem.
    /// @param _feeRecipient The address that will receive the executor fee.
    /// @return executorTip The the total amount of tokens claimed by the executor.
    /// @return tipToken The address of the tip of the subscription that was redeemed.
    function redeemPayment(uint256 _subscriptionIndex, address _feeRecipient)
        external
        returns (uint256 executorTip, address tipToken);

    /// @notice Can only be called by the owner of the subscription.
    /// @param _subscriptionIndex The index in the Subscriptions array of the subscription to update.
    /// @param _maxTip The new maximum tip of tokens to be claimed by an executor.
    /// @param _tipToken The new token to be used for the tip.
    function updateMaxTip(uint256 _subscriptionIndex, uint256 _maxTip, address _tipToken) external;

    /// @notice Can only be called by the recipient of the subscription.
    /// @param _subscriptionIndex The index in the Subscriptions array of the subscription to update.
    /// @param _auctionDuration The new auction duration of the subscription.
    function updateAuctionDuration(uint256 _subscriptionIndex, uint256 _auctionDuration) external;

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
        uint256 protocolFee,
        uint256 executorTip,
        address tipToken,
        uint256 terms
    );
    event SubscriptionCreated(uint256 indexed subscriptionIndex, address indexed recipient);
    event SubscriptionCanceled(uint256 indexed subscriptionIndex, address indexed recipient);
    event MaxTipUpdated(uint256 subscriptionIndex, uint256 maxTip, address tipToken);
    event AuctionDurationUpdated(uint256 subscriptionIndex, uint256 auctionDuration);
    event SponsorshipRevoked(uint256 indexed subscriptionIndex, address indexed sender);

    /// @notice Thrown when there has not been enough time past since the last payment
    error NotEnoughTimePast();

    /// @notice Thrown when the caller is not the owner of the subscription
    error NotOwnerOfSubscription();

    /// @notice Thrown when the caller is not the sponsor of the subscription
    error NotSponsorOfSubscription();

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

    /// @notice Thrown when a subscription aldready exists at index
    error SubscriptionAlreadyExists();

    /// @notice Thrown when auction time is less than cooldown
    error AuctionDurationGreaterThanCooldown();

    /// @notice Thrown auction time has passed
    error AuctionExpired();

    /// @notice Emits an event when the owner successfully invalidates an unordered nonce.
    event UnorderedNonceInvalidation(address indexed owner, uint256 word, uint256 mask);

    struct Subscription {
        address sender;
        address recipient;
        address sponsor;
        uint256 amount;
        address token;
        uint256 cooldown;
        uint256 lastPayment;
        uint256 maxTip;
        address tipToken;
        uint256 auctionDuration;
    }

    struct IndexedSubscription {
        uint256 index;
        Subscription subscription;
    }

    struct SponsorPermit {
        // a unique value for every token owner's signature to prevent signature replays
        uint256 nonce;
        // deadline on the permit signature
        uint256 deadline;
        // Subscription specification
        address recipient;
        uint256 amount;
        address token;
        uint256 cooldown;
        uint256 delay;
        uint256 terms;
        uint256 maxTip;
        address tipToken;
        uint256 auctionDuration;
    }
}
