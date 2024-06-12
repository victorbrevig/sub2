// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IQuerier} from "./interfaces/IQuerier.sol";
import {ISub2} from "./interfaces/ISub2.sol";
import {Sub2} from "./Sub2.sol";

contract Querier is IQuerier {
    Sub2 public immutable sub2;

    constructor(Sub2 _sub2) {
        sub2 = _sub2;
    }

    function getSubscriptionsSender(address _sender)
        public
        view
        override
        returns (ISub2.IndexedSubscription[] memory)
    {
        uint16 nonce = sub2.userSubscriptionNonce(_sender);
        ISub2.IndexedSubscription[] memory userSubscriptions = new ISub2.IndexedSubscription[](nonce);

        for (uint16 i = 0; i < nonce; ++i) {
            uint256 index = sub2.userToSubscriptionIndex(_sender, i);
            (
                address sender,
                address recipient,
                address sponsor,
                uint256 amount,
                address token,
                uint256 cooldown,
                uint256 lastPayment,
                uint256 maxProcessingFee,
                address processingFeeToken,
                uint256 auctionDuration,
                uint256 totalPayments
            ) = sub2.subscriptions(index);
            if (sender != _sender) continue;
            ISub2.Subscription memory subscription = ISub2.Subscription({
                sender: sender,
                recipient: recipient,
                sponsor: sponsor,
                amount: amount,
                token: token,
                cooldown: cooldown,
                lastPayment: lastPayment,
                maxProcessingFee: maxProcessingFee,
                processingFeeToken: processingFeeToken,
                auctionDuration: auctionDuration,
                totalPayments: totalPayments
            });

            userSubscriptions[i] = ISub2.IndexedSubscription({index: index, subscription: subscription});
        }

        return userSubscriptions;
    }

    function getSubscriptionsRecipient(address _recipient)
        public
        view
        override
        returns (ISub2.IndexedSubscription[] memory)
    {
        uint32 nonce = sub2.recipientSubscriptionNonce(_recipient);
        ISub2.IndexedSubscription[] memory recipientSubscriptions = new ISub2.IndexedSubscription[](nonce);

        for (uint16 i = 0; i < nonce; ++i) {
            uint256 index = sub2.recipientToSubscriptionIndex(_recipient, i);
            (
                address sender,
                address recipient,
                address sponsor,
                uint256 amount,
                address token,
                uint256 cooldown,
                uint256 lastPayment,
                uint256 maxProcessingFee,
                address processingFeeToken,
                uint256 auctionDuration,
                uint256 totalPayments
            ) = sub2.subscriptions(index);
            if (recipient != _recipient) continue;
            ISub2.Subscription memory subscription = ISub2.Subscription({
                sender: sender,
                recipient: recipient,
                sponsor: sponsor,
                amount: amount,
                token: token,
                cooldown: cooldown,
                lastPayment: lastPayment,
                maxProcessingFee: maxProcessingFee,
                processingFeeToken: processingFeeToken,
                auctionDuration: auctionDuration,
                totalPayments: totalPayments
            });
            recipientSubscriptions[i] = ISub2.IndexedSubscription({index: index, subscription: subscription});
        }

        return recipientSubscriptions;
    }

    function getSubscriptions(uint256[] calldata _subscriptionIndices)
        public
        view
        override
        returns (ISub2.Subscription[] memory)
    {
        ISub2.Subscription[] memory subscriptions = new ISub2.Subscription[](_subscriptionIndices.length);
        for (uint256 i = 0; i < _subscriptionIndices.length; ++i) {
            (
                address sender,
                address recipient,
                address sponsor,
                uint256 amount,
                address token,
                uint256 cooldown,
                uint256 lastPayment,
                uint256 maxProcessingFee,
                address processingFeeToken,
                uint256 auctionDuration,
                uint256 totalPayments
            ) = sub2.subscriptions(_subscriptionIndices[i]);
            subscriptions[i] = ISub2.Subscription({
                sender: sender,
                recipient: recipient,
                sponsor: sponsor,
                amount: amount,
                token: token,
                cooldown: cooldown,
                lastPayment: lastPayment,
                maxProcessingFee: maxProcessingFee,
                processingFeeToken: processingFeeToken,
                auctionDuration: auctionDuration,
                totalPayments: totalPayments
            });
        }
        return subscriptions;
    }
}
