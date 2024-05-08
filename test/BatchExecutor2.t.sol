// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {SafeERC20, IERC20, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {TokenProvider} from "./utils/TokenProvider.sol";
import {AddressBuilder} from "./utils/AddressBuilder.sol";
import {AmountBuilder} from "./utils/AmountBuilder.sol";
import {StructBuilder} from "./utils/StructBuilder.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {IERC20Subscription2} from "../src/interfaces/IERC20Subscription2.sol";
import {ERC20Subscription2} from "../src/ERC20Subscription2.sol";
import {IBatchExecutor2} from "../src/interfaces/IBatchExecutor2.sol";
import {BatchExecutor2} from "../src/BatchExecutor2.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

contract ERC20SubscriptonTest is Test, TokenProvider, GasSnapshot {
    using AddressBuilder for address[];
    using AmountBuilder for uint256[];

    event Transfer(address indexed from, address indexed token, address indexed to, uint256 amount);

    ERC20Subscription2 erc20Subscription;
    BatchExecutor2 batchExecutor;

    address from;
    uint256 fromPrivateKey;
    uint256 defaultAmount = 10 * 1e6;

    address address0 = address(0x0);
    address address2 = address(0x2);
    address address3 = address(0x3);

    address feeRecipient = address3;

    address treasury = address(0x4);

    address executor = address(0x5);

    uint16 treasuryFeeBasisPoints = 2000;
    uint16 defaultExecutorFeeBasisPoints = 3000;

    function setUp() public {
        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

        erc20Subscription = new ERC20Subscription2(treasury, treasuryFeeBasisPoints, address2);

        initializeERC20Tokens();

        setERC20TestTokens(from);
        setERC20TestTokenApprovals(vm, from, address(erc20Subscription));

        batchExecutor = new BatchExecutor2(erc20Subscription);
    }

    function test_CorrectClaimableAmountAfterSuccessfulExecution() public {
        uint256 cooldownTime = 0;

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address2);

        uint256 treasuryFee = erc20Subscription.calculateFee(defaultAmount, erc20Subscription.treasuryFeeBasisPoints());
        uint256 executorFee = erc20Subscription.calculateFee(defaultAmount, defaultExecutorFeeBasisPoints);

        vm.prank(from);
        erc20Subscription.createSubscription(
            address2, defaultAmount, address(token0), cooldownTime, defaultExecutorFeeBasisPoints
        );

        IBatchExecutor2.ExecuteSubscriptionInput[] memory subscriptionInputs =
            new IBatchExecutor2.ExecuteSubscriptionInput[](1);
        subscriptionInputs[0] = IBatchExecutor2.ExecuteSubscriptionInput({from: from, nonce: 0, feeRecipient: executor});

        vm.prank(executor);
        batchExecutor.executeBatch(subscriptionInputs);

        uint256 remaining = defaultAmount - treasuryFee - executorFee;

        assertEq(defaultAmount, remaining + treasuryFee + executorFee, "default amount sum");
        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount * 2, "from balance");
        assertEq(token0.balanceOf(address2), startBalanceTo + (defaultAmount - treasuryFee) + remaining, "to balance");
        assertEq(token0.balanceOf(treasury), treasuryFee * 2, "treasury balance");
        assertEq(token0.balanceOf(executor), executorFee, "executor balance");
    }

    function test_CorrectClaimableAmountAfterUnsuccessfulExecution() public {
        uint256 cooldownTime = 0;

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address2);

        uint256 treasuryFee =
            erc20Subscription.calculateFee(startBalanceFrom, erc20Subscription.treasuryFeeBasisPoints());
        uint256 executorFee = erc20Subscription.calculateFee(startBalanceFrom, defaultExecutorFeeBasisPoints);

        vm.prank(from);
        erc20Subscription.createSubscription(
            address2, startBalanceFrom, address(token0), cooldownTime, defaultExecutorFeeBasisPoints
        );

        IBatchExecutor2.ExecuteSubscriptionInput[] memory subscriptionInputs =
            new IBatchExecutor2.ExecuteSubscriptionInput[](1);
        subscriptionInputs[0] = IBatchExecutor2.ExecuteSubscriptionInput({from: from, nonce: 0, feeRecipient: executor});

        vm.prank(executor);
        batchExecutor.executeBatch(subscriptionInputs);

        assertEq(token0.balanceOf(from), 0, "from balance");
        assertEq(token0.balanceOf(address2), startBalanceFrom - treasuryFee, "to balance");
        assertEq(token0.balanceOf(treasury), treasuryFee, "treasury balance");
        assertEq(token0.balanceOf(executor), 0, "executor balance");
    }
}
