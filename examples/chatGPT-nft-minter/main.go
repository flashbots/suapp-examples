package main

import (
	"context"
	"fmt"
	"log"
	"math/big"
	"strings"

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

func generateNFT(cfg *framework.Config, privKey *framework.PrivKey, chatNft *framework.Contract, userPrompts []string) *types.Receipt {
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
		userPrompts,                                // prompts
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

// QueryResult is an event which contains the result of a ChatGPT query on the ChatNFT contract.
type QueryResult struct {
	Result hexutil.Bytes `json:"result"`
}

// NftCreated is the event emitted when an NFT is created.
type NftCreated struct {
	TokenID   *big.Int        `json:"tokenId"`
	Recipient *common.Address `json:"recipient"`
	Signature []byte          `json:"signature"`
}

func parseNFTLogs(chatNft *framework.Contract, receipt *types.Receipt) (*QueryResult, *NftCreated) {
	// Parse logs
	// Find and decode the QueryResult and NFTCreated events
	var queryResult *QueryResult
	var nftCreated *NftCreated
	for _, logEvent := range receipt.Logs {
		switch logEvent.Topics[0].Hex() {
		case chatNft.Abi.Events["QueryResult"].ID.Hex():
			err := chatNft.Abi.Events["QueryResult"].ParseLogToObject(&queryResult, logEvent)
			if err != nil {
				log.Fatalf("Failed to unpack QueryResult event: %v", err)
			}
		case chatNft.Abi.Events["NFTCreated"].ID.Hex():
			err := chatNft.Abi.Events["NFTCreated"].ParseLogToObject(&nftCreated, logEvent)
			if err != nil {
				log.Fatalf("Failed to unpack NFTCreated event: %v", err)
			}
		}
	}
	return queryResult, nftCreated
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
	log.Println("Waiting for contract deployment transaction to be included...")
	receipt, err := bind.WaitMined(context.Background(), ethClient, tx)
	if err != nil {
		log.Fatalf("Error waiting for contract deployment transaction to be included: %v", err)
	}

	if receipt.Status != types.ReceiptStatusSuccessful {
		log.Printf("Contract deployment transaction failed: receipt status %v", receipt.Status)
		return common.Address{}, common.Hash{}, artifact
	}

	return receipt.ContractAddress, tx.Hash(), artifact
}

func mintNFTWithSignature(contractAddress common.Address, tokenID *big.Int, recipient common.Address, content string, signature []byte, client *ethclient.Client, auth *bind.TransactOpts, sabi *abi.ABI) (*types.Receipt, error) {
	contract := bind.NewBoundContract(contractAddress, *sabi, client, client, client)

	if len(signature) != 65 {
		return nil, fmt.Errorf("signature must be 65 bytes long")
	}

	// Extract r, s, and v
	r := [32]byte{}
	s := [32]byte{}
	copy(r[:], signature[:32])   // First 32 bytes
	copy(s[:], signature[32:64]) // Next 32 bytes

	v := signature[64] // Last byte

	// Ethereum signatures are [R || S || V]
	// Where V is 0 or 1, it must be adjusted to 27 or 28
	if v == 0 || v == 1 {
		v += 27
	}

	tx, err := contract.Transact(auth, "mintNFTWithSignature", tokenID, recipient, content, v, r, s)
	if err != nil {
		return nil, fmt.Errorf("mintNFTWithSignature transaction failed: %v", err)
	}
	log.Printf("Mint transaction sent: data=%s", hexutil.Encode(tx.Data()))

	// Wait for the transaction to be included
	log.Println("Waiting for mint transaction to be included...")
	receipt, err := bind.WaitMined(context.Background(), client, tx)
	if err != nil {
		return nil, fmt.Errorf("waiting for mint transaction mining failed: %v", err)
	}

	if receipt.Status != types.ReceiptStatusSuccessful {
		return nil, fmt.Errorf("Mint transaction failed: receipt status %v", receipt.Status)
	}

	log.Println("NFT minted successfully, transaction hash:", receipt.TxHash.Hex())
	return receipt, nil
}

func main() {
	var cfg framework.Config
	if err := envconfig.Process(context.Background(), &cfg); err != nil {
		log.Fatal(err)
	}
	fr := framework.New(framework.WithL1())
	ethClient := fr.L1.RPC()

	log.Printf("Kettle address: %s", fr.KettleAddress)

	// ask user for prompts to feed to ChatGPT
	userPrompts := []string{
		"Render a cat in ASCII art. Return only the result without any other text.",
	}
	fmt.Println("Prompts:")
	for _, prompt := range userPrompts {
		fmt.Printf("  %s\n", prompt)
	}

	// create private key to be used on SUAVE and Eth L1
	privKey := cfg.FundedAccountL1
	log.Printf("SUAVE Signer Address: %s\n", privKey.Address())

	// create tx signer
	auth, err := bind.NewKeyedTransactorWithChainID(privKey.Priv, big.NewInt(EthChainID)) // Chain ID for Goerli
	if err != nil {
		log.Fatalf("Failed to create authorized transactor: %v", err)
	}

	// Deploy SUAVE L1 Contract (ChatNFT.sol)
	chatNft := fr.Suave.DeployContract("ChatNFT.sol/ChatNFT.json")
	log.Printf("ChatNFT deployed on SUAVE (address=%s)", chatNft.Raw().Address())

	// Deploy Ethereum L1 Contract
	nfteeAddress, nfteeTxHash, nfteeArtifact := deployEthNFTEE(ethClient, privKey.Address(), auth)
	log.Printf("NFTEE deployed on L1 (%s): %s\n", nfteeTxHash.Hex(), nfteeAddress.Hex())

	// Create NFT on SUAVE (sign a message to approve a mint on L1)
	receipt := generateNFT(&cfg, privKey, chatNft, userPrompts)
	queryResult, nftCreated := parseNFTLogs(chatNft, receipt)
	log.Printf("QueryResult: %s\n", queryResult.Result.String())
	log.Printf("tokenId: %s\n", nftCreated.TokenID)
	log.Printf("signature: %s\n", common.Bytes2Hex(nftCreated.Signature))

	decodedResult, err := hexutil.Decode(queryResult.Result.String())
	if err != nil {
		log.Fatalf("Failed to decode QueryResult: %v", err)
	}

	// Mint NFT on L1 Ethereum
	log.Printf("content: %s", string(decodedResult))
	receipt, err = mintNFTWithSignature(nfteeAddress, nftCreated.TokenID, *nftCreated.Recipient, string(decodedResult), nftCreated.Signature, ethClient, auth, nfteeArtifact.Abi)
	if err != nil {
		log.Fatalf("Failed to mint NFT: %v", err)
	}
	if receipt.Status == types.ReceiptStatusSuccessful {
		log.Println("NFT minted successfully!")
	} else {
		log.Fatalln("Failed to mint NFT")
	}

	// call tokenData method to view our NFT
	contract := bind.NewBoundContract(nfteeAddress, *nfteeArtifact.Abi, ethClient, ethClient, ethClient)
	var tokenData []interface{}
	contract.Call(&bind.CallOpts{
		Context: context.Background(),
	}, &tokenData, "tokenData", nftCreated.TokenID)
	var tokenURI []interface{}
	contract.Call(&bind.CallOpts{
		Context: context.Background(),
	}, &tokenURI, "tokenURI", nftCreated.TokenID)
	nftData := tokenData[0].(string)
	nftData = strings.ReplaceAll(nftData, "\\\\", "\\")
	nftData = strings.ReplaceAll(nftData, "\\n", "\n")
	log.Printf("Token uri: %s", tokenURI...)
	log.Printf("Token data:\n%s", nftData)
}