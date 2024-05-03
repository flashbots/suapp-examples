// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {LibString} from "solmate/utils/LibString.sol";

/// @title SuaveNFT
/// @notice Contract to mint ERC-721 tokens with a signed EIP-712 message
contract SuaveNFT is ERC721 {
    using LibString for uint256;

    // string private constant BASE_URI = "http://localhost:8080/metadata/";
    string private baseUri;

    // Event declarations
    event NFTMintedEvent(address indexed recipient, uint256 indexed tokenId);

    // EIP-712 Domain Separator
    // keccak256(abi.encode(keccak256("EIP712Domain(string name,string symbol,uint256 chainId,address verifyingContract)"),keccak256(bytes(NAME)),keccak256(bytes(SYMBOL)),block.chainid,address(this))
    bytes32 public DOMAIN_SEPARATOR = 0x07c5db21fddca4952bc7dee96ea945c5702afed160b9697111b37b16b1289b89;

    // EIP-712 TypeHash
    // keccak256("Mint(string name,string symbol,uint256 tokenId,address recipient)");
    bytes32 public constant MINT_TYPEHASH = 0x686aa0ee2a8dd75ace6f66b3a5e79d3dfd8e25e05a5e494bb85e72214ab37880;

    // token data
    mapping(uint256 => string) public tokenData;

    // NFT Details
    string public constant NAME = "SUAVE_NFT2";
    string public constant SYMBOL = "NFTEE";

    constructor(string memory _baseUri) ERC721(NAME, SYMBOL) {
        baseUri = _baseUri;
    }

    // Mint NFT with a signed EIP-712 message
    function mintNFTWithSignature(
        uint256 tokenId,
        address recipient,
        string memory content,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(verifyEIP712Signature(tokenId, recipient, content, v, r, s), "INVALID_SIGNATURE");

        _safeMint(recipient, tokenId);
        tokenData[tokenId] = content;

        emit NFTMintedEvent(recipient, tokenId);
    }

    // Verify EIP-712 signature
    function verifyEIP712Signature(
        uint256 tokenId,
        address recipient,
        string memory content,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public view returns (bool) {
        bytes32 digestHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        MINT_TYPEHASH,
                        keccak256(bytes(NAME)),
                        keccak256(bytes(SYMBOL)),
                        tokenId,
                        recipient,
                        keccak256(bytes(content))
                    )
                )
            )
        );

        address recovered = ecrecover(digestHash, v, r, s);
        return recovered == recipient;
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return keccak256(bytes(tokenData[tokenId])) != keccak256("");
    }

    /// Hijack `tokenURI` function to comply w/ ERC721 standard,
    /// but we're just using it to hold string data for NFTs.
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return string(abi.encodePacked(baseUri, tokenId.toString()));
    }
}
