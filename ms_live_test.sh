#!/bin/bash
. .env && ./run.sh && . .env
MS=0xb7a5bd0345ef1cc5e66bf61bdec17d2461fbd968
cast send $FACTORY "createWallet(address[],uint256)" "[$OWNER_1, $OWNER_2, $OWNER_3]" 2 --private-key $PRIVATE_KEY_1 --rpc-url $RPC_URL
cast call $FACTORY "getLastDeployed()" --rpc-url $RPC_URL
cast send $MS --value 1ether --private-key $PRIVATE_KEY_1 --rpc-url $RPC_URL

TX_ID=$(cast send $MS "submitTransaction(address,uint256,bytes)" $OWNER_1 500000000000000000 "0x" \
    --private-key $PRIVATE_KEY_1 \
    --rpc-url $RPC_URL --json | \
    jq -r '.logs[0].topics[1]')

echo "TX_ID=$TX_ID"

cast send $MS "confirmTransaction(uint256)" $TX_ID --private-key $PRIVATE_KEY_1 --rpc-url $RPC_URL
cast send $MS "confirmTransaction(uint256)" $TX_ID --private-key $PRIVATE_KEY_2 --rpc-url $RPC_URL
cast send $MS "executeTransaction(uint256)" $TX_ID --private-key $PRIVATE_KEY_1 --rpc-url $RPC_URL


NS=$(forge create --broadcast src/MultiSig.sol:MultiSig --private-key $PRIVATE_KEY_1 --rpc-url $RPC_URL | grep "Deployed to" | awk '{print $3}')
echo "NS=$NS"

echo "PROPOSAL ID"
PR_ID=$(cast send $MS "proposeUpgrade(address)" $NS --private-key $PRIVATE_KEY_1 \
    --rpc-url $RPC_URL --json | \
    jq -r '.logs[0].topics[1]')

echo "PR_ID=$PR_ID"
TX_HASH=$(cast call $MS "getUpgradeProposalTxHash(uint256)" -- $PR_ID --to-uint256 --rpc-url $RPC_URL)
echo "TX_HASH=$TX_HASH"

p_TX_HASH=$(cast keccak $(cast concat-hex "0x1901" $TX_HASH))
echo "p_TX_HASH=$p_TX_HASH"

SIG1=$(cast wallet sign --private-key $PRIVATE_KEY_1 $p_TX_HASH)
R1=${SIG1:2:64}
S1=${SIG1:66:64}
V1=${SIG1:130:2}
SIG1_FULL="0x${R1}${S1}${V1}"
echo "R1: $R1"
echo "S1: $S1"
echo "V1: $V1"
echo "SIG1_FULL: $SIG1_FULL"

SIG2=$(cast wallet sign --private-key $PRIVATE_KEY_2 $p_TX_HASH)

echo "SIG1=$SIG1"
echo "SIG2=$SIG2"

cast send $MS "approveUpgrade(uint256,bytes)" $PR_ID $SIG1_FULL --private-key $PRIVATE_KEY_1 --rpc-url $RPC_URL
cast send $MS "approveUpgrade(uint256,bytes)" $PR_ID $SIG2 --private-key $PRIVATE_KEY_2 --rpc-url $RPC_URL

cast call $MS "singleton()" --rpc-url $RPC_URL
