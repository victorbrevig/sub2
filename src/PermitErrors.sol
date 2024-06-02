// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @notice Shared errors between signature based transfers and allowance based transfers.

/// @notice Thrown when validating an inputted signature that is stale
/// @param signatureDeadline The timestamp at which a signature is no longer valid
error SignatureExpired(uint256 signatureDeadline);

/// @notice Thrown when validating that the inputted nonce has not been used
error InvalidNonce();

error InvalidRecipient(address recipient);
error InvalidAmount(uint256 amount);
error InvalidToken(address token);
error InvalidTipToken(address tipToken);
error InvalidCooldown(uint256 cooldown);
error InvalidDelay(uint256 delay);
error InvalidTerms(uint256 terms);
error InvalidMaxTip(uint256 maxTip);
error InvalidAuctionDuration(uint256 auctionDuration);
