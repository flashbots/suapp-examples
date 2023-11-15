# Example Suapp with OnChain Callback

This example shows how Suapps can return a function call signature during the confidential execution. This signature can be used to trigger an on-chain callback when the request is committed to the chain.

Only logs emitted during the onchain execution are available for querying on the onchain nodes. Due to the confidential nature of the execution, logs emitted during the confidential execution are not saved.

## How to use

Run `Suave` in development mode:

```
$ suave --suave.dev
```

Execute the deployment script:

```
$ go run main.go
```
