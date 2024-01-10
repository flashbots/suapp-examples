package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/big"
	"net/http"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	relayerURL := "0.0.0.0:1234"
	go func() {
		log.Fatal(http.ListenAndServe(relayerURL, &relayHandlerExample{}))
	}()

	fr := framework.New()
	contract := fr.Suave.DeployContract("ofa-private.sol/OFAPrivate.json")

	// Step 1. Create and fund the accounts we are going to frontrun/backrun
	fmt.Println("1. Create and fund test accounts")

	testAddr1 := framework.GeneratePrivKey()
	testAddr2 := framework.GeneratePrivKey()

	fundBalance := big.NewInt(100000000000000000)
	if err := fr.L1.FundAccount(testAddr1.Address(), fundBalance); err != nil {
		log.Fatal(err)
	}
	if err := fr.L1.FundAccount(testAddr2.Address(), fundBalance); err != nil {
		log.Fatal(err)
	}

	targeAddr := testAddr1.Address()

	ethTxn1, _ := fr.L1.SignTx(testAddr1, &types.LegacyTx{
		To:       &targeAddr,
		Value:    big.NewInt(1000),
		Gas:      21000,
		GasPrice: big.NewInt(670189871),
	})

	ethTxnBackrun, _ := fr.L1.SignTx(testAddr2, &types.LegacyTx{
		To:       &targeAddr,
		Value:    big.NewInt(1000),
		Gas:      21420,
		GasPrice: big.NewInt(670189871),
	})

	// Step 2. Send the initial transaction
	fmt.Println("2. Send dataRecord")

	refundPercent := 10
	bundle := &types.SBundle{
		Txs:             types.Transactions{ethTxn1},
		RevertingHashes: []common.Hash{},
		RefundPercent:   &refundPercent,
	}
	bundleBytes, _ := json.Marshal(bundle)

	// new dataRecord inputs
	receipt := contract.SendTransaction("newOrder", []interface{}{}, bundleBytes)

	hintEvent := &HintEvent{}
	if err := hintEvent.Unpack(receipt.Logs[0]); err != nil {
		panic(err)
	}

	fmt.Println("Hint event id", hintEvent.DataRecordId)

	// Step 3. Send the backrun transaction
	fmt.Println("3. Send backrun")

	backRunBundle := &types.SBundle{
		Txs:             types.Transactions{ethTxnBackrun},
		RevertingHashes: []common.Hash{},
	}
	backRunBundleBytes, _ := json.Marshal(backRunBundle)

	// backrun inputs
	receipt = contract.SendTransaction("newMatch", []interface{}{hintEvent.DataRecordId}, backRunBundleBytes)

	matchEvent := &HintEvent{}
	if err := matchEvent.Unpack(receipt.Logs[0]); err != nil {
		panic(err)
	}

	fmt.Println("Match event id", matchEvent.DataRecordId)

	// Step 4. Emit the batch to the relayer
	fmt.Println("4. Emit batch")

	contract.SendTransaction("emitMatchDataRecordAndHint", []interface{}{"http://172.17.0.1:1234", matchEvent.DataRecordId}, backRunBundleBytes)
}

var hintEventABI abi.Event

func init() {
	artifact, _ := framework.ReadArtifact("ofa-private.sol/OFAPrivate.json")
	hintEventABI = artifact.Abi.Events["HintEvent"]
}

type HintEvent struct {
	DataRecordId [16]byte
	Hint         []byte
}

func (h *HintEvent) Unpack(log *types.Log) error {
	unpacked, err := hintEventABI.Inputs.Unpack(log.Data)
	if err != nil {
		return err
	}
	h.DataRecordId, _ = unpacked[0].([16]byte)
	h.Hint, _ = unpacked[1].([]byte)
	return nil
}

type relayHandlerExample struct{}

func (rl *relayHandlerExample) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	bodyBytes, err := io.ReadAll(r.Body)
	if err != nil {
		panic(err)
	}

	fmt.Println(string(bodyBytes))
}
