package main

import (
	"fmt"
	"log"
	"math/big"

	"github.com/flashbots/suapp-examples/framework"
)

func main() {

	fr := framework.New()
	contract := fr.Suave.DeployContract("LLM/LLM.sol/LLM.json")
	// artifact, _ := framework.ReadArtifact("LLM/LLM.sol/LLM.json")

	// Step 1. Create and fund the accounts we are going to frontrun/backrun
	fmt.Println("1. Create and fund test accounts")

	testAddr1 := framework.GeneratePrivKey()
	testAddr2 := framework.GeneratePrivKey()

	log.Printf("Test address 1: %s", testAddr1.Address().Hex())
	log.Printf("Test address 2: %s", testAddr2.Address().Hex())

	fundBalance := big.NewInt(100000000000000000)
	if err := fr.Suave.FundAccount(testAddr1.Address(), fundBalance); err != nil {
		log.Fatal(err)
	}
	if err := fr.Suave.FundAccount(testAddr2.Address(), fundBalance); err != nil {
		log.Fatal(err)
	}

	// Step 2. Send LLM prompt
	// confBytes, err := artifact.Abi.Methods["submitPromptOffchain"].Inputs.Pack("LLM test")
	// if err != nil {
	// 	log.Fatal(err)
	// }
	receipt := contract.SendTransaction("callLLM", []interface{}{"Test LLM Prompt"}, nil)

	fmt.Println(receipt)

}
