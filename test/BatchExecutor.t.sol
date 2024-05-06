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
import {IBatchExecutor} from "../src/interfaces/IBatchExecutor.sol";
import {BatchExecutor} from "../src/BatchExecutor.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

contract ERC20SubscriptonTest is Test, PermitSignature, TokenProvider, GasSnapshot {
    using AddressBuilder for address[];
    using AmountBuilder for uint256[];

    event Transfer(address indexed from, address indexed token, address indexed to, uint256 amount);

    ERC20Subscription erc20Subscription;
    BatchExecutor batchExecutor;
    ERC20Token rewardToken;

    address from;
    uint256 fromPrivateKey;
    uint256 defaultAmount = 10 * 1e6;

    address auth;
    uint256 authPrivateKey;

    uint256 rewardFactor = 1;

    address address0 = address(0x0);
    address address2 = address(0x2);
    address address3 = address(0x3);

    address feeRecipient = address3;
    uint16 feeBasisPoints = 3000;

    bytes32 DOMAIN_SEPARATOR;

    function setUp() public {
        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

        authPrivateKey = 0x12345678;
        auth = vm.addr(authPrivateKey);

        erc20Subscription = new ERC20Subscription(feeRecipient, feeBasisPoints, auth, address0);
        DOMAIN_SEPARATOR = erc20Subscription.DOMAIN_SEPARATOR();

        initializeERC20Tokens();

        setERC20TestTokens(from);
        setERC20TestTokenApprovals(vm, from, address(erc20Subscription));

        batchExecutor = new BatchExecutor(erc20Subscription, rewardFactor, address0);
        rewardToken = new ERC20Token("RewardToken", "REW", 18, address(batchExecutor));
        vm.prank(address(0));
        batchExecutor.setRewardTokenAddress(address(rewardToken));
    }

    function test_CorrectClaimableAmountAfterSuccessfulExecution() public {
        uint256 salt = 0;
        uint256 cooldownTime = 0;
        IERC20Subscription.PermitTransferFrom memory permit =
            defaultERC20SubscriptionPermit(address(token0), address2, defaultAmount, salt, cooldownTime);
        bytes memory sig = getPermitERC20SubscriptionSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);
        bytes memory authSig = getAuthSignature(sig, authPrivateKey);
        IERC20Subscription.Subscription[] memory subscriptions = new IERC20Subscription.Subscription[](1);
        subscriptions[0] =
            IERC20Subscription.Subscription({owner: from, signature: sig, permit: permit, authSignature: authSig});

        vm.prank(from);
        batchExecutor.executeBatch(subscriptions);

        uint256 startBalanceFrom = rewardToken.balanceOf(from);

        vm.prank(from);
        batchExecutor.claimRewards();

        assertEq(rewardToken.balanceOf(from), startBalanceFrom + rewardFactor);
    }

    // tests that a failed  collectPayment will not increase the claimable rewards
    function test_FailedCollectPayment() public {
        uint256 salt = 0;
        uint256 cooldownTime = 0;
        // collectPayment with this subscription should fail
        uint256 amountToTransfer = token0.balanceOf(from) + 1;
        IERC20Subscription.PermitTransferFrom memory permit =
            defaultERC20SubscriptionPermit(address(token0), address2, amountToTransfer, salt, cooldownTime);
        bytes memory sig = getPermitERC20SubscriptionSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);
        bytes memory authSig = getAuthSignature(sig, authPrivateKey);
        IERC20Subscription.Subscription[] memory subscriptions = new IERC20Subscription.Subscription[](1);
        subscriptions[0] =
            IERC20Subscription.Subscription({owner: from, signature: sig, permit: permit, authSignature: authSig});

        vm.prank(from);
        batchExecutor.executeBatch(subscriptions);

        uint256 startBalanceFrom = rewardToken.balanceOf(from);

        vm.prank(from);
        batchExecutor.claimRewards();

        assertEq(rewardToken.balanceOf(from), startBalanceFrom);
    }

    function testFail_SetRewardTokenAfterItsSet() public {
        BatchExecutor batchExecutor2 = new BatchExecutor(erc20Subscription, rewardFactor, address0);
        ERC20Token rewardToken2 = new ERC20Token("RewardToken", "REW", 18, address(batchExecutor2));
        vm.prank(address(0));
        batchExecutor2.setRewardTokenAddress(address(rewardToken2));
        vm.prank(address(0));
        batchExecutor2.setRewardTokenAddress(address(0));
    }

    function testFail_CannotClaimUntilRewardTokenSet() public {
        BatchExecutor batchExecutor2 = new BatchExecutor(erc20Subscription, rewardFactor, address0);

        uint256 salt = 0;
        uint256 cooldownTime = 0;
        IERC20Subscription.PermitTransferFrom memory permit =
            defaultERC20SubscriptionPermit(address(token0), address2, defaultAmount, salt, cooldownTime);
        bytes memory sig = getPermitERC20SubscriptionSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);
        bytes memory authSig = getAuthSignature(sig, authPrivateKey);
        IERC20Subscription.Subscription[] memory subscriptions = new IERC20Subscription.Subscription[](1);
        subscriptions[0] =
            IERC20Subscription.Subscription({owner: from, signature: sig, permit: permit, authSignature: authSig});

        vm.prank(from);
        batchExecutor2.executeBatch(subscriptions);

        vm.prank(from);
        batchExecutor2.claimRewards();
    }
}
