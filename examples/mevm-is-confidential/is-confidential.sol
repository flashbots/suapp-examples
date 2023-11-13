// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "../../suave-geth/suave/sol/libraries/Suave.sol";

contract ConfidentialStore {
    function example() external payable {
        require(Suave.isConfidential());
    }
}
