#!/bin/bash
. .env

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

declare -i TEST_RESULT=0
declare -a TEST_FAILURES=()
declare -a TEST_SUCCESSES=()

color_print() {
    printf "${1}%${2}s${3}${NC}${4}\n"
}

log_test_result() {
    local test_name=$1
    local success=$2
    local message=$3
    
    if [ $success -eq 0 ]; then
        TEST_SUCCESSES+=("$test_name")
        color_print $GREEN 2 "✓ $message"
    else
        TEST_RESULT=1
        TEST_FAILURES+=("$test_name")
        color_print $RED 2 "✗ $message"
    fi
}

color_print $BLUE 0 "[0/5] Funding MultiSig..."
cast send $CR --value 10ether --rpc-url $RPC_URL --private-key $PRIVATE_KEY_1 > /dev/null

color_print $BLUE 0 "\n[1/5] Testing Auto-Execution Flow..."
color_print $CYAN 2 "Submitting transaction..."
cast send $CR "submitTransaction(address,uint256,bytes)" $NON_OWNER 1ether 0x --rpc-url $RPC_URL --private-key $PRIVATE_KEY_1 > /dev/null

color_print $CYAN 2 "First confirmation..."
cast send $CR "confirmTransaction(uint256)" 0 --rpc-url $RPC_URL --private-key $PRIVATE_KEY_2 > /dev/null

color_print $CYAN 2 "Second confirmation..."
cast send $CR "confirmTransaction(uint256)" 0 --rpc-url $RPC_URL --private-key $PRIVATE_KEY_3 > /dev/null

balance=$(cast balance $NON_OWNER --rpc-url $RPC_URL)
color_print $GREEN 2 "Balance after transfer:" "$balance"

if [[ $(echo "$balance > 0" | bc) -eq 1 ]]; then
    log_test_result "Auto-Execution" 0 "Transaction executed successfully"
else
    log_test_result "Auto-Execution" 1 "Transaction failed to execute"
fi

color_print $BLUE 0 "\n[2/5] Testing Non-Owner Attempt..."
color_print $CYAN 2 "Attempting non-owner confirmation:"
if cast send $CR "confirmTransaction(uint256)" 0 --rpc-url $RPC_URL --private-key $PRIVATE_KEY_NON_OWNER > /dev/null 2>&1; then
    log_test_result "Non-Owner" 1 "Non-owner confirmation should have failed"
else
    log_test_result "Non-Owner" 0 "Non-owner confirmation correctly reverted"
fi

color_print $BLUE 0 "\n[3/5] Testing Double Confirmation..."
color_print $CYAN 2 "Submitting new tx..."
cast send $CR "submitTransaction(address,uint256,bytes)" $NON_OWNER 0.5ether 0x --rpc-url $RPC_URL --private-key $PRIVATE_KEY_1 > /dev/null

color_print $CYAN 2 "First confirmation..."
cast send $CR "confirmTransaction(uint256)" 1 --rpc-url $RPC_URL --private-key $PRIVATE_KEY_2 > /dev/null

color_print $CYAN 2 "Attempting same confirmation again:"
if cast send $CR "confirmTransaction(uint256)" 1 --rpc-url $RPC_URL --private-key $PRIVATE_KEY_2 > /dev/null 2>&1; then
    log_test_result "Double-Confirm" 1 "Double confirmation should have failed"
else
    log_test_result "Double-Confirm" 0 "Double confirmation correctly reverted"
fi

color_print $BLUE 0 "\n[4/5] Testing Threshold Edge Case..."
threshold=$(cast call $CR "threshold()(uint256)" --rpc-url $RPC_URL)
color_print $YELLOW 2 "Current threshold:" "$threshold"

color_print $CYAN 2 "Submitting tx with 1/3 threshold..."
cast send $CR "submitTransaction(address,uint256,bytes)" $NON_OWNER 0.1ether 0x --rpc-url $RPC_URL --private-key $PRIVATE_KEY_1 > /dev/null

tx_count_before=$(cast call $CR "transactionsLength()(uint256)" --rpc-url $RPC_URL)
color_print $CYAN 2 "Single confirmation (should NOT execute)..."
cast send $CR "confirmTransaction(uint256)" $((tx_count_before-1)) --rpc-url $RPC_URL --private-key $PRIVATE_KEY_2 > /dev/null

tx_data=$(cast call $CR "getTransaction(uint256)(address,uint256,bytes,bool,uint256)" $((tx_count_before-1)) --rpc-url $RPC_URL --json)
to=$(echo "$tx_data" | jq -r '.[0]')
value=$(echo "$tx_data" | jq -r '.[1]')
data=$(echo "$tx_data" | jq -r '.[2]')
executed=$(echo "$tx_data" | jq -r '.[3]')
confirmations=$(echo "$tx_data" | jq -r '.[4]')

color_print $YELLOW 2 "Recipient:" "$to"
color_print $YELLOW 2 "Value:" "$(echo "scale=18; $value / 10^18" | bc) ETH"
color_print $YELLOW 2 "Data:" "$data"
color_print $YELLOW 2 "Executed:" "$executed"
color_print $YELLOW 2 "Confirmations:" "$confirmations"

if [[ "$executed" == "true" ]]; then
    log_test_result "Threshold" 1 "Transaction executed prematurely!"
elif [[ "$confirmations" -ne 1 ]]; then
    log_test_result "Threshold" 1 "Confirmations count mismatch!"
else
    log_test_result "Threshold" 0 "Transaction correctly pending"
fi

color_print $BLUE 0 "\nTest Results Summary:"
color_print $GREEN 2 "Passed tests (${#TEST_SUCCESSES[@]}):"
for test in "${TEST_SUCCESSES[@]}"; do
    color_print $GREEN 4 "- $test"
done

if [ ${#TEST_FAILURES[@]} -gt 0 ]; then
    color_print $RED 2 "Failed tests (${#TEST_FAILURES[@]}):"
    for test in "${TEST_FAILURES[@]}"; do
        color_print $RED 4 "- $test"
    done
else
    color_print $GREEN 2 "All tests passed successfully!"
fi

exit $TEST_RESULT
