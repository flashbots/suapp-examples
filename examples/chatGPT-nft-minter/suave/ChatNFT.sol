// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Suave} from "suave-std/suavelib/Suave.sol";
import {ChatGPT} from "suave-std/protocols/ChatGPT.sol";

/// @title ChatNFT: ChatGPT-based NFT Creator
/// @dev ChatNFT is responsible for querying ChatGPT on behalf of the user,
/// and storing the user's latest query result.
/// @dev Once the user is satisfied with the query result, they can choose to
/// create a new NFT with the query result. This can be an image, text;
/// any bytes-encoded data.
contract ChatNFT {
    ChatGPT chatGPT;
    // address erc1155L1;

    constructor(string memory apiKey /*, address _erc1155L1*/ ) {
        chatGPT = new ChatGPT(apiKey);
        // erc1155L1 = _erc1155L1;
    }

    modifier confidential() {
        require(Suave.isConfidential(), "must call confidentially");
        _;
    }

    event QueryResult(bytes result);
    event NFTCreated(address owner, uint256 tokenId);

    /// Logs the query result.
    function onQueryResult(bytes memory result) public confidential {
        emit QueryResult(result);
    }

    function createNFT(bytes memory data) public {
        // Create an NFT with the given data.
    }

    /// Makes a query to ChatGPT with the given prompts.
    /// Stores the result in the confidential store.
    /// Logs with the query result are emitted when suaveCalldata is returned.
    /// @param prompts The sequence of prompts to send to ChatGPT.
    function query(string[] memory prompts) public returns (bytes memory suaveCalldata) {
        //

        // Call ChatGPT with the prompt.
        ChatGPT.Message[] memory messages = new ChatGPT.Message[](prompts.length);
        for (uint256 i = 0; i < prompts.length; i++) {
            messages[i] = ChatGPT.Message({role: ChatGPT.Role.User, content: prompts[i]});
        }
        string memory queryResult = chatGPT.complete(messages);

        // Store the result in the confidential store.
        // Map msg.sender to the query result... or should we have a sessionId?

        // Callback emits the query result.
        suaveCalldata = abi.encodeWithSelector(this.onQueryResult.selector, queryResult);
    }
}
