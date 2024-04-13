package framework

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"

	"github.com/ethereum/go-ethereum/beacon/types"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
)

// BeaconChain is a very-minimal client for interacting with the beacon chain.
type BeaconChain struct {
	httpClient *http.Client
	baseURL    string
}

// GetBlockHeaderResponse is returned from GetBlockHeader.
type GetBlockHeaderResponse struct {
	ExecutionOptimistic bool `json:"execution_optimistic"`
	Finalized           bool `json:"finalized"`
	Data                []struct {
		Root      common.Hash `json:"root"`
		Canonical bool        `json:"canonical"`
		Header    struct {
			Message   types.Header  `json:"message"`
			Signature hexutil.Bytes `json:"signature"`
		} `json:"header"`
	} `json:"data"`
}

// GetProposerDutiesResponse is returned from GetProposerDuties.
type GetProposerDutiesResponse struct {
	DependentRoot       common.Hash `json:"dependent_root"`
	ExecutionOptimistic bool        `json:"execution_optimistic"`
	Data                []struct {
		Pubkey         hexutil.Bytes `json:"pubkey"`
		ValidatorIndex uint64        `json:"validator_index,string"`
		Slot           uint64        `json:"slot,string"`
	} `json:"data"`
}

// GetAndParse makes a GET request to the given URL and unmarshals the response into v.
func GetAndParse[V interface{}](b *BeaconChain, url string, v V) error {
	res, err := b.httpClient.Get(url)
	if err != nil {
		return err
	}
	body, err := io.ReadAll(res.Body)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(body, v); err != nil {
		panic(err)
	}
	return nil
}

// getAndParse calls GetAndParse with the BeaconChain receiver.
func (b *BeaconChain) getAndParse(url string, v any) error {
	return GetAndParse(b, url, v)
}

// GetBlockHeader gets the beacon block header for a given beacon block ID, or the latest block if blockID is nil.
func (b *BeaconChain) GetBlockHeader(blockID *common.Hash) (*GetBlockHeaderResponse, error) {
	url := fmt.Sprintf("%s/eth/v1/beacon/headers", b.baseURL)
	if blockID != nil {
		url = fmt.Sprintf("/%s", blockID)
	}

	data := new(GetBlockHeaderResponse)
	if err := b.getAndParse(url, data); err != nil {
		return nil, err
	}

	return data, nil
}

// GetProposerDuties gets the proposer duties for a given epoch.
func (b *BeaconChain) GetProposerDuties(epoch uint64) (*GetProposerDutiesResponse, error) {
	url := fmt.Sprintf("%s/eth/v1/validator/duties/proposer/%d", b.baseURL, epoch)
	log.Printf("url: %s", url)

	data := new(GetProposerDutiesResponse)
	if err := b.getAndParse(url, data); err != nil {
		return nil, err
	}

	return data, nil
}
