package main

import (
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	framework.DeployAndTransact("onchain-callback.sol/OnChainCallback.json", "example")
}
