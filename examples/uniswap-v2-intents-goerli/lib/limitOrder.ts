import {
    type Address,
    type Hex,
    type Transport,
    encodeAbiParameters,
    encodeFunctionData,
    keccak256,
    parseAbi
} from '@flashbots/suave-viem'
import {
    type SuaveProvider,
    SuaveTxRequestTypes,
    type SuaveWallet,
    type TransactionRequestSuave
} from '@flashbots/suave-viem/chains/utils'
import IntentsContract from '../../../out/Intents.sol/Intents.json'

export interface ILimitOrder {
    tokenIn: Address
    tokenOut: Address
    amountInMax: bigint
    amountOutMin: bigint
    expiryTimestamp: bigint
    to: Address
    senderKey: Hex
}

export async function deployIntentRouter<T extends Transport>(wallet: SuaveWallet<T>, provider: SuaveProvider<T>): Promise<Address> {
    // deploy IntentRouter
    console.log("deploying IntentRouter")
    const deployContractTxHash = await wallet.deployContract({
        abi: IntentsContract.abi,
        bytecode: IntentsContract.bytecode.object as Hex,
        
    })
    const deployContractReceipt = await provider.waitForTransactionReceipt({ hash: deployContractTxHash })
    console.log("FINISHED deploying IntentRouter")

    // Return the contract address from the receipt
    if (!deployContractReceipt.contractAddress) throw new Error('no contract address')
    return deployContractReceipt.contractAddress
}

export class LimitOrder<T extends Transport> implements ILimitOrder {
    // ILimitOrder fields
    tokenIn: Address
    tokenOut: Address
    amountInMax: bigint
    amountOutMin: bigint
    expiryTimestamp: bigint
    senderKey: Hex
    // client configs
    client: SuaveProvider<T>
    contractAddress: Address
    kettleAddress: Address
    to: Address

    constructor(params: ILimitOrder, client: SuaveProvider<T>, contractAddress: Address, kettleAddress: Address) {
        this.tokenIn = params.tokenIn
        this.tokenOut = params.tokenOut
        this.amountInMax = params.amountInMax
        this.amountOutMin = params.amountOutMin
        this.expiryTimestamp = params.expiryTimestamp
        this.senderKey = params.senderKey
        this.client = client
        this.contractAddress = contractAddress
        this.kettleAddress = kettleAddress
        this.to = params.to
    }

    inner(): ILimitOrder {
        // return {
        //     tokenIn: this.tokenIn,
        //     tokenOut: this.tokenOut,
        //     amountInMax: this.amountInMax,
        //     amountOutMin: this.amountOutMin,
        //     expiryTimestamp: this.expiryTimestamp,
        //     senderKey: this.senderKey,
        //     to: this.to,
        // }
        return this as ILimitOrder // idk if type coercion is actually necessary but hey why not
    }

    orderId(): Hex {
        return keccak256(this.publicBytes())
    }

    // TODO: ideally we'd extend PublicClient to create LimitOrders, then we could
    // just use the class' client instance
    async toTransactionRequest(): Promise<TransactionRequestSuave> {
        const feeData = await this.client.getFeeHistory({blockCount: 1, rewardPercentiles: [51]})
        return {
            to: this.contractAddress,
            data: this.newOrderCalldata(),
            confidentialInputs: this.confidentialInputsBytes(),
            kettleAddress: this.kettleAddress,
            gasPrice: feeData.baseFeePerGas[0] || 10000000000n,
            gas: 150000n,
            type: SuaveTxRequestTypes.ConfidentialRequest,
        }
    }

    private confidentialInputsBytes(): Hex {
        return encodeAbiParameters([
            {type: 'address', name: 'tokenIn'},
            {type: 'address', name: 'tokenOut'},
            {type: 'uint256', name: 'amountIn'},
            {type: 'uint256', name: 'amountOutMin'},
            {type: 'uint256', name: 'expiryTimestamp'},
            {type: 'address', name: 'to'},
            {type: 'bytes32', name: 'senderKey'},
        ], [
            this.tokenIn,
            this.tokenOut,
            this.amountInMax,
            this.amountOutMin,
            this.expiryTimestamp,
            this.to,
            this.senderKey,
        ])
    }

    private publicBytes(): Hex {
        return encodeAbiParameters([
            {type: 'address', name: 'tokenIn'},
            {type: 'address', name: 'tokenOut'},
            {type: 'uint256', name: 'amountIn'},
            {type: 'uint256', name: 'amountOutMin'},
            {type: 'uint256', name: 'expiryTimestamp'},
        ], [
            this.tokenIn,
            this.tokenOut,
            this.amountInMax,
            this.amountOutMin,
            this.expiryTimestamp,
        ])
    }

    private newOrderCalldata(): Hex {
        return encodeFunctionData({
            abi: parseAbi(['function sendIntent() public']),
            // args: [],
            functionName: 'sendIntent'
          })
    }
}
