const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const context = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../site/mint-rules.js'), 'utf8'), context);
const rules = context.AgenticMintRules;

(async () => {
  const openPaid = { agentIdRequired: false, freeMintRequiresAgentId: true, paidMintRequiresAgentId: false, mintAdapter: 'public-paid-v1' };
  assert.equal(rules.requiresAgentId(openPaid, 'free'), true);
  assert.equal(rules.requiresAgentId(openPaid, 'paid'), false);
  assert.equal(rules.requiresAgentId({ agentIdRequired: true }, 'free'), true);
  assert.equal(rules.requiresAgentId({ agentIdRequired: true }, 'paid'), true);
  assert.equal(rules.requiresAgentId({}, 'paid'), false);

  // A filtered card must resolve the contract by address, never by its position in the filtered list.
  const collections = [{ contractAddress: '0x' + '1'.repeat(40) }, { contractAddress: '0x' + '2'.repeat(40) }];
  assert.equal(rules.findCollectionIndex(collections, collections[1].contractAddress), 1);
  assert.equal(rules.findCollectionIndex(collections, '0x' + '3'.repeat(40)), -1);
  assert.equal(rules.findCollectionIndex(collections, undefined), -1);

  // The real contract quote is authoritative, including discounts; base-price multiplication is not used.
  const discounted = { quoteMint: async q => { assert.equal(q, 5n); return 200n; }, mintPrice: async () => { throw Error('Wrong pricing path'); } };
  assert.equal(await rules.paidMintValue(discounted, openPaid, 5n), 200n);
  assert.equal(await rules.paidMintValue({ mintPrice: async () => 50n }, {}, 5n), 250n);
  await assert.rejects(rules.paidMintValue({ quoteMint: async () => { throw Error('RPC unavailable'); } }, openPaid, 5n));

  assert.equal(rules.imageUrl('javascript:alert(1)'), null);
  assert.equal(rules.imageUrl('https://untrusted.example/a.png'), null);
  assert.equal(rules.imageUrl('ipfs://bafkreifounderexamplecontent/image.png'), 'https://ipfs.io/ipfs/bafkreifounderexamplecontent/image.png');

  // Exercise the actual card renderer with a filtered list and new batch controls.
  const app = fs.readFileSync(path.join(__dirname, '../site/app.js'), 'utf8');
  const start = app.indexOf('function render(){');
  const end = app.indexOf('function esc(', start);
  assert.ok(start >= 0 && end > start);
  const nodes = { search: { value: 'Byte' }, status: { value: 'all' }, grid: { innerHTML: '' } };
  const sample = { ...openPaid, name: 'Byte Punks', symbol: 'BPUNK', contractAddress: collections[1].contractAddress,
    max: 777n, remaining: 777n, minted: 0n, price: 50000000000000n,
    freeAllocation: 77n, paidAllocation: 700n, freeMinted: 0n, paidMinted: 0n,
    bundleDiscountEnabled: true, images: { founder: { uri: 'ipfs://bafkreifounderexamplecontent/image.png' } } };
  const renderContext = { AgenticMintRules: rules, collections: [
    { ...sample, name: 'Legacy', symbol: 'OLD', contractAddress: collections[0].contractAddress, mintAdapter: undefined }, sample],
    $: id => nodes[id], t: key => key, bnb: value => String(Number(value) / 1e18),
    esc: value => String(value).replace(/[&<>"']/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]) };
  vm.runInNewContext(app.slice(start, end) + ';render();', renderContext);
  assert.equal(nodes.grid.innerHTML.includes(collections[0].contractAddress), false);
  assert.ok(nodes.grid.innerHTML.includes('Claim Scout'));
  assert.ok(nodes.grid.innerHTML.includes('Buy Founder'));
  assert.ok(nodes.grid.innerHTML.includes('data-quantity="1"'));
  assert.ok(nodes.grid.innerHTML.includes('data-quantity="3"'));
  assert.ok(nodes.grid.innerHTML.includes('data-quantity="5"'));
  assert.ok(nodes.grid.innerHTML.includes('pay for 4'));
  assert.equal(nodes.grid.innerHTML.includes('data-index='), false);
  for (const match of nodes.grid.innerHTML.matchAll(/data-address="([^"]+)"/g)) {
    assert.equal(match[1], collections[1].contractAddress);
  }
  console.log('Mint route, filtered-card selection, quote, and image URL checks passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
