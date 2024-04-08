# NFTEE - EIP712 Minting Example

This SUAPP example showcases how you can write a SUAPP to generate a 712 signature on SUAVE that can then ben sent to a contract on Eth L1 which allows you to mint an NFT.

## Usage
## Solidity
Like all examples in this repo:
```sh
forge build
```
## Go Script
Before running you need to fill in some values:
- `PRIV_KEY`: Valid ECDSA Private Key with L1 Eth. (Hexadecimal format)
- `ETH_RPC_URL`: Ethereum L1 testnet RPC URL.
- `ETH_CHAIN_ID`: Chain Id of the L1 you're testing on.

To run the script, execute the following command in your terminal:

```sh
go run main.go
```

## Notes
- The `DOMAIN_SEPARATOR` and `MINT_TYPEHASH` are currently hard coded, you will need to make this dynamic for you prod application. Also Accepting PRs!
- Ensure that the Ethereum Goerli testnet account associated with the provided private key has sufficient ETH to cover transaction fees.
- The script currently targets the Goerli testnet. For mainnet deployment, update the `ETH_RPC_URL` and `ETH_CHAIN_ID` appropriately, and ensure that the account has sufficient mainnet ETH.

# 712
The source code for creating the 712 Signature is based off [Testing EIP-712 Signatures](https://book.getfoundry.sh/tutorials/testing-eip712.html).
