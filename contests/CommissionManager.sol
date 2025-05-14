// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SafeMath.sol";

library CommissionManager {
    using SafeMath for uint256;

    event CommissionWalletUpdated(address indexed newWallet);
    event CommissionPercentageUpdated(uint256 newPercentage);
    event NoCommissionAddressUpdated(address indexed _address, bool status);
    
    // Установка нового кошелька для комиссий
    function setCommissionWallet(address _newWallet) internal returns (address) {
        require(_newWallet != address(0), "Commission wallet cannot be zero address");
        emit CommissionWalletUpdated(_newWallet);
        return _newWallet;
    }
    
    // Установка нового процента комиссии
    function setCommissionPercentage(uint256 _newPercentage) internal returns (uint256) {
        require(_newPercentage <= 10000, "Commission cannot exceed 100%");
        emit CommissionPercentageUpdated(_newPercentage);
        return _newPercentage;
    }
    
    // Управление адресами, освобожденными от комиссии
    function setNoCommissionAddress(mapping(address => bool) storage noCommissionAddresses, address _address, bool _status) internal {
        require(_address != address(0), "Address cannot be zero");
        noCommissionAddresses[_address] = _status;
        emit NoCommissionAddressUpdated(_address, _status);
    }
    
    // Расчет комиссии с учетом освобожденных адресов и безопасных математических операций
    function calculateCommission(uint256 amount, address _address, uint256 commissionPercentage, mapping(address => bool) storage noCommissionAddresses) internal view returns (uint256) {
        if (noCommissionAddresses[_address]) return 0;
        // Используем SafeMath для безопасного расчета
        uint256 commission = amount.mul(commissionPercentage).div(10000);
        // Проверяем, что комиссия не превышает исходную сумму
        require(commission <= amount, "Commission exceeds amount");
        return commission;
    }
} 