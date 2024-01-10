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
	"strings"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/ethereum/go-ethereum/suave/artifacts"
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

type Contract struct {
	*sdk.Contract

	clt        *sdk.Client
	kettleAddr common.Address

	addr common.Address
	abi  *abi.ABI
}

func (c *Contract) Call(methodName string) []interface{} {
	input, err := c.abi.Pack(methodName)
	if err != nil {
		panic(err)
	}

	callMsg := ethereum.CallMsg{
		To:   &c.addr,
		Data: input,
	}
	output, err := c.clt.RPC().CallContract(context.Background(), callMsg, nil)
	if err != nil {
		panic(err)
	}

	results, err := c.abi.Methods[methodName].Outputs.Unpack(output)
	if err != nil {
		panic(err)
	}
	return results
}

func (c *Contract) Raw() *sdk.Contract {
	return c.Contract
}

var executionRevertedPrefix = "execution reverted: 0x"

// SendTransaction sends the transaction and panics if it fails
func (c *Contract) SendTransaction(method string, args []interface{}, confidentialBytes []byte) *types.Receipt {
	txnResult, err := c.Contract.SendTransaction(method, args, confidentialBytes)
	if err != nil {
		// decode the PeekerReverted error
		errMsg := err.Error()
		if strings.HasPrefix(errMsg, executionRevertedPrefix) {
			errMsg = errMsg[len(executionRevertedPrefix):]
			errMsgBytes, _ := hex.DecodeString(errMsg)

			unpacked, _ := artifacts.SuaveAbi.Errors["PeekerReverted"].Inputs.Unpack(errMsgBytes[4:])

			addr, _ := unpacked[0].(common.Address)
			eventErr, _ := unpacked[1].([]byte)
			panic(fmt.Sprintf("peeker 0x%x reverted: %s", addr, eventErr))
		}
		panic(err)
	}
	receipt, err := txnResult.Wait()
	if err != nil {
		panic(err)
	}
	if receipt.Status == 0 {
		panic(fmt.Errorf("status not correct"))
	}
	return receipt
}

type Framework struct {
	config        *Config
	kettleAddress common.Address

	Suave *Chain
	L1    *Chain
}

type Config struct {
	KettleRPC     string
	L1RPC         string
	FundedAccount *PrivKey
}

func DefaultConfig() *Config {
	return &Config{
		KettleRPC: "http://localhost:8545",
		L1RPC:     "http://localhost:8555",

		// This account is funded in your local SUAVE devnet
		// address: 0xBE69d72ca5f88aCba033a063dF5DBe43a4148De0
		FundedAccount: NewPrivKeyFromHex("91ab9a7e53c220e6210460b65a7a3bb2ca181412a8a7b43ff336b3df1737ce12"),
	}
}

func New() *Framework {
	config := DefaultConfig()

	kettleRPC, _ := rpc.Dial(config.KettleRPC)

	var accounts []common.Address
	if err := kettleRPC.Call(&accounts, "eth_kettleAddress"); err != nil {
		panic(fmt.Sprintf("failed to get kettle address: %v", err))
	}

	suaveClt := sdk.NewClient(kettleRPC, config.FundedAccount.Priv, accounts[0])

	l1RPC, _ := rpc.Dial(config.L1RPC)
	l1Clt := sdk.NewClient(l1RPC, config.FundedAccount.Priv, common.Address{})

	return &Framework{
		config:        config,
		kettleAddress: accounts[0],
		Suave:         &Chain{rpc: kettleRPC, clt: suaveClt, kettleAddr: accounts[0]},
		L1:            &Chain{rpc: l1RPC, clt: l1Clt},
	}
}

type Chain struct {
	rpc        *rpc.Client
	clt        *sdk.Client
	kettleAddr common.Address
}

func (c *Chain) DeployContract(path string) *Contract {
	artifact, err := ReadArtifact(path)
	if err != nil {
		panic(err)
	}

	// deploy contract
	txnResult, err := sdk.DeployContract(artifact.Code, c.clt)
	if err != nil {
		panic(err)
	}

	receipt, err := txnResult.Wait()
	if err != nil {
		panic(err)
	}
	if receipt.Status == 0 {
		panic(fmt.Errorf("transaction failed"))
	}

	contract := sdk.GetContract(receipt.ContractAddress, artifact.Abi, c.clt)
	return &Contract{addr: receipt.ContractAddress, clt: c.clt, kettleAddr: c.kettleAddr, abi: artifact.Abi, Contract: contract}
}

func (c *Contract) Ref(acct *PrivKey) *Contract {
	clt := sdk.NewClient(c.clt.RPC().Client(), acct.Priv, c.kettleAddr)

	cc := &Contract{
		addr:     c.addr,
		abi:      c.abi,
		Contract: sdk.GetContract(c.addr, c.abi, clt),
	}
	return cc
}

func (f *Framework) NewClient(acct *PrivKey) *sdk.Client {
	rpc, _ := rpc.Dial(f.config.KettleRPC)
	return sdk.NewClient(rpc, acct.Priv, f.kettleAddress)
}

func (c *Chain) SignTx(priv *PrivKey, tx *types.LegacyTx) (*types.Transaction, error) {
	cltAcct1 := sdk.NewClient(c.rpc, priv.Priv, common.Address{})
	signedTxn, err := cltAcct1.SignTxn(tx)
	if err != nil {
		return nil, err
	}
	return signedTxn, nil
}

var errFundAccount = fmt.Errorf("failed to fund account")

func (c *Chain) FundAccount(to common.Address, value *big.Int) error {
	txn := &types.LegacyTx{
		Value: value,
		To:    &to,
	}
	result, err := c.clt.SendTransaction(txn)
	if err != nil {
		return err
	}
	_, err = result.Wait()
	if err != nil {
		return err
	}
	// check balance
	balance, err := c.clt.RPC().BalanceAt(context.Background(), to, nil)
	if err != nil {
		return err
	}
	if balance.Cmp(value) != 0 {
		return errFundAccount
	}
	return nil
}
