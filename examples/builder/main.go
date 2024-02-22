package main

import (
	"encoding/json"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/suave/sdk"

	"github.com/flashbots/suapp-examples/framework"
)

var (
	BundleContract = mustReadArtifact("builder.sol/BundleContract.json")
	// EthBundleSenderContract = mustReadArtifact("builder.sol/EthBundleSenderContract.json")
	BuildEthBlockContract = mustReadArtifact("builder.sol/EthBlockContract.json")
	// EthBlockBidSenderContract = mustReadArtifact("builder.sol/EthBlockBidSenderContract.json")
)

var (
	// testKey is a private key to use for funding a tester account.
	testKey, _ = crypto.HexToECDSA("b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291")

	// testAddr is the Ethereum address of the tester account.
	testAddr = crypto.PubkeyToAddress(testKey.PublicKey)

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

	clt := sdk.NewClient(fr.Suave.RPC().Client(), testKey, fr.KettleAddress)
	_ = fr.Suave.DeployContract("builder.sol/BundleContract.json")
	_ = fr.Suave.DeployContract("builder.sol/EthBlockContract.json")
	// _ = fr.Suave.DeployContract("builder.sol/EthBundleSenderContract.json")
	// _ = fr.Suave.DeployContract("builder.sol/EthBlockBidSenderContract.json")

	bundleBytes := mustCreateBundlePayload(clt)

	targetBlock := uint64(1)

	{ // Send a bundle record
		allowedPeekers := []common.Address{newBlockBidAddress, newBundleBidAddress, buildEthBlockAddress}

		confidentialDataBytes, err := BundleContract.Abi.Methods["fetchConfidentialBundleData"].Outputs.Pack(bundleBytes)
		maybe(err)

		BundleContractI := sdk.GetContract(newBundleBidAddress, BundleContract.Abi, clt)

		_, err = BundleContractI.SendTransaction("newBundle", []interface{}{targetBlock + 1, allowedPeekers, []common.Address{}}, confidentialDataBytes) // XXX:  @ferran
		maybe(err)
	}

	// block := fr.suethSrv.ProgressChain()
	// if size := len(block.Transactions()); size != 1 {
	// 	panic(fmt.Sprintf("expected block of length 1, got %d", size))
	// }

	// {
	// 	ethHead := fr.ethSrv.CurrentBlock()

	// 	payloadArgsTuple := types.BuildBlockArgs{
	// 		ProposerPubkey: []byte{0x42},
	// 		Timestamp:      ethHead.Time + uint64(12),
	// 		FeeRecipient:   common.Address{0x42},
	// 	}

	// 	BuildEthBlockContractI := sdk.GetContract(newBlockBidAddress, BuildEthBlockContract.Abi, Elt)

	// 	_, err = BuildEthBlockContractI.SendTransaction("buildFromPool", []interface{}{payloadArgsTuple, targetBlock + 1}, nil)
	// 	maybe(Err)

	// 	block = fr.suethSrv.ProgressChain()
	// 	if size := len(block.Transactions()); size != 1 {
	// 		panic(fmt.Sprintf("expected block of length 1, got %d", size))
	// 	}
	// }
}

func mustCreateBundlePayload(clt *sdk.Client) []byte {
	tx := mustSignTx(clt)

	bundle := &types.SBundle{
		Txs:             types.Transactions{tx},
		RevertingHashes: []common.Hash{},
	}
	b, err := json.Marshal(bundle)
	maybe(err)

	return b
}

func mustSignTx(clt *sdk.Client) *types.Transaction {
	tx, err := clt.SignTxn(&types.LegacyTx{
		Nonce:    0,
		To:       &testAddr,
		Value:    big.NewInt(1000),
		Gas:      21000,
		GasPrice: big.NewInt(13),
		Data:     []byte{},
	})
	maybe(err)
	return tx
}

func mustReadArtifact(name string) *framework.Artifact {
	a, err := framework.ReadArtifact(name)
	maybe(err)
	return a
}

func maybe(err error) {
	if err != nil {
		panic(err)
	}
}
