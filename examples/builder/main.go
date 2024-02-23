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

var (
	// // testKey is a private key to use for funding a tester account.
	// testKey, _ = crypto.HexToECDSA("b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291")

	// // testAddr is the Ethereum address of the tester account.
	// testAddr = crypto.PubkeyToAddress(testKey.PublicKey)

	/* precompiles */
	// isConfidentialAddress     = common.HexToAddress("0x42010000")
	// fetchBidsAddress          = common.HexToAddress("0x42030001")
	// fillMevShareBundleAddress = common.HexToAddress("0x43200001")

	// signEthTransaction = common.HexToAddress("0x40100001")
	// signMessage        = common.HexToAddress("0x40100003")

	// simulateBundleAddress = common.HexToAddress("0x42100000")
	buildEthBlockAddress = common.HexToAddress("0x42100001")

	// privateKeyGen = common.HexToAddress("0x53200003")

	/* contracts */
	newBundleBidAddress = common.HexToAddress("0x642300000")
	newBlockBidAddress  = common.HexToAddress("0x642310000")
	// mevShareAddress     = common.HexToAddress("0x642100073")
)

func main() {
	fr := framework.New()

	testAddr1 := framework.GeneratePrivKey()
	log.Printf("Test address 1: %s", testAddr1.Address().Hex())

	fundBalance := big.NewInt(100000000000000000)
	maybe(fr.L1.FundAccount(testAddr1.Address(), fundBalance))

	targeAddr := testAddr1.Address()
	tx, err := fr.L1.SignTx(testAddr1, &types.LegacyTx{
		To:       &targeAddr,
		Value:    big.NewInt(1000),
		Gas:      21000,
		GasPrice: big.NewInt(670189871),
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

	targetBlock := uint64(1)

	{ // Send a bundle record
		allowedPeekers := []common.Address{newBlockBidAddress, newBundleBidAddress, buildEthBlockAddress, bundleContract.Address()}

		confidentialDataBytes, err := bundleContract.Abi.Methods["fetchConfidentialBundleData"].Outputs.Pack(bundleBytes)
		maybe(err)

		_ = bundleContract.SendTransaction("newBundle", []interface{}{targetBlock + 1, allowedPeekers, []common.Address{}}, confidentialDataBytes)
	}

	// block := fr.suethSrv.ProgressChain()
	// if size := len(block.Transactions()); size != 1 {
	// 	panic(fmt.Sprintf("expected block of length 1, got %d", size))
	// }

	{
		ethHead, err := fr.L1.RPC().BlockNumber(context.TODO())
		maybe(err)

		payloadArgsTuple := types.BuildBlockArgs{
			ProposerPubkey: []byte{0x42},
			Timestamp:      ethHead + uint64(12),
			FeeRecipient:   common.Address{0x42},
		}

		_ = ethBlockContract.SendTransaction("buildFromPool", []interface{}{payloadArgsTuple, targetBlock + 1}, nil)
		maybe(err)

		// block = fr.suethSrv.ProgressChain()
		// if size := len(block.Transactions()); size != 1 {
		// 	panic(fmt.Sprintf("expected block of length 1, got %d", size))
		// }
	}
}

func maybe(err error) {
	if err != nil {
		panic(err)
	}
}
