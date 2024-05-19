// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISub2} from "./interfaces/ISub2.sol";
import {FeeManager} from "./FeeManager.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solmate/src/utils/ReentrancyGuard.sol";

contract Sub2 is ISub2, FeeManager, ReentrancyGuard {
    using SafeTransferLib for ERC20;

    uint16 public feeAuctionPeriod = 30 minutes;

    Subscription[] public subscriptions;

    //mapping(address => mapping(uint16 => Subscription)) public subscriptions;
    mapping(address => mapping(uint16 => uint256)) public userToSubscriptionIndex;
    mapping(address => uint16) public userSubscriptionNonce;

    mapping(address => mapping(uint32 => uint256)) public recipientToSubscriptionIndex;
    mapping(address => uint32) public recipientSubscriptionNonce;

    constructor(address _treasury, uint16 _treasuryBasisPoints, address _owner)
        FeeManager(_owner, _treasury, _treasuryBasisPoints)
    {}

    function createSubscription(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint16 _maxExecutorFeeBasisPoints
    ) public override returns (uint256 subscriptionIndex) {
        // first send the transaction
        // fee is calculated based on the amount
        uint256 protocolFee = calculateFee(_amount, treasuryFeeBasisPoints);

        // transfer protocol fee
        ERC20(_token).safeTransferFrom(msg.sender, treasury, protocolFee);

        // transfer amount
        ERC20(_token).safeTransferFrom(msg.sender, _recipient, _amount);

        subscriptionIndex =
            _createSubscription(_recipient, _amount, _token, _cooldown, _maxExecutorFeeBasisPoints, _cooldown);

        emit SuccessfulPayment(msg.sender, _recipient, subscriptionIndex, _amount, _token, protocolFee, 1);

        return subscriptionIndex;
    }

    function createSubscriptionWithDelay(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint16 _maxExecutorFeeBasisPoints,
        uint256 _delay
    ) public override returns (uint256 subscriptionIndex) {
        return _createSubscription(_recipient, _amount, _token, _cooldown, _maxExecutorFeeBasisPoints, _delay);
    }

    function _createSubscription(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint16 _maxExecutorFeeBasisPoints,
        uint256 _delay
    ) private returns (uint256) {
        uint256 subscriptionIndex = subscriptions.length;
        subscriptions.push(
            Subscription(
                msg.sender,
                _recipient,
                _amount,
                _token,
                _cooldown,
                block.timestamp - _cooldown + _delay,
                _maxExecutorFeeBasisPoints
            )
        );

        userToSubscriptionIndex[msg.sender][userSubscriptionNonce[msg.sender]] = subscriptionIndex;
        userSubscriptionNonce[msg.sender]++;
        recipientToSubscriptionIndex[_recipient][recipientSubscriptionNonce[_recipient]] = subscriptionIndex;
        recipientSubscriptionNonce[_recipient]++;

        emit SubscriptionCreated(subscriptionIndex);

        return subscriptionIndex;
    }

    function cancelSubscription(uint256 _subscriptionIndex) public override {
        // test if storage or memory is cheaper
        Subscription memory subscription = subscriptions[_subscriptionIndex];
        if (subscription.sender != msg.sender && subscription.recipient != msg.sender) revert NotSenderOrRecipient();
        delete subscriptions[_subscriptionIndex];
        emit SubscriptionCanceled(_subscriptionIndex);
    }

    // returns (subscriptionIndex, executorFee, executorFeeBasisPoints, tokenAddress)
    function redeemPayment(uint256 _subscriptionIndex, address _feeRecipient)
        public
        override
        returns (uint256 executorFee, address token)
    {
        Subscription storage subscription = subscriptions[_subscriptionIndex];

        // check if subscription exists, it would be set to 0 if delete previously
        if (subscription.sender == address(0)) revert SubscriptionIsCanceled();
        if (subscription.lastPayment + subscription.cooldown > block.timestamp) revert NotEnoughTimePast();

        // calculate executor fee basis points, goes from 0 to subscription.executorFeeBasisPoints over feeAuctionPeriod seconds
        uint256 secondsInAuctionPeriod =
            min(block.timestamp - subscription.lastPayment - subscription.cooldown, feeAuctionPeriod);

        uint256 executorFeeBPS =
            (uint256(subscription.maxExecutorFeeBasisPoints) * secondsInAuctionPeriod) / feeAuctionPeriod;

        require(executorFeeBPS <= type(uint16).max, "Value exceeds uint16 range");

        uint16 castExecutorFeeBPS = uint16(executorFeeBPS);

        require(executorFeeBPS <= subscription.maxExecutorFeeBasisPoints, "Invalid fee basis points");

        uint256 protocolFee = calculateFee(subscription.amount, treasuryFeeBasisPoints);
        executorFee = calculateFee(subscription.amount, castExecutorFeeBPS);

        subscription.lastPayment = block.timestamp;

        // transfer protocol fee
        ERC20(subscription.token).safeTransferFrom(subscription.sender, treasury, protocolFee);

        // transfer executor fee
        ERC20(subscription.token).safeTransferFrom(subscription.sender, _feeRecipient, executorFee);

        // transfer amount
        ERC20(subscription.token).safeTransferFrom(subscription.sender, subscription.recipient, subscription.amount);

        emit SuccessfulPayment(
            subscription.sender,
            subscription.recipient,
            _subscriptionIndex,
            subscription.amount,
            subscription.token,
            protocolFee + executorFee,
            1
        );

        return (executorFee, subscription.token);
    }

    function updateMaxExecutorFee(uint256 _subscriptionIndex, uint16 _maxExecutorFeeBasisPoints) public override {
        Subscription storage subscription = subscriptions[_subscriptionIndex];
        if (subscription.sender != msg.sender) revert NotOwnerOfSubscription();
        if (subscription.sender == address(0)) revert SubscriptionIsCanceled();
        if (_maxExecutorFeeBasisPoints > FEE_BASE) revert InvalidFeeBasisPoints();
        if (
            block.timestamp >= subscription.lastPayment + subscription.cooldown
                && block.timestamp < subscription.lastPayment + subscription.cooldown + feeAuctionPeriod
        ) revert InFeeAuctionPeriod();

        subscription.maxExecutorFeeBasisPoints = _maxExecutorFeeBasisPoints;

        emit ExecutorFeeUpdated(_subscriptionIndex, _maxExecutorFeeBasisPoints);
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

        ERC20(subscription.token).safeTransferFrom(msg.sender, treasury, protocolFee);
        ERC20(subscription.token).safeTransferFrom(msg.sender, subscription.recipient, totalAmount);

        emit SuccessfulPayment(
            msg.sender, subscription.recipient, _subscriptionIndex, totalAmount, subscription.token, protocolFee, _terms
        );
    }

    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }
}
