<script lang="ts">
	import { onMount } from 'svelte';
	import { account } from '$lib/blockchain/wallet';
	import { linkIdFromRawLink } from '$lib/utils/canonicalize-link';
	import {
		FACTORY_FUNCTIONS,
		DISTRIBUTOR_FUNCTIONS,
		readContract,
		writeContract,
		linkTokenFunction,
		CONTRACTS
	} from '$lib/blockchain/contracts';
	import { formatPercent, formatUnits, formatUSD, parseUnits } from '$lib/utils/format';

	let rawLink = '';
	let canonicalLink = '';
	let linkId = '';
	let linkTokenAddress: string | null = null;
	let tokenPrice = 0n;
	let totalSupply = 0n;
	let revenue24h = 0n;
	let userPending = 0n;
	let userBalance = 0n;
	let isBusy = false;
	let statusMessage = '';
	let amountInput = '';
	let txHash: string | null = null;
	let autoCanon = false;

	function computeCanonical() {
		if (!rawLink) {
			canonicalLink = '';
			linkId = '';
			return;
		}
		const { canonical, linkId: computedId } = linkIdFromRawLink(rawLink);
		canonicalLink = canonical;
		linkId = computedId;
	}

	$: (autoCanon, rawLink, autoCanon && computeCanonical());

	async function fetchTokenPrice() {
		const [price] = (await readContract(FACTORY_FUNCTIONS.tokenPrice, [])) as [bigint];
		tokenPrice = price;
	}

	async function resolveTokenAddress() {
		if (!linkId) {
			computeCanonical();
		}
		if (!linkId) return;
		if (!CONTRACTS.address || CONTRACTS.address === '0x0000000000000000000000000000000000000000') {
			statusMessage = 'Factory address not configured (VITE_FACTORY_ADDRESS).';
			return;
		}
		const [address] = (await readContract(FACTORY_FUNCTIONS.getLinkToken, [linkId])) as [string];
		linkTokenAddress = address !== '0x0000000000000000000000000000000000000000' ? address : null;
		if (linkTokenAddress) {
			await refreshTokenStats();
		}
	}

	async function refreshTokenStats() {
		if (!linkTokenAddress) return;
		const supplyResult = (await readContract(
			linkTokenFunction(linkTokenAddress, 'totalSupply'),
			[]
		)) as [bigint];
		totalSupply = supplyResult[0];
		if ($account) {
			const balanceResult = (await readContract(linkTokenFunction(linkTokenAddress, 'balanceOf'), [
				$account
			])) as [bigint];
			userBalance = balanceResult[0];
			const [pending] = (await readContract(DISTRIBUTOR_FUNCTIONS.pendingRewards, [
				linkTokenAddress,
				$account
			])) as [bigint];
			userPending = pending;
		} else {
			userBalance = 0n;
			userPending = 0n;
		}
		const [last24h] = (await readContract(DISTRIBUTOR_FUNCTIONS.revenue24h, [
			linkTokenAddress
		])) as [bigint];
		revenue24h = last24h;
	}

	async function handleCreateToken() {
		if (!linkId || !canonicalLink) {
			computeCanonical();
		}
		if (!linkId || !canonicalLink) {
			statusMessage = 'Provide a link to continue.';
			return;
		}
		if (!CONTRACTS.address || CONTRACTS.address === '0x0000000000000000000000000000000000000000') {
			statusMessage =
				'Factory address is not configured. Set VITE_FACTORY_ADDRESS in your environment.';
			return;
		}
		if (!$account) {
			statusMessage = 'Connect your wallet to create a link token.';
			return;
		}
		isBusy = true;
		statusMessage = 'Submitting transaction…';
		try {
			const tx = await writeContract($account, FACTORY_FUNCTIONS.getOrCreateLinkToken, [
				linkId,
				canonicalLink,
				'LINK'
			]);
			txHash = tx;
			statusMessage = 'Token creation submitted. Once mined, refresh to load stats.';
			await resolveTokenAddress();
		} catch (error) {
			console.error(error);
			statusMessage = error instanceof Error ? error.message : 'Failed to create token';
		} finally {
			isBusy = false;
		}
	}

	async function handlePurchase() {
		if (!linkTokenAddress) {
			statusMessage = 'Resolve or create a link token first.';
			return;
		}
		if (!$account) {
			statusMessage = 'Connect your wallet to buy tokens.';
			return;
		}
		if (!amountInput) {
			statusMessage = 'Enter an amount of tokens to buy.';
			return;
		}
		try {
			const parsed = parseUnits(amountInput, 18);
			isBusy = true;
			statusMessage = 'Submitting purchase…';
			const tx = await writeContract($account, FACTORY_FUNCTIONS.purchase, [
				linkId,
				parsed,
				$account
			]);
			txHash = tx;
			statusMessage = 'Purchase sent. Approve USDC beforehand to avoid failures.';
			await refreshTokenStats();
		} catch (error) {
			console.error(error);
			statusMessage = error instanceof Error ? error.message : 'Failed to buy tokens';
		} finally {
			isBusy = false;
		}
	}

	$: if ($account && linkTokenAddress) {
		refreshTokenStats();
	}

	onMount(async () => {
		await fetchTokenPrice();
		computeCanonical();
	});
