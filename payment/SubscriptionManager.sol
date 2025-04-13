// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library RecurringPaymentService {
    // Структура для хранения информации о регулярном платеже
    struct RecurringPayment {
        bytes32 id;                  // Уникальный идентификатор платежа
        address client;              // Клиент
        address merchant;            // Получатель платежа
        string planCode;             // Код тарифного плана
        uint256 amount;              // Сумма регулярного платежа
        uint256 period;              // Период между платежами в днях
        uint256 createdAt;           // Время создания регулярного платежа
        uint256 nextPaymentAt;       // Время следующего платежа
        bool isNativeToken;          // Нативный токен или ERC20 токен
        bool enabled;                // Активен ли регулярный платеж
    }
    
    // События
    event RecurringPaymentCreated(bytes32 paymentId, address client, address merchant, string planCode);
    event RecurringPaymentUpdated(bytes32 paymentId, uint256 newAmount, uint256 newPeriod);
    event RecurringPaymentEnabled(bytes32 paymentId);
    event RecurringPaymentDisabled(bytes32 paymentId);
    
    // Функция для создания нового регулярного платежа
    function createRecurringPayment(
        mapping(bytes32 => RecurringPayment) storage recurringPayments,
        address client,
        address merchant,
        string memory planCode,
        uint256 amount,
        uint256 period,
        bool isNativeToken,
        uint256 currentTime
    ) external returns (bytes32) {
        require(merchant != address(0), "Merchant cannot be zero address");
        require(bytes(planCode).length > 0, "Plan code cannot be empty");
        require(amount > 0, "Amount must be greater than zero");
        require(period > 0, "Period must be greater than zero");
        
        // Генерируем уникальный ID регулярного платежа
        bytes32 paymentId = keccak256(abi.encodePacked(client, merchant, planCode, block.timestamp));
        
        // Создаем новый регулярный платеж
        recurringPayments[paymentId] = RecurringPayment({
            id: paymentId,
            client: client,
            merchant: merchant,
            planCode: planCode,
            amount: amount,
            period: period,
            createdAt: currentTime,
            nextPaymentAt: currentTime + (period * 1 days),
            isNativeToken: isNativeToken,
            enabled: true
        });
        
        emit RecurringPaymentCreated(paymentId, client, merchant, planCode);
        
        return paymentId;
    }
    
    // Функция для обновления параметров регулярного платежа
    function updateRecurringPayment(
        mapping(bytes32 => RecurringPayment) storage recurringPayments,
        bytes32 paymentId,
        uint256 newAmount,
        uint256 newPeriod
    ) external returns (bool) {
        RecurringPayment storage recurringPayment = recurringPayments[paymentId];
        
        require(recurringPayment.id == paymentId, "Recurring payment does not exist");
        require(recurringPayment.enabled, "Recurring payment is not enabled");
        require(newAmount > 0, "New amount must be greater than zero");
        require(newPeriod > 0, "New period must be greater than zero");
        
        recurringPayment.amount = newAmount;
        recurringPayment.period = newPeriod;
        
        emit RecurringPaymentUpdated(paymentId, newAmount, newPeriod);
        
        return true;
    }
    
    // Функция для активации регулярного платежа
    function enableRecurringPayment(
        mapping(bytes32 => RecurringPayment) storage recurringPayments,
        bytes32 paymentId,
        uint256 currentTime
    ) external returns (bool) {
        RecurringPayment storage recurringPayment = recurringPayments[paymentId];
        
        require(recurringPayment.id == paymentId, "Recurring payment does not exist");
        require(!recurringPayment.enabled, "Recurring payment is already enabled");
        
        recurringPayment.enabled = true;
        recurringPayment.nextPaymentAt = currentTime + (recurringPayment.period * 1 days);
        
        emit RecurringPaymentEnabled(paymentId);
        
        return true;
    }
    
    // Функция для деактивации регулярного платежа
    function disableRecurringPayment(
        mapping(bytes32 => RecurringPayment) storage recurringPayments,
        bytes32 paymentId
    ) external returns (bool) {
        RecurringPayment storage recurringPayment = recurringPayments[paymentId];
        
        require(recurringPayment.id == paymentId, "Recurring payment does not exist");
        require(recurringPayment.enabled, "Recurring payment is already disabled");
        
        recurringPayment.enabled = false;
        
        emit RecurringPaymentDisabled(paymentId);
        
        return true;
    }
    
    // Функция для получения списка регулярных платежей клиента
    function getClientRecurringPayments(
        mapping(bytes32 => RecurringPayment) storage recurringPayments,
        bytes32[] memory allPaymentIds,
        address client
    ) external view returns (bytes32[] memory) {
        // Сначала подсчитываем количество регулярных платежей клиента
        uint256 count = 0;
        for (uint256 i = 0; i < allPaymentIds.length; i++) {
            if (recurringPayments[allPaymentIds[i]].client == client) {
                count++;
            }
        }
        
        // Создаем массив подходящего размера
        bytes32[] memory clientPayments = new bytes32[](count);
        
        // Заполняем массив
        uint256 index = 0;
        for (uint256 i = 0; i < allPaymentIds.length; i++) {
            if (recurringPayments[allPaymentIds[i]].client == client) {
                clientPayments[index] = allPaymentIds[i];
                index++;
            }
        }
        
        return clientPayments;
    }
    
    // Функция для получения списка регулярных платежей продавца
    function getMerchantRecurringPayments(
        mapping(bytes32 => RecurringPayment) storage recurringPayments,
        bytes32[] memory allPaymentIds,
        address merchant
    ) external view returns (bytes32[] memory) {
        // Сначала подсчитываем количество регулярных платежей продавца
        uint256 count = 0;
        for (uint256 i = 0; i < allPaymentIds.length; i++) {
            if (recurringPayments[allPaymentIds[i]].merchant == merchant) {
                count++;
            }
        }
        
        // Создаем массив подходящего размера
        bytes32[] memory merchantPayments = new bytes32[](count);
        
        // Заполняем массив
        uint256 index = 0;
        for (uint256 i = 0; i < allPaymentIds.length; i++) {
            if (recurringPayments[allPaymentIds[i]].merchant == merchant) {
                merchantPayments[index] = allPaymentIds[i];
                index++;
            }
        }
        
        return merchantPayments;
    }
    
    // Вспомогательная функция для преобразования bytes32 в строку
    function recurringPaymentIdToString(bytes32 paymentId) external pure returns (string memory) {
        bytes memory result = new bytes(64);
        bytes memory characters = "0123456789abcdef";
        
        for (uint256 i = 0; i < 32; i++) {
            uint8 value = uint8(paymentId[i]);
            result[i * 2] = characters[uint8(value >> 4)];
            result[i * 2 + 1] = characters[uint8(value & 0x0f)];
        }
        
        return string(result);
    }
} 