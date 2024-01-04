// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "suave-std/suavelib/Suave.sol";

contract ConfidentialStore {
    function callback() external payable {}

    function example() external payable returns (bytes memory) {
        address[] memory allowedList = new address[](1);
        allowedList[0] = address(this);

        Suave.DataRecord memory bid = Suave.newDataRecord(10, allowedList, allowedList, "namespace");

        Suave.confidentialStore(bid.id, "key1", abi.encode(1));
        Suave.confidentialStore(bid.id, "key2", abi.encode(2));

        bytes memory value = Suave.confidentialRetrieve(bid.id, "key1");
        require(keccak256(value) == keccak256(abi.encode(1)));

        Suave.DataRecord[] memory allShareMatchBids = Suave.fetchDataRecords(10, "namespace");
        return abi.encodeWithSelector(this.callback.selector);
    }
}
