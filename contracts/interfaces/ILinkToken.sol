// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILinkToken {
    function linkId() external view returns (bytes32);
    function factory() external view returns (address);
    function distributor() external view returns (address);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}
