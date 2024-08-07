# Example Suapp that uses the service registry

This example shows how Suapps can use the Kettle service registry to resolve HTTP service aliases.

## How to use

Run `Suave` in development mode:

```
$ suave-geth --suave.dev --suave.service-alias example=https://example.com --suave.eth.external-whitelist='*'
```

Execute the deployment script:

```
$ go run main.go
```
