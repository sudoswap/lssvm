#!/usr/bin/env bash

set -eo pipefail

OUT_DIR=${OUT_DIR:-$PWD/out}
export CONTRACTS_FILE="$OUT_DIR/addresses.json"
export ADDRESSES_FILE="$OUT_DIR/addresses_extra.json"

# import the deployment helpers
. $(dirname $0)/common.sh

export LSSVMRouterAddr="${LSSVMRouterAddr:-$(jq -r .LSSVMRouter $CONTRACTS_FILE)}"
export LSSVMPairFactoryAddr="${LSSVMPairFactoryAddr:-$(jq -r .LSSVMPairFactory $CONTRACTS_FILE)}"

# Deploy tokens

# ERC20
Test20Addr=$(deploy Test20)
log "Test20 deployed at:" $Test20Addr

send $Test20Addr "mint(address,uint256)" $ETH_FROM 1000000000000000000000000 # 100M
log "100M T20 ($Test20Addr) minted for $ETH_FROM"

# Test721BatchMintWithRoyalty
Test721Addr=$(deploy Test721BatchMintWithRoyalty ${ROYALTY_RECIPIENT:-$ETH_fROM} 0 100000000000000) # flat, 0.0001 ETH
log "Test721 deployed at:" $Test721Addr

send $Test721Addr "batchMint(address,uint256[])" $ETH_FROM "[$(seq -s ',' 0 99)]"

# Test721EnumerableBatchMintWithRoyalty
Test721EnumerableAddr=$(deploy Test721EnumerableBatchMintWithRoyalty ${ROYALTY_RECIPIENT:-$ETH_fROM} 1 10000000000000000) # percent, 0.01 * salePrice ETH
log "Test721Enumerable deployed at:" $Test721EnumerableAddr

send $Test721EnumerableAddr "batchMint(address,uint256[])" $ETH_FROM "[$(seq -s ',' 0 99)]"

# Deploy routerWithRoyalties
LSSVMRouterWithRoyaltiesAddr=$(deploy LSSVMRouterWithRoyalties $LSSVMPairFactoryAddr)
log "LSSVMRouterWithRoyalties deployed at:" $LSSVMRouterWithRoyaltiesAddr

# Whitelist routerWithRoyalties in factory
send $LSSVMPairFactoryAddr "setRouterAllowed(address,bool)" $LSSVMRouterWithRoyaltiesAddr true
log "Whitelisted routerWithRoyalties in factory"