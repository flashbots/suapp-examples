import {
    type SuaveProvider,
    SuaveTxTypes,
    type SuaveWallet,
    type TransactionReceiptSuave,
    type TransactionRequestSuave,
    getSuaveProvider,
    getSuaveWallet
} from 'viem/src/chains/utils'
import IntentsContract from '../../out/Intents.sol/Intents.json'
import { 
    LimitOrder, deployLimitOrderManager,
} from './lib/limitOrder'
import { SuaveRevert } from './lib/suaveError'
import { 
    type Hex,
    type PublicClient,
    type Transport,
    concatHex,
    createPublicClient,
    createWalletClient,
    decodeEventLog,
    encodeFunctionData,
    formatEther,
    getEventSelector,
    http,
    padHex,
    parseEther,
    toHex
} from 'viem/src'
import { goerli, suaveRigil } from 'viem/src/chains'
import { privateKeyToAccount } from 'viem/src/accounts'
import { Bundle, FulfillIntentRequest, TxMeta } from './lib/intentBundle'
import TestnetConfig from './rigil.json'
import config from "./lib/env"
import { ETH } from './lib/utils'

async function testIntents<T extends Transport>(
    suaveWallet: SuaveWallet<T>
    , suaveProvider: SuaveProvider<T>
    , goerliKey: Hex
    , kettleAddress: Hex) {
        const intentRouterAddress = TestnetConfig.suave.intentRouter as Hex
        //   const intentRouterAddress = await deployLimitOrderManager(suaveWallet, suaveProvider)
    console.log("intentRouterAddress", intentRouterAddress)
    const goerliWallet = createWalletClient({
        account: privateKeyToAccount(goerliKey),
        transport: http(goerli.rpcUrls.public.http[0]),
    })

    console.log("suaveWallet", suaveWallet.account.address)
    console.log("goerliWallet", goerliWallet.account.address)

    // automagically decode revert messages before throwing them
    // TODO: build this natively into the wallet client
    suaveWallet = suaveWallet.extend((client) => ({
        async sendTransaction(tx: TransactionRequestSuave): Promise<Hex> {
        try {
            return await client.sendTransaction(tx)
        } catch (e) {
            throw new SuaveRevert(e as Error)
        }
        }
    }))

    const amountIn = parseEther('0.01')
    console.log(`buying tokens with ${formatEther(amountIn)} WETH`)
    const limitOrder = new LimitOrder({
        amountInMax: amountIn,
        amountOutMin: 13n,
        expiryTimestamp: BigInt(Math.round(new Date().getTime() / 1000) + 3600),
        senderKey: goerliKey,
        tokenIn: TestnetConfig.goerli.weth as Hex,
        tokenOut: TestnetConfig.goerli.dai as Hex,
        to: goerliWallet.account.address,
    }, suaveProvider, intentRouterAddress, kettleAddress)

    console.log("orderId", limitOrder.orderId())

    const tx = await limitOrder.toTransactionRequest()
    const limitOrderTxHash: Hex = await suaveWallet.sendTransaction(tx)
    console.log("limitOrderTxHash", limitOrderTxHash)

    let ccrReceipt: TransactionReceiptSuave | null = null

    let fails = 0
    for (let i = 0; i < 10; i++) {
        try {
        ccrReceipt = await suaveProvider.waitForTransactionReceipt({hash: limitOrderTxHash})
        console.log("ccrReceipt logs", ccrReceipt.logs)
        break
        } catch (e) {
        console.warn('error', e)
        if (++fails >= 10) {
            throw new Error('failed to get receipt: timed out')
        }
        }
    }
    if (!ccrReceipt) {
        throw new Error("no receipt (this should never happen)")
    }

    const txRes = await suaveProvider.getTransaction({hash: limitOrderTxHash})
    console.log("txRes", txRes)

    if (txRes.type !== SuaveTxTypes.Suave) {
        throw new Error('expected SuaveTransaction type (0x50)')
    }

    // check `confidentialComputeResult`; should be calldata for `onReceivedIntent`
    const fnSelector: Hex = `0x${IntentsContract.methodIdentifiers['onReceivedIntent((address,address,uint256,uint256,uint256),bytes32,bytes16,uint256)']}`
    const expectedData = [
        limitOrder.tokenIn,
        limitOrder.tokenOut,
        toHex(limitOrder.amountInMax),
        toHex(limitOrder.amountOutMin),
        toHex(limitOrder.expiryTimestamp),
        limitOrder.orderId(),
    ].map(
        param => padHex(param, {size: 32})
    ).reduce(
        (acc, cur) => concatHex([acc, cur])
    )

    // this test is extremely sensitive to changes. comment out if/when changing the contract to reduce stress.
    const expectedRawResult = concatHex([fnSelector, expectedData])
    if (!txRes.confidentialComputeResult.startsWith(expectedRawResult.toLowerCase())) {
        throw new Error('expected confidential compute result to be calldata for `onReceivedIntent`')
    }
    
    // check onchain for intent
    const intentResult = await suaveProvider.call({
        account: suaveWallet.account.address,
        to: intentRouterAddress,
        data: encodeFunctionData({
        abi: IntentsContract.abi,
        args: [limitOrder.orderId()],
        functionName: 'intentsPending'
        }),
        gasPrice: 10000000000n,
        gas: 42000n,
        type: '0x0'
    })
    console.log('intentResult', intentResult)

    // get dataId from event logs in receipt
    const LIMIT_ORDER_RECEIVED_SIG: Hex = getEventSelector('LimitOrderReceived(bytes32,bytes16,address,address,uint256,uint256)')
    const intentReceivedLog = ccrReceipt.logs.find(log => log.topics[0] === LIMIT_ORDER_RECEIVED_SIG)
    if (!intentReceivedLog) {
        throw new Error('no LimitOrderReceived event found in logs')
    }
    const decodedLog = decodeEventLog({
        abi: IntentsContract.abi,
        ...intentReceivedLog,
    }).args
    console.log("*** decoded log", decodedLog)
    const { dataId } = decodedLog as any
    console.log("dataId", dataId)
    if (!dataId) {
        throw new Error('no dataId found in logs')
    }

    // get user's latst goerli nonce
    const goerliProvider = await createPublicClient({
        chain: goerli,
        transport: http(goerli.rpcUrls.public.http[0]),
    })
    const nonce = await goerliProvider.getTransactionCount({
        address: goerliWallet.account.address
    })
    console.log("nonce", nonce)
    console.log("admin", goerliWallet.account.address)
    const blockNumber = await goerliProvider.getBlockNumber()
    const targetBlock = blockNumber + 1n
    console.log("targeting blockNumber", targetBlock)

    // fulfill order
    const txMeta = new TxMeta()
        .withChainId(goerli.id)
        .withNonce(nonce)
        .withGas(300000n)
        .withGasPrice(30000000000n)
    console.log("txMeta", txMeta)
    const fulfillIntent = new FulfillIntentRequest({
        orderId: limitOrder.orderId(),
        dataId: dataId,
        txMeta,
        bundleTxs: new Bundle().signedTxs,
        blockNumber: targetBlock,
    }, suaveProvider, intentRouterAddress, kettleAddress)
    const txRequest = await fulfillIntent.toTransactionRequest()
    console.log("fulfillOrder txRequest", txRequest)

    // send the CCR
    const fulfillIntentTxHash = await suaveWallet.sendTransaction(txRequest)
    console.log("fulfillIntentTxHash", fulfillIntentTxHash)

    // wait for tx receipt, then log it
    const fulfillIntentReceipt = await suaveProvider.waitForTransactionReceipt({hash: fulfillIntentTxHash})
    console.log("fulfillIntentReceipt", fulfillIntentReceipt)
}

