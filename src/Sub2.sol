// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISub2} from "./interfaces/ISub2.sol";
import {FeeManager2} from "./FeeManager2.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solmate/src/utils/ReentrancyGuard.sol";

contract Sub2 is ISub2, FeeManager2, ReentrancyGuard {
    using SafeTransferLib for ERC20;

    Subscription[] public subscriptions;

    //mapping(address => mapping(uint16 => Subscription)) public subscriptions;
    mapping(address => mapping(uint16 => uint256)) public userToSubscriptionIndex;
    mapping(address => uint16) public userSubscriptionNonce;

    mapping(address => mapping(uint16 => uint256)) public recipientToSubscriptionIndex;
    mapping(address => uint16) public recipientSubscriptionNonce;

    event ExecutorFeeUpdated(uint16 newBasisPoints, uint256 newAmount);

    constructor(address _treasury, uint16 _treasuryBasisPoints, address _owner)
        FeeManager2(_owner, _treasury, _treasuryBasisPoints)
    {}

    function createSubscription(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint16 _executorFeeBasisPoints
    ) public override {
        // first send the transaction
        // take fee
        uint256 protocolFee = calculateFee(_amount, treasuryFeeBasisPoints);
        uint256 remainingAmount = _amount - protocolFee;
        ERC20(_token).safeTransferFrom(msg.sender, treasury, protocolFee);

        // transfer remaining amount
        ERC20(_token).safeTransferFrom(msg.sender, _recipient, remainingAmount);

        emit SuccessfulPayment(msg.sender, _recipient, _amount, _token, protocolFee);

        _createSubscription(_recipient, _amount, _token, _cooldown, _executorFeeBasisPoints);
    }

    function createSubscriptionWithoutFirstPayment(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint16 _executorFeeBasisPoints
    ) public override {
        _createSubscription(_recipient, _amount, _token, _cooldown, _executorFeeBasisPoints);
    }

    function _createSubscription(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint16 _executorFeeBasisPoints
    ) private {
        // maybe check for nonce overflows?
        uint256 subscriptionIndex = subscriptions.length;
        subscriptions.push(
            Subscription(msg.sender, _recipient, _amount, _token, _cooldown, block.timestamp, _executorFeeBasisPoints)
        );

        userToSubscriptionIndex[msg.sender][userSubscriptionNonce[msg.sender]] = subscriptionIndex;
        userSubscriptionNonce[msg.sender]++;
        recipientToSubscriptionIndex[_recipient][recipientSubscriptionNonce[_recipient]] = subscriptionIndex;
        recipientSubscriptionNonce[_recipient]++;

        emit SubscriptionCreated(subscriptions[subscriptionIndex]);
    }

    function cancelSubscription(uint256 _subscriptionIndex) public override {
        Subscription memory subscription = subscriptions[_subscriptionIndex];
        if (subscription.sender != msg.sender && subscription.recipient != msg.sender) revert NotSenderOrRecipient();
        delete subscriptions[_subscriptionIndex];
        emit SubscriptionCanceled(subscription);
    }

    function redeemPayment(uint256 _subscriptionIndex, address _feeRecipient) public override nonReentrant {
        Subscription storage subscription = subscriptions[_subscriptionIndex];

        // check if subscription exists, it would be set to 0 if delete previously
        if (subscription.sender == address(0)) revert SubscriptionIsCanceled();
        if (subscription.lastPayment + subscription.cooldown > block.timestamp) revert NotEnoughTimePast();

        subscription.lastPayment = block.timestamp;

        uint256 protocolFee = calculateFee(subscription.amount, treasuryFeeBasisPoints);
        uint256 executorFee = calculateFee(subscription.amount, subscription.executorFeeBasisPoints);
        ERC20(subscription.token).safeTransferFrom(subscription.sender, treasury, protocolFee);

        ERC20(subscription.token).safeTransferFrom(subscription.sender, _feeRecipient, executorFee);

        uint256 remainingAmount = subscription.amount - protocolFee - executorFee;
        // transfer remaining amount
        ERC20(subscription.token).safeTransferFrom(subscription.sender, subscription.recipient, remainingAmount);

        emit SuccessfulPayment(
            subscription.sender,
            subscription.recipient,
            subscription.amount,
            subscription.token,
            protocolFee + executorFee
        );
    }

    function updateExecutorFee(uint256 _subscriptionIndex, uint16 _executorFeeBasisPoints) public override {
        if (subscriptions[_subscriptionIndex].recipient == address(0)) revert SubscriptionIsCanceled();

        uint256 newAmount = calculateNewAmountFromNewFee(
            subscriptions[_subscriptionIndex].amount,
            subscriptions[_subscriptionIndex].executorFeeBasisPoints,
            _executorFeeBasisPoints,
            treasuryFeeBasisPoints
        );

        subscriptions[_subscriptionIndex].amount = newAmount;
        subscriptions[_subscriptionIndex].executorFeeBasisPoints = _executorFeeBasisPoints;

        emit ExecutorFeeUpdated(_executorFeeBasisPoints, newAmount);
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
        uint16 nonce = recipientSubscriptionNonce[_recipient];
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
}
