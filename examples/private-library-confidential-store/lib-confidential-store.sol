pragma solidity ^0.8.8;

import "../../suave-geth/suave/sol/libraries/Suave.sol";

contract PublicSuapp {
    event ContractRegistered (
        Suave.BidId bidId
    );

    function registerContractCallback(Suave.BidId bidId) public payable {
        emit ContractRegistered(bidId);
    }

    function registerContract() public payable returns (bytes memory) {
        bytes memory bytecode = Suave.confidentialInputs();

        address[] memory allowedList = new address[](1);
        allowedList[0] = address(this);

        Suave.Bid memory bid = Suave.newBid(0, allowedList, allowedList, "contract");
        Suave.confidentialStore(bid.id, "bytecode", bytecode);

        return abi.encodeWithSelector(this.registerContractCallback.selector, bid.id);
    }

    function exampleCallback() public {
    }

    function example(Suave.BidId bidId) public payable returns (bytes memory) {
        bytes memory bytecode = Suave.confidentialRetrieve(bidId, "bytecode");
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
        return a+b;
    }
}