# Example Suapp with Offchain logs

This example shows how Suapps can emit logs during the confidential execution that are leaked during the onchain callback. To do so, the Suapp has to import the `suave-std/Suapp.sol` contract and use the `emitOffchainLogs` modifier in the onchain callback function. Then, logs emitted during the confidential execution which triggers the onchain computation will be emitted on the Suave chain.

The Suapp will look like this:

```
import "suave-std/Suapp.sol";

contract ExampleSuapp is Suapp {
    function onchainCallback() public emitOffchainLogs {
    }

    event OffchainLog();

    function offchain() public {
        emit OffchainLog();
        return abi.encodeWithSelector(this.onchainCallback.selector);
    }
}
```

## How to use

Run `Suave` in development mode:

```
$ suave-geth --suave.dev
```

Execute the deployment script:

```
$ go run main.go
```
