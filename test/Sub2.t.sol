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
import "forge-std/console2.sol";

contract Sub2Test is Test, TokenProvider, GasSnapshot {
    using AddressBuilder for address[];
    using AmountBuilder for uint256[];

    event Transfer(address indexed from, address indexed token, address indexed to, uint256 amount);

    Sub2 sub2;
    Sub2 sub2_2;

    address from;
    uint256 fromPrivateKey;

    address auth;
    uint256 authPrivateKey;

    uint256 defaultAmount = 10 * 1e6;

    address address0 = address(0x0);
    address address2 = address(0x2);
    address executor = address(0x3);

    address recipient = address(0x1);

    address treasury = address(0x4);
    uint16 treasuryFeeBasisPoints = 2000;
    uint16 defaultMaxExecutorFeeBasisPoints = 3000;

    uint256 defaultIndex = type(uint256).max;

    function setUp() public {
        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

        authPrivateKey = 0x43214321;
        auth = vm.addr(authPrivateKey);

        sub2 = new Sub2(treasury, treasuryFeeBasisPoints, address2);
        sub2_2 = new Sub2(treasury, treasuryFeeBasisPoints, address2);

        initializeERC20Tokens();

        setERC20TestTokens(from);
        setERC20TestTokenApprovals(vm, from, address(sub2));
        setERC20TestTokenApprovals(vm, from, address(sub2_2));
    }

    // tests that funds are correctly transferred from the owner to the recipient upon payment for initial payment
    function test_CreateSubscription() public {
        uint256 cooldownTime = 0;

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(recipient);

        vm.prank(from);
        snapStart("createSubscription");
        sub2.createSubscription(
            recipient, defaultAmount, address(token0), cooldownTime, defaultMaxExecutorFeeBasisPoints, defaultIndex
        );
        snapEnd();

        uint256 fee = sub2.calculateFee(defaultAmount, sub2.treasuryFeeBasisPoints());

        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount - fee);
        assertEq(token0.balanceOf(recipient), startBalanceTo + defaultAmount);
        assertEq(token0.balanceOf(treasury), fee);
    }

    function test_RedeemPayment() public {
        uint256 cooldownTime = 0;

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(recipient);

        uint256 treasuryFee = sub2.calculateFee(defaultAmount, sub2.treasuryFeeBasisPoints());

        vm.prank(from);

        sub2.createSubscription(
            recipient, defaultAmount, address(token0), cooldownTime, defaultMaxExecutorFeeBasisPoints, defaultIndex
        );

        assertEq(token0.balanceOf(executor), 0, "executor balance not 0");
        assertEq(token0.balanceOf(treasury), treasuryFee, "treasury balance too much");

        vm.prank(executor);
        snapStart("redeemPaymentFirst");
        (uint256 executorFee,) = sub2.redeemPayment(0, executor);
        snapEnd();

        assertEq(
            token0.balanceOf(from), startBalanceFrom - defaultAmount * 2 - treasuryFee * 2 - executorFee, "from balance"
        );
        assertEq(token0.balanceOf(recipient), startBalanceTo + defaultAmount * 2, "to balance");
        assertEq(token0.balanceOf(treasury), treasuryFee * 2, "treasury balance");
        assertEq(token0.balanceOf(executor), executorFee, "executor balance");
    }

    function test_CollectPaymentBeforeCooldownPassed(uint256 cooldownTime, uint256 blockTime) public {
        // cooldownTime has to be <= blockTime when created
        blockTime = bound(blockTime, 1, type(uint256).max / 2);
        cooldownTime = bound(cooldownTime, 0, blockTime);
        vm.warp(blockTime);
        vm.prank(from);
        sub2.createSubscription(
            recipient, defaultAmount, address(token0), cooldownTime, defaultMaxExecutorFeeBasisPoints, defaultIndex
        );

        vm.warp(blockTime + cooldownTime - 1);
        vm.prank(executor);
        vm.expectRevert(abi.encodeWithSelector(ISub2.NotEnoughTimePast.selector));
        sub2.redeemPayment(0, executor);
    }
    /*
    function test_PrePayTimeCorrectlyUpdated(uint256 cooldownTime) public {
        cooldownTime = bound(cooldownTime, 0, type(uint32).max - 1641070800);
        vm.warp(1641070800);
        vm.prank(from);
        sub2.createSubscription(
            recipient, defaultAmount, address(token0), cooldownTime, defaultMaxExecutorFeeBasisPoints, defaultIndex
        );

        vm.warp(1641070800 + cooldownTime - 1);
        vm.prank(from);
        vm.expectRevert(abi.encodeWithSelector(ISub2.NotEnoughTimePast.selector));
        sub2.prePay(0, 3);
    }
    */

    function test_CollectPaymentBeforeCooldownPassed2(uint256 cooldownTime, uint256 blockTime) public {
        blockTime = bound(blockTime, 1, type(uint256).max / 2);
        cooldownTime = bound(cooldownTime, 0, blockTime / 2);

        vm.warp(blockTime);
        vm.prank(from);
        sub2.createSubscription(
            recipient, defaultAmount, address(token0), cooldownTime, defaultMaxExecutorFeeBasisPoints, defaultIndex
        );

        vm.warp(blockTime + cooldownTime);
        vm.prank(executor);
        sub2.redeemPayment(0, executor);

        vm.warp(blockTime + cooldownTime * 2 - 1);
        vm.prank(executor);
        vm.expectRevert(abi.encodeWithSelector(ISub2.NotEnoughTimePast.selector));
        sub2.redeemPayment(0, executor);
    }

    function test_CollectPaymentAfterCooldownPassed(uint256 cooldownTime, uint256 blockTime) public {
        blockTime = bound(blockTime, 1, type(uint256).max / 2);
        cooldownTime = bound(cooldownTime, 0, blockTime);

        vm.prank(from);
        vm.warp(blockTime);
        sub2.createSubscription(
            recipient, defaultAmount, address(token0), cooldownTime, defaultMaxExecutorFeeBasisPoints, defaultIndex
        );

        vm.prank(executor);
        vm.warp(blockTime + cooldownTime);
        sub2.redeemPayment(0, executor);
    }

    function testFail_RedeemingNonExistentSubscription() public {
        vm.prank(executor);
        sub2.redeemPayment(0, executor);
    }

    function test_CancelSubscriptionUser() public {
        uint256 cooldownTime = 0;
        vm.prank(from);
        sub2.createSubscription(
            recipient, defaultAmount, address(token0), cooldownTime, defaultMaxExecutorFeeBasisPoints, defaultIndex
        );

        vm.prank(from);
        sub2.cancelSubscription(0);
    }

    function test_CancelSubscriptionRecipient() public {
        uint256 cooldownTime = 0;
        vm.prank(from);
        sub2.createSubscription(
            recipient, defaultAmount, address(token0), cooldownTime, defaultMaxExecutorFeeBasisPoints, defaultIndex
        );

        vm.prank(recipient);
        sub2.cancelSubscription(0);
    }

    function test_CancelSubscriptionOther(address _addressCancelling) public {
        vm.assume(_addressCancelling != from);
        vm.assume(_addressCancelling != recipient);

        uint256 cooldownTime = 0;
        vm.prank(from);
        sub2.createSubscription(
            recipient, defaultAmount, address(token0), cooldownTime, defaultMaxExecutorFeeBasisPoints, defaultIndex
        );

        vm.prank(_addressCancelling);
        vm.expectRevert(abi.encodeWithSelector(ISub2.NotSenderOrRecipient.selector));
        sub2.cancelSubscription(0);
    }

    function test_RedeemingCanceledSubscription() public {
        uint256 cooldownTime = 0;
        vm.prank(from);
        sub2.createSubscription(
            recipient, defaultAmount, address(token0), cooldownTime, defaultMaxExecutorFeeBasisPoints, defaultIndex
        );

        vm.prank(from);
        sub2.cancelSubscription(0);

        vm.prank(executor);
        vm.expectRevert(abi.encodeWithSelector(ISub2.SubscriptionIsCanceled.selector));
        sub2.redeemPayment(0, executor);
    }

    function testFail_NotEnoughBalance() public {
        uint256 cooldownTime = 0;
        uint256 startBalanceFrom = token0.balanceOf(from);
        vm.prank(from);
        sub2.createSubscription(
            recipient, startBalanceFrom, address(token0), cooldownTime, defaultMaxExecutorFeeBasisPoints, defaultIndex
        );

        vm.prank(from);
        sub2.redeemPayment(0, executor);
    }

    function test_ExecutorFeeChangeSameOutputAmount(uint16 oldFee, uint16 newFee, uint256 blockTime) public {
        uint256 cooldownTime = 0;
        blockTime = bound(blockTime, 0, type(uint256).max - sub2.feeAuctionPeriod());
        vm.assume(uint32(oldFee) + uint32(treasuryFeeBasisPoints) < sub2.FEE_BASE());
        vm.assume(uint32(newFee) + uint32(treasuryFeeBasisPoints) < sub2.FEE_BASE());

        vm.warp(blockTime);
        vm.prank(from);
        sub2.createSubscriptionWithDelay(
            recipient, defaultAmount, address(token0), cooldownTime, oldFee, 0, defaultIndex
        );

        uint256 startBalanceTo = token0.balanceOf(recipient);

        vm.warp(blockTime);
        vm.prank(executor);
        sub2.redeemPayment(0, executor);

        uint256 startBalanceToSecond = token0.balanceOf(recipient);
        uint256 toBalanceDifferenceFirst = startBalanceToSecond - startBalanceTo;

        vm.warp(blockTime + sub2.feeAuctionPeriod());
        vm.prank(from);
        sub2.updateMaxExecutorFee(0, newFee);

        vm.warp(blockTime + sub2.feeAuctionPeriod());
        vm.prank(executor);
        sub2.redeemPayment(0, executor);

        uint256 toBalanceDifferenceSecond = token0.balanceOf(recipient) - startBalanceToSecond;

        assertEq(toBalanceDifferenceFirst, toBalanceDifferenceSecond, "to balance differences differ");
    }

    function test_MaxFeeCeilingUponRedeeming(uint256 waitTime, uint256 blockTime) public {
        waitTime = bound(waitTime, 0, sub2.feeAuctionPeriod());
        blockTime = bound(blockTime, 1, type(uint256).max - waitTime);

        uint256 cooldownTime = 0;
        uint256 treasuryFee = sub2.calculateFee(defaultAmount, sub2.treasuryFeeBasisPoints());

        vm.warp(blockTime);
        vm.prank(from);
        snapStart("createSubscription");
        sub2.createSubscription(
            recipient, defaultAmount, address(token0), cooldownTime, defaultMaxExecutorFeeBasisPoints, defaultIndex
        );
        snapEnd();

        assertEq(token0.balanceOf(executor), 0, "executor balance not 0");
        assertEq(token0.balanceOf(treasury), treasuryFee, "treasury balance too much");

        vm.warp(blockTime + waitTime);
        vm.prank(executor);
        snapStart("redeemPaymentFirst");
        (uint256 executorFee,) = sub2.redeemPayment(0, executor);
        snapEnd();

        uint256 maxFee = sub2.calculateFee(defaultAmount, defaultMaxExecutorFeeBasisPoints);

        assertGe(maxFee, executorFee, "executor fee bps higher than max");
    }

    function test_CreateSubscriptionWithoutFirstPayment() public {
        uint256 cooldownTime = 0;

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(recipient);

        vm.prank(from);
        sub2.createSubscriptionWithDelay(
            recipient, defaultAmount, address(token0), cooldownTime, defaultMaxExecutorFeeBasisPoints, 0, defaultIndex
        );

        (address sender,,,,,,) = sub2.subscriptions(0);
        assertEq(sender, from);
        assertEq(token0.balanceOf(from), startBalanceFrom);
        assertEq(token0.balanceOf(recipient), startBalanceTo);
    }

    function test_ReuseSubscriptionIndex() public {
        uint256 cooldownTime = 0;

        vm.prank(from);
        uint256 subIndex = sub2.createSubscription(
            recipient, defaultAmount, address(token0), cooldownTime, defaultMaxExecutorFeeBasisPoints, defaultIndex
        );

        vm.prank(from);
        sub2.cancelSubscription(subIndex);

        vm.prank(address2);
        snapStart("createSubscriptionReusingIndex");
        sub2.createSubscriptionWithDelay(
            recipient, defaultAmount, address(token0), cooldownTime, defaultMaxExecutorFeeBasisPoints, 0, subIndex
        );
        snapEnd();

        (address sender,,,,,,) = sub2.subscriptions(subIndex);
        assertEq(sender, address2);
    }

    function test_ReuseNotCanceledSubscriptionIndex() public {
        uint256 cooldownTime = 0;

        vm.prank(from);
        uint256 subIndex = sub2.createSubscription(
            recipient, defaultAmount, address(token0), cooldownTime, defaultMaxExecutorFeeBasisPoints, defaultIndex
        );

        vm.expectRevert(abi.encodeWithSelector(ISub2.SubscriptionAlreadyExists.selector));
        vm.prank(address2);
        sub2.createSubscriptionWithDelay(
            recipient, defaultAmount, address(token0), cooldownTime, defaultMaxExecutorFeeBasisPoints, 0, subIndex
        );
    }
}
