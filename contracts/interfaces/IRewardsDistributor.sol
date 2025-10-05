// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRewardsDistributor {
    function notifyReward(address linkToken, uint256 amount) external;
    function updateUser(address linkToken, address user) external;
    function afterTokenTransfer(address linkToken, address user) external;
    function pendingRewards(address linkToken, address user) external view returns (uint256);
    function claim(address linkToken, address to) external returns (uint256);
    function claimBatch(address[] calldata linkTokens, address to) external returns (uint256);
    function revenueLast24Hours(address linkToken) external view returns (uint256);
    function setCampaigns(address campaigns_) external;
}
