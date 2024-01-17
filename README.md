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

# Checkout the suave-geth submodule
git submodule init
git submodule update
```

---

## Compile the examples

Install [Foundry](https://getfoundry.sh/):

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Compile:

```bash
forge build
```

---

## Start the local devnet

See the instructions in [suave-geth](https://github.com/flashbots/suave-geth#starting-a-local-devnet).

---

## Run the examples

Check out the [`/examples/`](/examples/) folder for several example Suapps and `main.go` files to deploy and run them!

---

Happy hacking 🛠️
