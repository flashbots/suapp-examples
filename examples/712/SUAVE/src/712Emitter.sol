// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../../../lib/suave-std/src/suavelib/Suave.sol";

contract Emitter {
    // Constants matching those in SuaveNFT
    string private constant NAME = "SUAVE_NFT";
    string private constant SYMBOL = "NFTEE";
    bytes32 private constant MINT_TYPEHASH = 0x686aa0ee2a8dd75ace6f66b3a5e79d3dfd8e25e05a5e494bb85e72214ab37880;
    bytes32 private constant DOMAIN_SEPARATOR = 0x617661b7ab13ce21150e0a39abe5834762b356e3c643f10c28a3c9331025604a;
    string private cstoreKey = "NFTEE:v0:PrivateKey";

    // Private key variable
    Suave.DataId public privateKeyDataID;
    address public owner;

    // Constructor to initialize owner
    constructor() {
        owner = msg.sender;
    }

    function getPrivateKeyDataIDBytes() public view returns (bytes16) {
        return Suave.DataId.unwrap(privateKeyDataID);
    }

    // function to fetch private key from confidential input portion of Confidential Compute Request
    function fetchConfidentialPrivateKey() public returns (bytes memory) {
        require(Suave.isConfidential());

        bytes memory confidentialInputs = Suave.confidentialInputs();
        return confidentialInputs;
    }

    event PrivateKeyUpdateEvent(Suave.DataId dataID);

    // setPrivateKey is the onchain portion of the Confidential Compute Request
    // inside we need to store our reference to our private key for future use
    // we must do this because updatePrivateKey() is offchain and can't directly store onchain without this
    function setPrivateKey(Suave.DataId dataID) public {
        // require(msg.sender == owner, "only owner can update");
        privateKeyDataID = dataID;
        emit PrivateKeyUpdateEvent(dataID);
    }

    // offchain portion of Confidential Compute Request to update privateKey
    function updatePrivateKey() public returns (bytes memory) {
        require(Suave.isConfidential());
        // // require(msg.sender == owner, "only owner can update");

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

    function emitSignedMintApproval(bytes memory msg) public {
        emit NFTEEApproval(msg);
    }

    // Function to create EIP-712 digest
    function createEIP712Digest(uint256 tokenId, address recipient) public view returns (bytes memory) {
        require(Suave.DataId.unwrap(privateKeyDataID) != bytes16(0), "private key is not set");

        bytes32 structHash =
            keccak256(abi.encode(MINT_TYPEHASH, keccak256(bytes(NAME)), keccak256(bytes(SYMBOL)), tokenId, recipient));

        bytes32 digestHash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

        return abi.encodePacked(digestHash);
    }

    // Function to sign and emit a signed EIP 712 digest for minting an NFTEE on L1
    function signL1MintApproval(uint256 tokenId, address recipient) public view returns (bytes memory) {
        require(Suave.isConfidential());
        require(Suave.DataId.unwrap(privateKeyDataID) != bytes16(0), "private key is not set");

        bytes memory digest = createEIP712Digest(tokenId, recipient);

        bytes memory signerPrivateKey = Suave.confidentialRetrieve(privateKeyDataID, cstoreKey);

        bytes memory msgBytes = Suave.signMessage(digest, string(signerPrivateKey));

        return bytes.concat(this.emitSignedMintApproval.selector, abi.encode(msgBytes));
    }
}
