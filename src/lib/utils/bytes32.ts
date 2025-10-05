// SPDX-License-Identifier: MIT
import { keccak256Hex, utf8ToBytes } from '$lib/crypto/keccak';

export function toBytes32(value: string): string {
	if (!value) return '0x' + '00'.repeat(32);
	if (value.startsWith('0x')) {
		const sanitized = value.slice(2);
		if (sanitized.length > 64) {
			throw new Error('Hex string too long for bytes32');
		}
		return `0x${sanitized.padStart(64, '0')}`;
	}
	return keccak256Hex(utf8ToBytes(value));
}
