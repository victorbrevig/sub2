// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Subscription2} from "./interfaces/IERC20Subscription2.sol";
import {FeeManager2} from "./FeeManager2.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";

contract ERC20Subscription2 is IERC20Subscription2, FeeManager2 {
    using SafeTransferLib for ERC20;

    mapping(address => mapping(uint16 => Subscription)) public subscriptions;
    mapping(address => uint16) public subscriptionNonce;

    constructor(address _treasury, uint16 _treasuryBasisPoints, uint16 _executorFeeBasisPoints, address _owner)
        FeeManager2(_owner, _treasury, _treasuryBasisPoints, _executorFeeBasisPoints)
    {}

    function createSubscription(address _recipient, uint256 _amount, address _token, uint256 _cooldown)
        public
        override
    {
        // maybe check for nonce overflows?
        uint16 nonce = subscriptionNonce[msg.sender];

        // first send the transaction
        // take fee
        uint256 protocolFee = calculateFee(_amount, treasuryFeeBasisPoints);
        uint256 remainingAmount = _amount - protocolFee;
        ERC20(_token).safeTransferFrom(msg.sender, treasury, protocolFee);

        // transfer remaining amount
        ERC20(_token).safeTransferFrom(msg.sender, _recipient, remainingAmount);

        Subscription memory subscription = Subscription(_recipient, _amount, _token, _cooldown, block.timestamp);
        subscriptions[msg.sender][nonce] = subscription;
        subscriptionNonce[msg.sender]++;

        emit SuccessfulPayment(msg.sender, _recipient, nonce, _amount, _token, protocolFee);
    }

    function cancelSubscription(uint16 _subscriptionId) public override {
        delete subscriptions[msg.sender][_subscriptionId];
    }

    function redeemPayment(address _from, uint16 _subscriptionId, address _feeRecipient) public override {
        uint16 nonce = subscriptionNonce[_from];
        if (_subscriptionId >= nonce) revert SubscriptionDoesNotExist();

        Subscription memory subscription = subscriptions[_from][_subscriptionId];
        // check if subscription exists, it would be set to 0 if delete previously
        if (subscription.recipient == address(0)) revert SubscriptionCanceled();
        if (subscription.lastPayment + subscription.cooldown > block.timestamp) revert NotEnoughTimePast();

        // first send the transaction
        // take fee
        uint256 protocolFee = calculateFee(subscription.amount, treasuryFeeBasisPoints);
        uint256 executorFee = calculateFee(subscription.amount, executorFeeBasisPoints);
        ERC20(subscription.token).safeTransferFrom(_from, treasury, protocolFee);

        ERC20(subscription.token).safeTransferFrom(_from, _feeRecipient, executorFee);

        uint256 remainingAmount = subscription.amount - protocolFee - executorFee;
        // transfer remaining amount
        ERC20(subscription.token).safeTransferFrom(_from, subscription.recipient, remainingAmount);

        emit SuccessfulPayment(
            _from, subscription.recipient, nonce, subscription.amount, subscription.token, protocolFee + executorFee
        );
    }

    function getSubscriptions(address _user) public view returns (Subscription[] memory) {
        uint16 nonce = subscriptionNonce[_user];
        Subscription[] memory userSubscriptions = new Subscription[](nonce);

        for (uint16 i = 0; i < nonce; i++) {
            userSubscriptions[i] = subscriptions[_user][i];
        }

        return userSubscriptions;
    }
}
