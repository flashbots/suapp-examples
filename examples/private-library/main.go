package main

import "github.com/flashbots/suapp-examples/framework"

func main() {
	privateLibrary, _ := framework.ReadArtifact("private-library.sol/PrivateLibrary.json")

	fr := framework.New()
	fr.DeployContract("private-library.sol/PublicSuapp.json").
		SendTransaction("example", nil, privateLibrary.Code)
}
