#!/bin/bash

# Usage: ./compute_gas.sh N
# N = number of bettors (max 6)

if [ -z "$1" ]; then
    echo "Usage: $0 N"
    exit 1
fi

N=$1
if (( N < 1 || N > 6 )); then
    echo "N must be between 1 and 6"
    exit 1
fi

get_gas_used() {
    echo "$1" | grep -oP 'Gas utilisé\s*:\s*\K[0-9]+' | head -n1
}

MANAGER="python3 manager.py"
BETTOR="python3 bettor.py"

BETTOR_PRIVS=(
    "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
    "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
    "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"
    "0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a"
    "0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba"
    "0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e"
)

MATCH_ID=1
MATCH_SCORE="3-1"

# Outcomes and amounts for each bettor (can be customized)
BET_RES=(1 0 2 1 0 2)
BET_AMT=(5 10 7 8 6 9)

# Generate salts for each bettor
for ((i=0; i<N; i++)); do
    SALTS[$i]=$(openssl rand -hex 8)
done

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
for ((i=0; i<N; i++)); do
    PRIV=${BETTOR_PRIVS[$i]}
    RES=${BET_RES[$i]}
    AMT=${BET_AMT[$i]}
    SALT=${SALTS[$i]}
    OUT=$($BETTOR commit $PRIV $MATCH_ID $RES $AMT --salt $SALT)
    GAS[commit$i]=$(get_gas_used "$OUT")
    GAS_BETTOR[$i]=${GAS[commit$i]}
    echo "$OUT"
done

echo "=== 4. Phase de reveal ouverte ==="
OUT=$($MANAGER open_reveal)
GAS[open_reveal]=$(get_gas_used "$OUT")
GAS_MANAGER[open_reveal]=${GAS[open_reveal]}
echo "$OUT"

echo "=== 5. Reveals des parieurs ==="
for ((i=0; i<N; i++)); do
    PRIV=${BETTOR_PRIVS[$i]}
    RES=${BET_RES[$i]}
    SALT=${SALTS[$i]}
    OUT=$($BETTOR reveal $PRIV $MATCH_ID $RES $SALT)
    GAS[reveal$i]=$(get_gas_used "$OUT")
    GAS_BETTOR[$i]=$(( ${GAS_BETTOR[$i]:-0} + ${GAS[reveal$i]:-0} ))
    echo "$OUT"
done

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

for ((i=0; i<N; i++)); do
    idx=$((i+1))
    echo "Bettor $idx : ${GAS_BETTOR[$i]:-0} gas"
done
TOTAL_BETTOR=0
for ((i=0; i<N; i++)); do
    TOTAL_BETTOR=$((TOTAL_BETTOR + ${GAS_BETTOR[$i]:-0}))
done
echo "Total gas utilisé par les parieurs"