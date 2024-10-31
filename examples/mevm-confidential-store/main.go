package main

import (
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.New()

	namespace := framework.RandomString(10)
	ctr := fr.Suave.DeployContract("confidential-store.sol/ConfidentialStore.json")

	ctr.SendConfidentialRequest("example", []interface{}{namespace}, nil)
	ctr.SendConfidentialRequest("example2", []interface{}{namespace}, nil)
	ctr.SendConfidentialRequest("query", []interface{}{namespace}, nil)
}
