package main

import (
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	privateLibrary, _ := framework.ReadArtifact("lib-confidential-store.sol/PrivateLibrary.json")

	fr := framework.New()
	suapp := fr.Suave.DeployContract("lib-confidential-store.sol/PublicSuapp.json")

	// Deploy the contract and get the bid id
	receipt := suapp.SendConfidentialRequest("registerContract", nil, privateLibrary.Code)
	event, _ := contractRegisteredABI.Inputs.Unpack(receipt.Logs[0].Data)
	privateContractBidId := event[0].([16]byte)

	// Use the private contract
	suapp.SendConfidentialRequest("example", []interface{}{privateContractBidId}, nil)
}

var contractRegisteredABI abi.Event

func init() {
	artifact, _ := framework.ReadArtifact("lib-confidential-store.sol/PublicSuapp.json")
	contractRegisteredABI = artifact.Abi.Events["ContractRegistered"]
}
