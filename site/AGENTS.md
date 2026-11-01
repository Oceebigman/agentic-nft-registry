# Agent instructions — Agentic NFT Launchpad

Public NFT collection directory on BNB Smart Chain (chain ID 56).

## Discovery
- Agent profile: https://agentic-nft-registry.pages.dev/agent-discovery.json
- Agent Card metadata: https://agentic-nft-registry.pages.dev/.well-known/agent-card.json
- Collections JSON: https://agentic-nft-registry.pages.dev/registry/collections.json
- Read-only collections API: https://agentic-nft-registry.pages.dev/api/agent/collections
- Human website: https://agentic-nft-registry.pages.dev/
- Binance Agent ID: https://web3.binance.com/agent-id

## Agent workflow
1. Fetch the collections API or JSON registry.
2. Use only records with status `deployed` and a contractAddress.
3. Verify chain ID 56, contract bytecode and live contract state before recommending or preparing a mint.
4. Read the per-collection `agentIdRequired` flag. HARTB, BLUM and PLUTO require Binance Agent ID for both free and paid mints. Their limits are shared by Agent ID, not by wallet. Other legacy collections use wallet-based limits.
5. To verify a wallet's Binance Agent ID, call `handleOf(address)` on registry contract `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` on BNB Chain. A non-empty handle is required only for gated collections.
6. Read `mintPrice()`, allocations, minted counters and the correct quota getter from the target contract. Do not rely on stale registry values for live state.
7. Free mint: `mintFree(uint256 quantity)`, value 0. Paid mint: `mint(uint256 quantity)`, value exactly `mintPrice() * quantity` in wei.
8. Obtain explicit user authorization before sending any transaction. Never request or reveal private keys, seed phrases or recovery material.

## Important
- A Binance Agent ID is not globally required to browse the launchpad.
- Agent ID discovery metadata is not an on-chain permission; only the contract enforces eligibility.
- Free allocation sold out does not necessarily mean the paid allocation is sold out.
- Never mint from pending_deployment records.
- The published Agent Card is a discovery profile; it does not claim a live A2A JSON-RPC task endpoint yet.
