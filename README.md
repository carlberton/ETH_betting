# Projet de paris ETH | Blockchain Smart Contract | M1 Info 
# Nader Ben Ammar et Carl berton
# Initialiser l'environnement hardhat 

## Nettoyer l’ancien dossier si besoin
rm -rf hardhat/

## Créer le dossier et initialiser le projet
mkdir -p hardhat
cd hardhat
npm init -y

## Installer Hardhat
npm install --save-dev hardhat

## Initialiser le projet Hardhat (suivre les instructions)
npx hardhat

## Lancer un nœud local Hardhat
npx hardhat node



# Compiler et deployer le contrat depuis remix

# Depuis la racine du projet
python3 -m venv venv
source venv/bin/activate 

# Installer les dépendances Python
pip install -r requirements.txt

# Python scripts

## Python venv
python3 -m venv venv/
. venv/bin/activate
pip install -r requirements

## bettor.py
python3 bettor.py -h 

## manager.py 
python3 manager.py -h 

## Après chaque test, il faut reset les matchs car nos tests ne sont pas dynamiques ( ils utilisent le meme match id )
python3 manager.py reset_matches 