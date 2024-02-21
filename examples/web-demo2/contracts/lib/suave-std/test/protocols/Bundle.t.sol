// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/protocols/Bundle.sol";
import "src/suavelib/Suave.sol";

contract EthSendBundle is Test {
    function testEthSendBundleEncode() public {
        Bundle.BundleObj memory bundle;
        bundle.blockNumber = 1;
        bundle.txns = new bytes[](1);
        bundle.txns[0] = hex"1234";

        Suave.HttpRequest memory request = Bundle.encodeBundle(bundle);
        assertEq(
            string(request.body),
            '{"jsonrpc":"2.0","method":"eth_sendBundle","params":[{"blockNumber": "0x01", "txs": ["0x1234"]}],"id":1}'
        );
        assertTrue(request.withFlashbotsSignature);

        // encode with 'minTimestamp'
        bundle.minTimestamp = 2;

        Suave.HttpRequest memory request2 = Bundle.encodeBundle(bundle);
        assertEq(
            string(request2.body),
            '{"jsonrpc":"2.0","method":"eth_sendBundle","params":[{"blockNumber": "0x01", "txs": ["0x1234"], "minTimestamp": 2}],"id":1}'
        );

        // encode with 'maxTimestamp'
        bundle.maxTimestamp = 3;

        Suave.HttpRequest memory request3 = Bundle.encodeBundle(bundle);
        assertEq(
            string(request3.body),
            '{"jsonrpc":"2.0","method":"eth_sendBundle","params":[{"blockNumber": "0x01", "txs": ["0x1234"], "minTimestamp": 2, "maxTimestamp": 3}],"id":1}'
        );
    }
}
