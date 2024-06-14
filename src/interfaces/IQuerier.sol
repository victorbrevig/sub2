// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISub2} from "./ISub2.sol";

interface IQuerier {
    /// @param _sender The sender address.
    /// @return indexedSubscriptions The indexed subscriptions with _sender as sender.
    function getSubscriptionsSender(address _sender) external view returns (ISub2.IndexedSubscription[] memory);

    /// @param _recipient The recipient address.
    /// @return indexedSubscriptions The subscriptions with _recipient as recipient.
    function getSubscriptionsRecipient(address _recipient) external view returns (ISub2.IndexedSubscription[] memory);

    /// @param _subscriptionIndices The indices of the subscriptions to get.
    /// @return subscriptions The subscriptions located in Subscriptions array at given indices in same order.
    function getSubscriptions(uint256[] calldata _subscriptionIndices)
        external
        view
        returns (ISub2.Subscription[] memory);

    /// @notice Checks if the sender is a payed subscriber of the recipient with given inputs.
    /// @dev This function runs in O(n) where n is the number of subscriptions matching the inputs not considering _minAmount.
    /// @param _sender The sender address.
    /// @param _recipient The recipient address.
    /// @param _minAmount The minimum amount of the subscription to allow.
    /// @param _token The token address of the subscription.
    /// @param _cooldown The cooldown of the subscription.
    /// @return isPayedSubscriber True if the sender is a payed subscriber of the recipient with given inputs.
    function isPayedSubscriber(
        address _sender,
        address _recipient,
        uint256 _minAmount,
        address _token,
        uint32 _cooldown
    ) external view returns (bool);
}
