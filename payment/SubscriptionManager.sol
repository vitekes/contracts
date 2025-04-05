// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
    
    // Функция для создания новой подписки
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
        require(provider != address(0), "Provider cannot be zero address");
        require(bytes(planId).length > 0, "Plan ID cannot be empty");
        require(amount > 0, "Amount must be greater than zero");
        require(intervalDays > 0, "Interval must be greater than zero");
        
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
    
    // Функция для обновления параметров подписки
    function updateSubscription(
        mapping(bytes32 => Subscription) storage subscriptions,
        bytes32 subscriptionId,
        uint256 newAmount,
        uint256 newIntervalDays
    ) external returns (bool) {
        Subscription storage subscription = subscriptions[subscriptionId];
        
        require(subscription.id == subscriptionId, "Subscription does not exist");
        require(subscription.active, "Subscription is not active");
        require(newAmount > 0, "New amount must be greater than zero");
        require(newIntervalDays > 0, "New interval must be greater than zero");
        
        subscription.amount = newAmount;
        subscription.intervalDays = newIntervalDays;
        
        emit SubscriptionUpdated(subscriptionId, newAmount, newIntervalDays);
        
        return true;
    }
    
    // Функция для активации подписки
    function activateSubscription(
        mapping(bytes32 => Subscription) storage subscriptions,
        bytes32 subscriptionId,
        uint256 currentTimestamp
    ) external returns (bool) {
        Subscription storage subscription = subscriptions[subscriptionId];
        
        require(subscription.id == subscriptionId, "Subscription does not exist");
        require(!subscription.active, "Subscription is already active");
        
        subscription.active = true;
        subscription.nextPaymentTimestamp = currentTimestamp + (subscription.intervalDays * 1 days);
        
        emit SubscriptionActivated(subscriptionId);
        
        return true;
    }
    
    // Функция для деактивации подписки
    function deactivateSubscription(
        mapping(bytes32 => Subscription) storage subscriptions,
        bytes32 subscriptionId
    ) external returns (bool) {
        Subscription storage subscription = subscriptions[subscriptionId];
        
        require(subscription.id == subscriptionId, "Subscription does not exist");
        require(subscription.active, "Subscription is already inactive");
        
        subscription.active = false;
        
        emit SubscriptionDeactivated(subscriptionId);
        
        return true;
    }
    
    // Функция для получения списка подписок пользователя
    function getUserSubscriptions(
        mapping(bytes32 => Subscription) storage subscriptions,
        bytes32[] memory allSubscriptionIds,
        address user
    ) external view returns (bytes32[] memory) {
        // Сначала подсчитываем количество подписок пользователя
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
    
    // Функция для получения списка подписок поставщика услуг
    function getProviderSubscriptions(
        mapping(bytes32 => Subscription) storage subscriptions,
        bytes32[] memory allSubscriptionIds,
        address provider
    ) external view returns (bytes32[] memory) {
        // Сначала подсчитываем количество подписок поставщика
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
    
    // Вспомогательная функция для преобразования bytes32 в строку
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