// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TransactionHelper {
    // Тип транзакции
    enum TransactionType {
        BASIC,     // Обычная транзакция
        PURCHASE,  // Покупка товара
        SUPPORT,   // Поддержка
        RECURRING  // Регулярный платеж
    }
    
    // Статус транзакции
    enum TransactionStatus {
        WAITING,   // Ожидает подтверждения
        FINALIZED, // Завершена
        REVOKED,   // Отменена
        RETURNED   // Возвращена
    }
    
    // Структура для хранения информации о транзакции
    struct Transaction {
        bytes32 id;            // Уникальный идентификатор транзакции
        address sender;        // Отправитель
        address receiver;      // Получатель
        uint256 value;         // Сумма транзакции
        bool isNative;         // Нативная валюта или токен
        address tokenContract; // Адрес контракта токена
        uint256 timestamp;     // Время создания транзакции
        TransactionStatus status;  // Статус транзакции
        TransactionType transactionType; // Тип транзакции
        string data;           // Дополнительные данные
    }
    
    // Информация о пользователе
    struct ClientInfo {
        address defaultToken;  // Предпочитаемый токен для транзакций
        uint256 transactionCount;  // Количество совершенных транзакций
    }
    
    // Функция для отмены транзакции
    function revokeTransaction(
        mapping(bytes32 => Transaction) storage transactions,
        bytes32 transactionId
    ) external returns (bool) {
        Transaction storage transaction = transactions[transactionId];
        
        require(transaction.id == transactionId, "Transaction does not exist");
        require(transaction.status == TransactionStatus.WAITING, "Transaction cannot be revoked");
        
        transaction.status = TransactionStatus.REVOKED;
        return true;
    }
    
    // Функция для возврата средств
    function returnTransaction(
        mapping(bytes32 => Transaction) storage transactions,
        bytes32 transactionId
    ) external returns (bool) {
        Transaction storage transaction = transactions[transactionId];
        
        require(transaction.id == transactionId, "Transaction does not exist");
        require(transaction.status == TransactionStatus.FINALIZED, "Transaction must be finalized to return");
        
        transaction.status = TransactionStatus.RETURNED;
        return true;
    }
} 