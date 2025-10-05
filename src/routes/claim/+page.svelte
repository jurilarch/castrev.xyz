<script lang="ts">
	import { account } from '$lib/blockchain/wallet';
	import { onMount } from 'svelte';
	import {
		FACTORY_FUNCTIONS,
		DISTRIBUTOR_FUNCTIONS,
		readContract,
		writeContract,
		linkTokenFunction,
		CONTRACTS
	} from '$lib/blockchain/contracts';
	import { formatUSD, formatUnits } from '$lib/utils/format';

	interface Holding {
		address: string;
		balance: bigint;
		pending: bigint;
		revenue24h: bigint;
	}

	let holdings: Holding[] = [];
	let isLoading = false;
	let claimStatus = '';

	async function loadHoldings() {
		if (!$account) {
			holdings = [];
			return;
		}
		if (!CONTRACTS.address || CONTRACTS.address === '0x0000000000000000000000000000000000000000') {
			claimStatus = 'Factory address missing (set VITE_FACTORY_ADDRESS).';
			holdings = [];
			return;
		}
		isLoading = true;
		claimStatus = '';
		try {
			const [tokenList] = (await readContract(FACTORY_FUNCTIONS.getAllLinkTokens, [])) as [
				string[]
			];
			const results: Holding[] = [];
			for (const token of tokenList) {
				const [balance] = (await readContract(linkTokenFunction(token, 'balanceOf'), [
					$account
				])) as [bigint];
				const [pending] = (await readContract(DISTRIBUTOR_FUNCTIONS.pendingRewards, [
					token,
					$account
				])) as [bigint];
				if (balance > 0n || pending > 0n) {
					const [revenue] = (await readContract(DISTRIBUTOR_FUNCTIONS.revenue24h, [token])) as [
						bigint
					];
					results.push({ address: token, balance, pending, revenue24h: revenue });
				}
			}
			holdings = results;
		} catch (error) {
			console.error(error);
			claimStatus = error instanceof Error ? error.message : 'Failed to load holdings';
		} finally {
			isLoading = false;
		}
	}

	async function claim(token: string) {
		if (!$account) {
			claimStatus = 'Connect wallet to claim.';
			return;
		}
		isLoading = true;
		try {
			const tx = await writeContract($account, DISTRIBUTOR_FUNCTIONS.claim, [token, $account]);
			claimStatus = `Claim submitted: ${tx}`;
			await loadHoldings();
		} catch (error) {
			console.error(error);
			claimStatus = error instanceof Error ? error.message : 'Failed to claim rewards';
		} finally {
			isLoading = false;
		}
	}

	async function claimAll() {
		if (!$account) {
			claimStatus = 'Connect wallet to claim.';
			return;
		}
		if (holdings.length === 0) {
			claimStatus = 'Nothing to claim.';
			return;
		}
		isLoading = true;
		try {
			const tx = await writeContract($account, DISTRIBUTOR_FUNCTIONS.claimBatch, [
				holdings.map((h) => h.address),
				$account
			]);
			claimStatus = `Batch claim submitted: ${tx}`;
			await loadHoldings();
		} catch (error) {
			console.error(error);
			claimStatus = error instanceof Error ? error.message : 'Failed to claim rewards';
		} finally {
			isLoading = false;
		}
	}

	$: ($account, loadHoldings());

	onMount(() => {
		loadHoldings();
	});
</script>

<section class="rounded-2xl border border-zinc-800 bg-zinc-900/30 p-8">
	<div class="flex items-center justify-between">
		<div>
			<h2 class="text-xl font-semibold text-white">Claim rewards</h2>
			<p class="text-sm text-zinc-400">
				View every link token you hold and pull down accrued USDC.
			</p>
		</div>
		<button
			class="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-60"
			on:click={loadHoldings}
			disabled={isLoading}
		>
			Refresh
		</button>
	</div>

	{#if !$account}
		<p class="mt-6 text-sm text-zinc-400">Connect your wallet to see claimable balances.</p>
	{:else}
		<div class="mt-6 flex justify-between text-sm text-zinc-300">
			<span>Total tokens tracked: {holdings.length}</span>
			<button
				class="rounded bg-emerald-600 px-3 py-1 text-sm text-white hover:bg-emerald-500 disabled:opacity-60"
				on:click={claimAll}
				disabled={isLoading || holdings.length === 0}
			>
				Claim all
			</button>
		</div>
		<div class="mt-4 space-y-4">
			{#if holdings.length === 0}
				<p
					class="rounded border border-dashed border-zinc-700 bg-zinc-950/60 p-6 text-sm text-zinc-400"
				>
					No balances detected. Acquire link tokens or wait for clicks to accrue rewards.
				</p>
			{:else}
				{#each holdings as holding}
					<div class="rounded-xl border border-zinc-800 bg-zinc-950/50 p-5">
						<div class="flex flex-wrap items-center justify-between gap-4">
							<div>
								<p class="font-mono text-sm text-zinc-200">{holding.address}</p>
								<p class="text-xs text-zinc-500">
									24h link revenue: {formatUSD(holding.revenue24h)}
								</p>
							</div>
							<div class="grid grid-cols-2 gap-6 text-sm text-zinc-300">
								<div>
									<p class="text-xs text-zinc-500 uppercase">Balance</p>
									<p class="font-mono text-base text-white">{formatUnits(holding.balance, 18)}</p>
								</div>
								<div>
									<p class="text-xs text-zinc-500 uppercase">Claimable USDC</p>
									<p class="font-mono text-base text-emerald-300">{formatUSD(holding.pending)}</p>
								</div>
							</div>
							<button
								class="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
								on:click={() => claim(holding.address)}
								disabled={holding.pending === 0n || isLoading}
							>
								Claim
							</button>
						</div>
					</div>
				{/each}
			{/if}
		</div>
	{/if}

	{#if claimStatus}
		<p class="mt-6 text-xs text-zinc-400">{claimStatus}</p>
	{/if}
</section>
