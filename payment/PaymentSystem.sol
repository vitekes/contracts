// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./PaymentLibrary.sol";
import "./SubscriptionManager.sol";

/**
 * @title PaymentSystem - Система платежей и управления подписками
 * @dev Основной контракт для управления финансовыми операциями в сети Ethereum
 */
contract PaymentSystem {
    address public owner;
    address public commissionWallet;
    uint256 public commissionPercentage; // в сотых долях процента (например, 100 = 1%, 1000 = 10%)
    
    // Список адресов, освобожденных от комиссии
    mapping(address => bool) public noCommissionAddresses;
    
    // Маппинги для управления платежами
    mapping(bytes32 => PaymentLibrary.Payment) private payments;
    mapping(address => PaymentLibrary.UserInfo) private userInfo;
    
    // Маппинг для подписок
    mapping(bytes32 => SubscriptionManager.Subscription) private subscriptions;
    
    // События
    event PaymentCreated(bytes32 paymentId, uint256 amount, address payer, address recipient);
    event PaymentCompleted(bytes32 paymentId, uint256 amount, uint256 commission, address payer, address recipient);
    event PaymentCancelled(bytes32 paymentId, address payer, address recipient);
    event PaymentRefunded(bytes32 paymentId, uint256 amount, address payer);
    
    event CommissionWalletUpdated(address oldWallet, address newWallet);
    event CommissionPercentageUpdated(uint256 oldPercentage, uint256 newPercentage);
    event NoCommissionStatusUpdated(address user, bool status);
    
    event ProductPurchased(bytes32 paymentId, string productId, uint256 amount, address buyer, address seller);
    event DonationMade(bytes32 paymentId, string message, uint256 amount, address donor, address recipient);
    event SubscriptionStarted(bytes32 subscriptionId, string planId, uint256 amount, address subscriber, address provider);
    event SubscriptionRenewed(bytes32 subscriptionId, uint256 amount, address subscriber, address provider);
    event SubscriptionCancelled(bytes32 subscriptionId, address subscriber, address provider);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized: only the owner can call this function");
        _;
    }
    
    /**
     * @dev Конструктор контракта
     * @param _commissionWallet Адрес кошелька для комиссий
     * @param _commissionPercentage Процент комиссии (в сотых долях)
     */
    constructor(address _commissionWallet, uint256 _commissionPercentage) {
        owner = msg.sender;
        commissionWallet = _commissionWallet;
        commissionPercentage = _commissionPercentage;
    }
    
    // Функции управления комиссией
    
    /**
     * @dev Устанавливает новый адрес для комиссий
     * @param _newWallet Новый адрес кошелька
     */
    function setCommissionWallet(address _newWallet) external onlyOwner {
        require(_newWallet != address(0), "The new wallet cannot be a null address");
        address oldWallet = commissionWallet;
        commissionWallet = _newWallet;
        emit CommissionWalletUpdated(oldWallet, _newWallet);
    }
    
    /**
     * @dev Устанавливает новый процент комиссии
     * @param _newPercentage Новый процент (в сотых долях)
     */
    function setCommissionPercentage(uint256 _newPercentage) external onlyOwner {
        require(_newPercentage <= 10000, "The commission percentage cannot exceed 100%"); // Максимум 100%
        uint256 oldPercentage = commissionPercentage;
        commissionPercentage = _newPercentage;
        emit CommissionPercentageUpdated(oldPercentage, _newPercentage);
    }
    
    /**
     * @dev Устанавливает статус освобождения от комиссии
     * @param _address Адрес пользователя
     * @param _status Статус освобождения
     */
    function setNoCommissionAddress(address _address, bool _status) external onlyOwner {
        noCommissionAddresses[_address] = _status;
        emit NoCommissionStatusUpdated(_address, _status);
    }
    
    // Вспомогательные функции
    
    /**
     * @dev Рассчитывает комиссию для платежа
     * @param _amount Сумма платежа
     * @param _payer Адрес плательщика
     * @return Сумма комиссии
     */
    function calculateCommission(uint256 _amount, address _payer) internal view returns (uint256) {
        if (noCommissionAddresses[_payer]) {
            return 0;
        }
        return (_amount * commissionPercentage) / 10000;
    }
    
    /**
     * @dev Генерирует уникальный ID платежа
     * @param _payer Адрес плательщика
     * @param _recipient Адрес получателя
     * @param _nonce Порядковый номер платежа
     * @return ID платежа
     */
    function generatePaymentId(address _payer, address _recipient, uint256 _nonce) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_payer, _recipient, _nonce));
    }
    
    /**
     * @dev Покупка продукта
     * @param _seller Адрес продавца
     * @param _productId ID продукта
     * @param _amount Сумма платежа
     * @param _isEth Использовать ETH или токен ERC20
     * @return ID платежа
     */
    function purchaseProduct(
        address _seller, 
        string calldata _productId,
        uint256 _amount,
        bool _isEth
    ) external payable returns (bytes32) {
        // Проверка оплаты
        validatePayment(_amount, _isEth);
        
        // Создаем платеж
        bytes32 paymentId = createPayment(_seller, _amount, _isEth);
        
        // Обновляем информацию о покупке
        PaymentLibrary.Payment storage payment = payments[paymentId];
        payment.paymentType = PaymentLibrary.PaymentType.PRODUCT;
        payment.metadata = _productId;
        
        emit ProductPurchased(paymentId, _productId, _amount, msg.sender, _seller);
        
        return paymentId;
    }
    
    /**
     * @dev Проверяет возможность платежа
     * @param _amount Сумма платежа
     * @param _isEth Использовать ETH или токен ERC20
     */
    function validatePayment(uint256 _amount, bool _isEth) private view {
        if (_isEth) {
            require(msg.value >= _amount, "Insufficient ETH for payment");
        } else {
            address tokenAddress = userInfo[msg.sender].preferredToken;
            require(tokenAddress != address(0), "The preferred token is not set");
        }
    }
    
    /**
     * @dev Отправка пожертвования
     * @param _recipient Адрес получателя
     * @param _message Сообщение
     * @param _amount Сумма платежа
     * @param _isEth Использовать ETH или токен ERC20
     * @return ID платежа
     */
    function makeDonation(
        address _recipient, 
        string calldata _message,
        uint256 _amount,
        bool _isEth
    ) external payable returns (bytes32) {
        // Проверка оплаты
        validatePayment(_amount, _isEth);
        
        // Создаем платеж
        bytes32 paymentId = createPayment(_recipient, _amount, _isEth);
        
        // Обновляем информацию о донате
        PaymentLibrary.Payment storage payment = payments[paymentId];
        payment.paymentType = PaymentLibrary.PaymentType.DONATION;
        payment.metadata = _message;
        
        emit DonationMade(paymentId, _message, _amount, msg.sender, _recipient);
        
        return paymentId;
    }
    
    /**
     * @dev Создает подписку
     * @param _provider Адрес поставщика услуг
     * @param _planId ID плана подписки
     * @param _amount Сумма первого платежа
     * @param _intervalDays Интервал между платежами
     * @param _isEth Использовать ETH или токен ERC20
     * @return ID подписки
     */
    function createSubscription(
        address _provider, 
        string calldata _planId,
        uint256 _amount,
        uint256 _intervalDays,
        bool _isEth
    ) external payable returns (bytes32) {
        // Проверка оплаты
        validatePayment(_amount, _isEth);
        
        // Создаем начальный платеж для подписки
        bytes32 paymentId = createPayment(_provider, _amount, _isEth);
        
        // Обновляем информацию о платеже
        PaymentLibrary.Payment storage payment = payments[paymentId];
        payment.paymentType = PaymentLibrary.PaymentType.SUBSCRIPTION;
        
        // Создаем подписку
        bytes32 subscriptionId = SubscriptionManager.createSubscription(
            subscriptions,
            msg.sender,
            _provider,
            _planId,
            _amount,
            _intervalDays,
            _isEth,
            block.timestamp
        );
        
        // Связываем платеж с подпиской
        payment.metadata = SubscriptionManager.subscriptionIdToString(subscriptionId);
        
        emit SubscriptionStarted(subscriptionId, _planId, _amount, msg.sender, _provider);
        
        return subscriptionId;
    }
    
    /**
     * @dev Продлевает подписку
     * @param _subscriptionId ID подписки
     * @return ID платежа
     */
    function renewSubscription(bytes32 _subscriptionId) external payable returns (bytes32) {
        SubscriptionManager.Subscription storage subscription = subscriptions[_subscriptionId];
        
        require(subscription.subscriber == msg.sender, "Only the subscriber can renew the subscription.");
        require(subscription.active, "The subscription is not active");
        
        // Проверка оплаты
        if (subscription.isEth) {
            require(msg.value >= subscription.amount, "Insufficient ETH to renew your subscription");
        }
        
        // Создаем платеж для продления подписки
        bytes32 paymentId = createPayment(subscription.provider, subscription.amount, subscription.isEth);
        
        // Обновляем информацию о платеже
        PaymentLibrary.Payment storage payment = payments[paymentId];
        payment.paymentType = PaymentLibrary.PaymentType.SUBSCRIPTION;
        payment.metadata = SubscriptionManager.subscriptionIdToString(_subscriptionId);
        
        // Обновляем дату следующего платежа
        subscription.nextPaymentTimestamp = block.timestamp + (subscription.intervalDays * 1 days);
        
        emit SubscriptionRenewed(_subscriptionId, subscription.amount, msg.sender, subscription.provider);
        
        return paymentId;
    }
    
    /**
     * @dev Отменяет подписку
     * @param _subscriptionId ID подписки
     */
    function cancelSubscription(bytes32 _subscriptionId) external {
        SubscriptionManager.Subscription storage subscription = subscriptions[_subscriptionId];
        
        require(subscription.subscriber == msg.sender || 
                subscription.provider == msg.sender || 
                msg.sender == owner, 
                "You cannot cancel another user's subscription.");
        require(subscription.active, "The subscription is not active");
        
        SubscriptionManager.deactivateSubscription(subscriptions, _subscriptionId);
        
        emit SubscriptionCancelled(_subscriptionId, subscription.subscriber, subscription.provider);
    }
    
    /**
     * @dev Создает новый платеж
     * @param _recipient Адрес получателя
     * @param _amount Сумма платежа
     * @param _isEth Использовать ETH или токен ERC20
     * @return ID платежа
     */
    function createPayment(
        address _recipient, 
        uint256 _amount,
        bool _isEth
    ) internal returns (bytes32) {
        require(_recipient != address(0), "The recipient cannot be a null address");
        require(_amount > 0, "The amount must be greater than zero");
        
        // Получаем nonce для нового платежа
        uint256 nonce = userInfo[msg.sender].paymentCount;
        bytes32 paymentId = generatePaymentId(msg.sender, _recipient, nonce);
        
        // Обрабатываем токен, если это не ETH
        if (!_isEth) {
            address tokenAddress = userInfo[msg.sender].preferredToken;
            require(tokenAddress != address(0), "The preferred token is not set");
            
            IERC20 token = IERC20(tokenAddress);
            require(token.allowance(msg.sender, address(this)) >= _amount, "Token is not allowed");
            require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
        }
        
        // Создаем запись о платеже
        payments[paymentId] = PaymentLibrary.Payment({
            id: paymentId,
            payer: msg.sender,
            recipient: _recipient,
            amount: _isEth ? msg.value : _amount,
            isEth: _isEth,
            tokenAddress: _isEth ? address(0) : userInfo[msg.sender].preferredToken,
            timestamp: block.timestamp,
            status: PaymentLibrary.PaymentStatus.COMPLETED,
            paymentType: PaymentLibrary.PaymentType.GENERIC,
            metadata: ""
        });
        
        // Увеличиваем счетчик платежей пользователя
        userInfo[msg.sender].paymentCount++;
        
        // Завершаем платеж
        return finalizePayment(paymentId, _recipient, _amount, _isEth);
    }
    
    /**
     * @dev Завершает платеж, отправляя средства
     * @param _paymentId ID платежа
     * @param _recipient Адрес получателя
     * @param _amount Сумма платежа
     * @param _isEth Использовать ETH или токен ERC20
     * @return ID платежа
     */
    function finalizePayment(
        bytes32 _paymentId,
        address _recipient,
        uint256 _amount,
        bool _isEth
    ) private returns (bytes32) {
        // Расчет комиссии
        uint256 commission = calculateCommission(_amount, msg.sender);
        uint256 finalAmount = _amount - commission;
        
        // Отправка средств
        transferFunds(_recipient, finalAmount, commissionWallet, commission, _isEth);
        
        emit PaymentCreated(_paymentId, _amount, msg.sender, _recipient);
        emit PaymentCompleted(_paymentId, finalAmount, commission, msg.sender, _recipient);
        
        return _paymentId;
    }
    
    /**
     * @dev Отправляет средства получателю и комиссию
     * @param _recipient Адрес получателя
     * @param _recipientAmount Сумма для получателя
     * @param _commissionWallet Адрес для комиссии
     * @param _commissionAmount Сумма комиссии
     * @param _isEth Использовать ETH или токен ERC20
     */
    function transferFunds(
        address _recipient, 
        uint256 _recipientAmount,
        address _commissionWallet,
        uint256 _commissionAmount,
        bool _isEth
    ) private {
        if (_isEth) {
            // Отправка комиссии, если она не нулевая
            if (_commissionAmount > 0) {
                (bool commissionSuccess, ) = _commissionWallet.call{value: _commissionAmount}("");
                require(commissionSuccess, "The transfer of the commission failed");
            }
            
            // Отправка средств получателю
            (bool recipientSuccess, ) = _recipient.call{value: _recipientAmount}("");
            require(recipientSuccess, "The transfer to the recipient failed");
        } else {
            IERC20 token = IERC20(userInfo[msg.sender].preferredToken);
            
            // Отправка комиссии, если она не нулевая
            if (_commissionAmount > 0) {
                require(token.transfer(_commissionWallet, _commissionAmount), "The transfer of the commission by token failed");
            }
            
            // Отправка средств получателю
            require(token.transfer(_recipient, _recipientAmount), "The transfer of the token to the recipient failed");
        }
    }
    
    /**
     * @dev Устанавливает предпочитаемый токен для пользователя
     * @param _tokenAddress Адрес токена ERC20
     */
    function setPreferredToken(address _tokenAddress) external {
        require(_tokenAddress != address(0), "The token address cannot be null");
        userInfo[msg.sender].preferredToken = _tokenAddress;
    }
    
    /**
     * @dev Получает информацию о платеже
     * @param _paymentId ID платежа
     * @return Информация о платеже
     */
    function getPayment(bytes32 _paymentId) external view returns (
        address payer,
        address recipient,
        uint256 amount,
        bool isEth,
        address tokenAddress,
        uint256 timestamp,
        PaymentLibrary.PaymentStatus status,
        PaymentLibrary.PaymentType paymentType,
        string memory metadata
    ) {
        PaymentLibrary.Payment storage payment = payments[_paymentId];
        return (
            payment.payer,
            payment.recipient,
            payment.amount,
            payment.isEth,
            payment.tokenAddress,
            payment.timestamp,
            payment.status,
            payment.paymentType,
            payment.metadata
        );
    }
    
    /**
     * @dev Получает информацию о подписке
     * @param _subscriptionId ID подписки
     * @return Информация о подписке
     */
    function getSubscription(bytes32 _subscriptionId) external view returns (
        address subscriber,
        address provider,
        string memory planId,
        uint256 amount,
        uint256 intervalDays,
        uint256 startTimestamp,
        uint256 nextPaymentTimestamp,
        bool isEth,
        bool active
    ) {
        SubscriptionManager.Subscription storage subscription = subscriptions[_subscriptionId];
        return (
            subscription.subscriber,
            subscription.provider,
            subscription.planId,
            subscription.amount,
            subscription.intervalDays,
            subscription.startTimestamp,
            subscription.nextPaymentTimestamp,
            subscription.isEth,
            subscription.active
        );
    }
    
    // Функция для приема ETH
    receive() external payable {}
} 