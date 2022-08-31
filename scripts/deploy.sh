#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

# Deploy pair templates
LSSVMPairEnumerableETHAddr=$(deploy LSSVMPairEnumerableETH)
log "LSSVMPairEnumerableETH deployed at:" $LSSVMPairEnumerableETHAddr

LSSVMPairMissingEnumerableETHAddr=$(deploy LSSVMPairMissingEnumerableETH)
log "LSSVMPairMissingEnumerableETH deployed at:" $LSSVMPairMissingEnumerableETHAddr

LSSVMPairEnumerableERC20Addr=$(deploy LSSVMPairEnumerableERC20)
log "LSSVMPairEnumerableERC20 deployed at:" $LSSVMPairEnumerableERC20Addr

LSSVMPairMissingEnumerableERC20Addr=$(deploy LSSVMPairMissingEnumerableERC20)
log "LSSVMPairMissingEnumerableERC20 deployed at:" $LSSVMPairMissingEnumerableERC20Addr

# Deploy factory
LSSVMPairFactoryAddr=$(deploy LSSVMPairFactory $LSSVMPairEnumerableETHAddr $LSSVMPairMissingEnumerableETHAddr $LSSVMPairEnumerableERC20Addr $LSSVMPairMissingEnumerableERC20Addr $PROTOCOL_FEE_RECIPIENT $PROTOCOL_FEE_MULTIPLIER)
log "LSSVMPairFactory deployed at:" $LSSVMPairFactoryAddr

# Deploy router
LSSVMRouterAddr=$(deploy LSSVMRouter $LSSVMPairFactoryAddr)
log "LSSVMRouter deployed at:" $LSSVMRouterAddr

# Whitelist router in factory
send $LSSVMPairFactoryAddr "setRouterAllowed(address,bool)" $LSSVMRouterAddr true
log "Whitelisted router in factory"

# Deploy bonding curves
ExponentialCurveAddr=$(deploy ExponentialCurve)
log "ExponentialCurve deployed at:" $ExponentialCurveAddr

LinearCurveAddr=$(deploy LinearCurve)
log "LinearCurve deployed at:" $LinearCurveAddr

# Whitelist bonding curves in factory
send $LSSVMPairFactoryAddr "setBondingCurveAllowed(address,bool)" $ExponentialCurveAddr true
log "Whitelisted exponential curve in factory"
send $LSSVMPairFactoryAddr "setBondingCurveAllowed(address,bool)" $LinearCurveAddr true
log "Whitelisted linear curve in factory"

# Transfer factory ownership to admin
send $LSSVMPairFactoryAddr "transferOwnership(address)" $ADMIN
log "Transferred factory ownership to:" $ADMIN