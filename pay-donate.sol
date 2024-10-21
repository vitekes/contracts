// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ContributionAndTransfersTRX {
    address public admin; 

    event ContributionAdded(address indexed contributor, uint256 value);
    event FundsTransferred(address indexed sender, address indexed receiver, uint256 value);

    constructor() {
        admin = msg.sender;
    }

    
    function addContribution() external payable {
        require(msg.value > 0, "Contribution must be greater than zero");
        emit ContributionAdded(msg.sender, msg.value);
    }

   
    function transferFunds(address payable beneficiary) external payable {
        require(msg.value > 0, "Transfer amount must be greater than zero");
        require(beneficiary != address(0), "Invalid beneficiary address");

        beneficiary.transfer(msg.value);
        emit FundsTransferred(msg.sender, beneficiary, msg.value);
    }

    function retrieveFunds(uint256 amount) external {
        require(msg.sender == admin, "Only the admin can retrieve funds");
        require(amount <= address(this).balance, "Insufficient balance");

        payable(admin).transfer(amount);
    }
}