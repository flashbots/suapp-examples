package framework

import (
	"context"
	"crypto/ecdsa"
	"encoding"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
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
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/ethereum/go-ethereum/suave/artifacts"
	"github.com/ethereum/go-ethereum/suave/sdk"
	envconfig "github.com/sethvargo/go-envconfig"
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

var _ encoding.TextUnmarshaler = &PrivKey{}

type PrivKey struct {
	Priv *ecdsa.PrivateKey
}

func (p *PrivKey) Address() common.Address {
	return crypto.PubkeyToAddress(p.Priv.PublicKey)
}

func (p *PrivKey) MarshalPrivKey() []byte {
	return crypto.FromECDSA(p.Priv)
}

func (p *PrivKey) UnmarshalText(text []byte) error {
	key, err := crypto.HexToECDSA(string(text))
	if err != nil {
		return fmt.Errorf("failed to parse private key: %w", err)
	}
	p.Priv = key
	return nil
}

func NewPrivKeyFromHex(hex string) *PrivKey {
	p := new(PrivKey)
	if err := p.UnmarshalText([]byte(hex)); err != nil {
		panic(err)
	}
	return p
}

func GeneratePrivKey() *PrivKey {
	key, err := crypto.GenerateKey()
	if err != nil {
		panic(fmt.Sprintf("failed to generate private key: %v", err))
	}
	return &PrivKey{Priv: key}
}

type Contract struct {
	contract *sdk.Contract

	clt        *sdk.Client
	kettleAddr common.Address

	addr common.Address
	Abi  *abi.ABI
}

func (c *Contract) Call(methodName string, args []interface{}) []interface{} {
	input, err := c.Abi.Pack(methodName, args...)
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

	results, err := c.Abi.Methods[methodName].Outputs.Unpack(output)
	if err != nil {
		panic(err)
	}
	return results
}

func (c *Contract) Raw() *sdk.Contract {
	return c.contract
}

var executionRevertedPrefix = "execution reverted: 0x"

// SendConfidentialRequest sends the confidential request to the kettle
func (c *Contract) SendConfidentialRequest(method string, args []interface{}, confidentialBytes []byte) *types.Receipt {
	txnResult, err := c.contract.SendTransaction(method, args, confidentialBytes)
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

	log.Printf("transaction hash: %s", txnResult.Hash().Hex())

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
	KettleAddress common.Address

	Suave *Chain
	L1    *Chain
}

type Config struct {
	KettleRPC string `env:"KETTLE_RPC, default=http://localhost:8545"`

	// This account is funded in your local SUAVE devnet
	// address: 0xBE69d72ca5f88aCba033a063dF5DBe43a4148De0
	FundedAccount *PrivKey `env:"KETTLE_PRIVKEY, default=91ab9a7e53c220e6210460b65a7a3bb2ca181412a8a7b43ff336b3df1737ce12"`

	L1RPC string `env:"L1_RPC, default=http://localhost:8555"`

	// This account is funded in your local L1 devnet
	// address: 0xB5fEAfbDD752ad52Afb7e1bD2E40432A485bBB7F
	FundedAccountL1 *PrivKey `env:"L1_PRIVKEY, default=6c45335a22461ccdb978b78ab61b238bad2fae4544fb55c14eb096c875ccfc52"`

	// Whether to enable L1 or not
	L1Enabled bool

	// OpenAI API key
	OpenAIKey string `env:"OPENAI_KEY"`

	NfteeBaseURI string `env:"NFTEE_BASE_URI, default=http://localhost:8080/metadata/"`
	// TODO: change this =============================>^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ to a public IPFS node
}

type ConfigOption func(c *Config)

func WithL1() ConfigOption {
	return func(c *Config) {
		c.L1Enabled = true
	}
}

func New(opts ...ConfigOption) *Framework {
	var config Config
	if err := envconfig.Process(context.Background(), &config); err != nil {
		log.Fatal(err)
	}
	for _, opt := range opts {
		opt(&config)
	}

	kettleRPC, err := rpc.Dial(config.KettleRPC)
	if err != nil {
		panic(err)
	}

	var accounts []common.Address
	if err := kettleRPC.Call(&accounts, "eth_kettleAddress"); err != nil {
		panic(fmt.Sprintf("failed to get kettle address: %v", err))
	}

	suaveClt := sdk.NewClient(kettleRPC, config.FundedAccount.Priv, accounts[0])

	fr := &Framework{
		config:        &config,
		KettleAddress: accounts[0],
		Suave:         &Chain{rpc: kettleRPC, clt: suaveClt, kettleAddr: accounts[0]},
	}

	if config.L1Enabled {
		l1RPC, err := rpc.Dial(config.L1RPC)
		if err != nil {
			panic(err)
		}
		l1Clt := sdk.NewClient(l1RPC, config.FundedAccountL1.Priv, common.Address{})
		fr.L1 = &Chain{rpc: l1RPC, clt: l1Clt}
	}

	return fr
}

type Chain struct {
	rpc        *rpc.Client
	clt        *sdk.Client
	kettleAddr common.Address
}

// DeployContract deploys a contract at the given path.
//
// path is relative to out/.
//
// # Example
//
//	path = "MyContract.sol/ContractName.json"
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

	log.Printf("deployed contract to SUAVE (txhash=%s)", receipt.TxHash.Hex())

	contract := sdk.GetContract(receipt.ContractAddress, artifact.Abi, c.clt)
	return &Contract{addr: receipt.ContractAddress, clt: c.clt, kettleAddr: c.kettleAddr, Abi: artifact.Abi, contract: contract}
}

func (c *Contract) Ref(acct *PrivKey) *Contract {
	clt := sdk.NewClient(c.clt.RPC().Client(), acct.Priv, c.kettleAddr)

	cc := &Contract{
		addr:     c.addr,
		Abi:      c.Abi,
		contract: sdk.GetContract(c.addr, c.Abi, clt),
	}
	return cc
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

func (c *Chain) RPC() *ethclient.Client {
	return ethclient.NewClient(c.rpc)
}

func (c *Chain) FundAccount(to common.Address, value *big.Int) error {
	balance, err := c.clt.RPC().BalanceAt(context.Background(), c.clt.Addr(), nil)
	if err != nil {
		return err
	}

	log.Printf("funding account %s with %s", to.Hex(), value.String())
	log.Printf("funder %s %s", c.clt.Addr().Hex(), balance.String())

	txn := &types.LegacyTx{
		Value: value,
		To:    &to,
	}
	result, err := c.clt.SendTransaction(txn)
	if err != nil {
		return err
	}

	log.Printf("transaction hash: %s", result.Hash().Hex())
	_, err = result.Wait()
	if err != nil {
		return err
	}
	// check balance
	balance, err = c.clt.RPC().BalanceAt(context.Background(), to, nil)
	if err != nil {
		return err
	}
	if balance.Cmp(value) != 0 {
		return errFundAccount
	}
	return nil
}

// GatewayAddr returns the IP address of the Docker gateway. This is,
// the IP address to access the host machine.
func GatewayAddr() string {
	if os.Getenv("CI") == "true" {
		// Inside Github actions, the 'host.docker.internal' does not seem to work.
		return "172.17.0.1"
	}
	return "host.docker.internal"
}
