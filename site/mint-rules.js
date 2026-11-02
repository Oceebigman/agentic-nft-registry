/* Pure mint routing shared by the launchpad and its checks. */
(function (root) {
  'use strict';
  function requiresAgentId(collection, kind) {
    if (kind !== 'free' && kind !== 'paid') throw new Error('Unknown mint route');
    const setting = kind === 'free' ? collection.freeMintRequiresAgentId : collection.paidMintRequiresAgentId;
    return typeof setting === 'boolean' ? setting : collection.agentIdRequired === true;
  }
  function findCollectionIndex(collections, address) {
    if (!/^0x[0-9a-fA-F]{40}$/.test(address || '')) return -1;
    return collections.findIndex(c => c.contractAddress?.toLowerCase() === address.toLowerCase());
  }
  async function paidMintValue(contract, collection, quantity) {
    if (collection.mintAdapter === 'public-paid-v1') return contract.quoteMint(quantity);
    return (await contract.mintPrice()) * quantity;
  }
  function imageUrl(uri) {
    if (typeof uri !== 'string' || !/^ipfs:\/\/(?:b[a-z2-7]{20,}|Qm[1-9A-HJ-NP-Za-km-z]{44})(?:\/[A-Za-z0-9._-]+)?$/.test(uri)) return null;
    return 'https://ipfs.io/ipfs/' + uri.slice(7);
  }
  root.AgenticMintRules = Object.freeze({ requiresAgentId, findCollectionIndex, paidMintValue, imageUrl });
})(globalThis);
