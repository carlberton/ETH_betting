// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract FootballBetting {
    address public owner; // Deployer Adress
    uint8 public commissionPercentage;  
 
    enum BettingState { Commit, Reveal, Distribution } // States of the betting 
    BettingState public currentBettingState;           // Current states

    enum MatchOutcome { Draw, HomeWin, AwayWin }       // Match outcomes

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");     // Modifier for deployer
        _;
    }

    struct Match {
        uint8 id;    
        string homeTeam;
        string awayTeam;
        string score;
        MatchOutcome winningOutcome; // The outcome (Draw, HomeWin, AwayWin)
        uint256 totalPool;           // Amount of Ether bet on this match  
        uint256 revealedWinningPool; // The total amount bet by winners who revealed their bets correctly.
        uint256 commission;          // The amount of commission taken from the total pool.
        uint256 prizePool;           // The total amount to be distributed among the winners
    }

    struct Commit {
        bytes32 commitHash;            // The encrypted hash of the bet (outcome + salt).
        uint256 amount;                // The amount of Ether the user has bet.
        bool revealed;                 // A flag to indicate if the user has revealed their bet.
        MatchOutcome revealedOutcome;  // The outcome the user revealed.  
        bool isWinner;                 // A flag to indicate if the user's bet was correct.
    }

    mapping(uint8 => Match) public matches; // ex : matches[1] => Match with id = 3
    uint8[] public matchIds;
    mapping(uint8 => mapping(address => Commit)) public commits; // ex: commits[3][address] => commit on match 3 by address
    mapping(uint8 => mapping(MatchOutcome => uint256)) public outcomePool; // ex outcomePool[3][MatchOutcome.Draw]=>How much bet on draw
    mapping(uint8 => address[]) public bettors; // matchId => liste des adresses ayant commit sur ce match
    constructor() {
        owner = msg.sender;
        commissionPercentage = 5;
        currentBettingState = BettingState.Commit;
    }

    // --- VUE DES MATCHS ---

function getAllMatches() external view returns (
        uint8[] memory, string[] memory, string[] memory
    ) {
        // Creates a new memory array to store match IDs.
        uint8[] memory ids = new uint8[](matchIds.length);
        // Creates a new memory array to store home team names.
        string[] memory homes = new string[](matchIds.length);
        // Creates a new memory array to store away team names.
        string[] memory aways = new string[](matchIds.length);
        for (uint i = 0; i < matchIds.length; i++) {
            // Gets the match ID from the matchIds array.
            ids[i] = matches[matchIds[i]].id;
            // Fills the arrays with the details of each match.
            homes[i] = matches[matchIds[i]].homeTeam;
            aways[i] = matches[matchIds[i]].awayTeam;
        }
        return (ids, homes, aways);
    }

    // --- PHASE MANAGEMENT admin only ---

    function openCommitPhase() external onlyOwner {
        currentBettingState = BettingState.Commit;
    }

    function openRevealPhase() external onlyOwner {
        currentBettingState = BettingState.Reveal;
    }
