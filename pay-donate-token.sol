// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract TokenDonationsAndPayments {
    address public owner;

    event TokenDonationReceived(address indexed donor, address indexed token, uint256 amount);
    event TokenPaymentMade(address indexed payer, address indexed token, address indexed recipient, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    
    function donateInTokens(address token, uint256 amount) external {
        require(amount > 0, "Donation must be greater than 0");
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        emit TokenDonationReceived(msg.sender, token, amount);
    }

 
    function payInTokens(address token, address recipient, uint256 amount) external {
        require(amount > 0, "Payment must be greater than 0");
        require(recipient != address(0), "Recipient address must be valid");
        require(IERC20(token).transferFrom(msg.sender, recipient, amount), "Token transfer failed");

        emit TokenPaymentMade(msg.sender, token, recipient, amount);
    }


    function withdrawTokens(address token, uint256 amount) external {
        require(msg.sender == owner, "Only the owner can withdraw");
        require(IERC20(token).transfer(owner, amount), "Token withdrawal failed");
    }
}