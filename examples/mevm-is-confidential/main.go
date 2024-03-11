package main

import (
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.New()
	fr.Suave.DeployContract("is-confidential.sol/IsConfidential.json").
		SendConfidentialRequest("example", nil, nil)
}
