// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {SafeERC20, IERC20, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {SignatureVerification} from "../src/libraries/SignatureVerification.sol";
import {TokenProvider} from "./utils/TokenProvider.sol";
import {SignatureVerification} from "../src/libraries/SignatureVerification.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";
import {AddressBuilder} from "./utils/AddressBuilder.sol";
import {AmountBuilder} from "./utils/AmountBuilder.sol";
import {StructBuilder} from "./utils/StructBuilder.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {IERC20Subscription} from "../src/interfaces/IERC20Subscription.sol";
import {ERC20Subscription} from "../src/ERC20Subscription.sol";

contract ERC20SubscriptonTest is Test, PermitSignature, TokenProvider, GasSnapshot {
    using AddressBuilder for address[];
    using AmountBuilder for uint256[];

    event Transfer(address indexed from, address indexed token, address indexed to, uint256 amount);

    ERC20Subscription erc20Subscription;

    address from;
    uint256 fromPrivateKey;
    uint256 defaultAmount = 1 ** 18;

    address address0 = address(0x0);
    address address2 = address(0x2);

    bytes32 DOMAIN_SEPARATOR;

    function setUp() public {
        erc20Subscription = new ERC20Subscription();
        DOMAIN_SEPARATOR = erc20Subscription.DOMAIN_SEPARATOR();

        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

        initializeERC20Tokens();

        setERC20TestTokens(from);
        setERC20TestTokenApprovals(vm, from, address(erc20Subscription));
    }

    // tests that funds are correctly transferred from the owner to the recipient upon payment for initial payment
    function test_CollectPayment() public {
        uint256 salt = 0;
        uint256 cooldownTime = 0;
        IERC20Subscription.PermitTransferFrom memory permit =
            defaultERC20SubscriptionPermit(address(token0), address2, defaultAmount, salt, cooldownTime);
        bytes memory sig = getPermitERC20SubscriptionSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        IERC20Subscription.Subscription memory subscription =
            IERC20Subscription.Subscription({owner: from, signature: sig, permit: permit});

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address2);

        erc20Subscription.collectPayment(subscription);

        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address2), startBalanceTo + defaultAmount);
    }

    // tests that a subscription is blocked when the user has blocked it
    function testFail_BlockedSubscription() public {
        uint256 salt = 0;
        uint256 cooldownTime = 0;
        IERC20Subscription.PermitTransferFrom memory permit =
            defaultERC20SubscriptionPermit(address(token0), address2, defaultAmount, salt, cooldownTime);
        bytes memory sig = getPermitERC20SubscriptionSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        IERC20Subscription.Subscription memory subscription =
            IERC20Subscription.Subscription({owner: from, signature: sig, permit: permit});

        erc20Subscription.blockSubscription(subscription);

        erc20Subscription.collectPayment(subscription);
    }

    // tests that someone else cannot block a subscription created from another account
    function testFail_BlockOtherAccountsSubscription() public {
        uint256 salt = 0;
        uint256 cooldownTime = 0;
        IERC20Subscription.PermitTransferFrom memory permit =
            defaultERC20SubscriptionPermit(address(token0), address2, defaultAmount, salt, cooldownTime);
        bytes memory sig = getPermitERC20SubscriptionSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        IERC20Subscription.Subscription memory subscription =
            IERC20Subscription.Subscription({owner: from, signature: sig, permit: permit});

        vm.prank(address(0));
        erc20Subscription.blockSubscription(subscription);
    }

    // tests that collectPayment can be called with right transfers after cooldown has passed
    // NOT COVERING MAX UNIT256, since warp argument will overflow
    function test_CollectPaymentAfterCooldownPassed(uint256 cooldownTime) public {
        if (cooldownTime == UINT256_MAX) {
            return;
        }

        uint256 salt = 0;
        IERC20Subscription.PermitTransferFrom memory permit =
            defaultERC20SubscriptionPermit(address(token0), address2, defaultAmount, salt, cooldownTime);
        bytes memory sig = getPermitERC20SubscriptionSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        IERC20Subscription.Subscription memory subscription =
            IERC20Subscription.Subscription({owner: from, signature: sig, permit: permit});

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address2);

        vm.warp(0);
        erc20Subscription.collectPayment(subscription);

        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount);
        assertEq(token0.balanceOf(address2), startBalanceTo + defaultAmount);

        vm.warp(0 + cooldownTime + 1);
        erc20Subscription.collectPayment(subscription);

        assertEq(token0.balanceOf(from), startBalanceFrom - defaultAmount - defaultAmount);
        assertEq(token0.balanceOf(address2), startBalanceTo + defaultAmount + defaultAmount);
    }

    // tests that collecyPayment cannot be called until cooldown has passed
    // NOT COVERING 0, since warp argument will underflow
    function testFail_CollectPaymentBeforeCooldownPassed(uint256 cooldownTime) public {
        if (cooldownTime == 0) {
            revert("cooldown time is 0");
        }

        uint256 salt = 0;
        IERC20Subscription.PermitTransferFrom memory permit =
            defaultERC20SubscriptionPermit(address(token0), address2, defaultAmount, salt, cooldownTime);
        bytes memory sig = getPermitERC20SubscriptionSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        IERC20Subscription.Subscription memory subscription =
            IERC20Subscription.Subscription({owner: from, signature: sig, permit: permit});

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address2);

        vm.warp(1641070800);
        erc20Subscription.collectPayment(subscription);

        vm.warp(1641070800 + cooldownTime - 1);
        erc20Subscription.collectPayment(subscription);
    }

    // tests that collectPayment can be called immediately with cooldown time of 0
    function test_CollectPaymentImmediatelyWithZeroCooldown() public {
        uint256 salt = 0;
        uint256 cooldownTime = 0;
        IERC20Subscription.PermitTransferFrom memory permit =
            defaultERC20SubscriptionPermit(address(token0), address2, defaultAmount, salt, cooldownTime);
        bytes memory sig = getPermitERC20SubscriptionSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        IERC20Subscription.Subscription memory subscription =
            IERC20Subscription.Subscription({owner: from, signature: sig, permit: permit});

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address2);

        vm.warp(1641070800);
        erc20Subscription.collectPayment(subscription);

        vm.warp(1641070800);
        erc20Subscription.collectPayment(subscription);
    }

    // tests for overflow of cooldown time
    function testFail_CooldownOverflow() public {
        uint256 initialBlockTime = 1641070800;
        uint256 cooldownTime = UINT256_MAX - initialBlockTime + 1;
        uint256 salt = 0;
        IERC20Subscription.PermitTransferFrom memory permit =
            defaultERC20SubscriptionPermit(address(token0), address2, defaultAmount, salt, cooldownTime);
        bytes memory sig = getPermitERC20SubscriptionSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        IERC20Subscription.Subscription memory subscription =
            IERC20Subscription.Subscription({owner: from, signature: sig, permit: permit});

        uint256 startBalanceFrom = token0.balanceOf(from);
        uint256 startBalanceTo = token0.balanceOf(address2);

        vm.warp(initialBlockTime);
        erc20Subscription.collectPayment(subscription);

        // now cooldownTime + initialBlockTime will overlow uint256 by 1 and next call should fail with arithmetic error
        erc20Subscription.collectPayment(subscription);
    }
}
