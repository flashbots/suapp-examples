package framework

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"

	builderApiV1 "github.com/attestantio/go-builder-client/api/v1"
)

// RelayClient is a very-minimal client for interacting with the mev-boost relay.
type RelayClient struct {
	httpClient *http.Client
	relayURL   string
}

/*
BuilderGetValidatorsResponseEntry is a single entry in the response from $BOOST_RELAY_URL/relay/v1/builder/validators.
Copied from [mev-boost-relay types](https://github.com/flashbots/mev-boost-relay/blob/main/common/types.go)
rather than importing mev-boost-relay, because it has conflicting dependencies w/ suave-geth.
*/
type BuilderGetValidatorsResponseEntry struct {
	Slot           uint64                                    `json:"slot,string"`
	ValidatorIndex uint64                                    `json:"validator_index,string"`
	Entry          *builderApiV1.SignedValidatorRegistration `json:"entry"`
}

// GetAndParse makes a GET request to the given URL and unmarshals the response into v.
func GetAndParse[V interface{}](b *RelayClient, url string, v V) error {
	res, err := b.httpClient.Get(url)
	if err != nil {
		return err
	}
	body, err := io.ReadAll(res.Body)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(body, v); err != nil {
		return err
	}
	return nil
}

// getAndParse calls GetAndParse with the RelayClient receiver.
func (b *RelayClient) getAndParse(url string, v any) error {
	return GetAndParse(b, url, v)
}

// GetValidators gets current & upcoming validators from the mev-boost relay.
func (b *RelayClient) GetValidators() (*[]BuilderGetValidatorsResponseEntry, error) {
	url := fmt.Sprintf("%s/relay/v1/builder/validators", b.relayURL)
	log.Printf("url: %s", url)

	data := new([]BuilderGetValidatorsResponseEntry)
	if err := b.getAndParse(url, data); err != nil {
		return nil, err
	}

	return data, nil
}
