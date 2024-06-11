// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISub2} from "./ISub2.sol";

interface IQuerier {
    function getSubscriptionsSender(address _sender) external view returns (ISub2.IndexedSubscription[] memory);
    function getSubscriptionsRecipient(address _recipient) external view returns (ISub2.IndexedSubscription[] memory);
    function readSubscriptions(uint256[] calldata _subscriptionIndices)
        external
        view
        returns (ISub2.Subscription[] memory);
}
