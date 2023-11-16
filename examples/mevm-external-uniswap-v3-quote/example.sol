// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "forge-std/Script.sol";

interface ISwapRouter {
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

    function exactOutputSingle(
        ISwapRouter.ExactOutputSingleParams memory params
    ) external returns (uint256 amountIn);
}

contract Forge is Script {
    address constant swapRouter = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function run() public {
        ISwapRouter router = ISwapRouter(swapRouter);
        router.exactOutputSingle(ISwapRouter.ExactOutputSingleParams({
            tokenIn: DAI,
            tokenOut: USDC,
            fee: 1000,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountOut: 1000,
            amountInMaximum: 1,
            sqrtPriceLimitX96: 0
        }));
    }
}
