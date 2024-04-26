// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "suave-std/suavelib/Suave.sol";

contract Emitter {
    // Constants matching those in SuaveNFT
    string public constant NAME = "SUAVE_NFT";
    string public constant SYMBOL = "NFTEE";
    bytes32 public constant MINT_TYPEHASH = 0x686aa0ee2a8dd75ace6f66b3a5e79d3dfd8e25e05a5e494bb85e72214ab37880;
    bytes32 public constant DOMAIN_SEPARATOR = 0x07c5db21fddca4952bc7dee96ea945c5702afed160b9697111b37b16b1289b89;

    function mintDigest(uint256 tokenId, address recipient, string memory content) public pure returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                MINT_TYPEHASH,
                keccak256(bytes(NAME)),
                keccak256(bytes(SYMBOL)),
                tokenId,
                recipient,
                keccak256(bytes(content))
            )
        );
        bytes32 digestHash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

        return abi.encodePacked(digestHash);
    }

    event NFTEEApproval(bytes signedMessage);

    function emitSignedMintApproval(bytes memory message) public {
        emit NFTEEApproval(message);
    }

    /// Returns signature of the mint approval.
    function signMintApproval(uint256 tokenId, address recipient, string memory content, bytes memory signerPrivateKey)
        public
        returns (bytes memory signature)
    {
        bytes memory _digest = mintDigest(tokenId, recipient, content);
        signature = Suave.signMessage(_digest, Suave.CryptoSignature.SECP256, string(signerPrivateKey));
    }
}
