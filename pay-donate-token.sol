// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenInterface {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
}

contract TokenTransfersAndContributions {
    address public admin;  

    event TokenContributionReceived(address indexed donor, address indexed token, uint256 value);
    event TokenSent(address indexed sender, address indexed token, address indexed receiver, uint256 value);

    constructor() {
        admin = msg.sender;
    }

   
    function receiveTokenContribution(address token, uint256 value) external {
        require(value > 0, "Contribution amount must be greater than zero");
        require(ITokenInterface(token).transferFrom(msg.sender, address(this), value), "Token transfer failed");

        emit TokenContributionReceived(msg.sender, token, value);
    }

   
    function sendTokens(address token, address recipient, uint256 value) external {
        require(value > 0, "Token amount must be greater than zero");
        require(recipient != address(0), "Recipient address cannot be zero");
        require(ITokenInterface(token).transferFrom(msg.sender, recipient, value), "Token transfer failed");

        emit TokenSent(msg.sender, token, recipient, value);
    }

    
    function withdrawTokenFunds(address token, uint256 value) external {
        require(msg.sender == admin, "Only admin can withdraw tokens");
        require(ITokenInterface(token).transfer(admin, value), "Token withdrawal failed");
    }
}