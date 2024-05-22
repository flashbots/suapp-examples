// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "suave-std/suavelib/Suave.sol";

// This could be added to suave-std so that all SUAPPs can use it.
abstract contract TxSender {
    event SentTransactions(bytes32[] txHashes);
}

contract Suapp is TxSender {
    modifier confidential() {
        require(Suave.isConfidential(), "must be called confidentially");
        _;
    }

    function didSomethingWithTxs(bytes32[] memory txHashes) public confidential {
        emit SentTransactions(txHashes);
    }

    function doSomethingWithTxs() public confidential returns (bytes memory) {
        // pretend these are tx hashes that we're handling in our SUAPP
        bytes32[] memory txHashes = new bytes32[](3);
        for (uint256 i = 0; i < txHashes.length; i++) {
            txHashes[i] = keccak256(abi.encode("tx", i));
        }
        return abi.encodeWithSelector(this.didSomethingWithTxs.selector, txHashes);
    }
}
