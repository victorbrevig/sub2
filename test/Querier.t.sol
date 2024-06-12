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
import {IBatchProcessor} from "../src/interfaces/IBatchProcessor.sol";
import {BatchProcessor} from "../src/BatchProcessor.sol";
import {ERC20Token} from "../src/ERC20Token.sol";
import {IQuerier} from "../src/interfaces/IQuerier.sol";
import {Querier} from "../src/Querier.sol";

contract QuerierTest is Test, TokenProvider, GasSnapshot {
    using AddressBuilder for address[];
    using AmountBuilder for uint256[];

    event Transfer(address indexed from, address indexed token, address indexed to, uint256 amount);

    Sub2 erc20Subscription;
    Querier querier;

    address sender0;
    uint256 sender0PrivateKey;
    address sender1;
    uint256 sender1PrivateKey;

    uint256 defaultAmount = 10 * 1e6;

    address address0 = address(0x0);
    address address2 = address(0x2);
    address address3 = address(0x3);

    address recipient0 = address(0x1);
    address recipient1 = address(0x6);

    address feeRecipient = address3;

    address treasury = address(0x4);

    address processor = address(0x5);

    uint16 treasuryFeeBasisPoints = 2000;

    uint256 defaultProcessingFee = 10 * 1e5;

    uint256 defaultCooldown = 1800;
    uint256 defaultAuctionTime = 1800;

    uint256 defaultDelay = 0;
    uint256 defaultTerms = 1;

    address defaultProcessingFeeToken;

    uint256 defaultIndex = type(uint256).max;

    function setUp() public {
        sender0PrivateKey = 0x12341234;
        sender0 = vm.addr(sender0PrivateKey);
        sender1PrivateKey = 0x43214321;
        sender1 = vm.addr(sender1PrivateKey);

        erc20Subscription = new Sub2(treasury, treasuryFeeBasisPoints, address2);

        initializeERC20Tokens();

        setERC20TestTokens(sender0);
        setERC20TestTokenApprovals(vm, sender0, address(erc20Subscription));
        setERC20TestTokens(sender1);
        setERC20TestTokenApprovals(vm, sender1, address(erc20Subscription));

        defaultProcessingFeeToken = address(token0);

        querier = new Querier(erc20Subscription);
    }

    function test_GetSubscriptionsSender() public {
        vm.prank(sender0);
        vm.warp(1641070800);
        erc20Subscription.createSubscription(
            recipient0,
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

        vm.prank(sender1);
        vm.warp(1641070800);
        erc20Subscription.createSubscription(
            recipient0,
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

        ISub2.IndexedSubscription[] memory indexedSubs = querier.getSubscriptionsSender(sender0);

        assertEq(indexedSubs.length, 1, "Incorrect number of subscriptions for sender");
    }

    function test_GetSubscriptionsRecipient() public {
        vm.prank(sender0);
        vm.warp(1641070800);
        erc20Subscription.createSubscription(
            recipient0,
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

        vm.prank(sender1);
        vm.warp(1641070800);
        erc20Subscription.createSubscription(
            recipient1,
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

        ISub2.IndexedSubscription[] memory indexedSubs = querier.getSubscriptionsRecipient(recipient0);

        assertEq(indexedSubs.length, 1, "Incorrect number of subscriptions for recipient");
    }

    function test_GetSubscriptions() public {
        vm.warp(1641070800);
        vm.prank(sender0);
        erc20Subscription.createSubscription(
            recipient0,
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

        vm.prank(sender1);
        erc20Subscription.createSubscription(
            address2,
            defaultAmount * 2,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );

        vm.prank(sender1);
        erc20Subscription.createSubscription(
            recipient1,
            defaultAmount * 3,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );

        uint256[] memory subscriptionIndices = new uint256[](2);
        subscriptionIndices[0] = 0;
        subscriptionIndices[1] = 2;

        ISub2.Subscription[] memory subs = querier.getSubscriptions(subscriptionIndices);

        assertEq(subs.length, 2, "Incorrect number of subscriptions");
        assertEq(subs[0].recipient, recipient0, "Incorrect recipient first subscription");
        assertEq(subs[1].recipient, recipient1, "Incorrect recipient second subscription");
        assertEq(subs[1].amount, defaultAmount * 3, "Incorrect amount second subscription");
    }

    function testFail_GetSubscriptionsIndexOutOfRange() public {
        vm.warp(1641070800);
        vm.prank(sender0);
        erc20Subscription.createSubscription(
            recipient0,
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

        vm.prank(sender1);
        erc20Subscription.createSubscription(
            address2,
            defaultAmount * 2,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );

        vm.prank(sender1);
        erc20Subscription.createSubscription(
            recipient1,
            defaultAmount * 3,
            address(token0),
            defaultCooldown,
            defaultProcessingFee,
            defaultProcessingFeeToken,
            defaultAuctionTime,
            defaultDelay,
            defaultTerms,
            defaultIndex
        );

        uint256[] memory subscriptionIndices = new uint256[](2);
        subscriptionIndices[0] = 0;
        subscriptionIndices[1] = 3;

        ISub2.Subscription[] memory subs = querier.getSubscriptions(subscriptionIndices);
    }
}
