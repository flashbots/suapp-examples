package main

import (
	"bytes"
	"context"
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/flashbots/suapp-examples/framework"
)

func buildConfidentialPayload(fr *framework.Framework) ([]byte, error) {
	testAddr := framework.GeneratePrivKey()
	targetAddr := testAddr.Address()

	ethTxn1, err := fr.L1.SignTx(testAddr, &types.LegacyTx{
		To:       &targetAddr,
		Value:    big.NewInt(1000),
		Gas:      21000,
		GasPrice: big.NewInt(670189871),
	})
	if err != nil {
		return nil, err
	}

	var buf bytes.Buffer
	err = ethTxn1.EncodeRLP(&buf)
	return buf.Bytes(), err
}

func decryptionCondition(fr *framework.Framework) (uint64, error) {
	// get the current block, and increment by one.
	head, err := fr.L1.RPC().BlockNumber(context.Background())
	return head + 1, err
}

func main() {
	fr := framework.New()
	c := fr.Suave.DeployContract("builder.sol/Builder.json")

	b, err := buildConfidentialPayload(fr)
	if err != nil {
		panic(err)
	}

	dc, err := decryptionCondition(fr)
	if err != nil {
		panic(err)
	}
	log.Printf("decryption condition: %d\n", dc)

	r := c.SendTransaction("example", []interface{}{dc}, b)
	if r == nil {
		panic(r)
	}
}
