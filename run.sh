#!/bin/bash
. .env
forge script script/Deploy.s.sol:DeployMultiSig --broadcast \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY_1 | grep "@Proxy@" \
  | awk '{print $4}' | xargs -I {} sh -c \
  'if grep -q "^CR=" .env; then sed -i "s/^CR=.*/CR={}/" .env; else echo "CR={}" >> .env; fi'
