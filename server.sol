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

    // Fonction pour créer un match
    function createMatch(string memory _id, string memory _home, string memory _away, string memory _score, string memory _timestamp) public {
        if (bytes(_score).length == 0) {
            _score = "";  // Valeur par défaut si score est vide
        }
        
        // Vérifie si un timestamp est fourni, sinon assigne une valeur par défaut
        if (bytes(_timestamp).length == 0) {
            _timestamp = "";  // Valeur par défaut (timestamp actuel)
        }
        
        matches[_id] = Match({
            id: _id,
            homeTeam: _home,
            awayTeam: _away,
            startTimestamp: _timestamp,
            score: _score
        });
        matchIds.push(_id);  // Ajoute l'ID du match au tableau matchIds
    }

    // Fonction pour obtenir tous les matchs
    function getAllMatches() public view returns (Match[] memory) {
        Match[] memory allMatches = new Match[](matchIds.length);
        for (uint256 i = 0; i < matchIds.length; i++) {
            allMatches[i] = matches[matchIds[i]];  // Utilise les IDs pour récupérer les matchs
        }
        return allMatches;
    }
}
