package main

import (
	"log"
	"math/big"
	"os"

	"github.com/ethereum/go-ethereum/common"
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	endpoint := os.Getenv("JSONRPC_ENDPOINT")
	if endpoint == "" {
		// skip test
		return
	}

	// usdc token address
	targetErc20Contract := common.HexToAddress("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
	balanceCheckAddr := common.HexToAddress("0x0000000000000000000000000000000000000001")

	fr := framework.New()
	contract := fr.Suave.DeployContract("gateway-erc20.sol/PublicSuapp.json")
	receipt := contract.
		SendConfidentialRequest("example", []interface{}{endpoint, targetErc20Contract, balanceCheckAddr}, nil)

	balanceEvent, err := contract.Abi.Events["Balance"].ParseLog(receipt.Logs[0])
	if err != nil {
		log.Fatal(err)
	}

	balance := balanceEvent["balance"].(*big.Int)
	if balance.Uint64() == 0 {
		// in Ethereum mainnet this balance is not zero
		log.Fatal("balance is 0?")
	}
}
