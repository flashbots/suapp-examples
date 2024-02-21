// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

contract ContextConnector {
    bytes confidentialInputs;
    address kettleAddress;

    function setConfidentialInputs(bytes memory _confidentialInputs) public {
        confidentialInputs = _confidentialInputs;
    }

    function resetConfidentialInputs() public {
        confidentialInputs = "";
    }

    function setKettleAddress(address _kettleAddress) public {
        kettleAddress = _kettleAddress;
    }

    function resetKettleAddress() public {
        setKettleAddress(address(0));
    }

    fallback() external {
        (string memory key) = abi.decode(msg.data, (string));
        bytes32 keyHash = keccak256(abi.encodePacked(key));

        bytes memory msgContent;
        if (keyHash == keccak256(abi.encodePacked("confidentialInputs"))) {
            msgContent = confidentialInputs;
        } else if (keyHash == keccak256(abi.encodePacked("kettleAddress"))) {
            msgContent = abi.encode(kettleAddress);
        } else {
            revert("Invalid context key");
        }

        bytes memory msgdata = abi.encode(msgContent);
        assembly {
            let location := msgdata
            let length := mload(msgdata)
            return(add(location, 0x20), length)
        }
    }
}
