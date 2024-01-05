package main

import (
	"fmt"
	"os"

	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.New()
	contract := fr.DeployContract("onchain-state.sol/OnChainState.json")

	fmt.Println("1. A confidential request fails if it tries to modify the state")

	_, err := contract.Raw().SendTransaction("nilExample", nil, nil)
	if err == nil {
		fmt.Println("expected an error")
		os.Exit(1)
	}

	fmt.Println("2. Send a confidential request that modifies the state")

	contract.SendTransaction("example", nil, nil)
	val, ok := contract.Call("getState")[0].(uint64)
	if !ok {
		fmt.Printf("expected uint64")
		os.Exit(1)
	}
	if val != 1 {
		fmt.Printf("expected 1")
		os.Exit(1)
	}
}
