package main

import (
	"bytes"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"math/big"
	"net/http"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/flashbots/suapp-examples/framework"
	"golang.org/x/crypto/sha3"
)

const MINT_TYPEHASH = "0x686aa0ee2a8dd75ace6f66b3a5e79d3dfd8e25e05a5e494bb85e72214ab37880"
const DOMAIN_SEPARATOR = "0x617661b7ab13ce21150e0a39abe5834762b356e3c643f10c28a3c9331025604a"

func main() {

	relayerURL := "localhost:1234"
	go func() {
		log.Fatal(http.ListenAndServe(relayerURL, &relayHandlerExample{}))
	}()

	fr := framework.New()
	contract := fr.DeployContract("712Emitter.sol/Emitter.json")

	privKey := framework.GeneratePrivKey()
	testAddr := privKey.Address()
	fundBalance := big.NewInt(100000000000000000)
	fr.FundAccount(testAddr, fundBalance)

	contractAddr := contract.Ref(privKey)
	skHex := hex.EncodeToString(crypto.FromECDSA(privKey.Priv))

	receipt := contractAddr.SendTransaction("updatePrivateKey", []interface{}{}, []byte(skHex))

	tokenId := big.NewInt(1)

	// Call createEIP712Digest to generate digestHash
	digestHash := contract.Call("createEIP712Digest", []interface{}{tokenId, testAddr})

	// Sign the digest in Go
	signature, err := crypto.Sign(digestHash[0].([]byte), privKey.Priv)
	if err != nil {
		log.Fatalf("Error signing message: %v", err)
	}

	// Call signL1MintApproval and compare signatures
	receipt = contractAddr.SendTransaction("signL1MintApproval", []interface{}{tokenId, testAddr}, nil)
	nfteeApprovalEvent := &NFTEEApproval{}
	if err := nfteeApprovalEvent.Unpack(receipt.Logs[0]); err != nil {
		panic(err)
	}

	fmt.Println(signature)
	fmt.Println(nfteeApprovalEvent.SignedMessage)

	if !bytes.Equal(signature, nfteeApprovalEvent.SignedMessage) {
		log.Fatal("Signed messages do not match")
	} else {
		fmt.Println("Signed messages match")
	}
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
	nameHash := keccak256([]byte("SUAVE_NFT"))
	symbolHash := keccak256([]byte("NFTEE"))

	mintTypeHashBytes := common.FromHex(MINT_TYPEHASH)
	domainSeparatorBytes := common.FromHex(DOMAIN_SEPARATOR)

	structHash := keccak256(encodePacked(
		mintTypeHashBytes,
		nameHash,
		symbolHash,
		tokenIdHash,
		recipientHash,
	))

	digestHash := keccak256(encodePacked(
		[]byte("\x19\x01"),
		domainSeparatorBytes,
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
