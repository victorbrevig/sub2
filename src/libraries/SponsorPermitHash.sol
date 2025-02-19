// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ISub2} from "../interfaces/ISub2.sol";

library SponsorPermitHash {
    bytes32 public constant _SPONSOR_PERMIT_TYPEHASH = keccak256(
        "SponsorPermit(uint256 nonce,uint256 deadline,address recipient,uint256 amount,address token,uint32 cooldown,uint32 delay,uint32 auctionDuration,uint16 initialPayments,uint256 maxProcessingFee,address processingFeeToken)"
    );

    function hash(ISub2.SponsorPermit memory permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                _SPONSOR_PERMIT_TYPEHASH,
                permit.nonce,
                permit.deadline,
                permit.recipient,
                permit.amount,
                permit.token,
                permit.cooldown,
                permit.delay,
                permit.auctionDuration,
                permit.initialPayments,
                permit.maxProcessingFee,
                permit.processingFeeToken
            )
        );
    }
}
