import './style.css'
import viteLogo from '/vite.svg'
import typescriptLogo from './typescript.svg'
import flashbotsLogo from './flashbots_icon.svg'
import { setupConnectButton, setupDripFaucetButton, setupSendBidButton } from './suave'
import { Logo } from './components'
import { custom, formatEther } from '@flashbots/suave-viem'
import { getSuaveWallet, getSuaveProvider } from '@flashbots/suave-viem/chains/utils'
import { suaveRigil } from '@flashbots/suave-viem/chains'

document.querySelector<HTMLDivElement>('#app')!.innerHTML = `
  <div>
    ${Logo('https://suave.flashbots.net', flashbotsLogo, 'Flashbots logo')}
    <h1><em>MEV-Share on SUAVE</em></h1>
    <div class="card">
      <button id="connect" type="button"></button>
      <div id="status-content"></div>
      <button id="dripFaucet" type="button"></button>
      <button id="sendBid" type="button" ></button>
    </div>
  </div>
`

document.querySelector<HTMLDivElement>('#footer')!.innerHTML = `
  <div>
    built with
      ${Logo('https://vite.org', viteLogo, 'Vite logo', "logo logo-tiny")}
      +${Logo('https://www.typescriptlang.org', typescriptLogo, 'Typescript logo', "logo logo-tiny")}
      +${Logo('https://flashbots.net', flashbotsLogo, 'Flashbots logo', "logo logo-tiny")}
  </div>
`

setupConnectButton(document.querySelector<HTMLButtonElement>('#connect')!, 
(account, ethereum, err) => {
  if (err) {
    console.error(err)
    alert(err.message)
  }
  const suaveWallet = getSuaveWallet({jsonRpcAccount: account, transport: custom(ethereum)})
  console.log(suaveWallet)
  const suaveProvider = getSuaveProvider(custom(ethereum))
  suaveProvider.getBalance({ address: account }).then((balance: any) => {
    suaveProvider.getChainId().then((chainId: any) => {
      if (chainId !== suaveRigil.id) {
        alert(`wrong chain id. expected ${suaveRigil.id}, got ${chainId}`)
      }
    })
    document.querySelector<HTMLDivElement>('#status-content')!.innerHTML = `
      <div>
        <p>SUAVE-ETH balance: ${formatEther(balance)}</p>
      </div>
    `
  })

  // setup other buttons once we've connected
  setupSendBidButton(document.querySelector<HTMLButtonElement>('#sendBid')!, suaveWallet, (txHash, err) => {
    if (err) {
      alert(err)
      return
    }
    const suaveProvider = getSuaveProvider(custom(ethereum))
    suaveProvider.getTransactionReceipt({hash: txHash}).then((receipt: any) => {
      console.log("receipt", receipt)
      document.querySelector<HTMLDivElement>('#status-content')!.innerHTML = `
        <div>
          <p>bid sent. tx hash: <code>${txHash}</code></p>
          <label for="receipt">receipt</label>
          <textarea id="receipt" wrap="hard">
${JSON.stringify(receipt, (_, value) =>
            (typeof value === 'bigint'
              ? value.toString()
              : value // return everything else unchanged
            ), 2)}
          </textarea>
        </div>
      `
    })
    console.log("sent bid.", txHash)
    document.querySelector<HTMLDivElement>('#status-content')!.innerHTML = `
      <div>
        <p>bid sent. tx hash: <code>${txHash}</code></p>
      </div>
    `
  })

  setupDripFaucetButton(
    document.querySelector<HTMLButtonElement>('#dripFaucet')!,
    account,
    (txHash, err) => {
      if (err) {
        console.error("error in setupDripFaucetButton", err)
        alert(err.message + (err as any).data)
      }
      console.log("funded account. txhash:", txHash)
  })
})
