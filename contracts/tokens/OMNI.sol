// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title OMNI Token
 * @dev OmniForge Protocol utility token for content generation purchases
 * Users stake OMNI to access the AI content factory and pay for generated assets on-chain
 */
contract OMNIToken is ERC20, Ownable {
    // Initial supply: 1 billion tokens (18 decimals)
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    constructor() ERC20("OmniForge", "OMNI") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /**
     * @dev Burn tokens (reduce supply)
     */
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Mint new tokens (only owner)
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
