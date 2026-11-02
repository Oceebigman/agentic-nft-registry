#!/usr/bin/env python3
"""Build real content-addressed artwork, draft launch records, and metadata examples.

No network writes, no wallet access, and no contract deployments. --verify-online
checks that a public IPFS gateway returns the exact reviewed image bytes.
"""
import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import datetime
import hashlib
import html
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess

COLLECTIONS = [
    ('byte-punks', 'Byte Punks', 'BPUNK', 777, 77, 50000000000000, True),
    ('bot-cats', 'Bot Cats', 'BCATS', 888, 88, 50000000000000, False),
    ('prompt-dogs', 'Prompt Dogs', 'PDOG', 1000, 100, 50000000000000, False),
    ('neural-frogs', 'Neural Frogs', 'NFRG', 777, 77, 50000000000000, False),
    ('agent-raccoons', 'Agent Raccoons', 'RACC', 1000, 100, 50000000000000, False),
    ('chain-rascals', 'Chain Rascals', 'RASC', 888, 88, 50000000000000, False),
    ('ai-gremlins', 'AI Gremlins', 'GREML', 777, 77, 80000000000000, False),
    ('pixel-operators', 'Pixel Operators', 'PXOP', 555, 55, 80000000000000, False),
    ('neural-nomads', 'Neural Nomads', 'NNOM', 555, 55, 120000000000000, False),
    ('genesis-bots', 'Genesis Bots', 'GBOT', 333, 33, 200000000000000, False),
]


def varint(value):
    result = bytearray()
    while value >= 128:
        result.append((value & 127) | 128)
        value >>= 7
    result.append(value)
    return bytes(result)


def cbor_size(major, value):
    if value < 24:
        return bytes([(major << 5) | value])
    if value < 256:
        return bytes([(major << 5) | 24, value])
    if value < 65536:
        return bytes([(major << 5) | 25]) + struct.pack('>H', value)
    return bytes([(major << 5) | 26]) + struct.pack('>I', value)


def car_header(roots):
    # DAG-CBOR CID tag 42 has a leading identity byte before the binary CID.
    return (b'\xa2\x65roots' + cbor_size(4, len(roots))
            + b''.join(b'\xd8\x2a' + cbor_size(2, len(cid) + 1) + b'\x00' + cid for cid in roots)
            + b'\x67version\x01')


