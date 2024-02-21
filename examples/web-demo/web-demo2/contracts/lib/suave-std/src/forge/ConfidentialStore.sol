// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "../suavelib/Suave.sol";
import "forge-std/Test.sol";

// ConfidentialStore is an implementation of the confidential store in Solidity.
contract ConfidentialStore is Test {
    mapping(bytes32 => Suave.DataRecord[]) private dataRecordsByConditionAndNamespace;
    mapping(Suave.DataId => mapping(string => bytes)) private dataRecordsContent;
    mapping(Suave.DataId => Suave.DataRecord) private dataRecords;

    uint64 private numRecords;

    type DataId is bytes16;

    constructor() {
        vm.record();
    }

    function newDataRecord(
        uint64 decryptionCondition,
        address[] memory allowedPeekers,
        address[] memory allowedStores,
        string memory dataType
    ) public returns (Suave.DataRecord memory) {
        numRecords++;

        // Use a counter of the records to create a unique key
        Suave.DataId id = Suave.DataId.wrap(bytes16(keccak256(abi.encodePacked(numRecords))));
        numRecords++;

        Suave.DataRecord memory newRecord;
        newRecord.id = id;
        newRecord.decryptionCondition = decryptionCondition;
        newRecord.allowedPeekers = allowedPeekers;
        newRecord.allowedStores = allowedStores;
        newRecord.version = dataType;

        // Store the data record metadata
        dataRecords[id] = newRecord;

        // Use a composite index to store the records for the 'fetchDataRecords' function
        bytes32 key = keccak256(abi.encodePacked(decryptionCondition, dataType));
        dataRecordsByConditionAndNamespace[key].push(newRecord);

        return newRecord;
    }

    function fetchDataRecords(uint64 cond, string memory namespace) public view returns (Suave.DataRecord[] memory) {
        bytes32 key = keccak256(abi.encodePacked(cond, namespace));
        return dataRecordsByConditionAndNamespace[key];
    }

    function confidentialStore(Suave.DataId dataId, string memory key, bytes memory value) public {
        address[] memory allowedStores = dataRecords[dataId].allowedStores;
        for (uint256 i = 0; i < allowedStores.length; i++) {
            if (allowedStores[i] == msg.sender || allowedStores[i] == Suave.ANYALLOWED) {
                dataRecordsContent[dataId][key] = value;
                return;
            }
        }

        revert("Not allowed to store");
    }

    function confidentialRetrieve(Suave.DataId dataId, string memory key) public view returns (bytes memory) {
        address[] memory allowedPeekers = dataRecords[dataId].allowedPeekers;
        for (uint256 i = 0; i < allowedPeekers.length; i++) {
            if (allowedPeekers[i] == msg.sender || allowedPeekers[i] == Suave.ANYALLOWED) {
                return dataRecordsContent[dataId][key];
            }
        }

        revert("Not allowed to retrieve");
    }

    function reset() public {
        (, bytes32[] memory writes) = vm.accesses(address(this));
        for (uint256 i = 0; i < writes.length; i++) {
            vm.store(address(this), writes[i], 0);
        }
    }
}
