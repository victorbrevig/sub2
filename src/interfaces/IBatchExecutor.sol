// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISub2} from "./ISub2.sol";

interface IBatchExecutor {
    function executeBatch(uint256[] calldata _subscriptionIndices, address _feeRecipient)
        external
        returns (Receipt[] memory);

    function readSubscriptions(uint256[] calldata _subscriptionIndices)
        external
        view
        returns (ISub2.Subscription[] memory);

    struct Receipt {
        uint256 subscriptionIndex;
        uint256 executorFee;
        uint256 executorFeeBSP;
        address token;
    }
}
