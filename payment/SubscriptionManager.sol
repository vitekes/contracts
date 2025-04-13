// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SubscriptionManager - Библиотека для управления подписками
 * @dev Содержит структуры данных и функции для работы с периодическими платежами
 */
library SubscriptionManager {
    // Структура для хранения информации о подписке
    struct Subscription {
        bytes32 id;                  // Уникальный идентификатор подписки
        address subscriber;          // Подписчик
        address provider;            // Поставщик услуг
        string planId;               // Идентификатор плана подписки
        uint256 amount;              // Сумма регулярного платежа
        uint256 intervalDays;        // Интервал между платежами в днях
        uint256 startTimestamp;      // Время начала подписки
        uint256 nextPaymentTimestamp; // Время следующего платежа
        bool isEth;                  // ETH или токен ERC20
        bool active;                 // Активна ли подписка
    }
    
    // События
    event SubscriptionCreated(bytes32 subscriptionId, address subscriber, address provider, string planId);
    event SubscriptionUpdated(bytes32 subscriptionId, uint256 newAmount, uint256 newIntervalDays);
    event SubscriptionActivated(bytes32 subscriptionId);
    event SubscriptionDeactivated(bytes32 subscriptionId);
    
    /**
     * @dev Создает новую подписку
     * @param subscriptions Маппинг подписок
     * @param subscriber Адрес подписчика
     * @param provider Адрес поставщика услуг
     * @param planId Идентификатор плана подписки
     * @param amount Сумма регулярного платежа
     * @param intervalDays Интервал между платежами в днях
     * @param isEth Использовать ETH или токен ERC20
     * @param currentTimestamp Текущее время
     * @return ID созданной подписки
     */
    function createSubscription(
        mapping(bytes32 => Subscription) storage subscriptions,
        address subscriber,
        address provider,
        string memory planId,
        uint256 amount,
        uint256 intervalDays,
        bool isEth,
        uint256 currentTimestamp
    ) external returns (bytes32) {
        require(provider != address(0), "Адрес поставщика не может быть нулевым");
        require(bytes(planId).length > 0, "ID плана не может быть пустым");
        require(amount > 0, "Сумма должна быть больше нуля");
        require(intervalDays > 0, "Интервал должен быть больше нуля");
        
        // Генерируем уникальный ID подписки
        bytes32 subscriptionId = keccak256(abi.encodePacked(subscriber, provider, planId, block.timestamp));
        
        // Создаем новую подписку
        subscriptions[subscriptionId] = Subscription({
            id: subscriptionId,
            subscriber: subscriber,
            provider: provider,
            planId: planId,
            amount: amount,
            intervalDays: intervalDays,
            startTimestamp: currentTimestamp,
            nextPaymentTimestamp: currentTimestamp + (intervalDays * 1 days),
            isEth: isEth,
            active: true
        });
        
        emit SubscriptionCreated(subscriptionId, subscriber, provider, planId);
        
        return subscriptionId;
    }
    
    /**
     * @dev Обновляет параметры подписки
     * @param subscriptions Маппинг подписок
     * @param subscriptionId ID подписки
     * @param newAmount Новая сумма регулярного платежа
     * @param newIntervalDays Новый интервал между платежами
     * @return Успешность операции
     */
    function updateSubscription(
        mapping(bytes32 => Subscription) storage subscriptions,
        bytes32 subscriptionId,
        uint256 newAmount,
        uint256 newIntervalDays
    ) external returns (bool) {
        Subscription storage subscription = subscriptions[subscriptionId];
        
        require(subscription.id == subscriptionId, "Подписка не существует");
        require(subscription.active, "Подписка не активна");
        require(newAmount > 0, "Новая сумма должна быть больше нуля");
        require(newIntervalDays > 0, "Новый интервал должен быть больше нуля");
        
        subscription.amount = newAmount;
        subscription.intervalDays = newIntervalDays;
        
        emit SubscriptionUpdated(subscriptionId, newAmount, newIntervalDays);
        
        return true;
    }
    
    /**
     * @dev Активирует подписку
     * @param subscriptions Маппинг подписок
     * @param subscriptionId ID подписки
     * @param currentTimestamp Текущее время
     * @return Успешность операции
     */
    function activateSubscription(
        mapping(bytes32 => Subscription) storage subscriptions,
        bytes32 subscriptionId,
        uint256 currentTimestamp
    ) external returns (bool) {
        Subscription storage subscription = subscriptions[subscriptionId];
        
        require(subscription.id == subscriptionId, "Подписка не существует");
        require(!subscription.active, "Подписка уже активна");
        
        subscription.active = true;
        subscription.nextPaymentTimestamp = currentTimestamp + (subscription.intervalDays * 1 days);
        
        emit SubscriptionActivated(subscriptionId);
        
        return true;
    }
    
    /**
     * @dev Деактивирует подписку
     * @param subscriptions Маппинг подписок
     * @param subscriptionId ID подписки
     * @return Успешность операции
     */
    function deactivateSubscription(
        mapping(bytes32 => Subscription) storage subscriptions,
        bytes32 subscriptionId
    ) external returns (bool) {
        Subscription storage subscription = subscriptions[subscriptionId];
        
        require(subscription.id == subscriptionId, "Подписка не существует");
        require(subscription.active, "Подписка уже неактивна");
        
        subscription.active = false;
        
        emit SubscriptionDeactivated(subscriptionId);
        
        return true;
    }
    
    /**
     * @dev Получает список подписок пользователя
     * @param subscriptions Маппинг подписок
     * @param allSubscriptionIds Массив всех ID подписок
     * @param user Адрес пользователя
     * @return Массив ID подписок пользователя
     */
    function getUserSubscriptions(
        mapping(bytes32 => Subscription) storage subscriptions,
        bytes32[] memory allSubscriptionIds,
        address user
    ) external view returns (bytes32[] memory) {
        // Подсчитываем количество подписок пользователя
        uint256 count = 0;
        for (uint256 i = 0; i < allSubscriptionIds.length; i++) {
            if (subscriptions[allSubscriptionIds[i]].subscriber == user) {
                count++;
            }
        }
        
        // Создаем массив подходящего размера
        bytes32[] memory userSubscriptions = new bytes32[](count);
        
        // Заполняем массив
        uint256 index = 0;
        for (uint256 i = 0; i < allSubscriptionIds.length; i++) {
            if (subscriptions[allSubscriptionIds[i]].subscriber == user) {
                userSubscriptions[index] = allSubscriptionIds[i];
                index++;
            }
        }
        
        return userSubscriptions;
    }
    
    /**
     * @dev Получает список подписок поставщика услуг
     * @param subscriptions Маппинг подписок
     * @param allSubscriptionIds Массив всех ID подписок
     * @param provider Адрес поставщика услуг
     * @return Массив ID подписок поставщика
     */
    function getProviderSubscriptions(
        mapping(bytes32 => Subscription) storage subscriptions,
        bytes32[] memory allSubscriptionIds,
        address provider
    ) external view returns (bytes32[] memory) {
        // Подсчитываем количество подписок поставщика
        uint256 count = 0;
        for (uint256 i = 0; i < allSubscriptionIds.length; i++) {
            if (subscriptions[allSubscriptionIds[i]].provider == provider) {
                count++;
            }
        }
        
        // Создаем массив подходящего размера
        bytes32[] memory providerSubscriptions = new bytes32[](count);
        
        // Заполняем массив
        uint256 index = 0;
        for (uint256 i = 0; i < allSubscriptionIds.length; i++) {
            if (subscriptions[allSubscriptionIds[i]].provider == provider) {
                providerSubscriptions[index] = allSubscriptionIds[i];
                index++;
            }
        }
        
        return providerSubscriptions;
    }
    
    /**
     * @dev Преобразует bytes32 в строку
     * @param subscriptionId ID подписки
     * @return Строковое представление ID
     */
    function subscriptionIdToString(bytes32 subscriptionId) external pure returns (string memory) {
        bytes memory result = new bytes(64);
        bytes memory characters = "0123456789abcdef";
        
        for (uint256 i = 0; i < 32; i++) {
            uint8 value = uint8(subscriptionId[i]);
            result[i * 2] = characters[uint8(value >> 4)];
            result[i * 2 + 1] = characters[uint8(value & 0x0f)];
        }
        
        return string(result);
    }
} 