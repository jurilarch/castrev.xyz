<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';
	import {
		account,
		connectWallet,
		disconnectWallet,
		initializeWallet
	} from '$lib/blockchain/wallet';

	let isConnecting = false;
	let hasWallet = false;
	let errorMessage = '';

	function updateWalletPresence(): boolean {
		if (!browser) return false;
		const { ethereum } = window as typeof window & { ethereum?: unknown };
		hasWallet = Boolean(ethereum);
		if (hasWallet) {
			errorMessage = '';
		}
		return hasWallet;
	}

	onMount(() => {
		if (browser) {
			updateWalletPresence();
			window.addEventListener(
				'ethereum#initialized',
				() => {
					updateWalletPresence();
				},
				{ once: true }
			);
		}
		initializeWallet();
	});

	async function handleConnect() {
		if (isConnecting) return;
		errorMessage = '';
		if (!updateWalletPresence()) {
			errorMessage =
				'No browser wallet detected. Install MetaMask or another Base-compatible wallet.';
			return;
		}
		isConnecting = true;
		try {
			await connectWallet();
		} catch (error) {
			console.error('Failed to connect wallet', error);
			const walletError = error as Error & { code?: number };
			if (walletError?.code === 4001) {
				errorMessage = 'Connection request rejected.';
			} else {
				errorMessage = walletError?.message ?? 'Failed to connect wallet';
			}
		} finally {
			isConnecting = false;
		}
	}

	function handleDisconnect() {
		errorMessage = '';
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
	<div class="flex flex-col items-stretch gap-1">
		<button
			class="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-60"
			on:click={handleConnect}
			disabled={isConnecting}
		>
			{isConnecting ? 'Connecting…' : 'Connect Wallet'}
		</button>
		{#if errorMessage}
			<p class="text-xs text-rose-400 sm:text-right">{errorMessage}</p>
		{/if}
	</div>
{/if}
