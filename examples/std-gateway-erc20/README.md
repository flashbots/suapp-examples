# Example Suapp with external calls to an ERC20 contract

This example features how a Suapp can use the [`Gateway.sol`](https://github.com/flashbots/suave-std/blob/main/src/Gateway.sol) contract to make an external call to check the balance of an ERC20 contract deployed on another chain.

## How to use

Run `Suave` in development mode:

```
$ suave-geth --suave.dev
```

Export the JSON-RPC URL of the chain where the ERC20 contract is deployed:

```
export JSONRPC_ENDPOINT=https://mainnet.infura.io<...>
```

Execute the deployment script:

```
$ go run main.go
```
