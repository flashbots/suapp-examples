pragma solidity ^0.8.8;

import "../../suave-geth/suave/sol/libraries/Suave.sol";

contract PublicSuapp {
    function callback() public payable {

    }

    function example() public payable returns (bytes memory) {
        bytes memory bytecode = Suave.confidentialInputs();
        address addr = deploy(bytecode);

        PrivateContractI c = PrivateContractI(addr);
        uint256 result = c.add(1, 2);
        require(result == 3);

        return abi.encodeWithSelector(this.callback.selector);
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

interface PrivateContractI {
    function add(uint256 a, uint256 b) external pure returns (uint256);
}

contract PrivateContract {
    function add(uint256 a, uint256 b) public pure returns (uint256) {
        return a+b;
    }
}
