import {
    Address,
    Hex,
    encodeAbiParameters,
    encodeFunctionData,
} from '@flashbots/suave-viem'
import { TransactionRequestSuave } from '@flashbots/suave-viem/chains/suave/types'
import OFAContract from '../contracts/out/OFA.sol/OFAPrivate.json'

/** Factory class to create MEV-Share bids on SUAVE. */
export class OFAOrder {
blockNumber: bigint
signedTx: Hex
OFAContract: Address
kettle: Address

constructor(
    blockNumber: bigint,
    signedTx: Hex,
    kettle: Address,
    OFAContract: Address,
) {
    this.blockNumber = blockNumber
    this.signedTx = signedTx
    this.kettle = kettle
    this.OFAContract = OFAContract
}

/** Encodes calldata to call the `newOrder` function. */
private newOrderCalldata() {
    return encodeFunctionData({
    abi: OFAContract.abi,
    functionName: 'newOrder',
    args: [this.blockNumber],
    })
}

/** Wraps `signedTx` in a bundle, then ABI-encodes it as bytes for `confidentialInputs`. */
private confidentialInputsBytes(): Hex {
    return encodeAbiParameters([
    {
        components: [
        { type: 'uint', name: 'blockNumber' },
        { type: 'uint', name: 'minTimestamp' },
        { type: 'uint', name: 'maxTimestamp' },
        { type: 'bytes[]', name: 'txns' },
        ],
        name: 'BundleObj',
        type: 'tuple',
    }] as const, [{
    blockNumber: this.blockNumber,
    minTimestamp: 0n,
    maxTimestamp: 0n,
    txns: [this.signedTx]
    }])
}

/** Encodes this bid as a ConfidentialComputeRequest, which can be sent to SUAVE. */
toConfidentialRequest(): TransactionRequestSuave {
    return {
    to: this.OFAContract,
    data: this.newOrderCalldata(),
    type: '0x43',
    gas: 500000n,
    gasPrice: 1000000000n,
    kettleAddress: this.kettle,
    confidentialInputs: this.confidentialInputsBytes(),
    }
}
}
  