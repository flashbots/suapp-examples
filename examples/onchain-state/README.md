# Example Suapp with OnChain state

This example shows how Suapps can update state of the smart contract on the Suave chain.

State variables updated during the confidential request are not updated on the state since the execution is confidential. But, a confidential request can update the state with a callback.

## How to use

Run `Suave` in development mode:

```
$ suave-geth --suave.dev
```

Execute the deployment script:

```
$ go run main.go
```
