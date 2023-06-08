#!/usr/bin/env bash

if [ -f .env ]
then
  export $(cat .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

echo "Please enter the chain id..."
read chain_id

echo ""

echo "Please enter the deployed CrossMarginPhysicalEngine address..."
read cmpe

echo ""

echo "Please enter the CrossMarginPhysicalLib address..."
read lib

echo ""

echo "Please enter the CrossMarginPhysicalMath address..."
read math

echo ""

echo "Verifying CrossMarginPhysicalEngine contract on Etherscan..."

forge verify-contract \
  $cmpe \
  ./src/settled-physical/CrossMarginPhysicalEngine.sol:CrossMarginPhysicalEngine \
  --etherscan-api-key ${ETHERSCAN_API_KEY} \
  --chain-id $chain_id \
  --compiler-version 0.8.17+commit.8df45f5f \
  --num-of-optimizations 10000 \
  --constructor-args-path script/cross-margin-physical-engine/constructor-args-cmpe.txt \
  --libraries src/settled-physical/CrossMarginPhysicalLib.sol:CrossMarginPhysicalLib:$lib \
  --libraries src/settled-physical/CrossMarginPhysicalMath.sol:CrossMarginPhysicalMath:$math \
  --watch