// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "../../suave-geth/suave/sol/libraries/Suave.sol";

contract RfqDriver {
    constructor(address[] memory solvers) {
        // create a threshold signature
    }

    event EmitOrder(bytes order);

    function submitOrderCallback(bytes memory order) external payable {
        emit EmitOrder(order);
    }
    
    function submitOrder(bytes memory order) external payable returns (bytes memory) {
        bytes memory orderEncrypted = encryptOrder(order);
        return abi.encodeWithSelector(this.submitOrderCallback.selector, orderEncrypted);
    }
    
    function encryptOrder(bytes memory order) internal returns (bytes memory) {
        bytes memory orderEncrypted;
        return orderEncrypted;
    }

    function submitSolution(bytes memory solution) external payable {
        uint64 score = evaluateSolution(solution);

        // Store the solution in the confidential store
        address[] emptyAddr;

        Suave.Bid memory bid = Suave.newBid(0, emptyAddr, emptyAddr, "namespace");
        Suave.confidentialStore(bid.id, "solution", solution);
        Suave.confidentialStore(bid.id, "score", abi.encode(score));
    }

    function evaluateSolution(bytes memory solution) internal pure returns (uint64) {
        // TODO: Score based on user execution
        return 0;
    }

    function settle() public payable {
        Suave.Bid[] memory solutions = Suave.fetchBids(10, "namespace");
        require(solutions.length > 0, "No bids available");

        uint64 highestScore = 0;
        uint256 winningBidIndex;

        for (uint256 i = 0; i < solutions.length; i++) {
            uint64 score = abi.decode(Suave.confidentialRetrieve(solutions[i].id, "score"), (uint64));

            if (score > highestScore) {
                highestScore = score;
                winningBidIndex = i;
            }
        }

        Suave.Bid memory winningBid = solutions[winningBidIndex];
        bytes memory solution = Suave.confidentialRetrieve(winningBid.id, "solution");

        emitWinningSolutionToL1(solution);
    }

    function emitWinningSolutionToL1(bytes memory solution) internal {
    }
}
