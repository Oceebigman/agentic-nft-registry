# Agent instructions — Agentic NFT Launchpad

Public NFT collection directory and read-only A2A discovery service on BNB Smart Chain (chain ID 56).

## Discovery
- A2A Agent Card: https://agentic-nft-registry.pages.dev/.well-known/agent-card.json
- A2A JSON-RPC endpoint: https://agentic-nft-registry.pages.dev/api/a2a
- Read-only collections API: https://agentic-nft-registry.pages.dev/api/agent/collections
- Collections JSON: https://agentic-nft-registry.pages.dev/registry/collections.json
- Agent profile: https://agentic-nft-registry.pages.dev/agent-discovery.json
- Binance Agent ID: https://web3.binance.com/agent-id

## A2A interaction
Send JSON-RPC 2.0 `message/send` to `/api/a2a`. Put the user request in `params.message.parts` as a text part, e.g. "Find live collections requiring Binance Agent ID". The endpoint returns deployed registry entries and filtering metadata. It is read-only.

## Agent workflow
1. Fetch the collections API or JSON registry.
2. Use only records with status `deployed` and a contractAddress.
3. Verify chain ID 56, contract bytecode and live contract state before recommending or preparing a mint.
4. HARTB, BLUM and PLUTO require Binance Agent ID for both free and paid mints. Their limits are shared by Agent ID, not by wallet. Other legacy collections use wallet-based limits.
5. Verify a wallet's Binance Agent ID by calling `handleOf(address)` on registry contract `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` on BNB Chain. A non-empty handle is required only for gated collections.
6. Read `mintPrice()`, allocations, minted counters and the correct quota getter from the target contract. Registry values are discovery metadata, not guaranteed live state.
7. Free mint: `mintFree(uint256 quantity)`, value 0. Paid mint: `mint(uint256 quantity)`, value exactly `mintPrice() * quantity` in wei.
8. Obtain explicit user authorization before sending any transaction. Never request or reveal private keys, seed phrases or recovery material.

## Important
- Binance Agent ID is not required to browse the launchpad.
- Agent ID discovery metadata does not itself grant on-chain mint permission.
- Free allocation sold out does not necessarily mean paid allocation is sold out.
- Never mint from pending_deployment records.
- The A2A endpoint is read-only and does not submit blockchain transactions.
