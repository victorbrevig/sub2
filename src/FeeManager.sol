// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IFeeManager} from "./interfaces/IFeeManager.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract FeeManager is IFeeManager, Ownable {
    uint256 constant FEE_BASE = 1_000_000;

    // like uniswap, 3000 = 0.3% etc
    uint16 public feeBasisPoints;
    address internal feeRecipient;

    constructor(address _feeRecipient, uint16 _feeBasisPoints) {
        feeRecipient = _feeRecipient;
        feeBasisPoints = _feeBasisPoints;
    }

    // Function to calculate fee and remaining amount
    function calculateFee(uint256 amount) public view override returns (uint256 fee, uint256 remaining) {
        // Calculate fee
        fee = (amount * feeBasisPoints) / FEE_BASE;
        // Calculate remaining amount after fee deduction
        remaining = amount - fee;
        return (fee, remaining);
    }

    function setFeeBase(uint16 _feeBasisPoints) public override onlyOwner {
        feeBasisPoints = _feeBasisPoints;
    }

    function setFeeRecipient(address _feeRecipient) public onlyOwner {
        feeRecipient = _feeRecipient;
    }
}
