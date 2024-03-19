import { bytesToString, hexToBytes } from '@flashbots/suave-viem'

/** only catches and decodes revert errors, throws the rest. */
function decodeRawError<E extends Error>(error: E): {name: string, details: string} {
    const details = error.message.match(/Details: (.*)/)?.[1]
    if (!details) {
        console.error('could not find revert details')
        throw error
    }
    const reason = error.message.match(/execution reverted: (.*)/)?.[1]
    if (!reason) {
        console.error('could not find revert reason')
        throw error
    }
    const decodedReason = bytesToString(hexToBytes(`0x${reason}`))
    return {
        name: 'execution reverted',
        details: decodedReason,
    }
}

/// this feels like it should be integrated into viem already, but I
/// think it would rely on me using the contract primitives in viem,
/// which I can't use because of how we sign/send txs (have to use suave wallet directly)
export class SuaveRevert<E extends Error> extends Error {
    details: string

    constructor(rawError: E) {
        const decodedError = decodeRawError(rawError)
        super(`Execution reverted. ${decodedError.details}`)
        this.name = decodedError.name
        this.cause = rawError.message
        this.details = decodedError.details
    }
}
