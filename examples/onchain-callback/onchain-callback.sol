// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "suave-std/suavelib/Suave.sol";

contract OnChainCallback {
    event CallbackEvent(uint256 num);

    function emitCallback(uint256 num) public {
        emit CallbackEvent(num);
    }

    function example() external returns (bytes memory) {
        return bytes.concat(this.emitCallback.selector, abi.encode(1));
    }
}
