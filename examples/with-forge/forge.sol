// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "../../suave-geth/suave/sol/libraries/SuaveForge.sol";
import "forge-std/Script.sol";

contract Forge is Script {
    address[] public addressList = [0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829];

    function example() public {
        Suave.Bid memory bid = SuaveForge.newBid(
            0,
            addressList,
            addressList,
            "namespace"
        );
    }
}
