
# Example Suapp with Private contract

This example shows how Suapps can use private contracts that are not visible in the Suave chain.

The private code is sent inside the confidential part of the confidential compute request and deployed on-runtime with the `create` opcode.

## How to use

Run `Suave` in development mode:

```
$ suave --suave.dev
```

Execute the deployment script:

```
$ go run main.go
```
