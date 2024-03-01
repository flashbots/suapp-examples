package main

import (
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.New()
	fr.Suave.DeployContract("context.sol/ContextExample.json").
		SendConfidentialRequest("example", nil, []byte{0x1})
}
