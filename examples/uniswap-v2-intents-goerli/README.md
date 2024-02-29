# uniswap-v2-intents-goerli

A SUAPP featuring a simple intent-based public mempool and solver-driven intent execution. The example is limited to Uniswap V2, but the protocol can easily be extended to other exchanges. Solvers' bundles are sent only when their bundle passes simulation.

This example sends the user's private key over the wire via confidentialInputs. This is not a sound design; it's just simpler for the sake of demonstration. The key is only ever seen by the MEVM, and is used to sign transactions on behalf of the user. That said, it's strongly recommended to use a burner account if you want to run this yourself.

> This example connects to the live SUAVE Rigil Testnet, and Goerli. To run this example, make sure you have at least 0.1 testnet ETH in both networks.

## instructions

To install dependencies:

```bash
bun install
```

Setup .env:

```bash
# assuming you're in this directory, go to project root
cd ../..
cp .env.example .env

# populate GOERLI_KEY and SUAVE_KEY in .env
vim .env
```

To run:

```bash
bun run index.ts
```

To deploy new contracts and run:

```bash
DEPLOY=true bun run index.ts
```

This project was created using `bun init` in bun v1.0.23. [Bun](https://bun.sh) is a fast all-in-one JavaScript runtime.

## notes

*Some notes on intents and ideas to improve the current design:*

- add a reimbursement feature to pay solvers
- generate the user's private key in a smart contract, so it never leaves the MEVM
- store the private key in confidential storage and include a transaction to fund it in the bundle
- write an L1 contract that uses EIP712 signatures to reimburse the solver
  - the signature is passed with confidentialInputs and is not revealed except when landed in a bundle
  - this allows us to program the recipient (solver) into the reimbursement function without requiring the recipient address to be encoded in the EIP712 struct, which is important because the user doesn't know who the solver is going to be ahead of time.

