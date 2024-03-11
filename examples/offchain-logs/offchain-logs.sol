// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "suave-std/Suapp.sol";

contract OffchainLogs is Suapp {
    event OnchainEvent(uint256 num);
    event OffchainEvent(uint256 num);

    function emitCallbackWithLogs(uint256 num) public emitOffchainLogs {
        emit OnchainEvent(num);
    }

    function example() external returns (bytes memory) {
        emit OffchainEvent(101);

        return bytes.concat(this.emitCallbackWithLogs.selector, abi.encode(101));
    }

    /* This function pair do not leak the events in the onchain transaction */

    function emitCallbackWithoutLogs(uint256 num) public {
        // this callback **does not** emit logs
        emit OnchainEvent(num);
    }

    function exampleNoLogs() external returns (bytes memory) {
        emit OffchainEvent(101);

        return bytes.concat(this.emitCallbackWithoutLogs.selector, abi.encode(101));
    }
}
