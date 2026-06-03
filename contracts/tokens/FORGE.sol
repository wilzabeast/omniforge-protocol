// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FORGE Token
 * @dev OmniForge Protocol governance token
 * FORGE holders participate in governance votes, protocol upgrades, and community treasury allocation
 */
contract FORGEToken is ERC20, Ownable {
    // Initial supply: 500 million tokens (18 decimals)
    uint256 public constant INITIAL_SUPPLY = 500_000_000 * 10 ** 18;

    constructor() ERC20("OmniForge Governance", "FORGE") {
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
