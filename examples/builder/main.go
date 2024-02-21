package main

import (
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.New()
	r := fr.Suave.
		DeployContract("builder.sol/Builder.json").
		SendTransaction("example", []interface{}{}, nil)
	if r == nil {
		panic(r)
	}
}
