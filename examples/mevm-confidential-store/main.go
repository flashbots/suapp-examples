package main

import (
	"github.com/ethereum/go-ethereum/common"
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.New()
	contract := fr.DeployContract("confidential-store.sol/ConfidentialStore.json")
	contract.SendTransaction("example", []interface{}{[]common.Address{contract.Address()}}, nil)
}
