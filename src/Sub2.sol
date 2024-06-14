// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISub2} from "./interfaces/ISub2.sol";
import {FeeManager} from "./FeeManager.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solmate/src/utils/ReentrancyGuard.sol";
import {EIP712} from "./EIP712.sol";
import {SignatureVerification} from "./libraries/SignatureVerification.sol";
import {SponsorPermitHash} from "./libraries/SponsorPermitHash.sol";
import {
    SignatureExpired,
    InvalidNonce,
    InvalidRecipient,
    InvalidAmount,
    InvalidToken,
    InvalidTipToken,
    InvalidCooldown,
    InvalidDelay,
    InvalidTerms,
    InvalidMaxTip,
    InvalidAuctionDuration
} from "./PermitErrors.sol";

contract Sub2 is ISub2, EIP712, FeeManager, ReentrancyGuard {
    using SignatureVerification for bytes;
    using SafeTransferLib for ERC20;
    using SponsorPermitHash for SponsorPermit;

    Subscription[] public subscriptions;

    //mapping(address => mapping(uint16 => Subscription)) public subscriptions;
    mapping(address => mapping(uint16 => uint256)) public userToSubscriptionIndex;
    mapping(address => uint16) public userSubscriptionNonce;

    mapping(address => mapping(uint32 => uint256)) public recipientToSubscriptionIndex;
    mapping(address => uint32) public recipientSubscriptionNonce;

    mapping(bytes32 => mapping(uint32 => uint256)) public subscriptionHashToSubscriptionIndex;
    mapping(bytes32 => uint32) public subscriptionHashToNonce;

    mapping(address => mapping(uint256 => uint256)) public nonceBitmap;

    constructor(address _treasury, uint16 _treasuryBasisPoints, address _owner)
        FeeManager(_owner, _treasury, _treasuryBasisPoints)
    {}

    function createSubscription(
        address _recipient,
        uint256 _amount,
        address _token,
        uint32 _cooldown,
        uint256 _maxProcessingFee,
        address _processingFeeToken,
        uint32 _auctionDuration,
        uint32 _delay,
        uint16 _initialPayments,
        uint256 _index
    ) public override returns (uint256 subscriptionIndex) {
        subscriptionIndex = _createCreateSubscription(
            _recipient,
            _amount,
            _token,
            _cooldown,
            _maxProcessingFee,
            _processingFeeToken,
            _delay,
            _initialPayments,
            _auctionDuration,
            msg.sender,
            _index
        );
        return subscriptionIndex;
    }

    function createSubscriptionWithSponsor(
        SponsorPermit calldata _permit,
        address _sponsor,
        bytes calldata _signature,
        uint256 _index
    ) public override returns (uint256 subscriptionIndex) {
        if (block.timestamp > _permit.deadline) revert SignatureExpired(_permit.deadline);

        _useUnorderedNonce(_sponsor, _permit.nonce);

        bytes32 dataHash = _permit.hash();
        _signature.verify(_hashTypedData(dataHash), _sponsor);

        subscriptionIndex = _createCreateSubscription(
            _permit.recipient,
            _permit.amount,
            _permit.token,
            _permit.cooldown,
            _permit.maxProcessingFee,
            _permit.processingFeeToken,
            _permit.delay,
            _permit.initialPayments,
            _permit.auctionDuration,
            _sponsor,
            _index
        );
        return subscriptionIndex;
    }

    function _createCreateSubscription(
        address _recipient,
        uint256 _amount,
        address _token,
        uint32 _cooldown,
        uint256 _maxProcessingFee,
        address _processingFeeToken,
        uint32 _delay,
        uint16 _initialPayments,
        uint32 _auctionDuration,
        address _sponsor,
        uint256 _index
    ) private returns (uint256 subscriptionIndex) {
        if (_delay == 0) {
            subscriptionIndex = _createSubscription(
                _recipient,
                _amount,
                _token,
                _cooldown,
                _maxProcessingFee,
                _processingFeeToken,
                _cooldown * _initialPayments,
                _auctionDuration,
                _sponsor,
                _initialPayments,
                _index
            );
            // initial payment
            uint256 totalAmount = _amount * _initialPayments;
            uint256 protocolFee = calculateFee(totalAmount, treasuryFeeBasisPoints);

            uint256 remainingAmount = totalAmount - protocolFee;

            // transfer protocol fee
            ERC20(_token).safeTransferFrom(msg.sender, treasury, protocolFee);

            // transfer amount
            ERC20(_token).safeTransferFrom(msg.sender, _recipient, remainingAmount);
            emit Payment(
                msg.sender,
                _recipient,
                subscriptionIndex,
                msg.sender,
                _amount,
                _token,
                protocolFee,
                0,
                _processingFeeToken,
                _initialPayments
            );
        } else {
            subscriptionIndex = _createSubscription(
                _recipient,
                _amount,
                _token,
                _cooldown,
                _maxProcessingFee,
                _processingFeeToken,
                _delay,
                _auctionDuration,
                _sponsor,
                0,
                _index
            );
        }

        return subscriptionIndex;
    }

    function _createSubscription(
        address _recipient,
        uint256 _amount,
        address _token,
        uint32 _cooldown,
        uint256 _maxProcessingFee,
        address _processingFeeToken,
        uint32 _delay,
        uint32 _auctionDuration,
        address _sponsor,
        uint16 _paymentCounter,
        uint256 _index
    ) private returns (uint256 subscriptionIndex) {
        subscriptionIndex = subscriptions.length;

        if (_auctionDuration > _cooldown) revert AuctionDurationGreaterThanCooldown();

        if (_index < subscriptionIndex) {
            Subscription storage subscription = subscriptions[_index];
            if (subscription.sender != address(0)) revert SubscriptionAlreadyExists();
            Subscription memory newSubscription = Subscription({
                sender: msg.sender,
                recipient: _recipient,
                sponsor: _sponsor,
                amount: _amount,
                token: _token,
                cooldown: _cooldown,
                lastPayment: uint40(block.timestamp - _cooldown + _delay),
                maxProcessingFee: _maxProcessingFee,
                processingFeeToken: _processingFeeToken,
                auctionDuration: _auctionDuration,
                paymentCounter: _paymentCounter
            });
            subscriptionIndex = _index;
            subscriptions[subscriptionIndex] = newSubscription;
        } else {
            subscriptions.push(
                Subscription(
                    msg.sender,
                    _recipient,
                    _amount,
                    _token,
                    _maxProcessingFee,
                    _processingFeeToken,
                    uint40(block.timestamp - _cooldown + _delay),
                    _sponsor,
                    _cooldown,
                    _auctionDuration,
                    _paymentCounter
                )
            );
        }

        userToSubscriptionIndex[msg.sender][userSubscriptionNonce[msg.sender]] = subscriptionIndex;
        userSubscriptionNonce[msg.sender]++;
        recipientToSubscriptionIndex[_recipient][recipientSubscriptionNonce[_recipient]] = subscriptionIndex;
        recipientSubscriptionNonce[_recipient]++;

        bytes32 subscriptionHash = keccak256(abi.encodePacked(msg.sender, _recipient, _token, _cooldown));
        subscriptionHashToSubscriptionIndex[subscriptionHash][subscriptionHashToNonce[subscriptionHash]] =
            subscriptionIndex;
        subscriptionHashToNonce[subscriptionHash]++;

        emit SubscriptionCreated(subscriptionIndex, _recipient);

        return subscriptionIndex;
    }

    function cancelSubscription(uint256 _subscriptionIndex) public override {
        // test if storage or memory is cheaper
        Subscription memory subscription = subscriptions[_subscriptionIndex];
        if (subscription.sender != msg.sender && subscription.recipient != msg.sender) revert NotSenderOrRecipient();

        delete subscriptions[_subscriptionIndex];
        emit SubscriptionCanceled(_subscriptionIndex, subscription.recipient);
    }

    function cancelExpiredSubscription(uint256 _subscriptionIndex) public override {
        Subscription memory subscription = subscriptions[_subscriptionIndex];
        if (subscription.lastPayment + subscription.cooldown + subscription.auctionDuration >= block.timestamp) {
            revert NotEnoughTimePast();
        }
        delete subscriptions[_subscriptionIndex];
        emit SubscriptionCanceled(_subscriptionIndex, subscription.recipient);
    }

    function revokeSponsorship(uint256 _subscriptionIndex) public override {
        Subscription storage subscription = subscriptions[_subscriptionIndex];
        if (subscription.sponsor != msg.sender) revert NotSponsorOfSubscription();
        subscription.sponsor = subscription.sender;
        emit SponsorshipRevoked(_subscriptionIndex, subscription.sender);
    }

    function processPayment(uint256 _subscriptionIndex, address _feeRecipient)
        public
        override
        returns (uint256 processingFee, address processingToken)
    {
        Subscription storage subscription = subscriptions[_subscriptionIndex];

        // check if subscription exists, it would be set to 0 if delete previously
        if (subscription.sender == address(0)) revert SubscriptionIsCanceled();
        if (subscription.lastPayment + subscription.cooldown > block.timestamp) revert NotEnoughTimePast();
        if (subscription.lastPayment + subscription.cooldown + subscription.auctionDuration < block.timestamp) {
            revert AuctionExpired();
        }

        // calculate executor fee basis points, goes from 0 to subscription.executorFeeBasisPoints over subscription.auctionDuration seconds
        uint256 secondsInAuctionPeriod = block.timestamp - subscription.lastPayment - subscription.cooldown;

        processingFee = (subscription.maxProcessingFee * secondsInAuctionPeriod) / subscription.auctionDuration;

        if (processingFee > subscription.maxProcessingFee) revert ExceedingMaxProcessingFee();

        subscription.lastPayment += subscription.cooldown;

        uint256 protocolFee = calculateFee(subscription.amount, treasuryFeeBasisPoints);
        uint256 remainingAmount = subscription.amount - protocolFee;

        // transfer protocol fee
        ERC20(subscription.token).safeTransferFrom(subscription.sender, treasury, protocolFee);
        // transfer executor fee
        ERC20(subscription.processingFeeToken).safeTransferFrom(subscription.sponsor, _feeRecipient, processingFee);
        // transfer amount
        ERC20(subscription.token).safeTransferFrom(subscription.sender, subscription.recipient, remainingAmount);

        emit Payment(
            subscription.sender,
            subscription.recipient,
            _subscriptionIndex,
            subscription.sponsor,
            subscription.amount,
            subscription.token,
            protocolFee,
            processingFee,
            subscription.processingFeeToken,
            1
        );

        subscription.paymentCounter++;

        return (processingFee, subscription.processingFeeToken);
    }

    function updateMaxProcessingFee(uint256 _subscriptionIndex, uint256 _maxProcessingFee, address _processingFeeToken)
        public
        override
    {
        Subscription storage subscription = subscriptions[_subscriptionIndex];
        if (subscription.sponsor != msg.sender) revert NotSponsorOfSubscription();

        uint256 nextPaymentDue = subscription.lastPayment + subscription.cooldown;

        if (block.timestamp >= nextPaymentDue && block.timestamp < nextPaymentDue + subscription.auctionDuration) {
            revert InFeeAuctionPeriod();
        }

        subscription.maxProcessingFee = _maxProcessingFee;
        subscription.processingFeeToken = _processingFeeToken;

        emit MaxProcessingFeeUpdated(_subscriptionIndex, _maxProcessingFee, _processingFeeToken);
    }

    function getNumberOfSubscriptions() public view override returns (uint256 numberOfSubscriptions) {
        numberOfSubscriptions = subscriptions.length;
        return numberOfSubscriptions;
    }

    function invalidateUnorderedNonces(uint256 wordPos, uint256 mask) external {
        nonceBitmap[msg.sender][wordPos] |= mask;

        emit UnorderedNonceInvalidation(msg.sender, wordPos, mask);
    }

    /// @notice Returns the index of the bitmap and the bit position within the bitmap. Used for unordered nonces
    /// @param nonce The nonce to get the associated word and bit positions
    /// @return wordPos The word position or index into the nonceBitmap
    /// @return bitPos The bit position
    /// @dev The first 248 bits of the nonce value is the index of the desired bitmap
    /// @dev The last 8 bits of the nonce value is the position of the bit in the bitmap
    function bitmapPositions(uint256 nonce) private pure returns (uint256 wordPos, uint256 bitPos) {
        wordPos = uint248(nonce >> 8);
        bitPos = uint8(nonce);
    }

    /// @notice Checks whether a nonce is taken and sets the bit at the bit position in the bitmap at the word position
    /// @param from The address to use the nonce at
    /// @param nonce The nonce to spend
    function _useUnorderedNonce(address from, uint256 nonce) internal {
        (uint256 wordPos, uint256 bitPos) = bitmapPositions(nonce);
        uint256 bit = 1 << bitPos;
        uint256 flipped = nonceBitmap[from][wordPos] ^= bit;

        if (flipped & bit == 0) revert InvalidNonce();
    }
}
