// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "src/suavelib/Suave.sol";
import "solady/src/utils/JSONParserLib.sol";

contract ChatGPT {
    using JSONParserLib for *;

    string apiKey;

    enum Role {
        User,
        System
    }

    struct Message {
        Role role;
        string content;
    }

    constructor(string memory _apiKey) {
        apiKey = _apiKey;
    }

    // https://platform.openai.com/docs/api-reference/making-requests
    function complete(Message[] memory messages) public returns (string memory) {
        bytes memory body;
        body = abi.encodePacked('{"model": "gpt-3.5-turbo", "messages": [');
        for (uint256 i = 0; i < messages.length; i++) {
            body = abi.encodePacked(
                body,
                '{"role": "',
                messages[i].role == Role.User ? "user" : "system",
                '", "content": "',
                messages[i].content,
                '"}'
            );
            if (i < messages.length - 1) {
                body = abi.encodePacked(body, ",");
            }
        }
        body = abi.encodePacked(body, '], "temperature": 0.7}');

        Suave.HttpRequest memory request;
        request.method = "POST";
        request.url = "https://api.openai.com/v1/chat/completions";
        request.headers = new string[](2);
        request.headers[0] = string.concat("Authorization: Bearer ", apiKey);
        request.headers[1] = "Content-Type: application/json";
        request.body = body;

        bytes memory output = Suave.doHTTPRequest(request);

        // decode responses
        JSONParserLib.Item memory item = string(output).parse();
        string memory result = trimQuotes(item.at('"choices"').at(0).at('"message"').at('"content"').value());

        return result;
    }

    function trimQuotes(string memory input) private pure returns (string memory) {
        bytes memory inputBytes = bytes(input);
        require(
            inputBytes.length >= 2 && inputBytes[0] == '"' && inputBytes[inputBytes.length - 1] == '"', "Invalid input"
        );

        bytes memory result = new bytes(inputBytes.length - 2);

        for (uint256 i = 1; i < inputBytes.length - 1; i++) {
            result[i - 1] = inputBytes[i];
        }

        return string(result);
    }
}
