// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "../../suave-geth/suave/sol/libraries/Suave.sol";

contract RfqDriver {
    address[] solvers;
    Context currentContext;

    struct Context {
        string namespace;
        uint64 cond;
        address[] solvers;
    }

    struct Proposal {
        uint64 priority;
        bytes body;
    }

    function submitOrder(bytes memory order) external payable {
        Suave.Bid memory bid = Suave.newBid(
            currentContext.cond, 
            currentContext.solvers, 
            currentContext.solvers, 
            string.concat(currentContext.namespace, "/orders")
        );
        Suave.confidentialStore(bid.id, "data", order);
    }

    function generateOrders(Context memory newContext) external payable returns (bytes memory) {
        // aggregate all the proposals.
        // TODO: Aggregator logic.
        
        // update the current bid on chain
        return abi.encodeWithSelector(this.updateContext.selector, newContext);
    }

    function updateContext(Context memory newContext) external payable {
        currentContext = newContext;
    }
}

contract RfqSolver {
    address[] public addressList;

    constructor(address _driver) {
        addressList.push(_driver);
    }

    // solve fetches the current user orders and solves
    function solve(RfqDriver.Context memory context) external payable {
        Suave.Bid[] memory allBids = Suave.fetchBids(context.cond, context.namespace);

        // TODO: SOLVER LOGIC

        // write the proposal
        RfqDriver.Proposal memory p;

        Suave.Bid memory bid = Suave.newBid(
            context.cond, 
            addressList, 
            addressList, 
            string.concat(context.namespace, "/solution")
        );
    }
}
