// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISub2 {
    /// @dev Requires that the msg.sender has approved the contract for the amount of tokens.
    /// @dev If _index is smaller than the length of Subscriptions, the function will update the subscription at that index if it has been canceled. Otherwise it will revert. This will revert if there is already a subscription at the index. type(uint256).max can be used to always ensure a new subscription slot is created.
    /// @param _recipient Recipient of the subscription.
    /// @param _amount Amount of tokens that the recipient will receive.
    /// @param _token Address of ERC20 token that will be used for the subscription.
    /// @param _cooldown Amount of time in seconds that must pass between payments.
    /// @param _maxProcessingFee The maximum amount of _processingFeeToken that can be sent as a fee to a processor.
    /// @param _processingFeeToken Address of ERC20 token that will be used for processing fee.
    /// @param _auctionDuration The duration of the auction period in seconds.
    /// @param _delay Amount of time in seconds that must pass before the first payment.
    /// @param _initialTerms The number of terms to pay initially.
    /// @param _index The index of the subscription created in Subscriptions.
    /// @return subscriptionIndex The index of the subscription created in Subscriptions.
    function createSubscription(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint256 _maxProcessingFee,
        address _processingFeeToken,
        uint256 _auctionDuration,
        uint256 _delay,
        uint256 _initialTerms,
        uint256 _index
    ) external returns (uint256 subscriptionIndex);

    /// @dev Requires that the msg.sender has approved the contract for the amount of tokens.
    /// @dev If _index is smaller than the length of Subscriptions, the function will update the subscription at that index if it has been canceled. Otherwise it will revert. This will revert if there is already a subscription at the index. type(uint256).max can be used to always ensure a new subscription slot is created.
    /// @param _permit The permit that will be used to create the subscription.
    /// @param _sponsor The address of the sponsor.
    /// @param _signature The EIP-712 signature of the permit signed by the sponsor.
    /// @param _index The index of the subscription created in Subscriptions.
    /// @return subscriptionIndex The index of the subscription created in Subscriptions.
    function createSubscriptionWithSponsor(
        SponsorPermit calldata _permit,
        address _sponsor,
        bytes calldata _signature,
        uint256 _index
    ) external returns (uint256 subscriptionIndex);

    /// @notice Can only be called by either the sender or the recipient.
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
    /// @return processingFee The the total amount of tokens claimed by the processor.
    /// @return processingFeeToken The address of the processing fee token.
    function processPayment(uint256 _subscriptionIndex, address _feeRecipient)
        external
        returns (uint256 processingFee, address processingFeeToken);

    /// @notice Can only be called by the sponsor of the subscription.
    /// @param _subscriptionIndex The index in the Subscriptions array of the subscription to update.
    /// @param _maxProcessingFee The new maximum fee to be claimed by a processor.
    /// @param _processingFeeToken The new token to be used for the tip.
    function updateMaxProcessingFee(uint256 _subscriptionIndex, uint256 _maxProcessingFee, address _processingFeeToken)
        external;

    /// @return numberOfSubscriptions The length of Subscriptions array.
    function getNumberOfSubscriptions() external view returns (uint256 numberOfSubscriptions);

    event Payment(
        address indexed sender,
        address indexed recipient,
        uint256 indexed subscriptionIndex,
        address sponsor,
        uint256 amount,
        address token,
        uint256 protocolFee,
        uint256 processingFee,
        address processingFeeToken,
        uint256 terms
    );
    event SubscriptionCreated(uint256 indexed subscriptionIndex, address indexed recipient);
    event SubscriptionCanceled(uint256 indexed subscriptionIndex, address indexed recipient);
    event MaxProcessingFeeUpdated(uint256 subscriptionIndex, uint256 maxProcessingFee, address processingFeeToken);
    event AuctionDurationUpdated(uint256 subscriptionIndex, uint256 auctionDuration);
    event SponsorshipRevoked(uint256 indexed subscriptionIndex, address indexed sender);

    /// @notice Thrown when there has not been enough time past since the last payment
    error NotEnoughTimePast();

    /// @notice Thrown when the caller is not the sponsor of the subscription
    error NotSponsorOfSubscription();

    /// @notice Thrown when the authSignature is not valid
    error InvalidAuthSignature();

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

    /// @notice Thrown when maximum processing fee is exceeded
    error ExceedingMaxProcessingFee();

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
        uint256 maxProcessingFee;
        address processingFeeToken;
        uint256 auctionDuration;
    }

    struct IndexedSubscription {
        uint256 index;
        Subscription subscription;
    }

    struct SponsorPermit {
        uint256 nonce;
        uint256 deadline;
        address recipient;
        uint256 amount;
        address token;
        uint256 cooldown;
        uint256 delay;
        uint256 initialTerms;
        uint256 maxProcessingFee;
        address processingFeeToken;
        uint256 auctionDuration;
    }
}
