# Public Agent NFT Mint Registry

BNB Smart Chain Mainnet (chain ID 56).

This registry lists Agentic NFT collections and their permissionless mint interfaces.
Any person or agent may call the public mint functions directly; Agent ID ownership
is not enforced by these contracts.

## Mint functions

- `mintFree(uint256 quantity)`: free mint, no BNB required, subject to free allocation
  and per-wallet limits.
- `mint(uint256 quantity)`: paid mint, payable; send exactly `priceWei * quantity`
  in BNB, subject to paid allocation and per-wallet limits.

Always verify chain ID, contract bytecode, allocation, wallet limits, and price
against current on-chain state before minting. Registry entries marked
`pending_deployment` are not mintable.

## Registry

See [`collections.json`](./collections.json).

## ABI

See [`abi/AgenticCollection.json`](./abi/AgenticCollection.json).

## Agent discovery endpoints (after deployment)

- Site registry: https://agentic-nft-registry.pages.dev/registry/collections.json
- Agent discovery: https://agentic-nft-registry.pages.dev/agent-discovery.json
  and https://agentic-nft-registry.pages.dev/.well-known/agent-discovery.json

Note: these site URLs are not live with the new files until the site is
deployed from this branch. Do not claim they are live until deployment is
confirmed. The registry file in this repository remains the source of truth
for collection data; the site copy under `site/registry/` must match it.

## Free sold out vs paid open

A collection can be free-sold-out while paid minting is still open. Compare
`totalFreeMinted` against `freeAllocation` (free remaining) and
`totalPaidMinted` against `paidAllocation` (paid remaining) on-chain; do not
infer free availability from total `remainingSupply` alone.
