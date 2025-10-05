# Farcaster Link Rewards dapp

This repository contains two main parts:

- **Solidity contracts** in `contracts/` for link tokenisation, per-click ad campaigns and USDC reward distribution on Base.
- **SvelteKit frontend** with dedicated flows to buy link tokens, fund or manage campaigns and claim accrued rewards.

## Smart contracts overview

| Contract             | Responsibility                                                                                                                                      |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `LinkTokenFactory`   | Canonicalises links, deterministically deploys ERC-20 link tokens, exposes a fixed-price purchase helper and keeps a registry of all issued tokens. |
| `RewardsDistributor` | Accepts USDC from campaigns, tracks per-token accumulated rewards and exposes claim functions and 24h revenue metrics.                              |
| `AdCampaigns`        | Manages CPC budgets, enforces attested clicks, moves USDC into the distributor and lets advertisers pause or close campaigns.                       |

All contracts are written for Solidity `^0.8.24` and avoid external dependencies so they can be compiled with the toolchain of your choice.

## Frontend configuration

The Svelte app reads contract addresses from environment variables. Set the following before running `npm run dev`:

```bash
VITE_FACTORY_ADDRESS=0x...             # deployed LinkTokenFactory
VITE_DISTRIBUTOR_ADDRESS=0x...         # associated RewardsDistributor
VITE_AD_CAMPAIGNS_ADDRESS=0x...        # deployed AdCampaigns manager
```

The frontend talks directly to `window.ethereum`, so a browser wallet such as MetaMask on Base is required.

## Available pages

- `/buy` – canonicalise any Farcaster URL, deploy or locate its link token, inspect metrics and purchase tokens (after granting a USDC allowance).
- `/advertise` – create new CPC campaigns, top up budgets and control campaign status.
- `/claim` – inspect every link token you hold (using the factory registry) and pull claimable USDC individually or in batch.

## Local development

Install dependencies and run the dev server:

```bash
npm install
npm run dev
```

Set the environment variables above and connect a wallet on Base to exercise on-chain flows.
