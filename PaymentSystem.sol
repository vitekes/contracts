// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITRC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract TronPaymentSystem {
    address public admin;
    address public feeCollector;
    uint256 public feeRate; // Процент комиссии (например, 100 = 1%, 1000 = 10%)

    enum TransactionType { PURCHASE, DONATION, SUBSCRIPTION }
    enum PaymentMethod { TRX, TOKEN }

    struct Transaction {
        uint256 id;
        address sender;
        address receiver;
        uint256 amount;
        TransactionType txType;
        PaymentMethod paymentMethod;
        address tokenAddress; // address(0) для TRX
        uint256 timestamp;
        uint256 itemId; // для платежей за товар
    }

    struct Subscription {
        address subscriber;
        address provider;
        uint256 providerId;
        uint256 monthlyFee;
        uint256 durationMonths;
        uint256 startTime;
        uint256 lastPaymentTime;
        bool isActive;
        PaymentMethod paymentMethod;
        address tokenAddress;
    }

    mapping(uint256 => Transaction) public transactions;
    mapping(address => Subscription[]) public subscriptions;
    uint256 public nextTransactionId = 1;

    event TransactionProcessed(
        uint256 indexed transactionId,
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        TransactionType txType,
        PaymentMethod paymentMethod,
        address tokenAddress
    );

    event SubscriptionCreated(
        address indexed subscriber,
        address indexed provider,
        uint256 providerId,
        uint256 monthlyFee,
        uint256 durationMonths
    );

    event SubscriptionCancelled(
        address indexed subscriber,
        address indexed provider,
        uint256 providerId
    );

    event SubscriptionPaymentFailed(
        address indexed subscriber,
        address indexed provider,
        uint256 providerId,
        string reason
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    constructor(address _feeCollector, uint256 _feeRate) {
        admin = msg.sender;
        feeCollector = _feeCollector;
        feeRate = _feeRate;
    }

    // Функции для изменения комиссии и кошелька комиссии
    function setFeeCollector(address _newCollector) external onlyAdmin {
        feeCollector = _newCollector;
    }

    function setFeeRate(uint256 _newRate) external onlyAdmin {
        require(_newRate <= 10000, "Fee rate cannot exceed 100%");
        feeRate = _newRate;
    }

    // Внутренняя функция для расчета комиссии
    function calculateFee(uint256 amount) internal view returns (uint256) {
        return (amount * feeRate) / 10000;
    }

    // 1. Оплата товара
    function processPurchase(
        uint256 itemId,
        address receiver,
        address tokenAddress
    ) external payable {
        if(tokenAddress == address(0)) {
            // Оплата в TRX
            require(msg.value > 0, "Amount must be greater than 0");
            uint256 fee = calculateFee(msg.value);
            uint256 finalAmount = msg.value - fee;

            // Отправляем комиссию
            (bool feeSuccess, ) = feeCollector.call{value: fee}("");
            require(feeSuccess, "Fee transfer failed");

            // Отправляем оставшуюся сумму получателю
            (bool success, ) = receiver.call{value: finalAmount}("");
            require(success, "Payment transfer failed");

            // Регистрируем транзакцию
            _registerTransaction(
                msg.sender,
                receiver,
                msg.value,
                TransactionType.PURCHASE,
                PaymentMethod.TRX,
                address(0),
                itemId
            );
        } else {
            // Оплата в токенах
            ITRC20 token = ITRC20(tokenAddress);
            uint256 amount = token.allowance(msg.sender, address(this));
            require(amount > 0, "Token allowance must be greater than 0");

            uint256 fee = calculateFee(amount);
            uint256 finalAmount = amount - fee;

            // Переводим токены
            require(token.transferFrom(msg.sender, feeCollector, fee), "Fee transfer failed");
            require(token.transferFrom(msg.sender, receiver, finalAmount), "Payment transfer failed");

            // Регистрируем транзакцию
            _registerTransaction(
                msg.sender,
                receiver,
                amount,
                TransactionType.PURCHASE,
                PaymentMethod.TOKEN,
                tokenAddress,
                itemId
            );
        }
    }

    // 2. Донат
    function processDonation(
        address receiver,
        uint256 receiverId,
        address tokenAddress
    ) external payable {
        if(tokenAddress == address(0)) {
            // Донат в TRX
            require(msg.value > 0, "Amount must be greater than 0");
            uint256 fee = calculateFee(msg.value);
            uint256 finalAmount = msg.value - fee;

            // Отправляем комиссию
            (bool feeSuccess, ) = feeCollector.call{value: fee}("");
            require(feeSuccess, "Fee transfer failed");

            // Отправляем донат
            (bool success, ) = receiver.call{value: finalAmount}("");
            require(success, "Donation transfer failed");

            _registerTransaction(
                msg.sender,
                receiver,
                msg.value,
                TransactionType.DONATION,
                PaymentMethod.TRX,
                address(0),
                receiverId
            );
        } else {
            // Донат в токенах
            ITRC20 token = ITRC20(tokenAddress);
            uint256 amount = token.allowance(msg.sender, address(this));
            require(amount > 0, "Token allowance must be greater than 0");

            uint256 fee = calculateFee(amount);
            uint256 finalAmount = amount - fee;

            require(token.transferFrom(msg.sender, feeCollector, fee), "Fee transfer failed");
            require(token.transferFrom(msg.sender, receiver, finalAmount), "Donation transfer failed");

            _registerTransaction(
                msg.sender,
                receiver,
                amount,
                TransactionType.DONATION,
                PaymentMethod.TOKEN,
                tokenAddress,
                receiverId
            );
        }
    }

    // 3. Подписка
    function createSubscription(
        address provider,
        uint256 providerId,
        uint256 monthlyFee,
        uint256 durationMonths,
        address tokenAddress
    ) external payable {
        require(durationMonths > 0, "Duration must be greater than 0");
        require(monthlyFee > 0, "Monthly fee must be greater than 0");

        PaymentMethod paymentMethod = tokenAddress == address(0) ? PaymentMethod.TRX : PaymentMethod.TOKEN;

        // Создаем подписку
        Subscription memory newSub = Subscription({
            subscriber: msg.sender,
            provider: provider,
            providerId: providerId,
            monthlyFee: monthlyFee,
            durationMonths: durationMonths,
            startTime: block.timestamp,
            lastPaymentTime: block.timestamp,
            isActive: true,
            paymentMethod: paymentMethod,
            tokenAddress: tokenAddress
        });

        // Делаем первый платеж
        if(paymentMethod == PaymentMethod.TRX) {
            require(msg.value >= monthlyFee, "Insufficient TRX sent");
            uint256 fee = calculateFee(monthlyFee);
            uint256 finalAmount = monthlyFee - fee;

            (bool feeSuccess, ) = feeCollector.call{value: fee}("");
            require(feeSuccess, "Fee transfer failed");

            (bool success, ) = provider.call{value: finalAmount}("");
            require(success, "Initial subscription payment failed");

            // Возвращаем лишний TRX, если был отправлен
            if(msg.value > monthlyFee) {
                (bool refundSuccess, ) = msg.sender.call{value: msg.value - monthlyFee}("");
                require(refundSuccess, "Refund failed");
            }
        } else {
            ITRC20 token = ITRC20(tokenAddress);
            require(token.allowance(msg.sender, address(this)) >= monthlyFee, "Insufficient token allowance");

            uint256 fee = calculateFee(monthlyFee);
            uint256 finalAmount = monthlyFee - fee;

            require(token.transferFrom(msg.sender, feeCollector, fee), "Fee transfer failed");
            require(token.transferFrom(msg.sender, provider, finalAmount), "Initial subscription payment failed");
        }

        subscriptions[msg.sender].push(newSub);

        emit SubscriptionCreated(
            msg.sender,
            provider,
            providerId,
            monthlyFee,
            durationMonths
        );

        _registerTransaction(
            msg.sender,
            provider,
            monthlyFee,
            TransactionType.SUBSCRIPTION,
            paymentMethod,
            tokenAddress,
            providerId
        );
    }

    // Функция для отмены подписки
    function cancelSubscription(uint256 subscriptionIndex) external {
        require(subscriptionIndex < subscriptions[msg.sender].length, "Invalid subscription index");
        require(subscriptions[msg.sender][subscriptionIndex].isActive, "Subscription already inactive");

        subscriptions[msg.sender][subscriptionIndex].isActive = false;

        emit SubscriptionCancelled(
            msg.sender,
            subscriptions[msg.sender][subscriptionIndex].provider,
            subscriptions[msg.sender][subscriptionIndex].providerId
        );
    }

    // Функция для проверки и списания платежей по подпискам
    function processSubscriptionPayments(address subscriber, uint256 subscriptionIndex) external {
        Subscription storage sub = subscriptions[subscriber][subscriptionIndex];
        require(sub.isActive, "Subscription is not active");

        // Проверяем, прошел ли месяц с последнего платежа
        uint256 timeElapsed = block.timestamp - sub.lastPaymentTime;
        require(timeElapsed >= 30 days, "Payment period has not elapsed");

        // Проверяем, не истекла ли подписка
        uint256 totalDuration = sub.startTime + (sub.durationMonths * 30 days);
        if(block.timestamp > totalDuration) {
            sub.isActive = false;
            emit SubscriptionCancelled(subscriber, sub.provider, sub.providerId);
            return;
        }

        if(sub.paymentMethod == PaymentMethod.TRX) {
            // Проверяем баланс TRX
            if(address(subscriber).balance < sub.monthlyFee) {
                sub.isActive = false;
                emit SubscriptionPaymentFailed(subscriber, sub.provider, sub.providerId, "Insufficient TRX balance");
                return;
            }

            uint256 fee = calculateFee(sub.monthlyFee);
            uint256 finalAmount = sub.monthlyFee - fee;

            // Попытка списания TRX
            (bool success, ) = sub.provider.call{value: finalAmount}("");
            if(!success) {
                sub.isActive = false;
                emit SubscriptionPaymentFailed(subscriber, sub.provider, sub.providerId, "TRX transfer failed");
                return;
            }

            (bool feeSuccess, ) = feeCollector.call{value: fee}("");
            require(feeSuccess, "Fee transfer failed");
        } else {
            ITRC20 token = ITRC20(sub.tokenAddress);

            // Проверяем баланс токенов и разрешение на списание
            if(token.balanceOf(subscriber) < sub.monthlyFee ||
               token.allowance(subscriber, address(this)) < sub.monthlyFee) {
                sub.isActive = false;
                emit SubscriptionPaymentFailed(subscriber, sub.provider, sub.providerId, "Insufficient token balance or allowance");
                return;
            }

            uint256 fee = calculateFee(sub.monthlyFee);
            uint256 finalAmount = sub.monthlyFee - fee;

            // Попытка списания токенов
            bool feeSuccess = token.transferFrom(subscriber, feeCollector, fee);
            bool transferSuccess = token.transferFrom(subscriber, sub.provider, finalAmount);

            if(!feeSuccess || !transferSuccess) {
                sub.isActive = false;
                emit SubscriptionPaymentFailed(subscriber, sub.provider, sub.providerId, "Token transfer failed");
                return;
            }
        }

        sub.lastPaymentTime = block.timestamp;

        _registerTransaction(
            subscriber,
            sub.provider,
            sub.monthlyFee,
            TransactionType.SUBSCRIPTION,
            sub.paymentMethod,
            sub.tokenAddress,
            sub.providerId
        );
    }

    // Внутренняя функция для регистрации транзакций
    function _registerTransaction(
        address sender,
        address receiver,
        uint256 amount,
        TransactionType txType,
        PaymentMethod paymentMethod,
        address tokenAddress,
        uint256 itemId
    ) internal {
        transactions[nextTransactionId] = Transaction({
            id: nextTransactionId,
            sender: sender,
            receiver: receiver,
            amount: amount,
            txType: txType,
            paymentMethod: paymentMethod,
            tokenAddress: tokenAddress,
            timestamp: block.timestamp,
            itemId: itemId
        });

        emit TransactionProcessed(
            nextTransactionId,
            sender,
            receiver,
            amount,
            txType,
            paymentMethod,
            tokenAddress
        );

        nextTransactionId++;
    }

    // Геттеры
    function getTransaction(uint256 transactionId) external view returns (Transaction memory) {
        return transactions[transactionId];
    }

    function getUserSubscriptions(address user) external view returns (Subscription[] memory) {
        return subscriptions[user];
    }

    // Функция для приема TRX
    receive() external payable {}
}