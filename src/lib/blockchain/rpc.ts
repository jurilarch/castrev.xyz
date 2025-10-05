// SPDX-License-Identifier: MIT
import type { AbiFunction } from './abi';
import { encodeCallData, decodeResult } from './abi';

export async function request<T = unknown>(method: string, params: unknown[]): Promise<T> {
	const { ethereum } = window as typeof window & {
		ethereum?: { request: (args: { method: string; params?: unknown[] }) => Promise<T> };
	};
	if (!ethereum) {
		throw new Error('Wallet not detected');
	}
	return ethereum.request({ method, params });
}

export async function ethCall(
	address: string,
	fn: AbiFunction,
	args: unknown[]
): Promise<unknown[]> {
	const data = encodeCallData(fn, args);
	const result = await request<string>('eth_call', [{ to: address, data }, 'latest']);
	return decodeResult(fn, result);
}

export async function ethSendTransaction(
	from: string,
	address: string,
	fn: AbiFunction,
	args: unknown[]
): Promise<string> {
	const data = encodeCallData(fn, args);
	return request<string>('eth_sendTransaction', [{ from, to: address, data }]);
}

export async function getChainId(): Promise<number> {
	const hexChainId = await request<string>('eth_chainId', []);
	return Number.parseInt(hexChainId, 16);
}

export async function getAccounts(): Promise<string[]> {
	try {
		return await request<string[]>('eth_accounts', []);
	} catch {
		return [];
	}
}

export async function requestAccounts(): Promise<string[]> {
	return request<string[]>('eth_requestAccounts', []);
}
