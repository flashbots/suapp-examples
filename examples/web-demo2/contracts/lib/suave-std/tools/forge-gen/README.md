# Forge-gen command

In the `forge` integration, a `forge/Connector.sol` contract is deployed for each of the `Suave` precompiles. The contract uses the fallback function to make an `vm.ffi` call to the `suave forge` command to peform the logic request.

The `forge-gen` command creates the `forge/Registry.sol` contract which deploys the `Connector.sol` contract in all the precompile addresses using the `vm.etch` function.

## Usage

```bash
$ go run tools/forge-gen/main.go --apply
```

Use the `apply` flag to write the contract. Otherwise, it prints the contract on the standard output.
