// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBatchExecutor2 {
    struct ExecuteSubscriptionInput {
        address from;
        uint16 nonce;
        address feeRecipient;
    }

    function executeBatch(ExecuteSubscriptionInput[] calldata _subscriptionInputs) external;
}
