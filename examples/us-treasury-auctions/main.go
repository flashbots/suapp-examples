package main

import (
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.New()
	fr.DeployContract("TAuction.sol/TAuction.json")
}
