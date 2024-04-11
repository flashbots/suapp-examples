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

	gasPrice, err := fr.L1.RPC().SuggestGasPrice(context.Background())
	maybe(err)

	targeAddr := testAddr1.Address()
	tx, err := fr.L1.SignTx(testAddr1, &types.LegacyTx{
		To:       &targeAddr,
		Value:    big.NewInt(1000),
		Gas:      21000,
		GasPrice: gasPrice.Add(gasPrice, big.NewInt(5000000000)),
	})
	maybe(err)

	bundle := &types.SBundle{
		Txs:             types.Transactions{tx},
		RevertingHashes: []common.Hash{},
	}
	bundleBytes, err := json.Marshal(bundle)
	maybe(err)

	bundleContract := fr.Suave.DeployContract("builder.sol/BundleContract.json")
	ethBlockContract := fr.Suave.DeployContractWithArgs(
		"builder.sol/EthBlockBidSenderContract.json",
		"https://0xac6e77dfe25ecd6110b8e780608cce0dab71fdd5ebea22a16c0205200f2f8e2e3ad3b71d3499c54ad14d6c21b41a37ae@boost-relay.flashbots.net",
	)

	targetBlock := currentL1Block(fr)

	{ // Send a bundle to the builder
		decryptionCondition := targetBlock.NumberU64() + 1
		allowedPeekers := []common.Address{
			buildEthBlockAddress,
			bundleContract.Raw().Address(),
			ethBlockContract.Raw().Address(),
		}
		allowedStores := []common.Address{}
		newBundleArgs := []any{
			decryptionCondition,
			allowedPeekers,
			allowedStores,
		}

		confidentialDataBytes, err := bundleContract.Abi.Methods["fetchConfidentialBundleData"].Outputs.Pack(bundleBytes)
		maybe(err)

		_ = bundleContract.SendConfidentialRequest("newBundle", newBundleArgs, confidentialDataBytes)
	}

	var blockBidID any
	{ // Signal to the builder that it's time to build a new block
		payloadArgsTuple := types.BuildBlockArgs{
			ProposerPubkey: []byte{0x42},
			Timestamp:      targetBlock.Time() + 12, //  ethHead + uint64(12),
			FeeRecipient:   common.Address{0x42},
		}

		receipt := ethBlockContract.SendConfidentialRequest("buildFromPool", []any{payloadArgsTuple, targetBlock.NumberU64() + 1}, nil)
		maybe(err)

		for _, receiptLog := range receipt.Logs {
			/// debug stuff ;; free to remove
			logJSON, err := receiptLog.MarshalJSON()
			maybe(err)
			log.Printf("receipt log: %s", string(logJSON))
			////////////////////////////////////////////////

			if receiptLog.Topics[0] == ethBlockContract.Abi.Events["BuilderBoostBidEvent"].ID {
				bids, err := ethBlockContract.Abi.Events["BuilderBoostBidEvent"].Inputs.Unpack(receiptLog.Data)
				maybe(err)
				blockBidID = bids[0] // the one we want for the merged-bundles data records
			}
		}
	}

	{ // Submit block to the relay
		// get latest block from live chain
		// execBlock, err := fr.L1.RPC().BlockByNumber(context.Background(), nil)
		maybe(err)
		beaconBlock, beaconRoot, err := fr.L1Beacon.GetBlockHeader(nil)
		maybe(err)
		blockJSON, err := json.Marshal(beaconBlock)
		maybe(err)
		log.Printf("beaconBlock: %s", string(blockJSON))

		blockArgs := types.BuildBlockArgs{
			ProposerPubkey: []byte{0x42},
			Timestamp:      getNewSlotTimestamp(beaconBlock.Slot), //  head + 12,
			FeeRecipient:   testAddr1.Address(),
			Parent:         *beaconRoot,
			Slot:           beaconBlock.Slot + 1,
		}

		/*buildAndEmit(
			Suave.BuildBlockArgs memory blockArgs,
			uint64 blockHeight,
			Suave.DataId bidId,
			string memory namespace
		) returns (bytes)*/
		_ = ethBlockContract.SendConfidentialRequest("buildAndEmit", []any{
			blockArgs,
			targetBlock.NumberU64() + 1,
			blockBidID,
			"",
		}, nil)
	}
}

// Calculate the timestamp for a new slot.
func getNewSlotTimestamp(slot uint64) uint64 {
	return 1712816195 + (slot-8832680)*12
}

func currentL1Block(fr *framework.Framework) *types.Block {
	b, err := fr.L1.RPC().BlockByNumber(context.Background(), nil)
	maybe(err)
	return b
}

func maybe(err error) {
	if err != nil {
		panic(err)
	}
}
