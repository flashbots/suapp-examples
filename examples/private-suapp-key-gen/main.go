package main

import (
	"fmt"
	"log"

	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.New()

	contract := fr.Suave.DeployContract("private-suapp-key-gen.sol/PublicSuapp.json")

	receipt := contract.SendConfidentialRequest("initialize", nil, nil)
	fmt.Println(receipt)

	contract.SendConfidentialRequest("example", nil, nil)

	// validate the signature (TODO: return the address from the Suapp and validate the signature)
	_, err := contract.Abi.Events["TxnSignature"].ParseLog(receipt.Logs[0])
	if err != nil {
		log.Fatal(err)
	}
}
