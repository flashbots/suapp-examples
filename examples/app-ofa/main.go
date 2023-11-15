package main

import (
	"encoding/json"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"net/http/httptest"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/ethereum/go-ethereum/suave/sdk"
	"github.com/flashbots/suapp-examples/framework"
)

var artifact *framework.Artifact

func main() {
	fakeRelayer := httptest.NewServer(&relayHandlerExample{})
	defer fakeRelayer.Close()

	contract, err := framework.DeployContract("ofa.sol/OFA.json")
	if err != nil {
		panic(err)
	}

	artifact, _ = framework.ReadArtifact("ofa.sol/OFA.json")

	rpc, _ := rpc.Dial("http://localhost:8545")

	testAddr1 := framework.GeneratePrivKey()
	testAddr2 := framework.GeneratePrivKey()

	// we use the sdk.Client for the Sign function though we only
	// want to sign simple ethereum transactions and not compute requests
	cltAcct1 := sdk.NewClient(rpc, testAddr1.Priv, common.Address{})
	cltAcct2 := sdk.NewClient(rpc, testAddr2.Priv, common.Address{})

	targeAddr := testAddr1.Address()

	ethTxn1, err := cltAcct1.SignTxn(&types.LegacyTx{
		To:       &targeAddr,
		Value:    big.NewInt(1000),
		Gas:      21000,
		GasPrice: big.NewInt(13),
	})
	if err != nil {
		panic(err)
	}

	ethTxnBackrun, err := cltAcct2.SignTxn(&types.LegacyTx{
		To:       &targeAddr,
		Value:    big.NewInt(1000),
		Gas:      21420,
		GasPrice: big.NewInt(13),
	})
	if err != nil {
		panic(err)
	}

	/* SEND BID */

	refundPercent := 10
	bundle := &types.SBundle{
		Txs:             types.Transactions{ethTxn1},
		RevertingHashes: []common.Hash{},
		RefundPercent:   &refundPercent,
	}
	bundleBytes, _ := json.Marshal(bundle)

	// new bid inputs
	txnResult, err := contract.SendTransaction("newOrder", []interface{}{}, bundleBytes)
	if err != nil {
		panic(err)
	}
	receipt, err := txnResult.Wait()
	if err != nil {
		panic(err)
	}
	if receipt.Status == 0 {
		panic("bad")
	}

	fmt.Println(receipt.Logs)

	hintEvent := &HintEvent{}
	if err := hintEvent.Unpack(receipt.Logs[0]); err != nil {
		panic(err)
	}

	fmt.Println("Hint event", hintEvent)

	/* SEND BACKRUN */

	backRunBundle := &types.SBundle{
		Txs:             types.Transactions{ethTxnBackrun},
		RevertingHashes: []common.Hash{},
	}
	backRunBundleBytes, _ := json.Marshal(backRunBundle)

	// backrun inputs
	txnResult, err = contract.SendTransaction("newMatch", []interface{}{hintEvent.BidId}, backRunBundleBytes)
	if err != nil {
		panic(err)
	}
	receipt, err = txnResult.Wait()
	if err != nil {
		panic(err)
	}
	if receipt.Status == 0 {
		panic("bad")
	}

	matchEvent := &HintEvent{}
	if err := matchEvent.Unpack(receipt.Logs[0]); err != nil {
		panic(err)
	}

	fmt.Println("Match event", matchEvent)

	// Send the request to the relay
	// backrun inputs
	txnResult, err = contract.SendTransaction("emitMatchBidAndHint", []interface{}{fakeRelayer.URL, matchEvent.BidId}, backRunBundleBytes)
	if err != nil {
		panic(err)
	}
	receipt, err = txnResult.Wait()
	if err != nil {
		panic(err)
	}
	if receipt.Status == 0 {
		panic("bad")
	}
}

type HintEvent struct {
	BidId [16]byte
	Hint  []byte
}

func (h *HintEvent) Unpack(log *types.Log) error {
	unpacked, err := artifact.Abi.Events["HintEvent"].Inputs.Unpack(log.Data)
	if err != nil {
		return err
	}
	h.BidId = unpacked[0].([16]byte)
	h.Hint = unpacked[1].([]byte)
	return nil
}

type BidEvent struct {
	BidId               [16]byte
	DecryptionCondition uint64
	AllowedPeekers      []common.Address
}

func (b *BidEvent) Unpack(log *types.Log) error {
	unpacked, err := artifact.Abi.Events["BidEvent"].Inputs.Unpack(log.Data)
	if err != nil {
		return err
	}
	b.BidId = unpacked[0].([16]byte)
	b.DecryptionCondition = unpacked[1].(uint64)
	b.AllowedPeekers = unpacked[2].([]common.Address)
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
