// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

enum WinnerSelection {
    DRAW,
    TEAM_A,
    TEAM_B
}

struct Match {
    uint256 id;
    string teamA;
    string teamB;
}

struct Bet {
    address creator;
    WinnerSelection winnerSelection;
}

contract SportsBetting is Ownable, ReentrancyGuard {
    uint256 constant BET_COST = 0.1 ether;
    uint256 constant BET_REWARD = 0.2 ether;

    Match[] public activeMatches;
    mapping(uint256 => bool) isMatchIdActive;
    mapping(uint256 => bool) isMatchIdFullfilled;
    mapping(uint256 => Bet[]) public matchIdToPendingBets;
    mapping(address => uint256) public balances;

    event BetCreated(address creator, uint256 matchId, WinnerSelection winner);
    event BetFinished(address creator, uint256 matchId, bool won);
    event MatchCreated(uint256 matchId, string teamA, string teamB);
    event MatchFinished(uint256 matchId, WinnerSelection winner);

    constructor() payable {}

    function createMatch(Match calldata _newMatch) public {
        require(
            !isMatchIdActive[_newMatch.id] &&
                !isMatchIdFullfilled[_newMatch.id],
            "Match already exists or fullfilled"
        );

        activeMatches.push(_newMatch);
        isMatchIdActive[_newMatch.id] = true;

        emit MatchCreated(_newMatch.id, _newMatch.teamA, _newMatch.teamB);
    }

    function createBet(uint256 matchId, WinnerSelection winnerSelection)
        public
        payable
    {
        require(isMatchIdActive[matchId], "Wrong match ID");
        require(msg.value == BET_COST, "Send eth amount of bet cost to bet");

        matchIdToPendingBets[matchId].push(Bet(msg.sender, winnerSelection));

        emit BetCreated(msg.sender, matchId, winnerSelection);
    }

    function getAllActiveMatches() public view returns (Match[] memory) {
        Match[] memory matches = new Match[](activeMatches.length);
        for (uint i = 0; i < activeMatches.length; i++) {
            Match storage match1 = activeMatches[i];
            matches[i] = match1;
        }

        return matches;
    }

    function finishMatch(uint256 _matchId, WinnerSelection _winner) public {
        require(isMatchIdActive[_matchId], "Match not active");
        require(!isMatchIdFullfilled[_matchId], "Match already fullfilled");

        isMatchIdActive[_matchId] = false;
        isMatchIdFullfilled[_matchId] = true;

        emit MatchFinished(_matchId, _winner);

        // add winning bets to users balances
        for (uint i = 0; i < matchIdToPendingBets[_matchId].length; i++) {
            bool betWon = matchIdToPendingBets[_matchId][i].winnerSelection ==
                _winner;
            if (betWon) {
                balances[
                    matchIdToPendingBets[_matchId][i].creator
                ] += BET_REWARD;
            }

            emit BetFinished(
                matchIdToPendingBets[_matchId][i].creator,
                _matchId,
                betWon
            );
        }

        delete matchIdToPendingBets[_matchId];
        removeActiveMatchArray(_matchId);
        // remove from active matches array
    }

    function removeActiveMatchArray(uint256 _id) private {
        for (uint i = 0; i < activeMatches.length; i++) {
            if (activeMatches[i].id == _id) {
                activeMatches[i] = activeMatches[activeMatches.length - 1];
                activeMatches.pop();
                return;
            }
        }
    }

    function userWithdraw(uint256 _amount) public nonReentrant returns (bool) {
        require(balances[msg.sender] >= _amount);
        balances[msg.sender] -= _amount;
        (bool sent, ) = payable(msg.sender).call{value: _amount}("");
        return sent;
    }
}
