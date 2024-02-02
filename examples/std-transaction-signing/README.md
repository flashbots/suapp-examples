# Example Suapp to sign a transaction

This example shows how to use the `suave-std` library to create and sign transactions with the `signTxn` method. Internally, the method uses the `signMessage` precompile available in the Suave MEVM.

## How to use

Run `Suave` in development mode:

```
$ suave --suave.dev
```

Execute the deployment script:

```
$ go run main.go
```
