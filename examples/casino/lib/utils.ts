import { Address, Hex, formatEther } from '@flashbots/suave-viem';

export const roundEth = (n: bigint) => Number.parseFloat(formatEther(n)).toPrecision(4)
export const ETH = 1000000000000000000n
export const DEFAULT_ADMIN_KEY: Hex = '0x91ab9a7e53c220e6210460b65a7a3bb2ca181412a8a7b43ff336b3df1737ce12'
export const DEFAULT_KETTLE_ADDRESS: Address = '0xb5feafbdd752ad52afb7e1bd2e40432a485bbb7f'
export const TESTNET_KETTLE_ADDRESS: Address = '0x03493869959c866713c33669ca118e774a30a0e5'
