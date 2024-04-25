// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/712Emitter.sol";

contract EmitterTest is Test {
    Emitter emitter;
    address internal owner;

    event NFTEEApproval(bytes signedMessage);

    function setUp() public {
        owner = address(this); // Setting the test contract as the owner for testing
        emitter = new Emitter();
    }

    function testSetPrivateKey() public {
        // Mock DataId and set private key
        bytes16 dataIDValue = bytes16(0x1234567890abcdef1234567890abcdef); // Ensure it's 16 bytes
        Suave.DataId dataID = Suave.DataId.wrap(dataIDValue);
        emitter.setPrivateKey(dataID);

        // Assertion to check if private key was set
        // Note: Requires getter for privateKeyDataID or event validation
        bytes16 expectedDataIDBytes = Suave.DataId.unwrap(dataID);
        bytes16 actualDataIDBytes = emitter.getPrivateKeyDataIDBytes();
        assertEq(actualDataIDBytes, expectedDataIDBytes, "Private key DataID should match");
    }

    function testSignL1MintApproval() public {
        // can't actually test this atm
    }

    function testEmitSignedMintApproval() public {
        bytes memory message = "test message";

        // Start recording logs
        vm.recordLogs();

        // Call the function to test
        emitter.emitSignedMintApproval(message);

        // Get the recorded logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Ensure at least one event was emitted
        assert(logs.length > 0); // This line is updated

        // Decode the event data - the structure depends on the event signature
        (bytes memory loggedMessage) = abi.decode(logs[0].data, (bytes));

        // Assertions to validate the event data
        assertEq(loggedMessage, message, "Emitted message should match the input message");
    }
}
