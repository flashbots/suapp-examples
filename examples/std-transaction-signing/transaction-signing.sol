// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.8;

import "suave-std/suavelib/Suave.sol";
import "suave-std/Transactions.sol";
import "suave-std/Context.sol";
import "suave-std/Suapp.sol";

contract TransactionSigning is Suapp {
    using Transactions for *;

    event TxnSignature(bytes32 r, bytes32 s);

    function callback() external emitOffchainLogs {}

    function example() public returns (bytes memory) {
        string memory signingKey = string(Context.confidentialInputs());

        Transactions.EIP155Request memory txnWithToAddress = Transactions
            .EIP155Request({
                to: address(0x00000000000000000000000000000000DeaDBeef),
                gas: 1000000,
                gasPrice: 500,
                value: 1,
                nonce: 1,
                data: bytes(""),
                chainId: 1337
            });

        Transactions.EIP155 memory txn = Transactions.signTxn(
            txnWithToAddress,
            string(signingKey)
        );

        emit TxnSignature(txn.r, txn.s);

        return abi.encodeWithSelector(this.callback.selector);
    }
}
