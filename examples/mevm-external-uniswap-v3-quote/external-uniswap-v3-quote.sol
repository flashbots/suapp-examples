// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "../../suave-geth/suave/sol/libraries/Suave.sol";

library UniswapV3 {
    address constant swapRouter = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    string constant exactOutputSingleSig = "exactOutputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))";

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactOutputSingle(ExactOutputSingleParams memory params)
        internal
        view
        returns (uint256 amountIn)
    {
        bytes memory output = Suave.ethcall(swapRouter, abi.encodeWithSignature(exactOutputSingleSig, params));
        (uint256 num) = abi.decode(output, (uint64));
        return num;
    }
}

contract ExternalUniswapV3Quote {
    function callback() external payable {
    }

    function example(UniswapV3.ExactOutputSingleParams memory params) external payable returns (bytes memory) {
        UniswapV3.exactOutputSingle(params);

        return abi.encodeWithSelector(this.callback.selector);
    }
}
