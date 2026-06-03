/**
 * OmniForge Protocol - Web3 Wallet Connection Layer
 * Integrates Coinbase Smart Wallet for frictionless user onboarding on the Base network.
 */

class OmniForgeWalletConnector {
    constructor() {
        this.userAddress = null;
        this.chainId = "0x2105"; // Hex code for Base Mainnet (8453)
        this.isConnecting = false;
    }

    /**
     * Checks if an Ethereum provider (like Coinbase Wallet or MetaMask) is injected into the browser.
     */
    checkProvider() {
        if (typeof window.ethereum !== 'undefined') {
            printStatus("[Web3] Ethereum provider detected.");
            return true;
        }
        printStatus("[Web3 Error] No Web3 provider found. Please install Coinbase Wallet.");
        return false;
    }

    /**
     * Requests wallet connection and forces network switch to Base Layer 2.
     */
    async connectWallet() {
        if (!this.checkProvider() || this.isConnecting) return;

        try {
            this.isConnecting = true;
            printStatus("Connecting to Coinbase Smart Wallet via Passkey...");

            // Request account access from the wallet
            const accounts = await window.ethereum.request({ 
                method: 'eth_requestAccounts' 
            });
            
            this.userAddress = accounts[0];
            printStatus(`Wallet connected successfully! Address: ${this.userAddress}`);

            // Ensure the user is connected to the Base network
            await this.ensureBaseNetwork();

            return this.userAddress;

        } catch (error) {
            printStatus(`Connection Failed: ${error.message}`);
        } finally {
            this.isConnecting = false;
        }
    }

    /**
     * Verification loop to guarantee the transaction occurs on Base L2 to keep gas fees low.
     */
    async ensureBaseNetwork() {
        try {
            const currentChainId = await window.ethereum.request({ method: 'eth_chainId' });
            
            if (currentChainId !== this.chainId) {
                printStatus("Incorrect network detected. Prompting switch to Base network...");
                try {
                    // Request the wallet to switch to Base
                    await window.ethereum.request({
                        method: 'wallet_switchEthereumChain',
                        params: [{ chainId: this.chainId }],
                    });
                } catch (switchError) {
                    // If the network isn't added to their wallet, request to add it
                    if (switchError.code === 4902) {
                        await window.ethereum.request({
                            method: 'wallet_addEthereumChain',
                            params: [{
                                chainId: this.chainId,
                                chainName: 'Base',
                                rpcUrls: ['https://mainnet.base.org'],
                                nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
                                blockExplorerUrls: ['https://basescan.org']
                            }]
                        });
                    } else {
                        throw switchError;
                    }
                }
            }
            printStatus("Network successfully synced to Base Layer 2.");
        } catch (error) {
            printStatus(`Network Switch Error: ${error.message}`);
        }
    }
}

// UI Helper function to simulate screen output
function printStatus(message) {
    console.log(`[OmniForge UI] ${message}`);
}

// Global initialization check
const walletConnector = new OmniForgeWalletConnector();