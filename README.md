# foundry-deployment-kit

The collections of smart contracts that support writing deployment scripts.

## Development

### Requirement

- [Foundry forge@^0.2.0](https://book.getfoundry.sh/)

### Build & Test

- Install packages

```shell
$ forge install
```

- Build contracts

```shell
$ forge build
```

- Run test

```shell
$ forge test
```

### Script usage (native-lite)

Scripts run through `ScriptExtended.run(bytes,string)`. Use the wrapper scripts for convenience:

```shell
$ ./run.sh script/examples/ExampleDeploySample.s.sol --network ronin-testnet -- --rpc-url <url>
$ ./broadcast.sh script/examples/ExampleDeploySample.s.sol --network ronin-testnet -- --rpc-url <url> --private-key <pk>
$ ./run.sh script/examples/ExampleReadDeployment.s.sol --network ronin-testnet -- --rpc-url <url>
```

Proxy upgrade example (requires `PROXY_ADMIN`):

```shell
$ PROXY_ADMIN=<admin> ./broadcast.sh script/examples/ExampleProxyUpgrade.s.sol --network ronin-testnet -- --rpc-url <url> --private-key <pk>
```

Direct `forge` invocation:

```shell
$ forge script script/examples/ExampleDeploySample.s.sol --sig "run(bytes,string)" $(cast calldata "run()") "network.ronin-testnet" --rpc-url <url>
```