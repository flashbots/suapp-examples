package main

import (
	"context"
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
	envconfig "github.com/sethvargo/go-envconfig"
)

type config struct {
	BuilderURL string `env:"BUILDER_URL, default=local"`
}

func main() {
	var cfg config
	if err := envconfig.Process(context.Background(), &cfg); err != nil {
		log.Fatal(err)
	}

	if cfg.BuilderURL == "local" {
		// '172.17.0.1' is the default docker host IP that a docker container can
		// use to connect with a service running on the host machine.
		cfg.BuilderURL = "http://172.17.0.1:1234"

		go func() {
			log.Fatal(http.ListenAndServe("0.0.0.0:1234", &relayHandlerExample{}))
		}()
	}

	fr := framework.New(framework.WithL1())
	contract := fr.Suave.DeployContract("ofa-private.sol/OFAPrivate.json")

	// Step 1. Create and fund the accounts we are going to frontrun/backrun
	fmt.Println("1. Create and fund test accounts")

	testAddr1 := framework.GeneratePrivKey()
	testAddr2 := framework.GeneratePrivKey()

	log.Printf("Test address 1: %s", testAddr1.Address().Hex())
	log.Printf("Test address 2: %s", testAddr2.Address().Hex())

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

	target, err := fr.L1.RPC().BlockNumber(context.Background())
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("Latest goerli block: %d", target)

	// new dataRecord inputs
	receipt := contract.SendConfidentialRequest("newOrder", []interface{}{target + 1}, bundleBytes)

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

	target, err = fr.L1.RPC().BlockNumber(context.Background())
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("Latest goerli block: %d", target)

	// backrun inputs
	receipt = contract.SendConfidentialRequest("newMatch", []interface{}{hintEvent.DataRecordId, target + 1}, backRunBundleBytes)

	matchEvent := &HintEvent{}
	if err := matchEvent.Unpack(receipt.Logs[0]); err != nil {
		panic(err)
	}

	fmt.Println("Match event id", matchEvent.DataRecordId)

	// Step 4. Emit the batch to the relayer and parse the output
	fmt.Println("4. Emit batch")

	receipt = contract.SendConfidentialRequest("emitMatchDataRecordAndHint", []interface{}{cfg.BuilderURL, matchEvent.DataRecordId}, backRunBundleBytes)
	bundleHash, err := decodeBundleEmittedOutput(receipt)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println("Bundle hash", bundleHash)
}

var (
	hintEventABI       abi.Event
	bundleEmittedEvent abi.Event
)

func init() {
	artifact, _ := framework.ReadArtifact("ofa-private.sol/OFAPrivate.json")
	hintEventABI = artifact.Abi.Events["HintEvent"]
	bundleEmittedEvent = artifact.Abi.Events["BundleEmitted"]
}

type HintEvent struct {
	DataRecordId [16]byte
	Hint         []byte
}

func (h *HintEvent) Unpack(log *types.Log) error {
	res, err := hintEventABI.ParseLog(log)
	if err != nil {
		return err
	}
	h.DataRecordId, _ = res["id"].([16]byte)
	h.Hint, _ = res["hint"].([]byte)
	return nil
}

func decodeBundleEmittedOutput(receipt *types.Receipt) (string, error) {
	bundleEmitted, _ := bundleEmittedEvent.ParseLog(receipt.Logs[0])
	response, _ := bundleEmitted["bundleRawResponse"].(string)

	log.Printf("mev_share response: %s", response)

	var bundleResponse []struct {
		Result struct {
			BundleHash string
		}
	}

	if err := json.Unmarshal([]byte(response), &bundleResponse); err != nil {
		return "", err
	}

	return bundleResponse[0].Result.BundleHash, nil
}

type relayHandlerExample struct{}

func (rl *relayHandlerExample) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	bodyBytes, err := io.ReadAll(r.Body)
	if err != nil {
		panic(err)
	}

	fmt.Println(string(bodyBytes))
	w.Write([]byte(`[{"id":1,"result":{"bundleHash":"0x8b3302e3ffe34149ba5b2e801f21d4227faf6c7860a4e03ace2b8a6bbac54f07"},"jsonrpc":"2.0"}]`))
}
