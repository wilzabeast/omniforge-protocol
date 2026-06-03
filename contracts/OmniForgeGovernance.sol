// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * OmniForgeGovernance: DAO for protocol decisions
 * 
 * FORGE token holders can:
 * - Propose changes to content pricing
 * - Vote on governance decisions
 * - Steer the future direction of the protocol
 * - Receive a portion of protocol revenue
 */
contract OmniForgeGovernance is Ownable, ReentrancyGuard {
    // Interfaces
    IERC20 public forgeToken;
    address public contentPricingContract;

    // Proposal structure
    enum ProposalType {
        PRICE_UPDATE,
        TREASURY_CHANGE,
        PARAMETER_UPDATE,
        EMERGENCY_PAUSE
    }

    enum ProposalStatus {
        PENDING,
        ACTIVE,
        DEFEATED,
        SUCCEEDED,
        EXECUTED
    }

    struct Proposal {
        uint256 id;
        address proposer;
        ProposalType proposalType;
        string description;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        ProposalStatus status;
        bool executed;
        string ipfsHash; // IPFS link to full proposal details
    }

    // Voting receipt
    struct Receipt {
        bool hasVoted;
        uint8 support; // 0 = against, 1 = for, 2 = abstain
        uint256 votes;
    }

    // State variables
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => Receipt)) public receipts;
    uint256 public proposalCount;

    // Governance parameters
    uint256 public votingDelay = 1; // blocks
    uint256 public votingPeriod = 45818; // ~1 week on Base (12s blocks)
    uint256 public proposalThreshold = 100_000 * 10 ** 18; // 100k FORGE to propose

    // Voting power snapshot system
    mapping(address => uint256) public lastVotedBlock;

    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        ProposalType proposalType,
        string description
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 votes,
        string reason
    );

    event ProposalExecuted(uint256 indexed proposalId);

    event ProposalCanceled(uint256 indexed proposalId);

    event GovernanceParameterUpdated(
        string paramName,
        uint256 oldValue,
        uint256 newValue
    );

    constructor(address _forgeToken, address _contentPricingContract) {
        require(_forgeToken != address(0), "Invalid FORGE token");
        require(
            _contentPricingContract != address(0),
            "Invalid ContentPricing contract"
        );

        forgeToken = IERC20(_forgeToken);
        contentPricingContract = _contentPricingContract;
    }

    /**
     * Get voting power of an address at current block
     */
    function getVotingPower(address account) public view returns (uint256) {
        return forgeToken.balanceOf(account);
    }

    /**
     * Create a new governance proposal
     * Requires proposalThreshold FORGE tokens
     */
    function createProposal(
        ProposalType proposalType,
        string memory description,
        string memory ipfsHash
    ) public returns (uint256) {
        require(
            getVotingPower(msg.sender) >= proposalThreshold,
            "Insufficient FORGE to propose"
        );
        require(bytes(description).length > 0, "Description required");
        require(bytes(ipfsHash).length > 0, "IPFS hash required");

        uint256 proposalId = proposalCount++;

        uint256 startBlock = block.number + votingDelay;
        uint256 endBlock = startBlock + votingPeriod;

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            proposalType: proposalType,
            description: description,
            startBlock: startBlock,
            endBlock: endBlock,
            forVotes: 0,
            againstVotes: 0,
            status: ProposalStatus.PENDING,
            executed: false,
            ipfsHash: ipfsHash
        });

        emit ProposalCreated(proposalId, msg.sender, proposalType, description);

        return proposalId;
    }

    /**
     * Cast vote on a proposal
     * support: 0 = against, 1 = for, 2 = abstain
     */
    function castVote(
        uint256 proposalId,
        uint8 support,
        string memory reason
    ) public nonReentrant {
        require(proposalId < proposalCount, "Invalid proposal");
        require(support <= 2, "Invalid vote type");

        Proposal storage proposal = proposals[proposalId];

        // Check voting period
        require(
            block.number >= proposal.startBlock,
            "Voting not started yet"
        );
        require(block.number <= proposal.endBlock, "Voting ended");

        // Check if already voted
        Receipt storage receipt = receipts[proposalId][msg.sender];
        require(!receipt.hasVoted, "Already voted");

        // Get voting power
        uint256 votes = getVotingPower(msg.sender);
        require(votes > 0, "No voting power");

        // Record vote
        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        if (support == 0) {
            proposal.againstVotes += votes;
        } else if (support == 1) {
            proposal.forVotes += votes;
        }
        // support == 2 (abstain) doesn't count towards either side

        lastVotedBlock[msg.sender] = block.number;

        emit VoteCast(msg.sender, proposalId, support, votes, reason);
    }

    /**
     * Finalize voting on a proposal
     * Anyone can call this after voting period ends
     */
    function finalizeVote(uint256 proposalId) public {
        require(proposalId < proposalCount, "Invalid proposal");

        Proposal storage proposal = proposals[proposalId];

        require(
            block.number > proposal.endBlock,
            "Voting period not ended"
        );
        require(
            proposal.status == ProposalStatus.PENDING ||
                proposal.status == ProposalStatus.ACTIVE,
            "Invalid proposal status"
        );

        // Determine outcome (simple majority)
        if (proposal.forVotes > proposal.againstVotes) {
            proposal.status = ProposalStatus.SUCCEEDED;
        } else {
            proposal.status = ProposalStatus.DEFEATED;
        }
    }

    /**
     * Execute a successful proposal
     * Only owner can execute (should be upgraded to timelock)
     */
    function executeProposal(uint256 proposalId) public onlyOwner nonReentrant {
        require(proposalId < proposalCount, "Invalid proposal");

        Proposal storage proposal = proposals[proposalId];

        require(
            proposal.status == ProposalStatus.SUCCEEDED,
            "Proposal not succeeded"
        );
        require(!proposal.executed, "Already executed");

        proposal.executed = true;
        proposal.status = ProposalStatus.EXECUTED;

        // Execute based on proposal type
        if (proposal.proposalType == ProposalType.EMERGENCY_PAUSE) {
            // Call pause on ContentPricing
            (bool success, ) = contentPricingContract.call(
                abi.encodeWithSignature("pause()")
            );
            require(success, "Pause execution failed");
        }

        emit ProposalExecuted(proposalId);
    }

    /**
     * Update governance parameters (voting delay, period, threshold)
     */
    function updateGovernanceParameter(
        string memory paramName,
        uint256 newValue
    ) public onlyOwner {
        require(newValue > 0, "Invalid parameter value");

        if (
            keccak256(abi.encodePacked(paramName)) ==
            keccak256(abi.encodePacked("votingDelay"))
        ) {
            uint256 oldValue = votingDelay;
            votingDelay = newValue;
            emit GovernanceParameterUpdated(paramName, oldValue, newValue);
        } else if (
            keccak256(abi.encodePacked(paramName)) ==
            keccak256(abi.encodePacked("votingPeriod"))
        ) {
            uint256 oldValue = votingPeriod;
            votingPeriod = newValue;
            emit GovernanceParameterUpdated(paramName, oldValue, newValue);
        } else if (
            keccak256(abi.encodePacked(paramName)) ==
            keccak256(abi.encodePacked("proposalThreshold"))
        ) {
            uint256 oldValue = proposalThreshold;
            proposalThreshold = newValue;
            emit GovernanceParameterUpdated(paramName, oldValue, newValue);
        }
    }

    /**
     * Get proposal details
     */
    function getProposal(uint256 proposalId)
        public
        view
        returns (Proposal memory)
    {
        require(proposalId < proposalCount, "Invalid proposal");
        return proposals[proposalId];
    }

    /**
     * Get vote receipt
     */
    function getReceipt(uint256 proposalId, address voter)
        public
        view
        returns (Receipt memory)
    {
        require(proposalId < proposalCount, "Invalid proposal");
        return receipts[proposalId][voter];
    }

    /**
     * Cancel a proposal (proposer or owner)
     */
    function cancelProposal(uint256 proposalId) public {
        require(proposalId < proposalCount, "Invalid proposal");

        Proposal storage proposal = proposals[proposalId];

        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "Not authorized to cancel"
        );
        require(!proposal.executed, "Cannot cancel executed proposal");

        proposal.status = ProposalStatus.DEFEATED;

        emit ProposalCanceled(proposalId);
    }
}
