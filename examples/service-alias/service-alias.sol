// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "suave-std/suavelib/Suave.sol";
import "suave-std/Suapp.sol";

contract ServiceAlias is Suapp {
    function exampleCallback() public {}

    function example() public returns (bytes memory) {
        Suave.HttpRequest memory request;
        request.url = "example";
        request.method = "GET";
        request.timeout = 1000;

        bytes memory response1 = Suave.doHTTPRequest(request);

        // Make the request to the http endpoint
        request.url = "https://example.com";
        bytes memory response2 = Suave.doHTTPRequest(request);

        require(keccak256(response1) == keccak256(response2), "Strings should be equal");
        return abi.encodeWithSelector(this.exampleCallback.selector);
    }
}
