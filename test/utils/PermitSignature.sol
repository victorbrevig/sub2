// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Vm} from "forge-std/Vm.sol";
import {ISub2} from "../../src/interfaces/ISub2.sol";

contract PermitSignature {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 public constant _SPONSOR_PERMIT_TYPEHASH = keccak256(
        "SponsorPermit(uint256 nonce,uint256 deadline,address recipient,uint256 amount,address token,uint256 cooldown,uint256 delay,uint256 initialTerms,uint256 maxProcessingFee,address processingFeeToken,uint256 auctionDuration)"
    );

    function getSponsorPermitSignature(ISub2.SponsorPermit memory permit, uint256 privateKey, bytes32 domainSeparator)
        internal
        view
        returns (bytes memory sig)
    {
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        _SPONSOR_PERMIT_TYPEHASH,
                        permit.nonce,
                        permit.deadline,
                        permit.recipient,
                        permit.amount,
                        permit.token,
                        permit.cooldown,
                        permit.delay,
                        permit.initialTerms,
                        permit.maxProcessingFee,
                        permit.processingFeeToken,
                        permit.auctionDuration
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }
}
