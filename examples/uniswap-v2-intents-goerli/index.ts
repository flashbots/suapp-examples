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
    LimitOrder,
    deployLimitOrderManager, // needed if you decide to re-deploy
} from './lib/limitOrder'
import { SuaveRevert } from './lib/suaveError'
import { 
    type Hex,
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

async function testIntents<T extends Transport>(
    _suaveWallet: SuaveWallet<T>
    , suaveProvider: SuaveProvider<T>
    , goerliKey: Hex
    , kettleAddress: Hex) 
{
    // set DEPLOY=true in process.env if you want to re-deploy the LimitOrderManager
    // `DEPLOY=true bun run index.ts`
    const intentRouterAddress = process.env.DEPLOY ?
        await deployLimitOrderManager(_suaveWallet, suaveProvider) :
        TestnetConfig.suave.intentRouter as Hex

    const goerliWallet = createWalletClient({
        account: privateKeyToAccount(goerliKey),
        transport: http(goerli.rpcUrls.public.http[0]),
    })
    
    console.log("intentRouterAddress", intentRouterAddress)
    console.log("suaveWallet", _suaveWallet.account.address)
    console.log("goerliWallet", goerliWallet.account.address)

    // automagically decode revert messages before throwing them
    // TODO: build this natively into the wallet client
    const suaveWallet = _suaveWallet.extend((client) => ({
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
    const fnSelector: Hex = `0x${IntentsContract.methodIdentifiers['onReceivedIntent((address,address,uint256,uint256,uint256),bytes32,bytes16)']}`
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
    const LIMIT_ORDER_RECEIVED_SIG: Hex = getEventSelector('LimitOrderReceived(bytes32,bytes16,address,address,uint256)')
    const intentReceivedLog = ccrReceipt.logs.find(log => log.topics[0] === LIMIT_ORDER_RECEIVED_SIG)
    if (!intentReceivedLog) {
        throw new Error('no LimitOrderReceived event found in logs')
    }
    const decodedLog = decodeEventLog({
        abi: IntentsContract.abi,
        ...intentReceivedLog,
    }).args
    console.log("*** decoded log", decodedLog)
    const { dataId } = decodedLog as { dataId: Hex }
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

    // tx params for goerli txs
    const txMeta = new TxMeta()
        .withChainId(goerli.id)
        .withNonce(nonce)
        .withGas(151000n)
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
    if (fulfillIntentReceipt.logs[0].data === '0x0000000000000000000000000000000000000000000000000000000000009001') {
        throw new Error("fulfillIntent failed: invalid function signature.")
    }
    if (fulfillIntentReceipt.logs[0].topics[0] !== '0x3b49987fdcb0497128d34095f53200b85e2eacaf3392a811c0133162bbb3a9f4') {
        throw new Error("fulfillIntent failed: invalid event signature.")
    }
}

async function main() {
    // get a suave wallet & provider, connected to rigil testnet
    const suaveWallet = getSuaveWallet({
        privateKey: (config.SUAVE_KEY || TestnetConfig.suave.defaultAdminKey) as Hex,
        transport: http(suaveRigil.rpcUrls.default.http[0]),
    })
    console.log("suaveWallet", suaveWallet.account.address)
    const suaveProvider = getSuaveProvider(http(suaveRigil.rpcUrls.default.http[0]))

    // goerli signer; separate from suaveWallet; only funded on goerli
    const goerliKEY = (config.GOERLI_KEY || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80') as Hex
    const goerliWallet = createWalletClient({
        account: privateKeyToAccount(goerliKEY),
        transport: http(goerli.rpcUrls.public.http[0]),
    })
    console.log("goerliWallet", goerliWallet.account.address)

    // run test script
    await testIntents(suaveWallet, suaveProvider, goerliKEY, TestnetConfig.suave.testnetKettleAddress as Hex)
}

main()
