package main

import (
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	framework.DeployAndTransact("confidential-store.sol/ConfidentialStore.json", "example")
}
