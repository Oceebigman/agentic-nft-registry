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
