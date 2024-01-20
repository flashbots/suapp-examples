// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Suave} from "lib/suave-std/src/suavelib/Suave.sol";
import {Bundle} from "lib/suave-std/src/protocols/Bundle.sol";
import {Transactions} from "lib/suave-std/src/Transactions.sol";
import {UniV2Swop, SwapExactTokensForTokensRequest, TxMeta} from "./libraries/SwopLib.sol";
import {LibString} from "lib/suave-std/lib/solady/src/utils/LibString.sol";

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
    // we probably shouldn't be storing intents in storage
    // TODO: make a stateless design
    mapping(bytes32 => LimitOrderPublic) public intentsPending;
    string public constant RPC_URL = "https://relay-goerli.flashbots.net";
    bytes2 public constant TX_PLACEHOLDER = 0xf00d;

    event Test(uint64 num);
    event LimitOrderReceived(
        bytes32 orderId, bytes16 dataId, address tokenIn, address tokenOut, uint256 expiryTimestamp
    );
    event IntentFulfilled(bytes32 orderId, uint256 amountOut, bytes bundleRes);

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
    function sendIntent() public view returns (bytes memory suaveCallData) {
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
    function encodeOnFulfilledIntent(bytes32 orderId, uint256 amountOut, bytes memory bundleRes)
        private
        pure
        returns (bytes memory)
    {
        return bytes.concat(this.onFulfilledIntent.selector, abi.encode(orderId, amountOut, bundleRes));
    }

    /// Triggered when an intent is fulfilled via `fulfillIntent`.
    function onFulfilledIntent(bytes32 orderId, uint256 amountOut, bytes memory bundleRes) public {
        delete intentsPending[orderId];
        emit IntentFulfilled(orderId, amountOut, bundleRes);
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
    function fulfillIntent(bytes32 orderId, Suave.DataId dataId, TxMeta memory txMeta)
        public
        view
        returns (bytes memory suaveCallData)
    {
        // ensure we're computing in the enclave (is this required here?)
        require(Suave.isConfidential(), "not confidential");

        LimitOrderPublic memory order = intentsPending[orderId];
        require(order.amountIn > 0, "intent not found");

        (bytes32 privateKey, address to) =
            abi.decode(Suave.confidentialRetrieve(dataId, LibString.toHexString(uint256(orderId))), (bytes32, address));

        (bytes memory signedApprove,) =
            UniV2Swop.approve(order.tokenIn, UniV2Swop.router, order.amountIn, privateKey, txMeta);

        txMeta.nonce += 1;

        address[] memory path = new address[](2);
        path[0] = order.tokenIn;
        path[1] = order.tokenOut;
        (bytes memory signedSwap, bytes memory swapCallData) = UniV2Swop.swapExactTokensForTokens(
            SwapExactTokensForTokensRequest(order.amountIn, order.amountOutMin, path, to, order.expiryTimestamp),
            privateKey,
            txMeta
        );

        // verify amountOutMin using eth_call
        // uint256 amountOut = abi.decode(Suave.ethcall(UniV2Swop.router, swapCallData), (uint256));
        // require(amountOut >= order.amountOutMin, "insufficient output");
        // TODO: once goerli is back in business, re-enable this check
        uint256 amountOut = 1337;

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

        // encode & send bundle request for each of the next 25 blocks
        bytes memory bundleRes;
        Bundle.BundleObj memory bundleObj;
        for (uint8 i = 0; i < 25; i++) {
            bundleObj = Bundle.BundleObj({
                blockNumber: uint64(bundle.blockNumber + i),
                minTimestamp: 0,
                maxTimestamp: 0,
                txns: bundle.txs
            });

            // simulate bundle and revert if it fails
            uint64 simResult = Suave.simulateBundle(Bundle.encodeBundle(bundleObj).body);
            require(simResult > 0, LibString.toHexString(abi.encodePacked("bundle sim failed", simResult)));

            bundleRes = Bundle.sendBundle("https://relay-goerli.flashbots.net", bundleObj);
            require(
                // this hex is '{"id":1,"result"'
                // close-enough way to check for successful sendBundle call
                bytes16(bundleRes) == 0x7b226964223a312c22726573756c7422,
                "bundle failed"
            );
        }
        // return the last bundle response
        bundleRes = Bundle.encodeBundle(bundleObj).body;

        // trigger `onFulfilledIntent`
        suaveCallData = encodeOnFulfilledIntent(orderId, amountOut, bundleRes);
    }
}