// Allows the owner to start the prize distribution for a specific match
function openDistributionPhase(uint8 matchId) external onlyOwner {
    require(bytes(matches[matchId].score).length > 0, "Score not set");
    require(currentBettingState == BettingState.Reveal, "Not in reveal phase");
     // Parses the score string to get home and away scores.
    (uint8 homeScore, uint8 awayScore, bool ok) = _parseScore(matches[matchId].score);
    require(ok, "Invalid score");
    // Determines the winning outcome based on the scores.
    MatchOutcome winningOutcome;
    if (homeScore > awayScore)
        winningOutcome = MatchOutcome.HomeWin;
    else if (awayScore > homeScore) 
        winningOutcome = MatchOutcome.AwayWin;
    else 
        winningOutcome = MatchOutcome.Draw;
    matches[matchId].winningOutcome = winningOutcome;

    matches[matchId].totalPool = outcomePool[matchId][MatchOutcome.HomeWin] +
                                outcomePool[matchId][MatchOutcome.AwayWin] +
                                outcomePool[matchId][MatchOutcome.Draw];

    matches[matchId].commission = (matches[matchId].totalPool * commissionPercentage) / 100;

    matches[matchId].prizePool = matches[matchId].totalPool - matches[matchId].commission;

    // Initializes the pool of money from revealed winners.
    uint256 revealedWinningPool = 0;
    address[] storage betAddrs = bettors[matchId];
    // Loops through all bettors to identify the winners.
    for (uint i = 0; i < betAddrs.length; i++) {
        Commit storage c = commits[matchId][betAddrs[i]];
        if (c.revealed && c.revealedOutcome == winningOutcome) {
            c.isWinner = true;
            revealedWinningPool += c.amount;
        }
    }
    
// Stores the total amount from revealed winners.
    matches[matchId].revealedWinningPool = revealedWinningPool;

    // Transfer commission to owner
    if (matches[matchId].commission > 0) {
        uint256 commissionToSend = matches[matchId].commission; 
        matches[matchId].commission = 0;
        payable(owner).transfer(commissionToSend);
    }

    // If there are no revealed winners, the entire prize pool goes to the owner
    if (revealedWinningPool == 0 && matches[matchId].prizePool > 0) {
        uint256 prizeToSend = matches[matchId].prizePool;
        matches[matchId].prizePool = 0;
        payable(owner).transfer(prizeToSend);
    } 
    // If there are winners, distribute the prize pool among them.
    else if (revealedWinningPool > 0) {
        for (uint i = 0; i < betAddrs.length; i++) {
            Commit storage c = commits[matchId][betAddrs[i]];
            if (c.isWinner) {
                uint256 payout = (c.amount * matches[matchId].prizePool) / revealedWinningPool;
                payable(betAddrs[i]).transfer(payout);
            }
        }
        // Resets the prize pool to zero.
        matches[matchId].prizePool = 0;
    }

        currentBettingState = BettingState.Distribution;
    }

    // --- BETTING FUNCTIONS ---
    uint256 public constant MIN_BET_AMOUNT = 217 * 1e14; // 2,17×10^{-4} ETH = 0.000217 ETH
    function commitBet(uint8 matchId, bytes32 commitHash) external payable {
        require(currentBettingState == BettingState.Commit, "Not commit phase");
        require(msg.value >= MIN_BET_AMOUNT, "Bet amount too low");
        require(msg.value > 0, "No ETH sent");
        require(commits[matchId][msg.sender].amount == 0, "Already committed");
        require(bytes(matches[matchId].homeTeam).length != 0, "Match does not exist");
        
        // Creates a new Commit struct for the user's bet.    
        commits[matchId][msg.sender] = Commit({
            commitHash: commitHash,
            amount: msg.value,
            revealed: false,
            revealedOutcome: MatchOutcome.Draw,    // Default value, will be updated on reveal.
            isWinner: false
        });
        // Adds the user's address to the list of bettors for this match.
        bettors[matchId].push(msg.sender);
    }

    function revealBet(uint8 matchId, MatchOutcome outcome, string calldata salt) external {
        require(currentBettingState == BettingState.Reveal, "Not reveal phase");
        Commit storage c = commits[matchId][msg.sender];
        require(c.amount > 0, "No commit");
        require(!c.revealed, "Already revealed");
        // Verifies the reveal by hashing the provided outcome and salt and comparing it to the stored commit hash 
        require(keccak256(abi.encodePacked(outcome, salt)) == c.commitHash, "Invalid reveal");

        c.revealed = true;
        c.revealedOutcome = outcome;
        // Adds the bet amount to the pool for the revealed outcome.
        outcomePool[matchId][outcome] += c.amount;
    }

    // --- ADMIN FUNCTIONS (Owner only) ---
    function createMatch(uint8 _id, string memory _home, string memory _away) public onlyOwner {
        require(bytes(matches[_id].homeTeam).length == 0, "Match with this ID already exists");
        // Creates a new Match struct and adds it to the matches mapping
        matches[_id] = Match({
            id: _id,
            homeTeam: _home,
            awayTeam: _away,
            score: "",
            winningOutcome: MatchOutcome.Draw,
            totalPool: 0,
            revealedWinningPool: 0,
            commission: 0,
            prizePool: 0
        });
        // Adds the new match ID to the matchIds array.
        matchIds.push(_id);
    }

    function addScore(uint8 _matchId, string memory _score) public onlyOwner {
        require(bytes(matches[_matchId].homeTeam).length != 0, "Match does not exist");
        matches[_matchId].score = _score;
    }

    function resetMatches() external onlyOwner {

        for (uint i = 0; i < matchIds.length; i++) {
            uint8 matchId = matchIds[i];

            // Delete all bettors and their commits for this match
            address[] storage betAddrs = bettors[matchId];
            for (uint j = 0; j < betAddrs.length; j++) {
                delete commits[matchId][betAddrs[j]];
            }
            delete bettors[matchId];

            // Reset outcome pools
            delete outcomePool[matchId][MatchOutcome.HomeWin];
            delete outcomePool[matchId][MatchOutcome.AwayWin];
            delete outcomePool[matchId][MatchOutcome.Draw];

            // Delete the match itself
            delete matches[matchId];
        }
        // Clear the matchIds array
        delete matchIds;
    }

    // --- UTILS ---
    // An internal function to parse a score string (e.g., "2-1") into two numbers.
    function _parseScore(string memory _score) private pure returns (uint8 home, uint8 away, bool success) {
        bytes memory b = bytes(_score);
        if (b.length != 3 || b[1] != '-') return (0, 0, false);
        uint8 homeDigit = uint8(b[0]);
        uint8 awayDigit = uint8(b[2]);
        if (homeDigit < 48 || homeDigit > 57 || awayDigit < 48 || awayDigit > 57) return (0, 0, false);
        home = homeDigit - 48;
        away = awayDigit - 48;
        return (home, away, true);
    }
    // A view function to get the current betting state as a number.
    function getBettingState() external view returns (uint8) {
        return uint8(currentBettingState);
    }
    
}
