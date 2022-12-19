# Installation

## Requirements
`make`, `node`, `npm`, `yarn`, `jq`

### Install Forge
https://github.com/foundry-rs/foundry/blob/master/README.md

Requires: `curl` and `git`

### Install Nix
https://nixos.org/download.html

Requires: `xz-utils`

Choose single user installation for simplicity.


### Install Dapptools
https://github.com/dapphub/dapptools


### Preparation
### Local RPC Node

We recommend you to use `anvil` that comes with foundry during forge installation. Create a fork of mainnet and deploy a local node.

```bash
anvil \
    --fork-url https://rpc.ankr.com/eth \
    --chain-id 31337 \
    --block-time 3 \
    --block-base-fee-per-gas 1000000000
```
It will list default wallets that has balances. You can import one of them into your keystore and use it as a deployer to deploy contracts.

Please make sure your wallet is in you keystore. If you have to import a private key string, use the `ethsign` command.
```
ethsign import
```
Make sure that you set a passphrase and save the passphrase to a `password.txt` file in the root of this project directory.


Once these packages are installed, please copy `.env.local` into `.env`. And set your preferred wallet address and keystores.
```
export ETH_RPC_URL=http://127.0.0.1:8545
export ETH_FROM=[YOUR_ADDRESS_IN_KEYSTORE] # wallet address of $ETH_KEYSTORE_FILE specified below
export ADMIN=[ADDRESS_FOR_ADMIN_ACCESS]    # wallet address to set as admin, set it to the same value as $ETH_FROM for convenience
export PROTOCOL_FEE_RECIPIENT=[PROTOCOL_FEE_RECIPIENT_ADDRESS] # wallet address to set as protocol fee recipient, set it to the same value as $ETH_FROM for convenience
export PROTOCOL_FEE_MULTIPLIER=0           # set protocol fee to 0
export LEGACY_TX=true
export ETH_GAS_PRICE=1000000000
export ETH_KEYSTORE=/home/[YOUR_USERNAME]/.ethereum/keystore      # your keystore directory used by ethsign/seth commands, should contain your $ETH_KEYSTORE_FILE
export ETH_PASSWORD=password.txt                                  # passphrase of your $ETH_KEYSTORE_FILE wallet
export ETH_KEYSTORE_FILE=/home/[YOUR_USERNAME]/.ethereum/keystore/UTC--****--[YOUR_WALLET_ADDRESS]
export ROYALTY_RECIPIENT=[YOUR_ROYALTY_RECIPIENT_ADDRESS] # Royalty recipient for Test NFTs
```

## Deployment

### Contracts
```
make
make build
make deploy
```

Once deployed, all the addresses are saved in `out/addresses.json` file.

### Fake Router and Test tokens (ERC20, ERC721, ERC721Enumerable)
```
make deploy_extra
```
Once deployed, all token and router addresses are saved in `out/addresses_extra.json` file. This should be executed after contracts deployment above.