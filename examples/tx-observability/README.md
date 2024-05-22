# tx observability

Opt into a standardized set of events ([TBD](https://github.com/flashbots/suave-std/pull/85)) to enable interoperability with other SUAPPS, block-builders, L2 networks, etc.

Events are defined in an abstract contract (ideally in suave-std):

```solidity
abstract contract ObservableOrderflow {
    event SentTransaction(bytes32 txHash);
}
```

Then SUAPP developers import and emit those events in their own callbacks:

```solidity
contract Suapp is ObservableOrderflow {
    event MySuappEvent(uint256 x);

    modifier confidential() {
        require(Suave.isConfidential(), "must be called confidentially");
        _;
    }

    function didSomething(bytes32[] memory txHashes, uint256 x) public confidential {
        emit MySuappEvent(x);
        emit SentTransactions(txHashes);
    }

    function doSomething() public confidential returns (bytes memory) {
        // pretend these are tx hashes that we're handling in our SUAPP
        bytes32[] memory txHashes = new bytes32[](3);
        for (uint256 i = 0; i < txHashes.length; i++) {
            txHashes[i] = keccak256(abi.encode("tx", i));
        }
        return abi.encodeWithSelector(this.didSomethingWithTxs.selector, txHashes, 9001);
    }
}
```
