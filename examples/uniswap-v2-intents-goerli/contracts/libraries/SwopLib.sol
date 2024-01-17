// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/* SWOP
Swap
WithOut
Permission
*/

// import {Suave} from "suave/libraries/Suave.sol";
import {Suave} from "lib/suave-std/src/suavelib/Suave.sol";
import {Transactions} from "lib/suave-std/src/Transactions.sol";
import {HexEncoder} from "./HexEncoder.sol";
// import "lib/suave-std/lib/solady/src/utils/LibString.sol";

struct SwapExactTokensForTokensRequest {
    uint256 amountIn;
    uint256 amountOutMin;
    address[] path;
    address to;
    uint256 deadline;
}

/// Fields required to sign a transaction for an intent fulfillment.
struct TxMeta {
    uint64 chainId;
    uint256 gas;
    uint256 gasPrice;
    uint64 nonce;
}

library UniV2Swop {
    address public constant router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    /// Returns market price sans fees.
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        view
        returns (uint256 price)
    {
        bytes memory result = Suave.ethcall(
            router, abi.encodeWithSignature("getAmountOut(uint256,uint256,uint256)", amountIn, reserveIn, reserveOut)
        );
        (price) = abi.decode(result, (uint256));
    }

    function approve(address token, address spender, uint256 amount, bytes32 privateKey, TxMeta memory txMeta)
        internal
        view
        returns (bytes memory signedTx, bytes memory data)
    {
        data = abi.encodeWithSignature("approve(address,uint256)", spender, amount);

        Transactions.EIP155Request memory txStruct = Transactions.EIP155Request({
            to: token,
            gas: uint64(txMeta.gas),
            gasPrice: uint64(txMeta.gasPrice),
            value: 0,
            nonce: txMeta.nonce,
            data: data,
            chainId: txMeta.chainId
        });
        bytes memory rlpTx = Transactions.encodeRLP(txStruct);
        signedTx = Suave.signEthTransaction(
            rlpTx, HexEncoder.toHexString(txMeta.chainId, true, true), HexEncoder.toHexString(privateKey, false)
        );
    }

    /// Swap tokens on Uniswap V2. Returns raw signed tx, which can be broadcasted.
    /// txMeta must contain chainId, gas, gasPrice, and nonce.
    function swapExactTokensForTokens(
        SwapExactTokensForTokensRequest memory request,
        bytes32 privateKey,
        TxMeta memory txMeta
    ) internal view returns (bytes memory signedTx, bytes memory data) {
        data = abi.encodeWithSignature(
            "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
            request.amountIn,
            request.amountOutMin,
            request.path,
            request.to,
            request.deadline
        );
        // bytes memory emptyBytes = new bytes(0);
        Transactions.EIP155Request memory txStruct = Transactions.EIP155Request({
            to: router,
            gas: uint64(txMeta.gas),
            gasPrice: uint64(txMeta.gasPrice),
            value: 0,
            nonce: txMeta.nonce,
            data: data,
            chainId: txMeta.chainId
        });
        // r: emptyBytes,
        // s: emptyBytes,
        // v: emptyBytes

        bytes memory rlpTx = Transactions.encodeRLP(txStruct);
        signedTx = Suave.signEthTransaction(
            rlpTx, HexEncoder.toHexString(txMeta.chainId, true, true), HexEncoder.toHexString(privateKey, false)
        );
    }
}
