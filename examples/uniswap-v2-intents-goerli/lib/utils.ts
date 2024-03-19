import { type Hash, type Hex, type WalletClient, formatEther } from '@flashbots/suave-viem'
import { goerli } from "@flashbots/suave-viem/chains"
import config from "../rigil.json"

export const ETH = 1000000000000000000n

export const roundEth = (n: bigint) => Number.parseFloat(formatEther(n)).toPrecision(4)

export async function getWeth(amount: bigint, wallet: WalletClient): Promise<Hash> {
    if (!process.env.GOERLI_KEY) {
        throw new Error('GOERLI_KEY must be set to get WETH')
    }
    if (!wallet.account) {
        throw new Error('wallet must have an account to get WETH')
    }
    const txRequest = await wallet.prepareTransactionRequest({
        account: wallet.account,
        chain: goerli,
        to: config.goerli.weth as Hex,
        value: amount, // 0.1 WETH
        data: '0xd0e30db0' as Hex, // deposit()
        gas: 50000n,
        gasPrice: 10000000000n,
    })
    const signedTx = await wallet.signTransaction(txRequest)
    return await wallet.sendRawTransaction({serializedTransaction: signedTx})
}
