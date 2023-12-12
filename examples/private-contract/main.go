package main

import "github.com/flashbots/suapp-examples/framework"

func main() {
	privateContract, _ := framework.ReadArtifact("private-contract.sol/PrivateContract.json")

	fr := framework.New()
	fr.DeployContract("private-contract.sol/PublicSuapp.json").
		SendTransaction("example", nil, privateContract.Code)
}
