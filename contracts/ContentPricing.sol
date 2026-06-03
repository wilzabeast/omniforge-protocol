// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * ContentPricing: Dynamic USD-pegged pricing system
 * 
 * Core Feature: Content prices stay fixed in USD value regardless of token price
 * 
 * Example:
 * - Image costs $1.50 in OMNI
 * - If OMNI is $0.50, user pays 3 OMNI
 * - If OMNI is $0.75, user pays 2 OMNI
 * - Price always equals $1.50 in real value
 */
contract ContentPricing is Ownable, ReentrancyGuard, Pausable {
    // Token interfaces
    IERC20 public omniToken;
    IERC20 public forgeToken;

    // Chainlink price feed for OMNI/USD
    AggregatorV3Interface public omniPriceFeed;

    // Content types and their USD prices (scaled by 10^8 for precision)
    enum ContentType {
        IMAGE,
        VIDEO,
        AUDIO,
        DOCUMENT,
        BUNDLE
    }

    struct ContentPrice {
        uint256 priceUSD; // Price in USD with 8 decimal precision
        bool active;
        string description;
    }

    mapping(ContentType => ContentPrice) public contentPrices;

    // Treasury for collected OMNI
    address public treasury;

    // Revenue tracking
    uint256 public totalOmniCollected;
    mapping(address => uint256) public userSpent;
    mapping(ContentType => uint256) public contentTypeRevenue;

    // Events
    event PriceUpdated(ContentType indexed contentType, uint256 priceUSD);
    event ContentPurchased(
        address indexed buyer,
        ContentType indexed contentType,
        uint256 omniAmount,
        uint256 usdValue
    );
    event OracleUpdated(address indexed newOracle);
    event TreasuryUpdated(address indexed newTreasury);

    constructor(
        address _omniToken,
        address _forgeToken,
        address _omniPriceFeed,
        address _treasury
    ) {
        require(_omniToken != address(0), "Invalid OMNI token");
        require(_forgeToken != address(0), "Invalid FORGE token");
        require(_omniPriceFeed != address(0), "Invalid price feed");
        require(_treasury != address(0), "Invalid treasury");

        omniToken = IERC20(_omniToken);
        forgeToken = IERC20(_forgeToken);
        omniPriceFeed = AggregatorV3Interface(_omniPriceFeed);
        treasury = _treasury;

        // Initialize default content prices (USD prices with 8 decimals)
        // $1.50 = 150000000 (150 * 10^6)
        // $10.00 = 1000000000 (1000 * 10^6)
        contentPrices[ContentType.IMAGE] = ContentPrice({
            priceUSD: 150_000_000,
            active: true,
            description: "Single Image"
        });

        contentPrices[ContentType.VIDEO] = ContentPrice({
            priceUSD: 1_000_000_000,
            active: true,
            description: "Single Video"
        });

        contentPrices[ContentType.AUDIO] = ContentPrice({
            priceUSD: 300_000_000,
            active: true,
            description: "Single Audio Track"
        });

        contentPrices[ContentType.DOCUMENT] = ContentPrice({
            priceUSD: 50_000_000,
            active: true,
            description: "Document/Report"
        });

        contentPrices[ContentType.BUNDLE] = ContentPrice({
            priceUSD: 1_500_000_000,
            active: true,
            description: "Media Bundle (5 items)"
        });
    }

    /**
     * Get current OMNI price in USD from Chainlink oracle
     * Returns price with 8 decimal precision
     */
    function getOmniPriceUSD() public view returns (uint256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = omniPriceFeed.latestRoundData();

        require(price > 0, "Invalid price from oracle");
        require(timeStamp > 0, "Round not complete");
        require(
            timeStamp >= block.timestamp - 3600,
            "Price feed stale (>1 hour)"
        );

        return uint256(price);
    }

    /**
     * Calculate OMNI amount needed to purchase content
     * 
     * Formula: omniNeeded = contentPriceUSD / omniPriceUSD
     * 
     * Example:
     * - contentPriceUSD = 150_000_000 ($1.50)
     * - omniPriceUSD = 50_000_000 ($0.50)
     * - omniNeeded = 150_000_000 / 50_000_000 = 3 OMNI
     */
    function calculateOmniNeeded(ContentType contentType)
        public
        view
        returns (uint256)
    {
        ContentPrice memory price = contentPrices[contentType];
        require(price.active, "Content type not available");

        uint256 omniPrice = getOmniPriceUSD();
        require(omniPrice > 0, "Invalid OMNI price");

        // Both prices have 8 decimals, so division gives correct OMNI amount
        uint256 omniNeeded = (price.priceUSD * 10 ** 18) / omniPrice;

        return omniNeeded;
    }

    /**
     * Purchase content with OMNI tokens
     * Automatically burns a portion (deflationary) and sends rest to treasury
     */
    function purchaseContent(ContentType contentType)
        public
        nonReentrant
        whenNotPaused
        returns (uint256 omniSpent)
    {
        ContentPrice memory price = contentPrices[contentType];
        require(price.active, "Content type not available");

        // Calculate OMNI needed
        omniSpent = calculateOmniNeeded(contentType);
        require(omniSpent > 0, "Invalid purchase amount");

        // Verify user has sufficient balance
        require(
            omniToken.balanceOf(msg.sender) >= omniSpent,
            "Insufficient OMNI balance"
        );

        // Transfer OMNI from user to this contract
        require(
            omniToken.transferFrom(msg.sender, address(this), omniSpent),
            "OMNI transfer failed"
        );

        // Split: 90% to treasury, 10% burned (deflationary)
        uint256 burnAmount = (omniSpent * 10) / 100;
        uint256 treasuryAmount = omniSpent - burnAmount;

        // Burn the deflationary portion
        omniToken.transfer(address(0), burnAmount);

        // Send treasury portion
        require(
            omniToken.transfer(treasury, treasuryAmount),
            "Treasury transfer failed"
        );

        // Update metrics
        totalOmniCollected += omniSpent;
        userSpent[msg.sender] += omniSpent;
        contentTypeRevenue[contentType] += omniSpent;

        emit ContentPurchased(
            msg.sender,
            contentType,
            omniSpent,
            price.priceUSD
        );

        return omniSpent;
    }

    /**
     * Governance: Update content pricing (FORGE holders vote)
     * Only callable by owner (should be DAO governance contract)
     */
    function setContentPrice(
        ContentType contentType,
        uint256 newPriceUSD,
        string memory description
    ) public onlyOwner {
        require(newPriceUSD > 0, "Price must be > 0");

        contentPrices[contentType] = ContentPrice({
            priceUSD: newPriceUSD,
            active: true,
            description: description
        });

        emit PriceUpdated(contentType, newPriceUSD);
    }

    /**
     * Governance: Disable a content type
     */
    function deactivateContentType(ContentType contentType) public onlyOwner {
        contentPrices[contentType].active = false;
    }

    /**
     * Governance: Enable a content type
     */
    function activateContentType(ContentType contentType) public onlyOwner {
        contentPrices[contentType].active = true;
    }

    /**
     * Update Chainlink price feed (oracle migration)
     */
    function setPriceFeed(address _newPriceFeed) public onlyOwner {
        require(_newPriceFeed != address(0), "Invalid price feed");
        omniPriceFeed = AggregatorV3Interface(_newPriceFeed);
        emit OracleUpdated(_newPriceFeed);
    }

    /**
     * Update treasury address
     */
    function setTreasury(address _newTreasury) public onlyOwner {
        require(_newTreasury != address(0), "Invalid treasury");
        treasury = _newTreasury;
        emit TreasuryUpdated(_newTreasury);
    }

    /**
     * Pause all purchases (emergency)
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * Resume purchases
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * Get user's total spending
     */
    function getUserTotalSpent(address user) public view returns (uint256) {
        return userSpent[user];
    }

    /**
     * Get revenue for content type
     */
    function getContentTypeRevenue(ContentType contentType)
        public
        view
        returns (uint256)
    {
        return contentTypeRevenue[contentType];
    }

    /**
     * Emergency: Recover stuck tokens (not OMNI/FORGE)
     */
    function recoverStuckToken(address token, uint256 amount)
        public
        onlyOwner
    {
        require(
            token != address(omniToken) && token != address(forgeToken),
            "Cannot recover OMNI or FORGE"
        );
        IERC20(token).transfer(msg.sender, amount);
    }
}
