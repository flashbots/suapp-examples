// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Suave} from "suave-std/suavelib/Suave.sol";
import {ChatGPT} from "suave-std/protocols/ChatGPT.sol";
import {Emitter} from "./712Emitter2.sol";

/// @title ChatNFT: ChatGPT-based NFT Creator
/// @dev ChatNFT is responsible for querying ChatGPT on behalf of the user,
/// and storing the user's latest query result.
/// @dev Once the user is satisfied with the query result, they can choose to
/// create a new NFT with the query result. This can be an image, text;
/// any bytes-encoded data.
contract ChatNFT {
    /// Require function to be called via confidential compute request.
    modifier confidential() {
        require(Suave.isConfidential(), "must call confidentially");
        _;
    }

    struct MintNFTConfidentialParams {
        bytes privateKey;
        address recipient;
        string[] prompts;
        string openaiApiKey;
    }

    event QueryResult(bytes result);
    event NFTCreated(uint256 tokenId, address recipient, bytes signature);

    function getTokenId(string[] memory prompts) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(prompts)));
    }

    /// Logs the query result.
    function onMintNFT(bytes memory queryResult, uint256 tokenId, address recipient, bytes memory signature) public {
        emit QueryResult(queryResult);
        emit NFTCreated(tokenId, recipient, signature);
    }

    /// Makes a query to ChatGPT with prompts given via confidentialInputs.
    /// Mints an NFT with the query result.
    function mintNFT() public confidential returns (bytes memory suaveCalldata) {
        // parse confidential inputs
        bytes memory cInputs = Suave.confidentialInputs();
        MintNFTConfidentialParams memory cParams = abi.decode(cInputs, (MintNFTConfidentialParams));
        uint256 tokenId = getTokenId(cParams.prompts);

        // query ChatGPT
        ChatGPT chatGPT = new ChatGPT(cParams.openaiApiKey);
        ChatGPT.Message[] memory messages = new ChatGPT.Message[](cParams.prompts.length);
        for (uint256 i = 0; i < cParams.prompts.length; i++) {
            messages[i] = ChatGPT.Message({role: ChatGPT.Role.User, content: cParams.prompts[i]});
        }
        string memory queryResult = chatGPT.complete(messages);

        // for signing NFT-minting approvals
        Emitter emitter = new Emitter();
        bytes memory signature =
            emitter.signMintApproval(tokenId, cParams.recipient, string(queryResult), cParams.privateKey);

        // Callback emits the query result.
        suaveCalldata =
            abi.encodeWithSelector(this.onMintNFT.selector, queryResult, tokenId, cParams.recipient, signature);
    }
}
