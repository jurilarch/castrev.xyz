// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LinkToken} from "./LinkToken.sol";
import {RewardsDistributor} from "./RewardsDistributor.sol";
import {IERC20, SafeTransferLib} from "./libraries/SafeTransferLib.sol";
import {LinkCanonicalizer} from "./libraries/LinkCanonicalizer.sol";
import {Errors} from "./utils/Errors.sol";

contract LinkTokenFactory {
    using SafeTransferLib for IERC20;

    IERC20 public immutable usdc;
    RewardsDistributor public immutable distributor;
    address public immutable treasury;

    uint256 public immutable tokenPrice; // price per token in USDC (6 decimals)
    address public immutable owner;

    mapping(bytes32 => address) public linkTokenForId;
    address[] public allLinkTokens;

    event LinkTokenCreated(bytes32 indexed linkId, address linkToken, string canonicalLink);
    event TokensPurchased(bytes32 indexed linkId, address indexed buyer, uint256 amount, uint256 cost);

    constructor(address usdc_, address treasury_, uint256 tokenPrice_) {
        require(usdc_ != address(0) && treasury_ != address(0), Errors.ZERO_ADDRESS);
        require(tokenPrice_ > 0, Errors.INVALID_INPUT);
        usdc = IERC20(usdc_);
        treasury = treasury_;
        tokenPrice = tokenPrice_;
        distributor = new RewardsDistributor(usdc_, address(this));
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, Errors.UNAUTHORIZED);
        _;
    }

    function getOrCreateLinkToken(bytes32 linkId, string calldata canonicalLink, string calldata symbol) external returns (address) {
        address existing = linkTokenForId[linkId];
        if (existing != address(0)) {
            return existing;
        }
        string memory name = string(abi.encodePacked("Link: ", canonicalLink));
        LinkToken token = new LinkToken(address(this), linkId, address(distributor), name, symbol);
        address tokenAddress = address(token);
        linkTokenForId[linkId] = tokenAddress;
        allLinkTokens.push(tokenAddress);
        emit LinkTokenCreated(linkId, tokenAddress, canonicalLink);
        return tokenAddress;
    }

    function purchase(bytes32 linkId, uint256 amount, address recipient) external {
        require(amount > 0, Errors.INVALID_INPUT);
        address tokenAddress = linkTokenForId[linkId];
        require(tokenAddress != address(0), Errors.INVALID_INPUT);
        uint256 cost = amount * tokenPrice;
        usdc.safeTransferFrom(msg.sender, treasury, cost);
        LinkToken(tokenAddress).mint(recipient, amount);
        emit TokensPurchased(linkId, msg.sender, amount, cost);
    }

    function getAllLinkTokens() external view returns (address[] memory) {
        return allLinkTokens;
    }

    function getLinkToken(bytes32 linkId) external view returns (address) {
        return linkTokenForId[linkId];
    }

    function configureCampaigns(address campaigns_) external onlyOwner {
        distributor.setCampaigns(campaigns_);
    }

    function canonicalize(string calldata rawLink) external pure returns (string memory) {
        return LinkCanonicalizer.canonicalize(rawLink);
    }

    function computeLinkId(string calldata rawLink) external pure returns (bytes32) {
        return LinkCanonicalizer.computeLinkId(rawLink);
    }

    function distributorAddress() external view returns (address) {
        return address(distributor);
    }
}
