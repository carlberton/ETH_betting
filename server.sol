// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract FootballBetting {

    address private owner;
    uint8 public commissionPercentage;

    enum BettingState { Open, Closed }
    BettingState private currentBettingState;

    // Enum to make outcomes clearer and less error-prone
    enum MatchOutcome { Draw, HomeWin, AwayWin }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the admin can call this function");
        _;
    }

    struct Match {
        uint8 id;
        string homeTeam;
        string awayTeam;
        string score;
        uint256 totalHomeBets;
        uint256 totalAwayBets;
        uint256 totalDrawBets;
        address[] bettors; // Keep track of everyone who bet on this match
        bool isSettled;    // To prevent paying out twice
    }
    
    struct Bet {
        uint256 amount;
        MatchOutcome team; // Using the enum for clarity
    }

    mapping(uint8 => Match) private matches;
    uint8[] private matchIds;

    mapping(uint8 => mapping(address => Bet)) private bets;
    // This mapping helps in viewing user's bets, but is not used in settlement logic
    mapping(address => uint8[]) private userBets;

    constructor() {
        owner = msg.sender;
        currentBettingState = BettingState.Closed; 
        commissionPercentage = 5; // Default 5% commission
    }
    
    /**
     * @notice The main settlement function for the owner.
     * Iterates through all matches and settles any that have a score and are not already settled.
     * This is the only function the owner needs to call to trigger all payouts.
     */
    function settleAllMatches() public onlyOwner {
        require(currentBettingState == BettingState.Closed, "Betting must be closed to settle matches");

        for (uint i = 0; i < matchIds.length; i++) {
            uint8 matchId = matchIds[i];
            // Settle if score is set and not already settled
            if (bytes(matches[matchId].score).length > 0 && !matches[matchId].isSettled) {
                _settle(matchId);
            }
        }
    }

    /**
     * @notice Internal logic to settle a single match.
     * @param _matchId The ID of the match to settle.
     */
    function _settle(uint8 _matchId) private {
        Match storage currentMatch = matches[_matchId];
        currentMatch.isSettled = true; // Settle match at the beginning to prevent re-entrancy attacks

        // 1. Determine winner from score string
        (uint8 homeScore, uint8 awayScore, bool success) = _parseScore(currentMatch.score);
        if (!success) { return; } // Could not parse score, skip match for now

        MatchOutcome winningOutcome;
        if (homeScore > awayScore) {
            winningOutcome = MatchOutcome.HomeWin;
        } else if (awayScore > homeScore) {
            winningOutcome = MatchOutcome.AwayWin;
        } else {
            winningOutcome = MatchOutcome.Draw;
        }

        // 2. Calculate pools and payouts
        uint256 totalPool = currentMatch.totalHomeBets + currentMatch.totalAwayBets + currentMatch.totalDrawBets;
        if (totalPool == 0) { return; } // No bets on this match, nothing to do

        uint256 commission = (totalPool * commissionPercentage) / 100;
        uint256 prizePool = totalPool - commission;

        uint256 winningPoolTotal;
        if (winningOutcome == MatchOutcome.HomeWin) {
            winningPoolTotal = currentMatch.totalHomeBets;
        } else if (winningOutcome == MatchOutcome.AwayWin) {
            winningPoolTotal = currentMatch.totalAwayBets;
        } else {
            winningPoolTotal = currentMatch.totalDrawBets;
        }

        // 3. Pay the winners proportionally
        if (winningPoolTotal > 0) {
            for (uint i = 0; i < currentMatch.bettors.length; i++) {
                address bettor = currentMatch.bettors[i];
                Bet memory userBet = bets[_matchId][bettor];

                if (userBet.team == winningOutcome) {
                    uint256 payout = (userBet.amount * prizePool) / winningPoolTotal;
                    if (payout > 0) {
                        payable(bettor).transfer(payout);
                    }
                }
            }
        }
        
        // 4. Pay commission to the contract owner
        if (commission > 0) {
            payable(owner).transfer(commission);
        }
    }

    /**
     * @notice Helper function to parse scores like "2-1".
     * @dev This simple version only works for single-digit scores (0-9).
     * @return home score, away score, success boolean
     */
    function _parseScore(string memory _score) private pure returns (uint8 home, uint8 away, bool success) {
        bytes memory b = bytes(_score);
        if (b.length != 3 || b[1] != '-') {
            return (0, 0, false); // Invalid format, e.g., "10-1" or "2 1"
        }
        
        uint8 homeDigit = uint8(b[0]);
        uint8 awayDigit = uint8(b[2]);

        // Ensure characters are digits '0' through '9'
        if (homeDigit < 48 || homeDigit > 57 || awayDigit < 48 || awayDigit > 57) {
            return (0, 0, false);
        }

        // Convert ASCII '0'-'9' to number 0-9
        home = homeDigit - 48;
        away = awayDigit - 48;

        return (home, away, true);
    }
    
    // --- Public and Owner Functions ---

    function placeBet(uint8 _matchId, MatchOutcome _team) public payable {
        require(msg.value > 0, "A bet amount is required");
        require(uint8(_team) <= 2, "Invalid team selection");
        require(bytes(matches[_matchId].homeTeam).length != 0, "Match does not exist");
        require(currentBettingState == BettingState.Open, "Betting is currently closed for all matches");
        require(!matches[_matchId].isSettled, "This match has already been settled");

        Match storage currentMatch = matches[_matchId];
        
        if (_team == MatchOutcome.HomeWin) currentMatch.totalHomeBets += msg.value;
        else if (_team == MatchOutcome.AwayWin) currentMatch.totalAwayBets += msg.value;
        else currentMatch.totalDrawBets += msg.value;

        // If this is the user's first bet on this match, add them to the bettors list for iteration during settlement
        if (bets[_matchId][msg.sender].amount == 0) {
            currentMatch.bettors.push(msg.sender);
        }
        
        // Add the bet amount to the user's existing bet
        bets[_matchId][msg.sender].amount += msg.value;
        bets[_matchId][msg.sender].team = _team;

        userBets[msg.sender].push(_matchId); // For getMyBets view function
    }
    
    function createMatch(uint8 _id, string memory _home, string memory _away) public onlyOwner {
        require(bytes(matches[_id].homeTeam).length == 0, "Match with this ID already exists");
        matches[_id] = Match({
            id: _id, homeTeam: _home, awayTeam: _away, score: "",
            totalHomeBets: 0, totalAwayBets: 0, totalDrawBets: 0,
            isSettled: false, bettors: new address[](0)
        });
        matchIds.push(_id);
    }

    function addScore(uint8 _matchId, string memory _score) public onlyOwner {
        require(bytes(matches[_matchId].homeTeam).length != 0, "Match does not exist");
        matches[_matchId].score = _score;
    }
    
    function closeBetting() public onlyOwner { currentBettingState = BettingState.Closed; }
    function openBetting() public onlyOwner { currentBettingState = BettingState.Open; }

    function resetMatches() public onlyOwner {
        for (uint i = 0; i < matchIds.length; i++) {
            delete matches[matchIds[i]];
        }
        delete matchIds;
    }

    // --- View Functions ---

    function getBettingState() public view returns (BettingState) { return currentBettingState; }

    function getAllMatches() public view returns (Match[] memory) {
        Match[] memory all = new Match[](matchIds.length);
        for (uint i = 0; i < matchIds.length; i++) {
            all[i] = matches[matchIds[i]];
        }
        return all;
    }

    function getMyBets() public view returns (Bet[] memory) {
        uint8[] memory ids = userBets[msg.sender];
        Bet[] memory my = new Bet[](ids.length);
        for (uint i = 0; i < ids.length; i++) {
            my[i] = bets[ids[i]][msg.sender];
        }
        return my;
    }
}