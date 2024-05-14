// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISub2} from "./ISub2.sol";

interface IBatchExecutor2 {
    function executeBatch(uint256[] calldata _subscriptionIndices, address _feeRecipient) external;

    function readSubscriptions(uint256[] calldata _subscriptionIndices)
        external
        view
        returns (ISub2.Subscription[] memory);
}
