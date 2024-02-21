// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../suavelib/Suave.sol";
import "solady/src/utils/LibString.sol";

// https://docs.flashbots.net/flashbots-auction/advanced/rpc-endpoint#eth_sendbundle
library Bundle {
    struct BundleObj {
        uint64 blockNumber;
        uint64 minTimestamp;
        uint64 maxTimestamp;
        bytes[] txns;
    }

    function sendBundle(string memory url, BundleObj memory bundle) internal returns (bytes memory) {
        Suave.HttpRequest memory request = encodeBundle(bundle);
        request.url = url;
        return Suave.doHTTPRequest(request);
    }

    function encodeBundle(BundleObj memory args) internal pure returns (Suave.HttpRequest memory) {
        require(args.txns.length > 0, "Bundle: no txns");

        bytes memory params =
            abi.encodePacked('{"blockNumber": "', LibString.toHexString(args.blockNumber), '", "txs": [');
        for (uint256 i = 0; i < args.txns.length; i++) {
            params = abi.encodePacked(params, '"', LibString.toHexString(args.txns[i]), '"');
            if (i < args.txns.length - 1) {
                params = abi.encodePacked(params, ",");
            } else {
                params = abi.encodePacked(params, "]");
            }
        }
        if (args.minTimestamp > 0) {
            params = abi.encodePacked(params, ', "minTimestamp": ', LibString.toString(args.minTimestamp));
        }
        if (args.maxTimestamp > 0) {
            params = abi.encodePacked(params, ', "maxTimestamp": ', LibString.toString(args.maxTimestamp));
        }
        params = abi.encodePacked(params, "}");

        bytes memory body =
            abi.encodePacked('{"jsonrpc":"2.0","method":"eth_sendBundle","params":[', params, '],"id":1}');

        Suave.HttpRequest memory request;
        request.method = "POST";
        request.body = body;
        request.headers = new string[](1);
        request.headers[0] = "Content-Type: application/json";
        request.withFlashbotsSignature = true;

        return request;
    }
}
