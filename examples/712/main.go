package main

import (
	"bytes"
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
	"golang.org/x/crypto/sha3"
)

const MINT_TYPEHASH = "0x686aa0ee2a8dd75ace6f66b3a5e79d3dfd8e25e05a5e494bb85e72214ab37880"
const DOMAIN_SEPARATOR = "0x617661b7ab13ce21150e0a39abe5834762b356e3c643f10c28a3c9331025604a"
const NAME_HASH = keccak256([]byte("SUAVE_NFT"))
const SYMBOL_HASH = keccak256([]byte("NFTEE"))

func main() {
	relayerURL := "localhost:1234"
	go func() {
		log.Fatal(http.ListenAndServe(relayerURL, &relayHandlerExample{}))
	}()

	fr := framework.New()
	contract := fr.DeployContract("path/to/Emitter.json")

	testAddr := framework.GeneratePrivKey()
	fundBalance := big.NewInt(100000000000000000)
	fr.FundAccount(testAddr.Address(), fundBalance)

	privateKeyData := []byte("some_private_key_data")
	contractAddr := contract.Ref(testAddr)
	receipt := contractAddr.SendTransaction("setPrivateKey", []interface{}{privateKeyData}, nil)

	if receipt.Failed() {
		log.Fatalf("setPrivateKey transaction failed: %v", receipt.Err)
	}

	tokenId := big.NewInt(1)
	recipient := common.HexToAddress("0x123...")

	receipt = contractAddr.SendTransaction("signL1MintApproval", []interface{}{tokenId, recipient}, nil)

	if receipt.Failed() {
		log.Fatalf("signL1MintApproval transaction failed: %v", receipt.Err)
	}

	nfteeApprovalEvent := &NFTEEApproval{}
	if err := nfteeApprovalEvent.Unpack(receipt.Logs[0]); err != nil {
		panic(err)
	}

	tokenIdPadded := leftPadBytes(tokenId.Bytes(), 32)
	recipientPadded := recipient.Bytes()

	valid := ValidateEIP712Message(nfteeApprovalEvent.SignedMessage, tokenIdPadded, recipientPadded)
	if !valid {
		log.Fatal("EIP-712 message validation failed")
	}
}

type NFTEEApproval struct {
	SignedMessage []byte
}

func (na *NFTEEApproval) Unpack(log *types.Log) error {
	na.SignedMessage = log.Data
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

func keccak256(data ...[]byte) []byte {
	hasher := sha3.NewLegacyKeccak256()
	for _, b := range data {
		hasher.Write(b)
	}
	return hasher.Sum(nil)
}

func encodePacked(data ...[]byte) []byte {
	var packed []byte
	for _, b := range data {
		packed = append(packed, b...)
	}
	return packed
}

func ValidateEIP712Message(signedMessage, tokenId, recipient []byte) bool {
	tokenIdHash := keccak256(tokenId)
	recipientHash := keccak256(recipient)

	structHash := keccak256(encodePacked(
		MINT_TYPEHASH,
		NAME_HASH,
		SYMBOL_HASH,
		tokenIdHash,
		recipientHash,
	))

	digestHash := keccak256(encodePacked(
		[]byte("\x19\x01"),
		DOMAIN_SEPARATOR,
		structHash,
	))

	return bytes.Equal(digestHash, signedMessage)
}

func leftPadBytes(slice []byte, l int) []byte {
	if len(slice) == l {
		return slice
	}
	padded := make([]byte, l)
	copy(padded[l-len(slice):], slice)
	return padded
}
