package main

import (
	"fmt"
	"bufio"
	"os"
	"github.com/flashbots/suapp-examples/framework"
)

func main() {
	fr := framework.New()

	chat := fr.Suave.DeployContract("MyGpt.sol/Chat.json")

	fmt.Println("deploy chat complete!")
	var apiKey string
	updateKey := func(){
		fmt.Println("please input your chatgpt api-key:")
		_,err := fmt.Scanf("%s",&apiKey)
		if(err != nil){
			fmt.Printf("error :", err)
		}
		fmt.Printf("your key is : %s\n", apiKey)
		receipt := chat.SendConfidentialRequest("registerKeyOffchain", []interface{}{}, []byte(apiKey))
		if len(receipt.Logs) >= 1 {
			fmt.Printf("%s\n",receipt.Logs[0].Data)	
		}
		fmt.Println("your key has been put in suave confidential store")
	}
	sendQuestion := func () {
		fmt.Println("please input your question:")
		var question string 

		scanner := bufio.NewScanner(os.Stdin)
    	scanner.Scan()
    	question = scanner.Text()
		fmt.Printf("your question is : %s\n", question)
		fmt.Println("please choose your model:")
		var model int
		fmt.Println("please choose a model,1 or 2")
		fmt.Println("1:gpt-3.5-turbo")
		fmt.Println("2:gpt-4o")
		_,err := fmt.Scanf("%d",&model)
		if(err != nil) {
			fmt.Printf("error :", err)
			return
		}
		gptModel := "gpt-3.5-turbo"
		switch model {
		case 1:
			gptModel = "gpt-3.5-turbo"
		case 2:
			gptModel = "gpt-4o"
		default:
			fmt.Printf("you have choose a wrong option\n")
		}

		receipt := chat.SendConfidentialRequest("ask", []interface{}{question, gptModel, "0.7"}, nil)
		if len(receipt.Logs) >= 1 {
			fmt.Printf("%s\n",receipt.Logs[0].Data)
		}
	}
	hasKey := false
	for true {
		if(!hasKey){
			updateKey()
			hasKey = true
		}
		fmt.Println("please choose a option,1 or 2")
		fmt.Println("1:ask a question")
		fmt.Println("2:update api key")
		option := -1
		_,err := fmt.Scanf("%d",&option)
		if(err != nil){
			fmt.Printf("error :", err)
			break
		}
		switch option {
		case 1:
			sendQuestion()
		case 2:
			updateKey()
		default:
			fmt.Printf("you have choose a wrong option\n")
		}
	}
	
	fmt.Println("finished")
}
