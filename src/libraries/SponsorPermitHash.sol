// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ISub2} from "../interfaces/ISub2.sol";

library SponsorPermitHash {
    bytes32 public constant _SPONSOR_PERMIT_TYPEHASH = keccak256(
        "SponsorPermit(uint256 nonce,uint256 deadline,address recipient,address token,uint256 cooldown,uint256 delay,uint256 terms,uint256 maxTip,address tipToken,uint256 auctionDuration)"
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
                permit.terms,
                permit.maxTip,
                permit.tipToken,
                permit.auctionDuration
            )
        );
    }
}
