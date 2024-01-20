import {
    type Address,
    type Hash,
    type Hex,
    type Transport,
    encodeAbiParameters,
    encodeFunctionData,
    parseAbi
} from 'viem/src'
import {
    type SuaveProvider,
    SuaveTxRequestTypes,
    type TransactionRequestSuave
} from 'viem/src/chains/utils'

export const TX_PLACEHOLDER: Hex = '0xf00d'

export type ITxMeta = {
    gas: bigint
    gasPrice: bigint
    nonce: number
    chainId: number
}

export class TxMeta implements ITxMeta {
    gas: bigint
    gasPrice: bigint
    nonce: number
    chainId: number
    constructor() {
        this.gas = 150000n
        this.gasPrice = 30000000000n
        this.nonce = 0
        this.chainId = 1
    }

    withChainId(chainId: number): this {
        this.chainId = chainId
        return this
    }

    withGas(gas: bigint): this {
        this.gas = gas
        return this
    }

    withGasPrice(gasPrice: bigint): this {
        this.gasPrice = gasPrice
        return this
    }

    withNonce(nonce: number): this {
        this.nonce = nonce
        return this
    }

    abiData(): [bigint, bigint, bigint, bigint] {
        return [
            BigInt(this.chainId),
            this.gas,
            this.gasPrice,
            BigInt(this.nonce),
        ]
    }
}

export interface IFulfillIntentRequest {
    // for `fulfillIntent(bytes32 orderId, Suave.DataId dataId, memory txMeta)`
    orderId: Hash
    dataId: Hex // bytes16
    txMeta: TxMeta
    // confidential input
    bundleTxs: Hex[]
    blockNumber: bigint
}

/** Build a bundle around a tx placeholder.
 * Felt cute, might delete later.
*/
export class Bundle {
    signedTxs: Hex[]
    constructor() {
        this.signedTxs = ['0xf00d', '0xf00d']
    }

    frontload(txs: Hex[]): this {
        this.signedTxs = [...txs, ...this.signedTxs]
        return this
    }

    backload(txs: Hex[]): this {
        this.signedTxs = [...this.signedTxs, ...txs]
        return this
    }
}

export class FulfillIntentRequest<T extends Transport> implements IFulfillIntentRequest {
    // client configs
    client: SuaveProvider<T>
    contractAddress: Address
    kettleAddress: Address
    // request params
    orderId: Hash
    dataId: Hex
    txMeta: TxMeta
    // confidential input
    bundleTxs: Hex[]
    blockNumber: bigint

    constructor(params: IFulfillIntentRequest, client: SuaveProvider<T>, contractAddress: Address, kettleAddress: Address) {
        this.client = client
        this.contractAddress = contractAddress
        this.kettleAddress = kettleAddress
        this.orderId = params.orderId
        this.dataId = params.dataId
        this.txMeta = params.txMeta
        this.bundleTxs = params.bundleTxs
        this.blockNumber = params.blockNumber

        if (!params.bundleTxs.includes(TX_PLACEHOLDER)) {
            throw new Error(`bundle must include tx placeholder: "${TX_PLACEHOLDER}"`)
        }
    }

    async toTransactionRequest(): Promise<TransactionRequestSuave> {
        const feeData = await this.client.getFeeHistory({blockCount: 1, rewardPercentiles: [51]})
        console.log("confidentialInputsBytes", this.confidentialInputsBytes())
        return {
            to: this.contractAddress,
            data: this.calldata(),
            confidentialInputs: this.confidentialInputsBytes(),
            kettleAddress: this.kettleAddress,
            gasPrice: feeData.baseFeePerGas[0] || 10000000000n,
            gas: 25000n,
            type: SuaveTxRequestTypes.ConfidentialRequest,
        }
    }

    private confidentialInputsBytes(): Hex {
        /**
        FulfillIntentBundle {
            bytes[] txs;
            uint256 blockNumber;
        }
         */
        return encodeAbiParameters([
            {
                components: [
                    {
                        name: 'txs',
                        type: 'bytes[]',
                    },
                    {
                        name: 'blockNumber',
                        type: 'uint256',
                    }
                ],
                name: 'FulfillIntentBundle',
                type: 'tuple'
            }
        ] as const, [{
            txs: this.bundleTxs,
            blockNumber: this.blockNumber,
        }])
    }

    private calldata(): Hex {
        return encodeFunctionData({
            abi: parseAbi(['function fulfillIntent(bytes32,bytes16,(uint64,uint256,uint256,uint64)) public']),
            args: [
                this.orderId,
                this.dataId,
                this.txMeta.abiData(),
            ],
            functionName: 'fulfillIntent'
        })
    }
}
