package main

import (
	"context"
	"encoding/json"
	"log"
	"math/big"
	"strings"
	"time"

	eth2 "github.com/attestantio/go-eth2-client"
	v1 "github.com/attestantio/go-eth2-client/api/v1"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/flashbots/suapp-examples/framework"
)

var buildEthBlockAddress = common.HexToAddress("0x42100001")

func buildBlock(fr *framework.Framework, payloadAttributes *v1.PayloadAttributesEvent) {
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

	targetBlock := payloadAttributes.Data.ParentBlockNumber + 1
	targetSlot := payloadAttributes.Data.ProposalSlot

	{ // Send a bundle to the builder
		decryptionCondition := targetBlock
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

	validators, err := fr.L1Relay.GetValidators()
	maybe(err)
	var slotDuty framework.BuilderGetValidatorsResponseEntry
	for _, validator := range *validators {
		if validator.Slot == uint64(targetSlot) {
			slotDuty = validator
			log.Printf("found proposer duty for slot %d, %v", targetSlot, slotDuty)
			break
		}
	}

	proposerPubkey, err := slotDuty.Entry.Message.Pubkey.MarshalJSON()
	maybe(err)

	// map payloadAttributes.Data.V3.Withdrawals to types.Withdrawals
	withdrawals := make([]*types.Withdrawal, len(payloadAttributes.Data.V3.Withdrawals))
	for i, withdrawal := range payloadAttributes.Data.V3.Withdrawals {
		withdrawals[i] = &types.Withdrawal{
			Index:     uint64(withdrawal.Index),
			Validator: uint64(withdrawal.ValidatorIndex),
			Address:   common.Address(withdrawal.Address),
			Amount:    uint64(withdrawal.Amount),
		}
	}

	blockArgs := types.BuildBlockArgs{
		Slot:           uint64(targetSlot),
		Parent:         common.Hash(payloadAttributes.Data.ParentBlockHash),
		Timestamp:      payloadAttributes.Data.V3.Timestamp,
		Random:         payloadAttributes.Data.V3.PrevRandao,
		FeeRecipient:   common.Address(slotDuty.Entry.Message.FeeRecipient),
		GasLimit:       uint64(slotDuty.Entry.Message.GasLimit),
		ProposerPubkey: proposerPubkey,
		BeaconRoot:     common.Hash(payloadAttributes.Data.ParentBlockRoot),
		Withdrawals:    withdrawals,
	}

	{ // Signal to the builder that it's time to build a new block
		startTime := time.Now().UnixMilli()
		receipt := ethBlockContract.SendConfidentialRequest("buildFromPool", []any{blockArgs, targetBlock}, nil)
		maybe(err)

		duration := time.Now().UnixMilli() - startTime
		log.Printf("finished buildFromPool in %d ms", duration)

		for _, receiptLog := range receipt.Logs {
			buildEvent := ethBlockContract.Abi.Events["BuilderBoostBidEvent"]
			if receiptLog.Topics[0] == buildEvent.ID {
				bids, err := buildEvent.Inputs.Unpack(receiptLog.Data)
				maybe(err)
				blockBidID = bids[0].([16]byte)
				break
			}
		}
	}

	{ // Submit block to the relay
		log.Printf("blockBidID: %s", hexutil.Encode(blockBidID[:]))

		startTime := time.Now().UnixMilli()
		var receipt *types.Receipt
		for {
			receipt, err = ethBlockContract.MaybeSendConfidentialRequest("submitToRelay", []any{
				blockArgs,
				blockBidID,
				"",
			}, nil)
			if err == nil {
				break
			} else {
				log.Printf("submitToRelay error: %s. retrying in 3 seconds...", err.Error())
				if strings.Contains(err.Error(), "payload attributes not (yet) known") {
					time.Sleep(3 * time.Second)
				} else {
					panic(err)
				}
			}
		}

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

func main() {
	fr := framework.New(framework.WithL1())

	eventProvider := eth2.EventsProvider(fr.L1Beacon)

	// subscribe to the beacon chain event `payload_attributes`
	err := eventProvider.Events(context.Background(), []string{"payload_attributes"}, func(e *v1.Event) {
		log.Printf("payload_attributes received: %v", e)
		payloadAttributes := e.Data.(*v1.PayloadAttributesEvent)

		buildBlock(fr, payloadAttributes)
	})
	maybe(err)

	// wait forever
	select {}
}

func maybe(err error) {
	if err != nil {
		panic(err)
	}
}
