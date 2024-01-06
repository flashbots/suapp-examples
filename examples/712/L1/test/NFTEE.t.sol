// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/NFTEE.sol";

contract SuaveNFTTest is Test {
    uint256 internal signerPrivateKey;
    address internal signerPubKey;
    SuaveNFT suaveNFT;

    function setUp() public {
        signerPrivateKey = 0xA11CE;
        signerPubKey = vm.addr(signerPrivateKey);
        suaveNFT = new SuaveNFT(signerPubKey);
    }

    function testMintNFTWithSignature() public {
        uint256 tokenId = 1;
        address recipient = 0xE0f5206BBD039e7b0592d8918820024e2a7437b9;
        uint8 v;
        bytes32 r;
        bytes32 s;

        // Prepare the EIP-712 signature
        {
            bytes32 DOMAIN_SEPARATOR = suaveNFT.DOMAIN_SEPARATOR();
            bytes32 structHash = keccak256(
                abi.encode(
                    suaveNFT.MINT_TYPEHASH(), // Use MINT_TYPEHASH from the contract
                    keccak256(bytes(suaveNFT.NAME())), // Use NAME constant from the contract
                    keccak256(bytes(suaveNFT.SYMBOL())), // Use SYMBOL constant from the contract
                    tokenId,
                    recipient
                )
            );
            bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
            // example forge logs for debugging 712
            console.logBytes32(DOMAIN_SEPARATOR);
            console.logBytes32(suaveNFT.MINT_TYPEHASH());
            console.logBytes32(keccak256(bytes(suaveNFT.NAME())));
            console.logBytes32(keccak256(bytes(suaveNFT.SYMBOL())));
            console.logBytes32(digest);

            // Sign the digest
            (v, r, s) = vm.sign(signerPrivateKey, digest);
        }

        // Mint the NFT
        suaveNFT.mintNFTWithSignature(tokenId, recipient, v, r, s);

        // Assertions
        assertEq(suaveNFT.ownerOf(tokenId), recipient);
        assertEq(suaveNFT.tokenURI(tokenId), "IPFS_URL");
    }
}
