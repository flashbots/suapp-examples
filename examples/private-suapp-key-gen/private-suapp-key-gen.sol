// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.8;

import "suave-std/suavelib/Suave.sol";
import "suave-std/Context.sol";
import "suave-std/Suapp.sol";
import "suave-std/Transactions.sol";

contract PublicSuapp is Suapp {
    Suave.DataId signingKeyBid;
    string public KEY_PRIVATE_KEY = "KEY";

    // onchain-offchain pattern to register the new private key in the Confidential storage
    function updateKeyCallback(Suave.DataId _signingKeyBid) public {
        signingKeyBid = _signingKeyBid;
    }

    function initialize() public returns (bytes memory) {
        string memory keyData = Suave.privateKeyGen(Suave.CryptoSignature.SECP256);

        address[] memory peekers = new address[](1);
        peekers[0] = address(this);

        Suave.DataRecord memory bid = Suave.newDataRecord(10, peekers, peekers, "private_key");
        Suave.confidentialStore(bid.id, KEY_PRIVATE_KEY, abi.encodePacked(keyData));

        return abi.encodeWithSelector(this.updateKeyCallback.selector, bid.id);
    }

    // offchain-onchain pattern to sign a transaction using the private key stored in the Suapp
    event TxnSignature(bytes32 r, bytes32 s);

    function exampleCallback() public emitOffchainLogs {}

    function example() public returns (bytes memory) {
        bytes memory signingKey = Suave.confidentialRetrieve(signingKeyBid, KEY_PRIVATE_KEY);

        Transactions.EIP155Request memory txnWithToAddress = Transactions.EIP155Request({
            to: address(0x00000000000000000000000000000000DeaDBeef),
            gas: 1000000,
            gasPrice: 500,
            value: 1,
            nonce: 1,
            data: bytes(""),
            chainId: 1337
        });

        Transactions.EIP155 memory txn = Transactions.signTxn(txnWithToAddress, string(signingKey));
        emit TxnSignature(txn.r, txn.s);

        return abi.encodeWithSelector(this.exampleCallback.selector);
    }
}
