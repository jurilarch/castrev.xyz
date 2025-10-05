// SPDX-License-Identifier: MIT
import { keccak256Hex, utf8ToBytes } from '$lib/crypto/keccak';

function trimWhitespace(input: string): string {
	return input.trim();
}

function toLowercase(input: string): string {
	return input.toLowerCase();
}

function stripTrailingSlash(path: string): string {
	if (path.length <= 1) return path;
	return path.endsWith('/') ? path.slice(0, -1) : path;
}

function filterUtmParams(query: string): string {
	if (!query) return '';
	const params = query.split('&').filter((part) => part && !part.startsWith('utm_'));
	return params.join('&');
}

export function canonicalizeLink(rawLink: string): string {
	const trimmed = trimWhitespace(rawLink);
	if (!trimmed) return '';
	const lowered = toLowercase(trimmed);
	const [base, query = ''] = lowered.split('?');
	const normalizedBase = stripTrailingSlash(base);
	const filteredQuery = filterUtmParams(query);
	return filteredQuery ? `${normalizedBase}?${filteredQuery}` : normalizedBase;
}

export function linkIdFromCanonicalLink(canonicalLink: string): string {
	return keccak256Hex(utf8ToBytes(canonicalLink));
}

export function linkIdFromRawLink(rawLink: string): { canonical: string; linkId: string } {
	const canonical = canonicalizeLink(rawLink);
	const linkId = linkIdFromCanonicalLink(canonical);
	return { canonical, linkId };
}
