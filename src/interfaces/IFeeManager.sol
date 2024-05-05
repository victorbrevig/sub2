// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IFeeManager {
    function calculateFee(uint256 _amount, uint16 _basisPoints)
        external
        pure
        returns (uint256 fee, uint256 remaining);

    function setFeeBase(uint16 _feeBasisPoints) external;

    function setFeeRecipient(address _feeRecipient) external;
}
