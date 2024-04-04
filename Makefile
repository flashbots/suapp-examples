VERSION := $(shell git describe --tags --always --dirty="-dev")

.PHONY: clean
clean:
	rm -rf out/

.PHONY: test
test:
	go test ./framework/...

.PHONY: lint
lint:
	gofmt -d -s examples/ framework/
	gofumpt -d -extra examples/ framework/
	go vet ./examples/... ./framework/...
	staticcheck ./examples/... ./framework/...
	golangci-lint run

.PHONY: fmt
fmt:
	gofmt -s -w examples/ framework/
	gofumpt -extra -w examples/ framework/
	gci write examples/ framework/
	go mod tidy

.PHONY: lt
lt: lint test

.PHONY: devnet-up
devnet-up:
	@docker compose --file ./docker-compose.yaml up --detach

.PHONY: devnet-down
devnet-down:
	@docker compose --file ./docker-compose.yaml down

.PHONY: devnet-kurtosis-up
devnet-kurtosis-up:
	@kurtosis run \
			--enclave eth-devnet \
		github.com/kurtosis-tech/ethereum-package@1.4.0 \
			"$$( cat ./devnet/kurtosis.yaml )"
	@kurtosis service stop eth-devnet mev-flood
	@docker compose --file ./devnet/docker-compose.yaml up --detach

.PHONY: devnet-kurtosis-down
devnet-kurtosis-down:
	@docker compose --file ./devnet/docker-compose.yaml down
	@docker volume rm devnet_suave-blockscout-db-data || true
	@kurtosis enclave stop eth-devnet
	@kurtosis enclave rm eth-devnet
	@kurtosis engine stop

.PHONY: run-integration
run-integration:
	go run examples/build-eth-block/main.go
	go run examples/app-ofa-private/main.go
	go run examples/mevm-confidential-store/main.go
	go run examples/mevm-context/main.go
	go run examples/mevm-is-confidential/main.go
	go run examples/onchain-callback/main.go
	go run examples/onchain-state/main.go
	go run examples/offchain-logs/main.go
	go run examples/mevm-context/main.go
	go run examples/private-library/main.go
	go run examples/private-library-confidential-store/main.go
	go run examples/private-suapp-key/main.go
	go run examples/private-suapp-key-gen/main.go
	go run examples/std-transaction-signing/main.go
