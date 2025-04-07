#!/bin/bash
. .env
forge script script/Deploy.s.sol:Deploy --broadcast \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY_1 | grep "@Factory@" \
  | awk '{print $4}' | xargs -I {} sh -c \
  'if grep -q "^FACTORY=" .env; then sed -i "s/^FACTORY=.*/FACTORY={}/" .env; else echo "FACTORY={}" >> .env; fi'
