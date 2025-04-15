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
 * @title ContestsPromocodeContract.sol
 * @dev Выносит функционал работы с промокодами в отдельный контракт для уменьшения размера основного
 */
contract ContestsPromocodeContract {
    using SafeMath for uint256;
    
    ContestsContract public mainContract;
    address public owner;
    
    constructor(address _mainContract) {
        require(_mainContract != address(0), "Main contract address cannot be zero");
        mainContract = ContestsContract(_mainContract);
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    // Создание нового конкурса с промокодами в качестве призов
    function createPromocodeContest(
        uint256 numberOfWinners,
        uint256 durationDays,
        string[] calldata promocodes
    ) external onlyOwner {
        // Вызываем метод основного контракта
        mainContract.createPromocodeContest(numberOfWinners, durationDays, promocodes);
    }
    
    // Завершение конкурса и распределение промокодов
    function completePromocodeContest(
        uint256 contestId, 
        uint256[] calldata winnerIndices
    ) external onlyOwner {
        mainContract.completePromocodeContest(contestId, winnerIndices);
    }
    
    // Добавление промокодов к существующему конкурсу
    function addPromocodesToContest(
        uint256 contestId,
        string[] calldata newPromocodes
    ) external onlyOwner {
        mainContract.addPromocodesToContest(contestId, newPromocodes);
    }
    
    // Получение промокодов из конкурса
    function getContestPromocodes(uint256 contestId) external view onlyOwner returns (string[] memory) {
        return mainContract.getContestPromocodes(contestId);
    }
} 