package main

import (
	"bytes"
	"context"
	"crypto/ecdsa"
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
)

const (
	// Deployment specific
	PRIV_KEY    = "VALID_PRIVATE_KEY"    // FILL IN TO RUN EXAMPLE
	ETH_RPC_URL = "VALID_ETH_L1_RPC_URL" // FILL IN TO RUN EXAMPLE

	// Contract Specific
	MINT_TYPEHASH    = "0x686aa0ee2a8dd75ace6f66b3a5e79d3dfd8e25e05a5e494bb85e72214ab37880"
	DOMAIN_SEPARATOR = "0x617661b7ab13ce21150e0a39abe5834762b356e3c643f10c28a3c9331025604a"
	ETH_CHAIN_ID     = 5
	NFTEE_TOKEN_ID   = 1
)

func main() {
	// create private key to be used on SUAVE and Eth L1
	privKey := framework.NewPrivKeyFromHex("VALID_PRIVATE_KEY")
	fmt.Printf("SUAVE Signer Address: %s\n", privKey.Address())

	// Deploy SUAVE L1 Contract
	suaveContractAddress, suaveTxHash, suaveSig := deploySuaveContract(privKey)

	fmt.Printf("SUAVE Contract deployed at: %s\n", suaveContractAddress.Hex())
	fmt.Printf("SUAVE Transaction Hash: %s\n", suaveTxHash.Hex())

	// Deploy Ethereum L1 Contract and Mint NFT
	ethContractAddress, ethTxHash, ok := deployEthContractAndMint(privKey.Address(), suaveSig, privKey.Priv)

	fmt.Printf("Ethereum Contract deployed at: %s\n", ethContractAddress.Hex())
	fmt.Printf("Ethereum Transaction Hash: %s\n", ethTxHash.Hex())

	// Check if NFT was minted
	if !ok {
		panic("NFTEE minting on L1 failed")
	}

}

func deploySuaveContract(privKey *framework.PrivKey) (common.Address, common.Hash, []byte) {
	relayerURL := "localhost:1234"
	go func() {
		log.Fatal(http.ListenAndServe(relayerURL, &relayHandlerExample{}))
	}()

	fr := framework.New()
	contract := fr.DeployContract("712Emitter.sol/Emitter.json")

	addr := privKey.Address()
	fundBalance := big.NewInt(100000000000000000)
	fr.FundAccount(addr, fundBalance)

	contractAddr := contract.Ref(privKey)
	skHex := hex.EncodeToString(crypto.FromECDSA(privKey.Priv))

	receipt := contractAddr.SendTransaction("updatePrivateKey", []interface{}{}, []byte(skHex))

	tokenId := big.NewInt(NFTEE_TOKEN_ID)

	// Call createEIP712Digest to generate digestHash
	digestHash := contract.Call("createEIP712Digest", []interface{}{tokenId, addr})

	// Call signL1MintApproval and compare signatures
	receipt = contractAddr.SendTransaction("signL1MintApproval", []interface{}{tokenId, addr}, nil)
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

	return contractAddr.Address(), receipt.TxHash, signature
}

func deployEthContractAndMint(suaveSignerAddr common.Address, suaveSignature []byte, privKey *ecdsa.PrivateKey) (common.Address, common.Hash, bool) {
	ethClient, err := ethclient.Dial(ETH_RPC_URL)
	if err != nil {
		log.Fatalf("Failed to connect to the Ethereum client: %v", err)
	}

	auth, err := bind.NewKeyedTransactorWithChainID(privKey, big.NewInt(ETH_CHAIN_ID)) // Chain ID for Goerli
	if err != nil {
		log.Fatalf("Failed to create authorized transactor: %v", err)
	}

	artifact, err := framework.ReadArtifact("NFTEE.sol/SuaveNFT.json")
	if err != nil {
		panic(err)
	}

	// Deploy contract with SUAVE signer address as a constructor argument
	_, tx, _, err := bind.DeployContract(auth, *artifact.Abi, artifact.Code, ethClient, suaveSignerAddr)
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
		return common.Address{}, common.Hash{}, false
	}

	fmt.Println("Contract deployed, address:", receipt.ContractAddress.Hex())

	// Mint NFT with the signature from SUAVE
	tokenId := big.NewInt(NFTEE_TOKEN_ID)
	isMinted, err := mintNFTWithSignature(receipt.ContractAddress, tokenId, suaveSignerAddr, suaveSignature, ethClient, auth, artifact.Abi)
	if err != nil {
		log.Printf("Error minting NFT: %v", err)
		return receipt.ContractAddress, tx.Hash(), false
	}

	return receipt.ContractAddress, tx.Hash(), isMinted
}

func mintNFTWithSignature(contractAddress common.Address, tokenId *big.Int, recipient common.Address, signature []byte, client *ethclient.Client, auth *bind.TransactOpts, sabi *abi.ABI) (bool, error) {

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

	tx, err := contract.Transact(auth, "mintNFTWithSignature", tokenId, recipient, v, r, s)
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

type NFTEEApproval struct {
	SignedMessage []byte
}

func (na *NFTEEApproval) Unpack(log *types.Log) error {
	eventABI, err := abi.JSON(strings.NewReader(NFTEEApprovalEventABI))
	if err != nil {
		return err
	}

	return eventABI.UnpackIntoInterface(na, "NFTEEApproval", log.Data)
}

func encodePacked(data ...[]byte) []byte {
	var packed []byte
	for _, b := range data {
		packed = append(packed, b...)
	}
	return packed
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
