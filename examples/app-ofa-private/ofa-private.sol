// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "suave-std/suavelib/Suave.sol";

contract OFAPrivate {
    // Struct to hold hint-related information for an order.
    struct HintOrder {
        Suave.DataId id;
        bytes hint;
    }

    event HintEvent(Suave.DataId id, bytes hint);

    // Internal function to save order details and generate a hint.
    function saveOrder() internal view returns (HintOrder memory) {
        // Retrieve the bundle data from the confidential inputs
        bytes memory bundleData = Suave.confidentialInputs();

        // Simulate the bundle and extract its score.
        uint64 egp = Suave.simulateBundle(bundleData);

        // Extract a hint about this bundle that is going to be leaked
        // to external applications.
        bytes memory hint = Suave.extractHint(bundleData);

        address[] memory allowedList = new address[](2);
        allowedList[0] = address(this);
        allowedList[1] = 0x0000000000000000000000000000000043200001;

        // Store the bundle and the simulation results in the confidential datastore.
        Suave.DataRecord memory dataRecord = Suave.newDataRecord(10, allowedList, allowedList, "");
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
    function newOrder() external payable returns (bytes memory) {
        HintOrder memory hintOrder = saveOrder();
        return abi.encodeWithSelector(this.emitHint.selector, hintOrder);
    }

    // Function to match and backrun another dataRecord.
    function newMatch(Suave.DataId shareDataRecordId) external payable returns (bytes memory) {
        HintOrder memory hintOrder = saveOrder();

        // Merge the dataRecords and store them in the confidential datastore.
        // The 'fillMevShareBundle' precompile will use this information to send the bundles.
        Suave.DataId[] memory dataRecords = new Suave.DataId[](2);
        dataRecords[0] = shareDataRecordId;
        dataRecords[1] = hintOrder.id;
        Suave.confidentialStore(hintOrder.id, "mevshare:v0:mergedBids", abi.encode(dataRecords));

        return abi.encodeWithSelector(this.emitHint.selector, hintOrder);
    }

    function emitMatchDataRecordAndHintCallback() external payable {}

    function emitMatchDataRecordAndHint(string memory builderUrl, Suave.DataId dataRecordId)
        external
        payable
        returns (bytes memory)
    {
        bytes memory bundleData = Suave.fillMevShareBundle(dataRecordId);
        Suave.submitBundleJsonRPC(builderUrl, "mev_sendBundle", bundleData);

        return abi.encodeWithSelector(this.emitMatchDataRecordAndHintCallback.selector);
    }
}
