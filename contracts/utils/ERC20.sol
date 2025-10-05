// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "./Errors.sol";

abstract contract ERC20 {
    string public name;
    string public symbol;
    uint8 public immutable decimals;

    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    uint256 internal _totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= value, Errors.INSUFFICIENT_ALLOWANCE);
            unchecked {
                _allowances[from][msg.sender] = allowed - value;
            }
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), Errors.ZERO_ADDRESS);
        uint256 balance = _balances[from];
        require(balance >= value, Errors.INSUFFICIENT_BALANCE);
        _beforeTokenTransfer(from, to, value);
        unchecked {
            _balances[from] = balance - value;
            _balances[to] += value;
        }
        emit Transfer(from, to, value);
        _afterTokenTransfer(from, to, value);
    }

    function _mint(address to, uint256 value) internal {
        require(to != address(0), Errors.ZERO_ADDRESS);
        _beforeTokenTransfer(address(0), to, value);
        _totalSupply += value;
        _balances[to] += value;
        emit Transfer(address(0), to, value);
        _afterTokenTransfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        uint256 balance = _balances[from];
        require(balance >= value, Errors.INSUFFICIENT_BALANCE);
        _beforeTokenTransfer(from, address(0), value);
        unchecked {
            _balances[from] = balance - value;
        }
        _totalSupply -= value;
        emit Transfer(from, address(0), value);
        _afterTokenTransfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0) && spender != address(0), Errors.ZERO_ADDRESS);
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _beforeTokenTransfer(address from, address to, uint256 value) internal virtual {}

    function _afterTokenTransfer(address from, address to, uint256 value) internal virtual {}
}
