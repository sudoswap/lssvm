#!/usr/bin/env bash

set -eo pipefail

OUT_DIR=${OUT_DIR:-$PWD/out}
export CONTRACTS_FILE="$OUT_DIR/addresses.json"
export ADDRESSES_FILE="$OUT_DIR/addresses_extra.json"

# import the deployment helpers
. $(dirname $0)/common.sh

export LSSVMPairFactoryAddr="${LSSVMPairFactoryAddr:-$(jq -r .LSSVMPairFactory $CONTRACTS_FILE)}"

# Deploy Router (but not whitelist it in Factory)
LSSVMRouterFakeAddr=$(deploy LSSVMRouter $LSSVMPairFactoryAddr)
log "LSSVMRouterFake deployed at:" $LSSVMRouterFakeAddr

# Deploy test tokens
Test20Addr=$(deploy Test20)
log "Test20 deployed at:" $Test20Addr

send $Test20Addr "mint(address,uint256)" $ETH_FROM 1000000000000000000000000 # 100M
log "100M T20 ($Test20Addr) minted for $ETH_FROM"

Test721Addr=$(deploy Test721)
log "Test721 deployed at:" $Test721Addr

for i in $(seq 0 49); do
    send $Test721Addr "mint(address,uint256)" $ETH_FROM "$i"
done

Test721EnumerableAddr=$(deploy Test721Enumerable)
log "Test721Enumerable deployed at:" $Test721EnumerableAddr

for i in $(seq 0 49); do
    send $Test721EnumerableAddr "mint(address,uint256)" $ETH_FROM "$i"
done