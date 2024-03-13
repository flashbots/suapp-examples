// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.8;

import "suave-std/suavelib/Suave.sol";
import "suave-std/Context.sol";

contract PublicSuapp {
    event ContractRegistered(Suave.DataId dataId);

    function registerContractCallback(Suave.DataId dataId) public {
        emit ContractRegistered(dataId);
    }

    function registerContract() public returns (bytes memory) {
        bytes memory bytecode = Context.confidentialInputs();

        address[] memory allowedList = new address[](1);
        allowedList[0] = address(this);

        Suave.DataRecord memory dataRecord = Suave.newDataRecord(0, allowedList, allowedList, "contract");
        Suave.confidentialStore(dataRecord.id, "bytecode", bytecode);

        return abi.encodeWithSelector(this.registerContractCallback.selector, dataRecord.id);
    }

    function exampleCallback() public {}

    function example(Suave.DataId dataId) public returns (bytes memory) {
        bytes memory bytecode = Suave.confidentialRetrieve(dataId, "bytecode");
        address addr = deploy(bytecode);

        PrivateLibraryI c = PrivateLibraryI(addr);
        uint256 result = c.add(1, 2);
        require(result == 3);

        return abi.encodeWithSelector(this.exampleCallback.selector);
    }

    function deploy(bytes memory _code) internal returns (address addr) {
        assembly {
            // create(v, p, n)
            // v = amount of ETH to send
            // p = pointer in memory to start of code
            // n = size of code
            addr := create(callvalue(), add(_code, 0x20), mload(_code))
        }
        // return address 0 on error
        require(addr != address(0), "deploy failed");
    }
}

interface PrivateLibraryI {
    function add(uint256 a, uint256 b) external pure returns (uint256);
}

contract PrivateLibrary {
    function add(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;
    }
}
