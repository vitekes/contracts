// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// Настройка оптимизатора должна быть в настройках компилятора, а не в директиве pragma

import "./ContestsContract.sol";
import "./ContestsParticipantContract.sol";
import "./ContestsPromocodeContract.sol";

/**
 * @title ContestsContractManager.sol
 * @dev Фабрика для деплоя связанных контрактов системы ContestsContract.sol
 */
contract ContestsContractManager {
    address public owner;
    ContestsContract public mainContract;
    ContestsParticipantContract public participantContract;
    ContestsPromocodeContract public promocodeContract;
    
    event ContractsDeployed(
        address mainContract,
        address participantContract,
        address promocodeContract
    );
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Деплоит все контракты системы и настраивает связи между ними
     * @param _commissionWallet Адрес кошелька для получения комиссий
     * @param _commissionPercentage Процент комиссии (100 = 1%, 1000 = 10%)
     */
    function deployContracts(
        address _commissionWallet,
        uint256 _commissionPercentage
    ) external {
        require(msg.sender == owner, "Only owner can deploy contracts");
        require(address(mainContract) == address(0), "Contracts already deployed");
        
        // Деплоим основной контракт
        mainContract = new ContestsContract(_commissionWallet, _commissionPercentage);
        
        // Деплоим вспомогательные контракты
        participantContract = new ContestsParticipantContract(address(mainContract));
        promocodeContract = new ContestsPromocodeContract(address(mainContract));
        
        // Устанавливаем связи между контрактами
        mainContract.setParticipantContract(address(participantContract));
        
        // Передаем владение контрактами создателю
        transferOwnership(owner);
        
        emit ContractsDeployed(
            address(mainContract),
            address(participantContract),
            address(promocodeContract)
        );
    }
    
    /**
     * @dev Передает владение всеми контрактами указанному адресу
     * @param _newOwner Новый владелец контрактов
     */
    function transferOwnership(address _newOwner) public {
        require(msg.sender == owner, "Only owner can transfer ownership");
        require(_newOwner != address(0), "New owner cannot be zero address");
        
        // TODO: Здесь нужна реализация передачи владения в каждом контракте
        // Это потребует добавления методов transferOwnership в каждый контракт
        
        owner = _newOwner;
    }
} 