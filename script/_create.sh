#!/usr/bin/env bash

# ./create.sh src/core/WhitelistManager.sol:WhitelistManager

if [ -f .env ]
then
  export $(cat .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

ARGS=""

echo "Please enter the network name..."
read network

echo ""

echo "Verify contract? [y/n]..."
read verify

echo ""

ARGS="-i"
ARGS="$ARGS --rpc-url https://$network.infura.io/v3/$INFURA_API_KEY"
ARGS="$ARGS --private-key $PRIVATE_KEY"

if [ "$verify" = "y" ]
then
  ARGS="$ARGS --verify"
fi

echo "Running create: $1"
echo "Arguments: $ARGS"

forge create $1 $ARGS

echo "Create ran successfully 🎉🎉🎉"