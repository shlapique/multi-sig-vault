#!/bin/bash

. .env

# fund MultiSig 
cast send $CR --value 10ether --rpc-url $RPC_URL --private-key $PRIVATE_KEY_1

# normal flow
echo -e "\n\033[1;34m[1/4] Testing Auto-Execution Flow...\033[0m"
echo "Submitting transaction..."
cast send $CR "submitTransaction(address,uint256,bytes)" $NON_OWNER 1ether 0x --rpc-url $RPC_URL --private-key $PRIVATE_KEY_1

echo "First confirmation (should not execute yet)..."
cast send $CR "confirmTransaction(uint256)" 0 --rpc-url $RPC_URL --private-key $PRIVATE_KEY_2

echo "Second confirmation (should auto-execute)..."
cast send $CR "confirmTransaction(uint256)" 0 --rpc-url $RPC_URL --private-key $PRIVATE_KEY_3

echo "Balance after transfer: $(cast balance $NON_OWNER --rpc-url $RPC_URL)"

# security test
echo -e "\n\033[1;34m[2/4] Testing Non-Owner Attempt...\033[0m"
echo "Attempting non-owner confirmation:"
cast send $CR "confirmTransaction(uint256)" 0 --rpc-url $RPC_URL --private-key $PRIVATE_KEY_NON_OWNER || echo "✅ Expected revert - Not owner"
