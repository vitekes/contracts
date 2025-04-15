// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// Enable optimization with reduced runs (50) to optimize for deployment size
// Настройка оптимизатора должна быть в настройках компилятора, а не в директиве pragma
// pragma abicoder v2;

import "./IERC20.sol";
import "./ParticipantManager.sol";
import "./ContestManager.sol";
import "./CommissionManager.sol";
import "./PrizeManager.sol";
import "./SafeMath.sol";

contract ContestsContract {
    using SafeMath for uint256;

    address public owner;
    address public commissionWallet;
    uint256 public commissionPercentage; // Процент комиссии (например, 100 = 1%, 1000 = 10%)

    // Вспомогательный контракт для разгрузки основного
    address public participantContractAddress;

    // Список адресов, освобожденных от комиссии
    mapping(address => bool) public noCommissionAddresses;

    // Маппинги для хранения данных
    mapping(uint256 => ContestManager.Contest) public contests;
    mapping(uint256 => mapping(uint256 => ParticipantManager.Participant)) public participants; // contestId => participantIndex => Participant
    mapping(uint256 => uint256) public nextParticipantIndex; // contestId => nextIndex

    uint256 public nextContestId = 1;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyParticipantContract() {
        require(
            msg.sender == participantContractAddress || msg.sender == owner, 
            "Only participant contract or owner can call this function"
        );
        _;
    }

    modifier contestExists(uint256 contestId) {
        require(contests[contestId].id != 0, "Contest does not exist");
        _;
    }

    modifier contestActive(uint256 contestId) {
        require(contests[contestId].status == ContestManager.ContestStatus.ACTIVE, "Contest is not active");
        require(block.timestamp <= contests[contestId].endTime, "Contest has ended");
        _;
    }

    constructor(address _commissionWallet, uint256 _commissionPercentage) {
        require(_commissionWallet != address(0), "Commission wallet cannot be zero address");
        require(_commissionPercentage <= 10000, "Commission percentage cannot exceed 100%");
        owner = msg.sender;
        commissionWallet = _commissionWallet;
        commissionPercentage = _commissionPercentage;
    }

    function setParticipantContract(address _participantContract) external onlyOwner {
        require(_participantContract != address(0), "Participant contract cannot be zero address");
        participantContractAddress = _participantContract;
    }

    // Функции управления комиссией
    function setCommissionWallet(address _newWallet) external onlyOwner {
        commissionWallet = CommissionManager.setCommissionWallet(_newWallet);
    }

    function setCommissionPercentage(uint256 _newPercentage) external onlyOwner {
        commissionPercentage = CommissionManager.setCommissionPercentage(_newPercentage);
    }

    function setNoCommissionAddress(address _address, bool _status) external onlyOwner {
        CommissionManager.setNoCommissionAddress(noCommissionAddresses, _address, _status);
    }

    // Создание нового конкурса с денежным призом
    function createMoneyContest(
        uint256 numberOfWinners,
        uint256 durationDays,
        uint256 prizeAmount,
        ContestManager.PrizeType prizeType,
        address tokenAddress
    ) external payable {
        require(numberOfWinners > 0, "Number of winners must be greater than 0");
        require(durationDays > 0, "Duration days must be greater than 0");
        require(prizeAmount > 0, "Prize amount must be greater than 0");
        
        if (prizeType == ContestManager.PrizeType.ETH) {
            require(msg.value >= prizeAmount, "Insufficient ETH sent for prize");
            require(msg.value == prizeAmount, "Exact ETH amount required");
        } else if (prizeType == ContestManager.PrizeType.TOKEN) {
            require(tokenAddress != address(0), "Token address cannot be zero");
            IERC20 token = IERC20(tokenAddress);
            uint256 allowanceBefore = token.allowance(msg.sender, address(this));
            require(allowanceBefore >= prizeAmount, "Insufficient token allowance");
            
            uint256 balanceBefore = token.balanceOf(address(this));
            require(token.transferFrom(msg.sender, address(this), prizeAmount), "Token transfer failed");
            uint256 balanceAfter = token.balanceOf(address(this));
            
            require(balanceAfter >= balanceBefore + prizeAmount, "Token transfer amount mismatch");
        } else {
            revert("Invalid prize type for money contest");
        }

        uint256 contestId = ContestManager.createMoneyContest(
            contests,
            nextContestId,
            numberOfWinners,
            durationDays,
            prizeAmount,
            prizeType,
            tokenAddress
        );
        
        nextContestId = contestId + 1;
    }
    
    // Создание нового конкурса с промокодами в качестве призов
    function createPromocodeContest(
        uint256 numberOfWinners,
        uint256 durationDays,
        string[] calldata promocodes
    ) external {
        uint256 contestId = ContestManager.createPromocodeContest(
            contests,
            nextContestId,
            numberOfWinners,
            durationDays,
            promocodes
        );
        
        nextContestId = contestId + 1;
    }
    
    // Создание смешанного конкурса (с денежными призами и промокодами)
    function createMixedContest(
        uint256 numberOfWinners,
        uint256 durationDays,
        uint256 prizeAmount,
        ContestManager.PrizeType moneyType,
        address tokenAddress,
        string[] calldata promocodes
    ) external payable {
        if (moneyType == ContestManager.PrizeType.ETH) {
            require(msg.value >= prizeAmount, "Insufficient ETH sent for prize");
        } else if (moneyType == ContestManager.PrizeType.TOKEN) {
            require(tokenAddress != address(0), "Token address cannot be zero");
            IERC20 token = IERC20(tokenAddress);
            require(token.allowance(msg.sender, address(this)) >= prizeAmount, "Insufficient token allowance");
            require(token.transferFrom(msg.sender, address(this), prizeAmount), "Token transfer failed");
        } else {
            revert("Invalid money prize type");
        }
        
        uint256 contestId = ContestManager.createMixedContest(
            contests,
            nextContestId,
            numberOfWinners,
            durationDays,
            prizeAmount,
            moneyType,
            tokenAddress,
            promocodes
        );
        
        nextContestId = contestId + 1;
    }
    
    // Добавление промокодов к существующему конкурсу
    function addPromocodesToContest(
        uint256 contestId,
        string[] calldata newPromocodes
    ) external onlyOwner contestExists(contestId) {
        ContestManager.addPromocodes(
            contests,
            contestId,
            newPromocodes
        );
    }

    // Участие в конкурсе - доступно также через вспомогательный контракт
    function joinContest(uint256 contestId, uint256 userId) external contestExists(contestId) contestActive(contestId) {
        ContestManager.Contest storage contest = contests[contestId];
        require(contest.totalParticipants < contest.numberOfWinners * 1000, "Contest is full");

        uint256 participantIndex = ParticipantManager.addParticipant(
            participants,
            nextParticipantIndex,
            contestId,
            msg.sender,
            userId
        );
        
        contest.totalParticipants++;
        nextParticipantIndex[contestId]++;
    }

    // Завершение конкурса и распределение денежных призов
    function completeMoneyContest(
        uint256 contestId, 
        uint256[] calldata winnerIndices, 
        uint256[] calldata prizeAmounts
    ) external onlyOwner contestExists(contestId) {
        ContestManager.Contest storage contest = contests[contestId];
        require(contest.status == ContestManager.ContestStatus.ACTIVE, "Contest is not active");
        require(block.timestamp > contest.endTime, "Contest has not ended yet");
        require(winnerIndices.length == contest.numberOfWinners, "Invalid number of winners");
        require(prizeAmounts.length == contest.numberOfWinners, "Invalid number of prize amounts");
        require(contest.prizeType == ContestManager.PrizeType.ETH || 
                contest.prizeType == ContestManager.PrizeType.TOKEN, 
                "Contest does not support money prizes");
        
        // Проверка общей суммы призов
        uint256 totalPrizeAmount = 0;
        for(uint256 i = 0; i < prizeAmounts.length; i++) {
            totalPrizeAmount += prizeAmounts[i];
        }
        require(totalPrizeAmount <= contest.prizeAmount, "Total prize amount exceeds contest prize");
        
        // Распределение призов победителям
        PrizeManager.distributeMoneyPrizes(
            participants,
            contestId,
            winnerIndices,
            prizeAmounts
        );
        
        // Обновление статусов проигравших
        for(uint256 i = 0; i < contest.totalParticipants; i++) {
            if(participants[contestId][i].status == ParticipantManager.ParticipantStatus.PARTICIPATED) {
                ParticipantManager.updateParticipantStatus(
                    participants,
                    contestId,
                    i,
                    ParticipantManager.ParticipantStatus.LOST
                );
            }
        }
        
        // Завершаем конкурс
        ContestManager.completeContest(
            contests,
            contestId,
            winnerIndices
        );
    }
    
    // Завершение конкурса и распределение промокодов
    function completePromocodeContest(
        uint256 contestId, 
        uint256[] calldata winnerIndices
    ) external onlyOwner contestExists(contestId) {
        ContestManager.Contest storage contest = contests[contestId];
        require(contest.status == ContestManager.ContestStatus.ACTIVE, "Contest is not active");
        require(block.timestamp > contest.endTime, "Contest has not ended yet");
        require(winnerIndices.length == contest.numberOfWinners, "Invalid number of winners");
        require(contest.prizeType == ContestManager.PrizeType.PROMOCODE, "Contest does not support promocode prizes");
        
        // Распределение промокодов победителям
        PrizeManager.distributePromocodePrizes(
            participants,
            contests,
            contestId,
            winnerIndices
        );
        
        // Обновление статусов проигравших
        for(uint256 i = 0; i < contest.totalParticipants; i++) {
            if(participants[contestId][i].status == ParticipantManager.ParticipantStatus.PARTICIPATED) {
                ParticipantManager.updateParticipantStatus(
                    participants,
                    contestId,
                    i,
                    ParticipantManager.ParticipantStatus.LOST
                );
            }
        }
        
        // Завершаем конкурс
        ContestManager.completeContest(
            contests,
            contestId,
            winnerIndices
        );
    }
    
    // Завершение смешанного конкурса и распределение призов
    function completeMixedContest(
        uint256 contestId, 
        uint256[] calldata moneyWinnerIndices, 
        uint256[] calldata prizeAmounts,
        uint256[] calldata promocodeWinnerIndices
    ) external onlyOwner contestExists(contestId) {
        ContestManager.Contest storage contest = contests[contestId];
        require(contest.status == ContestManager.ContestStatus.ACTIVE, "Contest is not active");
        require(block.timestamp > contest.endTime, "Contest has not ended yet");
        require(moneyWinnerIndices.length + promocodeWinnerIndices.length == contest.numberOfWinners, "Invalid number of winners");
        require(moneyWinnerIndices.length == prizeAmounts.length, "Money winners and prize amounts mismatch");
        require(contest.prizeType == ContestManager.PrizeType.MIXED, "Contest is not a mixed type");
        
        // Проверка общей суммы призов
        uint256 totalPrizeAmount = 0;
        for(uint256 i = 0; i < prizeAmounts.length; i++) {
            totalPrizeAmount += prizeAmounts[i];
        }
        require(totalPrizeAmount <= contest.prizeAmount, "Total prize amount exceeds contest prize");
        
        // Распределение смешанных призов
        PrizeManager.distributeMixedPrizes(
            participants,
            contests,
            contestId,
            moneyWinnerIndices,
            prizeAmounts,
            promocodeWinnerIndices
        );
        
        // Обновление статусов проигравших
        for(uint256 i = 0; i < contest.totalParticipants; i++) {
            if(participants[contestId][i].status == ParticipantManager.ParticipantStatus.PARTICIPATED) {
                ParticipantManager.updateParticipantStatus(
                    participants,
                    contestId,
                    i,
                    ParticipantManager.ParticipantStatus.LOST
                );
            }
        }
        
        // Объединяем списки победителей для события завершения конкурса
        uint256[] memory allWinners = new uint256[](moneyWinnerIndices.length + promocodeWinnerIndices.length);
        
        for(uint256 i = 0; i < moneyWinnerIndices.length; i++) {
            allWinners[i] = moneyWinnerIndices[i];
        }
        
        for(uint256 i = 0; i < promocodeWinnerIndices.length; i++) {
            allWinners[moneyWinnerIndices.length + i] = promocodeWinnerIndices[i];
        }
        
        // Завершаем конкурс
        ContestManager.completeContest(
            contests,
            contestId,
            allWinners
        );
    }

    // Получение приза - доступно также через вспомогательный контракт
    function claimPrize(uint256 contestId, uint256 participantIndex) external contestExists(contestId) {
        ContestManager.Contest storage contest = contests[contestId];
        require(contest.status == ContestManager.ContestStatus.COMPLETED, "Contest is not completed");

        ParticipantManager.Participant storage participant = participants[contestId][participantIndex];
        require(participant.wallet == msg.sender, "Not the prize winner");
        require(participant.status == ParticipantManager.ParticipantStatus.WON, "Not a winner");
        require(!participant.hasClaimed, "Prize already claimed");

        // Расчет комиссии с использованием библиотеки CommissionManager
        uint256 commission = 0;
        if (participant.prizeAmount > 0) {
            commission = CommissionManager.calculateCommission(
                participant.prizeAmount, 
                msg.sender, 
                commissionPercentage, 
                noCommissionAddresses
            );
        }

        // Обработка разных типов призов
        if (contest.prizeType == ContestManager.PrizeType.PROMOCODE) {
            // Только промокод
            PrizeManager.claimPromocodePrize(
                participants,
                contestId,
                participantIndex
            );
        } else if (contest.prizeType == ContestManager.PrizeType.MIXED && 
                  bytes(participant.promocode).length > 0) {
            // Смешанный тип приза
            PrizeManager.claimMixedPrize(
                participants,
                contests,
                contestId,
                participantIndex,
                commissionWallet,
                commission
            );
        } else {
            // Только денежный приз
            PrizeManager.claimMoneyPrize(
                participants,
                contests,
                contestId,
                participantIndex,
                commissionWallet,
                commission
            );
        }
    }

    // Функция для обновления денежного призового фонда конкурса
    function updateContestPrize(uint256 contestId, uint256 newPrizeAmount) external payable onlyOwner contestExists(contestId) {
        ContestManager.Contest storage contest = contests[contestId];
        require(contest.status == ContestManager.ContestStatus.ACTIVE, "Contest is not active");
        require(contest.prizeType == ContestManager.PrizeType.ETH || 
                contest.prizeType == ContestManager.PrizeType.TOKEN || 
                contest.prizeType == ContestManager.PrizeType.MIXED, 
                "Contest does not support money prizes");

        if(contest.prizeType == ContestManager.PrizeType.ETH || 
           (contest.prizeType == ContestManager.PrizeType.MIXED && contest.tokenAddress == address(0))) {
            require(msg.value >= newPrizeAmount, "Insufficient ETH sent for new prize");
        } else {
            IERC20 token = IERC20(contest.tokenAddress);
            require(token.allowance(msg.sender, address(this)) >= newPrizeAmount, "Insufficient token allowance");
            require(token.transferFrom(msg.sender, address(this), newPrizeAmount), "Token transfer failed");
        }

        ContestManager.updateMoneyPrize(
            contests,
            contestId,
            newPrizeAmount
        );
    }

    // Функция для продления срока конкурса
    function extendContestDuration(uint256 contestId, uint256 additionalDays) external onlyOwner contestExists(contestId) {
        ContestManager.extendDuration(
            contests,
            contestId,
            additionalDays
        );
    }

    // Функция для отмены конкурса
    function cancelContest(uint256 contestId, string calldata reason) external onlyOwner contestExists(contestId) {
        ContestManager.Contest storage contest = contests[contestId];
        
        ContestManager.cancelContest(
            contests,
            contestId,
            reason
        );

        // Возвращаем призовой фонд создателю конкурса
        if(contest.prizeType == ContestManager.PrizeType.ETH || 
           (contest.prizeType == ContestManager.PrizeType.MIXED && contest.tokenAddress == address(0))) {
            (bool success, ) = msg.sender.call{value: contest.prizeAmount}("");
            require(success, "ETH refund failed");
        } else if (contest.prizeType == ContestManager.PrizeType.TOKEN ||
                  (contest.prizeType == ContestManager.PrizeType.MIXED && contest.tokenAddress != address(0))) {
            IERC20 token = IERC20(contest.tokenAddress);
            require(token.transfer(msg.sender, contest.prizeAmount), "Token refund failed");
        }
    }

    // Функция для удаления участника из конкурса
    function removeParticipant(uint256 contestId, uint256 participantIndex) external onlyOwner contestExists(contestId) {
        ContestManager.Contest storage contest = contests[contestId];
        require(contest.status == ContestManager.ContestStatus.ACTIVE, "Contest is not active");
        require(participantIndex < contest.totalParticipants, "Invalid participant index");

        contest.totalParticipants = ParticipantManager.removeParticipant(
            participants,
            contestId,
            participantIndex,
            contest.totalParticipants
        );
    }

    // Функция для вывода призового фонда (только для владельца)
    function withdrawContestPrize(uint256 contestId) external onlyOwner contestExists(contestId) {
        ContestManager.Contest storage contest = contests[contestId];
        require(contest.status == ContestManager.ContestStatus.COMPLETED, "Contest must be completed");
        require(contest.prizeType != ContestManager.PrizeType.PROMOCODE, "Contest has no money prize to withdraw");

        uint256 remainingPrize = ContestManager.calculateRemainingPrize(
            contests,
            contestId,
            participants
        );

        PrizeManager.withdrawUnusedPrize(
            contests,
            contestId,
            msg.sender,
            remainingPrize
        );
    }

    // Геттеры - доступны также через вспомогательный контракт
    function getContest(uint256 contestId) external view returns (ContestManager.Contest memory) {
        return ContestManager.getContest(contests, contestId);
    }

    function getParticipant(uint256 contestId, uint256 participantIndex) external view returns (ParticipantManager.Participant memory) {
        return participants[contestId][participantIndex];
    }

    function getContestParticipants(uint256 contestId) external view returns (ParticipantManager.Participant[] memory) {
        ContestManager.Contest storage contest = contests[contestId];
        return ParticipantManager.getContestParticipants(
            participants,
            contestId,
            contest.totalParticipants
        );
    }

    function getContestWinners(uint256 contestId) external view returns (ParticipantManager.Participant[] memory) {
        ContestManager.Contest storage contest = contests[contestId];
        require(contest.status == ContestManager.ContestStatus.COMPLETED, "Contest is not completed");
        
        return ParticipantManager.getContestWinners(
            participants,
            contestId,
            contest.totalParticipants
        );
    }
    
    // Функция для получения промокодов из конкурса
    function getContestPromocodes(uint256 contestId) external view onlyOwner contestExists(contestId) returns (string[] memory) {
        return contests[contestId].promocodes;
    }

    // Функция для приема ETH
    receive() external payable {}
} 