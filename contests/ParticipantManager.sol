// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ParticipantManager {
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
    
    event ParticipantJoined(
        uint256 indexed contestId,
        address indexed wallet,
        uint256 userId
    );
    
    event ParticipantRemoved(
        uint256 indexed contestId, 
        address indexed participant, 
        uint256 userId
    );
    
    // Добавление участника в конкурс
    function addParticipant(
        mapping(uint256 => mapping(uint256 => Participant)) storage participants,
        mapping(uint256 => uint256) storage nextParticipantIndex,
        uint256 contestId,
        address wallet,
        uint256 userId
    ) internal returns (uint256) {
        uint256 participantIndex = nextParticipantIndex[contestId];
        
        participants[contestId][participantIndex] = Participant({
            wallet: wallet,
            userId: userId,
            contestId: contestId,
            status: ParticipantStatus.PARTICIPATED,
            prizeAmount: 0,
            promocode: "",
            hasClaimed: false
        });
        
        emit ParticipantJoined(contestId, wallet, userId);
        
        return participantIndex;
    }
    
    // Удаление участника из конкурса
    function removeParticipant(
        mapping(uint256 => mapping(uint256 => Participant)) storage participants,
        uint256 contestId,
        uint256 participantIndex,
        uint256 totalParticipants
    ) internal returns (uint256) {
        Participant storage participant = participants[contestId][participantIndex];
        require(participant.status == ParticipantStatus.PARTICIPATED, "Can only remove active participants");
        
        // Сдвигаем последнего участника на место удаляемого
        if(participantIndex < totalParticipants - 1) {
            participants[contestId][participantIndex] = participants[contestId][totalParticipants - 1];
        }
        
        emit ParticipantRemoved(contestId, participant.wallet, participant.userId);
        
        return totalParticipants - 1;
    }
    
    // Обновление статуса участника
    function updateParticipantStatus(
        mapping(uint256 => mapping(uint256 => Participant)) storage participants,
        uint256 contestId,
        uint256 participantIndex,
        ParticipantStatus status
    ) internal {
        participants[contestId][participantIndex].status = status;
    }
    
    // Установка денежного приза для участника
    function setParticipantMoneyPrize(
        mapping(uint256 => mapping(uint256 => Participant)) storage participants,
        uint256 contestId,
        uint256 participantIndex,
        uint256 prizeAmount
    ) internal {
        participants[contestId][participantIndex].prizeAmount = prizeAmount;
        participants[contestId][participantIndex].status = ParticipantStatus.WON;
    }
    
    // Установка промокода как приза для участника
    function setParticipantPromocodePrize(
        mapping(uint256 => mapping(uint256 => Participant)) storage participants,
        uint256 contestId,
        uint256 participantIndex,
        string memory promocode
    ) internal {
        participants[contestId][participantIndex].promocode = promocode;
        participants[contestId][participantIndex].status = ParticipantStatus.WON;
    }
    
    // Отметка приза как полученного
    function markPrizeAsClaimed(
        mapping(uint256 => mapping(uint256 => Participant)) storage participants,
        uint256 contestId,
        uint256 participantIndex
    ) internal {
        participants[contestId][participantIndex].hasClaimed = true;
        participants[contestId][participantIndex].status = ParticipantStatus.CLAIMED;
    }
    
    // Получение всех участников конкурса
    function getContestParticipants(
        mapping(uint256 => mapping(uint256 => Participant)) storage participants,
        uint256 contestId,
        uint256 totalParticipants
    ) internal view returns (Participant[] memory) {
        Participant[] memory result = new Participant[](totalParticipants);
        for(uint256 i = 0; i < totalParticipants; i++) {
            result[i] = participants[contestId][i];
        }
        return result;
    }
    
    // Получение победителей конкурса
    function getContestWinners(
        mapping(uint256 => mapping(uint256 => Participant)) storage participants,
        uint256 contestId,
        uint256 totalParticipants
    ) internal view returns (Participant[] memory) {
        uint256 winnerCount = 0;
        for(uint256 i = 0; i < totalParticipants; i++) {
            if(participants[contestId][i].status == ParticipantStatus.WON || 
               participants[contestId][i].status == ParticipantStatus.CLAIMED) {
                winnerCount++;
            }
        }
        
        Participant[] memory winners = new Participant[](winnerCount);
        uint256 currentIndex = 0;
        
        for(uint256 i = 0; i < totalParticipants; i++) {
            if(participants[contestId][i].status == ParticipantStatus.WON || 
               participants[contestId][i].status == ParticipantStatus.CLAIMED) {
                winners[currentIndex] = participants[contestId][i];
                currentIndex++;
            }
        }
        
        return winners;
    }
} 