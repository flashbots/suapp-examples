// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/Test.sol";
import "solady/src/utils/LibString.sol";
import "src/protocols/EthJsonRPC.sol";

contract EthJsonRPCTest is Test, SuaveEnabled {
    function testEthJsonRPCGetNonce() public {
        EthJsonRPC ethjsonrpc = getEthJsonRPC();

        uint256 nonce = ethjsonrpc.nonce(address(this));
        assertEq(nonce, 0);
    }

    function getEthJsonRPC() public returns (EthJsonRPC ethjsonrpc) {
        try vm.envString("JSONRPC_ENDPOINT") returns (string memory endpoint) {
            ethjsonrpc = new EthJsonRPC(endpoint);
        } catch {
            vm.skip(true);
        }
    }
}
