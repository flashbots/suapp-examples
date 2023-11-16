package main

import "github.com/flashbots/suapp-examples/framework"

func main() {
	framework.DeployAndTransact("external-uniswap-v3-quote.sol/ExternalUniswapV3Quote.json", "example")
}
