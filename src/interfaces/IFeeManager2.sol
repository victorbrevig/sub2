// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IFeeManager2 {
    function calculateFee(uint256 _amount, uint16 _basisPoints) external pure returns (uint256 fee);

    function setTreasury(address _treasury) external;

    function setExecutorFeeBasisPoints(uint16 _executorFeeBasisPoints) external;

    function setTreasuryFeeBasisPoints(uint16 _treasuryFeeBasisPoints) external;
}
