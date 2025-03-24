// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITRC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract TronLotterySystem {
    address public admin;
    address public feeCollector;
    uint256 public feeRate; // Процент комиссии (например, 100 = 1%, 1000 = 10%)

    // Список адресов, освобожденных от комиссии
    mapping(address => bool) public noFeeAddresses;

    enum PrizeType { TRX, TOKEN }
    enum ParticipantStatus { PARTICIPATED, WON, CLAIMED, LOST }
    enum ContestStatus { ACTIVE, COMPLETED }

    struct Contest {
        uint256 id;
        uint256 numberOfWinners;
        uint256 endTime;
        uint256 prizeAmount;
        PrizeType prizeType;
        address tokenAddress; // address(0) для TRX
        ContestStatus status;
        uint256 totalParticipants;
    }

    struct Participant {
        address wallet;
        uint256 userId;
        uint256 contestId;
        ParticipantStatus status;
        uint256 prizeAmount;
        bool hasClaimed;
    }

    // Маппинги для хранения данных
    mapping(uint256 => Contest) public contests;
    mapping(uint256 => mapping(uint256 => Participant)) public participants; // contestId => participantIndex => Participant
    mapping(uint256 => uint256) public nextParticipantIndex; // contestId => nextIndex

    uint256 public nextContestId = 1;

    // События
    event ContestCreated(
        uint256 indexed contestId,
        uint256 numberOfWinners,
        uint256 endTime,
        uint256 prizeAmount,
        PrizeType prizeType,
        address tokenAddress
    );

    event ParticipantJoined(
        uint256 indexed contestId,
        address indexed wallet,
        uint256 userId
    );

    event ContestCompleted(
        uint256 indexed contestId,
        uint256[] winners
    );

    event PrizeClaimed(
        uint256 indexed contestId,
        address indexed winner,
        uint256 amount
    );

    event FeeCollectorUpdated(address indexed newCollector);
    event FeeRateUpdated(uint256 newRate);
    event NoFeeAddressUpdated(address indexed _address, bool status);

    // Добавляем новые события
    event ContestPrizeUpdated(uint256 indexed contestId, uint256 newPrizeAmount);
    event ContestDurationExtended(uint256 indexed contestId, uint256 newEndTime);
    event ContestCancelled(uint256 indexed contestId, string reason);
    event ParticipantRemoved(uint256 indexed contestId, address indexed participant, uint256 userId);
    event ContestPrizeWithdrawn(uint256 indexed contestId, address indexed withdrawnBy, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier contestExists(uint256 contestId) {
        require(contests[contestId].id != 0, "Contest does not exist");
        _;
    }

    modifier contestActive(uint256 contestId) {
        require(contests[contestId].status == ContestStatus.ACTIVE, "Contest is not active");
        require(block.timestamp <= contests[contestId].endTime, "Contest has ended");
        _;
    }

    constructor(address _feeCollector, uint256 _feeRate) {
        admin = msg.sender;
        feeCollector = _feeCollector;
        feeRate = _feeRate;
    }

    // Функции управления комиссией
    function setFeeCollector(address _newCollector) external onlyAdmin {
        feeCollector = _newCollector;
        emit FeeCollectorUpdated(_newCollector);
    }

    function setFeeRate(uint256 _newRate) external onlyAdmin {
        require(_newRate <= 10000, "Fee rate cannot exceed 100%");
        feeRate = _newRate;
        emit FeeRateUpdated(_newRate);
    }

    function setNoFeeAddress(address _address, bool _status) external onlyAdmin {
        noFeeAddresses[_address] = _status;
        emit NoFeeAddressUpdated(_address, _status);
    }

    // Внутренняя функция для расчета комиссии
    function calculateFee(uint256 amount, address _address) internal view returns (uint256) {
        if (noFeeAddresses[_address]) return 0;
        return (amount * feeRate) / 10000;
    }

    // Создание нового конкурса
    function createContest(
        uint256 numberOfWinners,
        uint256 durationDays,
        uint256 prizeAmount,
        PrizeType prizeType,
        address tokenAddress
    ) external payable {
        require(numberOfWinners > 0, "Number of winners must be greater than 0");
        require(durationDays > 0, "Duration must be greater than 0");
        require(prizeAmount > 0, "Prize amount must be greater than 0");

        if (prizeType == PrizeType.TRX) {
            require(msg.value >= prizeAmount, "Insufficient TRX sent for prize");
        } else {
            require(tokenAddress != address(0), "Token address cannot be zero");
            ITRC20 token = ITRC20(tokenAddress);
            require(token.allowance(msg.sender, address(this)) >= prizeAmount, "Insufficient token allowance");
            require(token.transferFrom(msg.sender, address(this), prizeAmount), "Token transfer failed");
        }

        contests[nextContestId] = Contest({
            id: nextContestId,
            numberOfWinners: numberOfWinners,
            endTime: block.timestamp + (durationDays * 1 days),
            prizeAmount: prizeAmount,
            prizeType: prizeType,
            tokenAddress: tokenAddress,
            status: ContestStatus.ACTIVE,
            totalParticipants: 0
        });

        emit ContestCreated(
            nextContestId,
            numberOfWinners,
            block.timestamp + (durationDays * 1 days),
            prizeAmount,
            prizeType,
            tokenAddress
        );

        nextContestId++;
    }

    // Участие в конкурсе
    function joinContest(uint256 contestId, uint256 userId) external contestExists(contestId) contestActive(contestId) {
        Contest storage contest = contests[contestId];
        require(contest.totalParticipants < contest.numberOfWinners * 1000, "Contest is full");

        uint256 participantIndex = nextParticipantIndex[contestId];
        participants[contestId][participantIndex] = Participant({
            wallet: msg.sender,
            userId: userId,
            contestId: contestId,
            status: ParticipantStatus.PARTICIPATED,
            prizeAmount: 0,
            hasClaimed: false
        });

        contest.totalParticipants++;
        nextParticipantIndex[contestId]++;

        emit ParticipantJoined(contestId, msg.sender, userId);
    }

    // Завершение конкурса и определение победителей
    function completeContest(uint256 contestId, uint256[] calldata winnerIndices, uint256[] calldata prizeAmounts)
        external
        onlyAdmin
        contestExists(contestId)
    {
        Contest storage contest = contests[contestId];
        require(contest.status == ContestStatus.ACTIVE, "Contest is not active");
        require(block.timestamp > contest.endTime, "Contest has not ended yet");
        require(winnerIndices.length == contest.numberOfWinners, "Invalid number of winners");
        require(prizeAmounts.length == contest.numberOfWinners, "Invalid number of prize amounts");

        uint256 totalPrizeAmount = 0;
        for(uint256 i = 0; i < prizeAmounts.length; i++) {
            totalPrizeAmount += prizeAmounts[i];
        }
        require(totalPrizeAmount <= contest.prizeAmount, "Total prize amount exceeds contest prize");

        // Обновляем статусы победителей
        for(uint256 i = 0; i < winnerIndices.length; i++) {
            require(winnerIndices[i] < contest.totalParticipants, "Invalid winner index");
            participants[contestId][winnerIndices[i]].status = ParticipantStatus.WON;
            participants[contestId][winnerIndices[i]].prizeAmount = prizeAmounts[i];
        }

        // Обновляем статусы проигравших
        for(uint256 i = 0; i < contest.totalParticipants; i++) {
            if(participants[contestId][i].status == ParticipantStatus.PARTICIPATED) {
                participants[contestId][i].status = ParticipantStatus.LOST;
            }
        }

        contest.status = ContestStatus.COMPLETED;
        emit ContestCompleted(contestId, winnerIndices);
    }

    // Получение приза
    function claimPrize(uint256 contestId, uint256 participantIndex) external {
        Contest storage contest = contests[contestId];
        require(contest.status == ContestStatus.COMPLETED, "Contest is not completed");

        Participant storage participant = participants[contestId][participantIndex];
        require(participant.wallet == msg.sender, "Not the prize winner");
        require(participant.status == ParticipantStatus.WON, "Not a winner");
        require(!participant.hasClaimed, "Prize already claimed");

        uint256 prizeAmount = participant.prizeAmount;
        uint256 fee = calculateFee(prizeAmount, msg.sender);
        uint256 finalAmount = prizeAmount - fee;

        if(contest.prizeType == PrizeType.TRX) {
            (bool feeSuccess, ) = feeCollector.call{value: fee}("");
            require(feeSuccess, "Fee transfer failed");

            (bool success, ) = msg.sender.call{value: finalAmount}("");
            require(success, "Prize transfer failed");
        } else {
            ITRC20 token = ITRC20(contest.tokenAddress);
            require(token.transfer(feeCollector, fee), "Fee transfer failed");
            require(token.transfer(msg.sender, finalAmount), "Prize transfer failed");
        }

        participant.hasClaimed = true;
        participant.status = ParticipantStatus.CLAIMED;

        emit PrizeClaimed(contestId, msg.sender, prizeAmount);
    }

    // Функция для обновления призового фонда конкурса
    function updateContestPrize(uint256 contestId, uint256 newPrizeAmount) internal  onlyAdmin contestExists(contestId) {
        Contest storage contest = contests[contestId];
        require(contest.status == ContestStatus.ACTIVE, "Contest is not active");
        require(newPrizeAmount > 0, "Prize amount must be greater than 0");

        if(contest.prizeType == PrizeType.TRX) {
            require(msg.value >= newPrizeAmount, "Insufficient TRX sent for new prize");
        } else {
            ITRC20 token = ITRC20(contest.tokenAddress);
            require(token.allowance(msg.sender, address(this)) >= newPrizeAmount, "Insufficient token allowance");
            require(token.transferFrom(msg.sender, address(this), newPrizeAmount), "Token transfer failed");
        }

        contest.prizeAmount = newPrizeAmount;
        emit ContestPrizeUpdated(contestId, newPrizeAmount);
    }

    // Функция для продления срока конкурса
    function extendContestDuration(uint256 contestId, uint256 additionalDays) external onlyAdmin contestExists(contestId) {
        Contest storage contest = contests[contestId];
        require(contest.status == ContestStatus.ACTIVE, "Contest is not active");
        require(additionalDays > 0, "Additional days must be greater than 0");

        contest.endTime += (additionalDays * 1 days);
        emit ContestDurationExtended(contestId, contest.endTime);
    }

    // Функция для отмены конкурса
    function cancelContest(uint256 contestId, string calldata reason) external onlyAdmin contestExists(contestId) {
        Contest storage contest = contests[contestId];
        require(contest.status == ContestStatus.ACTIVE, "Contest is not active");

        contest.status = ContestStatus.COMPLETED;

        // Возвращаем призовой фонд создателю конкурса
        if(contest.prizeType == PrizeType.TRX) {
            (bool success, ) = msg.sender.call{value: contest.prizeAmount}("");
            require(success, "TRX refund failed");
        } else {
            ITRC20 token = ITRC20(contest.tokenAddress);
            require(token.transfer(msg.sender, contest.prizeAmount), "Token refund failed");
        }

        emit ContestCancelled(contestId, reason);
    }

    // Функция для удаления участника из конкурса
    function removeParticipant(uint256 contestId, uint256 participantIndex) external onlyAdmin contestExists(contestId) {
        Contest storage contest = contests[contestId];
        require(contest.status == ContestStatus.ACTIVE, "Contest is not active");
        require(participantIndex < contest.totalParticipants, "Invalid participant index");

        Participant storage participant = participants[contestId][participantIndex];
        require(participant.status == ParticipantStatus.PARTICIPATED, "Can only remove active participants");

        // Сдвигаем последнего участника на место удаляемого
        if(participantIndex < contest.totalParticipants - 1) {
            participants[contestId][participantIndex] = participants[contestId][contest.totalParticipants - 1];
        }

        contest.totalParticipants--;
        emit ParticipantRemoved(contestId, participant.wallet, participant.userId);
    }

    // Функция для вывода призового фонда (только для владельца)
    function withdrawContestPrize(uint256 contestId) external onlyAdmin contestExists(contestId) {
        Contest storage contest = contests[contestId];
        require(contest.status == ContestStatus.COMPLETED, "Contest must be completed");

        uint256 remainingPrize = contest.prizeAmount;
        for(uint256 i = 0; i < contest.totalParticipants; i++) {
            if(participants[contestId][i].status == ParticipantStatus.WON) {
                remainingPrize -= participants[contestId][i].prizeAmount;
            }
        }

        require(remainingPrize > 0, "No remaining prize to withdraw");

        if(contest.prizeType == PrizeType.TRX) {
            (bool success, ) = msg.sender.call{value: remainingPrize}("");
            require(success, "TRX withdrawal failed");
        } else {
            ITRC20 token = ITRC20(contest.tokenAddress);
            require(token.transfer(msg.sender, remainingPrize), "Token withdrawal failed");
        }

        emit ContestPrizeWithdrawn(contestId, msg.sender, remainingPrize);
    }

    // Геттеры
    function getContest(uint256 contestId) external view returns (Contest memory) {
        return contests[contestId];
    }

    function getParticipant(uint256 contestId, uint256 participantIndex) external view returns (Participant memory) {
        return participants[contestId][participantIndex];
    }

    function getContestParticipants(uint256 contestId) external view returns (Participant[] memory) {
        Contest storage contest = contests[contestId];
        Participant[] memory result = new Participant[](contest.totalParticipants);
        for(uint256 i = 0; i < contest.totalParticipants; i++) {
            result[i] = participants[contestId][i];
        }
        return result;
    }

    function getContestWinners(uint256 contestId) external view returns (Participant[] memory) {
        Contest storage contest = contests[contestId];
        require(contest.status == ContestStatus.COMPLETED, "Contest is not completed");

        uint256 winnerCount = 0;
        for(uint256 i = 0; i < contest.totalParticipants; i++) {
            if(participants[contestId][i].status == ParticipantStatus.WON ||
               participants[contestId][i].status == ParticipantStatus.CLAIMED) {
                winnerCount++;
            }
        }

        Participant[] memory winners = new Participant[](winnerCount);
        uint256 currentIndex = 0;

        for(uint256 i = 0; i < contest.totalParticipants; i++) {
            if(participants[contestId][i].status == ParticipantStatus.WON ||
               participants[contestId][i].status == ParticipantStatus.CLAIMED) {
                winners[currentIndex] = participants[contestId][i];
                currentIndex++;
            }
        }

        return winners;
    }

    // Функция для приема TRX
    receive() external payable {}
}