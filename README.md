
## Uniswap Nezlobin Hook

> Trying to implement Nezlobin hook approach for dynamic fee.




### Reference of potential existing implementation
- https://github.com/heypran/v4-dynamic-fee/blob/main/src/DirectionalFee.sol
- https://github.com/Jaseempk/NZ-Directional-Fee/blob/main/src/NezlobinDirectionalFee.sol
- https://github.com/Emirhan-Cavusoglu-sftw/CrossLink/blob/main/backend/src/Nezlobin.sol



## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
