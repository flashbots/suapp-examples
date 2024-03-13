package main

import (
	"context"
	"encoding/json"
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/flashbots/suapp-examples/framework"
)

var buildEthBlockAddress = common.HexToAddress("0x42100001")

func main() {
	fr := framework.New(framework.WithL1())

	testAddr1 := framework.GeneratePrivKey()
	log.Printf("Test address 1: %s", testAddr1.Address().Hex())

	fundBalance := big.NewInt(100000000000000000)
	maybe(fr.L1.FundAccount(testAddr1.Address(), fundBalance))

	targeAddr := testAddr1.Address()
	tx, err := fr.L1.SignTx(testAddr1, &types.LegacyTx{
		To:       &targeAddr,
		Value:    big.NewInt(1000),
		Gas:      21000,
		GasPrice: big.NewInt(6701898710),
	})
	maybe(err)

	bundle := &types.SBundle{
		Txs:             types.Transactions{tx},
		RevertingHashes: []common.Hash{},
	}
	bundleBytes, err := json.Marshal(bundle)
	maybe(err)

	bundleContract := fr.Suave.DeployContract("builder.sol/BundleContract.json")
	ethBlockContract := fr.Suave.DeployContract("builder.sol/EthBlockContract.json")

	targetBlock := currentBlock(fr).Time()

	{ // Send a bundle to the builder
		decryptionCondition := targetBlock + 1
		allowedPeekers := []common.Address{
			buildEthBlockAddress,
			bundleContract.Raw().Address(),
			ethBlockContract.Raw().Address()}
		allowedStores := []common.Address{}
		newBundleArgs := []any{
			decryptionCondition,
			allowedPeekers,
			allowedStores}

		confidentialDataBytes, err := bundleContract.Abi.Methods["fetchConfidentialBundleData"].Outputs.Pack(bundleBytes)
		maybe(err)

		_ = bundleContract.SendConfidentialRequest("newBundle", newBundleArgs, confidentialDataBytes)
	}

	{ // Signal to the builder that it's time to build a new block
		payloadArgsTuple := types.BuildBlockArgs{
			ProposerPubkey: []byte{0x42},
			Timestamp:      targetBlock + 12, //  ethHead + uint64(12),
			FeeRecipient:   common.Address{0x42},
		}

		_ = ethBlockContract.SendConfidentialRequest("buildFromPool", []any{payloadArgsTuple, targetBlock + 1}, nil)
		maybe(err)
	}
}

func currentBlock(fr *framework.Framework) *types.Block {
	n, err := fr.L1.RPC().BlockNumber(context.TODO())
	maybe(err)
	b, err := fr.L1.RPC().BlockByNumber(context.TODO(), new(big.Int).SetUint64(n))
	maybe(err)
	return b
}

func maybe(err error) {
	if err != nil {
		panic(err)
	}
}
