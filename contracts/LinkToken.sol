// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "./utils/ERC20.sol";
import {IRewardsDistributor} from "./interfaces/IRewardsDistributor.sol";
import {Errors} from "./utils/Errors.sol";

contract LinkToken is ERC20 {
    address public immutable factory;
    bytes32 public immutable linkId;
    IRewardsDistributor public immutable distributor;

    modifier onlyFactory() {
        require(msg.sender == factory, Errors.UNAUTHORIZED);
        _;
    }

    constructor(
        address factory_,
        bytes32 linkId_,
        address distributor_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_, 18) {
        require(factory_ != address(0) && distributor_ != address(0), Errors.ZERO_ADDRESS);
        factory = factory_;
        linkId = linkId_;
        distributor = IRewardsDistributor(distributor_);
    }

    function mint(address to, uint256 amount) external onlyFactory {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyFactory {
        _burn(from, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 value) internal override {
        if (from != address(0)) {
            distributor.updateUser(address(this), from);
        }
        if (to != address(0)) {
            distributor.updateUser(address(this), to);
        }
    }

    function _afterTokenTransfer(address from, address to, uint256) internal override {
        if (from != address(0)) {
            distributor.afterTokenTransfer(address(this), from);
        }
        if (to != address(0)) {
            distributor.afterTokenTransfer(address(this), to);
        }
    }
}
