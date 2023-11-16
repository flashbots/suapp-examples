package main

import (
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.NewFr()
	fr.DeployContract("is-confidential.sol/IsConfidential.json").
		SendTransaction("example", nil, nil)
}
