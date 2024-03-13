import IntentsContract from "../../out/Intents.sol/Intents.json";
import config from "./lib/env";
import { Bundle, FulfillIntentRequest, TxMeta } from "./lib/intentBundle";
import {
	LimitOrder,
	deployIntentRouter, // needed if you decide to re-deploy
} from "./lib/limitOrder";
import { SuaveRevert } from "./lib/suaveError";
import { getWeth } from "./lib/utils";
import TestnetConfig from "./rigil.json";
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
	toHex,
	hexToBigInt,
	decodeAbiParameters,
    parseAbi,
	parseAbiParameters,
	hexToString,
} from "@flashbots/suave-viem";
import {
	type SuaveProvider,
	SuaveTxTypes,
	type SuaveWallet,
	type TransactionReceiptSuave,
	type TransactionRequestSuave,
	getSuaveProvider,
	getSuaveWallet,
} from "@flashbots/suave-viem/chains/utils";
import { goerli, suaveRigil } from "@flashbots/suave-viem/chains";
import { privateKeyToAccount } from "@flashbots/suave-viem/accounts";
import fs from "fs/promises";

async function testIntents<T extends Transport>(
	_suaveWallet: SuaveWallet<T>,
	suaveProvider: SuaveProvider<T>,
	goerliKey: Hex,
	kettleAddress: Hex,
) {
	// set DEPLOY=true in process.env if you want to re-deploy the IntentRouter
	// `DEPLOY=true bun run index.ts`
	const intentRouterAddress = process.env.DEPLOY
		? await (async () => {
				const address = await deployIntentRouter(_suaveWallet, suaveProvider)
				// replace address in rigil.json
				const newConfig = TestnetConfig
				newConfig.suave.intentRouter = address
				fs.writeFile("./rigil.json", JSON.stringify(newConfig, null, 4))
                return address
		  })()
		: (TestnetConfig.suave.intentRouter as Hex);

	const goerliWallet = createWalletClient({
		account: privateKeyToAccount(goerliKey),
		transport: http(goerli.rpcUrls.public.http[0]),
	});

	console.log("intentRouterAddress", intentRouterAddress);
	console.log("suaveWallet", _suaveWallet.account.address);
	console.log("goerliWallet", goerliWallet.account.address);

	// automagically decode revert messages before throwing them
	// TODO: build this natively into the wallet client
	const suaveWallet = _suaveWallet.extend((client) => ({
		async sendTransaction(tx: TransactionRequestSuave): Promise<Hex> {
			try {
				return await client.sendTransaction(tx);
			} catch (e) {
				throw new SuaveRevert(e as Error);
			}
		},
	}));

	const amountIn = parseEther("0.01");
	console.log(`buying tokens with ${formatEther(amountIn)} WETH`);
	const limitOrder = new LimitOrder(
		{
			amountInMax: amountIn,
			amountOutMin: 13n,
			expiryTimestamp: BigInt(Math.round(new Date().getTime() / 1000) + 3600),
			senderKey: goerliKey,
			tokenIn: TestnetConfig.goerli.weth as Hex,
			tokenOut: TestnetConfig.goerli.dai as Hex,
			to: goerliWallet.account.address,
		},
		suaveProvider,
		intentRouterAddress,
		kettleAddress,
	);

	console.log("orderId", limitOrder.orderId());

	const tx = await limitOrder.toTransactionRequest();
	const limitOrderTxHash: Hex = await suaveWallet.sendTransaction(tx);
	console.log("limitOrderTxHash", limitOrderTxHash);

	let ccrReceipt: TransactionReceiptSuave | null = null;

	let fails = 0;
	for (let i = 0; i < 10; i++) {
		try {
			ccrReceipt = await suaveProvider.waitForTransactionReceipt({
				hash: limitOrderTxHash,
			});
			console.log("ccrReceipt logs", ccrReceipt.logs);
			break;
		} catch (e) {
			console.warn("error", e);
			if (++fails >= 10) {
				throw new Error("failed to get receipt: timed out");
			}
		}
	}
	if (!ccrReceipt) {
		throw new Error("no receipt (this should never happen)");
	}

	const txRes = await suaveProvider.getTransaction({ hash: limitOrderTxHash });
	console.log("txRes", txRes);

	if (txRes.type !== SuaveTxTypes.Suave) {
		throw new Error("expected SuaveTransaction type (0x50)");
	}

	// check `confidentialComputeResult`; should be calldata for `onReceivedIntent`
	const fnSelector: Hex = `0x${IntentsContract.methodIdentifiers["onReceivedIntent((address,address,uint256,uint256,uint256),bytes32,bytes16)"]}`;
	const expectedData = [
		limitOrder.tokenIn,
		limitOrder.tokenOut,
		toHex(limitOrder.amountInMax),
		toHex(limitOrder.amountOutMin),
		toHex(limitOrder.expiryTimestamp),
		limitOrder.orderId(),
	]
		.map((param) => padHex(param, { size: 32 }))
		.reduce((acc, cur) => concatHex([acc, cur]));

	// this test is extremely sensitive to changes. comment out if/when changing the contract to reduce stress.
	const expectedRawResult = concatHex([fnSelector, expectedData]);
	if (
		!txRes.confidentialComputeResult.startsWith(expectedRawResult.toLowerCase())
	) {
		throw new Error(
			"expected confidential compute result to be calldata for `onReceivedIntent`",
		);
	}

	// check onchain for intent
	const intentResult = await suaveProvider.call({
		to: intentRouterAddress,
		data: encodeFunctionData({
			abi: IntentsContract.abi,
			args: [limitOrder.orderId()],
			functionName: "intentsPending",
		}),
	});
	console.log("intentResult", intentResult);

	// get dataId from event logs in receipt
	const LIMIT_ORDER_RECEIVED_SIG: Hex = getEventSelector(
		"LimitOrderReceived(bytes32,bytes16,address,address,uint256)",
	);
	const intentReceivedLog = ccrReceipt.logs.find(
		(log) => log.topics[0] === LIMIT_ORDER_RECEIVED_SIG,
	);
	if (!intentReceivedLog) {
		throw new Error("no LimitOrderReceived event found in logs");
	}
	const decodedLog = decodeEventLog({
		abi: IntentsContract.abi,
		...intentReceivedLog,
	}).args;
	console.log("*** decoded log", decodedLog);
	const { dataId } = decodedLog as { dataId: Hex };
	if (!dataId) {
		throw new Error("no dataId found in logs");
	}

	// get user's latst goerli nonce
	const goerliProvider = await createPublicClient({
		chain: goerli,
		transport: http(goerli.rpcUrls.public.http[0]),
	});
	const nonce = await goerliProvider.getTransactionCount({
		address: goerliWallet.account.address,
	});
	const blockNumber = await goerliProvider.getBlockNumber();
	const targetBlock = blockNumber + 2n;
	console.log("targeting blockNumber", targetBlock);

	// tx params for goerli txs
	const txMetaApprove = new TxMeta()
		.withChainId(goerli.id)
		.withNonce(nonce)
		.withGas(70000n)
		.withGasPrice(10000000000n);
	const txMetaSwap = new TxMeta()
		.withChainId(goerli.id)
		.withNonce(nonce + 1)
		.withGas(200000n)
		.withGasPrice(50000000000n);

	const fulfillIntent = new FulfillIntentRequest(
		{
			orderId: limitOrder.orderId(),
			dataId: dataId,
			txMeta: [txMetaApprove, txMetaSwap],
			bundleTxs: new Bundle().signedTxs,
			blockNumber: targetBlock,
		},
		suaveProvider,
		intentRouterAddress,
		kettleAddress,
	);
	const txRequest = await fulfillIntent.toTransactionRequest();
	console.log("fulfillIntent txRequest", txRequest);

	// send the CCR
	const fulfillIntentTxHash = await suaveWallet.sendTransaction(txRequest);
	console.log("fulfillIntentTxHash", fulfillIntentTxHash);

	// wait for tx receipt, then log it
	const fulfillIntentReceipt = await suaveProvider.waitForTransactionReceipt({
		hash: fulfillIntentTxHash,
	});
	console.log("fulfillIntentReceipt", fulfillIntentReceipt);
	if (
		fulfillIntentReceipt.logs[0].data ===
		"0x0000000000000000000000000000000000000000000000000000000000009001"
	) {
		throw new Error("fulfillIntent failed: invalid function signature.");
	}
	if (
		fulfillIntentReceipt.logs[0].topics[0] !==
		"0x6cfef2b359d2bc325989410c5b08045b006cd80ea36a48c332233798808abacb"
	) {
		throw new Error("fulfillIntent failed: invalid event signature.");
	}

	for (const log of fulfillIntentReceipt.logs) {
		const decodedLog = decodeEventLog({
			abi: IntentsContract.abi,
			...log,
		});
		console.log("decodedLog", decodedLog);
		const logData = decodedLog.args as { orderId: Hex; receiptRes: Hex };
		const [orderRes, egps] = decodeAbiParameters(
			parseAbiParameters("bytes, uint64[10]"),
			logData.receiptRes,
		);
		console.log(hexToString(orderRes));
		console.log("egps", egps);
	}
}

