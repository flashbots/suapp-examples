// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721} from "solmate/tokens/ERC721.sol";

/// @title NFTMinter
/// @notice Contract to mint ERC-721 tokens with a signed EIP-712 message
contract SuaveNFT is ERC721 {
    // Event declarations
    event NFTMintedEvent(address indexed recipient, uint256 indexed tokenId);

    // EIP-712 Domain Separator
    bytes32 public DOMAIN_SEPARATOR;

    // EIP-712 TypeHash
    bytes32 public constant MINT_TYPEHASH =
        keccak256("Mint(string name,string symbol,uint256 tokenId,address recipient)");

    // Authorized signer's address
    address public authorizedSigner;

    // NFT Details
    string public constant NAME = "SUAVE_NFT";
    string public constant SYMBOL = "NFTEE";
    string public constant TOKEN_URI = "IPFS_URL";

    constructor(address _authorizedSigner) ERC721(NAME, SYMBOL) {
        authorizedSigner = _authorizedSigner;

        // Initialize DOMAIN_SEPARATOR with EIP-712 domain separator, specific to your contract
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(NAME)),
                keccak256(bytes(SYMBOL)),
                block.chainid,
                address(this)
            )
        );
    }

    // Mint NFT with a signed EIP-712 message
    function mintNFTWithSignature(uint256 tokenId, address recipient, uint8 v, bytes32 r, bytes32 s) external {
        require(verifyEIP712Signature(tokenId, recipient, v, r, s), "INVALID_SIGNATURE");

        _safeMint(recipient, tokenId);

        emit NFTMintedEvent(recipient, tokenId);
    }

    // Verify EIP-712 signature
    function verifyEIP712Signature(uint256 tokenId, address recipient, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (bool)
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(MINT_TYPEHASH, keccak256(bytes(NAME)), keccak256(bytes(SYMBOL)), tokenId, recipient)
                )
            )
        );

        address recovered = ecrecover(digest, v, r, s);

        return recovered == authorizedSigner;
    }

    // Token URI implementation
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf[tokenId] != address(0), "NOT_MINTED");
        return TOKEN_URI;
    }
}
