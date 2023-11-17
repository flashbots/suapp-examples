package main

import (
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.New()
	fr.DeployContract("onchain-callback.sol/OnChainCallback.json").
		SendTransaction("example", nil, nil)
}
