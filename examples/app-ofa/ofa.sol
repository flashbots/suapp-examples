// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "../../suave-geth/suave/sol/libraries/Suave.sol";

contract OFA {
    event NewOrder (
        Suave.BidId id,
        bytes hint
    );
    
    function newOrderCallback(Suave.BidId id, bytes memory hint) public payable {
        emit NewOrder(id, hint);
    }

    function newOrder(bytes memory order) external payable returns (bytes memory) {
        // Retrieve the bundle data from the confidential inputs
        bytes memory bundleData = Suave.confidentialInputs();

        // Simulate the bundle and extract its score
        uint64 egp = Suave.simulateBundle(bundleData);

        // Extract a hint about this bundle that is going to be leaked
        // to external applications
        bytes memory hint = Suave.extractHint(bundleData);

        // Store the bundle and the simulation results in the confidential datastore.
        Suave.Bid memory bid = Suave.newBid();
        Suave.confidentialStore(bid.id, "ofa-app", order);
		Suave.confidentialStore(bid.id, "ofa-app", abi.encode(egp));

        // Use the callback to return the hint and the id of the order.
        abi.encodeWithSelector(this.newOrderCallback.selector, bid.id, hint);
    }
}
