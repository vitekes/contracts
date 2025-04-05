// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./PaymentLibrary.sol";
import "./SubscriptionManager.sol";

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
        require(msg.sender == owner, "Not authorized: Only owner can call this function");
        _;
    }

    constructor(address _commissionWallet, uint256 _commissionPercentage) {
        owner = msg.sender;
        commissionWallet = _commissionWallet;
        commissionPercentage = _commissionPercentage;
    }

    // Функции управления комиссией
    function setCommissionWallet(address _newWallet) external onlyOwner {
        require(_newWallet != address(0), "New wallet cannot be zero address");
        address oldWallet = commissionWallet;
        commissionWallet = _newWallet;
        emit CommissionWalletUpdated(oldWallet, _newWallet);
    }

    function setCommissionPercentage(uint256 _newPercentage) external onlyOwner {
        require(_newPercentage <= 10000, "Commission percentage cannot exceed 100%"); // Максимум 100%
        uint256 oldPercentage = commissionPercentage;
        commissionPercentage = _newPercentage;
        emit CommissionPercentageUpdated(oldPercentage, _newPercentage);
    }

    function setNoCommissionAddress(address _address, bool _status) external onlyOwner {
        noCommissionAddresses[_address] = _status;
        emit NoCommissionStatusUpdated(_address, _status);
    }

    // Вспомогательные функции
    function calculateCommission(uint256 _amount, address _payer) internal view returns (uint256) {
        if (noCommissionAddresses[_payer]) {
            return 0;
        }
        return (_amount * commissionPercentage) / 10000;
    }

    function generatePaymentId(address _payer, address _recipient, uint256 _nonce) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_payer, _recipient, _nonce));
    }

    // Функции для покупки продуктов
    function purchaseProduct(
        address _seller,
        string calldata _productId,
        uint256 _amount,
        bool _isEth
    ) external payable returns (bytes32) {
        if (_isEth) {
            require(msg.value >= _amount, "Insufficient ETH sent for payment");
        } else {
            // Проверка на баланс и разрешения для токенов ERC20 будет в createPayment
        }

        bytes32 paymentId = createPayment(_seller, _amount, _isEth);

        // Обновляем информацию о покупке
        PaymentLibrary.Payment storage payment = payments[paymentId];
        payment.paymentType = PaymentLibrary.PaymentType.PRODUCT;
        payment.metadata = _productId;

        emit ProductPurchased(paymentId, _productId, _amount, msg.sender, _seller);

        return paymentId;
    }

    // Функции для донатов
    function donate(
        address _recipient,
        string calldata _message,
        uint256 _amount,
        bool _isEth
    ) external payable returns (bytes32) {
        if (_isEth) {
            require(msg.value >= _amount, "Insufficient ETH sent for donation");
        } else {
            // Проверка на баланс и разрешения для токенов ERC20 будет в createPayment
        }

        bytes32 paymentId = createPayment(_recipient, _amount, _isEth);

        // Обновляем информацию о донате
        PaymentLibrary.Payment storage payment = payments[paymentId];
        payment.paymentType = PaymentLibrary.PaymentType.DONATION;
        payment.metadata = _message;

        emit DonationMade(paymentId, _message, _amount, msg.sender, _recipient);

        return paymentId;
    }

    // Функции для подписок
    function createSubscription(
        address _provider,
        string calldata _planId,
        uint256 _amount,
        uint256 _intervalDays,
        bool _isEth
    ) external payable returns (bytes32) {
        if (_isEth) {
            require(msg.value >= _amount, "Insufficient ETH sent for subscription");
        } else {
            // Проверка на баланс и разрешения для токенов ERC20 будет в createPayment
        }

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

    function renewSubscription(bytes32 _subscriptionId) external payable returns (bytes32) {
        SubscriptionManager.Subscription storage subscription = subscriptions[_subscriptionId];

        require(subscription.subscriber == msg.sender, "Only subscriber can renew");
        require(subscription.active, "Subscription is not active");

        if (subscription.isEth) {
            require(msg.value >= subscription.amount, "Insufficient ETH sent for renewal");
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

    function cancelSubscription(bytes32 _subscriptionId) external {
        SubscriptionManager.Subscription storage subscription = subscriptions[_subscriptionId];

        require(subscription.subscriber == msg.sender ||
        subscription.provider == msg.sender ||
        msg.sender == owner,
            "Not authorized to cancel subscription");
        require(subscription.active, "Subscription is not active");

        subscription.active = false;

        emit SubscriptionCancelled(_subscriptionId, subscription.subscriber, subscription.provider);
    }

    // Базовая функция для создания платежа
    function createPayment(
        address _recipient,
        uint256 _amount,
        bool _isEth
    ) internal returns (bytes32) {
        require(_recipient != address(0), "Recipient cannot be zero address");
        require(_amount > 0, "Amount must be greater than zero");

        // Получаем nonce для нового платежа
        uint256 nonce = userInfo[msg.sender].paymentCount;
        bytes32 paymentId = generatePaymentId(msg.sender, _recipient, nonce);

        // Обрабатываем токен, если это не ETH
        if (!_isEth) {
            address tokenAddress = userInfo[msg.sender].preferredToken;
            require(tokenAddress != address(0), "No preferred token set");

            IERC20 token = IERC20(tokenAddress);
            require(token.allowance(msg.sender, address(this)) >= _amount, "Insufficient token allowance");
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

        // Расчет комиссии
        uint256 commission = calculateCommission(_amount, msg.sender);
        uint256 finalAmount = _amount - commission;

        // Отправка средств получателю и комиссии на соответствующий адрес
        if (_isEth) {
            // Отправка комиссии, если она не нулевая
            if (commission > 0) {
                (bool commissionSuccess,) = commissionWallet.call{value: commission}("");
                require(commissionSuccess, "Commission transfer failed");
            }

            // Отправка средств получателю
            (bool recipientSuccess,) = _recipient.call{value: finalAmount}("");
            require(recipientSuccess, "Recipient transfer failed");
        } else {
            IERC20 token = IERC20(userInfo[msg.sender].preferredToken);

            // Отправка комиссии, если она не нулевая
            if (commission > 0) {
                require(token.transfer(commissionWallet, commission), "Commission token transfer failed");
            }

            // Отправка средств получателю
            require(token.transfer(_recipient, finalAmount), "Recipient token transfer failed");
        }

        emit PaymentCreated(paymentId, _amount, msg.sender, _recipient);
        emit PaymentCompleted(paymentId, finalAmount, commission, msg.sender, _recipient);

        return paymentId;
    }

    // Пользовательские настройки
    function setPreferredToken(address _tokenAddress) external {
        require(_tokenAddress != address(0), "Token address cannot be zero");
        userInfo[msg.sender].preferredToken = _tokenAddress;
    }

    // Геттеры (для получения информации)
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