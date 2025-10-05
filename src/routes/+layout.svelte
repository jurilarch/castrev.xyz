<script lang="ts">
	import '../app.css';
	import favicon from '$lib/assets/favicon.svg';
	import ConnectWallet from '$lib/components/ConnectWallet.svelte';

	let { children } = $props();
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
	<title>Farcaster Link Rewards</title>
</svelte:head>

<div class="min-h-screen bg-zinc-950 text-zinc-100">
	<header class="border-b border-zinc-800 bg-zinc-900/60 backdrop-blur">
		<div
			class="mx-auto flex max-w-6xl flex-col gap-4 px-6 py-6 sm:flex-row sm:items-center sm:justify-between"
		>
			<div>
				<h1 class="text-2xl font-semibold">Farcaster Link Rewards</h1>
				<p class="text-sm text-zinc-400">
					Tokenize attention. Reward curators. Settle clicks on Base.
				</p>
			</div>
			<div class="flex flex-col gap-3 sm:flex-row sm:items-center">
				<nav class="flex items-center gap-4 text-sm text-zinc-300">
					<a class="hover:text-white" href="/">Overview</a>
					<a class="hover:text-white" href="/buy">Buy</a>
					<a class="hover:text-white" href="/advertise">Advertise</a>
					<a class="hover:text-white" href="/claim">Claim</a>
				</nav>
				<ConnectWallet />
			</div>
		</div>
	</header>
	<main class="mx-auto max-w-6xl px-6 py-10">
		{@render children?.()}
	</main>
	<footer class="border-t border-zinc-900 bg-zinc-950/80">
		<div class="mx-auto max-w-6xl px-6 py-6 text-sm text-zinc-500">
			Built for Base • Signed clicks only • Rewards flow continuously.
		</div>
	</footer>
</div>
