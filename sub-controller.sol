// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISubscriptionHandler {
    function processSubscription(address user, uint256 value, uint256 term) external;
}

interface ITokenInterface {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract MembershipPayments {
    address public admin;  // Администратор контракта
    ISubscriptionHandler public membershipService;  

    event MembershipStarted(address indexed member, uint256 value, uint256 term);

    constructor(address _membershipService) {
        admin = msg.sender;
        membershipService = ISubscriptionHandler(_membershipService);
    }

    
    function startMembershipInTRX(uint256 term) external payable {
        require(msg.value > 0, "Subscription amount must be greater than zero");

        // Вызов внешнего контракта для обработки подписки
        membershipService.processSubscription(msg.sender, msg.value, term);

        emit MembershipStarted(msg.sender, msg.value, term);
    }

   
    function startMembershipInTokens(address token, uint256 value, uint256 term) external {
        require(value > 0, "Subscription amount must be greater than zero");
        require(ITokenInterface(token).transferFrom(msg.sender, address(this), value), "Token transfer failed");

       
        membershipService.processSubscription(msg.sender, value, term);

        emit MembershipStarted(msg.sender, value, term);
    }

    
    function retrieveTRX(uint256 amount) external {
        require(msg.sender == admin, "Only admin can retrieve funds");
        require(amount <= address(this).balance, "Insufficient balance");

        payable(admin).transfer(amount);
    }

    
    function withdrawTokenFunds(address token, uint256 value) external {
        require(msg.sender == admin, "Only admin can withdraw tokens");
        require(ITokenInterface(token).transfer(admin, value), "Token withdrawal failed");
    }
}