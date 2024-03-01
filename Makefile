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

.PHONY: run-integration
run-integration:
	go run examples/build-eth-block/main.go
	go run examples/mevm-confidential-store/main.go 
	go run examples/mevm-is-confidential/main.go 
	go run examples/onchain-callback/main.go 
	go run examples/onchain-state/main.go
	go run examples/mevm-context/main.go