async function getAmountOut(routerAddress: Hex, goerliProvider: PublicClient) {
    const abiItem = {
    inputs: [
        { name: 'amountIn', type: 'uint256' },
        { name: 'reserveIn', type: 'uint256' },
        { name: 'reserveOut', type: 'uint256' },
    ],
    name: 'getAmountOut',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
    }
    const calldata = encodeFunctionData({
    abi: [abiItem],
    args: [
        1n * ETH,
        100n * ETH,
        42000n * ETH,
    ],
    functionName: 'getAmountOut'
    })
    const tx = {
    to: routerAddress,
    data: calldata,
    }
    return await goerliProvider.call(tx)
}

async function main() {
    /* call getAmountOut directly on goerli */
    const goerliProvider = createPublicClient({
    transport: http(goerli.rpcUrls.public.http[0]),
    })
    const routerAddress = TestnetConfig.goerli.uniV2Router as Hex
    const goerliAmountOut = await getAmountOut(routerAddress, goerliProvider)
    console.log("goerliAmountOut", goerliAmountOut)

    const suaveWallet = getSuaveWallet({
    privateKey: (config.SUAVE_KEY || TestnetConfig.suave.defaultAdminKey) as Hex,
    transport: http(suaveRigil.rpcUrls.default.http[0]),
    })
    console.log("suaveWallet", suaveWallet.account.address)
    // connect to rigil testnet
    const suaveProvider = getSuaveProvider(http(suaveRigil.rpcUrls.default.http[0]))
    const goerliKEY = (config.GOERLI_KEY || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80') as Hex
    const goerliWallet = createWalletClient({
    account: privateKeyToAccount(goerliKEY),
    transport: http(goerli.rpcUrls.public.http[0]),
    })
    console.log("goerliWallet", goerliWallet.account.address)
    await testIntents(suaveWallet, suaveProvider, goerliKEY, TestnetConfig.suave.testnetKettleAddress as Hex)
}

main()
