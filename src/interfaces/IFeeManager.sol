// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IFeeManager {
    function calculateFee(uint256 _amount, uint16 _basisPoints) external pure returns (uint256 fee);

    function setTreasury(address _treasury) external;

    function setTreasuryFeeBasisPoints(uint16 _treasuryFeeBasisPoints) external;

    function calculateNewAmountFromNewFee(
        uint256 _currentAmount,
        uint16 _currentBps,
        uint16 _newBps,
        uint16 _treasuryBps
    ) external pure returns (uint256 newAmount);
}
