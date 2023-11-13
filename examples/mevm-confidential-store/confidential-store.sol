// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "../../suave-geth/suave/sol/libraries/Suave.sol";

contract ConfidentialStore {
    address[] public addressList = [0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829];

    function callback() external payable {}

    function example() external payable returns (bytes memory) {
        Suave.Bid memory bid = Suave.newBid(
            10,
            addressList,
            addressList,
            "namespace"
        );

        Suave.confidentialStore(bid.id, "key1", abi.encode(1));
        Suave.confidentialStore(bid.id, "key2", abi.encode(2));

        bytes memory value = Suave.confidentialRetrieve(bid.id, "key1");
        require(keccak256(value) == keccak256(abi.encode(1)));

        Suave.Bid[] memory allShareMatchBids = Suave.fetchBids(10, "namespace");
        require(allShareMatchBids.length > 1);

        return abi.encodeWithSelector(this.callback.selector);
    }
}
