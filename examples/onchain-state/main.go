package main

import (
	"fmt"
	"os"

	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.New()
	contract := fr.DeployContract("onchain-state.sol/OnChainState.json")

	fmt.Printf("1. Send a confidential request that cannot modify the state")

	contract.SendTransaction("nilExample", nil, nil)
	val := contract.Call("getState")[0].(uint64)
	if val != 0 {
		fmt.Printf("expected 0")
		os.Exit(1)
	}

	fmt.Printf("2. Send a confidential request that modifies the state")

	contract.SendTransaction("example", nil, nil)
	val = contract.Call("getState")[0].(uint64)
	if val != 0 {
		fmt.Printf("expected 1")
		os.Exit(1)
	}
}
