// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Sub2} from "./Sub2.sol";
import {IBatchExecutor} from "./interfaces/IBatchExecutor.sol";
import {ISub2} from "./interfaces/ISub2.sol";

/// @author stick
contract BatchExecutor is IBatchExecutor {
    Sub2 public immutable sub2;

    constructor(Sub2 _erc20SubscriptionContract) {
        sub2 = _erc20SubscriptionContract;
    }

    event FailedExecution(uint256 subscriptionIndex, bytes revertData);

    function executeBatch(uint256[] calldata _subscriptionIndices, address _feeRecipient)
        public
        override
        returns (Receipt[] memory)
    {
        Receipt[] memory receipts = new Receipt[](_subscriptionIndices.length);
        for (uint256 i = 0; i < _subscriptionIndices.length; ++i) {
            try sub2.redeemPayment(_subscriptionIndices[i], _feeRecipient) returns (
                uint256 executorTip, address tipToken
            ) {
                receipts[i] = Receipt({subscriptionIndex: i, executorTip: executorTip, tipToken: tipToken});
            } catch (bytes memory revertData) {
                emit FailedExecution(_subscriptionIndices[i], revertData);
            }
        }
        return receipts;
    }

    function readSubscriptions(uint256[] calldata _subscriptionIndices)
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
                uint256 amount,
                address token,
                uint256 cooldown,
                uint256 lastPayment,
                uint256 maxTip,
                address tipToken
            ) = sub2.subscriptions(_subscriptionIndices[i]);
            subscriptions[i] = ISub2.Subscription({
                sender: sender,
                recipient: recipient,
                amount: amount,
                token: token,
                cooldown: cooldown,
                lastPayment: lastPayment,
                maxTip: maxTip,
                tipToken: tipToken
            });
        }
        return subscriptions;
    }
}
