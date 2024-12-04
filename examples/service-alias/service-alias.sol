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

        Suave.HttpResponse memory response1 = Suave.doHTTPRequest2(request);

        // Make the request to the http endpoint
        request.url = "https://example.com";
        Suave.HttpResponse memory response2 = Suave.doHTTPRequest2(request);

        require(response1.status == 200, "Status should be 200");
        require(response2.status == 200, "Status should be 200");

        require(keccak256(response1.body) == keccak256(response2.body), "Strings should be equal");
        return abi.encodeWithSelector(this.exampleCallback.selector);
    }
}
