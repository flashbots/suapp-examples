// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../suavelib/Suave.sol";
import "solady/src/utils/LibString.sol";
import "solady/src/utils/JSONParserLib.sol";

// https://github.com/flashbots/mev-share/blob/main/specs/bundles/v0.1.md#json-rpc-request-scheme
library MevShare {
    struct Bundle {
        uint64 inclusionBlock;
        bytes[] bodies;
        bool[] canRevert;
        uint8[] refundPercents;
    }

    function encodeBundle(Bundle memory bundle) internal pure returns (Suave.HttpRequest memory) {
        require(bundle.bodies.length == bundle.canRevert.length, "MevShare: bodies and canRevert length mismatch");
        bytes memory body = abi.encodePacked('{"jsonrpc":"2.0","method":"mev_sendBundle","params":[{"version":"v0.1",');

        // -> inclusion
        body =
            abi.encodePacked(body, '"inclusion":{"block":"', LibString.toMinimalHexString(bundle.inclusionBlock), '"},');

        // -> body
        body = abi.encodePacked(body, '"body":[');

        for (uint256 i = 0; i < bundle.bodies.length; i++) {
            body = abi.encodePacked(
                body,
                '{"tx":"',
                LibString.toHexString(bundle.bodies[i]),
                '","canRevert":',
                bundle.canRevert[i] ? "true" : "false",
                "}"
            );

            if (i < bundle.bodies.length - 1) {
                body = abi.encodePacked(body, ",");
            }
        }

        body = abi.encodePacked(body, "],");

        // -> validity
        body = abi.encodePacked(body, '"validity":{"refund":[');

        for (uint256 i = 0; i < bundle.refundPercents.length; i++) {
            body = abi.encodePacked(
                body,
                '{"bodyIdx":',
                LibString.toString(i),
                ',"percent":',
                LibString.toString(bundle.refundPercents[i]),
                "}"
            );

            if (i < bundle.refundPercents.length - 1) {
                body = abi.encodePacked(body, ",");
            }
        }

        body = abi.encodePacked(body, "]}");

        Suave.HttpRequest memory request;
        request.headers = new string[](1);
        request.headers[0] = "Content-Type:application/json";
        request.body = body;
        request.withFlashbotsSignature = true;

        return request;
    }

    function sendBundle(string memory url, Bundle memory bundle) internal {
        Suave.HttpRequest memory request = encodeBundle(bundle);
        request.url = url;
        Suave.doHTTPRequest(request);
    }
}
