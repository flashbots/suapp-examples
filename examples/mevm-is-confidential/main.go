package main

import (
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	framework.DeployAndTransact("is-confidential.sol/IsConfidential.json", "example")
}
