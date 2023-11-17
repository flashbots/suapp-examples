package main

import (
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.New()
	fr.DeployContract("confidential-store.sol/ConfidentialStore.json").
		SendTransaction("example", nil, nil)
}
