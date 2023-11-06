// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "../../suave-geth/suave/sol/libraries/Suave.sol";

contract ConfidentialStore {
    address[] public addressList = [0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829];

    function example() external payable {
        Suave.Bid memory bid = Suave.newBid(
            10,
            addressList,
            addressList,
            "namespace"
        );

        Suave.confidentialStore(bid.id, "key1", abi.encode(1));
        Suave.confidentialStore(bid.id, "key2", abi.encode(2));

        Suave.Bid[] memory allShareMatchBids = Suave.fetchBids(10, "namespace");
        // allShareMatchBids[0] == bid
    }
}
