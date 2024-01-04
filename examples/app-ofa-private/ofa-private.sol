// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "suave-std/suavelib/Suave.sol";

contract OFAPrivate {
    address[] public addressList = [0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829];

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

        // Store the bundle and the simulation results in the confidential datastore.
        Suave.DataRecord memory bid = Suave.newDataRecord(
            10,
            addressList,
            addressList,
            ""
        );
        Suave.confidentialStore(bid.id, "mevshare:v0:ethBundles", bundleData);
        Suave.confidentialStore(
            bid.id,
            "mevshare:v0:ethBundleSimResults",
            abi.encode(egp)
        );

        HintOrder memory hintOrder;
        hintOrder.id = bid.id;
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

    // Function to match and backrun another bid.
    function newMatch(
        Suave.DataId shareBidId
    ) external payable returns (bytes memory) {
        HintOrder memory hintOrder = saveOrder();

        // Merge the bids and store them in the confidential datastore.
        // The 'fillMevShareBundle' precompile will use this information to send the bundles.
        Suave.DataId[] memory bids = new Suave.DataId[](2);
        bids[0] = shareBidId;
        bids[1] = hintOrder.id;
        Suave.confidentialStore(
            hintOrder.id,
            "mevshare:v0:mergedBids",
            abi.encode(bids)
        );

        return abi.encodeWithSelector(this.emitHint.selector, hintOrder);
    }

    function emitMatchBidAndHintCallback() external payable {}

    function emitMatchBidAndHint(
        string memory builderUrl,
        Suave.DataId bidId
    ) external payable returns (bytes memory) {
        bytes memory bundleData = Suave.fillMevShareBundle(bidId);
        Suave.submitBundleJsonRPC(builderUrl, "mev_sendBundle", bundleData);

        return
            abi.encodeWithSelector(this.emitMatchBidAndHintCallback.selector);
    }
}
