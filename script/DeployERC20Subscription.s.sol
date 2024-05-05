// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {ERC20Subscription} from "../src/ERC20Subscription.sol";

contract DeployERC20Subscription is Script {
    address feeRecipient;
    uint16 feeBasisPoints;
    address authAddress;
    address owner;

    function setUp() public {
        // set to treasury
        feeRecipient = 0x84cC05F95B87fd9ba181C43562d89Ea5e605F6D0;
        feeBasisPoints = 500;
        authAddress = 0x0ad846B856f36F47f2C6F2997F8bF5a73eD16ED1;
        owner = 0x303cAE9641B868722194Bd9517eaC5ca2ad6e71a;
    }

    function run() public returns (ERC20Subscription erc20Subscription) {
        vm.startBroadcast();

        erc20Subscription = new ERC20Subscription(feeRecipient, feeBasisPoints, authAddress, owner);
        console2.log("ERC20Subscription Deployed:", address(erc20Subscription));

        vm.stopBroadcast();
    }
}
