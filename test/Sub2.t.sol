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
import {PermitSignature} from "./utils/PermitSignature.sol";
import {SignatureVerification} from "../src/libraries/SignatureVerification.sol";
import "forge-std/console2.sol";

contract Sub2Test is Test, PermitSignature, TokenProvider, GasSnapshot {
    using AddressBuilder for address[];
    using AmountBuilder for uint256[];

    event Transfer(address indexed from, address indexed token, address indexed to, uint256 amount);

    Sub2 sub2;
    Sub2 sub2_2;

    address from;
    uint256 fromPrivateKey;

    address sponsor;
    uint256 sponsorPrivateKey;

    uint256 defaultAmount = 10 * 1e6;

    address address0 = address(0x0);
    address address2 = address(0x2);
    address processor = address(0x3);

    address recipient = address(0x1);

    address treasury = address(0x4);
    uint16 treasuryFeeBasisPoints = 2000;

    uint256 defaultProcessingFee = 10 * 1e5;

    uint32 defaultCooldown = 1800;
    uint32 defaultAuctionTime = 1800;

    uint32 defaultDelay = 0;
    uint16 defaultTerms = 1;

    address defaultProcessingFeeToken;

    uint256 defaultIndex = type(uint256).max;

    function setUp() public {
        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

        sponsorPrivateKey = 0x43214321;
        sponsor = vm.addr(sponsorPrivateKey);

        sub2 = new Sub2(treasury, treasuryFeeBasisPoints, address2);
        sub2_2 = new Sub2(treasury, treasuryFeeBasisPoints, address2);

        initializeERC20Tokens();
        defaultProcessingFeeToken = address(token0);

        setERC20TestTokens(from);
        setERC20TestTokenApprovals(vm, from, address(sub2));
        setERC20TestTokenApprovals(vm, from, address(sub2_2));
    }

    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    // tests that funds are correctly transferred from the owner to the recipient upon payment for initial payment
    function test_CreateSubscription() public {
        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(recipient);

        vm.prank(from);
        vm.warp(1641070800);
        snapStart("createSubscription");
        sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );
        snapEnd();

        uint256 treasuryFee = sub2.calculateFee(defaultAmount, sub2.treasuryFeeBasisPoints());

        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(recipient), startBalanceTo + defaultAmount - treasuryFee);
        assertEq(token0.balanceOf(treasury), treasuryFee);
    }

    function test_CreateSubscriptionWithSponsor() public {
        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(recipient);

        ISub2.SponsorPermit memory sponsorPermit = ISub2.SponsorPermit({
            nonce: 0,
            deadline: UINT256_MAX,
            recipient: recipient,
            amount: defaultAmount,
            token: address(token0),
            cooldown: defaultCooldown,
            delay: 0,
            initialPayments: 1,
            maxProcessingFee: defaultProcessingFee,
            processingFeeToken: defaultProcessingFeeToken,
            auctionDuration: defaultAuctionTime
        });

        bytes memory sig = getSponsorPermitSignature(sponsorPermit, sponsorPrivateKey, sub2.DOMAIN_SEPARATOR());

        vm.prank(from);
        vm.warp(1641070800);
        snapStart("createSubscriptionWithSponsor");
        sub2.createSubscriptionWithSponsor(sponsorPermit, sponsor, sig, defaultIndex);
        snapEnd();

        uint256 treasuryFee = sub2.calculateFee(defaultAmount, sub2.treasuryFeeBasisPoints());

        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(recipient), startBalanceTo + defaultAmount - treasuryFee);
        assertEq(token0.balanceOf(treasury), treasuryFee);
    }

    function test_CreateSubscriptionWithSponsorOtherPermit() public {
        ISub2.SponsorPermit memory sponsorPermit = ISub2.SponsorPermit({
            nonce: 0,
            deadline: UINT256_MAX,
            recipient: recipient,
            amount: defaultAmount,
            token: address(token0),
            cooldown: defaultCooldown,
            delay: 0,
            initialPayments: 1,
            maxProcessingFee: defaultProcessingFee,
            processingFeeToken: defaultProcessingFeeToken,
            auctionDuration: defaultAuctionTime
        });

        bytes memory sig = getSponsorPermitSignature(sponsorPermit, sponsorPrivateKey, sub2.DOMAIN_SEPARATOR());

        ISub2.SponsorPermit memory sponsorPermitOther = ISub2.SponsorPermit({
            nonce: 0,
            deadline: UINT256_MAX,
            recipient: recipient,
            amount: defaultAmount + 1,
            token: address(token0),
            cooldown: defaultCooldown,
            delay: 0,
            initialPayments: 1,
            maxProcessingFee: defaultProcessingFee,
            processingFeeToken: defaultProcessingFeeToken,
            auctionDuration: defaultAuctionTime
        });

        vm.prank(from);
        vm.warp(1641070800);
        vm.expectRevert(abi.encodeWithSelector(SignatureVerification.InvalidSigner.selector));
        sub2.createSubscriptionWithSponsor(sponsorPermitOther, sponsor, sig, defaultIndex);
    }

    function test_ProcessPayment() public {
        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(recipient);

        uint256 treasuryFee = sub2.calculateFee(defaultAmount, sub2.treasuryFeeBasisPoints());

        vm.prank(from);
        vm.warp(1641070800);
        sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            0,
            defaultTerms,
            defaultIndex
        );

        assertEq(token0.balanceOf(processor), 0, "processor balance not 0");
        assertEq(token0.balanceOf(treasury), treasuryFee, "treasury balance too much");

        vm.prank(processor);
        vm.warp(1641070800 + defaultCooldown);
        snapStart("processPaymentFirst");
        (uint256 processingFee,) = sub2.processPayment(0, processor);
        snapEnd();

        (,,,,,,,,,, uint256 paymentCounter) = sub2.subscriptions(0);

        assertEq(paymentCounter, 2, "payment counter incorrect");
        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount * 2 - processingFee, "from balance");
        assertEq(token0.balanceOf(recipient), startBalanceTo + defaultAmount * 2 - treasuryFee * 2, "to balance");
        assertEq(token0.balanceOf(treasury), treasuryFee * 2, "treasury balance");
        assertEq(token0.balanceOf(processor), processingFee, "processor balance");
    }

    function test_ProcessPaymentBeforeCooldownPassed(uint32 cooldownTime, uint40 blockTime) public {
        // cooldownTime has to be <= blockTime when created
        blockTime = uint40(bound(blockTime, defaultAuctionTime, type(uint40).max / 2));
        cooldownTime = uint32(bound(cooldownTime, defaultAuctionTime, blockTime));
        vm.warp(blockTime);
        vm.prank(from);
        sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            cooldownTime,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );

        vm.warp(blockTime + cooldownTime - 1);
        vm.prank(processor);
        vm.expectRevert(abi.encodeWithSelector(ISub2.NotEnoughTimePast.selector));
        sub2.processPayment(0, processor);
    }

    function test_ProcessPaymentBeforeCooldownPassed2(uint32 cooldownTime, uint40 blockTime) public {
        blockTime = uint40(bound(blockTime, defaultAuctionTime * 2, type(uint40).max / 2));
        cooldownTime = uint32(bound(cooldownTime, defaultAuctionTime, uint32(min(blockTime, type(uint32).max / 2))));
        // uint40(block.timestamp - _cooldown + _delay)
        vm.warp(blockTime);
        vm.prank(from);
        sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            cooldownTime,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );

        vm.warp(blockTime + cooldownTime);
        vm.prank(processor);
        sub2.processPayment(0, processor);

        vm.warp(blockTime + cooldownTime * 2 - 1);
        vm.prank(processor);
        vm.expectRevert(abi.encodeWithSelector(ISub2.NotEnoughTimePast.selector));
        sub2.processPayment(0, processor);
    }

    function test_ProcessPaymentAfterCooldownPassed(uint32 cooldownTime, uint40 blockTime) public {
        blockTime = uint40(bound(blockTime, defaultAuctionTime, type(uint40).max / 2 - defaultAuctionTime));
        cooldownTime = uint32(bound(cooldownTime, defaultAuctionTime, blockTime));

        vm.prank(from);
        vm.warp(blockTime);
        sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            cooldownTime,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );

        vm.prank(processor);
        vm.warp(blockTime + cooldownTime);
        sub2.processPayment(0, processor);
    }

    function test_ProcessPaymentTimesAreCorrect() public {
        vm.prank(from);
        vm.warp(1641070800);
        sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );

        vm.prank(processor);
        vm.warp(1641070800 + defaultCooldown + 10);
        sub2.processPayment(0, processor);

        (,,,,,, uint256 lastPayment,,,,) = sub2.subscriptions(0);
        assertEq(lastPayment, 1641070800 + defaultCooldown, "lastPayment incorrect");
    }

    function testFail_ProcessNonExistentSubscription() public {
        vm.prank(processor);
        sub2.processPayment(0, processor);
    }

    function test_CancelSubscriptionUser() public {
        vm.prank(from);
        vm.warp(1641070800);
        sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            0,
            defaultTerms,
            defaultIndex
        );

        vm.prank(from);
        snapStart("cancelSubscription");
        sub2.cancelSubscription(0);
        snapEnd();
    }

    function test_CancelSubscriptionRecipient() public {
        vm.prank(from);
        vm.warp(1641070800);
        sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );

        vm.prank(recipient);
        sub2.cancelSubscription(0);
    }

    function test_CancelSubscriptionOther(address _addressCancelling) public {
        vm.assume(_addressCancelling != from);
        vm.assume(_addressCancelling != recipient);

        vm.prank(from);
        vm.warp(1641070800);
        sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );

        vm.prank(_addressCancelling);
        vm.expectRevert(abi.encodeWithSelector(ISub2.NotSenderOrRecipient.selector));
        sub2.cancelSubscription(0);
    }

    function test_ProcessCanceledSubscription() public {
        vm.prank(from);
        vm.warp(1641070800);
        sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );

        vm.prank(from);
        sub2.cancelSubscription(0);

        vm.prank(processor);
        vm.expectRevert(abi.encodeWithSelector(ISub2.SubscriptionIsCanceled.selector));
        sub2.processPayment(0, processor);
    }

    function test_ProcessExpiredSubscription() public {
        vm.prank(from);
        vm.warp(1641070800);
        sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );

        vm.prank(processor);
        vm.warp(1641070800 + defaultCooldown + defaultAuctionTime + 1);
        vm.expectRevert(abi.encodeWithSelector(ISub2.AuctionExpired.selector));
        sub2.processPayment(0, processor);
    }

    function testFail_NotEnoughBalance() public {
        uint256 startBalanceFrom = token0.balanceOf(from);
        vm.prank(from);
        vm.warp(1641070800);
        sub2.createSubscription(
            recipient,
            startBalanceFrom,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );

        vm.prank(from);
        sub2.processPayment(0, processor);
    }

    function test_ProcessingFeeChangeSameOutputAmount(uint256 oldFee, uint256 newFee, uint40 blockTime) public {
        uint256 startBalanceFrom = token0.balanceOf(from);
        blockTime = uint40(bound(blockTime, defaultCooldown, type(uint40).max - defaultAuctionTime - defaultCooldown));
        vm.assume(oldFee < startBalanceFrom / 4);
        vm.assume(newFee < startBalanceFrom / 4);

        vm.warp(blockTime);
        vm.prank(from);
        sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            0,
            defaultIndex
        );

        uint256 startBalanceTo = token0.balanceOf(recipient);

        vm.prank(processor);
        sub2.processPayment(0, processor);

        uint256 startBalanceToSecond = token0.balanceOf(recipient);
        uint256 toBalanceDifferenceFirst = startBalanceToSecond - startBalanceTo;

        vm.warp(blockTime + defaultCooldown + defaultAuctionTime);
        vm.prank(from);
        sub2.updateMaxProcessingFee(0, newFee, defaultProcessingFeeToken);

        vm.prank(processor);
        sub2.processPayment(0, processor);

        uint256 toBalanceDifferenceSecond = token0.balanceOf(recipient) - startBalanceToSecond;

        assertEq(toBalanceDifferenceFirst, toBalanceDifferenceSecond, "to balance differences differ");
    }

    function test_MaxFeeCeilingUponProcessing(uint32 waitTime, uint40 blockTime) public {
        waitTime = uint32(bound(waitTime, 0, defaultAuctionTime));
        blockTime = uint40(bound(blockTime, defaultCooldown, type(uint40).max - defaultAuctionTime - defaultCooldown));

        uint256 treasuryFee = sub2.calculateFee(defaultAmount, sub2.treasuryFeeBasisPoints());

        vm.warp(blockTime);
        vm.prank(from);
        snapStart("createSubscription");
        sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );
        snapEnd();

        assertEq(token0.balanceOf(processor), 0, "processor balance not 0");
        assertEq(token0.balanceOf(treasury), treasuryFee, "treasury balance too much");

        vm.warp(blockTime + defaultCooldown + waitTime);
        vm.prank(processor);
        snapStart("processPaymentFirst");
        (uint256 processingFee,) = sub2.processPayment(0, processor);
        snapEnd();

        assertGe(defaultProcessingFee, processingFee, "processing fee larger than max");
    }

    function test_CreateSubscriptionWithoutFirstPayment() public {
        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(recipient);

        vm.prank(from);
        vm.warp(1641070800);
        sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            0,
            defaultIndex
        );

        (address sender,,,,,,,,,,) = sub2.subscriptions(0);
        assertEq(sender, from);
        assertEq(token0.balanceOf(from), startBalanceFrom);
        assertEq(token0.balanceOf(recipient), startBalanceTo);
    }

    function test_ReuseSubscriptionIndex() public {
        vm.prank(from);
        vm.warp(1641070800);
        uint256 subIndex = sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );

        vm.prank(from);
        sub2.cancelSubscription(subIndex);

        vm.prank(address2);
        snapStart("createSubscriptionReusingIndex");
        sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            0,
            subIndex
        );
        snapEnd();

        (address sender,,,,,,,,,,) = sub2.subscriptions(subIndex);
        assertEq(sender, address2);
    }

    function test_ReuseNotCanceledSubscriptionIndex() public {
        vm.prank(from);
        vm.warp(1641070800);
        uint256 subIndex = sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );

        vm.expectRevert(abi.encodeWithSelector(ISub2.SubscriptionAlreadyExists.selector));
        vm.prank(address2);
        sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            subIndex
        );
    }

    function test_CancelExpiredSubscription(address cancelling) public {
        vm.prank(from);
        vm.warp(1641070800);
        uint256 subIndex = sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );

        vm.warp(1641070800 + defaultCooldown + defaultAuctionTime + 1);
        vm.prank(cancelling);
        sub2.cancelExpiredSubscription(subIndex);
    }

    function test_SponsorTest() public {
        ISub2.SponsorPermit memory sponsorPermit = ISub2.SponsorPermit({
            nonce: 0,
            deadline: UINT256_MAX,
            recipient: recipient,
            amount: defaultAmount,
            token: address(token0),
            cooldown: defaultCooldown,
            delay: 0,
            initialPayments: 1,
            maxProcessingFee: defaultProcessingFee,
            processingFeeToken: defaultProcessingFeeToken,
            auctionDuration: defaultAuctionTime
        });

        bytes memory sig = getSponsorPermitSignature(sponsorPermit, sponsorPrivateKey, sub2.DOMAIN_SEPARATOR());

        vm.prank(from);
        vm.warp(1641070800);
        sub2.createSubscriptionWithSponsor(sponsorPermit, sponsor, sig, UINT256_MAX);
    }

    function test_UpdateMaxProcessingFee() public {
        vm.prank(from);
        vm.warp(1641070800);
        uint256 subIndex = sub2.createSubscription(
            recipient,
            defaultAmount,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );

        vm.prank(from);
        snapStart("updateMaxProcessingFee");
        sub2.updateMaxProcessingFee(subIndex, defaultProcessingFee * 2, address(token1));
        snapEnd();
    }
}
