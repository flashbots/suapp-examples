# US Treasury Auction Example

This example demonstrates how the US Treasury could use SUAVE to run their auctions.

While efficient and confidential execution is not an issue the Treasury has, we feel they might benefit from verifiability after each auction. For instance, they may be able to more readily prove that [hacks of the ICBC](https://twitter.com/jameslavish/status/1724541469476991139) did indeed result in lower participation, if that was actually the case.

This example provides support for multiple types of auctions: TBills, Notes, Bonds, TIPS and FRNs could all potentially be run as different `auctionType`s using this same contract. Please read [this thread](https://twitter.com/jameslavish/status/1577334009092198400) for an explanation of each.

Anyone can use this contract to run auctions - there are no special privileges. We assume that Treasury would specify the auction that they create and direct traders and other relevant parties to them.

This example does not move securities once the auction is settled: it simply runs the auction itself. We assume Treasuries would distribute the relevant securities based on the verifiable auction results once it has been run. 

For on-chain assets, you might wish to write another contract the handles the distribution of whatever has been auctioned immediately and without intermediation once the auction has been completed.

## How to use

Run `Suave` in development mode:

```
cd suave-geth
suave --suave.dev
```

Execute the deployment script:

```
go run main.go
```

