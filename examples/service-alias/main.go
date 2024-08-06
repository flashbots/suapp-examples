package main

import "github.com/flashbots/suapp-examples/framework"

func main() {
	fr := framework.New()
	fr.Suave.DeployContract("service-alias.sol/ServiceAlias.json").
		SendConfidentialRequest("example", nil, nil)
}
