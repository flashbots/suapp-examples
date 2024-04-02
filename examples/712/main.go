package main

import (
	"bytes"
	"context"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"math/big"
	"net/http"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
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

	// Deploy SUAVE L1 Contract
	suaveContractAddress, suaveTxHash, suaveSig := deploySuaveEmitter(privKey)
	fmt.Printf("SUAVE Contract deployed at: %s\n", suaveContractAddress.Hex())
	fmt.Printf("SUAVE Transaction Hash: %s\n", suaveTxHash.Hex())

	// create tx signer
	auth, err := bind.NewKeyedTransactorWithChainID(privKey.Priv, big.NewInt(EthChainID)) // Chain ID for Goerli
	if err != nil {
		log.Fatalf("Failed to create authorized transactor: %v", err)
	}

	// Deploy Ethereum L1 Contract
	ethContractAddress, ethTxHash, artifact := deployEthNFTEE(ethClient, privKey.Address(), auth)
	fmt.Printf("Ethereum Contract deployed at: %s\n", ethContractAddress.Hex())
	fmt.Printf("Ethereum Transaction Hash: %s\n", ethTxHash.Hex())

	// Mint NFT with the signature from SUAVE
	tokenID := big.NewInt(NFTEETokenID)
	isMinted, err := mintNFTWithSignature(ethContractAddress, tokenID, privKey.Address(), suaveSig, ethClient, auth, artifact.Abi)
	if err != nil {
		log.Printf("Error minting NFT: %v", err)
	}
	if !isMinted {
		log.Printf("NFT minting failed")
	}
}

func deploySuaveEmitter(privKey *framework.PrivKey) (common.Address, common.Hash, []byte) {
	relayerURL := "localhost:1234"
	go func() {
		log.Fatal(http.ListenAndServe(relayerURL, &relayHandlerExample{}))
	}()

	fr := framework.New()
	contract := fr.Suave.DeployContract("712Emitter.sol/Emitter.json")

	addr := privKey.Address()
	fundBalance := big.NewInt(100000000000000000)
	fr.Suave.FundAccount(addr, fundBalance)

	emitterContract := contract.Ref(privKey)
	skHex := hex.EncodeToString(crypto.FromECDSA(privKey.Priv))

	_ = emitterContract.SendConfidentialRequest("updatePrivateKey", []interface{}{}, []byte(skHex))

	tokenID := big.NewInt(NFTEETokenID)

	// Call createEIP712Digest to generate digestHash
	digestHash := contract.Call("createEIP712Digest", []interface{}{tokenID, addr})

	// Call signL1MintApproval and compare signatures
	receipt := emitterContract.SendConfidentialRequest("signL1MintApproval", []interface{}{tokenID, addr}, nil)
	nfteeApprovalEvent := &NFTEEApproval{}
	if err := nfteeApprovalEvent.Unpack(receipt.Logs[0]); err != nil {
		panic(err)
	}

	// Sign the digest in Go
	goSignature, err := crypto.Sign(digestHash[0].([]byte), privKey.Priv)
	if err != nil {
		log.Fatalf("Error signing message: %v", err)
	}

	if !bytes.Equal(goSignature, nfteeApprovalEvent.SignedMessage) {
		log.Fatal("Signed messages do not match")
	} else {
		fmt.Println("Signed messages match")
	}

	// Extract the signature from SUAVE transaction logs
	var signature []byte
	if len(receipt.Logs) > 0 {
		nfteeApprovalEvent := &NFTEEApproval{}
		if err := nfteeApprovalEvent.Unpack(receipt.Logs[0]); err != nil {
			log.Fatalf("Error unpacking logs: %v", err)
		}
		signature = nfteeApprovalEvent.SignedMessage
	}

	return emitterContract.Raw().Address(), receipt.TxHash, signature
}

func deployEthNFTEE(ethClient *ethclient.Client, signerAddr common.Address, auth *bind.TransactOpts) (common.Address, common.Hash, *framework.Artifact) {
	artifact, err := framework.ReadArtifact("NFTEE.sol/SuaveNFT.json")
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

func mintNFTWithSignature(contractAddress common.Address, tokenID *big.Int, recipient common.Address, signature []byte, client *ethclient.Client, auth *bind.TransactOpts, sabi *abi.ABI) (bool, error) {

	contract := bind.NewBoundContract(contractAddress, *sabi, client, client, client)

	if len(signature) != 65 {
		return false, fmt.Errorf("signature must be 65 bytes long")
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

	tx, err := contract.Transact(auth, "mintNFTWithSignature", tokenID, recipient, v, r, s)
	if err != nil {
		return false, fmt.Errorf("mintNFTWithSignature transaction failed: %v", err)
	}

	// Wait for the transaction to be included
	fmt.Println("Waiting for mint transaction to be included...")
	receipt, err := bind.WaitMined(context.Background(), client, tx)
	if err != nil {
		return false, fmt.Errorf("waiting for mint transaction mining failed: %v", err)
	}

	if receipt.Status != types.ReceiptStatusSuccessful {
		log.Printf("Mint transaction failed: receipt status %v", receipt.Status)
		return false, nil
	}

	fmt.Println("NFT minted successfully, transaction hash:", receipt.TxHash.Hex())
	return true, nil
}

// NFTEEApprovalEventABI is the ABI of the NFTEEApproval event.
var NFTEEApprovalEventABI = `[{"anonymous":false,"inputs":[{"indexed":false,"internalType":"bytes","name":"signedMessage","type":"bytes"}],"name":"NFTEEApproval","type":"event"}]`

// NFTEEApproval is a wrapper for a signed NFTEEApproval message.
type NFTEEApproval struct {
	SignedMessage []byte
}

// Unpack unpacks the log data into the NFTEEApproval struct.
func (na *NFTEEApproval) Unpack(log *types.Log) error {
	eventABI, err := abi.JSON(strings.NewReader(NFTEEApprovalEventABI))
	if err != nil {
		return err
	}

	return eventABI.UnpackIntoInterface(na, "NFTEEApproval", log.Data)
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
