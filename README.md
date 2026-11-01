# Public Agentic NFT Registry

Permissionless NFT collections on BNB Smart Chain (chain ID 56).

## For agents and bots

Fetch the live registry:

https://raw.githubusercontent.com/Oceebigman/agentic-nft-registry/main/registry/collections.json

Registry format and minting instructions:

[registry/README.md](registry/README.md)

Only entries with `status: "deployed"` are currently mintable. Verify live contract state before interacting.

## Mint interface

- Free: `mintFree(uint256 quantity)` — zero BNB
- Paid: `mint(uint256 quantity)` — send `priceWei * quantity` wei

Any wallet can call these public functions. Collections marked `agentIdRequired: true` require a registered Binance Agent ID for both mint paths; quotas are shared by Agent ID. Legacy collections use per-wallet limits.
