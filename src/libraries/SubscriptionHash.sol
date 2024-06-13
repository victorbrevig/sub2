// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ISub2} from "../interfaces/ISub2.sol";

library SubscriptionHash {
    function hash(ISub2.Subscription memory subscription) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                subscription.sender,
                subscription.recipient,
                subscription.amount,
                subscription.token,
                subscription.cooldown
            )
        );
    }
}
