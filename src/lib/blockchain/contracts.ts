// SPDX-License-Identifier: MIT
import type { AbiFunction } from './abi';
import { ethCall, ethSendTransaction } from './rpc';

export interface ContractFunction {
	readonly abi: AbiFunction;
	readonly address: string;
}

interface DappContracts {
	address: string;
	distributor: string;
	adCampaigns: string;
}

export const CONTRACTS: DappContracts = {
	address: import.meta.env.VITE_FACTORY_ADDRESS ?? '0x0000000000000000000000000000000000000000',
	distributor:
		import.meta.env.VITE_DISTRIBUTOR_ADDRESS ?? '0x0000000000000000000000000000000000000000',
	adCampaigns:
		import.meta.env.VITE_AD_CAMPAIGNS_ADDRESS ?? '0x0000000000000000000000000000000000000000'
};

export const FACTORY_FUNCTIONS = {
	getLinkToken: {
		abi: {
			name: 'getLinkToken',
			signature: 'getLinkToken(bytes32)',
			inputs: ['bytes32'],
			outputs: ['address']
		},
		address: CONTRACTS.address
	},
	getOrCreateLinkToken: {
		abi: {
			name: 'getOrCreateLinkToken',
			signature: 'getOrCreateLinkToken(bytes32,string,string)',
			inputs: ['bytes32', 'string', 'string'],
			outputs: ['address']
		},
		address: CONTRACTS.address
	},
	purchase: {
		abi: {
			name: 'purchase',
			signature: 'purchase(bytes32,uint256,address)',
			inputs: ['bytes32', 'uint256', 'address'],
			outputs: []
		},
		address: CONTRACTS.address
	},
	tokenPrice: {
		abi: {
			name: 'tokenPrice',
			signature: 'tokenPrice()',
			inputs: [],
			outputs: ['uint256']
		},
		address: CONTRACTS.address
	},
	getAllLinkTokens: {
		abi: {
			name: 'getAllLinkTokens',
			signature: 'getAllLinkTokens()',
			inputs: [],
			outputs: ['address[]']
		},
		address: CONTRACTS.address
	}
} satisfies Record<string, ContractFunction>;

export const DISTRIBUTOR_FUNCTIONS = {
	pendingRewards: {
		abi: {
			name: 'pendingRewards',
			signature: 'pendingRewards(address,address)',
			inputs: ['address', 'address'],
			outputs: ['uint256']
		},
		address: CONTRACTS.distributor
	},
	claim: {
		abi: {
			name: 'claim',
			signature: 'claim(address,address)',
			inputs: ['address', 'address'],
			outputs: ['uint256']
		},
		address: CONTRACTS.distributor
	},
	claimBatch: {
		abi: {
			name: 'claimBatch',
			signature: 'claimBatch(address[],address)',
			inputs: ['address[]', 'address'],
			outputs: ['uint256']
		},
		address: CONTRACTS.distributor
	},
	revenue24h: {
		abi: {
			name: 'revenueLast24Hours',
			signature: 'revenueLast24Hours(address)',
			inputs: ['address'],
			outputs: ['uint256']
		},
		address: CONTRACTS.distributor
	}
} satisfies Record<string, ContractFunction>;

export const AD_CAMPAIGNS_FUNCTIONS = {
	createCampaign: {
		abi: {
			name: 'createCampaign',
			signature: 'createCampaign(bytes32,bytes32,address,uint256,uint256)',
			inputs: ['bytes32', 'bytes32', 'address', 'uint256', 'uint256'],
			outputs: ['uint256']
		},
		address: CONTRACTS.adCampaigns
	},
	campaigns: {
		abi: {
			name: 'campaigns',
			signature: 'campaigns(uint256)',
			inputs: ['uint256'],
			outputs: [
				'address',
				'bytes32',
				'bytes32',
				'address',
				'uint256',
				'uint256',
				'uint256',
				'uint256',
				'bool',
				'bool'
			]
		},
		address: CONTRACTS.adCampaigns
	},
	fundCampaign: {
		abi: {
			name: 'fundCampaign',
			signature: 'fundCampaign(uint256,uint256)',
			inputs: ['uint256', 'uint256'],
			outputs: []
		},
		address: CONTRACTS.adCampaigns
	},
	pauseCampaign: {
		abi: {
			name: 'pauseCampaign',
			signature: 'pauseCampaign(uint256,bool)',
			inputs: ['uint256', 'bool'],
			outputs: []
		},
		address: CONTRACTS.adCampaigns
	},
	closeCampaign: {
		abi: {
			name: 'closeCampaign',
			signature: 'closeCampaign(uint256,address)',
			inputs: ['uint256', 'address'],
			outputs: []
		},
		address: CONTRACTS.adCampaigns
	},
	remainingBudget: {
		abi: {
			name: 'remainingBudget',
			signature: 'remainingBudget(uint256)',
			inputs: ['uint256'],
			outputs: ['uint256']
		},
		address: CONTRACTS.adCampaigns
	}
} satisfies Record<string, ContractFunction>;

const LINK_TOKEN_ABI: Record<string, AbiFunction> = {
	totalSupply: {
		name: 'totalSupply',
		signature: 'totalSupply()',
		inputs: [],
		outputs: ['uint256']
	},
	balanceOf: {
		name: 'balanceOf',
		signature: 'balanceOf(address)',
		inputs: ['address'],
		outputs: ['uint256']
	}
};

export function linkTokenFunction(
	address: string,
	key: keyof typeof LINK_TOKEN_ABI
): ContractFunction {
	return {
		abi: LINK_TOKEN_ABI[key],
		address
	};
}

export async function readContract(fn: ContractFunction, args: unknown[] = []): Promise<unknown[]> {
	return ethCall(fn.address, fn.abi, args);
}

export async function writeContract(
	from: string,
	fn: ContractFunction,
	args: unknown[] = []
): Promise<string> {
	return ethSendTransaction(from, fn.address, fn.abi, args);
}
