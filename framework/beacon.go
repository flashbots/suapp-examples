package framework

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/ethereum/go-ethereum/beacon/types"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
)

type BeaconChain struct {
	httpClient *http.Client
	baseURL    string
}

type BeaconClient struct {
	chain *BeaconChain
}

func (b *BeaconChain) Http() *BeaconClient {
	return &BeaconClient{chain: b}
}

func (b *BeaconClient) Get(url string) ([]byte, error) {
	res, err := b.chain.httpClient.Get(url)
	if err != nil {
		return nil, err
	}
	body, err := io.ReadAll(res.Body)
	if err != nil {
		panic(err)
	}
	return body, nil
}

// type BeaconBlockHeader struct {
// 	Slot          string      `json:"slot"`
// 	ProposerIndex string      `json:"proposer_index"`
// 	ParentRoot    common.Hash `json:"parent_root"`
// 	StateRoot     common.Hash `json:"state_root"`
// 	BodyRoot      common.Hash `json:"body_root"`
// }

// type SignedBeaconBlockHeader struct {
// 	Message   BeaconBlockHeader `json:"message"`
// 	Signature []byte            `json:"signature"`
// }

// type GetBlockHeaderData struct {
// 	Root      common.Hash             `json:"root"`
// 	Canonical bool                    `json:"canonical"`
// 	Header    SignedBeaconBlockHeader `json:"header"`
// }

// type GetBlockHeaderResponse struct {
// 	ExecutionOptimistic bool                 `json:"execution_optimistic"`
// 	Finalized           bool                 `json:"finalized"`
// 	Data                []GetBlockHeaderData `json:"data"`
// }

// GetBlockHeader gets the beacon block header for a given beacon block ID, or the latest block if blockID is nil.
func (b *BeaconChain) GetBlockHeader(blockID *common.Hash) (*types.Header, *common.Hash, error) {
	url := fmt.Sprintf("%s/eth/v1/beacon/headers", b.baseURL)
	if blockID != nil {
		url = fmt.Sprintf("/%s", blockID)
	}

	var data struct {
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

	body, err := b.Http().Get(url)
	if err != nil {
		return nil, nil, err
	}
	if err := json.Unmarshal(body, &data); err != nil {
		panic(err)
	}

	return &data.Data[0].Header.Message, &data.Data[0].Root, nil
}
