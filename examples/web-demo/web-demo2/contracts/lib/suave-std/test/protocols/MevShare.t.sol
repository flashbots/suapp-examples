// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/protocols/MevShare.sol";
import "src/suavelib/Suave.sol";

contract MevShareTest is Test {
    function testEncodeMevShare() public {
        MevShare.Bundle memory bundle;
        bundle.inclusionBlock = 1;

        bundle.bodies = new bytes[](1);
        bundle.bodies[0] = hex"1234";

        bundle.canRevert = new bool[](1);
        bundle.canRevert[0] = true;

        bundle.refundPercents = new uint8[](1);
        bundle.refundPercents[0] = 10;

        Suave.HttpRequest memory request = MevShare.encodeBundle(bundle);
        assertEq(
            string(request.body),
            '{"jsonrpc":"2.0","method":"mev_sendBundle","params":[{"version":"v0.1","inclusion":{"block":"0x1"},"body":[{"tx":"0x1234","canRevert":true}],"validity":{"refund":[{"bodyIdx":0,"percent":10}]}'
        );
        assertTrue(request.withFlashbotsSignature);
    }
}
