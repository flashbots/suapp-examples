package main

import (
	"context"
	"encoding/json"
	"log"
	"math/big"
	"time"

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
	log.Printf("execBlock header: %s", string(execHeaderJSON))
	beaconRes, err := fr.L1Beacon.GetBlockHeader(nil)
	maybe(err)
	beaconBlock := beaconRes.Data[0]
	blockJSON, err := json.Marshal(beaconBlock)
	maybe(err)
	log.Printf("beaconBlock header: %s (root=%s)", string(blockJSON), "")

	targetSlot := beaconBlock.Header.Message.Slot + 1
	epoch := beaconBlock.Header.Message.Epoch()
	proposerDuties, err := fr.L1Beacon.GetProposerDuties(epoch)
	var slotDuty struct { // TODO: replace w/ proper eth2 lib
		Pubkey         hexutil.Bytes `json:"pubkey"`
		ValidatorIndex uint64        `json:"validator_index,string"`
		Slot           uint64        `json:"slot,string"`
	}
	maybe(err)
	// find proposer duties for target slot
	for _, duty := range proposerDuties.Data {
		if duty.Slot == targetSlot {
			slotDuty = duty
			dutyJSON, err := json.Marshal(duty)
			maybe(err)
			log.Printf("found proposer duty for slot %d, %s", targetSlot, dutyJSON)
			maybe(err)
			break
		}
	}
	// decode BLS pubkey to Ethereum address
	blockArgs := types.BuildBlockArgs{
		ProposerPubkey: slotDuty.Pubkey,
		Timestamp:      getNewSlotTimestamp(beaconBlock.Header.Message.Slot),
		FeeRecipient:   common.Address(testAddr1.Address()),
		Parent:         execBlock.Hash(),
		Slot:           targetSlot,
		BeaconRoot:     *&beaconBlock.Root,
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
