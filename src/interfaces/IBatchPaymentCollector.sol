// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Subscription} from "./IERC20Subscription.sol";

interface IBatchPaymentCollector {
    function collectBatchPayment(
        IERC20Subscription.PermitTransferFrom[] memory permit,
        IERC20Subscription.SignatureTransferDetails[] calldata transferDetails,
        address[] calldata owners,
        bytes[] calldata signatures
    ) external;
}
