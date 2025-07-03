#!/bin/bash
get_balance() {
    local val=$(echo "$1" | grep -i -oP '([0-9]+([.][0-9]+)?)\s*eth' | grep -oP '[0-9]+([.][0-9]+)?')
    if [ -z "$val" ]; then
        echo "0"
    else
        echo "$val"
    fi
}
MANAGER="python3 manager.py"
BETTOR="python3 bettor.py"

BETTOR_PRIV1="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
BETTOR_PRIV2="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
BETTOR_PRIV3="0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"
BAL_MANAGER_BEFORE=$($MANAGER balance)
VAL_MANAGER_BEFORE=$(get_balance "$BAL_MANAGER_BEFORE")
MATCH_ID=1
MATCH_SCORE="3-1"
BET1_RES=1
BET2_RES=0
BET3_RES=2

BET1_AMT=5
BET2_AMT=10
BET3_AMT=7

# Générer des salts secrets pour chaque parieur
SALT1=$(openssl rand -hex 8)
SALT2=$(openssl rand -hex 8)
SALT3=$(openssl rand -hex 8)



echo "=== 1. Création du match ==="
$MANAGER create 1

echo "=== 2. Phase de commit ouverte ==="
$MANAGER open_commit

echo "=== 3. Soldes AVANT les commits ==="
BAL1_BEFORE=$($BETTOR balance $BETTOR_PRIV1)
BAL2_BEFORE=$($BETTOR balance $BETTOR_PRIV2)
BAL3_BEFORE=$($BETTOR balance $BETTOR_PRIV3)
VAL1_BEFORE=$(get_balance "$BAL1_BEFORE")
VAL2_BEFORE=$(get_balance "$BAL2_BEFORE")
VAL3_BEFORE=$(get_balance "$BAL3_BEFORE")
echo "Parieur 1 : $VAL1_BEFORE ETH"
echo "Parieur 2 : $VAL2_BEFORE ETH"
echo "Parieur 3 : $VAL3_BEFORE ETH"

echo "=== 4. Commits des parieurs ==="
$BETTOR commit $BETTOR_PRIV1 $MATCH_ID $BET1_RES $BET1_AMT --salt $SALT1
$BETTOR commit $BETTOR_PRIV2 $MATCH_ID $BET2_RES $BET2_AMT --salt $SALT2
$BETTOR commit $BETTOR_PRIV3 $MATCH_ID $BET3_RES $BET3_AMT --salt $SALT3

echo "=== 5. Phase de reveal ouverte ==="
$MANAGER open_reveal

echo "=== 6. Reveals des parieurs ==="
$BETTOR reveal $BETTOR_PRIV1 $MATCH_ID $BET1_RES $SALT1
$BETTOR reveal $BETTOR_PRIV2 $MATCH_ID $BET2_RES $SALT2
$BETTOR reveal $BETTOR_PRIV3 $MATCH_ID $BET3_RES $SALT3

echo "=== 7. Ajout du score par l'admin ==="
$MANAGER add_score $MATCH_ID $MATCH_SCORE

echo "=== 8. Phase de distribution ouverte ==="
$MANAGER open_distribution $MATCH_ID

echo "=== 9. Soldes finaux ==="
BAL1_AFTER=$($BETTOR balance $BETTOR_PRIV1)
BAL2_AFTER=$($BETTOR balance $BETTOR_PRIV2)
BAL3_AFTER=$($BETTOR balance $BETTOR_PRIV3)
VAL1_AFTER=$(get_balance "$BAL1_AFTER")
VAL2_AFTER=$(get_balance "$BAL2_AFTER")
VAL3_AFTER=$(get_balance "$BAL3_AFTER")
BAL_MANAGER_AFTER=$($MANAGER balance)
VAL_MANAGER_AFTER=$(get_balance "$BAL_MANAGER_AFTER")
echo "Parieur 1 : $VAL1_AFTER ETH"
echo "Parieur 2 : $VAL2_AFTER ETH"
echo "Parieur 3 : $VAL3_AFTER ETH"

GAIN1=$(awk "BEGIN {print $VAL1_AFTER - $VAL1_BEFORE}")
GAIN2=$(awk "BEGIN {print $VAL2_AFTER - $VAL2_BEFORE}")
GAIN3=$(awk "BEGIN {print $VAL3_AFTER - $VAL3_BEFORE}")

echo "=== 10. Résumé des mises et résultats ==="
echo "Parieur 1 : $BET1_AMT ETH sur 'domicile' (gagnant si score = domicile)"
echo "Parieur 2 : $BET2_AMT ETH sur 'nul' (gagnant si score = nul)"
echo "Parieur 3 : $BET3_AMT ETH sur 'extérieur' (gagnant si score = extérieur)"
echo "Score final du match : $MATCH_SCORE"

echo "=== 11. Résumé des gains/pertes ==="
if (( $(echo "$GAIN1 > 0" | bc -l) )); then STATUS1="GAGNANT"; else STATUS1="PERDANT"; fi
if (( $(echo "$GAIN2 > 0" | bc -l) )); then STATUS2="GAGNANT"; else STATUS2="PERDANT"; fi
if (( $(echo "$GAIN3 > 0" | bc -l) )); then STATUS3="GAGNANT"; else STATUS3="PERDANT"; fi
echo "Parieur 1 : $(printf '%+.6f' $GAIN1) ETH ($STATUS1)"
echo "Parieur 2 : $(printf '%+.6f' $GAIN2) ETH ($STATUS2)"
echo "Parieur 3 : $(printf '%+.6f' $GAIN3) ETH ($STATUS3)"
echo "Manager : $VAL_MANAGER_AFTER ETH (avant : $VAL_MANAGER_BEFORE ETH)"