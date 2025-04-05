// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library CommissionManager {
    event CommissionWalletUpdated(address indexed newWallet);
    event CommissionPercentageUpdated(uint256 newPercentage);
    event NoCommissionAddressUpdated(address indexed _address, bool status);
    
    // Установка нового кошелька для комиссий
    function setCommissionWallet(address storage commissionWallet, address _newWallet) internal {
        commissionWallet = _newWallet;
        emit CommissionWalletUpdated(_newWallet);
    }
    
    // Установка нового процента комиссии
    function setCommissionPercentage(uint256 storage commissionPercentage, uint256 _newPercentage) internal {
        require(_newPercentage <= 10000, "Commission cannot exceed 100%");
        commissionPercentage = _newPercentage;
        emit CommissionPercentageUpdated(_newPercentage);
    }
    
    // Управление адресами, освобожденными от комиссии
    function setNoCommissionAddress(mapping(address => bool) storage noCommissionAddresses, address _address, bool _status) internal {
        noCommissionAddresses[_address] = _status;
        emit NoCommissionAddressUpdated(_address, _status);
    }
    
    // Расчет комиссии с учетом освобожденных адресов
    function calculateCommission(uint256 amount, address _address, uint256 commissionPercentage, mapping(address => bool) storage noCommissionAddresses) internal view returns (uint256) {
        if (noCommissionAddresses[_address]) return 0;
        return (amount * commissionPercentage) / 10000;
    }
} 