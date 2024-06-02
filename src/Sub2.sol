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

    mapping(address => mapping(uint256 => uint256)) public nonceBitmap;

    constructor(address _treasury, uint16 _treasuryBasisPoints, address _owner)
        FeeManager(_owner, _treasury, _treasuryBasisPoints)
    {}

    function createSubscription(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint256 _maxTip,
        address _tipToken,
        uint256 _auctionDuration,
        uint256 _index
    ) public override returns (uint256 subscriptionIndex) {
        // first send the transaction
        // fee is calculated based on the amount
        uint256 protocolFee = calculateFee(_amount, treasuryFeeBasisPoints);

        uint256 remainingAmount = _amount - protocolFee;

        // transfer protocol fee
        ERC20(_token).safeTransferFrom(msg.sender, treasury, protocolFee);

        // transfer amount
        ERC20(_token).safeTransferFrom(msg.sender, _recipient, remainingAmount);

        subscriptionIndex = _createSubscription(
            _recipient, _amount, _token, _cooldown, _maxTip, _tipToken, _cooldown, _auctionDuration, msg.sender, _index
        );

        emit SuccessfulPayment(msg.sender, _recipient, subscriptionIndex, _amount, _token, protocolFee, 0, _tipToken, 1);

        return subscriptionIndex;
    }

    function createSubscriptionWithSponsor(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint256 _maxTip,
        address _tipToken,
        uint256 _delay,
        uint256 _terms,
        uint256 _auctionDuration,
        uint256 _index,
        address _sponsor,
        bytes calldata _signature,
        SponsorPermit calldata _permit
    ) public override returns (uint256 subscriptionIndex) {
        // validate signature with witness

        if (block.timestamp > _permit.deadline) revert SignatureExpired(_permit.deadline);
        if (_recipient != _permit.recipient) revert InvalidRecipient(_permit.recipient);
        if (_amount != _permit.amount) revert InvalidAmount(_permit.amount);
        if (_cooldown != _permit.cooldown) revert InvalidCooldown(_permit.cooldown);
        if (_delay != _permit.delay) revert InvalidDelay(_permit.delay);
        if (_terms != _permit.terms) revert InvalidTerms(_permit.terms);
        if (_maxTip != _permit.maxTip) revert InvalidMaxTip(_permit.maxTip);
        if (_auctionDuration != _permit.auctionDuration) revert InvalidAuctionDuration(_permit.auctionDuration);
        if (_token != _permit.token) revert InvalidToken(_permit.token);
        if (_tipToken != _permit.tipToken) revert InvalidTipToken(_permit.tipToken);

        _useUnorderedNonce(_sponsor, _permit.nonce);

        bytes32 dataHash = _permit.hash();

        _signature.verify(_hashTypedData(dataHash), _sponsor);

        if (_delay == 0) {
            subscriptionIndex = _createSubscription(
                _recipient,
                _amount,
                _token,
                _cooldown,
                _maxTip,
                _tipToken,
                _cooldown * _terms,
                _auctionDuration,
                _sponsor,
                _index
            );
            // initial payment
            uint256 totalAmount = _amount * _terms;
            uint256 protocolFee = calculateFee(totalAmount, treasuryFeeBasisPoints);

            uint256 remainingAmount = totalAmount - protocolFee;

            // transfer protocol fee
            ERC20(_token).safeTransferFrom(msg.sender, treasury, protocolFee);

            // transfer amount
            ERC20(_token).safeTransferFrom(msg.sender, _recipient, remainingAmount);
            emit SuccessfulPayment(
                msg.sender, _recipient, subscriptionIndex, _amount, _token, protocolFee, 0, _tipToken, _terms
            );
        } else {
            subscriptionIndex = _createSubscription(
                _recipient, _amount, _token, _cooldown, _maxTip, _tipToken, _delay, _auctionDuration, _sponsor, _index
            );
        }

        return subscriptionIndex;
    }

    function createSubscriptionWithDelay(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint256 _maxTip,
        address _tipToken,
        uint256 _delay,
        uint256 _auctionDuration,
        uint256 _index
    ) public override returns (uint256 subscriptionIndex) {
        return _createSubscription(
            _recipient, _amount, _token, _cooldown, _maxTip, _tipToken, _delay, _auctionDuration, msg.sender, _index
        );
    }

    function createSubscriptionWithPrepaidTerms(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint256 _maxTip,
        address _tipToken,
        uint256 _terms,
        uint256 _auctionDuration,
        uint256 _index
    ) public override returns (uint256 subscriptionIndex) {
        uint256 totalAmount = _amount * _terms;
        uint256 protocolFee = calculateFee(totalAmount, treasuryFeeBasisPoints);

        uint256 remainingAmount = totalAmount - protocolFee;

        ERC20(_token).safeTransferFrom(msg.sender, treasury, protocolFee);
        ERC20(_token).safeTransferFrom(msg.sender, _recipient, remainingAmount);

        subscriptionIndex = _createSubscription(
            _recipient,
            _amount,
            _token,
            _cooldown,
            _maxTip,
            _tipToken,
            _cooldown * (_terms + 1),
            _auctionDuration,
            msg.sender,
            _index
        );

        emit SuccessfulPayment(
            msg.sender, _recipient, subscriptionIndex, _amount, _token, protocolFee, 0, _tipToken, _terms
        );

        return subscriptionIndex;
    }

    function _createSubscription(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint256 _maxTip,
        address _tipToken,
        uint256 _delay,
        uint256 _auctionDuration,
        address _sponsor,
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
                lastPayment: block.timestamp - _cooldown + _delay,
                maxTip: _maxTip,
                tipToken: _tipToken,
                auctionDuration: _auctionDuration
            });
            subscriptionIndex = _index;
            subscriptions[subscriptionIndex] = newSubscription;
        } else {
            subscriptions.push(
                Subscription(
                    msg.sender,
                    _recipient,
                    _sponsor,
                    _amount,
                    _token,
                    _cooldown,
                    block.timestamp - _cooldown + _delay,
                    _maxTip,
                    _tipToken,
                    _auctionDuration
                )
            );
        }

        userToSubscriptionIndex[msg.sender][userSubscriptionNonce[msg.sender]] = subscriptionIndex;
        userSubscriptionNonce[msg.sender]++;
        recipientToSubscriptionIndex[_recipient][recipientSubscriptionNonce[_recipient]] = subscriptionIndex;
        recipientSubscriptionNonce[_recipient]++;

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

    // returns (subscriptionIndex, executorFee, executorFeeBasisPoints, tokenAddress)
    function redeemPayment(uint256 _subscriptionIndex, address _feeRecipient)
        public
        override
        returns (uint256 executorTip, address tipToken)
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

        executorTip = (subscription.maxTip * secondsInAuctionPeriod) / subscription.auctionDuration;

        require(executorTip <= subscription.maxTip, "Exceeding max tip");

        subscription.lastPayment += subscription.cooldown;

        uint256 protocolFee = calculateFee(subscription.amount, treasuryFeeBasisPoints);

        uint256 remainingAmount = subscription.amount - protocolFee;

        // transfer protocol fee
        ERC20(subscription.token).safeTransferFrom(subscription.sender, treasury, protocolFee);

        // transfer executor fee
        ERC20(subscription.tipToken).safeTransferFrom(subscription.sponsor, _feeRecipient, executorTip);

        // transfer amount
        ERC20(subscription.token).safeTransferFrom(subscription.sender, subscription.recipient, remainingAmount);

        emit SuccessfulPayment(
            subscription.sender,
            subscription.recipient,
            _subscriptionIndex,
            subscription.amount,
            subscription.token,
            protocolFee,
            executorTip,
            subscription.tipToken,
            1
        );

        return (executorTip, subscription.tipToken);
    }

    function updateMaxTip(uint256 _subscriptionIndex, uint256 _maxTip, address _tipToken) public override {
        Subscription storage subscription = subscriptions[_subscriptionIndex];
        if (subscription.sender != msg.sender) revert NotOwnerOfSubscription();
        if (
            block.timestamp >= subscription.lastPayment + subscription.cooldown
                && block.timestamp < subscription.lastPayment + subscription.cooldown + subscription.auctionDuration
        ) revert InFeeAuctionPeriod();

        subscription.maxTip = _maxTip;
        subscription.tipToken = _tipToken;

        emit MaxTipUpdated(_subscriptionIndex, _maxTip, _tipToken);
    }

    function updateAuctionDuration(uint256 _subscriptionIndex, uint256 _auctionDuration) public override {
        Subscription storage subscription = subscriptions[_subscriptionIndex];
        if (subscription.recipient != msg.sender) revert NotRecipientOfSubscription();
        if (
            block.timestamp >= subscription.lastPayment + subscription.cooldown
                && block.timestamp < subscription.lastPayment + subscription.cooldown + subscription.auctionDuration
        ) revert InFeeAuctionPeriod();
        if (_auctionDuration > subscription.cooldown) revert AuctionDurationGreaterThanCooldown();

        subscription.auctionDuration = _auctionDuration;
        emit AuctionDurationUpdated(_subscriptionIndex, _auctionDuration);
    }

    function getSubscriptionsSender(address _sender) public view override returns (IndexedSubscription[] memory) {
        uint16 nonce = userSubscriptionNonce[_sender];
        IndexedSubscription[] memory userSubscriptions = new IndexedSubscription[](nonce);

        for (uint16 i = 0; i < nonce; ++i) {
            uint256 index = userToSubscriptionIndex[_sender][i];
            userSubscriptions[i] = IndexedSubscription({index: index, subscription: subscriptions[index]});
        }

        return userSubscriptions;
    }

    function getSubscriptionsRecipient(address _recipient)
        public
        view
        override
        returns (IndexedSubscription[] memory)
    {
        uint32 nonce = recipientSubscriptionNonce[_recipient];
        IndexedSubscription[] memory recipientSubscriptions = new IndexedSubscription[](nonce);

        for (uint16 i = 0; i < nonce; ++i) {
            uint256 index = recipientToSubscriptionIndex[_recipient][i];
            recipientSubscriptions[i] = IndexedSubscription({index: index, subscription: subscriptions[index]});
        }

        return recipientSubscriptions;
    }

    function getNumberOfSubscriptions() public view override returns (uint256) {
        return subscriptions.length;
    }

    function prePay(uint256 _subscriptionIndex, uint256 _terms) public override {
        Subscription storage subscription = subscriptions[_subscriptionIndex];
        if (subscription.sender != msg.sender) revert NotOwnerOfSubscription();
        if (subscription.sender == address(0)) revert SubscriptionIsCanceled();

        subscription.lastPayment = block.timestamp + subscription.cooldown * _terms;

        uint256 totalAmount = subscription.amount * _terms;
        uint256 protocolFee = calculateFee(totalAmount, treasuryFeeBasisPoints);

        uint256 remainingAmount = totalAmount - protocolFee;

        ERC20(subscription.token).safeTransferFrom(msg.sender, treasury, protocolFee);
        ERC20(subscription.token).safeTransferFrom(msg.sender, subscription.recipient, remainingAmount);

        emit SuccessfulPayment(
            msg.sender,
            subscription.recipient,
            _subscriptionIndex,
            totalAmount,
            subscription.token,
            protocolFee,
            0,
            subscription.tipToken,
            _terms
        );
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
