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
cd -
```

To run (back in this directory):

```bash
bun run index.ts
```

_To deploy new contracts and run:_

```bash
DEPLOY=true bun run index.ts
```

_Alternatively, deploy a new contract with forge:_

```bash
# run from project root
cd ../..
# load .env into shell to make $SUAVE_KEY available
source .env
# deploy Intents contract
forge create --legacy --private-key $SUAVE_KEY --rpc-url https://rpc.rigil.suave.flashbots.net examples/uniswap-v2-intents-goerli/contracts/Intents.sol:Intents
```

This project was created using `bun init` in bun v1.0.23. [Bun](https://bun.sh) is a fast all-in-one JavaScript runtime.

## notes

*Some notes on intents and ideas to improve the current design:*

- generate the user's private key in a smart contract and store the private key in confidential storage, so it never leaves the MEVM+CStore
  - user or solver provides a signed transaction to fund the new account, which is placed at the front of the bundle
- check for inclusion onchain
  - check for a tx receipt from a reliable source to prove inclusion

    RPC URL will have to exist somewhere on suave chain. May be worthwhile to write an API registry contract there so that SUAPPS don't have to re-deploy contracts when an address changes. Naturally, since we want to update the registry over time, someone/something will control the registry. To make sure you don't get rekt, you either have to (A) trust the controller not to act maliciously, or (B) implement multi-sig/governance ownership on the contract, and trust the elected governors not to collude.
  - consider using merkle proofs instead of tx receipts for larger-scale inclusion checks
- add a reimbursement mechanism to pay solvers
  - write an L1 contract that uses EIP712 signatures to reimburse the solver.

    The signature is passed with confidentialInputs and is not revealed except when landed in a bundle.
    This allows us to program the recipient (solver) into the reimbursement function without requiring the recipient address to be encoded in the EIP712 struct, which is important because the user doesn't know who the solver is going to be ahead of time.
  - use inclusion proof to trigger solver reimbursement
    - It may not be possible to send bundles and check for inclusion atomically at the moment. This may change with pending parallelization developments on SUAVE.
