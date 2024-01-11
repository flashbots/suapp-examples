package main

import (
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.New()
	fr.Suave.DeployContract("confidential-store.sol/ConfidentialStore.json").SendTransaction("example", []interface{}{}, nil)
}
