import { formatEther } from 'viem/src'

export const roundEth = (n: bigint) => Number.parseFloat(formatEther(n)).toPrecision(4)
export const ETH = 1000000000000000000n
