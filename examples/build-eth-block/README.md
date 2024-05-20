# Example Ethereum L1 Block Builder SUAPP

This example demonstrates a simple block building contract that receives bundles and submits a block to mainnet Ethereum.

## Requirements

- [suave-geth](https://github.com/flashbots/suave-geth/tree/brock/mainnet-builder)
- [suavex-foundry](https://github.com/flashbots/suavex-foundry)
- [foundry](https://getfoundry.sh/) (system installation)
- [Golang](https://go.dev/doc/install) toolchain
- [Rust](https://rustup.rs/) toolchain

## Setup

This demo requires *suave-geth* to be configured for mainnet. Currently, it's hard-coded for Holesky testnet.

Check out this branch to reconfigure the node for mainnet and rebuild the binary:

```sh
# in suave-geth/
git checkout brock/mainnet-builder
make suave
```

Run suave-geth devnet with the following flags to ensure we connect to our own Ethereum provider, which we'll set up afterwards.

```sh
# in suave-geth/
./build/bin/suave-geth --suave.dev \
    --suave.eth.remote_endpoint=http://localhost:8555 \
    --suave.eth.external-whitelist='*'
```

This demo uses [suavex-anvil](https://github.com/flashbots/suavex-foundry)'s as the Ethereum provider for suave-geth, to replicate the conditions of building blocks for mainnet by forking a mainnet RPC provider.

Set `RPC_URL` (to a real mainnet RPC provider) in your environment, then run the following to download and run suavex-anvil.

```sh
git clone https://github.com/flashbots/suavex-foundry
cd suavex-foundry
cargo run --bin anvil -- -p 8555 --chain-id 1 -f $RPC_URL
```

The default account which is funded by suave-execution-geth (which we're replacing with suavex-anvil) isn't funded on this fork of anvil by default, so we'll need to send it some ether from one of the default anvil accounts.
We can do this with cast (from Foundry):

```sh
cast send \
    -r http://localhost:8555 \
    --value 999ether \
    --private-key 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6 \
    0xb5feafbdd752ad52afb7e1bd2e40432a485bbb7f
```

> For this demo, a mainnet beacon node with access to the `/eth/v1/events` endpoint is required. We use this to listen to the `payload_attributes` event, which gives us data we need to build blocks for mainnet.

Now back in this codebase, set `L1_BEACON_URL` to your beacon node's RPC in .env (in the project root directory), or in your shell's environment, and run the deployment script:

```sh
# in examples/build-eth-block/
go run main.go
```

Expected output:

```txt
<omitted sensitive trace logs from beacon node>
2024/05/19 12:07:46 Test address 1: 0x85E6919588CF2C82A5489c4606EC9C16Ab960cc9
2024/05/19 12:07:46 funding account 0x85E6919588CF2C82A5489c4606EC9C16Ab960cc9 with 100000000000000000
2024/05/19 12:07:46 funder 0xB5fEAfbDD752ad52Afb7e1bD2E40432A485bBB7F 998799840409509787000
2024/05/19 12:07:47 transaction hash: 0x1421782aadd47d8a033233b6bd8d376d79fe2c983be8e00c5613a3efe94914f3
2024/05/19 12:07:47 deployed contract at 0x19aE73489C3C76f27f110a9Bf51D03bbA99eF38d
2024/05/19 12:07:47 deployed contract at 0x010249e143b3b31286da7aAC26Ad2fCAB3A60a0D
2024/05/19 12:07:47 transaction hash: 0x8d5d492ff7b693d44b7d34972f2220b1bf4446360ff7b88b035fd61d5ef7f9c4
2024/05/19 12:07:47 finished newBundle in 117 ms
2024/05/19 12:07:47 found proposer duty for slot 9110137, {9110137 1229602 {message: {fee_recipient: '0x13F2241aa64bb6DA2B74553fA9E12B713b74F334', gas_limit: 30000000, timestamp: 1708476504, pubkey: '0x8e815d6361afd8475e9ca1388aeadbea8abd1e21a80e7cffae85e3ccb8eaad8704168e96210bdd6c4b778ecd913ce17d'}, signature: '0xa29ede14583f65253d5477b53a171fb5473aa25018c97b544eb43bb0ed02c45f9bf60f48dad6e7f1f07524da72165cc303e36d509791a97a0cb581f6d6d88f5dbeda118e5985247b588d4e7d3c9e81d224b2632616297b2b5a79aff587bb7287'}
}
2024/05/19 12:07:47 transaction hash: 0x1725273667a59c32e7a818516955118f90d5c62feaec08e40e6c9bbcc2ff10df
2024/05/19 12:07:47 finished buildFromPool in 123 ms
2024/05/19 12:07:47 blockBidID: 0x2a20347f1f6a5e749380e856e663e478
2024/05/19 12:07:48 transaction hash: 0xc8f617046e0f0e2acda8eef51a98b1e871ae896cb366227bd00a469d8bf4523f
2024/05/19 12:07:48 finished submitToRelay in 298 ms
2024/05/19 12:07:48 SubmitBlockResponse: @ {"message":{"slot":"9110137","parent_hash":"0x7e3da03170e94cae80e6d40ab8bf144c523f1496c0bb72a24edbd710ed96e13c","block_hash":"0x91f4a5437385cfc026ba229ed7c37d5d22c9a789b97ebe1b11ffc895419000a0","builder_pubkey":"0xaddea0de71ac5a8bc243bec7f7c7d9767aa8b129e54420217603e34faf519be8f57f42850a16539e803a13031dd4cd6b","proposer_pubkey":"0x8e815d6361afd8475e9ca1388aeadbea8abd1e21a80e7cffae85e3ccb8eaad8704168e96210bdd6c4b778ecd913ce17d","proposer_fee_recipient":"0x13F2241aa64bb6DA2B74553fA9E12B713b74F334","gas_limit":"30000000","gas_used":"21000","value":"42035392455000"},"execution_payload":{"parent_hash":"0x7e3da03170e94cae80e6d40ab8bf144c523f1496c0bb72a24edbd710ed96e13c","fee_recipient":"0x13F2241aa64bb6DA2B74553fA9E12B713b74F334","state_root":"0x0000000000000000000000000000000000000000000000000000000000000000","receipts_root":"0x056b23fbba480696b65fe5a59b8f2148a1299103c4f57df839233af2cf4ca2d2","logs_bloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000","prev_randao":"0x15c2cb2e95db2e4c1f62c72c4cd2a83c2cf012595066e89bcb6106df372109ab","block_number":"19905873","gas_limit":"30000000","gas_used":"21000","timestamp":"1716145667","extra_data":"0x","base_fee_per_gas":"2001685355","block_hash":"0x91f4a5437385cfc026ba229ed7c37d5d22c9a789b97ebe1b11ffc895419000a0","transactions":["0xf866808501dcf0076b8252089485e6919588cf2c82a5489c4606ec9c16ab960cc98203e88026a08ee0d6fea35637429d39f477a9c6709116e2287801582d8d9daa4d5f7478da09a06e27aa208b99a05b1b0f3483b14ee278a5b2e011f992a5f78aa66fa0bb2d1852"],"withdrawals":[{"index":"45936075","validator_index":"1083174","address":"0x210b3cb99fa1de0a64085fa80e18c22fe4722a1b","amount":"18290423"},{"index":"45936076","validator_index":"1083175","address":"0x210b3cb99fa1de0a64085fa80e18c22fe4722a1b","amount":"18432792"},{"index":"45936077","validator_index":"1083176","address":"0x210b3cb99fa1de0a64085fa80e18c22fe4722a1b","amount":"18315290"},{"index":"45936078","validator_index":"1083177","address":"0x210b3cb99fa1de0a64085fa80e18c22fe4722a1b","amount":"18286639"},{"index":"45936079","validator_index":"1083178","address":"0x210b3cb99fa1de0a64085fa80e18c22fe4722a1b","amount":"18340866"},{"index":"45936080","validator_index":"1083179","address":"0x210b3cb99fa1de0a64085fa80e18c22fe4722a1b","amount":"18329346"},{"index":"45936081","validator_index":"1083180","address":"0x210b3cb99fa1de0a64085fa80e18c22fe4722a1b","amount":"18456127"},{"index":"45936082","validator_index":"1083181","address":"0x210b3cb99fa1de0a64085fa80e18c22fe4722a1b","amount":"18361575"},{"index":"45936083","validator_index":"1083182","address":"0x210b3cb99fa1de0a64085fa80e18c22fe4722a1b","amount":"18410121"},{"index":"45936084","validator_index":"1083183","address":"0x210b3cb99fa1de0a64085fa80e18c22fe4722a1b","amount":"63239113"},{"index":"45936085","validator_index":"1083184","address":"0x210b3cb99fa1de0a64085fa80e18c22fe4722a1b","amount":"18314522"},{"index":"45936086","validator_index":"1083185","address":"0x210b3cb99fa1de0a64085fa80e18c22fe4722a1b","amount":"18463203"},{"index":"45936087","validator_index":"1083186","address":"0x210b3cb99fa1de0a64085fa80e18c22fe4722a1b","amount":"18370225"},{"index":"45936088","validator_index":"1083187","address":"0x210b3cb99fa1de0a64085fa80e18c22fe4722a1b","amount":"18426274"},{"index":"45936089","validator_index":"1083188","address":"0x210b3cb99fa1de0a64085fa80e18c22fe4722a1b","amount":"18347389"},{"index":"45936090","validator_index":"1083189","address":"0x2641c2ded63a0c640629f5edf1189e0f53c06561","amount":"18172407"}],"blob_gas_used":"0","excess_blob_gas":"0"},"blobs_bundle":{"commitments":[],"proofs":[],"blobs":[]},"signature":"0x89d1bd5453693e8ded23c0058fb69cf22e17e44cd1b6404d2245012acb7650fd26ed7aa72ff56775d8ed92f6fe300b1e01355a2c44dd2ce688c1a655470d21bd3910f2bb75c434a5346249e5bd382a490093acfa7a53237aae9c81876126cc77"};{"message":"accepted bid below floor, skipped validation"}
```

The block submitted won't be considered for inclusion because the transactions used to build the block in this demo aren't valid on mainnet. However, those transactions could easily be replaced with real transactions in another SUAPP.

⚠️ You may encounter an error `payload attributes not (yet) found`. This is common, and typically results from the beacon node being out of sync. Running the demo again often works. If it doesn't, you may need to check your node.

The `/eth/v1/node/syncing` endpoint is helpful in diagnosing this issue:

```sh
curl $L1_BEACON_URL/eth/v1/node/syncing
```

If your node is healthy, the response should look like this:

```json
{
    "data": {
        "is_syncing":false,
        "is_optimistic":false,
        "el_offline":false,
        "head_slot":"9110069",
        "sync_distance":"0"
    }
}
```
