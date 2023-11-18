// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "../../suave-geth/suave/sol/libraries/Suave.sol";

contract OnChainState {
    uint64 state;

    function nilExampleCallback() external payable {
    }

    function getState() external returns (uint64) {
        return state;
    }
    
    // nilExample is a function executed in a confidential request
    // that CANNOT modify the state of the smart contract.
    function nilExample() external payable returns (bytes memory) {
        require(Suave.isConfidential());
        state++;
        return abi.encodeWithSelector(this.nilExampleCallback.selector);
    }
    
    function exampleCallback() external payable {
        state++;
    }

    // example is a function executed in a confidential request that includes
    // a callback that can modify the state.
    function example() external payable returns (bytes memory) {
        require(Suave.isConfidential());
        return bytes.concat(this.exampleCallback.selector);
    }
}