def quote(price, quantity, bundle):
    return (quantity - quantity // 5 if bundle else quantity) * price


def dump(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True, help='Folder containing twenty reviewed PNG files')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--verify-online', action='store_true')
    parser.add_argument('--gateway', default='https://ipfs.io/ipfs/')
    parser.add_argument('--ipfs-root', help='CID returned by Pinata after uploading the images folder')
    args = parser.parse_args()
    output = args.output.resolve()
    source = args.source.resolve()
    if args.ipfs_root and not re.fullmatch(r'(?:b[a-z2-7]{20,}|Qm[1-9A-HJ-NP-Za-km-z]{44})', args.ipfs_root):
        raise ValueError('Invalid IPFS folder CID')
    output.mkdir(parents=True, exist_ok=True)
    images = output / 'images'
    examples = output / 'metadata-examples'
    images.mkdir(exist_ok=True)
    examples.mkdir(exist_ok=True)
    blocks = []
    rows = []
    pending = []
    cards = []
    hashes = set()
    for slug, name, ticker, supply, free, price, bundle in COLLECTIONS:
        description = (f'{name}: original AI-created collectible portrait editions. '
                       'Scout is a free registered-ID claim; Founder is the publicly paid edition. '
                       'Artwork is shared within each edition; every NFT has a unique serial and a permanent edition trait.')
        art = {}
        for edition in ('scout', 'founder'):
            filename = f'{slug}-{edition}.png'
            raw = (source / filename).read_bytes()
            if raw[:8] != b'\x89PNG\r\n\x1a\n':
                raise ValueError(f'{filename}: not a PNG')
            width, height = struct.unpack('>II', raw[16:24])
            if width != height or width < 512:
                raise ValueError(f'{filename}: artwork must be square and at least 512px')
            digest = hashlib.sha256(raw).digest()
            if digest in hashes:
                raise ValueError(f'{filename}: duplicate artwork bytes')
            hashes.add(digest)
            binary_cid = b'\x01\x55\x12\x20' + digest  # CIDv1 / raw / sha2-256
            cid = 'b' + base64.b32encode(binary_cid).decode().lower().rstrip('=')
            destination = images / filename
            if destination != (source / filename):
                shutil.copyfile(source / filename, destination)
            image_uri = 'ipfs://' + (args.ipfs_root + '/' + filename if args.ipfs_root else cid)
            art[edition] = dict(file='images/' + filename, rawBlockCid=cid, uri=image_uri,
                                sha256=digest.hex(), width=width, height=height, bytes=len(raw))
            blocks.append((binary_cid, raw))
            serial = 1 if edition == 'scout' else 2
            metadata = dict(name=f'{name} {edition.title()} #{serial}', description=description,
                            image=art[edition]['uri'], attributes=[
                                dict(trait_type='Edition', value=edition.title()),
                                dict(trait_type='Mint route', value='Free ID claim' if edition == 'scout' else 'Paid'),
                                dict(trait_type='Serial', value=serial)])
            dump(examples / f'{slug}-{edition}.json', metadata)
        row = dict(slug=slug, name=name, symbol=ticker, description=description,
                   maxSupply=supply, freeAllocation=free, paidAllocation=supply-free,
                   priceWei=str(price), bundleDiscountEnabled=bundle,
                   freeMintRequiresAgentId=True, paidMintRequiresAgentId=False,
                   freeLimitPerAgentId=1, freeLimitPerWallet=1,
                   paidLifetimeWalletLimit=None, maxMintPerTransaction=20,
                   images=art, quotesWei={str(q): str(quote(price, q, bundle)) for q in (1, 3, 5, 20)})
        rows.append(row)
        pending.append({k: v for k, v in row.items() if k not in ('quotesWei',)})
        pending[-1].update(status='pending_deployment', contractAddress=None,
                           agentIdRequired=False, mintAdapter='public-paid-v1',
                           abi='/registry/abi/PublicPaidCollection.json',
                           agentIdRegistry='0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F')
        cards.append(f'<section><header><h2>{html.escape(name)} <small>{ticker}</small></h2>'
                     f'<p>{supply:,} total · {free} Scout / {supply-free} Founder · '
                     f'{price / 10**18:.8f} BNB base price</p></header><div class="pair">'
                     f'<figure><img src="images/{slug}-scout.png" alt="{name} Scout"><figcaption>Scout · free ID claim</figcaption></figure>'
                     f'<figure><img src="images/{slug}-founder.png" alt="{name} Founder"><figcaption>Founder · paid edition</figcaption></figure>'
                     f'</div><p>1: {quote(price,1,bundle)/10**18:.8f} BNB · 3: {quote(price,3,bundle)/10**18:.8f} BNB · '
                     f'5: {quote(price,5,bundle)/10**18:.8f} BNB'
                     + (' · Five-for-four pilot' if bundle else ' · Flat per-NFT price') + '</p></section>')
    # One portable CAR archive containing all twenty real, independently addressable PNG blocks.
    header = car_header([cid for cid, _ in blocks])
    with (output / 'artwork.car').open('wb') as stream:
        stream.write(varint(len(header)) + header)
        for cid, raw in blocks:
            stream.write(varint(len(cid) + len(raw)) + cid + raw)
    manifest = dict(version='1.0.0', chainId=56, assetsVerified=False,
                    treasury='0x9BdC0913fD08d459BE910492cc9e6525fbd783c5',
                    agentRegistry='0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F',
                    contract='PublicPaidCollection', collections=rows)
    # Always reset the deployment gate before any network check; failure cannot preserve stale approval.
    dump(output / 'collections.json', manifest)
    dump(output / 'registry.pending.json', dict(chainId=56, collections=pending))
    if args.verify_online:
        if not args.gateway.startswith('https://'):
            raise ValueError('Verification gateway must use HTTPS')

        def verify(art):
            p = subprocess.run(['curl', '-fLsS', '--max-time', '45', args.gateway.rstrip('/') + '/' + art['uri'].removeprefix('ipfs://')],
                               capture_output=True, timeout=50)
            if p.returncode or hashlib.sha256(p.stdout).hexdigest() != art['sha256']:
                raise RuntimeError(f"Public image content unavailable or incorrect: {art['uri']}")
            return art['uri']

        with ThreadPoolExecutor(max_workers=4) as pool:
            verified = list(pool.map(verify, [art for row in rows for art in row['images'].values()]))
        manifest['assetsVerified'] = len(verified) == 20
        manifest['assetsVerifiedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        dump(output / 'collections.json', manifest)
    page = ('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>Public Paid Editions — Artwork Review</title><style>'
            '*{box-sizing:border-box}body{margin:0;background:#0a101b;color:#e9eef5;font:16px/1.5 system-ui,sans-serif}'
            'main{max-width:1160px;margin:auto;padding:48px 24px}h1{font-size:42px;letter-spacing:-1px}h2{font-size:28px;margin:0}'
            'small{color:#6fd1d4;font-size:15px}p{color:#adbbce}section{margin:44px 0 70px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}'
            'figure{margin:0;background:#141f31;border:1px solid #28384e;border-radius:16px;overflow:hidden}img{display:block;width:100%;height:auto}'
            'figcaption{padding:14px 18px;font-weight:600}aside{padding:20px;border:1px solid #375064;border-radius:12px}'
            '@media(max-width:600px){.pair{grid-template-columns:1fr}h1{font-size:32px}}</style><main>'
            '<p>AGENTIC NFT · NEW COLLECTION REVIEW</p><h1>Scout &amp; Founder editions</h1>'
            '<aside>Ten proposed collections. Twenty original AI-generated edition illustrations. Artwork is shared within each edition; '
            'each NFT has its own serial. Paid minting is public with repeat purchases allowed; Scout claims require a registered ID. '
            'This is a review package. No new contract has been deployed.</aside>' + ''.join(cards) + '</main></html>')
    (output / 'artwork-review.html').write_text(page, encoding='utf-8')
    print(json.dumps(dict(collections=len(rows), images=len(blocks), totalSupply=sum(r['maxSupply'] for r in rows),
                          assetsVerified=manifest['assetsVerified'], output=str(output)), indent=2))


if __name__ == '__main__':
    main()
