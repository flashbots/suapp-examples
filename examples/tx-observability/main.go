package main

import (
	"log"

	"github.com/ethereum/go-ethereum/common"
	"github.com/flashbots/suapp-examples/framework"
)

// SentTransactionsEvent is emitted by SUAPPs to indicate that the SUAPP sent some transactions to L1.
type SentTransactionsEvent struct {
	TxHashes []common.Hash `abi:"txHashes"`
}

func main() {
	fr := framework.New(framework.WithL1())
	suappContract := fr.Suave.DeployContract("observability.sol/Suapp.json")

	res := suappContract.SendConfidentialRequest("doSomethingWithTxs", nil, nil)
	if res.Status != 1 {
		log.Fatal("confidential request failed")
	}

	var event SentTransactionsEvent
	err := suappContract.Abi.UnpackIntoInterface(&event, "SentTransactions", res.Logs[0].Data)
	if err != nil {
		log.Fatalf("Failed to unpack log data: %v", err)
	}
	log.Printf("logged tx hashes: %v", event.TxHashes)
}
