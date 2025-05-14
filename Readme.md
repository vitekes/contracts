# Система платежей на Ethereum

Эта система контрактов предоставляет функциональность для обработки платежей, донатов и подписок на блокчейне Ethereum.

## Структура контрактов

1. `PaymentSystem.sol` - основной контракт, реализующий функциональность платежей, донатов и подписок.
2. `SubscriptionManager.sol` - библиотека для управления подписками.
3. `PaymentLibrary.sol` - библиотека для обработки платежей.

## Основные функции

### Оплата товаров
```solidity
function payForProduct(
    uint256 productId,
    address recipient,
    address tokenAddress
) external payable
```
- `productId` - ID товара
- `recipient` - получатель платежа
- `tokenAddress` - адрес токена (или address(0) для ETH)

### Донаты
```solidity
function makeDonation(
    address recipient,
    uint256 recipientId,
    address tokenAddress
) external payable
```
- `recipient` - получатель доната
- `recipientId` - ID получателя
- `tokenAddress` - адрес токена (или address(0) для ETH)

### Подписки
```solidity
function createSubscription(
    address recipient,
    uint256 recipientId,
    uint256 productId,
    uint256 monthlyAmount,
    uint256 durationMonths,
    address tokenAddress
) external payable
```
- `recipient` - получатель платежей по подписке
- `recipientId` - ID получателя
- `productId` - ID продукта или сервиса
- `monthlyAmount` - ежемесячная сумма платежа
- `durationMonths` - продолжительность подписки в месяцах
- `tokenAddress` - адрес токена (или address(0) для ETH)

## Управление комиссиями

```solidity
function setCommissionWallet(address _newWallet) external onlyOwner
function setCommissionPercentage(uint256 _newPercentage) external onlyOwner
```

## Дополнительные функции

Отмена подписки:
```solidity
function cancelSubscription(uint256 subscriptionIndex) external
```

Обработка платежей по подпискам:
```solidity
function processSubscriptionPayments(address subscriber, uint256 subscriptionIndex) external
```

Получение информации о платеже:
```solidity
function getPayment(uint256 paymentId) external view returns (PaymentLibrary.Payment memory)
```

Получение подписок пользователя:
```solidity
function getUserSubscriptions(address user) external view returns (SubscriptionManager.Subscription[] memory)
```

## Преимущества модульного дизайна

1. **Переиспользуемость кода** - общая логика платежей и подписок вынесена в библиотеки
2. **Удобное обслуживание** - проще обновлять отдельные модули
3. **Экономия газа** - библиотеки используют делегированный вызов (DELEGATECALL), что экономит газ
4. **Читаемость кода** - чистая архитектура повышает понимание функциональности

## Пример использования

### Создание контракта
```solidity
PaymentSystem paymentSystem = new PaymentSystem(commissionWalletAddress, 500); // 5% комиссия
```

### Оплата товара ETH
```solidity
paymentSystem.payForProduct{value: 1 ether}(productId, merchantAddress, address(0));
```

### Оплата товара токенами
```solidity
// Сначала одобрите расходование токенов
token.approve(address(paymentSystem), amount);
// Затем выполните платеж
paymentSystem.payForProduct(productId, merchantAddress, tokenAddress);
```

### Создание подписки
```solidity
// Подписка с оплатой ETH
paymentSystem.createSubscription{value: monthlyAmount}(
    serviceProviderAddress, 
    providerId, 
    productId,
    monthlyAmount, 
    12, // 12 месяцев
    address(0)
);

// Подписка с оплатой токенами
token.approve(address(paymentSystem), monthlyAmount);
paymentSystem.createSubscription(
    serviceProviderAddress, 
    providerId,
    productId, 
    monthlyAmount, 
    12, // 12 месяцев
    tokenAddress
);
```
