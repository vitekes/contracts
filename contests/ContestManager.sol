// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol";

library ContestManager {
    enum PrizeType { ETH, TOKEN, PROMOCODE, MIXED }
    enum ContestStatus { ACTIVE, COMPLETED }
    
    struct Contest {
        uint256 id;
        uint256 numberOfWinners;
        uint256 endTime;
        uint256 prizeAmount;
        PrizeType prizeType;
        address tokenAddress; // address(0) для ETH
        string[] promocodes; // Список промокодов для розыгрыша
        ContestStatus status;
        uint256 totalParticipants;
    }
    
    event ContestCreated(
        uint256 indexed contestId,
        uint256 numberOfWinners,
        uint256 endTime,
        uint256 prizeAmount,
        PrizeType prizeType,
        address tokenAddress,
        uint256 promocodesCount
    );
    
    event ContestCompleted(
        uint256 indexed contestId,
        uint256[] winners
    );
    
    event ContestPrizeUpdated(
        uint256 indexed contestId, 
        uint256 newPrizeAmount
    );
    
    event ContestDurationExtended(
        uint256 indexed contestId, 
        uint256 newEndTime
    );
    
    event ContestCancelled(
        uint256 indexed contestId, 
        string reason
    );
    
    event ContestPrizeWithdrawn(
        uint256 indexed contestId, 
        address indexed withdrawnBy, 
        uint256 amount
    );
    
    event PromocodeAdded(
        uint256 indexed contestId,
        uint256 promocodeCount
    );
    
    // Создание нового конкурса с денежным призом
    function createMoneyContest(
        mapping(uint256 => Contest) storage contests,
        uint256 nextContestId,
        uint256 numberOfWinners,
        uint256 durationDays,
        uint256 prizeAmount,
        PrizeType prizeType,
        address tokenAddress
    ) internal returns (uint256) {
        require(numberOfWinners > 0, "Number of winners must be greater than 0");
        require(durationDays > 0, "Duration must be greater than 0");
        require(prizeAmount > 0, "Prize amount must be greater than 0");
        require(prizeType == PrizeType.ETH || prizeType == PrizeType.TOKEN, "Invalid prize type for money contest");
        
        if (prizeType == PrizeType.TOKEN) {
            require(tokenAddress != address(0), "Token address cannot be zero");
        }
        
        contests[nextContestId] = Contest({
            id: nextContestId,
            numberOfWinners: numberOfWinners,
            endTime: block.timestamp + (durationDays * 1 days),
            prizeAmount: prizeAmount,
            prizeType: prizeType,
            tokenAddress: tokenAddress,
            promocodes: new string[](0),
            status: ContestStatus.ACTIVE,
            totalParticipants: 0
        });
        
        emit ContestCreated(
            nextContestId,
            numberOfWinners,
            block.timestamp + (durationDays * 1 days),
            prizeAmount,
            prizeType,
            tokenAddress,
            0
        );
        
        return nextContestId;
    }
    
    // Создание конкурса с промокодами
    function createPromocodeContest(
        mapping(uint256 => Contest) storage contests,
        uint256 nextContestId,
        uint256 numberOfWinners,
        uint256 durationDays,
        string[] memory promocodes
    ) internal returns (uint256) {
        require(numberOfWinners > 0, "Number of winners must be greater than 0");
        require(durationDays > 0, "Duration must be greater than 0");
        require(promocodes.length >= numberOfWinners, "Not enough promocodes for winners");
        
        contests[nextContestId] = Contest({
            id: nextContestId,
            numberOfWinners: numberOfWinners,
            endTime: block.timestamp + (durationDays * 1 days),
            prizeAmount: 0,
            prizeType: PrizeType.PROMOCODE,
            tokenAddress: address(0),
            promocodes: promocodes,
            status: ContestStatus.ACTIVE,
            totalParticipants: 0
        });
        
        emit ContestCreated(
            nextContestId,
            numberOfWinners,
            block.timestamp + (durationDays * 1 days),
            0,
            PrizeType.PROMOCODE,
            address(0),
            promocodes.length
        );
        
        return nextContestId;
    }
    
    // Создание смешанного конкурса (деньги + промокоды)
    function createMixedContest(
        mapping(uint256 => Contest) storage contests,
        uint256 nextContestId,
        uint256 numberOfWinners,
        uint256 durationDays,
        uint256 prizeAmount,
        PrizeType moneyType,
        address tokenAddress,
        string[] memory promocodes
    ) internal returns (uint256) {
        require(numberOfWinners > 0, "Number of winners must be greater than 0");
        require(durationDays > 0, "Duration must be greater than 0");
        require(prizeAmount > 0, "Prize amount must be greater than 0");
        require(moneyType == PrizeType.ETH || moneyType == PrizeType.TOKEN, "Invalid money prize type");
        
        if (moneyType == PrizeType.TOKEN) {
            require(tokenAddress != address(0), "Token address cannot be zero");
        }
        
        contests[nextContestId] = Contest({
            id: nextContestId,
            numberOfWinners: numberOfWinners,
            endTime: block.timestamp + (durationDays * 1 days),
            prizeAmount: prizeAmount,
            prizeType: PrizeType.MIXED,
            tokenAddress: tokenAddress,
            promocodes: promocodes,
            status: ContestStatus.ACTIVE,
            totalParticipants: 0
        });
        
        emit ContestCreated(
            nextContestId,
            numberOfWinners,
            block.timestamp + (durationDays * 1 days),
            prizeAmount,
            PrizeType.MIXED,
            tokenAddress,
            promocodes.length
        );
        
        return nextContestId;
    }
    
    // Обновление призового фонда конкурса
    function updateMoneyPrize(
        mapping(uint256 => Contest) storage contests,
        uint256 contestId,
        uint256 newPrizeAmount
    ) internal {
        Contest storage contest = contests[contestId];
        require(contest.status == ContestStatus.ACTIVE, "Contest is not active");
        require(newPrizeAmount > 0, "Prize amount must be greater than 0");
        require(contest.prizeType == PrizeType.ETH || contest.prizeType == PrizeType.TOKEN || contest.prizeType == PrizeType.MIXED, 
                "Contest does not support money prizes");
        
        contest.prizeAmount = newPrizeAmount;
        emit ContestPrizeUpdated(contestId, newPrizeAmount);
    }
    
    // Добавление промокодов к конкурсу
    function addPromocodes(
        mapping(uint256 => Contest) storage contests,
        uint256 contestId,
        string[] memory newPromocodes
    ) internal {
        Contest storage contest = contests[contestId];
        require(contest.status == ContestStatus.ACTIVE, "Contest is not active");
        require(contest.prizeType == PrizeType.PROMOCODE || contest.prizeType == PrizeType.MIXED,
                "Contest does not support promocode prizes");
        
        for(uint i = 0; i < newPromocodes.length; i++) {
            contest.promocodes.push(newPromocodes[i]);
        }
        
        emit PromocodeAdded(contestId, newPromocodes.length);
    }
    
    // Продление срока конкурса
    function extendDuration(
        mapping(uint256 => Contest) storage contests,
        uint256 contestId,
        uint256 additionalDays
    ) internal {
        Contest storage contest = contests[contestId];
        require(contest.status == ContestStatus.ACTIVE, "Contest is not active");
        require(additionalDays > 0, "Additional days must be greater than 0");
        
        contest.endTime += (additionalDays * 1 days);
        emit ContestDurationExtended(contestId, contest.endTime);
    }
    
    // Отмена конкурса
    function cancelContest(
        mapping(uint256 => Contest) storage contests,
        uint256 contestId,
        string memory reason
    ) internal {
        Contest storage contest = contests[contestId];
        require(contest.status == ContestStatus.ACTIVE, "Contest is not active");
        
        contest.status = ContestStatus.COMPLETED;
        emit ContestCancelled(contestId, reason);
    }
    
    // Завершение конкурса
    function completeContest(
        mapping(uint256 => Contest) storage contests,
        uint256 contestId,
        uint256[] memory winnerIndices
    ) internal {
        Contest storage contest = contests[contestId];
        require(contest.status == ContestStatus.ACTIVE, "Contest is not active");
        require(block.timestamp > contest.endTime, "Contest has not ended yet");
        require(winnerIndices.length == contest.numberOfWinners, "Invalid number of winners");
        
        contest.status = ContestStatus.COMPLETED;
        emit ContestCompleted(contestId, winnerIndices);
    }
    
    // Расчет оставшейся призовой суммы
    function calculateRemainingPrize(
        mapping(uint256 => Contest) storage contests,
        uint256 contestId,
        mapping(uint256 => mapping(uint256 => ParticipantManager.Participant)) storage participants
    ) internal view returns (uint256) {
        Contest storage contest = contests[contestId];
        uint256 remainingPrize = contest.prizeAmount;
        
        for(uint256 i = 0; i < contest.totalParticipants; i++) {
            if(participants[contestId][i].status == ParticipantManager.ParticipantStatus.WON) {
                remainingPrize -= participants[contestId][i].prizeAmount;
            }
        }
        
        return remainingPrize;
    }
    
    // Получение конкурса
    function getContest(
        mapping(uint256 => Contest) storage contests,
        uint256 contestId
    ) internal view returns (Contest memory) {
        return contests[contestId];
    }
}

// Требуется для компиляции библиотеки
interface ParticipantManager {
    enum ParticipantStatus { PARTICIPATED, WON, CLAIMED, LOST }
    struct Participant {
        address wallet;
        uint256 userId;
        uint256 contestId;
        ParticipantStatus status;
        uint256 prizeAmount;
        string promocode;
        bool hasClaimed;
    }
} 