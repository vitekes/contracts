// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IERC20 - Стандартный интерфейс для токенов ERC20
 * @dev Интерфейс определяет основные функции для работы с токенами стандарта ERC20
 */
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}