// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "suave-std/suavelib/Suave.sol";

contract Emitter {
    // Constants matching those in SuaveNFT
    string public constant NAME = "SUAVE_NFT";
    string public constant SYMBOL = "NFTEE";
    bytes32 public constant MINT_TYPEHASH = 0x686aa0ee2a8dd75ace6f66b3a5e79d3dfd8e25e05a5e494bb85e72214ab37880;
    bytes32 public constant DOMAIN_SEPARATOR = 0x07c5db21fddca4952bc7dee96ea945c5702afed160b9697111b37b16b1289b89;
    string public cstoreKey = "NFTEE:v0:PrivateKey";

    // Private key record
    Suave.DataId public privateKeyDataID;

    event PrivateKeyUpdateEvent(Suave.DataId dataID);

    function getPrivateKeyDataIDBytes() public view returns (bytes16) {
        return Suave.DataId.unwrap(privateKeyDataID);
    }

    // function to fetch private key from confidential input portion of Confidential Compute Request
    function fetchConfidentialPrivateKey() public returns (bytes memory) {
        require(Suave.isConfidential());

        bytes memory confidentialInputs = Suave.confidentialInputs();
        return confidentialInputs;
    }

    function mintDigest(uint256 tokenId, address recipient) public pure returns (bytes memory) {
        bytes32 structHash =
            keccak256(abi.encode(MINT_TYPEHASH, keccak256(bytes(NAME)), keccak256(bytes(SYMBOL)), tokenId, recipient));
        bytes32 digestHash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

        return abi.encodePacked(digestHash);
    }

    // setPrivateKey is the onchain portion of the Confidential Compute Request
    // inside we need to store our reference to our private key for future use
    // we must do this because updatePrivateKey() is offchain and can't directly store onchain without this
    function setPrivateKey(Suave.DataId dataID) public {
        privateKeyDataID = dataID;
        emit PrivateKeyUpdateEvent(dataID);
    }

    // offchain portion of Confidential Compute Request to update privateKey
    function updatePrivateKey() public returns (bytes memory) {
        require(Suave.isConfidential());

        bytes memory privateKey = this.fetchConfidentialPrivateKey();

        // create permissions for data record
        address[] memory peekers = new address[](1);
        peekers[0] = address(this);

        address[] memory allowedStores = new address[](1);
        allowedStores[0] = 0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829; // using the wildcard address for allowedStores

        // store private key in conf data store
        Suave.DataRecord memory record = Suave.newDataRecord(0, peekers, allowedStores, cstoreKey);

        Suave.confidentialStore(record.id, cstoreKey, privateKey);

        // return calback to emit data ID onchain
        return bytes.concat(this.setPrivateKey.selector, abi.encode(record.id));
    }

    event NFTEEApproval(bytes signedMessage);

    function emitSignedMintApproval(bytes memory message) public {
        emit NFTEEApproval(message);
    }

    /// Sign EIP 712 message for minting an NFTEE on L1 and emit the signature as a log.
    function signL1MintApproval(uint256 tokenId, address recipient) public returns (bytes memory) {
        require(Suave.isConfidential());
        require(Suave.DataId.unwrap(privateKeyDataID) != bytes16(0), "private key is not set");

        bytes memory signerPrivateKey = Suave.confidentialRetrieve(privateKeyDataID, cstoreKey);
        bytes memory msgBytes = signMintApproval(tokenId, recipient, signerPrivateKey);
        return bytes.concat(this.emitSignedMintApproval.selector, abi.encode(msgBytes));
    }

    /// Returns signature of the mint approval.
    function signMintApproval(uint256 tokenId, address recipient, bytes memory signerPrivateKey)
        public
        returns (bytes memory signature)
    {
        bytes memory _digest = mintDigest(tokenId, recipient);
        signature = Suave.signMessage(_digest, Suave.CryptoSignature.SECP256, string(signerPrivateKey));
    }
}
