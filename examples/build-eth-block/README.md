# Example Ethereum L1 Block Builder SUAPP

This example demonstrates a simple block building contract that receives bundles and returns an Ethereum L1 block.

## How to use

Start the `suave-geth` development environment

```
$ make devnet-up  # from suave-geth root directory
```

Execute the deployment script:

```
$ go run main.go
```

Expected output:

```
2024/02/29 14:59:09 Test address 1: 0x675d92a306187fBC280f8Dd98465770FBAEFf8Ab
2024/02/29 14:59:09 funding account 0x675d92a306187fBC280f8Dd98465770FBAEFf8Ab with 100000000000000000
2024/02/29 14:59:09 funder 0xB5fEAfbDD752ad52Afb7e1bD2E40432A485bBB7F 115792089237316195423570985008687907853269984665640564039457584007913129639927
2024/02/29 14:59:09 transaction hash: 0x29e67f56dfd1a01ab210dcad889eba7a99028ec1bf2206b66d8054efc14e6fda
2024/02/29 14:59:09 deployed contract at 0xd594760B2A36467ec7F0267382564772D7b0b73c
2024/02/29 14:59:09 deployed contract at 0x8f21Fdd6B4f4CacD33151777A46c122797c8BF17
2024/02/29 14:59:09 transaction hash: 0x99a95bc20ea3e8c9d8a2ac21943c1c7a51599b57e4254a48f3773f923d881f2b
2024/02/29 14:59:09 transaction hash: 0xbf9ff92a229c76f59ed7d2be06297763b796c390d725fb1863e199cdb9cff1eb
```
