# Agentic NFT Launchpad

Public, permissionless ERC-721 mint collections on BNB Smart Chain (chain ID 56).
The live site is https://agentic-nft-registry.pages.dev/ and is served from the
`site/` directory in this branch.

## For agents and bots

- A2A Agent Card: https://agentic-nft-registry.pages.dev/.well-known/agent-card.json
- A2A JSON-RPC endpoint (read-only): https://agentic-nft-registry.pages.dev/api/a2a
- Read-only collections API: https://agentic-nft-registry.pages.dev/api/agent/collections
- Agent instructions: https://agentic-nft-registry.pages.dev/AGENTS.md
- LLM discovery index: https://agentic-nft-registry.pages.dev/llms.txt

- Registry (site, JSON): https://agentic-nft-registry.pages.dev/registry/collections.json
- Registry (source of truth in this branch): [`registry/collections.json`](registry/collections.json)
- Agent discovery: https://agentic-nft-registry.pages.dev/agent-discovery.json
  (also at `/.well-known/agent-discovery.json`)
- Mint ABI: [`registry/abi/AgenticCollection.json`](registry/abi/AgenticCollection.json)
- Registry format and minting instructions: [`registry/README.md`](registry/README.md)

## Mint interface

- Free: `mintFree(uint256 quantity)` — zero BNB, subject to the free allocation
  and per-wallet limit. When the free allocation is exhausted, the free mint is
  sold out even if paid supply remains.
- Paid: `mint(uint256 quantity)` — payable; send exactly
  `mintPrice() * quantity` BNB, subject to the paid allocation and per-wallet limit.

Any wallet can call these public functions. Agent ID ownership is not required
by the contracts.

Only entries with `status: "deployed"` and a `contractAddress` are mintable.
Entries marked `pending_deployment` have no contract address and are not mintable.
Always verify chain ID, contract bytecode, allocation, wallet limits, and price
against current on-chain state before minting.

## Development

This repository is also a Foundry project (`src/`, `test/`, `script/`).
No contract, price, supply, allocation, or ownership changes are made by the
agent-discovery work in this branch.

```shell
forge build
forge test
forge fmt --check
```

Registry structure can be checked without a wallet:

```shell
bash script/ValidateRegistry.sh
```
