// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "suave-std/suavelib/Suave.sol";
import {Bundle} from "suave-std/protocols/Bundle.sol";
import "solady/src/utils/LibString.sol";

contract OFAPrivate {
    // Struct to hold hint-related information for an order.
    struct HintOrder {
        Suave.DataId id;
        bytes hint;
    }

    event HintEvent(Suave.DataId id, bytes hint);

    event BundleEmitted(string bundleRawResponse);

    event Debug(string message, bytes data);

    // Internal function to save order details and generate a hint.
    function saveOrder(uint64 decryptionCondition) internal returns (HintOrder memory) {
        // Retrieve the bundle data from the confidential inputs
        bytes memory bundleData = Suave.confidentialInputs();
        Bundle.BundleObj memory bundle = abi.decode(bundleData, (Bundle.BundleObj));
        bundleData = Bundle.encodeBundle(bundle).body;

        // Simulate the bundle and extract its score.
        uint64 egp = Suave.simulateBundle(bundleData);

        // Extract a hint about this bundle that is going to be leaked
        // to external applications.
        bytes memory extractHintPayload = abi.encodePacked(
            '{"revertingHashes": [], "txs": ['
        );
        for (uint256 i = 0; i < bundle.txns.length; i++) {
            extractHintPayload = abi.encodePacked(
                extractHintPayload,
                '"',
                LibString.toHexString(bundle.txns[i]),
                '"'
            );
            if (i < bundle.txns.length - 1) {
                extractHintPayload = abi.encodePacked(extractHintPayload, ",");
            }
        }
        extractHintPayload = abi.encodePacked(
            extractHintPayload,
            ']}'
        );
        bytes memory hint = Suave.extractHint(extractHintPayload);

        address[] memory allowedList = new address[](2);
        allowedList[0] = address(this);
        allowedList[1] = 0x0000000000000000000000000000000043200001;

        // Store the bundle and the simulation results in the confidential datastore.
        Suave.DataRecord memory dataRecord = Suave.newDataRecord(decryptionCondition, allowedList, allowedList, "");
        Suave.confidentialStore(dataRecord.id, "mevshare:v0:ethBundles", bundleData);
        Suave.confidentialStore(dataRecord.id, "mevshare:v0:ethBundleSimResults", abi.encode(egp));

        HintOrder memory hintOrder;
        hintOrder.id = dataRecord.id;
        hintOrder.hint = hint;

        return hintOrder;
    }

    function emitHint(HintOrder memory order) public payable {
        emit HintEvent(order.id, order.hint);
    }

    // Function to create a new user order
    function newOrder(uint64 decryptionCondition) external payable returns (bytes memory) {
        HintOrder memory hintOrder = saveOrder(decryptionCondition);
        return abi.encodeWithSelector(this.emitHint.selector, hintOrder);
    }

    // Function to match and backrun another dataRecord.
    function newMatch(Suave.DataId shareDataRecordId, uint64 decryptionCondition)
        external
        payable
        returns (bytes memory)
    {
        HintOrder memory hintOrder = saveOrder(decryptionCondition);

        // Merge the dataRecords and store them in the confidential datastore.
        // The 'fillMevShareBundle' precompile will use this information to send the bundles.
        Suave.DataId[] memory dataRecords = new Suave.DataId[](2);
        dataRecords[0] = shareDataRecordId;
        dataRecords[1] = hintOrder.id;
        Suave.confidentialStore(hintOrder.id, "mevshare:v0:mergedDataRecords", abi.encode(dataRecords));

        return abi.encodeWithSelector(this.emitHint.selector, hintOrder);
    }

    function emitMatchDataRecordAndHintCallback(string memory bundleRawResponse) external payable {
        emit BundleEmitted(bundleRawResponse);
    }

    function emitMatchDataRecordAndHint(string memory builderUrl, Suave.DataId dataRecordId)
        external
        payable
        returns (bytes memory)
    {
        bytes memory bundleData = Suave.fillMevShareBundle(dataRecordId);
        bytes memory response = submitBundle(builderUrl, bundleData);

        return abi.encodeWithSelector(this.emitMatchDataRecordAndHintCallback.selector, response);
    }

    function submitBundle(string memory builderUrl, bytes memory bundleData) internal returns (bytes memory) {
        // encode the jsonrpc request in JSON format.
        bytes memory body =
            abi.encodePacked('{"jsonrpc":"2.0","method":"mev_sendBundle","params":[', bundleData, '],"id":1}');

        Suave.HttpRequest memory request;
        request.url = builderUrl;
        request.method = "POST";
        request.body = body;
        request.headers = new string[](1);
        request.headers[0] = "Content-Type: application/json";
        request.withFlashbotsSignature = true;

        return Suave.doHTTPRequest(request);
    }
}
