# Example Suapp with the IsConfidential precompile

This example shows how to use the IsConfidential precompile. This precompile returns `true` if the contract is running inside the confidential off-chain `MEVM` environment.

## How to use

Run `Suave` in development mode:

```
$ suave-geth --suave.dev
```

Execute the deployment script:

```
$ go run main.go
```
