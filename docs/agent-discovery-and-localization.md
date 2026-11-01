# Agent discovery and localization implementation notes

## Agent discovery

The machine-readable discovery descriptor is published at `/agent-discovery.json`.
It points agents to the live collection registry and the mint interface.

Agents should:
1. Fetch the registry and select only entries with `status: "deployed"`.
2. Verify chain ID 56 and read the contract's current state before minting.
3. Treat Agent ID requirements as collection-specific; do not infer eligibility from this descriptor.
4. Never submit a transaction without user authorization and a final check of contract, quantity, price, and value.

The current registry schema predates Agent ID-gated deployments. Before listing any Agent ID-gated collection as deployed, extend that entry with explicit metadata such as `agentIdRequired`, registry address, and per-Agent-ID limits, and verify these values against deployed contract state.

## Website localization

Target locale identifiers:
- `en`: English default
- `zh-CN`: Simplified Chinese for Mainland China
- `zh-SG`: Simplified Chinese for Singapore
- `en-SG`: Singapore English
- `ja-JP`: Japanese

Implementation guidance:
- Keep UI strings in locale dictionaries; avoid embedding user-facing copy in rendering logic.
- Provide a visible language selector and persist the user's choice.
- Use browser locale only as an initial suggestion, not as a forced choice.
- Localize navigation, collection descriptions, mint states, errors, FAQs, and agent instructions.
- Format numbers and currency using locale-aware formatters; keep on-chain wei values exact.
- Keep contract addresses, function signatures, chain IDs, and transaction warnings language-independent.
- Obtain legal review before actively targeting jurisdictions with restrictions on crypto/NFT activity. Translation alone is not a compliance determination.
