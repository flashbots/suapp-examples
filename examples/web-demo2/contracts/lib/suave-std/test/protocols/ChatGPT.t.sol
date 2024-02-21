// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/Test.sol";
import "src/protocols/ChatGPT.sol";

contract ChatGPTTest is Test, SuaveEnabled {
    function testChatGPT() public {
        ChatGPT chatgpt = getChatGPT();

        ChatGPT.Message[] memory messages = new ChatGPT.Message[](1);
        messages[0] = ChatGPT.Message(ChatGPT.Role.User, "Say this is a test!");

        string memory expected = "This is a test!";
        string memory found = chatgpt.complete(messages);

        assertEq(found, expected, "ChatGPT did not return the expected result");
    }

    function getChatGPT() public returns (ChatGPT chatgpt) {
        // NOTE: tried to do it with envOr but it did not worked
        try vm.envString("CHATGPT_API_KEY") returns (string memory apiKey) {
            chatgpt = new ChatGPT(apiKey);
        } catch {
            vm.skip(true);
        }
    }
}
