// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract FootballBetting {
    address public owner;
    uint8 public commissionPercentage;

    enum BettingState { Commit, Reveal, Distribution }
    BettingState public currentBettingState;

    enum MatchOutcome { Draw, HomeWin, AwayWin }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    struct Match {
        uint8 id;
        string homeTeam;
        string awayTeam;
        string score;
        bool isSettled;
        MatchOutcome winningOutcome;
        uint256 totalPool;
        uint256 revealedWinningPool;
        uint256 commission;
        uint256 prizePool;
    }

    struct Commit {
        bytes32 commitHash;
        uint256 amount;
        bool revealed;
        MatchOutcome revealedOutcome;
        bool isWinner;
        bool claimed;
    }

    mapping(uint8 => Match) public matches;
    uint8[] public matchIds;
    mapping(uint8 => mapping(address => Commit)) public commits;
    mapping(uint8 => mapping(MatchOutcome => uint256)) public outcomePool;
    mapping(uint8 => address[]) public bettors; // matchId => liste des adresses ayant commit
    constructor() {
        owner = msg.sender;
        commissionPercentage = 5;
        currentBettingState = BettingState.Commit;
    }

    // --- PHASE MANAGEMENT ---

    function openCommitPhase() external onlyOwner {
        currentBettingState = BettingState.Commit;
    }

    function openRevealPhase() external onlyOwner {
        currentBettingState = BettingState.Reveal;
    }

function openDistributionPhase(uint8 matchId) external onlyOwner {
    require(bytes(matches[matchId].score).length > 0, "Score not set");
    require(currentBettingState == BettingState.Reveal, "Not in reveal phase");
    (uint8 homeScore, uint8 awayScore, bool ok) = _parseScore(matches[matchId].score);
    require(ok, "Invalid score");
    MatchOutcome winningOutcome;
    if (homeScore > awayScore) winningOutcome = MatchOutcome.HomeWin;
    else if (awayScore > homeScore) winningOutcome = MatchOutcome.AwayWin;
    else winningOutcome = MatchOutcome.Draw;
    matches[matchId].winningOutcome = winningOutcome;

    matches[matchId].totalPool = outcomePool[matchId][MatchOutcome.HomeWin] +
                                outcomePool[matchId][MatchOutcome.AwayWin] +
                                outcomePool[matchId][MatchOutcome.Draw];
    matches[matchId].commission = (matches[matchId].totalPool * commissionPercentage) / 100;
    matches[matchId].prizePool = matches[matchId].totalPool - matches[matchId].commission;

    uint256 revealedWinningPool = 0;
    address[] storage betAddrs = bettors[matchId];
    for (uint i = 0; i < betAddrs.length; i++) {
        Commit storage c = commits[matchId][betAddrs[i]];
        if (c.revealed && c.revealedOutcome == winningOutcome) {
            c.isWinner = true;
            revealedWinningPool += c.amount;
        }
    }
    matches[matchId].revealedWinningPool = revealedWinningPool;

    // Transfert la commission au owner à chaque distribution
    if (matches[matchId].commission > 0) {
        uint256 commissionToSend = matches[matchId].commission;
        matches[matchId].commission = 0;
        payable(owner).transfer(commissionToSend);
    }

    // Si aucun gagnant, transfert aussi la cagnotte au owner
    if (revealedWinningPool == 0 && matches[matchId].prizePool > 0) {
        matches[matchId].isSettled = true;
        uint256 prizeToSend = matches[matchId].prizePool;
        matches[matchId].prizePool = 0;
        payable(owner).transfer(prizeToSend);
    } else if (revealedWinningPool > 0) {
        // Distribution automatique aux gagnants
        for (uint i = 0; i < betAddrs.length; i++) {
            Commit storage c = commits[matchId][betAddrs[i]];
            if (c.isWinner) {
                uint256 payout = (c.amount * matches[matchId].prizePool) / revealedWinningPool;
                c.claimed = true;
                payable(betAddrs[i]).transfer(payout);
            }
        }
        matches[matchId].isSettled = true;
        matches[matchId].prizePool = 0;
    }

        currentBettingState = BettingState.Distribution;
    }

    // --- PARIS ---

    function commitBet(uint8 matchId, bytes32 commitHash) external payable {
        require(currentBettingState == BettingState.Commit, "Not commit phase");
        require(msg.value > 0, "No ETH sent");
        require(commits[matchId][msg.sender].amount == 0, "Already committed");
        require(bytes(matches[matchId].homeTeam).length != 0, "Match does not exist");

        commits[matchId][msg.sender] = Commit({
            commitHash: commitHash,
            amount: msg.value,
            revealed: false,
            revealedOutcome: MatchOutcome.Draw,
            isWinner: false,
            claimed: false
        });
        bettors[matchId].push(msg.sender);
    }

    function revealBet(uint8 matchId, MatchOutcome outcome, string calldata salt) external {
        require(currentBettingState == BettingState.Reveal, "Not reveal phase");
        Commit storage c = commits[matchId][msg.sender];
        require(c.amount > 0, "No commit");
        require(!c.revealed, "Already revealed");
        require(keccak256(abi.encodePacked(outcome, salt)) == c.commitHash, "Invalid reveal");

        c.revealed = true;
        c.revealedOutcome = outcome;
        outcomePool[matchId][outcome] += c.amount;
    }

    // --- ADMIN ---

    function createMatch(uint8 _id, string memory _home, string memory _away) public onlyOwner {
        require(bytes(matches[_id].homeTeam).length == 0, "Match with this ID already exists");
        matches[_id] = Match({
            id: _id,
            homeTeam: _home,
            awayTeam: _away,
            score: "",
            isSettled: false,
            winningOutcome: MatchOutcome.Draw,
            totalPool: 0,
            revealedWinningPool: 0,
            commission: 0,
            prizePool: 0
        });
        matchIds.push(_id);
    }

    function addScore(uint8 _matchId, string memory _score) public onlyOwner {
        require(bytes(matches[_matchId].homeTeam).length != 0, "Match does not exist");
        matches[_matchId].score = _score;
    }

    // --- UTILS ---

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
}