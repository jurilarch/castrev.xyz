// SPDX-License-Identifier: MIT

export function padHex(value: string, length: number): string {
	const sanitized = value.startsWith('0x') ? value.slice(2) : value;
	return sanitized.padStart(length * 2, '0');
}

export function toHex(bytes: Uint8Array): string {
	return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

export function hexToBytes(hex: string): Uint8Array {
	const sanitized = hex.startsWith('0x') ? hex.slice(2) : hex;
	const array = new Uint8Array(sanitized.length / 2);
	for (let i = 0; i < array.length; i++) {
		array[i] = parseInt(sanitized.slice(i * 2, i * 2 + 2), 16);
	}
	return array;
}

export function concatHex(...parts: string[]): string {
	return `0x${parts.map((p) => (p.startsWith('0x') ? p.slice(2) : p)).join('')}`;
}

export function numberToHex(value: bigint | number): string {
	const big = typeof value === 'bigint' ? value : BigInt(value);
	return big.toString(16);
}
