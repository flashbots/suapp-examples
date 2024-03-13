// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "suave-std/Context.sol";

contract ContextExample {
    function callback() external {}

    function example() external returns (bytes memory) {
        bytes memory confInput = Context.confidentialInputs();
        require(confInput.length == 1);

        address addr = Context.kettleAddress();
        require(addr == 0xB5fEAfbDD752ad52Afb7e1bD2E40432A485bBB7F, "invalid kettle address");

        return abi.encodeWithSelector(this.callback.selector);
    }
}
