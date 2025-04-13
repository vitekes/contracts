// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title PaymentLibrary - Библиотека для управления платежами
 * @dev Содержит структуры данных и функции для работы с платежами
 */
library PaymentLibrary {
    // Тип платежа
    enum PaymentType {
        GENERIC,    // Обычный платеж
        PRODUCT,    // Покупка продукта
        DONATION,   // Пожертвование
        SUBSCRIPTION // Подписка
    }
    
    // Статус платежа
    enum PaymentStatus {
        PENDING,    // Ожидает подтверждения
        COMPLETED,  // Завершен
        CANCELLED,  // Отменен
        REFUNDED    // Возвращен
    }
    
    // Структура для хранения информации о платеже
    struct Payment {
        bytes32 id;            // Уникальный идентификатор платежа
        address payer;         // Плательщик
        address recipient;     // Получатель
        uint256 amount;        // Сумма платежа
        bool isEth;            // ETH или токен ERC20
        address tokenAddress;  // Адрес токена (для ERC20)
        uint256 timestamp;     // Время создания платежа
        PaymentStatus status;  // Статус платежа
        PaymentType paymentType; // Тип платежа
        string metadata;       // Дополнительные данные (productId, message, subscriptionId)
    }
    
    // Информация о пользователе
    struct UserInfo {
        address preferredToken;  // Предпочитаемый токен для платежей
        uint256 paymentCount;    // Количество совершенных платежей (для генерации nonce)
    }
    
    /**
     * @dev Отменяет платеж
     * @param payments Маппинг платежей
     * @param paymentId ID платежа
     * @return Успешность операции
     */
    function cancelPayment(
        mapping(bytes32 => Payment) storage payments,
        bytes32 paymentId
    ) external returns (bool) {
        Payment storage payment = payments[paymentId];
        
        require(payment.id == paymentId, "The payment does not exist");
        require(payment.status == PaymentStatus.PENDING, "The payment cannot be cancelled");
        
        payment.status = PaymentStatus.CANCELLED;
        return true;
    }
    
    /**
     * @dev Возвращает средства по платежу
     * @param payments Маппинг платежей
     * @param paymentId ID платежа
     * @return Успешность операции
     */
    function refundPayment(
        mapping(bytes32 => Payment) storage payments,
        bytes32 paymentId
    ) external returns (bool) {
        Payment storage payment = payments[paymentId];
        
        require(payment.id == paymentId, "The payment does not exist");
        require(payment.status == PaymentStatus.COMPLETED, "The payment must be completed for a refund");
        
        payment.status = PaymentStatus.REFUNDED;
        return true;
    }
} 