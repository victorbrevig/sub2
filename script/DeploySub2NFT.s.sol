// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {Sub2NFT} from "../src/Sub2NFT.sol";

contract DeploySub2NFT is Script {
    function setUp() public {}

    function run() public returns (Sub2NFT sub2NFT) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        sub2NFT = new Sub2NFT("Sub2 Subscribed", "SUB2NFT", 0xb71D0A9BD766B94B4Db4d292770A589cDB1426d8);
        console2.log("Sub2NFT Deployed:", address(sub2NFT));

        vm.stopBroadcast();
    }
}
