// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {ERC20Subscription2} from "../src/ERC20Subscription2.sol";
import {BatchExecutor2} from "../src/BatchExecutor2.sol";

contract DeployAll2 is Script {
    address treasury;
    uint16 treasuryBasisPoints;
    uint16 executorFeeBasisPoints;
    // owner is deployer
    address owner;

    function setUp() public {
        // set to treasury
        treasury = 0x84cC05F95B87fd9ba181C43562d89Ea5e605F6D0;
        treasuryBasisPoints = 2000;
        executorFeeBasisPoints = 3000;
        owner = 0x303cAE9641B868722194Bd9517eaC5ca2ad6e71a;
    }

    function run() public returns (ERC20Subscription2 erc20Subscription, BatchExecutor2 batchExecutor) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        erc20Subscription = new ERC20Subscription2(treasury, treasuryBasisPoints, executorFeeBasisPoints, owner);
        console2.log("ERC20Subscription2 Deployed:", address(erc20Subscription));

        batchExecutor = new BatchExecutor2(erc20Subscription);
        console2.log("BatchExecutor2 Deployed:", address(batchExecutor));

        vm.stopBroadcast();
    }
}
