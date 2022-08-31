#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

# Deploy pair templates
BeaconAmmV1EnumerableETHAddr=$(deploy BeaconAmmV1EnumerableETH)
log "BeaconAmmV1EnumerableETH deployed at:" $BeaconAmmV1EnumerableETHAddr

BeaconAmmV1MissingEnumerableETHAddr=$(deploy BeaconAmmV1MissingEnumerableETH)
log "BeaconAmmV1MissingEnumerableETH deployed at:" $BeaconAmmV1MissingEnumerableETHAddr

BeaconAmmV1EnumerableERC20Addr=$(deploy BeaconAmmV1EnumerableERC20)
log "BeaconAmmV1EnumerableERC20 deployed at:" $BeaconAmmV1EnumerableERC20Addr

BeaconAmmV1MissingEnumerableERC20Addr=$(deploy BeaconAmmV1MissingEnumerableERC20)
log "BeaconAmmV1MissingEnumerableERC20 deployed at:" $BeaconAmmV1MissingEnumerableERC20Addr

# Deploy factory
BeaconAmmV1FactoryAddr=$(deploy BeaconAmmV1Factory $BeaconAmmV1EnumerableETHAddr $BeaconAmmV1MissingEnumerableETHAddr $BeaconAmmV1EnumerableERC20Addr $BeaconAmmV1MissingEnumerableERC20Addr $PROTOCOL_FEE_RECIPIENT $PROTOCOL_FEE_MULTIPLIER)
log "BeaconAmmV1Factory deployed at:" $BeaconAmmV1FactoryAddr

# Deploy router
BeaconAmmV1RouterAddr=$(deploy BeaconAmmV1Router $BeaconAmmV1FactoryAddr)
log "BeaconAmmV1Router deployed at:" $BeaconAmmV1RouterAddr

# Whitelist router in factory
send $BeaconAmmV1FactoryAddr "setRouterAllowed(address,bool)" $BeaconAmmV1RouterAddr true
log "Whitelisted router in factory"

# Deploy bonding curves
ExponentialCurveAddr=$(deploy ExponentialCurve)
log "ExponentialCurve deployed at:" $ExponentialCurveAddr

LinearCurveAddr=$(deploy LinearCurve)
log "LinearCurve deployed at:" $LinearCurveAddr

# Whitelist bonding curves in factory
send $BeaconAmmV1FactoryAddr "setBondingCurveAllowed(address,bool)" $ExponentialCurveAddr true
log "Whitelisted exponential curve in factory"
send $BeaconAmmV1FactoryAddr "setBondingCurveAllowed(address,bool)" $LinearCurveAddr true
log "Whitelisted linear curve in factory"

# Transfer factory ownership to admin
send $BeaconAmmV1FactoryAddr "transferOwnership(address)" $ADMIN
log "Transferred factory ownership to:" $ADMIN