// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "../../suave-geth/suave/sol/libraries/Suave.sol";

contract TAuction {
    struct Auction {
        uint256 id;
        string auctionType;
        address creator;
        uint64 startBlock;
        uint64 endBlock;
        uint256 totalAmount;
        uint16 coupon;
    }

    struct Bid {
        uint256 amount;
        uint16 rate;
    }

    Auction[] public auctions;
    mapping(uint256 => Suave.BidId[]) private _bids;

    event AuctionCreated(uint256 indexed auctionId, string auctionType, address indexed creator, uint256 startBlock, uint256 endBlock, uint16 coupon);
    event AuctionCompleted(uint256 indexed auctionId, uint256 btc, uint16 stopRate);
    event BidSubmitted(uint256 indexed auctionId, Suave.BidId bidId);

    // Create a new auction
    function createAuction(string memory auctionType, uint256 totalAmount, uint64 duration, uint8 coupon) external returns (uint256) {
        uint256 auctionId = auctions.length;
        auctions.push(Auction(auctionId, auctionType, msg.sender, block.number, block.number + duration, totalAmount, coupon));
        emit AuctionCreated(auctionId, auctionType, msg.sender, uint64(block.number), uint64(block.number + duration), coupon);
        return auctionId;
    }

    // Submit a bid (confidentially)
    // the decryption condition will be the startBlock
    // TODO: why are decryption conditions uint64s, but often we use block numbers, which are generally uint256?
    function submitBid(address[] memory bidAllowedPeekers, address[] memory bidAllowedStores, uint64 blockHeight) external payable {
        require(Suave.isConfidential(), "Execution must be confidential");
        
        bytes memory confidentialInputs = Suave.confidentialInputs();
        (uint256 auctionId, uint256 amount, uint16 rate) = abi.decode(confidentialInputs, (uint256, uint256, uint16));

        require(auctionId < auctions.length, "Invalid auction ID");
        require(auctions[auctionId].startBlock > block.number, "Auction yet to start");
        require(auctions[auctionId].endBlock < block.number, "Auction ended");

        if (rate == 0) {
            // Store non-competitive bid
            Suave.Bid memory bid = Suave.newBid(auctions[auctionId].startBlock, bidAllowedPeekers, bidAllowedStores, "tauction:v0:noncompetitive");
            Suave.confidentialStore(bid.id, "tauction:v0:noncompetitive", confidentialInputs);
            // Calculate current total and store for later
            bytes memory totalData = Suave.confidentialRetrieve(bid.id, "tauction:v0:noncompetitivetotal");
            uint256 currentTotal = totalData.length > 0 ? abi.decode(totalData, (uint256)) : 0;
            uint256 newTotal = currentTotal + amount;
            Suave.confidentialStore(bid.id, "tauction:v0:noncompetitivetotal", abi.encode(newTotal));
            emit BidSubmitted(auctionId, bid.id);
        } else {
            // Store competitive bids, in order of rate offered
            Suave.Bid memory bid = Suave.newBid(auctions[auctionId].startBlock, bidAllowedPeekers, bidAllowedStores, "tauction:v0:competitive");
            Suave.Bid[] memory allCompetitiveSortedBids = Suave.fetchBids(blockHeight, "tauction:v0:competitiveSorted");

            // TODO: I want to store competitive bids in ascending order, where 
            // 1 is the lowest rate, 2 is slightly higher etc.
            // overwriting ids won't work, and I am not sure how to add a new field to the confidentialInputs

             // no sorted bids yet - goes in at rank 1
            if (allCompetitiveSortedBids.length == 0) {
                Suave.confidentialStore(1, "tauction:v0:competitiveSorted", confidentialInputs);
            }
            // some bids in the sorted array, need to insert new one
            bool inserted = false;
            uint i = 0;
            
            for (; i < allCompetitiveSortedBids.length; i++) {
                // TODO: is this the correct way to retrieve the rate stored for any given bid?
                uint16 rateToCompare = abi.decode(Suave.confidentialRetrieve(i, "tauction:v0:competitiveSorted"), (uint16));
                
                if (rate < rateToCompare) {
                    // Insert the current bid here and shift the others
                    shiftAndStoreBids(i, allCompetitiveSortedBids.length, confidentialInputs);
                    Suave.confidentialStore(i, "tauction:v0:competitiveSorted", confidentialInputs);
                    inserted = true;
                    break;
                }
            }

            if (!inserted) {
                // If the current bid's rate is higher than all, insert at the end
                Suave.confidentialStore(allCompetitiveSortedBids.length, "tauction:v0:competitiveSorted", confidentialInputs);
            }

            emit BidSubmitted(auctionId, bid.id);
		}
    }

    // Complete an auction and emit results
    // Anyone can call this, as the creator sets the duration
    // question: can/should it emit all bids for public verification?
    function completeAuction(uint256 auctionId) external {
        require(auctionId < auctions.length, "Invalid auction ID");
        require(auctions[auctionId].endBlock < block.number, "Auction not complete");
        
        (uint256 btc, uint16 stopRate) = calculateAuctionOutcome(auctionId);
        emit AuctionCompleted(auctionId, btc, stopRate);
    }


    // Calculate the btc and stop rate
    function calculateAuctionOutcome(uint256 auctionId) private view returns (uint256 btc, uint256 stopRate) {
        Auction memory auction = auctions[auctionId];
        bytes memory nonCompetitiveTotalData = Suave.confidentialRetrieve(auction.startBlock, "tauction:v0:noncompetitivetotal");
        uint256 nonCompetitiveTotal = nonCompetitiveTotalData.length > 0 ? abi.decode(nonCompetitiveTotalData, (uint256)) : 0;

        uint256 remainingAmount = auction.totalAmount - nonCompetitiveTotal;
        uint256 totalCompetitiveBidAmount = 0;
        bool stopRateSet = false;

        Suave.Bid[] memory competitiveBids = Suave.fetchBids(auction.startBlock, "tauction:v0:competitiveSorted");
        for (uint i = 0; i < competitiveBids.length; i++) {
            (uint256 bidAmount, uint16 bidRate) = abi.decode(Suave.confidentialRetrieve(competitiveBids[i].id, "tauction:v0:competitive"), (uint256, uint16));
            totalCompetitiveBidAmount += bidAmount;

            if (!stopRateSet && remainingAmount > 0) {
                if (remainingAmount <= bidAmount) {
                    stopRate = bidRate;
                    stopRateSet = true;
                }
                remainingAmount -= bidAmount;
            }
        }

        btc = (nonCompetitiveTotal + totalCompetitiveBidAmount) / auction.totalAmount;
        return (btc, stopRate);
    }

    function shiftAndStoreBids(uint startIdx, uint length, bytes memory currentBidData) private {
        for (uint j = length; j > startIdx; j--) {
            bytes memory bidDataToShift = Suave.confidentialRetrieve(j - 1, "tauction:v0:competitiveSorted");
            Suave.confidentialStore(j, "tauction:v0:competitiveSorted", bidDataToShift);
        }
        Suave.confidentialStore(startIdx, "tauction:v0:competitiveSorted", currentBidData);
    }

}
