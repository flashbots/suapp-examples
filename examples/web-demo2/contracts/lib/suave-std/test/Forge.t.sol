// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/Test.sol";
import "src/suavelib/Suave.sol";
import "src/Context.sol";

contract TestForge is Test, SuaveEnabled {
    address[] public addressList = [0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829];

    function testForgeConfidentialStoreFetch() public {
        Suave.newDataRecord(0, addressList, addressList, "namespace");

        Suave.DataRecord[] memory records = Suave.fetchDataRecords(0, "namespace");
        assertEq(records.length, 1);

        Suave.newDataRecord(0, addressList, addressList, "namespace");
        Suave.newDataRecord(0, addressList, addressList, "namespace");

        Suave.DataRecord[] memory records2 = Suave.fetchDataRecords(0, "namespace");
        assertEq(records2.length, 3);

        resetConfidentialStore();

        Suave.DataRecord[] memory records3 = Suave.fetchDataRecords(0, "namespace");
        assertEq(records3.length, 0);
    }

    function testForgeConfidentialStoreRecordStore() public {
        Suave.DataRecord memory record = Suave.newDataRecord(0, addressList, addressList, "namespace");

        bytes memory value = abi.encode("suave works with forge!");
        Suave.confidentialStore(record.id, "key1", value);

        bytes memory found = Suave.confidentialRetrieve(record.id, "key1");
        assertEq(keccak256(found), keccak256(value));
    }

    function testForgeContextConfidentialInputs() public {
        bytes memory found1 = Context.confidentialInputs();
        assertEq(found1.length, 0);

        bytes memory input = hex"abcd";
        ctx.setConfidentialInputs(input);

        bytes memory found2 = Context.confidentialInputs();
        assertEq0(input, found2);

        ctx.resetConfidentialInputs();

        bytes memory found3 = Context.confidentialInputs();
        assertEq(found3.length, 0);
    }

    function testForgeContextKettleAddress() public {
        address found1 = Context.kettleAddress();
        assertEq(found1, address(0));

        ctx.setKettleAddress(address(this));

        address found2 = Context.kettleAddress();
        assertEq(found2, address(this));

        ctx.resetKettleAddress();

        address found3 = Context.kettleAddress();
        assertEq(found3, address(0));
    }
}
