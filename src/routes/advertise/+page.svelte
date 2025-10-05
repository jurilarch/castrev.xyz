<script lang="ts">
	import { account } from '$lib/blockchain/wallet';
	import { linkIdFromRawLink } from '$lib/utils/canonicalize-link';
	import { toBytes32 } from '$lib/utils/bytes32';
	import { formatUSD, parseUnits } from '$lib/utils/format';
	import {
		FACTORY_FUNCTIONS,
		DISTRIBUTOR_FUNCTIONS,
		AD_CAMPAIGNS_FUNCTIONS,
		readContract,
		writeContract,
		CONTRACTS
	} from '$lib/blockchain/contracts';

	interface CampaignState {
		advertiser: string;
		adId: string;
		linkId: string;
		linkToken: string;
		cpc: bigint;
		deposited: bigint;
		spent: bigint;
		clicks: bigint;
		paused: boolean;
		closed: boolean;
		remaining: bigint;
	}

	let rawLink = '';
	let canonicalLink = '';
	let linkId = '';
	let linkTokenAddress: string | null = null;
	let adIdInput = '';
	let cpcInput = '';
	let budgetInput = '';
	let createStatus = '';
	let manageStatus = '';
	let createdCampaignTx: string | null = null;
	let lookupCampaignId = '';
	let campaign: CampaignState | null = null;
	let topLineRevenue = 0n;
	let isBusy = false;
	let fundInput = '';

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

	async function lookupLinkToken() {
		computeCanonical();
		if (!linkId) {
			linkTokenAddress = null;
			return;
		}
		const [address] = (await readContract(FACTORY_FUNCTIONS.getLinkToken, [linkId])) as [string];
		linkTokenAddress = address !== '0x0000000000000000000000000000000000000000' ? address : null;
	}

	async function ensureLinkToken() {
		await lookupLinkToken();
		if (!linkTokenAddress && $account) {
			if (
				!CONTRACTS.address ||
				CONTRACTS.address === '0x0000000000000000000000000000000000000000'
			) {
				throw new Error('Factory address missing. Set VITE_FACTORY_ADDRESS.');
			}
			await writeContract($account, FACTORY_FUNCTIONS.getOrCreateLinkToken, [
				linkId,
				canonicalLink,
				'LINK'
			]);
			await lookupLinkToken();
		}
	}

	async function handleCreateCampaign() {
		computeCanonical();
		if (!$account) {
			createStatus = 'Connect your wallet to create a campaign.';
			return;
		}
		if (!linkId) {
			createStatus = 'Provide a valid link.';
			return;
		}
		try {
			isBusy = true;
			await ensureLinkToken();
			if (!linkTokenAddress) {
				throw new Error('Unable to find or deploy link token.');
			}
			const adId = toBytes32(adIdInput || canonicalLink);
			const cpc = parseUnits(cpcInput || '0', 6);
			const deposit = parseUnits(budgetInput || '0', 6);
			if (cpc === 0n || deposit === 0n) {
				throw new Error('Set CPC and initial budget (in USDC).');
			}
			createStatus = 'Submitting campaign…';
			const tx = await writeContract($account, AD_CAMPAIGNS_FUNCTIONS.createCampaign, [
				adId,
				linkId,
				linkTokenAddress,
				cpc,
				deposit
			]);
			createdCampaignTx = tx;
			createStatus = `Campaign transaction submitted: ${tx}`;
		} catch (error) {
			console.error(error);
			createStatus = error instanceof Error ? error.message : 'Failed to create campaign';
		} finally {
			isBusy = false;
		}
	}

	async function loadCampaign() {
		manageStatus = '';
		if (!lookupCampaignId) {
			manageStatus = 'Enter a campaign id to load.';
			return;
		}
		try {
			const id = BigInt(lookupCampaignId);
			const data = (await readContract(AD_CAMPAIGNS_FUNCTIONS.campaigns, [id])) as [
				string,
				string,
				string,
				string,
				bigint,
				bigint,
				bigint,
				bigint,
				boolean,
				boolean
			];
			const remainingResult = (await readContract(AD_CAMPAIGNS_FUNCTIONS.remainingBudget, [
				id
			])) as [bigint];
			campaign = {
				advertiser: data[0],
				adId: data[1],
				linkId: data[2],
				linkToken: data[3],
				cpc: data[4],
				deposited: data[5],
				spent: data[6],
				clicks: data[7],
				paused: data[8],
				closed: data[9],
				remaining: remainingResult[0]
			};
			await refreshRevenue();
		} catch (error) {
			console.error(error);
			manageStatus = error instanceof Error ? error.message : 'Failed to load campaign';
			campaign = null;
		}
	}

	async function refreshRevenue() {
		if (!campaign) return;
		const [revenue] = (await readContract(DISTRIBUTOR_FUNCTIONS.revenue24h, [
			campaign.linkToken
		])) as [bigint];
		topLineRevenue = revenue;
	}

	async function fund(amount: string) {
		if (!$account || !campaign) {
			manageStatus = 'Connect your wallet and load a campaign.';
			return;
		}
		const parsed = parseUnits(amount, 6);
		if (parsed === 0n) {
			manageStatus = 'Enter a positive USDC amount.';
			return;
		}
		isBusy = true;
		try {
			await writeContract($account, AD_CAMPAIGNS_FUNCTIONS.fundCampaign, [
				BigInt(lookupCampaignId),
				parsed
			]);
			manageStatus = 'Funding transaction sent. Approve USDC allowance first.';
			await loadCampaign();
		} catch (error) {
			console.error(error);
			manageStatus = error instanceof Error ? error.message : 'Failed to fund campaign';
		} finally {
			isBusy = false;
		}
	}

	async function setPause(paused: boolean) {
		if (!$account) {
			manageStatus = 'Connect your wallet to update status.';
			return;
		}
		isBusy = true;
		try {
			await writeContract($account, AD_CAMPAIGNS_FUNCTIONS.pauseCampaign, [
				BigInt(lookupCampaignId),
				paused
			]);
			manageStatus = paused ? 'Campaign paused.' : 'Campaign resumed.';
			await loadCampaign();
		} catch (error) {
			console.error(error);
			manageStatus = error instanceof Error ? error.message : 'Failed to update status';
		} finally {
			isBusy = false;
		}
	}

	async function closeCampaign(refundAddress: string) {
		if (!$account) {
			manageStatus = 'Connect your wallet to close the campaign.';
			return;
		}
		isBusy = true;
		try {
			await writeContract($account, AD_CAMPAIGNS_FUNCTIONS.closeCampaign, [
				BigInt(lookupCampaignId),
				refundAddress || $account
			]);
			manageStatus = 'Close transaction submitted.';
			await loadCampaign();
		} catch (error) {
			console.error(error);
			manageStatus = error instanceof Error ? error.message : 'Failed to close campaign';
		} finally {
			isBusy = false;
		}
	}

	function triggerPause(nextPaused: boolean) {
		if (!campaign) return;
		setPause(nextPaused);
	}

	function triggerClose() {
		if (!campaign) return;
		closeCampaign(campaign.advertiser);
	}
