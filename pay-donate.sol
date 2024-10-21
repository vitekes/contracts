// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DonationsAndPayments {
    
    address public owner;

   
    mapping(address => uint256) public donations;

    event DonationReceived(address indexed donor, uint256 amount);
    event PaymentMade(address indexed payer, address indexed recipient, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    
    function donate() external payable {
        require(msg.value > 0, "Donation must be greater than 0");
        donations[msg.sender] += msg.value;
        emit DonationReceived(msg.sender, msg.value);
    }


    function pay(address payable recipient) external payable {
        require(msg.value > 0, "Payment must be greater than 0");
        require(recipient != address(0), "Recipient address must be valid");

        recipient.transfer(msg.value);
        emit PaymentMade(msg.sender, recipient, msg.value);
    }

    
    function withdraw(uint256 amount) external {
        require(msg.sender == owner, "Only the owner can withdraw");
        require(amount <= address(this).balance, "Insufficient contract balance");

        payable(owner).transfer(amount);
    }
}