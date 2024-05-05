// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {BatchExecutor} from "../src/BatchExecutor.sol";
import {ERC20Subscription} from "../src/ERC20Subscription.sol";

contract DeployBatchExecutor is Script {
    ERC20Subscription erc20SubscriptionContract;
    address rewardTokenAddress;
    uint256 rewardFactor;
    address treasuryAddress;
    address owner;

    function setUp() public {
        erc20SubscriptionContract = ERC20Subscription(address(0x12341234));
        rewardTokenAddress = address(0x43214321);
        rewardFactor = 1;
        treasuryAddress = 0x84cC05F95B87fd9ba181C43562d89Ea5e605F6D0;
        owner = 0x303cAE9641B868722194Bd9517eaC5ca2ad6e71a;
    }

    function run() public returns (BatchExecutor batchExecutor) {
        vm.startBroadcast();

        batchExecutor =
            new BatchExecutor(erc20SubscriptionContract, rewardTokenAddress, rewardFactor, treasuryAddress, owner);
        console2.log("BatchExecutor Deployed:", address(batchExecutor));

        vm.stopBroadcast();
    }
}
