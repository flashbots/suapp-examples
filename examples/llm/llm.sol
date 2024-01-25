// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

// import "suave-std/suavelib/Suave.sol";

contract LLM {
    uint256 public gameFee = 0.01 ether;
    address public owner = address(this);

    constructor() {
        owner = msg.sender;
    }

    // TODO: Make this fully offchain by putting string in confidential inputs
    function submitPromptOffchain(string memory prompt) public payable returns (bytes memory) {
        require(msg.value >= gameFee, "Insufficient fee for prompt submission");

        address responseAddress = callLLM(prompt);

        return abi.encodeWithSelector(this.submitPromptOnchain.selector, responseAddress);
    }

    // WARNING : NOT SAFE
    function submitPromptOnchain(address responseAddress) public payable {
        require(msg.value >= gameFee, "Insufficient fee included");

        uint256 contractBalanceBefore = address(this).balance;
        uint256 expectedBalanceAfter = contractBalanceBefore + msg.value;

        // Add the received funds to the contract's balance
        address(this).call{value: msg.value}("");

        if (responseAddress != address(0) && msg.value > gameFee) {
            // Transfer the remaining balance (msg.value - gameFee) to the recipient
            (bool sent,) = responseAddress.call{value: msg.value - gameFee}("");
            require(sent, "Failed to send remaining balance");
        }
    }

    // WARNING : NOT SAFE
    function transferPot(address recipient) private {
        require(address(this).balance > gameFee, "Insufficient funds for transfer");
        uint256 transferAmount = address(this).balance - gameFee;
        (bool sent,) = recipient.call{value: transferAmount}("");
        require(sent, "Failed to send Ether");
    }

    // WARNING : NOT SAFE
    function callLLM(string memory prompt) public returns (address) {
        return address(0);
    }
}
