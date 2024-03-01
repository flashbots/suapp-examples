package main

import (
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.New()
	fr.Suave.DeployContract("onchain-callback.sol/OnChainCallback.json").
		SendConfidentialRequest("example", nil, nil)
}
