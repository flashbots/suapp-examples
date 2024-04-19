package main

import (
	"context"
	"encoding/json"
	"log"
	"math/big"
	"time"

	"github.com/attestantio/go-eth2-client/api"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
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

		// get current timestamp from system
		startTime := time.Now().UnixMilli()
		_ = bundleContract.SendConfidentialRequest("newBundle", newBundleArgs, confidentialDataBytes)
		duration := time.Now().UnixMilli() - startTime
		log.Printf("finished newBundle in %d ms", duration)
	}

	var blockBidID [16]byte
	// get latest blocks (exec & beacon) from live chain
	execBlock, err := fr.L1.RPC().BlockByNumber(context.Background(), nil)
	maybe(err)
	execHeaderJSON, err := execBlock.Header().MarshalJSON()
	maybe(err)
	log.Printf("execBlock header: %s", string(execHeaderJSON))
	beaconRes, err := fr.L1Beacon.BeaconBlockHeader(
		context.Background(),
		&api.BeaconBlockHeaderOpts{
			Block: "head",
		},
	)
	log.Printf("beaconRes: %v", beaconRes)
	maybe(err)
	beaconHeader := beaconRes.Data.Header
	targetSlot := beaconHeader.Message.Slot + 1
	beaconRoot := beaconRes.Data.Root

	validators, err := fr.L1Relay.GetValidators()
	var slotDuty framework.BuilderGetValidatorsResponseEntry
	maybe(err)
	for _, validator := range *validators {
		if validator.Slot == uint64(targetSlot) {
			slotDuty = validator
			log.Printf("found proposer duty for slot %d, %v", targetSlot, slotDuty)
			break
		}
	}

	// decode BLS pubkey to Ethereum address
	proposerPubkey, err := slotDuty.Entry.Message.Pubkey.MarshalJSON()
	maybe(err)
	blockArgs := types.BuildBlockArgs{
		ProposerPubkey: proposerPubkey,
		Timestamp:      getNewSlotTimestamp(uint64(targetSlot)),
		FeeRecipient:   common.Address(slotDuty.Entry.Message.FeeRecipient),
		Parent:         execBlock.Hash(),
		Slot:           uint64(targetSlot),
		BeaconRoot:     common.Hash(beaconRoot),
	}

	{ // Signal to the builder that it's time to build a new block
		startTime := time.Now().UnixMilli()
		receipt := ethBlockContract.SendConfidentialRequest("buildFromPool", []any{blockArgs, targetBlock.NumberU64() + 1}, nil)
		duration := time.Now().UnixMilli() - startTime
		log.Printf("finished buildFromPool in %d ms", duration)
		maybe(err)

		for _, receiptLog := range receipt.Logs {
			buildEvent := ethBlockContract.Abi.Events["BuilderBoostBidEvent"]
			if receiptLog.Topics[0] == buildEvent.ID {
				bids, err := buildEvent.Inputs.Unpack(receiptLog.Data)
				maybe(err)
				blockBidID = bids[0].([16]byte)
				break
			}
		}
		log.Printf("finished buildFromPool")
	}

	{ // Submit block to the relay
		log.Printf("blockBidID: %s", hexutil.Encode(blockBidID[:]))
		startTime := time.Now().UnixMilli()
		receipt := ethBlockContract.SendConfidentialRequest("submitToRelay", []any{
			blockArgs,
			blockBidID,
			"",
		}, nil)
		duration := time.Now().UnixMilli() - startTime
		log.Printf("finished submitToRelay in %d ms", duration)

		// get logs from ccr
		for _, receiptLog := range receipt.Logs {
			if receiptLog.Topics[0] == ethBlockContract.Abi.Events["SubmitBlockResponse"].ID {
				log.Printf("SubmitBlockResponse: %s", receiptLog.Data)
			}
		}
	}
}

// Calculate the timestamp for a new slot.
func getNewSlotTimestamp(targetSlot uint64) uint64 {
	return 1712816195 + (targetSlot-8832681)*12
} // lol

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
