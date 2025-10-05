// SPDX-License-Identifier: MIT

const TEN = 10n;

export function formatUnits(value: bigint, decimals: number, precision = 4): string {
	if (decimals === 0) return value.toString();
	const base = TEN ** BigInt(decimals);
	const integer = value / base;
	const fraction = value % base;
	if (fraction === 0n) {
		return integer.toString();
	}
	const fractionStr = (fraction + base).toString().slice(1).padStart(decimals, '0');
	const truncated = fractionStr.slice(0, precision).replace(/0+$/, '');
	return truncated ? `${integer.toString()}.${truncated}` : integer.toString();
}

export function parseUnits(value: string, decimals: number): bigint {
	const [whole, fraction = ''] = value.split('.');
	const sanitizedWhole = whole.replace(/_/g, '');
	const sanitizedFraction = fraction.replace(/_/g, '');
	const base = TEN ** BigInt(decimals);
	let result = BigInt(sanitizedWhole || '0') * base;
	if (sanitizedFraction) {
		const padded = (sanitizedFraction + '0'.repeat(decimals)).slice(0, decimals);
		result += BigInt(padded);
	}
	return result;
}

export function formatUSD(value: bigint): string {
	return `$${formatUnits(value, 6, 2)}`;
}

export function formatPercent(numerator: bigint, denominator: bigint): string {
	if (denominator === 0n) return '0%';
	const scale = 10_000n;
	const ratio = (numerator * scale * 100n) / denominator;
	const whole = ratio / scale;
	const fractional = ratio % scale;
	const fractionStr = fractional.toString().padStart(4, '0').replace(/0+$/, '');
	return fractionStr ? `${whole}.${fractionStr}%` : `${whole}%`;
}
