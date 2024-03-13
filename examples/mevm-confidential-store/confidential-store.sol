// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "suave-std/suavelib/Suave.sol";

contract ConfidentialStore {
    function callback() external {}

    function example() external returns (bytes memory) {
        address[] memory allowedList = new address[](1);
        allowedList[0] = address(this);

        Suave.DataRecord memory dataRecord = Suave.newDataRecord(10, allowedList, allowedList, "namespace");

        Suave.confidentialStore(dataRecord.id, "key1", abi.encode(1));
        Suave.confidentialStore(dataRecord.id, "key2", abi.encode(2));

        bytes memory value = Suave.confidentialRetrieve(dataRecord.id, "key1");
        require(keccak256(value) == keccak256(abi.encode(1)));

        Suave.DataRecord[] memory allShareMatchBids = Suave.fetchDataRecords(10, "namespace");
        return abi.encodeWithSelector(this.callback.selector);
    }
}
