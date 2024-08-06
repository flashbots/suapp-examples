# Example Suapp with the MEVM Context

This example demonstrates how a Suapp can query the MEVM context. The MEVM context is a set of kv pairs that return information about the execution environment of the Confidential Compute request (i.e confidential inputs, address of the kettle, etc..). It can be queried with the low-level `contextGet` precompile.

The `suave-std` suite provides a high-level interface to the MEVM context with the [`Context.sol`](https://github.com/flashbots/suave-std/blob/main/src/Context.sol) library which is what it is used in this example.

## How to use

Run `Suave` in development mode:

```
$ suave-geth --suave.dev
```

Execute the deployment script:

```
$ go run main.go
```
