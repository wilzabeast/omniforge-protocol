/**
 * OmniForge Protocol - Web3 Wallet Connection Layer
 * Integrates Coinbase Smart Wallet for frictionless user onboarding on the Base network.
 * 
 * IMPROVEMENTS:
 * - Exponential backoff retry logic for network switches
 * - Health monitoring with auto-reconnection
 * - Account validation and race condition handling
 * - Comprehensive error logging for debugging
 */

class OmniForgeWalletConnector {
    constructor(maxRetries = 3, healthCheckIntervalMs = 30000) {
        this.userAddress = null;
        this.chainId = "0x2105"; // Hex code for Base Mainnet (8453)
        this.isConnecting = false;
        this.maxRetries = maxRetries;
        this.healthCheckIntervalMs = healthCheckIntervalMs;
        this.connectionHistory = [];
        this.lastHealthCheck = null;
        this.healthMonitoringActive = false;
        this.eventListeners = [];
    }

    /**
     * Checks if an Ethereum provider (like Coinbase Wallet or MetaMask) is injected into the browser.
     */
    checkProvider() {
        if (typeof window.ethereum !== 'undefined') {
            this.printStatus("[Web3] Ethereum provider detected.", "INFO");
            return true;
        }
        this.printStatus("[Web3 Error] No Web3 provider found. Please install Coinbase Wallet.", "ERROR");
        return false;
    }

    /**
     * Validates that accounts array is non-empty before using.
     * Prevents "Cannot read property '0' of undefined" errors.
     */
    validateAccounts(accounts) {
        if (!accounts || !Array.isArray(accounts) || accounts.length === 0) {
            throw new Error("Wallet connection rejected or returned no accounts");
        }
        return accounts[0];
    }

    /**
     * Requests wallet connection with account validation.
     * Handles both acceptance and rejection gracefully.
     */
    async connectWallet() {
        if (!this.checkProvider() || this.isConnecting) {
            if (this.isConnecting) {
                this.printStatus("Connection already in progress", "WARN");
            }
            return null;
        }

        try {
            this.isConnecting = true;
            this.printStatus("Connecting to Coinbase Smart Wallet via Passkey...", "INFO");

            // Request account access from the wallet
            const accounts = await window.ethereum.request({ 
                method: 'eth_requestAccounts' 
            });
            
            // Validate accounts before assignment
            this.userAddress = this.validateAccounts(accounts);
            this.printStatus(`Wallet connected successfully! Address: ${this.userAddress}`, "SUCCESS");
            
            // Log connection for history
            this.connectionHistory.push({
                timestamp: Date.now(),
                address: this.userAddress,
                status: "connected"
            });

            // Ensure the user is connected to the Base network
            await this.ensureBaseNetwork();

            // Start health monitoring
            this.startHealthMonitoring();

            // Emit connection event
            this.emitEvent("walletConnected", { address: this.userAddress });

            return this.userAddress;

        } catch (error) {
            const errorMsg = `Connection Failed: ${error.message || error}`;
            this.printStatus(errorMsg, "ERROR");
            
            this.connectionHistory.push({
                timestamp: Date.now(),
                error: error.message,
                status: "failed"
            });

            this.emitEvent("walletConnectionFailed", { error: error.message });
            return null;

        } finally {
            this.isConnecting = false;
        }
    }

