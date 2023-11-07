# Example Suapp with external calls

This example features how a Suapp can make an external call to a contract deployed on the suave-enabled chain.

This example assumes there is a contract like this deployed on the suave-enabled chain

```solidity
contract ExampleEthCallTarget {
    function get() public view returns (uint256) {
        return 101;
    }
}
```

To test this example, the Suave nodes needs to connect to the suave-enabled node with the `--suave.rpc-endpoint` flag.
