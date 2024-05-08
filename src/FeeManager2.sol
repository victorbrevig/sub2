// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IFeeManager2} from "./interfaces/IFeeManager2.sol";
import {Owned} from "solmate/src/auth/Owned.sol";

contract FeeManager2 is IFeeManager2, Owned {
    uint32 public constant FEE_BASE = 1_000_000;

    // like uniswap, 3000 = 0.3% etc
    uint16 public treasuryFeeBasisPoints;
    uint16 public executorFeeBasisPoints;
    address internal treasury;

    constructor(address _owner, address _treasury, uint16 _treasuryFeeBasisPoints) Owned(_owner) {
        treasury = _treasury;
        treasuryFeeBasisPoints = _treasuryFeeBasisPoints;
    }

    // Function to calculate fee and remaining amount
    function calculateFee(uint256 _amount, uint16 _basisPoints) public pure override returns (uint256 fee) {
        // Calculate fee
        fee = (_amount * _basisPoints) / FEE_BASE;

        return fee;
    }

    function setTreasuryFeeBasisPoints(uint16 _treasuryFeeBasisPoints) public override onlyOwner {
        treasuryFeeBasisPoints = _treasuryFeeBasisPoints;
    }

    function setTreasury(address _treasury) public override onlyOwner {
        treasury = _treasury;
    }
}
