// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Errors {
    string internal constant ZERO_ADDRESS = "ZERO_ADDRESS";
    string internal constant INVALID_INPUT = "INVALID_INPUT";
    string internal constant UNAUTHORIZED = "UNAUTHORIZED";
    string internal constant INSUFFICIENT_BALANCE = "INSUFFICIENT_BALANCE";
    string internal constant INSUFFICIENT_ALLOWANCE = "INSUFFICIENT_ALLOWANCE";
    string internal constant OVERFLOW = "OVERFLOW";
    string internal constant CAMPAIGN_NOT_ACTIVE = "CAMPAIGN_NOT_ACTIVE";
    string internal constant CAMPAIGN_CLOSED = "CAMPAIGN_CLOSED";
    string internal constant CPC_OUT_OF_BOUNDS = "CPC_OUT_OF_BOUNDS";
    string internal constant CLICK_ALREADY_CONSUMED = "CLICK_ALREADY_CONSUMED";
    string internal constant TIMESTAMP_OUT_OF_RANGE = "TIMESTAMP_OUT_OF_RANGE";
    string internal constant INSUFFICIENT_REMAINING_BUDGET = "INSUFFICIENT_REMAINING_BUDGET";
    string internal constant NO_SUPPLY = "NO_SUPPLY";
}
