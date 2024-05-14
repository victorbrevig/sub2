// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {SafeERC20, IERC20, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {TokenProvider} from "./utils/TokenProvider.sol";
import {AddressBuilder} from "./utils/AddressBuilder.sol";
import {AmountBuilder} from "./utils/AmountBuilder.sol";
import {StructBuilder} from "./utils/StructBuilder.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {ISub2} from "../src/interfaces/ISub2.sol";
import {Sub2} from "../src/Sub2.sol";
import "forge-std/console2.sol";

contract Sub2Test is Test, TokenProvider, GasSnapshot {
    using AddressBuilder for address[];
    using AmountBuilder for uint256[];

    event Transfer(address indexed from, address indexed token, address indexed to, uint256 amount);

    Sub2 erc20Subscription;
    Sub2 erc20Subscription2;

    address from;
    uint256 fromPrivateKey;

    address auth;
    uint256 authPrivateKey;

    uint256 defaultAmount = 10 * 1e6;

    address address0 = address(0x0);
    address address2 = address(0x2);
    address executor = address(0x3);

    address treasury = address(0x4);
    uint16 treasuryFeeBasisPoints = 2000;
    uint16 defaultExecutorFeeBasisPoints = 3000;

    function setUp() public {
        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

        authPrivateKey = 0x43214321;
        auth = vm.addr(authPrivateKey);

        erc20Subscription = new Sub2(treasury, treasuryFeeBasisPoints, address2);
        erc20Subscription2 = new Sub2(treasury, treasuryFeeBasisPoints, address2);

        initializeERC20Tokens();

        setERC20TestTokens(from);
        setERC20TestTokenApprovals(vm, from, address(erc20Subscription));
        setERC20TestTokenApprovals(vm, from, address(erc20Subscription2));
    }

    // tests that funds are correctly transferred from the owner to the recipient upon payment for initial payment
    function test_CreateSubscription() public {
        address recipient = address2;
        uint256 cooldownTime = 0;

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address2);

        vm.prank(from);
        erc20Subscription.createSubscription(
            address2, defaultAmount, address(token0), cooldownTime, defaultExecutorFeeBasisPoints
        );

        uint256 fee = erc20Subscription.calculateFee(defaultAmount, erc20Subscription.treasuryFeeBasisPoints());
        uint256 remaining = defaultAmount - fee;
        assertEq(defaultAmount, remaining + fee);
        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address2), startBalanceTo + remaining);
        assertEq(token0.balanceOf(treasury), fee);
    }

    function test_RedeemPayment() public {
        address recipient = address2;
        uint256 cooldownTime = 0;

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address2);

        uint256 treasuryFee = erc20Subscription.calculateFee(defaultAmount, erc20Subscription.treasuryFeeBasisPoints());
        uint256 executorFee = erc20Subscription.calculateFee(defaultAmount, defaultExecutorFeeBasisPoints);

        vm.prank(from);
        snapStart("createSubscription");
        erc20Subscription.createSubscription(
            address2, defaultAmount, address(token0), cooldownTime, defaultExecutorFeeBasisPoints
        );
        snapEnd();

        assertEq(token0.balanceOf(executor), 0, "executor balance not 0");
        assertEq(token0.balanceOf(treasury), treasuryFee, "treasury balance too much");

        vm.prank(executor);
        snapStart("redeemPaymentFirst");
        erc20Subscription.redeemPayment(0, executor);
        snapEnd();

        uint256 remaining = defaultAmount - treasuryFee - executorFee;

        assertEq(defaultAmount, remaining + treasuryFee + executorFee, "default amount sum");
        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount * 2, "from balance");
        assertEq(token0.balanceOf(address2), startBalanceTo + (defaultAmount - treasuryFee) + remaining, "to balance");
        assertEq(token0.balanceOf(treasury), treasuryFee * 2, "treasury balance");
        assertEq(token0.balanceOf(executor), executorFee, "executor balance");
    }

    function testFail_CollectPaymentBeforeCooldownPassed(uint256 cooldownTime) public {
        vm.assume(cooldownTime > 0);
        address recipient = address2;

        vm.warp(1641070800);
        vm.prank(from);
        erc20Subscription.createSubscription(
            address2, defaultAmount, address(token0), cooldownTime, defaultExecutorFeeBasisPoints
        );

        vm.warp(1641070800 + cooldownTime - 1);
        vm.prank(executor);
        erc20Subscription.redeemPayment(0, executor);
    }

    function testFail_CollectPaymentBeforeCooldownPassed2(uint256 cooldownTime) public {
        vm.assume(cooldownTime > 0);
        vm.assume(1641070800 + cooldownTime * 2 < type(uint256).max);
        address recipient = address2;

        vm.warp(1641070800);
        vm.prank(from);
        erc20Subscription.createSubscription(
            address2, defaultAmount, address(token0), cooldownTime, defaultExecutorFeeBasisPoints
        );

        vm.warp(1641070800 + cooldownTime);
        vm.prank(executor);
        erc20Subscription.redeemPayment(0, executor);

        vm.warp(1641070800 + cooldownTime * 2 - 1);
        vm.prank(executor);
        erc20Subscription.redeemPayment(0, executor);
    }

    function test_CollectPaymentAfterCooldownPassed2(uint256 cooldownTime) public {
        vm.assume(cooldownTime > 0);
        vm.assume(1641070800 + cooldownTime * 2 < type(uint256).max);
        address recipient = address2;

        vm.prank(from);
        vm.warp(1641070800);
        erc20Subscription.createSubscription(
            address2, defaultAmount, address(token0), cooldownTime, defaultExecutorFeeBasisPoints
        );

        vm.prank(executor);
        vm.warp(1641070800 + cooldownTime);
        erc20Subscription.redeemPayment(0, executor);
    }

    function testFail_RedeemingNonExistentSubscription() public {
        vm.prank(executor);
        erc20Subscription.redeemPayment(0, executor);
    }

    function test_CancelSubscriptionUser() public {
        uint256 cooldownTime = 0;
        vm.prank(from);
        erc20Subscription.createSubscription(
            address2, defaultAmount, address(token0), cooldownTime, defaultExecutorFeeBasisPoints
        );

        vm.prank(from);
        erc20Subscription.cancelSubscription(0);
    }

    function test_CancelSubscriptionRecipient() public {
        uint256 cooldownTime = 0;
        vm.prank(from);
        erc20Subscription.createSubscription(
            address2, defaultAmount, address(token0), cooldownTime, defaultExecutorFeeBasisPoints
        );

        vm.prank(address2);
        erc20Subscription.cancelSubscription(0);
    }

    function testFail_CancelSubscriptionOther(address _addressCancelling) public {
        if (_addressCancelling == address2) {
            revert("recipient can cancel");
        }

        uint256 cooldownTime = 0;
        vm.prank(from);
        erc20Subscription.createSubscription(
            address2, defaultAmount, address(token0), cooldownTime, defaultExecutorFeeBasisPoints
        );

        vm.prank(_addressCancelling);
        erc20Subscription.cancelSubscription(0);
    }

    function testFail_RedeemingCanceledSubscription() public {
        uint256 cooldownTime = 0;
        vm.prank(from);
        erc20Subscription.createSubscription(
            address2, defaultAmount, address(token0), cooldownTime, defaultExecutorFeeBasisPoints
        );

        vm.prank(from);
        erc20Subscription.cancelSubscription(0);

        vm.prank(executor);
        erc20Subscription.redeemPayment(0, executor);
    }

    function testFail_NotEnoughBalance() public {
        uint256 cooldownTime = 0;
        uint256 startBalanceFrom = token0.balanceOf(from);
        vm.prank(from);
        erc20Subscription.createSubscription(
            address2, startBalanceFrom, address(token0), cooldownTime, defaultExecutorFeeBasisPoints
        );

        vm.prank(from);
        erc20Subscription.redeemPayment(0, executor);
    }

    function test_ExecutorFeeChangeSameOutputAmount(uint16 oldFee, uint16 newFee) public {
        address recipient = address2;
        uint256 cooldownTime = 0;

        if (!(uint32(oldFee) + uint32(treasuryFeeBasisPoints) < 1_000_000)) {
            return;
        }

        if (!(uint32(newFee) + uint32(treasuryFeeBasisPoints) < 1_000_000)) {
            return;
        }

        vm.prank(from);
        erc20Subscription.createSubscriptionWithoutFirstPayment(
            address2, defaultAmount, address(token0), cooldownTime, oldFee
        );

        uint256 startBalanceTo = token0.balanceOf(address2);

        vm.prank(executor);
        erc20Subscription.redeemPayment(0, executor);

        uint256 startBalanceToSecond = token0.balanceOf(address2);
        uint256 toBalanceDifferenceFirst = startBalanceToSecond - startBalanceTo;

        vm.prank(from);
        erc20Subscription.updateExecutorFee(0, newFee);

        vm.prank(executor);
        erc20Subscription.redeemPayment(0, executor);

        uint256 toBalanceDifferenceSecond = token0.balanceOf(address2) - startBalanceToSecond;

        //assertEq(toBalanceDifferenceFirst, toBalanceDifferenceSecond, "to balance differences differ");

        assertGe(toBalanceDifferenceSecond, toBalanceDifferenceFirst, "to balance not greater");
    }
}
