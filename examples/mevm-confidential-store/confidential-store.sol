// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "../../suave-geth/suave/sol/libraries/Suave.sol";

contract ConfidentialStore {
    function callback() external payable {}

    function example(address[] memory allowedList) external payable returns (bytes memory) {
        Suave.Bid memory bid = Suave.newBid(
            10,
            allowedList,
            allowedList,
            "namespace"
        );

        Suave.confidentialStore(bid.id, "key1", abi.encode(1));
        Suave.confidentialStore(bid.id, "key2", abi.encode(2));

        bytes memory value = Suave.confidentialRetrieve(bid.id, "key1");
        require(keccak256(value) == keccak256(abi.encode(1)));

        Suave.Bid[] memory allShareMatchBids = Suave.fetchBids(10, "namespace");
        return abi.encodeWithSelector(this.callback.selector);
    }
}
