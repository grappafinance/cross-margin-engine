#!/usr/bin/env bash

if [ -f .env ]
then
  export $(cat .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

echo "Please enter the network name..."
read network

echo ""

if [ -f ./script/.$network ]
then
  export $(cat ./script/.$network | xargs)
else
    echo "Please set your .$network file"
    exit 1
fi

echo "Broadcast? [y/n]..."
read broadcast

echo ""

echo "Verify contract? [y/n]..."
read verify

echo ""

echo "Profile? [default/optimized]..."
read profile

if [ "$profile" = "default" ] || [ "$profile" = "optimized" ]; then
  export FOUNDRY_PROFILE=$profile
  echo ""
  echo "Using profile: $FOUNDRY_PROFILE"
  echo ""
else
  echo ""
  echo "Invalid profile! 🛑🛑🛑"
  exit 0
fi

ARGS="--rpc-url https://$network.infura.io/v3/$INFURA_API_KEY"
ARGS="$ARGS --private-key $PRIVATE_KEY"

if [ "$broadcast" = "y" ]
then
  ARGS="$ARGS --broadcast"
fi

if [ "$verify" = "y" ]
then
  ARGS="$ARGS --verify"
fi

forge create \
  ./src/settled-physical/CrossMarginPhysicalEngineProxy.sol:CrossMarginPhysicalEngineProxy \
  -i \
  --constructor-args-path script/cross-margin-physical-engine/constructor-args-proxy.txt \
  $ARGS

echo ""

echo "CrossMarginPhysicalEngineProxy deployed successfully 🎉🎉🎉"