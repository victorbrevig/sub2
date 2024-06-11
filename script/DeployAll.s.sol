// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {Sub2} from "../src/Sub2.sol";
import {BatchProcessor} from "../src/BatchProcessor.sol";
import {Querier} from "../src/Querier.sol";

contract DeployAll is Script {
    address treasury;
    uint16 treasuryBasisPoints;
    // owner is deployer
    address owner;

    function setUp() public {
        // set to treasury
        treasury = 0x84cC05F95B87fd9ba181C43562d89Ea5e605F6D0;
        treasuryBasisPoints = 2000;
        owner = 0x303cAE9641B868722194Bd9517eaC5ca2ad6e71a;
    }

    function run() public returns (Sub2 sub2, BatchProcessor batchProcessor, Querier querier) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        sub2 = new Sub2(treasury, treasuryBasisPoints, owner);
        console2.log("Sub2 Deployed:", address(sub2));

        batchProcessor = new BatchProcessor(sub2);
        console2.log("BatchProcessor Deployed:", address(batchProcessor));

        querier = new Querier(sub2);
        console2.log("Querier Deployed:", address(querier));

        vm.stopBroadcast();
    }
}
