// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Suave} from "lib/suave-std/src/suavelib/Suave.sol";
import {Bundle} from "lib/suave-std/src/protocols/Bundle.sol";
import {Transactions} from "lib/suave-std/src/Transactions.sol";
import {UniV2Swop, SwapExactTokensForTokensRequest, TxMeta} from "./libraries/SwopLib.sol";
import {LibString} from "lib/suave-std/lib/solady/src/utils/LibString.sol";
import {LibSort} from "lib/suave-std/lib/solady/src/utils/LibSort.sol";

/// Limit order for a swap. Used as a simple example for intents delivery system.
struct LimitOrder {
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    uint256 amountOutMin;
    uint256 expiryTimestamp; // unix seconds
    // only available in confidentialInputs:
    address to;
    bytes32 senderKey;
}

/// A reduced version of the original limit order to be shared publicly.
struct LimitOrderPublic {
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    uint256 amountOutMin;
    uint256 expiryTimestamp;
}

struct FulfillIntentBundle {
    bytes[] txs;
    uint256 blockNumber;
}

contract Intents {
    // we probably shouldn't be storing intents in contract storage
    // TODO: make a stateless or ConfidentialStore-based design
    mapping(bytes32 => LimitOrderPublic) public intentsPending;
    string public constant GOERLI_BUNDLE_RPC = "https://relay-goerli.flashbots.net";
    string public constant GOERLI_ETH_RPC = "https://rpc-goerli.flashbots.net";
    bytes2 public constant TX_PLACEHOLDER = 0xf00d;

    event Test(uint64 num);
    event Test(bytes res);
    event LimitOrderReceived(
        bytes32 orderId, bytes16 dataId, address tokenIn, address tokenOut, uint256 expiryTimestamp
    );
    //TODO: event IntentFulfillmentRequested(bytes32 orderId, bytes bundleRes);
    event IntentFulfilled(bytes32 orderId, bytes receiptRes);

    fallback() external {
        emit Test(0x9001);
    }

    /// Returns the order ID used to look up a limit order.
    function getOrderId(LimitOrderPublic memory order) internal pure returns (bytes32 orderId) {
        orderId = keccak256(
            abi.encode(order.tokenIn, order.tokenOut, order.amountIn, order.amountOutMin, order.expiryTimestamp)
        );
    }

    /// Returns ABI-encoded calldata of `onReceivedIntent(...)`.
    function encodeOnReceivedIntent(LimitOrderPublic memory order, bytes32 orderId, Suave.DataId dataId)
        private
        pure
        returns (bytes memory)
    {
        return bytes.concat(this.onReceivedIntent.selector, abi.encode(order, orderId, dataId));
    }

    /// Triggered when an intent is successfully received.
    /// Emits an event on SUAVE chain w/ the tokens traded and the order's expiration timestamp.
    function onReceivedIntent(LimitOrderPublic calldata order, bytes32 orderId, bytes16 dataId) public {
        // check that this order doesn't already exist; check any value in the struct against 0
        if (intentsPending[orderId].amountIn > 0) {
            revert("intent already exists");
        }
        intentsPending[orderId] = order;

        emit LimitOrderReceived(orderId, dataId, order.tokenIn, order.tokenOut, order.expiryTimestamp);
    }

    /// Broadcast an intent to SUAVE.
    function sendIntent() public returns (bytes memory suaveCallData) {
        // ensure we're computing in the enclave
        require(Suave.isConfidential(), "not confidential");

        // get the confidential inputs and decode them bytes into a LimitOrder
        bytes memory confidential_inputs = Suave.confidentialInputs();
        LimitOrder memory order = abi.decode(confidential_inputs, (LimitOrder));

        // strip private key from public order
        LimitOrderPublic memory publicOrder =
            LimitOrderPublic(order.tokenIn, order.tokenOut, order.amountIn, order.amountOutMin, order.expiryTimestamp);
        bytes32 orderId = getOrderId(publicOrder);

        // allowedPeekers: which contracts can read the record (only this contract)
        address[] memory allowedPeekers = new address[](1);
        allowedPeekers[0] = address(this);
        // allowedStores: which kettles can read the record (any kettle)
        address[] memory allowedStores = new address[](1);
        allowedStores[0] = Suave.ANYALLOWED;

        // save private key & recipient addr to confidential storage
        Suave.DataRecord memory record = Suave.newDataRecord(
            0, // decryptionCondition: ignored for now
            allowedPeekers,
            allowedStores,
            "limit_key" // namespace
        );
        Suave.confidentialStore(
            record.id, LibString.toHexString(uint256(orderId)), abi.encode(order.senderKey, order.to)
        );

        // returns calldata to trigger `onReceivedIntent()`
        suaveCallData = encodeOnReceivedIntent(publicOrder, orderId, record.id);
    }

    /// Returns ABI-encoded calldata of `onReceivedIntent(...)`.
    function encodeOnFulfillIntent(bytes32 orderId, bytes memory bundleRes) private pure returns (bytes memory) {
        return bytes.concat(this.onFulfillIntent.selector, abi.encode(orderId, bundleRes));
    }

    // function checkTransactionReceipt(bytes32 txHash) internal view returns (bool) {
    //     Suave.HttpRequest memory req =
    //         Suave.HttpRequest({url: GOERLI_ETH_RPC, method: "POST", headers: "", body: bundleRes});
    //     Suave.doHTTPRequest(request);
    // }

    /// Triggered when an intent is fulfilled via `fulfillIntent`.
    function onFulfillIntent(bytes32 orderId, bytes memory bundleRes) public {
        delete intentsPending[orderId];
        emit IntentFulfilled(orderId, bundleRes);
    }

    /// Fulfill an intent.
    /// Bundle is expected to be in `confidentialInputs` in the form of:
    ///   rlp({
    ///     txs: [...signedTxs, TX_PLACEHOLDER, TX_PLACEHOLDER, ...signedTxs],
    ///     blockNumber: 0x42
    ///   })
    /// If only one placeholder is provided, the tx following the first one will be replaced with the user's swap tx.
    /// We need two placeholders because the user sends two transactions; one approval and one swap.
    /// example bundle.txs: [
    ///     "0x02...1",  // signedTx 1
    ///     "0xf00d",   // TX_PLACEHOLDER
    ///     "0xf00d",   // TX_PLACEHOLDER
    ///     "0x02...2" // signedTx 2
    /// ]
    function fulfillIntent(bytes32 orderId, Suave.DataId dataId, TxMeta[2] memory txMeta)
        public
        returns (bytes memory suaveCallData)
    {
        // ensure we're computing in the enclave (is this required here?)
        require(Suave.isConfidential(), "not confidential");

        LimitOrderPublic memory order = intentsPending[orderId];
        require(order.amountIn > 0, "intent not found");

        (bytes32 privateKey, address to) =
            abi.decode(Suave.confidentialRetrieve(dataId, LibString.toHexString(uint256(orderId))), (bytes32, address));

        (bytes memory signedApprove,) =
            UniV2Swop.approve(order.tokenIn, UniV2Swop.router, order.amountIn, privateKey, txMeta[0]);

        address[] memory path = new address[](2);
        path[0] = order.tokenIn;
        path[1] = order.tokenOut;
        (bytes memory signedSwap,) = UniV2Swop.swapExactTokensForTokens(
            SwapExactTokensForTokensRequest(order.amountIn, order.amountOutMin, path, to, order.expiryTimestamp),
            privateKey,
            txMeta[1]
        );

        // load bundle from confidentialInputs
        FulfillIntentBundle memory bundle = abi.decode(Suave.confidentialInputs(), (FulfillIntentBundle));

        // assemble the full bundle by replacing the bundle entry marked with the placeholder
        for (uint256 i = 0; i < bundle.txs.length; i++) {
            if (bytes2(bundle.txs[i]) == TX_PLACEHOLDER) {
                bundle.txs[i] = signedApprove;
                bundle.txs[i + 1] = signedSwap;
                break;
            }
        }

        // simulate bundle for each of the next 10 blocks
        bytes memory bundleRes;
        Bundle.BundleObj memory bundleObj;
        uint256[] memory egps = new uint256[](10);
        for (uint8 i = 0; i < 10; i++) {
            bundleObj = Bundle.BundleObj({
                blockNumber: uint64(bundle.blockNumber + i),
                txns: bundle.txs,
                minTimestamp: 0,
                maxTimestamp: 0,
                revertingHashes: new bytes32[](0),
                replacementUuid: "",
                refundPercent: 0
            });
            // returns effective gas price (egp) for the bundle
            uint256 egp = uint256(Bundle.simulateBundle(bundleObj));
            egps[i] = egp;
            require(egp > 0, "sim failed");
        }

        // send bundles targeting the top 3 egps from the simulation step
        LibSort.insertionSort(egps);
        for (uint8 i = 0; i < 3; i++) {
            bundleRes = Bundle.sendBundle(GOERLI_BUNDLE_RPC, bundleObj);
            require(
                // this hex is '{"id":1,"result":{"bundleHash":"'
                // close-enough way to check for successful sendBundle call
                bytes32(bundleRes) == 0x7b226964223a312c22726573756c74223a7b2262756e646c6548617368223a22,
                "bundle failed"
            );
        }

        // TODO: build a mechanism to check for inclusion
        // ... right now we just assume the bundle landed

        // trigger `onFulfilledIntent`
        suaveCallData = encodeOnFulfillIntent(orderId, abi.encode(bundleRes, egps));
    }
}
