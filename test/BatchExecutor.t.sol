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

contract ERC20SubscriptonTest is Test, PermitSignature, TokenProvider, GasSnapshot {
    using AddressBuilder for address[];
    using AmountBuilder for uint256[];

    event Transfer(address indexed from, address indexed token, address indexed to, uint256 amount);

    ERC20Subscription erc20Subscription;
    BatchExecutor batchExecutor;

    address from;
    uint256 fromPrivateKey;
    uint256 defaultAmount = 10 * 1e6;

    address treasury;
    uint256 treasuryPrivateKey;

    uint256 rewardFactor = 1;

    address address0 = address(0x0);
    address address2 = address(0x2);
    address address3 = address(0x3);

    address feeRecipient = address3;
    uint16 feeBasisPoints = 3000;

    bytes32 DOMAIN_SEPARATOR;

    function setUp() public {
        erc20Subscription = new ERC20Subscription(feeRecipient, feeBasisPoints);
        DOMAIN_SEPARATOR = erc20Subscription.DOMAIN_SEPARATOR();

        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

        treasuryPrivateKey = 0x43214321;
        treasury = vm.addr(treasuryPrivateKey);

        initializeERC20Tokens();

        setERC20TestTokens(from);
        setERC20TestTokens(treasury);
        setERC20TestTokenApprovals(vm, from, address(erc20Subscription));

        batchExecutor = new BatchExecutor(erc20Subscription, address(token1), rewardFactor, treasury);
        setERC20TestTokenApprovals(vm, treasury, address(batchExecutor));
    }

    function test_CorrectClaimableAmountAfterSuccessfulExecution() public {
        uint256 salt = 0;
        uint256 cooldownTime = 0;
        IERC20Subscription.PermitTransferFrom memory permit =
            defaultERC20SubscriptionPermit(address(token0), address2, defaultAmount, salt, cooldownTime);
        bytes memory sig = getPermitERC20SubscriptionSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        IERC20Subscription.Subscription[] memory subscriptions = new IERC20Subscription.Subscription[](1);
        subscriptions[0] = IERC20Subscription.Subscription({owner: from, signature: sig, permit: permit});

        vm.prank(from);
        batchExecutor.executeBatch(subscriptions);

        uint256 startBalanceFrom = token1.balanceOf(from);
        uint256 startBalanceTreasury = token1.balanceOf(treasury);

        vm.prank(from);
        batchExecutor.claimRewards();

        assertEq(token1.balanceOf(from), startBalanceFrom + rewardFactor);
        assertEq(token1.balanceOf(treasury), startBalanceTreasury - rewardFactor);
    }
}
