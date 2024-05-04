// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Subscription} from "./IERC20Subscription.sol";

interface IBatchPaymentCollector {
    event FailedPayment(address from, address to, uint256 amount, address token, bytes revertData);

    function collectBatchPayment(IERC20Subscription.Subscription[] calldata _subscriptions) external;
}
