// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "suave-std/suavelib/Suave.sol";

contract OnChainCallback {
    event CallbackEvent(uint256 num);

    event NilEvent();

    function emitCallback(uint256 num) public {
        emit CallbackEvent(num);
    }

    function example() external returns (bytes memory) {
        // event emitted in the off-chain confidential context, no effect.
        emit NilEvent();

        return bytes.concat(this.emitCallback.selector, abi.encode(1));
    }
}
