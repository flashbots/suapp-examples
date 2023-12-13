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

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
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

	addr common.Address
	abi  *abi.ABI
	fr   *Framework
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
	rpcClient := ethclient.NewClient(c.fr.rpc)
	output, err := rpcClient.CallContract(context.Background(), callMsg, nil)
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

// SendTransaction sends the transaction and panics if it fails
func (c *Contract) SendTransaction(method string, args []interface{}, confidentialBytes []byte) *types.Receipt {
	txnResult, err := c.Contract.SendTransaction(method, args, confidentialBytes)
	if err != nil {
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
	config *Config
	rpc    *rpc.Client
	clt    *sdk.Client
}

type Config struct {
	KettleRPC     string
	KettleAddr    common.Address
	FundedAccount *PrivKey
}

func DefaultConfig() *Config {
	return &Config{
		KettleRPC:  "http://localhost:8545",
		KettleAddr: common.HexToAddress("b5feafbdd752ad52afb7e1bd2e40432a485bbb7f"),

		// This account is funded in both devnev networks
		// address: 0xBE69d72ca5f88aCba033a063dF5DBe43a4148De0
		FundedAccount: NewPrivKeyFromHex("91ab9a7e53c220e6210460b65a7a3bb2ca181412a8a7b43ff336b3df1737ce12"),
	}
}

func New() *Framework {
	config := DefaultConfig()

	rpc, _ := rpc.Dial(config.KettleRPC)
	clt := sdk.NewClient(rpc, config.FundedAccount.Priv, config.KettleAddr)

	return &Framework{
		config: DefaultConfig(),
		rpc:    rpc,
		clt:    clt,
	}
}

func (f *Framework) DeployContract(path string) *Contract {
	artifact, err := ReadArtifact(path)
	if err != nil {
		panic(err)
	}

	// deploy contract
	txnResult, err := sdk.DeployContract(artifact.Code, f.clt)
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

	contract := sdk.GetContract(receipt.ContractAddress, artifact.Abi, f.clt)
	return &Contract{addr: receipt.ContractAddress, fr: f, abi: artifact.Abi, Contract: contract}
}

func (c *Contract) Ref(acct *PrivKey) *Contract {
	cc := &Contract{
		addr:     c.addr,
		abi:      c.abi,
		fr:       c.fr,
		Contract: sdk.GetContract(c.addr, c.abi, c.fr.NewClient(acct)),
	}
	return cc
}

func (f *Framework) NewClient(acct *PrivKey) *sdk.Client {
	cc := DefaultConfig()
	rpc, _ := rpc.Dial(cc.KettleRPC)
	return sdk.NewClient(rpc, acct.Priv, cc.KettleAddr)
}

func (f *Framework) SignTx(priv *PrivKey, tx *types.LegacyTx) (*types.Transaction, error) {
	rpc, _ := rpc.Dial("http://localhost:8545")

	cltAcct1 := sdk.NewClient(rpc, priv.Priv, common.Address{})
	signedTxn, err := cltAcct1.SignTxn(tx)
	if err != nil {
		return nil, err
	}
	return signedTxn, nil
}

var errFundAccount = fmt.Errorf("failed to fund account")

func (f *Framework) FundAccount(to common.Address, value *big.Int) error {
	txn := &types.LegacyTx{
		Value: value,
		To:    &to,
	}
	result, err := f.clt.SendTransaction(txn)
	if err != nil {
		return err
	}
	_, err = result.Wait()
	if err != nil {
		return err
	}
	// check balance
	balance, err := f.clt.RPC().BalanceAt(context.Background(), to, nil)
	if err != nil {
		return err
	}
	if balance.Cmp(value) != 0 {
		return errFundAccount
	}
	return nil
}
