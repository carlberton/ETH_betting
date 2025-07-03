# bettor.py
# Script pour les parieurs. Utilise la configuration dynamique.

import argparse
from web3 import Web3
# Importe la configuration, qui charge déjà l'ABI dynamiquement
from config import RPC_URL, CONTRACT_ADDRESS, CONTRACT_ABI 
import secrets
from eth_utils import keccak
class BettorClient:
    """Client pour interagir avec le contrat de pari du point de vue d'un parieur."""

    def __init__(self):
        """Initialise la connexion Web3 et le contrat."""
        if not CONTRACT_ABI:
            print("L'ABI n'a pas pu être chargé. Arrêt du script.")
            exit()
            
        self.w3 = Web3(Web3.HTTPProvider(RPC_URL))
        if not self.w3.is_connected():
            print("Erreur : Impossible de se connecter au noeud Ethereum.")
            exit()
        
        self.contract = self.w3.eth.contract(address=CONTRACT_ADDRESS, abi=CONTRACT_ABI)
        print("Connecté au contrat de pari.")

    def view_matches(self):
        """Affiche tous les matchs disponibles (id et équipes)."""
        print("\n--- Matchs du Jour ---")
        try:
            ids, homes, aways = self.contract.functions.getAllMatches().call()
            if not ids:
                print("Aucun match trouvé.")
                return
            for i in range(len(ids)):
                print(f"ID: {ids[i]} | {homes[i]} vs {aways[i]}")
            print("\n--------------------")
        except Exception as e:
            print(f"Erreur lors de la récupération des matchs : {e}")

    def check_betting_status(self):
        """Vérifie et affiche si les paris sont ouverts ou fermés."""
        print("\n--- Statut des Paris ---")
        try:
            state_val = self.contract.functions.getBettingState().call()
            betting_states = {0: "Commit", 1: "Reveal",2: "Distribution"}
            status_str = betting_states.get(state_val, "Inconnu")
            print(f"L'état global des paris est : {status_str}")
            print("------------------------")
        except Exception as e:
            print(f"Erreur lors de la récupération du statut : {e}")

    def commit_bet(self, private_key, match_id, outcome, amount, salt=None):
        """Envoie le commit hash pour un pari."""
        try:
            bettor_acct = self.w3.eth.account.from_key(private_key)
            if salt is None:
                salt = secrets.token_hex(16)
            # outcome must be int (0, 1, 2)
            outcome_bytes = bytes([outcome])
            commit_hash = self.w3.keccak(outcome_bytes + salt.encode())
            print(f"\nUtilisation du compte : {bettor_acct.address}")
            print(f"Commit pour {amount} ETH sur le match {match_id} (Résultat caché, salt: {salt})")
            print(f"Commit hash : {commit_hash.hex()}")

            bet_amount_wei = self.w3.to_wei(amount, 'ether')
            fn = self.contract.functions.commitBet(match_id, commit_hash)
            tx = fn.build_transaction({
                'from': bettor_acct.address,
                'nonce': self.w3.eth.get_transaction_count(bettor_acct.address),
                'value': bet_amount_wei
            })
            signed_tx = self.w3.eth.account.sign_transaction(tx, private_key=bettor_acct.key)
            tx_hash = self.w3.eth.send_raw_transaction(signed_tx.raw_transaction)
            print(f"  > Commit envoyé : {tx_hash.hex()}. En attente de confirmation...")
            receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
            if receipt.status == 1:
                print("  > Commit accepté !")
                print(f"Gardez bien ce salt pour la révélation : {salt}")
            else:
                print("  > La transaction a échoué.")
        except Exception as e:
            print(f"Erreur lors du commit : {e}")

    def reveal_bet(self, private_key, match_id, outcome, salt):
        """Révèle le pari (outcome + salt) pour obtenir le paiement si gagnant."""
        try:
            bettor_acct = self.w3.eth.account.from_key(private_key)
            print(f"\nRévélation pour le match {match_id} avec outcome={outcome}, salt={salt}")
            fn = self.contract.functions.revealBet(match_id, outcome, salt)
            tx = fn.build_transaction({
                'from': bettor_acct.address,
                'nonce': self.w3.eth.get_transaction_count(bettor_acct.address),
                'value': 0
            })
            signed_tx = self.w3.eth.account.sign_transaction(tx, private_key=bettor_acct.key)
            tx_hash = self.w3.eth.send_raw_transaction(signed_tx.raw_transaction)
            print(f"  > Reveal envoyé : {tx_hash.hex()}. En attente de confirmation...")
            receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
            if receipt.status == 1:
                print("  > Reveal accepté ! Si vous êtes gagnant, vous recevez votre gain.")
            else:
                print("  > La transaction a échoué.")
        except Exception as e:
            print(f"Erreur lors du reveal : {e}")

    def balance(self, args):
        # Dérive l'adresse à partir de la clé privée
        account = self.w3.eth.account.from_key(args.private_key)
        address = account.address
        balance = self.w3.eth.get_balance(address)
        print(f"Solde du compte {address} : {self.w3.from_wei(balance, 'ether')} ETH")

def main():
    parser = argparse.ArgumentParser(description="Client commit-reveal pour FootballBetting.")
    subparsers = parser.add_subparsers(dest='command', help='Commandes disponibles', required=True)

    parser_view = subparsers.add_parser('view', help='Voir les matchs du jour et le statut des paris.')
    parser_view.set_defaults(func=lambda args, client: (client.check_betting_status(), client.view_matches()))

    parser_commit = subparsers.add_parser('commit', help='Commit un pari (hashé, secret).')
    parser_commit.add_argument('private_key', type=str, help="Votre clé privée Ethereum pour signer la transaction.")
    parser_commit.add_argument('match_id', type=int, help="L'ID du match sur lequel parier.")
    parser_commit.add_argument('outcome', type=int, choices=[0, 1, 2], help='Résultat : 0=Nul, 1=Victoire Domicile, 2=Victoire Extérieur.')
    parser_commit.add_argument('amount', type=float, help='Le montant à parier en ETH.')
    parser_commit.add_argument('--salt', type=str, default=None, help='Salt secret (optionnel, généré si non fourni)')
    parser_commit.set_defaults(func=lambda args, client: client.commit_bet(args.private_key, args.match_id, args.outcome, args.amount, args.salt))

    parser_reveal = subparsers.add_parser('reveal', help='Révèle votre pari (outcome + salt).')
    parser_reveal.add_argument('private_key', type=str, help="Votre clé privée Ethereum pour signer la transaction.")
    parser_reveal.add_argument('match_id', type=int, help="L'ID du match.")
    parser_reveal.add_argument('outcome', type=int, choices=[0, 1, 2], help='Résultat parié : 0=Nul, 1=Victoire Domicile, 2=Victoire Extérieur.')
    parser_reveal.add_argument('salt', type=str, help='Le salt utilisé lors du commit.')
    parser_reveal.set_defaults(func=lambda args, client: client.reveal_bet(args.private_key, args.match_id, args.outcome, args.salt))

    parser_balance = subparsers.add_parser('balance', help='Afficher le solde du compte.')
    parser_balance.add_argument('private_key', type=str, help="Votre clé privée Ethereum pour vérifier le solde.")
    parser_balance.set_defaults(func=lambda args, client: client.balance(args))
    
    args = parser.parse_args()
    client = BettorClient()
    args.func(args, client)

if __name__ == "__main__":
    main()
