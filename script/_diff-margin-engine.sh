#!/usr/bin/env bash

echo "Type? [Cash/Physical]..."
read type

if [ "$type" = "Cash" ] || [ "$type" = "Physical" ]; then
  echo ""
else
  echo ""
  echo "Invalid Type! 🛑🛑🛑"
  exit 0
fi

echo "Deployed Commit?..."
read deployed

echo ""

echo "Current Commit?..."
read current

echo ""

git diff $deployed $current -- src/settled-${type,,}/CrossMargin${type}Engine.sol src/settled-${type,,}/CrossMargin${type}Lib.sol src/settled-${type,,}/CrossMargin${type}Math.sol