# config.py
# Ce fichier contient toutes les informations de configuration pour se connecter au contrat.
# Il charge maintenant l'ABI dynamiquement depuis les artéfacts de Hardhat.

import json
import os

# --- CONFIGURATION DE BASE ---
# L'URL de votre noeud Ethereum (par exemple, votre noeud Hardhat/Anvil local)
RPC_URL = "http://127.0.0.1:8545/"

# L'adresse du contrat intelligent déployé (À METTRE À JOUR APRÈS CHAQUE DÉPLOIEMENT)
CONTRACT_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3" # Remplacez par votre adresse

# --- CONFIGURATION POUR LE CHARGEMENT DYNAMIQUE DE L'ABI ---
# Nom du fichier de contrat (ex: "server.sol")
CONTRACT_SOURCE_FILE = "server.sol"
# Nom exact du contrat dans le fichier .sol (ex: "contract FootballBetting { ... }")
CONTRACT_NAME = "FootballBetting"


def load_abi():
    """
    Charge dynamiquement l'ABI depuis le fichier JSON généré par Hardhat.
    """
    try:
        # Construit le chemin vers le fichier d'artéfact
        artifact_path = os.path.join(
            os.path.dirname(__file__), "artifacts", f"{CONTRACT_NAME}.json"
        )
        
        # Vérifie si le fichier existe
        if not os.path.exists(artifact_path):
            print(f"Erreur : Le fichier d'artéfact n'a pas été trouvé à l'emplacement : {artifact_path}")
            print("Veuillez vous assurer d'avoir compilé votre contrat avec 'npx hardhat compile'.")
            return None

        # Ouvre et charge le fichier JSON
        with open(artifact_path, 'r') as f:
            artifact = json.load(f)
            return artifact['abi']
            
    except Exception as e:
        print(f"Une erreur est survenue lors du chargement de l'ABI : {e}")
        return None

# On charge l'ABI une seule fois au démarrage pour l'utiliser dans les autres scripts
CONTRACT_ABI = load_abi()
