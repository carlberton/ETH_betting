import random
import string
import argparse
from web3 import Web3

# --- CONFIGURATION ---
from config import RPC_URL, CONTRACT_ADDRESS, CONTRACT_ABI 
class ManagerClient:
    def __init__(self):
        self.PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
        self.w3 = Web3(Web3.HTTPProvider(RPC_URL))
        self.acct = self.w3.eth.account.from_key(self.PRIVATE_KEY)

        if not self.w3.is_connected() or "YourNewContractAddressHere" in CONTRACT_ADDRESS:
            print("Erreur : Veuillez vous connecter à un nœud et mettre à jour le CONTRACT_ADDRESS.")
            exit()

        self.contract = self.w3.eth.contract(address=CONTRACT_ADDRESS, abi=CONTRACT_ABI)
        print(f"Connecté à Web3. Utilisation du compte : {self.acct.address}")

    # --- HELPER & COMMAND FUNCTIONS ---

    def send_tx(self, fn, value=0):
        try:
            tx = fn.build_transaction({
                'from': self.acct.address,
                'nonce': self.w3.eth.get_transaction_count(self.acct.address),
                'value': value
            })
            signed = self.acct.sign_transaction(tx)
            tx_hash = self.w3.eth.send_raw_transaction(signed.raw_transaction)
            print(f"  > Transaction envoyée : {tx_hash.hex()}. En attente de réception...")
            receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
            if receipt.status == 1:
                print(f"  > Succès ! Transaction confirmée dans le bloc {receipt.blockNumber}.")
            else:
                print(f"  > Erreur : La transaction a échoué. Vérifiez la logique du contrat et les entrées.")
        except Exception as e:
            print(f"Une erreur est survenue lors de l'envoi de la transaction : {e}")

    def handle_create_matches(self, args):
        print(f"\nCréation de {args.num} matchs aléatoires...")
        for i in range(args.num):
            home = ''.join(random.choices(string.ascii_uppercase, k=3))
            away = ''.join(random.choices(string.ascii_uppercase, k=3))
            print(f"Soumission du match {i+1} : {home} vs {away}")
            self.send_tx(self.contract.functions.createMatch(i + 1, home, away))

    def handle_place_bet(self, args):
        print(f"\nPlacement d'un pari de {args.amount} ETH sur le match {args.match_id}, Résultat {args.outcome}...")
        bet_amount_wei = self.w3.to_wei(args.amount, 'ether')
        self.send_tx(self.contract.functions.placeBet(args.match_id, args.outcome), value=bet_amount_wei)

    def handle_add_score(self, args):
        print(f"\nDéfinition du score pour le match {args.match_id} à '{args.score}'")
        self.send_tx(self.contract.functions.addScore(args.match_id, args.score))

    def handle_settle_matches(self, args):
        print("\nTentative de règlement de tous les matchs terminés...")
        print("Cela va analyser les scores, déterminer les gagnants et déclencher automatiquement les paiements.")
        self.send_tx(self.contract.functions.settleAllMatches())

    def handle_open_betting(self, args):
        print("\nEnvoi de la transaction pour OUVRIR les paris...")
        self.send_tx(self.contract.functions.openBetting())

    def handle_close_betting(self, args):
        print("\nEnvoi de la transaction pour FERMER les paris...")
        self.send_tx(self.contract.functions.closeBetting())

    def handle_view_matches(self, args):
        print("\n--- Matchs du Jour ---")
        all_matches = self.contract.functions.getAllMatches().call()
        if not all_matches:
            print("Aucun match trouvé.")
            return
        for m in all_matches:
            (match_id, home, away, score, total_home, total_away, total_draw, _, is_settled) = m
            status = "Terminé" if is_settled else "Actif"
            print(f"\nID: {match_id} | {home} vs {away} | Score: {score or 'À venir'} | Statut: {status}")
            print(f"  Cagnottes (ETH): Domicile: {self.w3.from_wei(total_home, 'ether')}, Nul: {self.w3.from_wei(total_draw, 'ether')}, Extérieur: {self.w3.from_wei(total_away, 'ether')}")
        print("\n--------------------")

    def handle_reset(self, args):
        print("\nRéinitialisation de tous les matchs sur le contrat...")
        self.send_tx(self.contract.functions.resetMatches())

    def handle_balance(self, args):
        balance_after = self.w3.eth.get_balance("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
        print(f"Solde :  {self.w3.from_wei(balance_after, 'ether')} ETH")

# --- MAIN EXECUTION ---
if __name__ == "__main__":
    manager = ManagerClient()
    parser = argparse.ArgumentParser(description="Final CLI for the Football Betting smart contract.")
    subparsers = parser.add_subparsers(dest='command', help='Available commands', required=True)

    p_create = subparsers.add_parser('create', help='Create N new random matches.')
    p_create.add_argument('num', type=int)
    p_create.set_defaults(func=manager.handle_create_matches)

    p_bet = subparsers.add_parser('bet', help='Place a bet on a match.')
    p_bet.add_argument('match_id', type=int)
    p_bet.add_argument('outcome', type=int, choices=[0, 1, 2], help='0=Draw, 1=HomeWin, 2=AwayWin.')
    p_bet.add_argument('amount', type=float, help='Amount in ETH.')
    p_bet.set_defaults(func=manager.handle_place_bet)

    p_score = subparsers.add_parser('add_score', help="(Owner) Set a match's final score.")
    p_score.add_argument('match_id', type=int)
    p_score.add_argument('score', type=str, help="Score string, e.g., '2-1'. Must be single digits.")
    p_score.set_defaults(func=manager.handle_add_score)

    p_settle = subparsers.add_parser('settle_matches', help='(Owner) Settle all matches with scores.')
    p_settle.set_defaults(func=manager.handle_settle_matches)

    p_open = subparsers.add_parser('open_betting', help='(Owner) Opens betting.')
    p_open.set_defaults(func=manager.handle_open_betting)
    p_close = subparsers.add_parser('close_betting', help='(Owner) Closes betting.')
    p_close.set_defaults(func=manager.handle_close_betting)
    
    p_view = subparsers.add_parser('view_matches', help='View all matches and their betting pools.')
    p_view.set_defaults(func=manager.handle_view_matches)

    p_reset = subparsers.add_parser('reset_matches', help='Reset all matches on the contract.')
    p_reset.set_defaults(func=manager.handle_reset)

    p_balance = subparsers.add_parser('balance', help='Get balance')
    p_balance.set_defaults(func=manager.handle_balance)
    args = parser.parse_args()
    args.func(args)