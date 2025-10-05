// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20, SafeTransferLib} from "./libraries/SafeTransferLib.sol";
import {ILinkToken} from "./interfaces/ILinkToken.sol";
import {Errors} from "./utils/Errors.sol";

contract RewardsDistributor {
    using SafeTransferLib for IERC20;

    uint256 private constant ACC_PRECISION = 1e18;
    uint256 private constant HOURS_IN_DAY = 24;

    IERC20 public immutable usdc;
    address public immutable factory;
    address public campaigns;

    struct RewardData {
        uint256 accPerShare;
        uint256 queuedRewards;
    }

    mapping(address => RewardData) public rewardData;
    mapping(address => mapping(address => uint256)) public rewardDebt;
    mapping(address => mapping(address => uint256)) public pending;

    mapping(address => mapping(uint64 => uint256)) internal hourlyRevenue;
    mapping(address => uint64) public lastRecordedHour;

    event RewardAdded(address indexed linkToken, uint256 amount, uint256 accPerShare);
    event Claimed(address indexed linkToken, address indexed user, address indexed to, uint256 amount);
    event CampaignsUpdated(address indexed newCampaigns);

    modifier onlyFactory() {
        require(msg.sender == factory, Errors.UNAUTHORIZED);
        _;
    }

    constructor(address usdc_, address factory_) {
        require(usdc_ != address(0) && factory_ != address(0), Errors.ZERO_ADDRESS);
        usdc = IERC20(usdc_);
        factory = factory_;
    }

    function notifyReward(address linkToken, uint256 amount) external {
        require(msg.sender == factory || msg.sender == campaigns, Errors.UNAUTHORIZED);
        RewardData storage data = rewardData[linkToken];
        uint256 totalSupply = ILinkToken(linkToken).totalSupply();
        _bumpHour(linkToken, amount);
        if (totalSupply == 0) {
            data.queuedRewards += amount;
            return;
        }
        uint256 totalAmount = amount + data.queuedRewards;
        data.queuedRewards = 0;
        data.accPerShare += (totalAmount * ACC_PRECISION) / totalSupply;
        emit RewardAdded(linkToken, totalAmount, data.accPerShare);
    }

    function setCampaigns(address campaigns_) external onlyFactory {
        require(campaigns_ != address(0), Errors.ZERO_ADDRESS);
        campaigns = campaigns_;
        emit CampaignsUpdated(campaigns_);
    }

    function updateUser(address linkToken, address user) external {
        require(msg.sender == linkToken, Errors.UNAUTHORIZED);
        _updateUser(linkToken, user);
    }

    function afterTokenTransfer(address linkToken, address user) external {
        require(msg.sender == linkToken, Errors.UNAUTHORIZED);
        _syncUserDebt(linkToken, user);
    }

    function claim(address linkToken, address to) external returns (uint256) {
        _updateUser(linkToken, msg.sender);
        return _payout(linkToken, msg.sender, to);
    }

    function claimBatch(address[] calldata linkTokens, address to) external returns (uint256 totalClaimed) {
        for (uint256 i = 0; i < linkTokens.length; i++) {
            address token = linkTokens[i];
            _updateUser(token, msg.sender);
            totalClaimed += _payout(token, msg.sender, to);
        }
    }

    function pendingRewards(address linkToken, address user) external view returns (uint256) {
        RewardData storage data = rewardData[linkToken];
        uint256 acc = data.accPerShare;
        uint256 totalSupply = ILinkToken(linkToken).totalSupply();
        if (totalSupply > 0) {
            uint256 totalAmount = data.queuedRewards;
            if (totalAmount > 0) {
                acc += (totalAmount * ACC_PRECISION) / totalSupply;
            }
        }
        uint256 balance = ILinkToken(linkToken).balanceOf(user);
        uint256 accumulated = (balance * acc) / ACC_PRECISION;
        uint256 debt = rewardDebt[linkToken][user];
        uint256 stored = pending[linkToken][user];
        if (accumulated <= debt) {
            return stored;
        }
        return stored + (accumulated - debt);
    }

    function revenueLast24Hours(address linkToken) external view returns (uint256 total) {
        uint64 currentHour = uint64(block.timestamp / 1 hours);
        for (uint256 i = 0; i < HOURS_IN_DAY; i++) {
            if (currentHour < i) {
                break;
            }
            uint64 hourId = currentHour - uint64(i);
            total += hourlyRevenue[linkToken][hourId];
        }
    }

    function _payout(address linkToken, address user, address to) private returns (uint256) {
        uint256 amount = pending[linkToken][user];
        if (amount == 0) {
            _syncUserDebt(linkToken, user);
            return 0;
        }
        pending[linkToken][user] = 0;
        _syncUserDebt(linkToken, user);
        usdc.safeTransfer(to, amount);
        emit Claimed(linkToken, user, to, amount);
        return amount;
    }

    function _updateUser(address linkToken, address user) private {
        if (user == address(0)) {
            return;
        }
        RewardData storage data = rewardData[linkToken];
        uint256 acc = data.accPerShare;
        uint256 totalSupply = ILinkToken(linkToken).totalSupply();
        if (totalSupply > 0 && data.queuedRewards > 0) {
            acc += (data.queuedRewards * ACC_PRECISION) / totalSupply;
        }
        uint256 balance = ILinkToken(linkToken).balanceOf(user);
        uint256 accumulated = (balance * acc) / ACC_PRECISION;
        uint256 debt = rewardDebt[linkToken][user];
        if (accumulated > debt) {
            pending[linkToken][user] += accumulated - debt;
        }
        rewardDebt[linkToken][user] = accumulated;
    }

    function _syncUserDebt(address linkToken, address user) private {
        uint256 balance = ILinkToken(linkToken).balanceOf(user);
        RewardData storage data = rewardData[linkToken];
        uint256 acc = data.accPerShare;
        uint256 totalSupply = ILinkToken(linkToken).totalSupply();
        if (totalSupply > 0 && data.queuedRewards > 0) {
            acc += (data.queuedRewards * ACC_PRECISION) / totalSupply;
        }
        rewardDebt[linkToken][user] = (balance * acc) / ACC_PRECISION;
    }

    function _bumpHour(address linkToken, uint256 amount) private {
        uint64 currentHour = uint64(block.timestamp / 1 hours);
        hourlyRevenue[linkToken][currentHour] += amount;
        lastRecordedHour[linkToken] = currentHour;
    }
}
