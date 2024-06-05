// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {Faucet} from "../src/Faucet.sol";

contract DeployFaucet is Script {
    function setUp() public {}

    function run() public returns (Faucet faucet) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        faucet = new Faucet();
        console2.log("Faucet Deployed:", address(faucet));

        vm.stopBroadcast();
    }
}
