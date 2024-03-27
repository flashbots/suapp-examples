// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "suave-std/Gateway.sol";
import "suave-std/Suapp.sol";

interface ERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract PublicSuapp is Suapp {
    function callback() external payable emitOffchainLogs {}

    event Balance(uint256 balance);

    function example(string memory jsonrpc, address erc20Token, address addr) external returns (bytes memory) {
        Gateway gateway = new Gateway(jsonrpc, erc20Token);
        ERC20 token = ERC20(address(gateway));

        uint256 balance = token.balanceOf(addr);
        emit Balance(balance);

        return abi.encodeWithSelector(this.callback.selector);
    }
}
