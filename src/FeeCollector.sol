// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20} from "solmate/src/tokens/ERC20.sol";

contract FeeCollector {
    address private immutable sub2;

    constructor(address _sub2) {
        sub2 = _sub2;
    }
}
