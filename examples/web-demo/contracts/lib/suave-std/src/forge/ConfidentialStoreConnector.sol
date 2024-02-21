// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "./ConfidentialStore.sol";
import "../suavelib/Suave.sol";

contract ConfidentialStoreConnector {
    fallback() external {
        address confidentialStoreAddr = 0x0101010101010101010101010101010101010101;

        address addr = address(this);
        bytes4 sig;

        if (addr == Suave.CONFIDENTIAL_STORE) {
            sig = ConfidentialStore.confidentialStore.selector;
        } else if (addr == Suave.CONFIDENTIAL_RETRIEVE) {
            sig = ConfidentialStore.confidentialRetrieve.selector;
        } else if (addr == Suave.FETCH_DATA_RECORDS) {
            sig = ConfidentialStore.fetchDataRecords.selector;
        } else if (addr == Suave.NEW_DATA_RECORD) {
            sig = ConfidentialStore.newDataRecord.selector;
        } else {
            revert("function signature not found in the confidential store");
        }

        bytes memory input = msg.data;

        // call 'confidentialStore' with the selector and the input data.
        (bool success, bytes memory output) = confidentialStoreAddr.call(abi.encodePacked(sig, input));
        if (!success) {
            revert("Call to confidentialStore failed");
        }

        if (addr == Suave.CONFIDENTIAL_RETRIEVE) {
            // special case we have to unroll the value from the abi
            // since it comes encoded as tuple() but we return the value normally
            // this was a special case that was not fixed yet in suave-geth.
            output = abi.decode(output, (bytes));
        }

        assembly {
            let location := output
            let length := mload(output)
            return(add(location, 0x20), length)
        }
    }
}
