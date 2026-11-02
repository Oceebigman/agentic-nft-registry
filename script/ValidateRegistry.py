#!/usr/bin/env python3
"""Validate registry copies and compare deployed metadata with BNB Chain."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--offline', action='store_true')
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument('--registry', type=Path)
    args = parser.parse_args()
    root = args.root
    source = args.registry or root / 'registry/collections.json'
    data = json.loads(source.read_text())
    if data.get('chainId') != 56:
        raise ValueError('Registry chain ID must be 56')
    collections = data['collections']
    if not collections:
        raise ValueError('Registry must not be empty')
    addresses = []
    deployed = []
    for c in collections:
        label = c['symbol']
        if c['status'] not in ('deployed', 'pending_deployment'):
            raise ValueError(f'{label}: invalid deployment status')
        if int(c['freeAllocation']) + int(c['paidAllocation']) != int(c['maxSupply']):
            raise ValueError(f'{label}: allocations do not add up to maxSupply')
        if any(int(c[k]) < 0 for k in ('freeAllocation', 'paidAllocation', 'priceWei')):
            raise ValueError(f'{label}: negative allocation or price')
        if c['status'] == 'pending_deployment':
            if c.get('contractAddress'):
                raise ValueError(f'{label}: pending entry has a contract address')
            continue
        address = c.get('contractAddress', '')
        if not re.fullmatch('0x[0-9a-fA-F]{40}', address):
            raise ValueError(f'{label}: invalid contract address')
        addresses.append(address.lower())
        deployed.append(c)
    if len(addresses) != len(set(addresses)):
        raise ValueError('Deployed contract addresses must be unique')
    # A ticker can be reused by distinct collections; addresses must remain unique.
    copy = root / 'site/registry/collections.json'
    if copy.exists() and json.loads(copy.read_text()) != data:
        raise ValueError('Site registry differs from source registry')
    print(f'Structure OK: {len(collections)} collections, {len(deployed)} deployed', flush=True)
    if args.offline:
        return
    cast = os.environ.get('CAST_BIN') or shutil.which('cast') or str(Path.home() / '.foundry/bin/cast')
    rpc = os.environ.get('BSC_RPC_URL', 'https://bsc-dataseed.bnbchain.org')

    def command(parts):
        p = subprocess.run([cast, *parts, '--rpc-url', rpc, '--rpc-timeout', '20'],
                           capture_output=True, text=True, timeout=30)
        if p.returncode:
            raise RuntimeError(p.stderr.strip())
        return p.stdout.strip()

    if int(command(['chain-id'])) != 56:
        raise ValueError('RPC is not BNB Smart Chain mainnet')

    def inspect(c):
        failures = []
        address = c['contractAddress']
        label = c['symbol'] + ' ' + address
        checks = [('name', 'name', 'string'), ('symbol', 'symbol', 'string')]
        adapter = c.get('mintAdapter')
        if adapter == 'the-future':
            checks += [('maxSupply', 'MAX_SUPPLY', 'uint256'),
                       ('freeAllocation', 'FREE_SUPPLY', 'uint256'),
                       ('paidAllocation', 'PAID_SUPPLY', 'uint256'),
                       ('priceWei', 'PAID_MINT_PRICE', 'uint256')]
        elif adapter == 'ai-shiba-inu':
            checks += [('maxSupply', 'MAX_SUPPLY', 'uint256'),
                       ('priceWei', 'MINT_PRICE', 'uint256')]
        elif adapter and adapter != 'public-paid-v1':
            return [f'{label}: unsupported mint adapter {adapter}']
        else:
            checks += [(k, k, 'uint256') for k in
                       ('maxSupply', 'freeAllocation', 'paidAllocation')]
            checks.append(('priceWei', 'mintPrice', 'uint256'))
            for key in ('freeLimitPerWallet', 'paidLimitPerWallet',
                        'freeLimitPerAgentId', 'paidLimitPerAgentId'):
                if key in c:
                    checks.append((key, key, 'uint256'))
            if c.get('agentIdRequired') or c.get('freeMintRequiresAgentId'):
                checks.append(('agentIdRegistry', 'agentRegistry', 'address'))
        if c.get('treasury'):
            checks.append(('treasury', 'treasury', 'address'))
        for key, getter, kind in checks:
            try:
                raw = command(['call', address, f'{getter}()({kind})'])
                actual = json.loads(raw) if kind == 'string' else (
                    int(raw.split()[0]) if kind == 'uint256' else raw.lower())
                expected = int(c[key]) if kind == 'uint256' else c[key]
                if kind == 'address':
                    expected = expected.lower()
                if actual != expected:
                    failures.append(f'{label}: {key}: registry={expected!r}, on-chain={actual!r}')
            except Exception as e:
                failures.append(f'{label}: {key}: {e}')
        print(('FAIL ' if failures else 'OK ') + label, flush=True)
        return failures

    with ThreadPoolExecutor(max_workers=4) as pool:
        failures = [error for group in pool.map(inspect, deployed) for error in group]
    if failures:
        raise ValueError('\n'.join(failures))
    print(f'On-chain metadata verified for {len(deployed)} collections.')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'Registry validation failed: {error}', file=sys.stderr)
        sys.exit(1)
