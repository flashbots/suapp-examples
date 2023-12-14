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

```bash
$ curl -L https://foundry.paradigm.xyz | bash
```

Compile:

```bash
$ forge build
```

---

## Start the local devnet

See the instructions here: https://github.com/flashbots/suave-geth#starting-a-local-devnet

---

## Run the examples

Check out the [`/examples/`](/examples/) folder for several example Suapps and `main.go` files to deploy and run them!

## Contributing

Some notes and helpers for contributing to this repository:

```bash
# Install testing dependencies
$ go install mvdan.cc/gofumpt@v0.4.0
$ go install honnef.co/go/tools/cmd/staticcheck@v0.4.5
$ go install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.55.0

# Update the git submodules to the latest commit
$ git submodule update --remote
```

---

Happy hacking 🛠️
