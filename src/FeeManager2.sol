// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IFeeManager2} from "./interfaces/IFeeManager2.sol";
import {Owned} from "solmate/src/auth/Owned.sol";

contract FeeManager2 is IFeeManager2, Owned {
    uint32 public constant FEE_BASE = 1_000_000;

    // like uniswap, 3000 = 0.3% etc
    uint16 public treasuryFeeBasisPoints;
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

    function calculateNewAmountFromNewFee(
        uint256 _currentAmount,
        uint16 _currentBps,
        uint16 _newBps,
        uint16 _treasuryBps
    ) public pure override returns (uint256 newAmount) {
        require(FEE_BASE - _currentBps - _treasuryBps > 0, "numerator is <= 0");
        require(FEE_BASE - _newBps - _treasuryBps > 0, "denominator is <= 0");

        uint256 numerator = _currentAmount * (FEE_BASE - _currentBps - _treasuryBps);
        uint256 denominator = (FEE_BASE - _newBps - _treasuryBps);

        newAmount = numerator / denominator;
        return newAmount;
    }

    function setTreasuryFeeBasisPoints(uint16 _treasuryFeeBasisPoints) public override onlyOwner {
        treasuryFeeBasisPoints = _treasuryFeeBasisPoints;
    }

    function setTreasury(address _treasury) public override onlyOwner {
        treasury = _treasury;
    }
}
