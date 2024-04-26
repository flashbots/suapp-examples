package main

import (
	"context"
	"fmt"
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/flashbots/suapp-examples/framework"
	envconfig "github.com/sethvargo/go-envconfig"
)

// Contract-specific constants
const (
	MintTypehash = "0x686aa0ee2a8dd75ace6f66b3a5e79d3dfd8e25e05a5e494bb85e72214ab37880"
	EthChainID   = 5
	NFTEETokenID = 1
)

func generateNFT(cfg *framework.Config, privKey *framework.PrivKey, chatNft *framework.Contract) *types.Receipt {
	var (
		mintParamsType, _ = abi.NewType("tuple", "MintNFTConfidentialParams", []abi.ArgumentMarshaling{
			{Name: "privateKey", Type: "string"},
			{Name: "recipient", Type: "address"},
			{Name: "prompts", Type: "string[]"},
			{Name: "openaiApiKey", Type: "string"},
		})

		args = abi.Arguments{
			{Type: mintParamsType, Name: "params"},
		}
	)

	confidentialInputs := struct {
		PrivateKey string         `json:"privateKey" abi:"privateKey"`
		Recipient  common.Address `json:"recipient" abi:"recipient"`
		Prompts    []string       `json:"prompts" abi:"prompts"`
		OpenaiKey  string         `json:"openaiApiKey" abi:"openaiApiKey"`
	}{
		common.Bytes2Hex(privKey.MarshalPrivKey()), // privateKey
		privKey.Address(),                          // recipient
		[]string{"What is the meaning of life?"},   // prompts
		cfg.OpenAIKey,                              // openaiKey
	}
	log.Printf("Prompt: %s\n", confidentialInputs.Prompts)
	confBytes, err := args.Pack(confidentialInputs)
	if err != nil {
		log.Fatalf("Failed to pack confidential inputs: %v", err)
	}

	receipt := chatNft.SendConfidentialRequest("mintNFT", nil, confBytes)
	return receipt
}

func parseNFTLogs(chatNft *framework.Contract, receipt *types.Receipt) {
	// Parse logs
	// Find and decode the QueryResult and NFTCreated events
	for _, logEvent := range receipt.Logs {
		switch logEvent.Topics[0].Hex() {
		case chatNft.Abi.Events["QueryResult"].ID.Hex():
			var queryResult struct {
				Result hexutil.Bytes `json:"result"`
			}
			err := chatNft.Abi.Events["QueryResult"].ParseLogToObject(&queryResult, logEvent)
			if err != nil {
				log.Fatalf("Failed to unpack QueryResult event: %v", err)
			}
			fmt.Printf("QueryResult: %s\n", queryResult.Result)
		case chatNft.Abi.Events["NFTCreated"].ID.Hex():
			var nftCreated struct {
				TokenID   *big.Int `json:"tokenId"`
				Signature []byte   `json:"signature"`
			}
			err := chatNft.Abi.Events["NFTCreated"].ParseLogToObject(&nftCreated, logEvent)
			if err != nil {
				log.Fatalf("Failed to unpack NFTCreated event: %v", err)
			}
			fmt.Printf("Generated NFT. (id=%s) (signature=%s)\n", nftCreated.TokenID, common.Bytes2Hex(nftCreated.Signature))
		}
	}
}

func deployEthNFTEE(ethClient *ethclient.Client, signerAddr common.Address, auth *bind.TransactOpts) (common.Address, common.Hash, *framework.Artifact) {
	artifact, err := framework.ReadArtifact("NFTEE2.sol/SuaveNFT.json")
	if err != nil {
		panic(err)
	}

	// Deploy contract with signer address as a constructor argument
	_, tx, _, err := bind.DeployContract(auth, *artifact.Abi, artifact.Code, ethClient, signerAddr)
	if err != nil {
		log.Fatalf("Failed to deploy new contract: %v", err)
	}

	// Wait for the transaction to be included
	fmt.Println("Waiting for contract deployment transaction to be included...")
	receipt, err := bind.WaitMined(context.Background(), ethClient, tx)
	if err != nil {
		log.Fatalf("Error waiting for contract deployment transaction to be included: %v", err)
	}

	if receipt.Status != types.ReceiptStatusSuccessful {
		log.Printf("Contract deployment transaction failed: receipt status %v", receipt.Status)
		return common.Address{}, common.Hash{}, artifact
	}

	fmt.Println("Contract deployed, address:", receipt.ContractAddress.Hex())

	return receipt.ContractAddress, tx.Hash(), artifact
}

func main() {
	var cfg framework.Config
	if err := envconfig.Process(context.Background(), &cfg); err != nil {
		log.Fatal(err)
	}
	frL1 := framework.New(framework.WithL1())
	ethClient := frL1.L1.RPC()

	// create private key to be used on SUAVE and Eth L1
	privKey := cfg.FundedAccountL1
	fmt.Printf("SUAVE Signer Address: %s\n", privKey.Address())

	// create tx signer
	auth, err := bind.NewKeyedTransactorWithChainID(privKey.Priv, big.NewInt(EthChainID)) // Chain ID for Goerli
	if err != nil {
		log.Fatalf("Failed to create authorized transactor: %v", err)
	}

	// Deploy SUAVE L1 Contract (ChatNFT.sol)
	chatNft := frL1.Suave.DeployContract("ChatNFT.sol/ChatNFT.json")

	// Deploy Ethereum L1 Contract
	ethContractAddress, ethTxHash, artifact := deployEthNFTEE(ethClient, privKey.Address(), auth)
	fmt.Printf("Ethereum Contract deployed at: %s\n", ethContractAddress.Hex())
	fmt.Printf("Ethereum Transaction Hash: %s\n", ethTxHash.Hex())
	if artifact != nil {
		fmt.Printf("Artifact: OK\n")
	} else {
		log.Fatalf("Artifact is nil")
	}

	// Get signature to mint NFT
	/* struct MintNFTConfidentialParams {
	    bytes32 privateKey;
	    address recipient;
	    string[] prompts;
	    string openaiApiKey;
	}*/
	receipt := generateNFT(&cfg, privKey, chatNft)
	parseNFTLogs(chatNft, receipt)
}
