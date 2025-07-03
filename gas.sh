#!/bin/bash

get_gas_used() {
    echo "$1" | grep -oP 'Gas utilisé\s*:\s*\K[0-9]+' | head -n1
}

MANAGER="python3 manager.py"
BETTOR="python3 bettor.py"

BETTOR_PRIV1="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
BETTOR_PRIV2="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
BETTOR_PRIV3="0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"

MATCH_ID=1
MATCH_SCORE="3-1"
BET1_RES=1
BET2_RES=0
BET3_RES=2
BET1_AMT=5
BET2_AMT=10
BET3_AMT=7

SALT1=$(openssl rand -hex 8)
SALT2=$(openssl rand -hex 8)
SALT3=$(openssl rand -hex 8)

declare -A GAS
declare -A GAS_BETTOR
declare -A GAS_MANAGER

echo "=== 1. Création du match ==="
OUT=$($MANAGER create 1)
GAS[create]=$(get_gas_used "$OUT")
GAS_MANAGER[create]=${GAS[create]}
echo "$OUT"

echo "=== 2. Phase de commit ouverte ==="
OUT=$($MANAGER open_commit)
GAS[open_commit]=$(get_gas_used "$OUT")
GAS_MANAGER[open_commit]=${GAS[open_commit]}
echo "$OUT"

echo "=== 3. Commits des parieurs ==="
OUT=$($BETTOR commit $BETTOR_PRIV1 $MATCH_ID $BET1_RES $BET1_AMT --salt $SALT1)
GAS[commit1]=$(get_gas_used "$OUT")
GAS_BETTOR[1]=${GAS[commit1]}
echo "$OUT"
OUT=$($BETTOR commit $BETTOR_PRIV2 $MATCH_ID $BET2_RES $BET2_AMT --salt $SALT2)
GAS[commit2]=$(get_gas_used "$OUT")
GAS_BETTOR[2]=${GAS[commit2]}
echo "$OUT"
OUT=$($BETTOR commit $BETTOR_PRIV3 $MATCH_ID $BET3_RES $BET3_AMT --salt $SALT3)
GAS[commit3]=$(get_gas_used "$OUT")
GAS_BETTOR[3]=${GAS[commit3]}
echo "$OUT"

echo "=== 4. Phase de reveal ouverte ==="
OUT=$($MANAGER open_reveal)
GAS[open_reveal]=$(get_gas_used "$OUT")
GAS_MANAGER[open_reveal]=${GAS[open_reveal]}
echo "$OUT"

echo "=== 5. Reveals des parieurs ==="
OUT=$($BETTOR reveal $BETTOR_PRIV1 $MATCH_ID $BET1_RES $SALT1)
GAS[reveal1]=$(get_gas_used "$OUT")
GAS_BETTOR[1]=$(( ${GAS_BETTOR[1]:-0} + ${GAS[reveal1]:-0} ))
echo "$OUT"
OUT=$($BETTOR reveal $BETTOR_PRIV2 $MATCH_ID $BET2_RES $SALT2)
GAS[reveal2]=$(get_gas_used "$OUT")
GAS_BETTOR[2]=$(( ${GAS_BETTOR[2]:-0} + ${GAS[reveal2]:-0} ))
echo "$OUT"
OUT=$($BETTOR reveal $BETTOR_PRIV3 $MATCH_ID $BET3_RES $SALT3)
GAS[reveal3]=$(get_gas_used "$OUT")
GAS_BETTOR[3]=$(( ${GAS_BETTOR[3]:-0} + ${GAS[reveal3]:-0} ))
echo "$OUT"

echo "=== 6. Ajout du score par l'admin ==="
OUT=$($MANAGER add_score $MATCH_ID $MATCH_SCORE)
GAS[add_score]=$(get_gas_used "$OUT")
GAS_MANAGER[add_score]=${GAS[add_score]}
echo "$OUT"

echo "=== 7. Phase de distribution ouverte ==="
OUT=$($MANAGER open_distribution $MATCH_ID)
GAS[open_distribution]=$(get_gas_used "$OUT")
GAS_MANAGER[open_distribution]=${GAS[open_distribution]}
echo "$OUT"

echo "=== 8. Récapitulatif de la consommation de gas ==="
TOTAL_MANAGER=0
for k in "${!GAS_MANAGER[@]}"; do
    echo "Manager - $k : ${GAS_MANAGER[$k]} gas"
    TOTAL_MANAGER=$((TOTAL_MANAGER + ${GAS_MANAGER[$k]:-0}))
done
echo "Total gas utilisé par le manager : $TOTAL_MANAGER"

for i in 1 2 3; do
    echo "Bettor $i : ${GAS_BETTOR[$i]:-0} gas"
done
TOTAL_BETTOR=$(( ${GAS_BETTOR[1]:-0} + ${GAS_BETTOR[2]:-0} + ${GAS_BETTOR[3]:-0} ))
echo "Total gas utilisé par les parieurs : $TOTAL_BETTOR"