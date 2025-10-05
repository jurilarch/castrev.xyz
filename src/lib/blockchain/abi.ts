// SPDX-License-Identifier: MIT
import { concatHex, padHex } from '$lib/utils/hex';
import { keccak256Hex, utf8ToBytes } from '$lib/crypto/keccak';

export type AbiType = 'uint256' | 'bytes32' | 'address' | 'bool' | 'string' | 'address[]';

export interface AbiFunction {
	readonly name: string;
	readonly signature: string;
	readonly inputs: readonly AbiType[];
	readonly outputs: readonly AbiType[];
}

const ADDRESS_LENGTH = 20;
const WORD_SIZE = 32;

function encodeUint256(value: bigint | number | string): string {
	const big = typeof value === 'bigint' ? value : BigInt(value);
	const hex = big.toString(16);
	return padHex(`0x${hex}`, WORD_SIZE);
}

function encodeBool(value: boolean): string {
	return padHex(value ? '0x1' : '0x0', WORD_SIZE);
}

function encodeAddress(value: string): string {
	const sanitized = value.toLowerCase().replace(/^0x/, '');
	if (sanitized.length !== ADDRESS_LENGTH * 2) {
		throw new Error('Invalid address length');
	}
	return padHex(`0x${sanitized}`, WORD_SIZE);
}

function encodeBytes32(value: string): string {
	const sanitized = value.replace(/^0x/, '');
	if (sanitized.length !== 64) {
		throw new Error('Invalid bytes32 length');
	}
	return sanitized;
}

function encodeString(value: string): { head: string; tail: string } {
	const bytes = utf8ToBytes(value);
	const lengthEncoded = encodeUint256(bytes.length);
	const padding = (WORD_SIZE - (bytes.length % WORD_SIZE)) % WORD_SIZE;
	const dataHex = `${Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('')}${'00'.repeat(padding)}`;
	return { head: lengthEncoded, tail: dataHex };
}

export function functionSelector(signature: string): string {
	return keccak256Hex(utf8ToBytes(signature)).slice(0, 10);
}

export function encodeCallData(fn: AbiFunction, args: readonly unknown[]): string {
	if (args.length !== fn.inputs.length) {
		throw new Error('Invalid argument length');
	}
	const head: string[] = [];
	const tail: string[] = [];
	let dynamicOffset = WORD_SIZE * fn.inputs.length;
	fn.inputs.forEach((type, index) => {
		const value = args[index];
		switch (type) {
			case 'uint256':
				head.push(encodeUint256(value as bigint | number | string));
				break;
			case 'bool':
				head.push(encodeBool(Boolean(value)));
				break;
			case 'address':
				head.push(encodeAddress(value as string));
				break;
			case 'bytes32':
				head.push(encodeBytes32(value as string));
				break;
			case 'string': {
				head.push(encodeUint256(dynamicOffset));
				const encoded = encodeString(value as string);
				tail.push(encoded.head + encoded.tail);
				dynamicOffset += WORD_SIZE + encoded.tail.length / 2;
				break;
			}
			case 'address[]': {
				head.push(encodeUint256(dynamicOffset));
				const addresses = (value as string[]) ?? [];
				const lengthEncoded = encodeUint256(addresses.length);
				const encodedItems = addresses.map((item) => encodeAddress(item)).join('');
				tail.push(lengthEncoded + encodedItems);
				dynamicOffset += WORD_SIZE + addresses.length * WORD_SIZE;
				break;
			}
			default:
				throw new Error(`Unsupported type: ${type}`);
		}
	});
	const selector = functionSelector(fn.signature);
	return concatHex(selector, head.join(''), tail.join(''));
}

function readWord(data: string, index: number): string {
	const offset = 2 + index * WORD_SIZE * 2;
	return data.slice(offset, offset + WORD_SIZE * 2);
}

function decodeUint256(hex: string): bigint {
	return BigInt(`0x${hex}`);
}

function decodeBool(hex: string): boolean {
	return hex.endsWith('1');
}

function decodeAddress(hex: string): string {
	return `0x${hex.slice(24)}`;
}

function decodeBytes32(hex: string): string {
	return `0x${hex}`;
}

function decodeString(data: string, offsetWord: string): string {
	const offset = Number(decodeUint256(offsetWord));
	const start = 2 + offset * 2;
	const lengthHex = data.slice(start, start + WORD_SIZE * 2);
	const length = Number(decodeUint256(lengthHex));
	const contentStart = start + WORD_SIZE * 2;
	const contentHex = data.slice(contentStart, contentStart + length * 2);
	let result = '';
	for (let i = 0; i < contentHex.length; i += 2) {
		result += String.fromCharCode(parseInt(contentHex.slice(i, i + 2), 16));
	}
	return result;
}

function decodeAddressArray(data: string, offsetWord: string): string[] {
	const offset = Number(decodeUint256(offsetWord));
	const start = 2 + offset * 2;
	const lengthHex = data.slice(start, start + WORD_SIZE * 2);
	const length = Number(decodeUint256(lengthHex));
	const result: string[] = [];
	let cursor = start + WORD_SIZE * 2;
	for (let i = 0; i < length; i++) {
		const segment = data.slice(cursor, cursor + WORD_SIZE * 2);
		result.push(decodeAddress(segment));
		cursor += WORD_SIZE * 2;
	}
	return result;
}

export function decodeResult(fn: AbiFunction, data: string): unknown[] {
	if (!data || data === '0x') return [];
	const values: unknown[] = [];
	fn.outputs.forEach((type, index) => {
		const word = readWord(data, index);
		switch (type) {
			case 'uint256':
				values.push(decodeUint256(word));
				break;
			case 'bool':
				values.push(decodeBool(word));
				break;
			case 'address':
				values.push(decodeAddress(word));
				break;
			case 'bytes32':
				values.push(decodeBytes32(word));
				break;
			case 'string':
				values.push(decodeString(data, word));
				break;
			case 'address[]':
				values.push(decodeAddressArray(data, word));
				break;
			default:
				throw new Error(`Unsupported type: ${type}`);
		}
	});
	return values;
}
