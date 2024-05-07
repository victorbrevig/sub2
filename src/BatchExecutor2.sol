// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20Subscription2} from "./ERC20Subscription2.sol";
import {IBatchExecutor2} from "./interfaces/IBatchExecutor2.sol";

/// @author stick
contract BatchExecutor2 is IBatchExecutor2 {
    ERC20Subscription2 public immutable erc20SubscriptionContract;

    constructor(ERC20Subscription2 _erc20SubscriptionContract) {
        erc20SubscriptionContract = _erc20SubscriptionContract;
    }

    event FailedExecution(ExecuteSubscriptionInput subscriptionInput, bytes revertData);

    function executeBatch(ExecuteSubscriptionInput[] calldata _subscriptionInputs) public override {
        for (uint256 i = 0; i < _subscriptionInputs.length; ++i) {
            try erc20SubscriptionContract.redeemPayment(
                _subscriptionInputs[i].from, _subscriptionInputs[i].nonce, _subscriptionInputs[i].feeRecipient
            ) {} catch (bytes memory revertData) {
                emit FailedExecution(_subscriptionInputs[i], revertData);
            }
        }
    }
}
