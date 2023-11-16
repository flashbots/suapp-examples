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
    address public constant DAI = 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844;
    address public constant WETH9 = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

    function callback() external payable {}

    function example() external payable returns (bytes memory) {
        UniswapV3.ExactOutputSingleParams memory params = UniswapV3.ExactOutputSingleParams({
            tokenIn: DAI,
            tokenOut: WETH9,
            fee: 100,
            recipient: address(this),
            deadline: 100,
            amountOut: 100,
            amountInMaximum: 1,
            sqrtPriceLimitX96: 0
        });
        UniswapV3.exactOutputSingle(params);

        return abi.encodeWithSelector(this.callback.selector);
    }
}
