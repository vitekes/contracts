// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// Настройка оптимизатора должна быть в настройках компилятора, а не в директиве pragma

import "./IERC20.sol";
import "./ParticipantManager.sol";
import "./ContestManager.sol";
import "./CommissionManager.sol";
import "./PrizeManager.sol";
import "./SafeMath.sol";
import "./ContestsContract.sol";

/**
 * @title ContestsParticipantContract.sol
 * @dev Расширяет функционал ContestsContract.sol, перенимая часть методов для уменьшения размера основного контракта
 */
contract ContestsParticipantContract {
    using SafeMath for uint256;
    
    ContestsContract public mainContract;
    
    constructor(address _mainContract) {
        require(_mainContract != address(0), "Main contract address cannot be zero");
        mainContract = ContestsContract(_mainContract);
    }
    
    // Участие в конкурсе
    function joinContest(uint256 contestId, uint256 userId) external {
        // Делегируем вызов основному контракту
        mainContract.joinContest(contestId, userId);
    }
    
    // Получение приза
    function claimPrize(uint256 contestId, uint256 participantIndex) external {
        // Делегируем вызов основному контракту
        mainContract.claimPrize(contestId, participantIndex);
    }
    
    // Геттеры
    function getContest(uint256 contestId) external view returns (ContestManager.Contest memory) {
        return mainContract.getContest(contestId);
    }

    function getParticipant(uint256 contestId, uint256 participantIndex) external view returns (ParticipantManager.Participant memory) {
        return mainContract.getParticipant(contestId, participantIndex);
    }

    function getContestParticipants(uint256 contestId) external view returns (ParticipantManager.Participant[] memory) {
        return mainContract.getContestParticipants(contestId);
    }

    function getContestWinners(uint256 contestId) external view returns (ParticipantManager.Participant[] memory) {
        return mainContract.getContestWinners(contestId);
    }
} 