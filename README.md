# sudoswap AMM

An implementation of the AMM idea described [here](https://blog.0xmons.xyz/83017366310).

Things left to do:

- More tests to ensure math invariants hold
- More tests to ensure that role permissions work as intended
- More tests to ensure that idSet always tracks NFT IDs in/out (if missing enumerable)

Liquidity providers us `LSSVMPairFactory` to deploy a minimal proxy `LSSVMPair` for a specific NFT collection. From there, the deployed pool maintains its own ETH/NFT inventory. Users can then call the various `swap` functions on the pool to trade ETH/NFTs.

A Router (TBD) can allow splitting swaps across multiple LSSVMPairs.

An LSSVMPair can be ETH, NFT, or TRADE. The type refers to what the pool holds.
The LSSVMPair `swap` functions are named from the perspective of the end user. EX: `swapETHForAnyNFTs` means the caller is sending ETH and receiving NFTs.

In order to determine how many NFTs or ETH to give/receive, each LSSVMPair calls a bonding curve contract that conforms to the `ICurve` interface. Bonding curve contracts are pure; it is up to LSSVMPair to update its state and perform input/output validation.

See inline comments for more on swap/bonding curve logic.

If an LSSVMPair is created for an NFT collection that doesn't implement the ERC721Enumerable interface, we keep track of a set of IDs internally. This is to allow for swaps which are ID agnostic. This means we have to be careful when accounting for NFTs entering/exiting the pool--we need to update the id set at the same time.

# Built with DappTools Template

**Template repository for getting started quickly with DappTools**

![Github Actions](https://github.com/gakonst/dapptools-template/workflows/Tests/badge.svg)

## Building and testing

```sh
make
make test
```

## Deploying

Contracts can be deployed via the `make deploy` command. Addresses are automatically
written in a name-address json file stored under `out/addresses.json`.

We recommend testing your deployments and provide an example under [`scripts/test-deploy.sh`](./scripts/test-deploy.sh)
which will launch a local testnet, deploy the contracts, and do some sanity checks.

Environment variables under the `.env` file are automatically loaded (see [`.env.example`](./.env.example)).
Be careful of the [precedence in which env vars are read](https://github.com/dapphub/dapptools/tree/2cf441052489625f8635bc69eb4842f0124f08e4/src/dapp#precedence).

We assume `ETH_FROM` is an address you own and is part of your keystore.
If not, use `ethsign import` to import your private key.

See the [`Makefile`](./Makefile#25) for more context on how this works under the hood

We use Alchemy as a remote node provider for the Mainnet & Rinkeby network deployments.
You must have set your API key as the `ALCHEMY_API_KEY` enviroment variable in order to
deploy to these networks

### Mainnet

```
ETH_FROM=0x3538b6eF447f244268BCb2A0E1796fEE7c45002D make deploy-mainnet
```

### Rinkeby

```
ETH_FROM=0x3538b6eF447f244268BCb2A0E1796fEE7c45002D make deploy-rinkeby
```

### Custom Network

```
ETH_RPC_URL=<your network> make deploy
```

### Local Testnet

```
# on one terminal
dapp testnet
# get the printed account address from the testnet, and set it as ETH_FROM. Then:
make deploy
```

## Installing the toolkit

If you do not have DappTools already installed, you'll need to run the below
commands

### Install Nix

```sh
# User must be in sudoers
curl -L https://nixos.org/nix/install | sh

# Run this or login again to use Nix
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
```

### Install DappTools

```sh
curl https://dapp.tools/install | sh
```

## DappTools Resources

* [DappTools](https://dapp.tools)
    * [Hevm Docs](https://github.com/dapphub/dapptools/blob/master/src/hevm/README.md)
    * [Dapp Docs](https://github.com/dapphub/dapptools/tree/master/src/dapp/README.md)
    * [Seth Docs](https://github.com/dapphub/dapptools/tree/master/src/seth/README.md)
* [DappTools Overview](https://www.youtube.com/watch?v=lPinWgaNceM)
* [Awesome-DappTools](https://github.com/rajivpo/awesome-dapptools)
