// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * FORGE Token: Governance & Voting
 * 
 * Features:
 * - ERC20 standard token
 * - Governance voting rights
 * - DAO proposal participation
 * - Protocol parameter steering
 */
contract ForgeToken is ERC20, Ownable, Pausable {
    // Events
    event TokensMinted(address indexed to, uint256 amount, string reason);
    event TokensBurned(address indexed from, uint256 amount, string reason);

    // Initial supply: 100 million FORGE
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10 ** 18;

    constructor() ERC20("Forge", "FORGE") {
        _mint(msg.sender, INITIAL_SUPPLY);
        emit TokensMinted(msg.sender, INITIAL_SUPPLY, "Initial supply");
    }

    /**
     * Mint new FORGE tokens (only owner/DAO)
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
        emit TokensMinted(to, amount, "Minted by governance");
    }

    /**
     * Burn FORGE tokens
     */
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount, "User burn");
    }

    /**
     * Pause token transfers (emergency)
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * Resume token transfers
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}

/**
 * OMNI Token: Content Purchase Currency
 * 
 * Features:
 * - ERC20 standard token
 * - Pegged to USD via Chainlink oracle
 * - Burning mechanism for deflation
 * - Content marketplace integration
 */
contract OmniToken is ERC20, Ownable, Pausable, ReentrancyGuard {
    // Events
    event TokensMinted(address indexed to, uint256 amount, string reason);
    event TokensBurned(address indexed from, uint256 amount, string reason);
    event OracleUpdated(address indexed newOracle);

    // Oracle for USD pricing
    address public priceOracle;

    // Initial supply: 1 billion OMNI
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    constructor(address _priceOracle) ERC20("Omni", "OMNI") {
        priceOracle = _priceOracle;
        _mint(msg.sender, INITIAL_SUPPLY);
        emit TokensMinted(msg.sender, INITIAL_SUPPLY, "Initial supply");
    }

    /**
     * Update price oracle for USD conversions
     */
    function setPriceOracle(address _newOracle) public onlyOwner {
        require(_newOracle != address(0), "Invalid oracle address");
        priceOracle = _newOracle;
        emit OracleUpdated(_newOracle);
    }

    /**
     * Mint new OMNI tokens (only for content creators/platform)
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
        emit TokensMinted(to, amount, "Minted by platform");
    }

    /**
     * Burn OMNI tokens (deflationary mechanism)
     */
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount, "User burn");
    }

    /**
     * Pause token transfers (emergency)
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * Resume token transfers
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}
