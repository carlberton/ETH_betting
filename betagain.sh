#!/bin/bash

MANAGER="python3 manager.py"
BETTOR="python3 bettor.py"

BETTOR_PRIV="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
MATCH_ID=1
BET_RES=1
BET_AMT=5

SALT1=$(openssl rand -hex 8)
SALT2=$(openssl rand -hex 8)

echo "=== 1. Création du match ==="
$MANAGER create 1

echo "=== 2. Phase de commit ouverte ==="
$MANAGER open_commit

echo "=== 3. Premier commit du parieur ==="
$BETTOR commit $BETTOR_PRIV $MATCH_ID $BET_RES $BET_AMT --salt $SALT1

echo "=== 4. Tentative de second commit du même parieur sur le même match ==="
$BETTOR commit $BETTOR_PRIV $MATCH_ID $BET_RES $BET_AMT --salt $SALT2

echo "=== 5. Si le contrat est correct, le second commit doit échouer ==="