package framework

import (
	"context"
	"crypto/ecdsa"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math/big"
	"os"
	"path/filepath"
	"runtime"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/ethereum/go-ethereum/suave/sdk"
)

type Artifact struct {
	Abi *abi.ABI

	// Code is the code to deploy the contract
	Code []byte
}

func ReadArtifact(path string) (*Artifact, error) {
	_, filename, _, ok := runtime.Caller(0)
	if !ok {
		return nil, fmt.Errorf("unable to get the current filename")
	}
	dirname := filepath.Dir(filename)

	data, err := os.ReadFile(filepath.Join(dirname, "../out", path))
	if err != nil {
		return nil, err
	}

	var artifact struct {
		Abi      *abi.ABI `json:"abi"`
		Bytecode struct {
			Object string `json:"object"`
		} `json:"bytecode"`
	}
	if err := json.Unmarshal(data, &artifact); err != nil {
		return nil, err
	}

	code, err := hex.DecodeString(artifact.Bytecode.Object[2:])
	if err != nil {
		return nil, err
	}

	art := &Artifact{
		Abi:  artifact.Abi,
		Code: code,
	}
	return art, nil
}

var (
	ExNodeEthAddr = common.HexToAddress("b5feafbdd752ad52afb7e1bd2e40432a485bbb7f")
	ExNodeNetAddr = "http://localhost:8545"

	// This account is funded in both devnev networks
	// address: 0xBE69d72ca5f88aCba033a063dF5DBe43a4148De0
	FundedAccount = NewPrivKeyFromHex("91ab9a7e53c220e6210460b65a7a3bb2ca181412a8a7b43ff336b3df1737ce12")
)

type PrivKey struct {
	Priv *ecdsa.PrivateKey
}

func (p *PrivKey) Address() common.Address {
	return crypto.PubkeyToAddress(p.Priv.PublicKey)
}

func (p *PrivKey) MarshalPrivKey() []byte {
	return crypto.FromECDSA(p.Priv)
}

func NewPrivKeyFromHex(hex string) *PrivKey {
	key, err := crypto.HexToECDSA(hex)
	if err != nil {
		panic(fmt.Sprintf("failed to parse private key: %v", err))
	}
	return &PrivKey{Priv: key}
}

func GeneratePrivKey() *PrivKey {
	key, err := crypto.GenerateKey()
	if err != nil {
		panic(fmt.Sprintf("failed to generate private key: %v", err))
	}
	return &PrivKey{Priv: key}
}

func DeployContract(path string) (*sdk.Contract, error) {
	rpc, _ := rpc.Dial(ExNodeNetAddr)
	mevmClt := sdk.NewClient(rpc, FundedAccount.Priv, ExNodeEthAddr)

	artifact, err := ReadArtifact(path)
	if err != nil {
		return nil, err
	}

	// deploy contract
	txnResult, err := sdk.DeployContract(artifact.Code, mevmClt)
	if err != nil {
		return nil, err
	}

	receipt, err := ensureTransactionSuccess(txnResult)
	if err != nil {
		return nil, err
	}

	contract := sdk.GetContract(receipt.ContractAddress, artifact.Abi, mevmClt)
	return contract, nil
}

func ensureTransactionSuccess(txn *sdk.TransactionResult) (*types.Receipt, error) {
	receipt, err := txn.Wait()
	if err != nil {
		return nil, err
	}
	if receipt.Status == 0 {
		return nil, err
	}
	return receipt, nil
}

// DeployAndTransact is a helper function that deploys a suapp
// and inmediately executes a function on it with a confidential request.
func DeployAndTransact(path, funcName string) {
	contract, err := DeployContract(path)
	if err != nil {
		fmt.Printf("failed to deploy contract: %v", err)
		os.Exit(1)
	}

	txnResult, err := contract.SendTransaction(funcName, []interface{}{}, []byte{})
	if err != nil {
		fmt.Printf("failed to send transaction: %v", err)
		os.Exit(1)
	}

	if _, err = ensureTransactionSuccess(txnResult); err != nil {
		fmt.Printf("failed to ensure transaction success: %v", err)
		os.Exit(1)
	}
}

func FundAccount(to common.Address, value *big.Int) error {
	rpc, _ := rpc.Dial(ExNodeNetAddr)
	clt := sdk.NewClient(rpc, FundedAccount.Priv, ExNodeEthAddr)

	txn := &types.LegacyTx{
		Value: value,
		To:    &to,
	}
	result, err := clt.SendTransaction(txn)
	if err != nil {
		return err
	}
	_, err = result.Wait()
	if err != nil {
		return err
	}
	// check balance
	balance, err := clt.RPC().BalanceAt(context.Background(), to, nil)
	if err != nil {
		return err
	}
	if balance.Cmp(value) != 0 {
		return fmt.Errorf("failed to fund account")
	}
	return nil
}
