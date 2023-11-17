# SUAVE Suapp Examples

This repository contains several [examples and useful references](/examples/) for building Suapps!

---

See also:

- **https://github.com/flashbots/suave-geth**
- https://collective.flashbots.net/c/suave/27

Writings:

- https://writings.flashbots.net/the-future-of-mev-is-suave
- https://writings.flashbots.net/mevm-suave-centauri-and-beyond

---

## Getting Started

```bash
# Clone this repository
$ git clone git@github.com:flashbots/suapp-examples.git

# Checkout the suave-geth submodule
$ git submodule init
$ git submodule update
```

---

## Compile the examples

Install [Foundry](https://getfoundry.sh/):

```
$ curl -L https://foundry.paradigm.xyz | bash
```

Compile:

```bash
$ forge build
```

---

## Start the local devnet

There's two ways to start the local devnet: with Docker or directly using the suave-geth binary.

### Building from source

```bash
# change into the suave-geth directory
$ cd suave-geth

# build the binary
$ make suave
```

Now you have the `suave`` binary in your Go bin directory. You can check this by running:

```bash
$ which suave
$ suave --version
```

Start the local devnet like this:

```bash
$ suave --suave.dev
```

### Docker

```bash
# change into the suave-geth directory
$ cd suave-geth

# spin up the local devnet with docker-compose
$ make devnet-up

# check that the containers are running
$ docker ps

# you can stop the local devnet like this
$ make devnet-down
```

### Testing the devnet

Create a few example transactions:

```bash
$ go run suave/devenv/cmd/main.go
```

Execute a RPC request with curl like this:

```bash
$ curl 'http://localhost:8545' --header 'Content-Type: application/json' --data '{ "jsonrpc":"2.0", "method":"eth_blockNumber", "params":[], "id":83 }'
```

---

## Run the examples

Check out the [`/examples/`](/examples/) folder for several example Suapps and `main.go` files to deploy and run them!

---

Happy hacking 🛠️
