package main

import (
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.New(framework.WithL1())

	// deploy some example pool contract with swap function
	poolContract := fr.L1.DeployContract("pool.sol/Pool.json")
	lpAddress := poolContract.Raw().Address()

	constructorArgs := []interface{}{fr.GetConfigs().L1RPC, lpAddress}
	contract := fr.Suave.DeployContract("private-swap.sol/PrivateSwap.json", constructorArgs...)

	// params for confidential request
	from := common.HexToAddress("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")
	to := common.HexToAddress("0xdAC17F958D2ee523a2206206994597C13D831ec7")
	amount := big.NewInt(100000)

	encodedInputs, err := poolContract.Abi.Methods["swap"].Inputs.Pack(from, to, amount)
	if err != nil {
		log.Fatal(err, "failed to pack inputs")
	}

	receipt := contract.SendConfidentialRequest("example", []interface{}{}, encodedInputs)

	swapEvent, err := contract.Abi.Events["Swap"].ParseLog(receipt.Logs[0])
	if err != nil {
		log.Fatal(err)
	}

	amountResult := swapEvent["resultAmount"].(*big.Int)
	if amountResult.Uint64() != amount.Uint64()*2 {
		log.Fatal("balance should be swapAmount * 2")
	}
}
