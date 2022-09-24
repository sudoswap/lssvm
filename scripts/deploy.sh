#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

# Deploy pair templates
BeaconAmmV1PairEnumerableETHAddr=$(deploy BeaconAmmV1PairEnumerableETH)
log "BeaconAmmV1PairEnumerableETH deployed at:" $BeaconAmmV1PairEnumerableETHAddr

BeaconAmmV1PairMissingEnumerableETHAddr=$(deploy BeaconAmmV1PairMissingEnumerableETH)
log "BeaconAmmV1PairMissingEnumerableETH deployed at:" $BeaconAmmV1PairMissingEnumerableETHAddr

BeaconAmmV1PairEnumerableERC20Addr=$(deploy BeaconAmmV1PairEnumerableERC20)
log "BeaconAmmV1PairEnumerableERC20 deployed at:" $BeaconAmmV1PairEnumerableERC20Addr

BeaconAmmV1PairMissingEnumerableERC20Addr=$(deploy BeaconAmmV1PairMissingEnumerableERC20)
log "BeaconAmmV1PairMissingEnumerableERC20 deployed at:" $BeaconAmmV1PairMissingEnumerableERC20Addr

# Deploy factory
BeaconAmmV1PairFactoryAddr=$(deploy BeaconAmmV1PairFactory $BeaconAmmV1PairEnumerableETHAddr $BeaconAmmV1PairMissingEnumerableETHAddr $BeaconAmmV1PairEnumerableERC20Addr $BeaconAmmV1PairMissingEnumerableERC20Addr $PROTOCOL_FEE_RECIPIENT $PROTOCOL_FEE_MULTIPLIER)
log "BeaconAmmV1PairFactory deployed at:" $BeaconAmmV1PairFactoryAddr

# Deploy router
BeaconAmmV1RouterAddr=$(deploy BeaconAmmV1Router $BeaconAmmV1PairFactoryAddr)
log "BeaconAmmV1Router deployed at:" $BeaconAmmV1RouterAddr

# Whitelist router in factory
send $BeaconAmmV1PairFactoryAddr "setRouterAllowed(address,bool)" $BeaconAmmV1RouterAddr true
log "Whitelisted router in factory"

# Deploy bonding curves
ExponentialCurveAddr=$(deploy ExponentialCurve)
log "ExponentialCurve deployed at:" $ExponentialCurveAddr

LinearCurveAddr=$(deploy LinearCurve)
log "LinearCurve deployed at:" $LinearCurveAddr

# Whitelist bonding curves in factory
send $BeaconAmmV1PairFactoryAddr "setBondingCurveAllowed(address,bool)" $ExponentialCurveAddr true
log "Whitelisted exponential curve in factory"
send $BeaconAmmV1PairFactoryAddr "setBondingCurveAllowed(address,bool)" $LinearCurveAddr true
log "Whitelisted linear curve in factory"

# Deploy royalty manager
BeaconAmmV1RoyaltyManagerAddr=$(deploy BeaconAmmV1RoyaltyManager $BeaconAmmV1PairFactoryAddr)
log "BeaconAmmV1RoyaltyManager deployed at:" $BeaconAmmV1RoyaltyManagerAddr

# Add royalty manager in factory
send $BeaconAmmV1PairFactoryAddr "setRoyaltyManager(address)" $BeaconAmmV1RoyaltyManagerAddr
log "Added royalty manager in factory"

# Transfer factory ownership to admin
send $BeaconAmmV1PairFactoryAddr "transferOwnership(address)" $ADMIN
log "Transferred factory ownership to:" $ADMIN
