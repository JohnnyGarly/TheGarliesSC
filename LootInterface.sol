// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface LootInterface {
    function createItem(uint) external returns(uint);
    function setItem(uint, uint) external;
    function getAllItems() external view returns(uint[] memory,uint[] memory, uint[] memory);
    function getItem(uint) external view returns(uint,uint,uint);
    function mint(address, uint) external;
}