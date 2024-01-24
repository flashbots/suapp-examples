// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "forge-std/Test.sol";
import "../LLM.sol";

contract LLMTest is Test {
    LLM llm;
    address internal owner;

    function setUp() public {
        owner = address(this); // Setting the test contract as the owner for testing
        llm = new LLM();
        vm.deal(address(llm), 1 ether); // Fund the contract with enough ether
    }

    function testOwnerInitialization() public {
        assertEq(llm.owner(), owner, "Owner should be initialized correctly");
    }

    function testGameFeeInitialization() public {
        uint256 expectedFee = 0.01 ether;
        assertEq(llm.gameFee(), expectedFee, "Game fee should be initialized to 0.01 ETH");
    }

    function testSubmitPromptWithInsufficientFeeOffchain() public {
        string memory prompt = "Test prompt";
        uint256 sentValue = 0.005 ether; // Less than the required fee

        vm.expectRevert("Insufficient fee for prompt submission");
        llm.submitPromptOffchain{value: sentValue}(prompt);
    }

    function testTransferPotFunctionality() public {
        address recipient = address(0x1);
        uint256 amountToRecipient = 1 ether;
        uint256 totalSentValue = amountToRecipient + llm.gameFee();

        uint256 initialRecipientBalance = recipient.balance;
        uint256 initialOwnerBalance = owner.balance;
        uint256 initialContractBalance = address(llm).balance;

        console.log("Initial Contract Balance:", initialContractBalance);
        console.log("Total Sent Value:", totalSentValue);

        // Call the function that triggers transferPot, sending the total sent value
        llm.submitPromptOnchain{value: totalSentValue}(recipient);

        uint256 finalContractBalance = address(llm).balance;
        uint256 finalOwnerBalance = owner.balance;
        uint256 finalRecipientBalance = recipient.balance;

        console.log("Final Contract Balance:", finalContractBalance);
        console.log("Final Owner Balance:", finalOwnerBalance);
        console.log("Final Recipient Balance:", finalRecipientBalance);

        assertEq(
            recipient.balance,
            initialRecipientBalance + amountToRecipient,
            "Recipient should receive the correct amount"
        );
    }
}
