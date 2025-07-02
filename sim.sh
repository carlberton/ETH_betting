#!/bin/bash

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

# Fonction robuste pour extraire le solde ETH d'une sortie
get_balance() {
    local val=$(echo "$1" | grep -i -oP '([0-9]+([.][0-9]+)?)\s*eth' | grep -oP '[0-9]+([.][0-9]+)?')
    if [ -z "$val" ]; then
        echo "0"
    else
        echo "$val"
    fi
}

echo "=== 1. Création de 1 match ==="
$MANAGER create 1

echo "=== 2. Ouverture des paris ==="
$MANAGER open_betting

echo "=== 3. Soldes AVANT les paris ==="
BAL1_BEFORE=$($BETTOR balance $BETTOR_PRIV1)
BAL2_BEFORE=$($BETTOR balance $BETTOR_PRIV2)
BAL3_BEFORE=$($BETTOR balance $BETTOR_PRIV3)
VAL1_BEFORE=$(get_balance "$BAL1_BEFORE")
VAL2_BEFORE=$(get_balance "$BAL2_BEFORE")
VAL3_BEFORE=$(get_balance "$BAL3_BEFORE")
echo "Parieur 1 : $VAL1_BEFORE ETH"
echo "Parieur 2 : $VAL2_BEFORE ETH"
echo "Parieur 3 : $VAL3_BEFORE ETH"

echo "=== 4. Mises des parieurs ==="
echo "Parieur 1 mise $BET1_AMT ETH sur la victoire domicile"
$BETTOR bet $BETTOR_PRIV1 $MATCH_ID $BET1_RES $BET1_AMT
echo "Parieur 2 mise $BET2_AMT ETH sur le nul"
$BETTOR bet $BETTOR_PRIV2 $MATCH_ID $BET2_RES $BET2_AMT
echo "Parieur 3 mise $BET3_AMT ETH sur la victoire extérieur"
$BETTOR bet $BETTOR_PRIV3 $MATCH_ID $BET3_RES $BET3_AMT

echo "=== 5. Soldes APRÈS les paris ==="
BAL1_AFTER_BET=$($BETTOR balance $BETTOR_PRIV1)
BAL2_AFTER_BET=$($BETTOR balance $BETTOR_PRIV2)
BAL3_AFTER_BET=$($BETTOR balance $BETTOR_PRIV3)
VAL1_AFTER_BET=$(get_balance "$BAL1_AFTER_BET")
VAL2_AFTER_BET=$(get_balance "$BAL2_AFTER_BET")
VAL3_AFTER_BET=$(get_balance "$BAL3_AFTER_BET")
echo "Parieur 1 : $VAL1_AFTER_BET ETH"
echo "Parieur 2 : $VAL2_AFTER_BET ETH"
echo "Parieur 3 : $VAL3_AFTER_BET ETH"

echo "=== 6. Fermeture des paris ==="
$MANAGER close_betting

echo "=== 7. Ajout du score (3-1) au match $MATCH_ID (victoire domicile) ==="
$MANAGER add_score $MATCH_ID $MATCH_SCORE

echo "=== 8. Règlement des matchs ==="
$MANAGER settle_matches

echo "=== 9. Soldes APRÈS règlement ==="
BAL1_FINAL=$($BETTOR balance $BETTOR_PRIV1)
BAL2_FINAL=$($BETTOR balance $BETTOR_PRIV2)
BAL3_FINAL=$($BETTOR balance $BETTOR_PRIV3)
VAL1_FINAL=$(get_balance "$BAL1_FINAL")
VAL2_FINAL=$(get_balance "$BAL2_FINAL")
VAL3_FINAL=$(get_balance "$BAL3_FINAL")
echo "Parieur 1 : $VAL1_FINAL ETH"
echo "Parieur 2 : $VAL2_FINAL ETH"
echo "Parieur 3 : $VAL3_FINAL ETH"

# Calculs robustes des gains/pertes (en float)
GAIN1=$(awk "BEGIN {printf \"%.6f\", $VAL1_FINAL - $VAL1_BEFORE}")
GAIN2=$(awk "BEGIN {printf \"%.6f\", $VAL2_FINAL - $VAL2_BEFORE}")
GAIN3=$(awk "BEGIN {printf \"%.6f\", $VAL3_FINAL - $VAL3_BEFORE}")

if (( $(echo "$GAIN1 > 0" | bc -l) )); then STATUS1="GAGNANT"; else STATUS1="PERDANT"; fi
if (( $(echo "$GAIN2 > 0" | bc -l) )); then STATUS2="GAGNANT"; else STATUS2="PERDANT"; fi
if (( $(echo "$GAIN3 > 0" | bc -l) )); then STATUS3="GAGNANT"; else STATUS3="PERDANT"; fi

echo "=== 10. Résumé des mises et résultats ==="
echo "Parieur 1 : $BET1_AMT ETH sur 'domicile' (gagnant si score = domicile)"
echo "Parieur 2 : $BET2_AMT ETH sur 'nul' (gagnant si score = nul)"
echo "Parieur 3 : $BET3_AMT ETH sur 'extérieur' (gagnant si score = extérieur)"
echo "Score final du match : 3-1 (victoire domicile)"

echo "=== 11. Résumé des gains/pertes ==="
echo "Parieur 1 : $(printf '%+.6f' $GAIN1) ETH ($STATUS1)"
echo "Parieur 2 : $(printf '%+.6f' $GAIN2) ETH ($STATUS2)"
echo "Parieur 3 : $(printf '%+.6f' $GAIN3) ETH ($STATUS3)"