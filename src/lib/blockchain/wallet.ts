// SPDX-License-Identifier: MIT
import { writable } from 'svelte/store';
import { getAccounts, getChainId, requestAccounts } from './rpc';

export const account = writable<string | null>(null);
export const chainId = writable<number | null>(null);

export async function initializeWallet(): Promise<void> {
	if (typeof window === 'undefined') return;
	const accounts = await getAccounts();
	account.set(accounts[0] ?? null);
	try {
		const id = await getChainId();
		chainId.set(id);
	} catch {
		chainId.set(null);
	}
	const { ethereum } = window as typeof window & { ethereum?: any };
	if (ethereum?.on) {
		ethereum.on('accountsChanged', (accs: string[]) => {
			account.set(accs[0] ?? null);
		});
		ethereum.on('chainChanged', (chain: string) => {
			chainId.set(Number.parseInt(chain, 16));
		});
	}
}

export async function connectWallet(): Promise<string | null> {
	const accounts = await requestAccounts();
	const selected = accounts[0] ?? null;
	account.set(selected);
	if (selected) {
		const id = await getChainId();
		chainId.set(id);
	}
	return selected;
}

export function disconnectWallet(): void {
	account.set(null);
}
