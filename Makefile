# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

install: update npm solc

# dapp deps
update:; dapp update

# npm deps for linting etc.
npm:; yarn install

# install solc version
# example to install other versions: `make solc 0_8_2`
SOLC_VERSION := 0_8_10
solc:; nix-env -f https://github.com/dapphub/dapptools/archive/master.tar.gz -iA solc-static-versions.solc_${SOLC_VERSION}

# Build & test
build  :; forge build --optimize --optimize-runs 1000000
test   :; forge test --optimize --optimize-runs 1000000 # --ffi # enable if you need the `ffi` cheat code on HEVM
fuzz   :; forge test -v --optimize --optimize-runs 1000000
clean  :; forge clean
lint   :; yarn run lintm
estimate :; ./scripts/estimate-gas.sh ${contract}
size   :; ./scripts/contract-size.sh ${contract}
snapshot :; dapp snapshot
test-deploy :; ./scripts/test-deploy.sh

# Deployment helpers
deploy :; @./scripts/deploy.sh

# mainnet
deploy-mainnet: export ETH_RPC_URL = $(call network,mainnet)
deploy-mainnet: check-api-key deploy

# rinkeby
deploy-rinkeby: export ETH_RPC_URL = $(call network,rinkeby)
deploy-rinkeby: check-api-key deploy

check-api-key:
ifndef ALCHEMY_API_KEY
	$(error ALCHEMY_API_KEY is undefined)
endif

# Returns the URL to deploy to a hosted node.
# Requires the ALCHEMY_API_KEY env var to be set.
# The first argument determines the network (mainnet / rinkeby / ropsten / kovan / goerli)
define network
https://eth-$1.alchemyapi.io/v2/${ALCHEMY_API_KEY}
endef
