<div align="center">
  <h1> Cross Margin Engine </h1>

  <img height=60 src="https://i.imgur.com/vSIO8xJ.png"/>
  <br/>
  <br/>
  <a href="https://github.com/foundry-rs/foundry"><img src="https://img.shields.io/static/v1?label=foundry-rs&message=foundry&color=blue&logo=github"/></a>
  <a href=https://github.com/cross-margin-engine/actions/workflows/CI.yml""><img src="https://github.com/grappafinance/cross-margin-engine/actions/workflows/CI.yml/badge.svg?branch=master"> </a>
  <a href="https://codecov.io/gh/grappafinance/cross-margin-engine" >
<img src="https://codecov.io/gh/grappafinance/cross-margin-engine/branch/master/graph/badge.svg?token=9M0382HKTQ"/>
</a>


</div>


## Get Started

```shell
forge build
forge test
```

For auto linting and running gas snapshot, you will also need to setup npm environment, and install husky hooks

```shell
# install yarn dependencies
yarn
# install hooks
npx husky install
```

### Test locally

```shell
forge test
```

### Run Coverage

```shell
forge coverage
```

### Linting

```shell
forge fmt
```

## Run Slither

installation

```shell
pip3 install slither-analyzer
pip3 install solc-select
solc-select install 0.8.13
solc-select use 0.8.13
```

Run analysis

```shell
slither ./src/core/
```