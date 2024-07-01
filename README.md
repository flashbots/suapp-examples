# SUAVE Suapp Examples

This repository contains several [examples and useful references](/examples/) for building Suapps!

---

See also:

- [suave-geth source](https://github.com/flashbots/suave-geth)
- [Flashbots Collective: SUAVE Forum](https://collective.flashbots.net/c/suave/27)

Writings:

- [The Future of MEV is SUAVE](https://writings.flashbots.net/the-future-of-mev-is-suave)
- [The MEVM, SUAVE Centauri, and Beyond](https://writings.flashbots.net/mevm-suave-centauri-and-beyond)

---

## Getting Started

```bash
# Clone this repository
git clone https://github.com/flashbots/suapp-examples.git
```

---

## Compile the examples

Install [Foundry](https://getfoundry.sh/):

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Install dependencies:

```bash
forge install
```

Compile:

```bash
forge build
```

---

## Start the local devnet

### TL;DR

1. Install prerequisites:

   - [Docker](https://docs.docker.com/engine/install/)
   - [Kurtosis](https://docs.kurtosis.com/install/)

2. Run

    ```bash
    # Launch kurtosis devnet + sidecar docker-compose with SUAVE
    make devnet-up

    # Run
    go run examples/app-ofa-private/main.go

    # Tear-down
    make devnet-down
    ```

>
> **Notes:**
>
> 1. If you are Mac OS user, you might want to consider using
>    [OrbStack](https://orbstack.dev/) instead of Docker Desktop.
>
> 2. Some of the tests (`app-ofa-private`, for example) will need Eth
>    devnet to progress beyond dencun fork.  Wait out ~5m after the
>    start before running them (roughly slot 128).
>

### Details

Above setup will (among other things) deploy:

- SUAVE devnet RPC on `http://127.0.0.1:8545`
- Eth devnet RPC on `http://127.0.0.1:8555`
- SUAVE explorer on `http://127.0.0.1:8080`
- Eth explorer on `http://127.0.0.1:18080`
- MEV Boost Relay Overview on `http://127.0.0.1:9060`

All Eth components are provisioned by `ethereum-package` from kurtosis.
Please check `https://github.com/kurtosis-tech/ethereum-package` for more info.

---

## Run the examples

Check out the [`/examples/`](/examples/) folder for several example Suapps and `main.go` files to deploy and run them!

---

Happy hacking 🛠️
