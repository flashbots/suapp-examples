# Example Suapp with a Private library

This example shows how Suapps can use private libraries stored in the confidential store that are not public in the Suave chain.

The private code is saved in the confidential store with the `registerContract` function. The function receives the bytecode as confidential inputs such that the code is not leaked. Then, when the `example` function is called, it retrieves the library from the confidential stores and deploys it on-runtime. Note that this library is volatile and only visible as part of the confidential request, its bytecode and changes in the storage variables are never saved on-chain.

## How to use

Run `Suave` in development mode:

```
$ suave-geth --suave.dev
```

Execute the deployment script:

```
$ go run main.go
```
