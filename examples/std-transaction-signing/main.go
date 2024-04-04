package main

import (
	"encoding/hex"
	"log"

	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.New()
	priv := "b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291"

	contract := fr.Suave.DeployContract("transaction-signing.sol/TransactionSigning.json")
	receipt := contract.SendConfidentialRequest("example", nil, []byte(priv))

	// validate the signature
	txnSignatureEvent, err := contract.Abi.Events["TxnSignature"].ParseLog(receipt.Logs[0])
	if err != nil {
		log.Fatal(err)
	}
	r, s := txnSignatureEvent["r"].([32]byte), txnSignatureEvent["s"].([32]byte)

	if hex.EncodeToString(r[:]) != "eebcfac0def6db5649d0ae6b52ed3b8ba1f5c6c428588df125461113ba8c6749" {
		log.Fatal("wrong r signature")
	}
	if hex.EncodeToString(s[:]) != "5d5e1aafa0c964b43c251b6a525d49572968f2cebc5868c58bcc9281b9a07505" {
		log.Fatal("wrong s signature")
	}
}
