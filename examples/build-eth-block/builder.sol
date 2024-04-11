// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "suave-std/suavelib/Suave.sol";
import {Suapp} from "suave-std/Suapp.sol";

contract AnyBundleContract {
    event DataRecordEvent(Suave.DataId dataId, uint64 decryptionCondition, address[] allowedPeekers);

    function fetchConfidentialBundleData() public returns (bytes memory) {
        require(Suave.isConfidential());

        bytes memory confidentialInputs = Suave.confidentialInputs();
        return abi.decode(confidentialInputs, (bytes));
    }

    function emitDataRecord(Suave.DataRecord calldata dataRecord) public {
        emit DataRecordEvent(dataRecord.id, dataRecord.decryptionCondition, dataRecord.allowedPeekers);
    }
}

contract BundleContract is AnyBundleContract {
    function newBundle(
        uint64 decryptionCondition,
        address[] memory dataAllowedPeekers,
        address[] memory dataAllowedStores
    ) external payable returns (bytes memory) {
        require(Suave.isConfidential());

        bytes memory bundleData = this.fetchConfidentialBundleData();

        uint64 egp = Suave.simulateBundle(bundleData);

        Suave.DataRecord memory dataRecord =
            Suave.newDataRecord(decryptionCondition, dataAllowedPeekers, dataAllowedStores, "default:v0:ethBundles");

        Suave.confidentialStore(dataRecord.id, "default:v0:ethBundles", bundleData);
        Suave.confidentialStore(dataRecord.id, "default:v0:ethBundleSimResults", abi.encode(egp));

        return emitAndReturn(dataRecord, bundleData);
    }

    function emitAndReturn(Suave.DataRecord memory dataRecord, bytes memory) internal virtual returns (bytes memory) {
        emit DataRecordEvent(dataRecord.id, dataRecord.decryptionCondition, dataRecord.allowedPeekers);
        return bytes.concat(this.emitDataRecord.selector, abi.encode(dataRecord));
    }
}

contract EthBundleSenderContract is BundleContract {
    string[] public builderUrls;

    constructor(string[] memory builderUrls_) {
        builderUrls = builderUrls_;
    }

    function emitAndReturn(Suave.DataRecord memory dataRecord, bytes memory bundleData)
        internal
        virtual
        override
        returns (bytes memory)
    {
        for (uint256 i = 0; i < builderUrls.length; i++) {
            Suave.submitBundleJsonRPC(builderUrls[i], "eth_sendBundle", bundleData);
        }

        return BundleContract.emitAndReturn(dataRecord, bundleData);
    }
}

struct EgpRecordPair {
    uint64 egp; // in wei, beware overflow
    Suave.DataId dataId;
}

