package main

import (
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	contract := framework.DeployContract("confidential-store.sol/ConfidentialStore.json")

	txnResult, _ := contract.SendTransaction("example", []interface{}{}, []byte{})
	framework.EnsureTransactionSuccess(txnResult)
}
