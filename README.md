# SUAVE Suapp Examples

See also:

- **https://github.com/flashbots/suave-geth**
- https://collective.flashbots.net/c/suave/27

Writings:

- https://writings.flashbots.net/the-future-of-mev-is-suave
- https://writings.flashbots.net/mevm-suave-centauri-and-beyond

## Getting Started

```bash
# Clone this repository
$ git clone https://github.com/flashbots/suapp-examples.git

# Checkout the suave-geth submodule
$ git submodule init
$ git submodule update
```

## Compile the examples

Install [Foundry](https://getfoundry.sh/):

```
$ curl -L https://foundry.paradigm.xyz | bash
```

Compile:

```bash
$ forge build
```

## Start the local devnet

```bash
# spin up the local devnet with docker-compose
$ make devnet-up

# create a few example transactions
$ go run suave/devenv/cmd/main.go

# execute a RPC request with curl
$ curl 'http://localhost:8545' --header 'Content-Type: application/json' --data '{ "jsonrpc":"2.0", "method":"eth_blockNumber", "params":[], "id":83 }'
```

## Run the examples

Check out the [`/examples/`](/examples/) folder for several example Suapps and `main.go` files to deploy and run them!

---

Happy hacking 🛠️
