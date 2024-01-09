// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "suave-std/Test.sol";
import "forge-std/Script.sol";

contract Forge is Script, SuaveEnabled {
    address[] public addressList = [0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829];

    function run() public {
        Suave.DataRecord memory bid = Suave.newDataRecord(0, addressList, addressList, "namespace");
    }
}
