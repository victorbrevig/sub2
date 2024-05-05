// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Subscription} from "./IERC20Subscription.sol";

interface IBatchExecutor {
    event FailedExecution(IERC20Subscription.Subscription subscription, bytes revertData);

    function executeBatch(IERC20Subscription.Subscription[] calldata _subscriptions) external;

    function claimRewards() external;

    function setRewardFactor(uint256 _rewardFactor) external;

    function setTreasuryAddress(address _treasuryAddress) external;
}
