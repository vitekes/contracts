// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISubscriptionContract {
    function registerSubscription(address subscriber, uint256 amount, uint256 duration) external;
}

contract SubscriptionPayments {
    address public owner;
    ISubscriptionContract public subscriptionContract;

    event SubscriptionRegistered(address indexed subscriber, uint256 amount, uint256 duration);

    constructor(address _subscriptionContract) {
        owner = msg.sender;
        subscriptionContract = ISubscriptionContract(_subscriptionContract);
    }

    
    function subscribeInEther(uint256 duration) external payable {
        require(msg.value > 0, "Subscription fee must be greater than 0");

        // Вызов метода подписки на внешнем контракте
        subscriptionContract.registerSubscription(msg.sender, msg.value, duration);

        emit SubscriptionRegistered(msg.sender, msg.value, duration);
    }

   
    function subscribeInTokens(address token, uint256 amount, uint256 duration) external {
        require(amount > 0, "Subscription fee must be greater than 0");
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        // Вызов метода подписки на внешнем контракте
        subscriptionContract.registerSubscription(msg.sender, amount, duration);

        emit SubscriptionRegistered(msg.sender, amount, duration);
    }

    
    function withdrawEther(uint256 amount) external {
        require(msg.sender == owner, "Only the owner can withdraw");
        require(amount <= address(this).balance, "Insufficient contract balance");

        payable(owner).transfer(amount);
    }

    
    function withdrawTokens(address token, uint256 amount) external {
        require(msg.sender == owner, "Only the owner can withdraw");
        require(IERC20(token).transfer(owner, amount), "Token withdrawal failed");
    }
}