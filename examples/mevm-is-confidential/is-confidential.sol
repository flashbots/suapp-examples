// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "../../suave-geth/suave/sol/libraries/Suave.sol";

contract IsConfidential {
    function callback() external payable {}

    function example() external payable returns (bytes memory) {
        require(Suave.isConfidential());

        return abi.encodeWithSelector(this.callback.selector);
    }
}
