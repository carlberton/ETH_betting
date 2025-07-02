# bettor.py
# Script pour les parieurs. Utilise la configuration dynamique.

import argparse
from web3 import Web3
# Importe la configuration, qui charge déjà l'ABI dynamiquement
from config import RPC_URL, CONTRACT_ADDRESS, CONTRACT_ABI 

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
        """Affiche tous les matchs disponibles et leur statut."""
        print("\n--- Matchs du Jour ---")
        try:
            all_matches = self.contract.functions.getAllMatches().call()
            if not all_matches:
                print("Aucun match trouvé.")
                return

            for match_data in all_matches:
                (match_id, home, away, score, total_home, total_away, total_draw, _, is_settled) = match_data
                status = "Terminé" if is_settled else "Actif"
                print(f"\nID: {match_id} | {home} vs {away} | Score: {score or 'À venir'} | Statut: {status}")
                print(f"  Cagnottes (ETH): Domicile: {self.w3.from_wei(total_home, 'ether')}, Nul: {self.w3.from_wei(total_draw, 'ether')}, Extérieur: {self.w3.from_wei(total_away, 'ether')}")
            
            print("\n--------------------")

        except Exception as e:
            print(f"Erreur lors de la récupération des matchs : {e}")

    def check_betting_status(self):
        """Vérifie et affiche si les paris sont ouverts ou fermés."""
        print("\n--- Statut des Paris ---")
        try:
            state_val = self.contract.functions.getBettingState().call()
            betting_states = {0: "Ouverts", 1: "Fermés"}
            status_str = betting_states.get(state_val, "Inconnu")
            print(f"L'état global des paris est : {status_str}")
            print("------------------------")
        except Exception as e:
            print(f"Erreur lors de la récupération du statut : {e}")

    def place_bet(self, private_key, match_id, outcome, amount):
        """Place un pari sur un match spécifique."""
        try:
            bettor_acct = self.w3.eth.account.from_key(private_key)
            print(f"\nUtilisation du compte : {bettor_acct.address}")
            print(f"Pari de {amount} ETH sur le match {match_id} (Résultat: {outcome})...")

            bet_amount_wei = self.w3.to_wei(amount, 'ether')
            
            function_call = self.contract.functions.placeBet(match_id, outcome)
            
            tx = function_call.build_transaction({
                'from': bettor_acct.address,
                'nonce': self.w3.eth.get_transaction_count(bettor_acct.address),
                'value': bet_amount_wei
            })
            
            signed_tx = self.w3.eth.account.sign_transaction(tx, private_key=bettor_acct.key)
            tx_hash = self.w3.eth.send_raw_transaction(signed_tx.raw_transaction)
            
            print(f"  > Transaction envoyée : {tx_hash.hex()}. En attente de confirmation...")
            receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
            
            if receipt.status == 1:
                print("  > Pari placé avec succès !")
            else:
                print("  > La transaction a échoué.")
        
        except Exception as e:
            print(f"Une erreur est survenue lors du pari : {e}")

    def balance(self, args):
        # Dérive l'adresse à partir de la clé privée
        account = self.w3.eth.account.from_key(args.private_key)
        address = account.address
        balance = self.w3.eth.get_balance(address)
        print(f"Solde du compte {address} : {self.w3.from_wei(balance, 'ether')} ETH")

def main():
    """Fonction principale pour gérer les arguments de la ligne de commande."""
    parser = argparse.ArgumentParser(description="Client pour les parieurs du contrat FootballBetting.")
    subparsers = parser.add_subparsers(dest='command', help='Commandes disponibles', required=True)

    parser_view = subparsers.add_parser('view', help='Voir les matchs du jour et le statut des paris.')
    parser_view.set_defaults(func=lambda args, client: (client.check_betting_status(), client.view_matches()))

    parser_bet = subparsers.add_parser('bet', help='Placer un pari sur un match.')
    parser_bet.add_argument('private_key', type=str, help="Votre clé privée Ethereum pour signer la transaction.")
    parser_bet.add_argument('match_id', type=int, help="L'ID du match sur lequel parier.")
    parser_bet.add_argument('outcome', type=int, choices=[0, 1, 2], help='Résultat : 0=Nul, 1=Victoire Domicile, 2=Victoire Extérieur.')
    parser_bet.add_argument('amount', type=float, help='Le montant à parier en ETH.')
    parser_bet.set_defaults(func=lambda args, client: client.place_bet(args.private_key, args.match_id, args.outcome, args.amount))

    parser_balance = subparsers.add_parser('balance', help='Afficher le solde du compte.')
    parser_balance.add_argument('private_key', type=str, help="Votre clé privée Ethereum pour vérifier le solde.")
    parser_balance.set_defaults(func=lambda args, client: client.balance(args))
    args = parser.parse_args()
    client = BettorClient()
    args.func(args, client)

if __name__ == "__main__":
    main()
