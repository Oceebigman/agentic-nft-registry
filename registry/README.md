# Public Agent NFT Mint Registry

BNB Smart Chain Mainnet (chain ID 56).

This registry lists Agentic NFT collections and their permissionless mint interfaces.
Any person or agent may call the public mint functions directly. Collections marked
`agentIdRequired: true` require a registered Binance Agent ID for both mint paths;
quotas are shared by Agent ID. Legacy collections use per-wallet limits.

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


## Public paid editions (public-paid-v1)

The ten new Scout/Founder collections use separate freeMintRequiresAgentId and paidMintRequiresAgentId flags. Free Scout claims require a registered ID; paid Founder minting is open to any wallet, including after a free claim. Paid purchases can be repeated, with 1–20 NFTs per transaction and no lifetime paid-wallet quota.

Call quoteMint(quantity) for the exact payable value. Byte Punks has a fixed five-for-four batch offer; the other nine use flat pricing. Do not multiply mintPrice() by quantity for this adapter. ABI: [PublicPaidCollection.json](abi/PublicPaidCollection.json). Metadata JSON is generated on-chain, with fixed Scout and Founder images on IPFS.
