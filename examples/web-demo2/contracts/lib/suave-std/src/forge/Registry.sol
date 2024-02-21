// SPDX-License-Identifier: UNLICENSED
// DO NOT edit this file. Code generated by forge-gen.
pragma solidity ^0.8.8;

import "../suavelib/Suave.sol";
import "./Connector.sol";
import "./ContextConnector.sol";
import "./SuaveAddrs.sol";
import "./ConfidentialStore.sol";
import "./ConfidentialStoreConnector.sol";

interface registryVM {
    function etch(address, bytes calldata) external;
}

library Registry {
    registryVM constant vm = registryVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address public constant confidentialStoreAddr = 0x0101010101010101010101010101010101010101;

    function enable() public {
        // enable all suave libraries
        address[] memory addrList = SuaveAddrs.getSuaveAddrs();
        for (uint256 i = 0; i < addrList.length; i++) {
            // code for Forge proxy connector
            vm.etch(addrList[i], type(Connector).runtimeCode);
        }

        // enable the confidential store
        deployCodeTo(type(ConfidentialStore).creationCode, confidentialStoreAddr);

        // enable the confidential inputs wrapper
        vm.etch(Suave.CONFIDENTIAL_RETRIEVE, type(ConfidentialStoreConnector).runtimeCode);
        vm.etch(Suave.CONFIDENTIAL_STORE, type(ConfidentialStoreConnector).runtimeCode);
        vm.etch(Suave.NEW_DATA_RECORD, type(ConfidentialStoreConnector).runtimeCode);
        vm.etch(Suave.FETCH_DATA_RECORDS, type(ConfidentialStoreConnector).runtimeCode);

        // enable is confidential wrapper
        vm.etch(Suave.CONTEXT_GET, type(ContextConnector).runtimeCode);
    }

    function deployCodeTo(bytes memory creationCode, address where) internal {
        vm.etch(where, creationCode);
        (bool success, bytes memory runtimeBytecode) = where.call("");
        require(success, "StdCheats deployCodeTo(string,bytes,uint256,address): Failed to create runtime bytecode.");
        vm.etch(where, runtimeBytecode);
    }
}
