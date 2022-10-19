# beaconAMM-v1

First version of the BeaconAMM. Forked from [sudoswap](https://github.com/sudoswap/lssvm/tree/9e8ee80f60682b8f3f73163f1870ff28f7e07668).

Liquidity providers use `BeaconAmmV1PairFactory` to deploy a modified minimal proxy `BeaconAmmV1Pair` for a specific NFT collection. From there, the deployed pool maintains its own TOKEN/NFT inventory. Users can then call the various `swap` functions on the pool to trade TOKEN/NFTs.

`BeaconAmmV1Pair`s are either `BeaconAmmV1PairEnumerable` or `BeaconAmmV1PairMissingEnumerable` depending on whether or not the pair's `ERC721` contract supports `Enumerable` or not. If it doesn't, we implement our own ID set to allow for easy access to NFT IDs in the pool.

For the actual token, NFTs are paired either with an `ERC20` or `ETH`, so there are 4 types of pairs:

* Missing Enumerable | ETH
* Missing Enumerable | ERC20
* Enumerable | ETH
* Enumerable | ERC20

The `BeaconAmmV1Router` allows splitting swaps across multiple `BeaconAmmV1Pair`s to purchase and sell multiple NFTs in one call.

An `BeaconAmmV1Pair` can be TOKEN, NFT, or TRADE.
The type refers to what the pool holds:
- a TOKEN pool has tokens that it is willing to give to traders in exchange for NFTs
- an NFT pool has NFTs that it is willing to give to traders in exchange for tokens
- a TRADE pools allow for both TOKEN-->NFT and NFT-->TOKEN swaps.

The `BeaconAmmV1Pair` `swap` functions are named from the perspective of the end user. EX: `swapTokenForAnyNFTs` means the caller is sending ETH and receiving NFTs.

In order to determine how many NFTs or tokens to give or receive, each `BeaconAmmV1Pair` calls a discrete bonding curve contract that conforms to the `ICurve` interface. Bonding curve contracts are intended to be pure; it is the responsibility of `BeaconAmmV1Pair` to update its state and perform input/output validation.

See inline comments for more on swap/bonding curve logic.

### Architecture

See the diagram below for a high-level overview, credits go to [IT DAO](https://twitter.com/InfoTokenDAO):

![overview of beaconAMM architecture](./diagram.png)

### Testing
To help with code reuse, `base` contains actual swap logic to be tested in the form of abstract contracts, while actual test files inherit from various parent contracts found in `mixins` to implement the different choices of bonding curve, NFT, or token.

`testgen-scripts` contains a Python script used to generate all combinations of bonding curve, NFT, and token for each test in `base`. They are then placed into `test-cases`, which are the actual test files that get run.

Test files are prefixed with a shortened name of the base test they implememnt (e.g. NoArb for NoArbBondingCurve), which is then followed by the specific bonding curve type, then NFT type, then token type, e.g. `NoArbLinearMissingEnumerableETH`.

Our testing setup is compatible with both `forge` and `dapptools`. We recommend `forge` as it is significantly faster to run.

---

# Built with DappTools Template

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

We use Infura as a remote node provider for the Mainnet & Goerli network deployments.
You must have set your API key as the `INFURA_API_KEY` enviroment variable in order to
deploy to these networks

## Deployments

### Goerli

{
  "DEPLOYER": "0x1277057C301c120aeC09Cf1a47eEf59993fA6F56",
  "BeaconAmmV1PairEnumerableETH": "0x6f08339AEFA011872E32D89Ab03B67EEB9ee20A0",
  "BeaconAmmV1PairMissingEnumerableETH": "0xDcEb908CA98483bCa04f00f45CA8518105fD5DC9",
  "BeaconAmmV1PairEnumerableERC20": "0x7EA65Fb3D49299308C0D69D81f94129823B8092C",
  "BeaconAmmV1PairMissingEnumerableERC20": "0xa0717e113275cbe5666299649D36a48625C70108",
  "BeaconAmmV1PairFactory": "0x5e703991f17Cb8196E7aB682446e7D8a911Bf869",
  "BeaconAmmV1Router": "0xceA94a45895eCcBc38Cf44faC2148912F3BF0873",
  "ExponentialCurve": "0x993d49b33A47D7791720C73d4B707FDcD9a8d497",
  "LinearCurve": "0xc1410471fB65F7152B170a6328031CAbcD5d8BF8",
  "BeaconAmmV1RoyaltyManager": "0xb1a05b4dceded5e37ab2b2c45b9a3b50f8603448"
}
