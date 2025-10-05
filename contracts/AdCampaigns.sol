// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20, SafeTransferLib} from "./libraries/SafeTransferLib.sol";
import {Errors} from "./utils/Errors.sol";
import {LinkTokenFactory} from "./LinkTokenFactory.sol";
import {ILinkToken} from "./interfaces/ILinkToken.sol";
import {IRewardsDistributor} from "./interfaces/IRewardsDistributor.sol";
import {ECDSA} from "./libraries/ECDSA.sol";

contract AdCampaigns {
    using SafeTransferLib for IERC20;

    bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant CLICK_TYPEHASH = keccak256("Click(uint256 campaignId,bytes32 adId,bytes32 linkId,bytes32 clickId,uint256 cpc,uint256 timestamp,address clicker)");
    string private constant NAME = "FarcasterClick";
    string private constant VERSION = "1";

    IERC20 public immutable usdc;
    LinkTokenFactory public immutable factory;
    IRewardsDistributor public immutable distributor;

    uint256 public immutable minCpc;
    uint256 public immutable maxCpc;
    uint256 public immutable maxClockSkew;

    struct Campaign {
        address advertiser;
        bytes32 adId;
        bytes32 linkId;
        address linkToken;
        uint128 cpc;
        uint128 totalDeposited;
        uint128 spent;
        uint64 totalClicks;
        bool paused;
        bool closed;
    }

    uint256 public nextCampaignId = 1;

    mapping(uint256 => Campaign) public campaigns;
    mapping(address => bool) public attesters;
    mapping(bytes32 => bool) public consumedClicks;

    event CampaignCreated(uint256 indexed campaignId, address indexed advertiser, bytes32 indexed linkId, bytes32 adId, uint256 cpc, uint256 deposit);
    event CampaignFunded(uint256 indexed campaignId, uint256 amount, uint256 newBudget);
    event CampaignStatusChanged(uint256 indexed campaignId, bool paused);
    event CampaignClosed(uint256 indexed campaignId, uint256 refundAmount);
    event ClickRecorded(uint256 indexed campaignId, bytes32 indexed clickId, uint256 cpc, address indexed clicker);
    event AttesterUpdated(address indexed attester, bool allowed);

    modifier onlyAdvertiser(uint256 campaignId) {
        require(campaigns[campaignId].advertiser == msg.sender, Errors.UNAUTHORIZED);
        _;
    }

    constructor(
        address usdc_,
        address factory_,
        uint256 minCpc_,
        uint256 maxCpc_,
        uint256 maxClockSkew_,
        address[] memory initialAttesters
    ) {
        require(usdc_ != address(0) && factory_ != address(0), Errors.ZERO_ADDRESS);
        require(minCpc_ > 0 && maxCpc_ >= minCpc_, Errors.CPC_OUT_OF_BOUNDS);
        usdc = IERC20(usdc_);
        factory = LinkTokenFactory(factory_);
        distributor = IRewardsDistributor(factory.distributorAddress());
        distributor.setCampaigns(address(this));
        minCpc = minCpc_;
        maxCpc = maxCpc_;
        maxClockSkew = maxClockSkew_;
        for (uint256 i = 0; i < initialAttesters.length; i++) {
            attesters[initialAttesters[i]] = true;
            emit AttesterUpdated(initialAttesters[i], true);
        }
    }

    function createCampaign(
        bytes32 adId,
        bytes32 linkId,
        address linkToken,
        uint256 cpc,
        uint256 depositAmount
    ) external returns (uint256 campaignId) {
        require(cpc >= minCpc && cpc <= maxCpc, Errors.CPC_OUT_OF_BOUNDS);
        require(linkToken != address(0) && linkId == ILinkToken(linkToken).linkId(), Errors.INVALID_INPUT);
        require(depositAmount >= cpc && depositAmount <= type(uint128).max, Errors.INVALID_INPUT);

        campaignId = nextCampaignId++;
        campaigns[campaignId] = Campaign({
            advertiser: msg.sender,
            adId: adId,
            linkId: linkId,
            linkToken: linkToken,
            cpc: uint128(cpc),
            totalDeposited: uint128(depositAmount),
            spent: 0,
            totalClicks: 0,
            paused: false,
            closed: false
        });

        usdc.safeTransferFrom(msg.sender, address(this), depositAmount);

        emit CampaignCreated(campaignId, msg.sender, linkId, adId, cpc, depositAmount);
    }

    function fundCampaign(uint256 campaignId, uint256 amount) external onlyAdvertiser(campaignId) {
        Campaign storage campaign = campaigns[campaignId];
        require(!campaign.closed, Errors.CAMPAIGN_CLOSED);
        require(amount > 0 && amount <= type(uint128).max, Errors.INVALID_INPUT);
        uint256 newTotal = uint256(campaign.totalDeposited) + amount;
        require(newTotal <= type(uint128).max, Errors.OVERFLOW);
        campaign.totalDeposited = uint128(newTotal);
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        emit CampaignFunded(campaignId, amount, remainingBudget(campaignId));
    }

    function pauseCampaign(uint256 campaignId, bool pause) external onlyAdvertiser(campaignId) {
        Campaign storage campaign = campaigns[campaignId];
        require(!campaign.closed, Errors.CAMPAIGN_CLOSED);
        campaign.paused = pause;
        emit CampaignStatusChanged(campaignId, pause);
    }

    function closeCampaign(uint256 campaignId, address refundTo) external onlyAdvertiser(campaignId) {
        Campaign storage campaign = campaigns[campaignId];
        require(!campaign.closed, Errors.CAMPAIGN_CLOSED);
        campaign.closed = true;
        campaign.paused = true;
        uint256 remaining = remainingBudget(campaignId);
        campaign.totalDeposited = campaign.spent;
        if (remaining > 0) {
            usdc.safeTransfer(refundTo, remaining);
        }
        emit CampaignClosed(campaignId, remaining);
    }

    function recordClick(
        uint256 campaignId,
        bytes32 clickId,
        uint256 cpc,
        uint256 timestamp,
        address clicker,
        bytes calldata signature
    ) external {
        Campaign storage campaign = campaigns[campaignId];
        require(!campaign.closed, Errors.CAMPAIGN_CLOSED);
        require(!campaign.paused, Errors.CAMPAIGN_NOT_ACTIVE);
        require(cpc == campaign.cpc, Errors.INVALID_INPUT);
        require(timestamp + maxClockSkew >= block.timestamp && timestamp <= block.timestamp + maxClockSkew, Errors.TIMESTAMP_OUT_OF_RANGE);
        require(!consumedClicks[clickId], Errors.CLICK_ALREADY_CONSUMED);

        bytes32 digest = _hashClick(campaignId, campaign.adId, campaign.linkId, clickId, cpc, timestamp, clicker);
        address signer = ECDSA.recover(digest, signature);
        require(attesters[signer], Errors.UNAUTHORIZED);

        uint256 remaining = remainingBudget(campaignId);
        require(remaining >= cpc, Errors.INSUFFICIENT_REMAINING_BUDGET);

        consumedClicks[clickId] = true;
        uint256 newSpent = uint256(campaign.spent) + cpc;
        require(newSpent <= type(uint128).max, Errors.OVERFLOW);
        campaign.spent = uint128(newSpent);
        campaign.totalClicks += 1;

        usdc.safeTransfer(address(distributor), cpc);
        distributor.notifyReward(campaign.linkToken, cpc);

        emit ClickRecorded(campaignId, clickId, cpc, clicker);
    }

    function remainingBudget(uint256 campaignId) public view returns (uint256) {
        Campaign storage campaign = campaigns[campaignId];
        return uint256(campaign.totalDeposited) - uint256(campaign.spent);
    }

    function setAttester(address attester, bool allowed) external {
        require(msg.sender == address(factory), Errors.UNAUTHORIZED);
        attesters[attester] = allowed;
        emit AttesterUpdated(attester, allowed);
    }

    function _domainSeparatorV4() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(NAME)),
                keccak256(bytes(VERSION)),
                block.chainid,
                address(this)
            )
        );
    }

    function _hashClick(
        uint256 campaignId,
        bytes32 adId,
        bytes32 linkId,
        bytes32 clickId,
        uint256 cpc,
        uint256 timestamp,
        address clicker
    ) private view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(CLICK_TYPEHASH, campaignId, adId, linkId, clickId, cpc, timestamp, clicker));
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparatorV4(), structHash));
    }
}
