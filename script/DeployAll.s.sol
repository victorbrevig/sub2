// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {ERC20Subscription} from "../src/ERC20Subscription.sol";
import {BatchExecutor} from "../src/BatchExecutor.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

contract DeployAll is Script {
    address feeRecipient;
    uint16 feeBasisPoints;
    address authAddress;
    // owner is deployer
    address owner;

    uint256 rewardFactor;

    // token
    string name;
    string symbol;
    uint8 decimals;

    function setUp() public {
        // set to treasury
        feeRecipient = 0x84cC05F95B87fd9ba181C43562d89Ea5e605F6D0;
        feeBasisPoints = 500;
        authAddress = 0x0ad846B856f36F47f2C6F2997F8bF5a73eD16ED1;
        owner = 0x303cAE9641B868722194Bd9517eaC5ca2ad6e71a;

        rewardFactor = 1;

        name = "RewardToken";
        symbol = "RWT";
        decimals = 18;
    }

    function run()
        public
        returns (ERC20Subscription erc20Subscription, BatchExecutor batchExecutor, ERC20Token erc20Token)
    {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        erc20Subscription = new ERC20Subscription(feeRecipient, feeBasisPoints, authAddress, owner);
        console2.log("ERC20Subscription Deployed:", address(erc20Subscription));

        batchExecutor = new BatchExecutor(erc20Subscription, rewardFactor, owner);
        console2.log("BatchExecutor Deployed:", address(batchExecutor));

        erc20Token = new ERC20Token(name, symbol, decimals, address(batchExecutor));
        console2.log("ERC20Token Deployed:", address(erc20Token));

        batchExecutor.setRewardTokenAddress(address(erc20Token));
        console2.log("RewardToken Address Set:", address(erc20Token));

        console2.logBytes32(erc20Subscription.DOMAIN_SEPARATOR());

        vm.stopBroadcast();
    }
}
