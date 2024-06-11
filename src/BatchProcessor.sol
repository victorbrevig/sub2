// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Sub2} from "./Sub2.sol";
import {IBatchProcessor} from "./interfaces/IBatchProcessor.sol";
import {ISub2} from "./interfaces/ISub2.sol";

/// @author stick
contract BatchProcessor is IBatchProcessor {
    Sub2 public immutable sub2;

    constructor(Sub2 _sub2) {
        sub2 = _sub2;
    }

    event FailedExecution(uint256 subscriptionIndex, bytes revertData);

    function processBatch(uint256[] calldata _subscriptionIndices, address _feeRecipient)
        public
        override
        returns (Receipt[] memory)
    {
        Receipt[] memory receipts = new Receipt[](_subscriptionIndices.length);
        for (uint256 i = 0; i < _subscriptionIndices.length; ++i) {
            try sub2.processPayment(_subscriptionIndices[i], _feeRecipient) returns (
                uint256 processingFee, address processingFeeToken
            ) {
                receipts[i] = Receipt({
                    subscriptionIndex: i,
                    processingFee: processingFee,
                    processingFeeToken: processingFeeToken
                });
            } catch (bytes memory revertData) {
                emit FailedExecution(_subscriptionIndices[i], revertData);
            }
        }
        return receipts;
    }
}
