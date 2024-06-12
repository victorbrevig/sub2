// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISub2} from "./ISub2.sol";

interface IBatchProcessor {
    /// @notice Processes a batch of subscriptions.
    /// @notice Will not revert on failure of processing any single subscription, but will emit a FailedExecution event.
    /// @param _subscriptionIndices The indices of the subscriptions to process.
    /// @param _feeRecipient The address to receive the processing fees.
    /// @return receipts The receipts of the processed subscriptions.
    function processBatch(uint256[] calldata _subscriptionIndices, address _feeRecipient)
        external
        returns (Receipt[] memory);

    struct Receipt {
        uint256 subscriptionIndex;
        uint256 processingFee;
        address processingFeeToken;
    }

    /// @notice Thrown when processing a single subscription payment reverts.
    event FailedExecution(uint256 subscriptionIndex, bytes revertData);
}
