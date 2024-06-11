// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISub2} from "./ISub2.sol";

interface IBatchProcessor {
    function processBatch(uint256[] calldata _subscriptionIndices, address _feeRecipient)
        external
        returns (Receipt[] memory);

    struct Receipt {
        uint256 subscriptionIndex;
        uint256 processingFee;
        address processingFeeToken;
    }
}