</script>

<div class="grid gap-8 lg:grid-cols-[1.2fr,1fr]">
	<section class="rounded-2xl border border-zinc-800 bg-zinc-900/30 p-8">
		<h2 class="text-xl font-semibold text-white">Buy link tokens</h2>
		<p class="mt-2 text-sm text-zinc-400">
			Paste a Farcaster cast URL or any link. We canonicalize it and look up its link token. If it
			does not exist yet you can create it with a single transaction.
		</p>

		<div class="mt-6 space-y-4">
			<label class="block text-sm font-medium text-zinc-300">
				Raw link
				<input
					class="mt-2 w-full rounded border border-zinc-700 bg-zinc-950/80 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none"
					bind:value={rawLink}
					placeholder="https://warpcast.com/..."
				/>
			</label>
			<label class="flex items-center gap-2 text-xs text-zinc-400">
				<input type="checkbox" bind:checked={autoCanon} /> auto-canonicalize
			</label>
			<div class="grid gap-3 text-sm text-zinc-300">
				<div>
					<span class="font-medium text-zinc-400">Canonical link:</span>
					<span class="ml-2 font-mono text-zinc-200">{canonicalLink || '—'}</span>
				</div>
				<div>
					<span class="font-medium text-zinc-400">Link ID:</span>
					<span class="ml-2 font-mono text-zinc-200">{linkId || '—'}</span>
				</div>
				<div>
					<span class="font-medium text-zinc-400">Token address:</span>
					<span class="ml-2 font-mono text-zinc-200">{linkTokenAddress ?? 'Not deployed'}</span>
				</div>
			</div>
			<div class="flex flex-wrap gap-3">
				<button
					class="rounded bg-zinc-800 px-4 py-2 text-sm hover:bg-zinc-700"
					on:click={resolveTokenAddress}
					disabled={!linkId || isBusy}
				>
					Lookup token
				</button>
				<button
					class="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-60"
					on:click={handleCreateToken}
					disabled={!linkId || isBusy}
				>
					Create link token
				</button>
			</div>
		</div>

		<div class="mt-8 rounded-xl border border-zinc-800 bg-zinc-950/60 p-6">
			<h3 class="text-sm font-semibold text-zinc-200">Purchase</h3>
			<p class="mt-1 text-xs text-zinc-500">
				Price per token: {formatUSD(tokenPrice)} (assuming 18 decimal token supply).
			</p>
			<div class="mt-4 grid gap-4">
				<label class="text-sm text-zinc-300">
					Amount of tokens
					<input
						class="mt-2 w-full rounded border border-zinc-700 bg-zinc-900 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none"
						bind:value={amountInput}
						placeholder="10"
					/>
				</label>
				<button
					class="rounded bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-500 disabled:opacity-60"
					on:click={handlePurchase}
					disabled={!amountInput || isBusy}
				>
					Buy tokens
				</button>
				{#if txHash}
					<p class="text-xs text-emerald-300">
						Submitted: <span class="font-mono">{txHash}</span>
					</p>
				{/if}
			</div>
			{#if statusMessage}
				<p class="mt-4 text-xs text-zinc-400">{statusMessage}</p>
			{/if}
		</div>
	</section>

	<aside class="space-y-4">
		<div class="rounded-2xl border border-zinc-800 bg-zinc-900/30 p-6">
			<h3 class="text-sm font-semibold text-zinc-200">Token metrics</h3>
			<dl class="mt-4 space-y-2 text-sm text-zinc-300">
				<div class="flex justify-between">
					<dt>Total supply</dt>
					<dd class="font-mono">{formatUnits(totalSupply, 18)}</dd>
				</div>
				<div class="flex justify-between">
					<dt>24h click revenue</dt>
					<dd class="font-mono">{formatUSD(revenue24h)}</dd>
				</div>
				<div class="flex justify-between">
					<dt>Your balance</dt>
					<dd class="font-mono">{formatUnits(userBalance, 18)}</dd>
				</div>
				<div class="flex justify-between">
					<dt>Your share of last 24h</dt>
					<dd class="font-mono">
						{formatUSD(totalSupply > 0n ? (revenue24h * userBalance) / totalSupply : 0n)}
					</dd>
				</div>
				<div class="flex justify-between">
					<dt>Unclaimed rewards</dt>
					<dd class="font-mono">{formatUSD(userPending)}</dd>
				</div>
				<div class="flex justify-between">
					<dt>Ownership</dt>
					<dd class="font-mono">{formatPercent(userBalance, totalSupply)}</dd>
				</div>
			</dl>
		</div>
	</aside>
</div>