</script>

<div class="space-y-10">
	<section class="rounded-2xl border border-zinc-800 bg-zinc-900/30 p-8">
		<h2 class="text-xl font-semibold text-white">Create a new campaign</h2>
		<p class="mt-2 text-sm text-zinc-400">
			Fund USDC on Base, set a CPC and point to a canonical Farcaster link. Each validated click
			will move the CPC amount into the link token reward pool.
		</p>

		<div class="mt-6 grid gap-4 md:grid-cols-2">
			<label class="text-sm text-zinc-300">
				Advertised link
				<input
					class="mt-2 w-full rounded border border-zinc-700 bg-zinc-950/80 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none"
					bind:value={rawLink}
					on:blur={computeCanonical}
					placeholder="https://warpcast.com/..."
				/>
			</label>
			<label class="text-sm text-zinc-300">
				Ad identifier (cast hash or label)
				<input
					class="mt-2 w-full rounded border border-zinc-700 bg-zinc-950/80 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none"
					bind:value={adIdInput}
					placeholder="auto-hash if blank"
				/>
			</label>
			<label class="text-sm text-zinc-300">
				CPC (USDC)
				<input
					class="mt-2 w-full rounded border border-zinc-700 bg-zinc-900 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none"
					bind:value={cpcInput}
					placeholder="0.25"
				/>
			</label>
			<label class="text-sm text-zinc-300">
				Initial budget (USDC)
				<input
					class="mt-2 w-full rounded border border-zinc-700 bg-zinc-900 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none"
					bind:value={budgetInput}
					placeholder="100"
				/>
			</label>
		</div>
		<div class="mt-4 grid gap-2 text-xs text-zinc-400">
			<span>Canonical: <span class="font-mono text-zinc-200">{canonicalLink || '—'}</span></span>
			<span>Link ID: <span class="font-mono text-zinc-200">{linkId || '—'}</span></span>
			<span
				>Link token: <span class="font-mono text-zinc-200"
					>{linkTokenAddress ?? 'Lookup pending'}</span
				></span
			>
		</div>
		<div class="mt-6 flex gap-3">
			<button
				class="rounded bg-zinc-800 px-4 py-2 text-sm hover:bg-zinc-700"
				on:click={lookupLinkToken}
				disabled={isBusy}
			>
				Lookup token
			</button>
			<button
				class="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-60"
				on:click={handleCreateCampaign}
				disabled={isBusy}
			>
				Create campaign
			</button>
		</div>
		{#if createStatus}
			<p class="mt-4 text-xs text-zinc-400">{createStatus}</p>
		{/if}
		{#if createdCampaignTx}
			<p class="mt-2 text-sm text-emerald-300">Track your campaign tx: {createdCampaignTx}</p>
		{/if}
	</section>

	<section class="rounded-2xl border border-zinc-800 bg-zinc-900/30 p-8">
		<h2 class="text-xl font-semibold text-white">Manage campaign</h2>
		<div class="mt-4 flex flex-wrap items-end gap-3">
			<label class="text-sm text-zinc-300">
				Campaign ID
				<input
					class="mt-2 w-40 rounded border border-zinc-700 bg-zinc-950 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none"
					bind:value={lookupCampaignId}
				/>
			</label>
			<button
				class="rounded bg-zinc-800 px-4 py-2 text-sm hover:bg-zinc-700"
				on:click={loadCampaign}
				disabled={!lookupCampaignId || isBusy}
			>
				Load
			</button>
		</div>

		{#if campaign}
			<div class="mt-6 grid gap-4 lg:grid-cols-2">
				<div class="rounded-xl border border-zinc-800 bg-zinc-950/40 p-6">
					<h3 class="text-sm font-semibold text-zinc-200">Campaign details</h3>
					<dl class="mt-4 space-y-2 text-sm text-zinc-300">
						<div class="flex justify-between">
							<dt>Advertiser</dt>
							<dd class="font-mono">{campaign.advertiser}</dd>
						</div>
						<div class="flex justify-between">
							<dt>Link token</dt>
							<dd class="font-mono">{campaign.linkToken}</dd>
						</div>
						<div class="flex justify-between">
							<dt>CPC</dt>
							<dd>{formatUSD(campaign.cpc)}</dd>
						</div>
						<div class="flex justify-between">
							<dt>Budget</dt>
							<dd>{formatUSD(campaign.deposited)}</dd>
						</div>
						<div class="flex justify-between">
							<dt>Spent</dt>
							<dd>{formatUSD(campaign.spent)}</dd>
						</div>
						<div class="flex justify-between">
							<dt>Remaining</dt>
							<dd>{formatUSD(campaign.remaining)}</dd>
						</div>
						<div class="flex justify-between">
							<dt>Total clicks</dt>
							<dd>{campaign.clicks.toString()}</dd>
						</div>
						<div class="flex justify-between">
							<dt>Status</dt>
							<dd>{campaign.closed ? 'Closed' : campaign.paused ? 'Paused' : 'Active'}</dd>
						</div>
						<div class="flex justify-between">
							<dt>24h link revenue</dt>
							<dd>{formatUSD(topLineRevenue)}</dd>
						</div>
					</dl>
				</div>
				<div class="space-y-4 rounded-xl border border-zinc-800 bg-zinc-950/40 p-6">
					<h3 class="text-sm font-semibold text-zinc-200">Actions</h3>
					<label class="text-sm text-zinc-300">
						Add budget (USDC)
						<div class="mt-2 flex gap-2">
							<input
								class="w-full rounded border border-zinc-700 bg-zinc-900 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none"
								bind:value={fundInput}
								placeholder="25"
							/>
							<button
								class="rounded bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-500"
								on:click={() => fund(fundInput)}
								disabled={isBusy}>Fund</button
							>
						</div>
					</label>
					<div class="flex flex-wrap gap-2">
						<button
							class="rounded bg-yellow-600/80 px-4 py-2 text-sm text-white hover:bg-yellow-500"
							on:click={() => triggerPause(true)}
							disabled={campaign.paused || isBusy}>Pause</button
						>
						<button
							class="rounded bg-sky-600 px-4 py-2 text-sm text-white hover:bg-sky-500"
							on:click={() => triggerPause(false)}
							disabled={!campaign.paused || isBusy}>Resume</button
						>
						<button
							class="rounded bg-rose-600 px-4 py-2 text-sm text-white hover:bg-rose-500"
							on:click={triggerClose}
							disabled={campaign.closed || isBusy}>Close & Refund</button
						>
					</div>
				</div>
			</div>
		{:else if manageStatus}
			<p class="mt-4 text-sm text-zinc-400">{manageStatus}</p>
		{/if}
		{#if manageStatus && campaign}
			<p class="mt-4 text-xs text-zinc-400">{manageStatus}</p>
		{/if}
	</section>
</div>
