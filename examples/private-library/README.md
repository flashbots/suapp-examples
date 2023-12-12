
# Example Suapp with a Private library

This example shows how Suapps can use private libraries that are not public in the Suave chain.

The private code is sent inside the confidential part of the confidential compute request and deployed on-runtime with the `create` opcode. The new library is volatile and only visible as part of the confidential request. Thus, its bytecode and changes in the storage variables are never saved on-chain.

## How to use

Run `Suave` in development mode:

```
$ suave --suave.dev
```

Execute the deployment script:

```
$ go run main.go
```
