// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "forge-std/Test.sol";

contract Connector is Test {
    function forgeIt(bytes memory addr, bytes memory data) internal returns (bytes memory) {
        string memory root = vm.projectRoot();
        string memory foundryToml = string.concat(root, "/", "foundry.toml");

        string memory addrHex = iToHex(addr);
        string memory dataHex = iToHex(data);

        string[] memory inputs = new string[](7);
        inputs[0] = "suave-geth";
        inputs[1] = "forge";
        inputs[2] = "--local";
        inputs[3] = "--config";
        inputs[4] = foundryToml;
        inputs[5] = addrHex;
        inputs[6] = dataHex;

        bytes memory res = vm.ffi(inputs);
        return res;
    }

    function iToHex(bytes memory buffer) public pure returns (string memory) {
        bytes memory converted = new bytes(buffer.length * 2);

        bytes memory _base = "0123456789abcdef";

        for (uint256 i = 0; i < buffer.length; i++) {
            converted[i * 2] = _base[uint8(buffer[i]) / _base.length];
            converted[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
        }

        return string(abi.encodePacked("0x", converted));
    }

    fallback() external {
        bytes memory msgdata = forgeIt(abi.encodePacked(address(this)), msg.data);

        assembly {
            let location := msgdata
            let length := mload(msgdata)
            return(add(location, 0x20), length)
        }
    }
}
