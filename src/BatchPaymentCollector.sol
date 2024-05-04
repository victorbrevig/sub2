// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IBatchPaymentCollector} from "./interfaces/IBatchPaymentCollector.sol";
import {IERC20Subscription} from "./interfaces/IERC20Subscription.sol";
import {ERC20Subscription} from "./ERC20Subscription.sol";

contract BatchPaymentCollector is IBatchPaymentCollector {
    ERC20Subscription public immutable erc20SubscriptionContract;

    constructor(ERC20Subscription _erc20SubscriptionContract) {
        erc20SubscriptionContract = _erc20SubscriptionContract;
    }

    function collectBatchPayment(IERC20Subscription.Subscription[] calldata _subscriptions) public override {
        for (uint256 i = 0; i < _subscriptions.length; ++i) {
            try erc20SubscriptionContract.collectPayment(_subscriptions[i]) {}
            catch (bytes memory revertData) {
                emit FailedPayment(
                    _subscriptions[i].owner,
                    _subscriptions[i].permit.permitted.to,
                    _subscriptions[i].permit.permitted.amount,
                    _subscriptions[i].permit.permitted.token,
                    revertData
                );
            }
        }
    }
}