contract EthBlockContract is AnyBundleContract {
    event BuilderBoostBidEvent(Suave.DataId dataId, bytes builderBid);

    function idsEqual(Suave.DataId _l, Suave.DataId _r) public pure returns (bool) {
        bytes memory l = abi.encodePacked(_l);
        bytes memory r = abi.encodePacked(_r);
        for (uint256 i = 0; i < l.length; i++) {
            if (bytes(l)[i] != r[i]) {
                return false;
            }
        }

        return true;
    }

    function buildFromPool(Suave.BuildBlockArgs memory blockArgs, uint64 blockHeight) public returns (bytes memory) {
        require(Suave.isConfidential());

        Suave.DataRecord[] memory allRecords = Suave.fetchDataRecords(blockHeight, "default:v0:ethBundles");
        if (allRecords.length == 0) {
            revert Suave.PeekerReverted(address(this), "no data records");
        }

        EgpRecordPair[] memory bidsByEGP = new EgpRecordPair[](allRecords.length);
        for (uint256 i = 0; i < allRecords.length; i++) {
            bytes memory simResults = Suave.confidentialRetrieve(allRecords[i].id, "default:v0:ethBundleSimResults");
            uint64 egp = abi.decode(simResults, (uint64));
            bidsByEGP[i] = EgpRecordPair(egp, allRecords[i].id);
        }

        // Bubble sort, cause why not
        uint256 n = bidsByEGP.length;
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = i + 1; j < n; j++) {
                if (bidsByEGP[i].egp < bidsByEGP[j].egp) {
                    EgpRecordPair memory temp = bidsByEGP[i];
                    bidsByEGP[i] = bidsByEGP[j];
                    bidsByEGP[j] = temp;
                }
            }
        }

        Suave.DataId[] memory alldataIds = new Suave.DataId[](allRecords.length);
        for (uint256 i = 0; i < bidsByEGP.length; i++) {
            alldataIds[i] = bidsByEGP[i].dataId;
        }

        return buildAndEmit(blockArgs, blockHeight, alldataIds, "");
    }

    function buildAndEmit(
        Suave.BuildBlockArgs memory blockArgs,
        uint64 blockHeight,
        Suave.DataId[] memory records,
        string memory namespace
    ) public virtual returns (bytes memory) {
        require(Suave.isConfidential());

        (Suave.DataRecord memory blockBid, bytes memory builderBid) =
            this.doBuild(blockArgs, blockHeight, records, namespace);

        emit BuilderBoostBidEvent(blockBid.id, builderBid);
        emit DataRecordEvent(blockBid.id, blockBid.decryptionCondition, blockBid.allowedPeekers);
        return bytes.concat(this.emitBuilderBidAndBid.selector, abi.encode(blockBid, builderBid));
    }

    function doBuild(
        Suave.BuildBlockArgs memory blockArgs,
        uint64 blockHeight,
        Suave.DataId[] memory records,
        string memory namespace
    ) public returns (Suave.DataRecord memory, bytes memory) {
        address[] memory allowedPeekers = new address[](2);
        allowedPeekers[0] = address(this);
        allowedPeekers[1] = Suave.BUILD_ETH_BLOCK;

        Suave.DataRecord memory blockBid =
            Suave.newDataRecord(blockHeight, allowedPeekers, allowedPeekers, "default:v0:mergedDataRecords");
        Suave.confidentialStore(blockBid.id, "default:v0:mergedDataRecords", abi.encode(records));

        (bytes memory builderBid, bytes memory payload) = Suave.buildEthBlock(blockArgs, blockBid.id, namespace);
        Suave.confidentialStore(blockBid.id, "default:v0:builderPayload", payload); // only through this.unlock

        return (blockBid, builderBid);
    }

    function emitBuilderBidAndBid(Suave.DataRecord memory dataRecord, bytes memory builderBid)
        public
        returns (Suave.DataRecord memory, bytes memory)
    {
        emit BuilderBoostBidEvent(dataRecord.id, builderBid);
        emit DataRecordEvent(dataRecord.id, dataRecord.decryptionCondition, dataRecord.allowedPeekers);
        return (dataRecord, builderBid);
    }

    function unlock(Suave.DataId dataId, bytes memory signedBlindedHeader) public returns (bytes memory) {
        require(Suave.isConfidential());

        // TODO: verify the header is correct
        // TODO: incorporate protocol name
        bytes memory payload = Suave.confidentialRetrieve(dataId, "default:v0:builderPayload");
        return payload;
    }
}

contract EthBlockBidSenderContract is EthBlockContract, Suapp {
    string boostRelayUrl;

    event SubmitBlockResponse(bytes);

    constructor(string memory boostRelayUrl_) {
        boostRelayUrl = boostRelayUrl_;
    }

    function buildAndEmit(
        Suave.BuildBlockArgs memory blockArgs,
        uint64 blockHeight,
        Suave.DataId bidId,
        string memory namespace
    ) public emitOffchainLogs returns (bytes memory) {
        require(Suave.isConfidential());
        Suave.DataId[] memory dataRecords =
            abi.decode(Suave.confidentialRetrieve(bidId, "default:v0:mergedDataRecords"), (Suave.DataId[]));
        (Suave.DataRecord memory blockDataRecord, bytes memory builderBid) =
            this.doBuild(blockArgs, blockHeight, dataRecords, namespace);
        bytes memory blockRes = Suave.submitEthBlockToRelay(boostRelayUrl, builderBid);

        // emit DataRecordEvent(blockDataRecord.id, blockDataRecord.decryptionCondition, blockDataRecord.allowedPeekers);
        // emit SubmitBlockResponse(blockRes);
        return bytes.concat(this.emitDataRecord.selector, abi.encode(blockDataRecord));
    }
}