async function main() {
	if (!config.GOERLI_KEY) {
		console.warn(
			"GOERLI_KEY is not set, using default. Your bundle will not land.\nTo fix, update .env in the project root.\n",
		);
	}
	if (!config.SUAVE_KEY) {
		console.warn(
			"SUAVE_KEY is not set, using default. Your SUAVE request may not land.\nTo fix, update .env in the project root.\n",
		);
	}
	// get a suave wallet & provider, connected to rigil testnet
	const suaveWallet = getSuaveWallet({
		privateKey: (config.SUAVE_KEY ||
			TestnetConfig.suave.defaultAdminKey) as Hex,
		transport: http(suaveRigil.rpcUrls.default.http[0]),
	});
	console.log("suaveWallet", suaveWallet.account.address);
	const suaveProvider = getSuaveProvider(
		http(suaveRigil.rpcUrls.default.http[0]),
	);

	// goerli signer; separate from suaveWallet; only funded on goerli
	const goerliKEY = (config.GOERLI_KEY ||
		"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80") as Hex;
	const goerliWallet = createWalletClient({
		account: privateKeyToAccount(goerliKEY),
		transport: http(goerli.rpcUrls.public.http[0]),
	});
	const goerliProvider = createPublicClient({
		chain: goerli,
		transport: http(goerli.rpcUrls.public.http[0]),
	});
	console.log("goerliWallet", goerliWallet.account.address);

	// get goerli weth balance, top up if needed
	const wethBalanceRes = (
		await goerliProvider.call({
			account: goerliWallet.account.address,
			to: TestnetConfig.goerli.weth as Hex,
			data: encodeFunctionData({
				functionName: "balanceOf",
				args: [goerliWallet.account.address],
				abi: parseAbi([
					"function balanceOf(address) public view returns (uint256)",
				]),
			}),
		})
	).data;

	if (!wethBalanceRes) {
		throw new Error("failed to get WETH balance");
	}
	const wethBalance = hexToBigInt(wethBalanceRes);

	console.log("wethBalance", formatEther(wethBalance));
	const minBalance = parseEther("0.1");
	if (wethBalance < minBalance) {
		console.log("topping up WETH");
		const txHash = await getWeth(minBalance, goerliWallet);
		console.log(`got ${minBalance} weth`, txHash);
		// wait for 12 seconds for the tx to land
		console.log("waiting for 12 seconds for tx to land on goerli");
		await new Promise((resolve) => setTimeout(resolve, 12000));
	}

	// run test script
	await testIntents(
		suaveWallet,
		suaveProvider,
		goerliKEY,
		TestnetConfig.suave.testnetKettleAddress as Hex,
	);
}

main();
