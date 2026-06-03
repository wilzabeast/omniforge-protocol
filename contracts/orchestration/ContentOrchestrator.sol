// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title ContentOrchestrator
 * @dev Orchestrates multi-agent workflow and manages content generation pipeline
 * Triggers four specialized agents: Architect, Audio, Cinematic, Publisher
 */
contract ContentOrchestrator is Ownable, ReentrancyGuard {
    struct GenerationJob {
        uint256 jobId;
        address creator;
        string campaignObjective;
        uint256 timestamp;
        bool completed;
        bytes32 assetHash; // On-chain provenance
    }

    mapping(uint256 => GenerationJob) public jobs;
    uint256 public jobCounter;

    event JobCreated(uint256 indexed jobId, address indexed creator, string objective);
    event JobCompleted(uint256 indexed jobId, bytes32 assetHash);
    event AgentTriggered(uint256 indexed jobId, string agentName);

    /**
     * @dev Submit a new content generation job
     * Triggers all four agents simultaneously
     */
    function submitGenerationJob(string memory _campaignObjective) external nonReentrant returns (uint256) {
        uint256 newJobId = jobCounter++;
        
        jobs[newJobId] = GenerationJob({
            jobId: newJobId,
            creator: msg.sender,
            campaignObjective: _campaignObjective,
            timestamp: block.timestamp,
            completed: false,
            assetHash: 0
        });

        // Trigger all four agents
        emit AgentTriggered(newJobId, "Architect");
        emit AgentTriggered(newJobId, "Audio");
        emit AgentTriggered(newJobId, "Cinematic");
        emit AgentTriggered(newJobId, "Publisher");
        
        emit JobCreated(newJobId, msg.sender, _campaignObjective);
        return newJobId;
    }

    /**
     * @dev Record completed generation with on-chain provenance
     */
    function completeJob(uint256 _jobId, bytes32 _assetHash) external onlyOwner {
        require(jobs[_jobId].creator != address(0), "Job does not exist");
        require(!jobs[_jobId].completed, "Job already completed");
        
        jobs[_jobId].completed = true;
        jobs[_jobId].assetHash = _assetHash;
        
        emit JobCompleted(_jobId, _assetHash);
    }

    /**
     * @dev Retrieve job details
     */
    function getJob(uint256 _jobId) external view returns (GenerationJob memory) {
        return jobs[_jobId];
    }
}
