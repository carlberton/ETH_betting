// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FootballBetting {

    struct Match {
        string id;
        string homeTeam;
        string awayTeam;
        string score;
        string startTimestamp;
    }

    mapping(string => Match) private matches;  // Mapping des matchs
    string[] private matchIds;  // Tableau des IDs des matchs

    struct Bet {
        uint256 amount;   // Somme en ETH mise sur le match
        uint8 team;       // 1 pour équipe à domicile, 2 pour équipe visiteuse, 0 pour match nul
    }

     // Mapping pour les paris
    mapping(string => mapping(address => Bet)) private bets;  // Mapping des paris par ID de match et par adresse d'utilisateur
    mapping(address => string[]) private userBets;  // Liste des matchIds sur lesquels chaque utilisateur a parié


    // Fonction pour créer un match
    function createMatch(string memory _id, string memory _home, string memory _away, string memory _score, string memory _timestamp) public {
        if (bytes(_score).length == 0) {
            _score = "";  
        }
    
        if (bytes(_timestamp).length == 0) {
            _timestamp = "";  
        }
        
        matches[_id] = Match({
            id: _id,
            homeTeam: _home,
            awayTeam: _away,
            startTimestamp: _timestamp,
            score: _score
        });
        matchIds.push(_id);  
    }

    // Fonction pour obtenir tous les matchs
    function getAllMatches() public view returns (Match[] memory) {
        Match[] memory allMatches = new Match[](matchIds.length);
        for (uint256 i = 0; i < matchIds.length; i++) {
            allMatches[i] = matches[matchIds[i]];  
        }
        return allMatches;
    }

    // Fonction pour parier sur un match
    function placeBet(string memory _matchId, uint8 _team) public payable {
        
        require(msg.value > 0, "La mise doit etre positive.");
        require(_team == 0 || _team == 1 || _team == 2, "Choix invalide d'equipe.");

        bets[_matchId][msg.sender] = Bet({
            amount: msg.value,
            team: _team
        });

        userBets[msg.sender].push(_matchId);
    }

    // Fonction pour voir tous les paris de l'utilisateur
    function getMyBets() public view returns (Bet[] memory) {
        string[] memory ids = userBets[msg.sender];
        Bet[] memory myBets = new Bet[](ids.length);
        
        for (uint i = 0; i < ids.length; i++) {
            myBets[i] = bets[ids[i]][msg.sender];
        }

        return myBets;
    }
}
