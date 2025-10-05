// SPDX-License-Identifier: MIT

const ROUND_CONSTANTS: bigint[] = [
	0x0000000000000001n,
	0x0000000000008082n,
	0x800000000000808an,
	0x8000000080008000n,
	0x000000000000808bn,
	0x0000000080000001n,
	0x8000000080008081n,
	0x8000000000008009n,
	0x000000000000008an,
	0x0000000000000088n,
	0x0000000080008009n,
	0x000000008000000an,
	0x000000008000808bn,
	0x800000000000008bn,
	0x8000000000008089n,
	0x8000000000008003n,
	0x8000000000008002n,
	0x8000000000000080n,
	0x000000000000800an,
	0x800000008000000an,
	0x8000000080008081n,
	0x8000000000008080n,
	0x0000000080000001n,
	0x8000000080008008n
];

const ROTATION_OFFSETS: number[][] = [
	[0, 36, 3, 41, 18],
	[1, 44, 10, 45, 2],
	[62, 6, 43, 15, 61],
	[28, 55, 25, 21, 56],
	[27, 20, 39, 8, 14]
];

const MASK = (1n << 64n) - 1n;
const RATE = 136;

function rotl(value: bigint, shift: number): bigint {
	shift %= 64;
	if (shift === 0) return value;
	return ((value << BigInt(shift)) & MASK) | (value >> BigInt(64 - shift));
}

function keccakF(state: BigUint64Array): void {
	const C = new BigUint64Array(5);
	const D = new BigUint64Array(5);
	const temp = new BigUint64Array(25);
	for (let round = 0; round < 24; round++) {
		for (let x = 0; x < 5; x++) {
			C[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20];
		}
		for (let x = 0; x < 5; x++) {
			D[x] = C[(x + 4) % 5] ^ rotl(C[(x + 1) % 5], 1);
		}
		for (let x = 0; x < 5; x++) {
			for (let y = 0; y < 5; y++) {
				const index = x + 5 * y;
				state[index] ^= D[x];
			}
		}

		for (let x = 0; x < 5; x++) {
			for (let y = 0; y < 5; y++) {
				const index = x + 5 * y;
				const shift = ROTATION_OFFSETS[y][x];
				const newX = y;
				const newY = (2 * x + 3 * y) % 5;
				temp[newX + 5 * newY] = rotl(state[index], shift);
			}
		}

		for (let x = 0; x < 5; x++) {
			for (let y = 0; y < 5; y++) {
				const index = x + 5 * y;
				state[index] = temp[index] ^ (~temp[((x + 1) % 5) + 5 * y] & temp[((x + 2) % 5) + 5 * y]);
			}
		}

		state[0] ^= ROUND_CONSTANTS[round];
	}
}

function padInput(input: Uint8Array): Uint8Array {
	const lengthWithPadding = input.length + 1;
	const remainder = lengthWithPadding % RATE;
	const paddingSize = remainder === 0 ? RATE : RATE - remainder;
	const output = new Uint8Array(lengthWithPadding + paddingSize);
	output.set(input, 0);
	output[input.length] = 0x01;
	output[output.length - 1] ^= 0x80;
	return output;
}

function absorb(state: BigUint64Array, block: Uint8Array): void {
	for (let i = 0; i < RATE / 8; i++) {
		let value = 0n;
		for (let j = 0; j < 8; j++) {
			value |= BigInt(block[i * 8 + j]) << BigInt(8 * j);
		}
		state[i] ^= value;
	}
	keccakF(state);
}

function squeeze(state: BigUint64Array, outputLength: number): Uint8Array {
	const output = new Uint8Array(outputLength);
	let offset = 0;
	while (offset < outputLength) {
		for (let i = 0; i < RATE / 8 && offset < outputLength; i++) {
			let lane = state[i];
			for (let j = 0; j < 8 && offset < outputLength; j++) {
				output[offset++] = Number(lane & 0xffn);
				lane >>= 8n;
			}
		}
		if (offset < outputLength) {
			keccakF(state);
		}
	}
	return output;
}

export function keccak256(data: Uint8Array): Uint8Array {
	const state = new BigUint64Array(25);
	const padded = padInput(data);
	for (let offset = 0; offset < padded.length; offset += RATE) {
		absorb(state, padded.subarray(offset, offset + RATE));
	}
	return squeeze(state, 32);
}

export function keccak256Hex(data: Uint8Array | string): string {
	const bytes = typeof data === 'string' ? utf8ToBytes(data) : data;
	const digest = keccak256(bytes);
	return `0x${Array.from(digest, (byte) => byte.toString(16).padStart(2, '0')).join('')}`;
}

export function utf8ToBytes(value: string): Uint8Array {
	const encoder = new TextEncoder();
	return encoder.encode(value);
}
