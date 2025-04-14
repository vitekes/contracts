// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./ContestManager.sol";
import "./ParticipantManager.sol";
import "./SafeMath.sol";

library PrizeManager {
    using SafeMath for uint256;
    
    event PrizeClaimed(
        uint256 indexed contestId,
        address indexed winner,
        uint256 amount,
        string promocode
    );
    
    // Добавляем событие из ContestManager для использования в нашем коде
    event ContestPrizeWithdrawn(
        uint256 indexed contestId, 
        address indexed withdrawnBy, 
        uint256 amount
    );
    
    // Распределение денежных призов
    function distributeMoneyPrizes(
        mapping(uint256 => mapping(uint256 => ParticipantManager.Participant)) storage participants,
        uint256 contestId,
        uint256[] memory winnerIndices, 
        uint256[] memory prizeAmounts
    ) internal {
        require(winnerIndices.length == prizeAmounts.length, "Arrays length mismatch");
        
        for(uint256 i = 0; i < winnerIndices.length; i++) {
            ParticipantManager.setParticipantMoneyPrize(
                participants,
                contestId,
                winnerIndices[i],
                prizeAmounts[i]
            );
        }
    }
    
    // Распределение промокодов
    function distributePromocodePrizes(
        mapping(uint256 => mapping(uint256 => ParticipantManager.Participant)) storage participants,
        mapping(uint256 => ContestManager.Contest) storage contests,
        uint256 contestId,
        uint256[] memory winnerIndices
    ) internal {
        ContestManager.Contest storage contest = contests[contestId];
        require(contest.promocodes.length >= winnerIndices.length, "Not enough promocodes");
        
        for(uint256 i = 0; i < winnerIndices.length; i++) {
            ParticipantManager.setParticipantPromocodePrize(
                participants,
                contestId,
                winnerIndices[i],
                contest.promocodes[i]
            );
        }
    }
    
    // Распределение смешанных призов (и деньги, и промокоды)
    function distributeMixedPrizes(
        mapping(uint256 => mapping(uint256 => ParticipantManager.Participant)) storage participants,
        mapping(uint256 => ContestManager.Contest) storage contests,
        uint256 contestId,
        uint256[] memory moneyWinnerIndices,
        uint256[] memory prizeAmounts,
        uint256[] memory promocodeWinnerIndices
    ) internal {
        // Распределяем денежные призы
        distributeMoneyPrizes(
            participants,
            contestId,
            moneyWinnerIndices,
            prizeAmounts
        );
        
        // Распределяем промокоды
        distributePromocodePrizes(
            participants,
            contests,
            contestId,
            promocodeWinnerIndices
        );
    }
    
    // Получение денежного приза с улучшенными проверками
    function claimMoneyPrize(
        mapping(uint256 => mapping(uint256 => ParticipantManager.Participant)) storage participants,
        mapping(uint256 => ContestManager.Contest) storage contests,
        uint256 contestId,
        uint256 participantIndex,
        address commissionWallet,
        uint256 commission
    ) internal {
        require(commissionWallet != address(0), "Commission wallet cannot be zero address");
        ParticipantManager.Participant storage participant = participants[contestId][participantIndex];
        require(participant.wallet != address(0), "Participant wallet cannot be zero address");
        ContestManager.Contest storage contest = contests[contestId];
        
        uint256 finalAmount = participant.prizeAmount.sub(commission);
        
        if(contest.prizeType == ContestManager.PrizeType.ETH || contest.prizeType == ContestManager.PrizeType.MIXED) {
            // Проверяем баланс контракта перед отправкой
            require(address(this).balance >= finalAmount.add(commission), "Contract has insufficient ETH balance");
            
            // Отправляем комиссию
            if(commission > 0) {
                (bool commissionSuccess, ) = commissionWallet.call{value: commission}("");
                require(commissionSuccess, "Commission transfer failed");
            }
            
            // Отправляем приз
            (bool success, ) = participant.wallet.call{value: finalAmount}("");
            require(success, "Prize transfer failed");
        } else if(contest.prizeType == ContestManager.PrizeType.TOKEN) {
            require(contest.tokenAddress != address(0), "Token address cannot be zero");
            IERC20 token = IERC20(contest.tokenAddress);
            
            // Проверяем баланс токенов контракта
            uint256 contractBalance = token.balanceOf(address(this));
            require(contractBalance >= finalAmount.add(commission), "Contract has insufficient token balance");
            
            // Отправляем комиссию
            if(commission > 0) {
                require(token.transfer(commissionWallet, commission), "Commission transfer failed");
            }
            
            // Отправляем приз
            require(token.transfer(participant.wallet, finalAmount), "Prize transfer failed");
        }
        
        ParticipantManager.markPrizeAsClaimed(participants, contestId, participantIndex);
        
        emit PrizeClaimed(contestId, participant.wallet, participant.prizeAmount, "");
    }
    
    // Получение промокода как приза
    function claimPromocodePrize(
        mapping(uint256 => mapping(uint256 => ParticipantManager.Participant)) storage participants,
        uint256 contestId,
        uint256 participantIndex
    ) internal {
        ParticipantManager.Participant storage participant = participants[contestId][participantIndex];
        
        ParticipantManager.markPrizeAsClaimed(participants, contestId, participantIndex);
        
        emit PrizeClaimed(contestId, participant.wallet, 0, participant.promocode);
    }
    
    // Получение смешанного приза (если у участника есть и деньги, и промокод)
    function claimMixedPrize(
        mapping(uint256 => mapping(uint256 => ParticipantManager.Participant)) storage participants,
        mapping(uint256 => ContestManager.Contest) storage contests,
        uint256 contestId,
        uint256 participantIndex,
        address commissionWallet,
        uint256 commission
    ) internal {
        ParticipantManager.Participant storage participant = participants[contestId][participantIndex];
        
        // Проверяем, есть ли денежный приз
        if(participant.prizeAmount > 0) {
            // Получаем денежный приз
            claimMoneyPrize(
                participants,
                contests,
                contestId,
                participantIndex,
                commissionWallet,
                commission
            );
        } else {
            // Иначе просто отмечаем приз как полученный
            ParticipantManager.markPrizeAsClaimed(participants, contestId, participantIndex);
        }
        
        // Генерируем событие о получении промокода (если он есть)
        if(bytes(participant.promocode).length > 0) {
            emit PrizeClaimed(contestId, participant.wallet, participant.prizeAmount, participant.promocode);
        } else {
            emit PrizeClaimed(contestId, participant.wallet, participant.prizeAmount, "");
        }
    }
    
    // Вывод неиспользованных призов владельцем контракта
    function withdrawUnusedPrize(
        mapping(uint256 => ContestManager.Contest) storage contests,
        uint256 contestId,
        address recipient,
        uint256 remainingPrize
    ) internal {
        ContestManager.Contest storage contest = contests[contestId];
        require(remainingPrize > 0, "No remaining prize to withdraw");
        
        if(contest.prizeType == ContestManager.PrizeType.ETH || contest.prizeType == ContestManager.PrizeType.MIXED) {
            (bool success, ) = recipient.call{value: remainingPrize}("");
            require(success, "ETH withdrawal failed");
        } else if(contest.prizeType == ContestManager.PrizeType.TOKEN) {
            IERC20 token = IERC20(contest.tokenAddress);
            require(token.transfer(recipient, remainingPrize), "Token withdrawal failed");
        }
        
        emit ContestPrizeWithdrawn(contestId, recipient, remainingPrize);
    }
} 