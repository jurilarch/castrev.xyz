<section class="grid gap-10 lg:grid-cols-2">
	<article class="rounded-2xl border border-zinc-800 bg-zinc-900/40 p-8 shadow-lg shadow-black/20">
		<h2 class="text-xl font-semibold text-white">On-chain revenue sharing for Farcaster links</h2>
		<p class="mt-4 text-zinc-400">
			Every Farcaster cast or URL mints its own ERC-20 “link token”. Holders of that token earn USDC
			every time a verified ad click is recorded for the linked cast. Advertisers fund campaigns
			with USDC on Base and each click settles instantly into the token’s reward pool.
		</p>
		<ul class="mt-6 space-y-3 text-sm text-zinc-300">
			<li>• Deterministic link IDs using canonicalized URLs.</li>
			<li>• Trusted attesters sign valid clicks; duplicates are rejected on-chain.</li>
			<li>• Rewards accumulate continuously and can be claimed anytime.</li>
		</ul>
		<div class="mt-8 flex gap-3">
			<a
				href="/buy"
				class="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500"
				>Buy link tokens</a
			>
			<a
				href="/advertise"
				class="rounded border border-indigo-500/60 px-4 py-2 text-sm font-medium text-indigo-200 hover:bg-indigo-500/10"
				>Fund a campaign</a
			>
		</div>
	</article>
	<article class="rounded-2xl border border-zinc-800 bg-zinc-900/20 p-8">
		<h3 class="text-lg font-semibold text-white">How it works</h3>
		<ol class="mt-4 space-y-4 text-sm text-zinc-300">
			<li>
				<span class="font-medium text-white">1. Tokenize links.</span> Anyone can register a canonical
				link and mint its link token via the factory.
			</li>
			<li>
				<span class="font-medium text-white">2. Fund CPC campaigns.</span> Advertisers escrow USDC with
				a target link and cost-per-click bounds.
			</li>
			<li>
				<span class="font-medium text-white">3. Validate clicks.</span> Off-chain attesters sign click
				payloads that the contract checks for freshness, attester approval and duplicate prevention.
			</li>
			<li>
				<span class="font-medium text-white">4. Claim rewards.</span> Link token holders pull their accrued
				USDC whenever they want.
			</li>
		</ol>
	</article>
</section>
