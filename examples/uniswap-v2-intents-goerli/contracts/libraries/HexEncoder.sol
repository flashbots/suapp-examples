// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library HexEncoder {
    function _encodeUint(uint256 value) internal pure returns (bytes memory result) {
        result = new bytes(64);
        for (uint256 i = 0; i < 32; i++) {
            bytes1 byteValue = bytes1(uint8(value / (2 ** (8 * (31 - i)))));
            result[i * 2] = _hexChar(uint8(byteValue) / 16);
            result[i * 2 + 1] = _hexChar(uint8(byteValue) % 16);
        }
        return result;
    }

    function _encodeBytes(bytes memory value, uint256 byteLength) internal pure returns (bytes memory result) {
        result = new bytes(byteLength * 2);
        for (uint256 i = 0; i < byteLength; i++) {
            bytes1 byteValue = value[i];
            result[i * 2] = _hexChar(uint8(byteValue) / 16);
            result[i * 2 + 1] = _hexChar(uint8(byteValue) % 16);
        }
    }

    function _encodeBytes(bytes32 value, uint256 byteLength) internal pure returns (bytes memory result) {
        result = _encodeBytes(abi.encodePacked(value), byteLength);
    }

    function toHexString(bytes32 value, bool removeLeadingZeros, bool addHexPrefix)
        internal
        pure
        returns (string memory hexString)
    {
        hexString = toHexString(value, removeLeadingZeros);
        if (addHexPrefix) {
            return string.concat("0x", hexString);
        }
    }

    function toHexString(uint256 value, bool removeLeadingZeros, bool addHexPrefix)
        internal
        pure
        returns (string memory hexString)
    {
        hexString = toHexString(bytes32(value), removeLeadingZeros, addHexPrefix);
    }

    function toHexString(bytes memory value, bool removeLeadingZeros, bool addHexPrefix)
        internal
        pure
        returns (string memory hexString)
    {
        hexString = toHexString(value, removeLeadingZeros);
        if (addHexPrefix) {
            return string.concat("0x", hexString);
        }
    }

    function toHexString(bytes32 value, bool removeLeadingZeros) internal pure returns (string memory) {
        bytes memory result = _encodeBytes(value, 32);
        if (removeLeadingZeros) {
            return string(_removeLeadingZeros(result, 64));
        }
        return string(result);
    }

    function toHexString(uint256 value, bool removeLeadingZeros) internal pure returns (string memory) {
        bytes memory result = _encodeUint(value);
        if (removeLeadingZeros) {
            return string(_removeLeadingZeros(result, 64));
        }
        return string(result);
    }

    function toHexString(bytes memory value, bool removeLeadingZeros) internal pure returns (string memory) {
        bytes memory result = _encodeBytes(value, value.length);
        if (removeLeadingZeros) {
            return string(_removeLeadingZeros(result, value.length * 2));
        }
        return string(result);
    }

    function _removeLeadingZeros(
        bytes memory value,
        uint256 charsLength // byteLength * 2
    ) internal pure returns (bytes memory) {
        uint256 lastIndex;
        for (uint256 i = 0; i < charsLength; i++) {
            if (value[i] != bytes1("0")) {
                lastIndex = uint256(i);
                break;
            }
        }
        bytes memory result = new bytes(charsLength - lastIndex);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = value[i + lastIndex];
        }
        return result;
    }

    function _hexChar(uint8 value) internal pure returns (bytes1) {
        if (value < 10) {
            return bytes1(uint8(bytes1("0")) + value);
        } else {
            return bytes1(uint8(bytes1("a")) + (value - 10));
        }
    }
}
