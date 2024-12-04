// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "suave-std/Suapp.sol";
import "suave-std/Context.sol";
import "solady/src/utils/JSONParserLib.sol";

contract Chat is Suapp {
    using JSONParserLib for *;
    struct DataItem {
        Suave.DataId id;
        bool used;
    }
    enum Role {
        User,
        System
    }

    struct Message {
        Role role;
        string content;
    }
    mapping(address=>DataItem) apiKeys;
    string public API_KEY = "API_KEY";

    event Response(string messages);
    event UpdateKey(address sender);
    error NoKeyExists(address sender);

    function updateKeyOnchain(Suave.DataId _apiKeyRecord) public {
        emit UpdateKey(msg.sender);
        apiKeys[msg.sender] = DataItem({
            id: _apiKeyRecord,
            used : true
        });
    }

    function registerKeyOffchain() public returns (bytes memory) {
        bytes memory keyData = Context.confidentialInputs();

        address[] memory peekers = new address[](1);
        peekers[0] = address(this);

        Suave.DataRecord memory record = Suave.newDataRecord(0, peekers, peekers, "api_key");
        Suave.confidentialStore(record.id, API_KEY, keyData);

        return abi.encodeWithSelector(this.updateKeyOnchain.selector, record.id);
    }

    function onchain() public emitOffchainLogs {}

    function ask(string calldata prompt,string calldata model,string calldata temperature) external returns (bytes memory) {
        if(!apiKeys[msg.sender].used){
            revert NoKeyExists(msg.sender);
        }
        bytes memory keyData = Suave.confidentialRetrieve(apiKeys[msg.sender].id, API_KEY);
        string memory apiKey = bytesToString(keyData);

        Message[] memory messages = new Message[](1);
        messages[0] = Message(Role.User, prompt);

        string memory data = complete(messages, model, temperature,apiKey);

        emit Response(data);

        return abi.encodeWithSelector(this.onchain.selector);
    }

    function bytesToString(bytes memory data) internal pure returns (string memory) {
        uint256 length = data.length;
        bytes memory chars = new bytes(length);

        for(uint i = 0; i < length; i++) {
            chars[i] = data[i];
        }

        return string(chars);
    }

    function complete(Message[] memory messages, string memory model, string memory temperature, string memory key) public returns (string memory) {
        bytes memory body;
        body = abi.encodePacked('{"model": "',model);
        body = abi.encodePacked(body,'", "messages": [');
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
        body = abi.encodePacked(body, '], "temperature":');
        body = abi.encodePacked(body,  temperature);
        body = abi.encodePacked(body,  '}');

        return doGptRequest(body,key);
    }

    function doGptRequest(bytes memory body,string memory apiKey) private returns (string memory) {
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