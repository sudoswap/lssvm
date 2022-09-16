# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

install: update npm solc

# deps
update:; forge update

# npm deps for linting etc.
npm:; yarn install

# install solc version
# example to install other versions: `make solc 0_8_2`
SOLC_VERSION := 0_8_13
solc:; nix-env -f https://github.com/dapphub/dapptools/archive/master.tar.gz -iA solc-static-versions.solc_${SOLC_VERSION}

# Build & test
build  :; forge build --optimize
test   :; forge test --optimize
fuzz   :; forge test -v --optimize
clean  :; forge clean
lint   :; yarn run lint
estimate :; ./scripts/estimate-gas.sh ${contract}
size   :; ./scripts/contract-size.sh ${contract}
snapshot :; forge snapshot --optimize
test-deploy :; ./scripts/test-deploy.sh

# Deployment helpers
deploy :; @./scripts/deploy.sh

# mainnet
deploy-mainnet: export ETH_RPC_URL = $(call network,mainnet)
deploy-mainnet: check-api-key deploy

# goerli
deploy-goerli: export ETH_RPC_URL = $(call network,goerli)
deploy-goerli: check-api-key deploy

check-api-key:
ifndef INFURA_API_KEY
	$(error INFURA_API_KEY is undefined)
endif

# Returns the URL to deploy to a hosted node.
# Requires the INFURA_API_KEY env var to be set.
# The first argument determines the network (mainnet / goerli)
define network
https://goerli.infura.io/v3/${INFURA_API_KEY}
endef