    /**
     * Ensures user is connected to Base network with exponential backoff retry.
     * Handles race conditions and user-initiated network switches.
     * 
     * RETRY LOGIC:
     * - Attempt 1: Immediately
     * - Attempt 2: Wait 2 seconds (2^1)
     * - Attempt 3: Wait 4 seconds (2^2)
     */
    async ensureBaseNetwork() {
        for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
            try {
                const currentChainId = await window.ethereum.request({ 
                    method: 'eth_chainId' 
                });
                
                if (currentChainId === this.chainId) {
                    this.printStatus("Network successfully synced to Base Layer 2.", "SUCCESS");
                    return true;
                }

                this.printStatus(`Attempt ${attempt}/${this.maxRetries}: Prompting network switch to Base...`, "INFO");

                try {
                    // Request the wallet to switch to Base
                    await window.ethereum.request({
                        method: 'wallet_switchEthereumChain',
                        params: [{ chainId: this.chainId }],
                    });
                    
                    this.printStatus("Network successfully switched to Base.", "SUCCESS");
                    return true;

                } catch (switchError) {
                    // Error code 4902 = Network not added to wallet
                    if (switchError.code === 4902) {
                        this.printStatus("Base network not found in wallet. Adding it...", "INFO");
                        
                        try {
                            await window.ethereum.request({
                                method: 'wallet_addEthereumChain',
                                params: [{
                                    chainId: this.chainId,
                                    chainName: 'Base',
                                    rpcUrls: ['https://mainnet.base.org'],
                                    nativeCurrency: { 
                                        name: 'Ether', 
                                        symbol: 'ETH', 
                                        decimals: 18 
                                    },
                                    blockExplorerUrls: ['https://basescan.org']
                                }]
                            });
                            
                            this.printStatus("Base network added and switched successfully.", "SUCCESS");
                            return true;

                        } catch (addError) {
                            throw new Error(`Failed to add Base network: ${addError.message}`);
                        }
                    } else {
                        // User rejected or other error - retry with backoff
                        throw switchError;
                    }
                }

            } catch (error) {
                const backoffMs = Math.pow(2, attempt) * 1000;
                
                if (attempt < this.maxRetries) {
                    this.printStatus(
                        `Network switch failed (${error.message}). Retrying in ${backoffMs}ms...`,
                        "WARN"
                    );
                    
                    // Exponential backoff
                    await new Promise(resolve => setTimeout(resolve, backoffMs));
                    continue;
                } else {
                    throw new Error(`Network switch failed after ${this.maxRetries} attempts: ${error.message}`);
                }
            }
        }
    }

    /**
     * Health check: Verifies wallet connection and network status.
     * Can be called periodically or on-demand.
     */
    async healthCheck() {
        try {
            if (typeof window.ethereum === 'undefined') {
                return {
                    isHealthy: false,
                    error: "Ethereum provider not found",
                    timestamp: Date.now()
                };
            }

            const chainId = await window.ethereum.request({ 
                method: 'eth_chainId' 
            });
            
            const accounts = await window.ethereum.request({ 
                method: 'eth_accounts' 
            });

            const isHealthy = (
                chainId === this.chainId && 
                accounts && 
                accounts.length > 0 && 
                accounts[0] === this.userAddress
            );

            this.lastHealthCheck = {
                isHealthy,
                chainId,
                address: accounts[0] || null,
                expectedChainId: this.chainId,
                expectedAddress: this.userAddress,
                timestamp: Date.now()
            };

            if (!isHealthy) {
                this.printStatus(
                    `Health check failed: chainId=${chainId}, connected=${accounts.length > 0}`,
                    "WARN"
                );
            }

            return this.lastHealthCheck;

        } catch (error) {
            this.printStatus(`Health check error: ${error.message}`, "ERROR");
            return { 
                isHealthy: false, 
                error: error.message,
                timestamp: Date.now()
            };
        }
    }

    /**
     * Starts periodic health monitoring with automatic reconnection.
     * Gracefully handles wallet disconnections and network changes.
     */
    startHealthMonitoring(intervalMs = null) {
        if (this.healthMonitoringActive) {
            this.printStatus("Health monitoring already active", "WARN");
            return;
        }

        const checkInterval = intervalMs || this.healthCheckIntervalMs;
        this.healthMonitoringActive = true;

        this.printStatus(
            `Starting health monitoring with ${checkInterval}ms interval`,
            "INFO"
        );

        const monitoringHandle = setInterval(async () => {
            try {
                const health = await this.healthCheck();

                if (!health.isHealthy) {
                    this.printStatus("Health check failed. Attempting to reconnect...", "WARN");
                    
                    // Attempt graceful reconnection
                    const reconnectResult = await this.connectWallet();
                    if (reconnectResult) {
                        this.emitEvent("walletReconnected", { address: reconnectResult });
                    } else {
                        this.emitEvent("walletDisconnected", {});
                    }
                }

            } catch (error) {
                this.printStatus(`Health monitoring error: ${error.message}`, "ERROR");
            }
        }, checkInterval);

        // Store handle for cleanup
        this.healthMonitoringHandle = monitoringHandle;
    }

    /**
     * Stops health monitoring.
     */
    stopHealthMonitoring() {
        if (this.healthMonitoringHandle) {
            clearInterval(this.healthMonitoringHandle);
            this.healthMonitoringActive = false;
            this.printStatus("Health monitoring stopped", "INFO");
        }
    }

    /**
     * Event emission for external listeners.
     * Allows UI components to react to wallet state changes.
     */
    on(event, callback) {
        if (typeof callback !== 'function') {
            throw new Error("Callback must be a function");
        }
        this.eventListeners.push({ event, callback });
    }

    emitEvent(event, data) {
        this.eventListeners
            .filter(listener => listener.event === event)
            .forEach(listener => {
                try {
                    listener.callback(data);
                } catch (error) {
                    this.printStatus(`Event handler error for '${event}': ${error.message}`, "ERROR");
                }
            });
    }

    /**
     * Get current connection status and history.
     */
    getStatus() {
        return {
            isConnected: !!this.userAddress,
            address: this.userAddress,
            chainId: this.chainId,
            isConnecting: this.isConnecting,
            healthMonitoringActive: this.healthMonitoringActive,
            lastHealthCheck: this.lastHealthCheck,
            connectionAttempts: this.connectionHistory.length,
            recentErrors: this.connectionHistory
                .filter(entry => entry.status === 'failed')
                .slice(-5)
        };
    }

    /**
     * Enhanced status printing with severity levels.
     */
    printStatus(message, level = "INFO") {
        const timestamp = new Date().toISOString();
        const levelColor = {
            "ERROR": "❌",
            "WARN": "⚠️",
            "INFO": "ℹ️",
            "SUCCESS": "✓"
        }[level] || "•";

        console.log(`[${timestamp}] [OmniForge UI] [${level}] ${levelColor} ${message}`);
    }

    /**
     * Cleanup: Stop monitoring and remove listeners.
     */
    destroy() {
        this.stopHealthMonitoring();
        this.eventListeners = [];
        this.printStatus("OmniForge Wallet Connector destroyed", "INFO");
    }
}

// Global initialization check
const walletConnector = new OmniForgeWalletConnector();

// Example usage for testing
if (typeof window !== 'undefined' && !window.walletConnectorInitialized) {
    window.walletConnectorInitialized = true;
    
    // Listen for wallet events
    walletConnector.on('walletConnected', (data) => {
        console.log('Wallet connected:', data.address);
    });

    walletConnector.on('walletDisconnected', () => {
        console.log('Wallet disconnected');
    });

    walletConnector.on('walletReconnected', (data) => {
        console.log('Wallet reconnected:', data.address);
    });

    walletConnector.on('walletConnectionFailed', (data) => {
        console.log('Connection failed:', data.error);
    });
}

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = OmniForgeWalletConnector;
}
