// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IBatchExecutor} from "./interfaces/IBatchExecutor.sol";
import {IERC20Subscription} from "./interfaces/IERC20Subscription.sol";
import {ERC20Subscription} from "./ERC20Subscription.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";

contract BatchExecutor is IBatchExecutor {
    using SafeTransferLib for ERC20;

    ERC20Subscription public immutable erc20SubscriptionContract;

    event NumberOfSuccessfulPayments(uint256 successfullPayments);
    event UpdatingClaimableRewards(address indexed from, uint256 amount);

    address public rewardTokenAddress;
    address public treasuryAddress;

    // address to claimable tokens
    mapping(address => uint256) public claimableRewards;

    uint256 public rewardFactor;

    constructor(
        ERC20Subscription _erc20SubscriptionContract,
        address _rewardTokenAddress,
        uint256 _rewardFactor,
        address _treasuryAddress
    ) {
        erc20SubscriptionContract = _erc20SubscriptionContract;
        rewardTokenAddress = _rewardTokenAddress;
        rewardFactor = _rewardFactor;
        treasuryAddress = _treasuryAddress;
    }

    function executeBatch(IERC20Subscription.Subscription[] calldata _subscriptions) public override {
        uint256 successfullPayments = 0;
        for (uint256 i = 0; i < _subscriptions.length; ++i) {
            try erc20SubscriptionContract.collectPayment(_subscriptions[i]) {
                successfullPayments++;
            } catch (bytes memory revertData) {
                emit FailedPayment(
                    _subscriptions[i].owner,
                    _subscriptions[i].permit.permitted.to,
                    _subscriptions[i].permit.permitted.amount,
                    _subscriptions[i].permit.permitted.token,
                    revertData
                );
            }
        }

        // update claimable tokens depending on successfullPayments
        if (successfullPayments > 0) {
            emit UpdatingClaimableRewards(msg.sender, successfullPayments * rewardFactor);
            claimableRewards[msg.sender] += successfullPayments * rewardFactor;
        }

        emit NumberOfSuccessfulPayments(successfullPayments);
    }

    // should have approval from treasuryAddress to transfer rewardToken, otherwise will revert
    function claimRewards() public override {
        uint256 claimableAmount = claimableRewards[msg.sender];
        claimableRewards[msg.sender] = 0;
        ERC20(rewardTokenAddress).safeTransferFrom(treasuryAddress, msg.sender, claimableAmount);
    }
}
