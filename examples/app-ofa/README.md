
# Example Suapp for an OFA application with private transactions

This example features an [Order-flow-auction](https://collective.flashbots.net/t/order-flow-auctions-and-centralisation-ii-order-flow-auctions/284) application based on the [mev-share](https://github.com/flashbots/mev-share) protocol specification.

User transactions are stored in the confidential datastore and only a small hint it is leaked outside the Kettle. Then, searchers bid in an order-flow auction for the right to execute against users’ private transactions.

## How to use

Run `Suave` in development mode:

```
$ suave --suave.dev
```

Execute the deployment script:

```
$ go run main.go
```
