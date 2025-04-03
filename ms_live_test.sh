#!/bin/bash
. .env

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

color_print() {
    local color=$1
    local indent=$2
    local message=$3
    local value=${4:-}
    
    printf "${color}%${indent}s${message}${NC}${value}\n"
}

parse_transaction() {
    local tx_data=$1
    local -n __to=$2
    local -n __value=$3
    local -n __executed=$4
    local -n __confirmations=$5
    
    IFS=',' read -ra parts <<< "${tx_data//[()]/}"
    
    __to=${parts[0]}
    __value=${parts[1]}
    __executed=${parts[2]}
    __confirmations=${parts[3]}
}

color_print $BLUE 0 "[0/5] Funding MultiSig..."
cast send $CR --value 10ether --rpc-url $RPC_URL --private-key $PRIVATE_KEY_1 > /dev/null

# 1. Normal flow
color_print $BLUE 0 "\n[1/5] Testing Auto-Execution Flow..."
color_print $CYAN 2 "Submitting transaction..."
cast send $CR "submitTransaction(address,uint256,bytes)" $NON_OWNER 1ether 0x --rpc-url $RPC_URL --private-key $PRIVATE_KEY_1 > /dev/null

color_print $CYAN 2 "First confirmation (should not execute yet)..."
cast send $CR "confirmTransaction(uint256)" 0 --rpc-url $RPC_URL --private-key $PRIVATE_KEY_2 > /dev/null

color_print $CYAN 2 "Second confirmation (should auto-execute)..."
cast send $CR "confirmTransaction(uint256)" 0 --rpc-url $RPC_URL --private-key $PRIVATE_KEY_3 > /dev/null

color_print $GREEN 2 "Balance after transfer:" "$(cast balance $NON_OWNER --rpc-url $RPC_URL)"

# 2. Security test
color_print $BLUE 0 "\n[2/5] Testing Non-Owner Attempt..."
color_print $CYAN 2 "Attempting non-owner confirmation:"
cast send $CR "confirmTransaction(uint256)" 0 --rpc-url $RPC_URL --private-key $PRIVATE_KEY_NON_OWNER > /dev/null 2>&1 || color_print $RED 2 "Expected revert - Not owner"

# 3. Double confirmation attempt
color_print $BLUE 0 "\n[3/5] Testing Double Confirmation..."
color_print $CYAN 2 "Submitting new tx..."
cast send $CR "submitTransaction(address,uint256,bytes)" $NON_OWNER 0.5ether 0x --rpc-url $RPC_URL --private-key $PRIVATE_KEY_1 > /dev/null

color_print $CYAN 2 "First confirmation..."
cast send $CR "confirmTransaction(uint256)" 1 --rpc-url $RPC_URL --private-key $PRIVATE_KEY_2 > /dev/null

color_print $CYAN 2 "Attempting same confirmation again:"
cast send $CR "confirmTransaction(uint256)" 1 --rpc-url $RPC_URL --private-key $PRIVATE_KEY_2 > /dev/null 2>&1 || color_print $RED 2 "Expected revert - Already confirmed"

# 4. Fixed Threshold edge case test
color_print $BLUE 0 "\n[4/5] Testing Threshold Edge Case..."
threshold=$(cast call $CR "threshold()(uint256)" --rpc-url $RPC_URL)
color_print $YELLOW 2 "Current threshold:" "$threshold"

color_print $CYAN 2 "Submitting tx with 1/3 threshold..."
cast send $CR "submitTransaction(address,uint256,bytes)" $NON_OWNER 0.1ether 0x --rpc-url $RPC_URL --private-key $PRIVATE_KEY_1 > /dev/null

color_print $CYAN 2 "Single confirmation (should NOT execute)..."
cast send $CR "confirmTransaction(uint256)" 2 --rpc-url $RPC_URL --private-key $PRIVATE_KEY_2 > /dev/null

# 
tx_data=$(cast call $CR "getTransaction(uint256)(address,uint256,bool,uint256)" 2 --rpc-url $RPC_URL)
parse_transaction "$tx_data" to value executed confirmations

color_print $YELLOW 2 "Recipient:" "$to"
color_print $YELLOW 2 "Value:" "$(echo "scale=18; $value / 10^18" | bc) ETH"
color_print $YELLOW 2 "Executed:" "$executed"
color_print $YELLOW 2 "Confirmations:" "$confirmations"

if [[ $executed == "true" || $confirmations -ne 1 ]]; then
  color_print $RED 2 "TEST FAILED: Transaction should be pending!"
else
  color_print $GREEN 2 "TEST PASSED: Transaction correctly pending"
fi

# 5. Failed execution check
color_print $BLUE 0 "\n[5/5] Testing Failed Execution..."
color_print $CYAN 2 "Submitting tx to invalid address..."
cast send $CR "submitTransaction(address,uint256,bytes)" 0x000000000000000000000000000000000000dEaD 1ether 0x --rpc-url $RPC_URL --private-key $PRIVATE_KEY_1 > /dev/null

color_print $CYAN 2 "Confirming (should revert on execute)..."
cast send $CR "confirmTransaction(uint256)" 3 --rpc-url $RPC_URL --private-key $PRIVATE_KEY_2 > /dev/null
cast send $CR "confirmTransaction(uint256)" 3 --rpc-url $RPC_URL --private-key $PRIVATE_KEY_3 > /dev/null 2>&1 || color_print $RED 2 "Expected revert - Call failed"

color_print $GREEN 0 "\nAll tests completed!"
