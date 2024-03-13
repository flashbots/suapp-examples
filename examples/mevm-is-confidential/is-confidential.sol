// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "suave-std/suavelib/Suave.sol";

contract IsConfidential {
    function callback() external {}

    function example() external returns (bytes memory) {
        require(Suave.isConfidential());

        return abi.encodeWithSelector(this.callback.selector);
    }
}
