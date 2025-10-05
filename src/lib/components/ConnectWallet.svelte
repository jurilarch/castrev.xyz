<script lang="ts">
	import { account, connectWallet, disconnectWallet } from '$lib/blockchain/wallet';
	import { onMount } from 'svelte';
	import { initializeWallet } from '$lib/blockchain/wallet';

	let isConnecting = false;

	onMount(() => {
		initializeWallet();
	});

	async function handleConnect() {
		if (isConnecting) return;
		isConnecting = true;
		try {
			await connectWallet();
		} catch (error) {
			console.error('Failed to connect wallet', error);
		} finally {
			isConnecting = false;
		}
	}

	function handleDisconnect() {
		disconnectWallet();
	}
</script>

{#if $account}
	<div class="flex items-center gap-2">
		<span class="rounded bg-emerald-900/40 px-3 py-1 font-mono text-sm text-emerald-200">
			{$account.slice(0, 6)}…{$account.slice(-4)}
		</span>
		<button
			class="rounded bg-zinc-700 px-3 py-1 text-sm hover:bg-zinc-600"
			on:click={handleDisconnect}
		>
			Disconnect
		</button>
	</div>
{:else}
	<button
		class="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-60"
		on:click={handleConnect}
		disabled={isConnecting}
	>
		{isConnecting ? 'Connecting…' : 'Connect Wallet'}
	</button>
{/if}
