// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FootballBetting {

    struct Match {
        uint8 id;
        string homeTeam;
        string awayTeam;
        string score;
        uint256 startTimestamp;
    }

    mapping(uint8 => Match) private matches;           // ID de match => Match
    uint8[] private matchIds;                          // Liste des IDs des matchs

    struct Bet {
        uint256 amount;
        uint8 team; // 0 = nul, 1 = domicile, 2 = extérieur
    }

    mapping(uint8 => mapping(address => Bet)) private bets;       // matchId => (joueur => Bet)
    mapping(address => uint8[]) private userBets;                 // joueur => liste de matchIds

    // Créer un match
    function createMatch(
        uint8 _id,
        string memory _home,
        string memory _away,
        string memory _score,
        uint256 _timestamp
    ) public {
        require(bytes(matches[_id].homeTeam).length == 0, "Match deja existant");

        if (bytes(_score).length == 0) {
            _score = "";
        }

        matches[_id] = Match({
            id: _id,
            homeTeam: _home,
            awayTeam: _away,
            score: bytes(_score).length == 0 ? "" : _score,
            startTimestamp: _timestamp
        });

        matchIds.push(_id);
    }

    // Récupérer tous les matchs
    function getAllMatches() public view returns (Match[] memory) {
        Match[] memory all = new Match[](matchIds.length);
        for (uint i = 0; i < matchIds.length; i++) {
            all[i] = matches[matchIds[i]];
        }
        return all;
    }

    // Parier sur un match
    function placeBet(uint8 _matchId, uint8 _team) public payable {
        require(msg.value > 0, "Mise requise");
        require(_team <= 2, "Choix invalide");
        require(bytes(matches[_matchId].homeTeam).length != 0, "Match inexistant");

        bets[_matchId][msg.sender] = Bet({
            amount: msg.value,
            team: _team
        });

        userBets[msg.sender].push(_matchId);
    }

    // Voir ses propres paris
    function getMyBets() public view returns (Bet[] memory) {
        uint8[] memory ids = userBets[msg.sender];
        Bet[] memory my = new Bet[](ids.length);
        for (uint i = 0; i < ids.length; i++) {
            my[i] = bets[ids[i]][msg.sender];
        }
        return my;
    }
}
