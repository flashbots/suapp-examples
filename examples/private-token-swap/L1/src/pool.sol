// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

contract Pool {
    event Swap(address from, address to, uint256 amount, uint256 resultAmount);

    function swap(address from, address to, uint256 amount) external returns (uint256) {
        // some swap logic
        emit Swap(from, to, amount, amount * 2);
        return amount * 2;
    }
}
