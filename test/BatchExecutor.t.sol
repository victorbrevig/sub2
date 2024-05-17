// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {SafeERC20, IERC20, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {TokenProvider} from "./utils/TokenProvider.sol";
import {AddressBuilder} from "./utils/AddressBuilder.sol";
import {AmountBuilder} from "./utils/AmountBuilder.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {ISub2} from "../src/interfaces/ISub2.sol";
import {Sub2} from "../src/Sub2.sol";
import {IBatchExecutor} from "../src/interfaces/IBatchExecutor.sol";
import {BatchExecutor} from "../src/BatchExecutor.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

contract BatchExecutorTest is Test, TokenProvider, GasSnapshot {
    using AddressBuilder for address[];
    using AmountBuilder for uint256[];

    event Transfer(address indexed from, address indexed token, address indexed to, uint256 amount);

    Sub2 erc20Subscription;
    BatchExecutor batchExecutor;

    address from;
    uint256 fromPrivateKey;
    uint256 defaultAmount = 10 * 1e6;

    address address0 = address(0x0);
    address address2 = address(0x2);
    address address3 = address(0x3);

    address recipient = address(0x1);

    address feeRecipient = address3;

    address treasury = address(0x4);

    address executor = address(0x5);

    uint16 treasuryFeeBasisPoints = 2000;
    uint16 defaultExecutorFeeBasisPoints = 3000;

    function setUp() public {
        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

        erc20Subscription = new Sub2(treasury, treasuryFeeBasisPoints, address2);

        initializeERC20Tokens();

        setERC20TestTokens(from);
        setERC20TestTokenApprovals(vm, from, address(erc20Subscription));

        batchExecutor = new BatchExecutor(erc20Subscription);
    }

    function test_CorrectClaimableAmountAfterSuccessfulExecution() public {
        uint256 cooldownTime = 0;

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(recipient);

        uint256 treasuryFee = erc20Subscription.calculateFee(defaultAmount, erc20Subscription.treasuryFeeBasisPoints());

        vm.prank(from);
        erc20Subscription.createSubscription(
            recipient, defaultAmount, address(token0), cooldownTime, defaultExecutorFeeBasisPoints
        );

        uint256[] memory subscriptionIndices = new uint256[](1);
        subscriptionIndices.push(0);
        vm.prank(executor);
        IBatchExecutor.Receipt[] memory receipts = batchExecutor.executeBatch(subscriptionIndices, address(executor));

        uint256 executorFee = receipts[0].executorFee;
        uint256 remaining = defaultAmount - treasuryFee - executorFee;

        assertEq(
            token0.balanceOf(from), startBalanceFrom - defaultAmount * 2 - treasuryFee * 2 - executorFee, "from balance"
        );
        assertEq(token0.balanceOf(recipient), startBalanceTo + defaultAmount * 2, "to balance");
        assertEq(token0.balanceOf(treasury), treasuryFee * 2, "treasury balance");
        assertEq(token0.balanceOf(executor), executorFee, "executor balance");
    }

    function test_CorrectClaimableAmountAfterUnsuccessfulExecution() public {
        // execution will revert since cooldown has not passed
        uint256 cooldownTime = 10;

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(recipient);

        uint256 treasuryFee = erc20Subscription.calculateFee(defaultAmount, erc20Subscription.treasuryFeeBasisPoints());

        vm.warp(1641070800);
        vm.prank(from);
        erc20Subscription.createSubscription(
            recipient, defaultAmount, address(token0), cooldownTime, defaultExecutorFeeBasisPoints
        );

        uint256[] memory subscriptionIndices = new uint256[](1);
        subscriptionIndices.push(0);

        vm.warp(1641070800 + 5);
        vm.prank(executor);
        batchExecutor.executeBatch(subscriptionIndices, address(executor));

        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount - treasuryFee, "from balance");
        assertEq(token0.balanceOf(recipient), defaultAmount, "to balance");
        assertEq(token0.balanceOf(treasury), treasuryFee, "treasury balance");
        assertEq(token0.balanceOf(executor), 0, "executor balance");
    }
}
