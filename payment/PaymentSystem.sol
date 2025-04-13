// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ITokenStandard.sol";
import "./TransactionHelper.sol";
import "./RecurringPaymentService.sol";

contract FinancialOperator {
    address public admin;
    address public feeCollector;
    uint256 public feeRate; // в сотых долях процента (например, 100 = 1%, 1000 = 10%)
    
    // Список адресов, освобожденных от комиссии
    mapping(address => bool) public feeExemptions;
    
    // Маппинги для управления транзакциями
    mapping(bytes32 => TransactionHelper.Transaction) private transactions;
    mapping(address => TransactionHelper.ClientInfo) private clientsInfo;
    
    // Маппинг для регулярных платежей
    mapping(bytes32 => RecurringPaymentService.RecurringPayment) private recurringPayments;
    
    // События
    event TransactionCreated(bytes32 transactionId, uint256 value, address sender, address receiver);
    event TransactionProcessed(bytes32 transactionId, uint256 value, uint256 fee, address sender, address receiver);
    event TransactionRevoked(bytes32 transactionId, address sender, address receiver);
    event TransactionReturned(bytes32 transactionId, uint256 value, address sender);
    
    event FeeCollectorUpdated(address oldCollector, address newCollector);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event FeeExemptionStatusUpdated(address user, bool status);
    
    event ItemPurchased(bytes32 transactionId, string itemId, uint256 value, address buyer, address seller);
    event SupportSent(bytes32 transactionId, string message, uint256 value, address supporter, address receiver);
    event RecurringPaymentStarted(bytes32 paymentId, string planCode, uint256 value, address client, address merchant);
    event RecurringPaymentRenewed(bytes32 paymentId, uint256 value, address client, address merchant);
    event RecurringPaymentCancelled(bytes32 paymentId, address client, address merchant);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Доступ запрещен: только администратор может вызвать эту функцию");
        _;
    }
    
    constructor(address _feeCollector, uint256 _feeRate) {
        admin = msg.sender;
        feeCollector = _feeCollector;
        feeRate = _feeRate;
    }
    
    // Функции управления комиссией
    function setFeeCollector(address _newCollector) external onlyAdmin {
        require(_newCollector != address(0), "Новый адрес сбора комиссии не может быть нулевым");
        address oldCollector = feeCollector;
        feeCollector = _newCollector;
        emit FeeCollectorUpdated(oldCollector, _newCollector);
    }
    
    function setFeeRate(uint256 _newRate) external onlyAdmin {
        require(_newRate <= 10000, "Ставка комиссии не может превышать 100%"); // Максимум 100%
        uint256 oldRate = feeRate;
        feeRate = _newRate;
        emit FeeRateUpdated(oldRate, _newRate);
    }
    
    function setFeeExemption(address _account, bool _status) external onlyAdmin {
        feeExemptions[_account] = _status;
        emit FeeExemptionStatusUpdated(_account, _status);
    }
    
    // Вспомогательные функции
    function calculateFee(uint256 _value, address _sender) internal view returns (uint256) {
        if (feeExemptions[_sender]) {
            return 0;
        }
        return (_value * feeRate) / 10000;
    }
    
    function generateTransactionId(address _sender, address _receiver, uint256 _nonce) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_sender, _receiver, _nonce));
    }
    
    // Функции для покупки товаров
    function purchaseItem(
        address _seller, 
        string calldata _itemId,
        uint256 _value,
        bool _isNative
    ) external payable returns (bytes32) {
        // Проверка оплаты
        validatePayment(_value, _isNative);
        
        // Создаем транзакцию
        bytes32 transactionId = processTransaction(_seller, _value, _isNative);
        
        // Обновляем информацию о покупке
        TransactionHelper.Transaction storage transaction = transactions[transactionId];
        transaction.transactionType = TransactionHelper.TransactionType.PURCHASE;
        transaction.data = _itemId;
        
        emit ItemPurchased(transactionId, _itemId, _value, msg.sender, _seller);
        
        return transactionId;
    }
    
    // Функции для отправки поддержки (донатов)
    function donate(
        address _receiver, 
        string calldata _message,
        uint256 _value,
        bool _isNative
    ) external payable returns (bytes32) {
        // Проверка оплаты
        validatePayment(_value, _isNative);
        
        // Создаем транзакцию
        bytes32 transactionId = processTransaction(_receiver, _value, _isNative);
        
        // Обновляем информацию о поддержке
        TransactionHelper.Transaction storage transaction = transactions[transactionId];
        transaction.transactionType = TransactionHelper.TransactionType.SUPPORT;
        transaction.data = _message;
        
        emit SupportSent(transactionId, _message, _value, msg.sender, _receiver);
        
        return transactionId;
    }
    
    // Функции для регулярных платежей
    function startRecurringPayment(
        address _merchant, 
        string calldata _planCode,
        uint256 _value,
        uint256 _period,
        bool _isNative
    ) external payable returns (bytes32) {
        // Проверка оплаты
        validatePayment(_value, _isNative);
        
        // Создаем начальную транзакцию
        bytes32 transactionId = processTransaction(_merchant, _value, _isNative);
        
        // Обновляем информацию о транзакции
        TransactionHelper.Transaction storage transaction = transactions[transactionId];
        transaction.transactionType = TransactionHelper.TransactionType.RECURRING;
        
        // Создаем регулярный платеж
        bytes32 paymentId = RecurringPaymentService.createRecurringPayment(
            recurringPayments,
            msg.sender,
            _merchant,
            _planCode,
            _value,
            _period,
            _isNative,
            block.timestamp
        );
        
        // Связываем транзакцию с регулярным платежом
        transaction.data = RecurringPaymentService.recurringPaymentIdToString(paymentId);
        
        emit RecurringPaymentStarted(paymentId, _planCode, _value, msg.sender, _merchant);
        
        return paymentId;
    }
    
    function renewRecurringPayment(bytes32 _paymentId) external payable returns (bytes32) {
        RecurringPaymentService.RecurringPayment storage payment = recurringPayments[_paymentId];
        
        require(payment.client == msg.sender, "Только клиент может обновить платеж");
        require(payment.enabled, "Регулярный платеж неактивен");
        
        // Проверка оплаты
        validatePayment(payment.amount, payment.isNativeToken);
        
        // Создаем транзакцию для обновления платежа
        bytes32 transactionId = processTransaction(payment.merchant, payment.amount, payment.isNativeToken);
        
        // Обновляем информацию о транзакции
        TransactionHelper.Transaction storage transaction = transactions[transactionId];
        transaction.transactionType = TransactionHelper.TransactionType.RECURRING;
        transaction.data = RecurringPaymentService.recurringPaymentIdToString(_paymentId);
        
        // Обновляем дату следующего платежа
        payment.nextPaymentAt = block.timestamp + (payment.period * 1 days);
        
        emit RecurringPaymentRenewed(_paymentId, payment.amount, msg.sender, payment.merchant);
        
        return transactionId;
    }
    
    function cancelRecurringPayment(bytes32 _paymentId) external {
        RecurringPaymentService.RecurringPayment storage payment = recurringPayments[_paymentId];
        
        require(payment.client == msg.sender || 
                payment.merchant == msg.sender || 
                msg.sender == admin, 
                "Нет прав для отмены регулярного платежа");
        require(payment.enabled, "Регулярный платеж уже неактивен");
        
        RecurringPaymentService.disableRecurringPayment(recurringPayments, _paymentId);
        
        emit RecurringPaymentCancelled(_paymentId, payment.client, payment.merchant);
    }
    
    // Функция для проверки оплаты
    function validatePayment(uint256 _value, bool _isNative) private view {
        if (_isNative) {
            require(msg.value >= _value, "Недостаточно ETH для операции");
        } else {
            address tokenAddress = clientsInfo[msg.sender].defaultToken;
            require(tokenAddress != address(0), "Не установлен токен по умолчанию");
        }
    }
    
    // Базовая функция для обработки транзакции
    function processTransaction(
        address _receiver, 
        uint256 _value,
        bool _isNative
    ) internal returns (bytes32) {
        require(_receiver != address(0), "Получатель не может быть нулевым адресом");
        require(_value > 0, "Сумма должна быть больше нуля");
        
        // Получаем nonce для новой транзакции
        uint256 nonce = clientsInfo[msg.sender].transactionCount;
        bytes32 transactionId = generateTransactionId(msg.sender, _receiver, nonce);
        
        // Обрабатываем токен, если это не нативная валюта
        if (!_isNative) {
            address tokenAddress = clientsInfo[msg.sender].defaultToken;
            require(tokenAddress != address(0), "Не установлен токен по умолчанию");
            
            ITokenStandard token = ITokenStandard(tokenAddress);
            require(token.allowance(msg.sender, address(this)) >= _value, "Недостаточно одобренных токенов");
            require(token.transferFrom(msg.sender, address(this), _value), "Перевод токена не удался");
        }
        
        // Создаем запись о транзакции
        transactions[transactionId] = TransactionHelper.Transaction({
            id: transactionId,
            sender: msg.sender,
            receiver: _receiver,
            value: _isNative ? msg.value : _value,
            isNative: _isNative,
            tokenContract: _isNative ? address(0) : clientsInfo[msg.sender].defaultToken,
            timestamp: block.timestamp,
            status: TransactionHelper.TransactionStatus.FINALIZED,
            transactionType: TransactionHelper.TransactionType.BASIC,
            data: ""
        });
        
        // Увеличиваем счетчик транзакций клиента
        clientsInfo[msg.sender].transactionCount++;
        
        // Расчет комиссии и перевод средств
        return finalizeTransaction(transactionId, _value, _isNative, _receiver);
    }
    
    // Функция для перевода средств и расчета комиссии
    function finalizeTransaction(
        bytes32 _transactionId, 
        uint256 _value,
        bool _isNative,
        address _receiver
    ) private returns (bytes32) {
        // Расчет комиссии
        uint256 fee = calculateFee(_value, msg.sender);
        uint256 finalValue = _value - fee;
        
        // Отправка средств получателю и комиссии
        transferFunds(_isNative, _receiver, finalValue, feeCollector, fee);
        
        emit TransactionCreated(_transactionId, _value, msg.sender, _receiver);
        emit TransactionProcessed(_transactionId, finalValue, fee, msg.sender, _receiver);
        
        return _transactionId;
    }
    
    // Функция для перевода средств
    function transferFunds(
        bool _isNative,
        address _receiver,
        uint256 _receiverValue,
        address _feeAddress,
        uint256 _feeValue
    ) private {
        if (_isNative) {
            // Отправка комиссии, если она не нулевая
            if (_feeValue > 0) {
                (bool feeSuccess, ) = _feeAddress.call{value: _feeValue}("");
                require(feeSuccess, "Перевод комиссии не удался");
            }
            
            // Отправка средств получателю
            (bool receiverSuccess, ) = _receiver.call{value: _receiverValue}("");
            require(receiverSuccess, "Перевод получателю не удался");
        } else {
            ITokenStandard token = ITokenStandard(clientsInfo[msg.sender].defaultToken);
            
            // Отправка комиссии, если она не нулевая
            if (_feeValue > 0) {
                require(token.transfer(_feeAddress, _feeValue), "Перевод комиссии токеном не удался");
            }
            
            // Отправка средств получателю
            require(token.transfer(_receiver, _receiverValue), "Перевод токеном получателю не удался");
        }
    }
    
    // Пользовательские настройки
    function setDefaultToken(address _tokenAddress) external {
        require(_tokenAddress != address(0), "Адрес токена не может быть нулевым");
        clientsInfo[msg.sender].defaultToken = _tokenAddress;
    }
    
    // Геттеры (для получения информации)
    function getTransaction(bytes32 _transactionId) external view returns (
        address sender,
        address receiver,
        uint256 value,
        bool isNative,
        address tokenContract,
        uint256 timestamp,
        TransactionHelper.TransactionStatus status,
        TransactionHelper.TransactionType transactionType,
        string memory data
    ) {
        TransactionHelper.Transaction storage transaction = transactions[_transactionId];
        return (
            transaction.sender,
            transaction.receiver,
            transaction.value,
            transaction.isNative,
            transaction.tokenContract,
            transaction.timestamp,
            transaction.status,
            transaction.transactionType,
            transaction.data
        );
    }
    
    function getRecurringPayment(bytes32 _paymentId) external view returns (
        address client,
        address merchant,
        string memory planCode,
        uint256 amount,
        uint256 period,
        uint256 createdAt,
        uint256 nextPaymentAt,
        bool isNativeToken,
        bool enabled
    ) {
        RecurringPaymentService.RecurringPayment storage payment = recurringPayments[_paymentId];
        return (
            payment.client,
            payment.merchant,
            payment.planCode,
            payment.amount,
            payment.period,
            payment.createdAt,
            payment.nextPaymentAt,
            payment.isNativeToken,
            payment.enabled
        );
    }
    
    // Функция для приема ETH
    receive() external payable {}
} 