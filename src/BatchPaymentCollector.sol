// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IBatchPaymentCollector} from "./interfaces/IBatchPaymentCollector.sol";
import {IERC20Subscription} from "./interfaces/IERC20Subscription.sol";
import {ERC20Subscription} from "./ERC20Subscription.sol";

contract BatchPaymentCollector is IBatchPaymentCollector {
    ERC20Subscription public immutable erc20SubscriptionContract;

    constructor(ERC20Subscription _erc20SubscriptionContract) {
        erc20SubscriptionContract = _erc20SubscriptionContract;
    }

    function collectBatchPayment(
        IERC20Subscription.PermitTransferFrom[] memory permit,
        IERC20Subscription.SignatureTransferDetails[] calldata transferDetails,
        address[] calldata owners,
        bytes[] calldata signatures
    ) public override {
        for (uint256 i = 0; i < permit.length; ++i) {
            try erc20SubscriptionContract.collectPayment(permit[i], transferDetails[i], owners[i], signatures[i]) {}
                catch (bytes memory revertData) {}
        }
    }
}
