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
	@kurtosis run \
			--enclave eth-devnet \
		../kurtosis-ethereum-package "$$( cat ./devnet/kurtosis.yaml )"
	@kurtosis service stop eth-devnet mev-flood
	@docker compose --file ./devnet/docker-compose.yaml up --detach

.PHONY: devnet-down
devnet-down:
	@docker compose --file ./devnet/docker-compose.yaml down
	@docker volume rm e2e_suave-blockscout-db-data || true
	@kurtosis enclave stop eth-devnet
	@kurtosis enclave rm eth-devnet
	@kurtosis engine stop

.PHONY: run-integration
run-integration:
	go run examples/mevm-confidential-store/main.go
	go run examples/mevm-is-confidential/main.go
	go run examples/onchain-callback/main.go
	go run examples/onchain-state/main.go
