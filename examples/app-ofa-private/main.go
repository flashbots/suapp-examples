package main

import (
	"encoding/json"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"net/http/httptest"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fakeRelayer := httptest.NewServer(&relayHandlerExample{})
	defer fakeRelayer.Close()

	fr := framework.New()
	contract := fr.DeployContract("ofa-private.sol/OFAPrivate.json")

	// Step 1. Create and fund the accounts we are going to frontrun/backrun
	fmt.Println("1. Create and fund test accounts")

	testAddr1 := framework.GeneratePrivKey()
	testAddr2 := framework.GeneratePrivKey()

	fundBalance := big.NewInt(100000000000000000)
	fr.FundAccount(testAddr1.Address(), fundBalance)
	fr.FundAccount(testAddr2.Address(), fundBalance)

	targeAddr := testAddr1.Address()

	ethTxn1, _ := fr.SignTx(testAddr1, &types.LegacyTx{
		To:       &targeAddr,
		Value:    big.NewInt(1000),
		Gas:      21000,
		GasPrice: big.NewInt(13),
	})

	ethTxnBackrun, _ := fr.SignTx(testAddr2, &types.LegacyTx{
		To:       &targeAddr,
		Value:    big.NewInt(1000),
		Gas:      21420,
		GasPrice: big.NewInt(13),
	})

	// Step 2. Send the initial transaction
	fmt.Println("2. Send bid")

	refundPercent := 10
	bundle := &types.SBundle{
		Txs:             types.Transactions{ethTxn1},
		RevertingHashes: []common.Hash{},
		RefundPercent:   &refundPercent,
	}
	bundleBytes, _ := json.Marshal(bundle)

	// new bid inputs
	contractAddr1 := contract.Ref(testAddr1)
	receipt := contractAddr1.SendTransaction("newOrder", []interface{}{}, bundleBytes)

	hintEvent := &HintEvent{}
	if err := hintEvent.Unpack(receipt.Logs[0]); err != nil {
		panic(err)
	}

	fmt.Println("Hint event id", hintEvent.BidId)

	// Step 3. Send the backrun transaction
	fmt.Println("3. Send backrun")

	backRunBundle := &types.SBundle{
		Txs:             types.Transactions{ethTxnBackrun},
		RevertingHashes: []common.Hash{},
	}
	backRunBundleBytes, _ := json.Marshal(backRunBundle)

	// backrun inputs
	contractAddr2 := contract.Ref(testAddr2)
	receipt = contractAddr2.SendTransaction("newMatch", []interface{}{hintEvent.BidId}, backRunBundleBytes)

	matchEvent := &HintEvent{}
	if err := matchEvent.Unpack(receipt.Logs[0]); err != nil {
		panic(err)
	}

	fmt.Println("Match event id", matchEvent.BidId)

	// Step 4. Emit the batch to the relayer
	fmt.Println("Step 4. Emit batch")

	contract.SendTransaction("emitMatchBidAndHint", []interface{}{fakeRelayer.URL, matchEvent.BidId}, backRunBundleBytes)
}

var hintEventABI abi.Event

func init() {
	artifact, _ := framework.ReadArtifact("ofa-private.sol/OFAPrivate.json")
	hintEventABI = artifact.Abi.Events["HintEvent"]
}

type HintEvent struct {
	BidId [16]byte
	Hint  []byte
}

func (h *HintEvent) Unpack(log *types.Log) error {
	unpacked, err := hintEventABI.Inputs.Unpack(log.Data)
	if err != nil {
		return err
	}
	h.BidId = unpacked[0].([16]byte)
	h.Hint = unpacked[1].([]byte)
	return nil
}

type relayHandlerExample struct {
}

func (rl *relayHandlerExample) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	bodyBytes, err := io.ReadAll(r.Body)
	if err != nil {
		panic(err)
	}

	fmt.Println(string(bodyBytes))
}
