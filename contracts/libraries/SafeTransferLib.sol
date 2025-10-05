// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "../utils/Errors.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

library SafeTransferLib {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        require(_callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value)), Errors.INVALID_INPUT);
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        require(_callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value)), Errors.INVALID_INPUT);
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(_callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value)), Errors.INVALID_INPUT);
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private returns (bool) {
        (bool success, bytes memory returndata) = address(token).call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(32, returndata), mload(returndata))
                }
            }
            return false;
        }

        if (returndata.length == 0) {
            return true;
        }

        return abi.decode(returndata, (bool));
    }
}
