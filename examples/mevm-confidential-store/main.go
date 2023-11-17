package main

import (
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.New()
	contract := fr.DeployContract("confidential-store.sol/ConfidentialStore.json")
	contract.SendTransaction("example", []interface{}{}, nil)
}
