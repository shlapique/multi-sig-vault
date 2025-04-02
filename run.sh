#!/bin/bash
. .env
forge script script/Deploy.s.sol:DeployMultiSig --broadcast \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY_1 | grep MultiSig \
  | awk '{print $4}' | xargs -I {} sh -c \
  'if grep -q "^MS=" .env; then sed -i "s/^MS=.*/MS={}/" .env; else echo "MS={}" >> .env; fi'
