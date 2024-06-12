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
}
