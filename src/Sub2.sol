// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISub2} from "./interfaces/ISub2.sol";
import {FeeManager2} from "./FeeManager2.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solmate/src/utils/ReentrancyGuard.sol";

contract Sub2 is ISub2, FeeManager2, ReentrancyGuard {
    using SafeTransferLib for ERC20;

    mapping(address => mapping(uint16 => Subscription)) public subscriptions;
    mapping(address => uint16) public subscriptionNonce;

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

        uint16 nonce = subscriptionNonce[msg.sender];
        emit SuccessfulPayment(msg.sender, _recipient, nonce, _amount, _token, protocolFee);

        _createSubscription(_recipient, _amount, _token, _cooldown, _executorFeeBasisPoints, nonce);
    }

    function createSubscriptionWithoutFirstPayment(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint16 _executorFeeBasisPoints
    ) public override {
        uint16 nonce = subscriptionNonce[msg.sender];
        _createSubscription(_recipient, _amount, _token, _cooldown, _executorFeeBasisPoints, nonce);
    }

    function _createSubscription(
        address _recipient,
        uint256 _amount,
        address _token,
        uint256 _cooldown,
        uint16 _executorFeeBasisPoints,
        uint16 _nonce
    ) private {
        // maybe check for nonce overflows?
        Subscription memory subscription =
            Subscription(_recipient, _amount, _token, _cooldown, block.timestamp, _executorFeeBasisPoints);
        subscriptions[msg.sender][_nonce] = subscription;
        subscriptionNonce[msg.sender]++;
        emit SubscriptionCreated(subscription, _nonce);
    }

    function cancelSubscription(uint16 _subscriptionId) public override {
        Subscription memory subscription = subscriptions[msg.sender][_subscriptionId];
        delete subscriptions[msg.sender][_subscriptionId];
        emit SubscriptionCanceled(subscription, _subscriptionId);
    }

    function redeemPayment(address _from, uint16 _subscriptionId, address _feeRecipient) public override nonReentrant {
        uint16 nonce = subscriptionNonce[_from];
        if (_subscriptionId >= nonce) revert SubscriptionDoesNotExist();

        Subscription storage subscription = subscriptions[_from][_subscriptionId];

        // check if subscription exists, it would be set to 0 if delete previously
        if (subscription.recipient == address(0)) revert SubscriptionIsCanceled();
        if (subscription.lastPayment + subscription.cooldown > block.timestamp) revert NotEnoughTimePast();

        subscriptions[_from][_subscriptionId].lastPayment = block.timestamp;

        uint256 protocolFee = calculateFee(subscription.amount, treasuryFeeBasisPoints);
        uint256 executorFee = calculateFee(subscription.amount, subscription.executorFeeBasisPoints);
        ERC20(subscription.token).safeTransferFrom(_from, treasury, protocolFee);

        ERC20(subscription.token).safeTransferFrom(_from, _feeRecipient, executorFee);

        uint256 remainingAmount = subscription.amount - protocolFee - executorFee;
        // transfer remaining amount
        ERC20(subscription.token).safeTransferFrom(_from, subscription.recipient, remainingAmount);

        emit SuccessfulPayment(
            _from, subscription.recipient, nonce, subscription.amount, subscription.token, protocolFee + executorFee
        );
    }

    function updateExecutorFee(uint16 _subscriptionId, uint16 _executorFeeBasisPoints) public {
        if (_executorFeeBasisPoints + treasuryFeeBasisPoints > FEE_BASE) revert InvalidFeeBasisPoints();
        uint16 nonce = subscriptionNonce[msg.sender];
        if (_subscriptionId >= nonce) revert SubscriptionDoesNotExist();
        if (subscriptions[msg.sender][_subscriptionId].recipient == address(0)) revert SubscriptionIsCanceled();

        subscriptions[msg.sender][_subscriptionId].executorFeeBasisPoints = _executorFeeBasisPoints;
    }

    function getSubscriptions(address _user) public view returns (Subscription[] memory) {
        uint16 nonce = subscriptionNonce[_user];
        Subscription[] memory userSubscriptions = new Subscription[](nonce);

        for (uint16 i = 0; i < nonce; ++i) {
            userSubscriptions[i] = subscriptions[_user][i];
        }

        return userSubscriptions;
    }
}
