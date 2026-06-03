# OmniForge Protocol: Two-Token Economy Architecture

## 🏗️ System Overview

OmniForge implements a dual-token model optimized for decentralized content generation and marketplace dynamics:

```
┌─────────────────────────────────────────────────────────────┐
│                    OmniForge Protocol                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐           ┌──────────────────┐       │
│  │  FORGE Token     │           │  OMNI Token      │       │
│  ├──────────────────┤           ├──────────────────┤       │
│  │ • Governance     │           │ • Content Purchase│      │
│  │ • Voting Rights  │           │ • USD Pegged      │       │
│  │ • 100M supply    │           │ • Deflationary    │       │
│  │ • Steering DAO   │           │ • 1B supply      │       │
│  └────────┬─────────┘           └────────┬─────────┘       │
│           │                             │                 │
│           ▼                             ▼                 │
│  ┌──────────────────────────────────────────────┐         │
│  │  OmniForgeGovernance Contract               │         │
│  │  • Proposals (PRICE, TREASURY, EMERGENCY)  │         │
│  │  • Voting (FORGE holders only)             │         │
│  │  • Vote counting & execution               │         │
│  └────────────────┬─────────────────────────────┘         │
│                   │                                        │
│                   ▼                                        │
│  ┌──────────────────────────────────────────────┐         │
│  │  ContentPricing Contract                    │         │
│  │  • USD-pegged pricing system               │         │
│  │  • Chainlink oracle integration            │         │
│  │  • Dynamic OMNI calculation               │         │
│  │  • Revenue tracking & splits              │         │
│  └─────────────────────────────────────────────┘         │
│           │           │              │                   │
│           ▼           ▼              ▼                   │
│    ┌──────────┐  ┌─────────┐  ┌───────────┐            │
│    │ Treasury │  │  Burn   │  │ Metrics   │            │
│    │ (90%)    │  │ (10%)   │  │ Tracking  │            │
│    └──────────┘  └─────────┘  └───────────┘            │
└─────────────────────────────────────────────────────────────┘
```

---

## 💰 Token Economics

### FORGE Token (Governance)

**Purpose**: Protocol steering and voting rights

| Parameter | Value |
|-----------|-------|
| Name | Forge |
| Symbol | FORGE |
| Total Supply | 100 million |
| Decimals | 18 |
| Use Case | Governance, voting, DAO participation |
| Transfer | Fully transferable |
| Burn | User-initiated burn available |

**Key Features**:
- ✅ ERC20 standard compliant
- ✅ Pausable (emergency governance)
- ✅ Burnable (deflation mechanism)
- ✅ Ownable (initial control, later DAO)

---

### OMNI Token (Content Currency)

**Purpose**: Purchasing content on the platform

| Parameter | Value |
|-----------|-------|
| Name | Omni |
| Symbol | OMNI |
| Total Supply | 1 billion |
| Decimals | 18 |
| Use Case | Content purchases, trading |
| Pegged To | USD via Chainlink |
| Burning | 10% of every purchase burned (deflationary) |

**Key Features**:
- ✅ ERC20 standard compliant
- ✅ Pausable (emergency governance)
- ✅ Pegged to USD for price stability
- ✅ Chainlink oracle integration
- ✅ Deflationary through burning

---

## 🎯 Content Pricing Model

### How It Works

The core innovation: **Content costs a fixed USD amount, NOT a fixed token amount**

```
User wants to buy a VIDEO ($10 USD)

┌─ OMNI current price: $0.50
│  OMNI needed = $10 / $0.50 = 20 OMNI
│
├─ OMNI current price: $1.00
│  OMNI needed = $10 / $1.00 = 10 OMNI
│
└─ OMNI current price: $2.00
   OMNI needed = $10 / $2.00 = 5 OMNI

✓ User always pays $10 worth of value
✓ Token volatility doesn't affect platform economics
```

### Default Content Pricing

| Content Type | USD Price | Example OMNI at $0.50 | Example OMNI at $1.00 |
|-------------|----------|----------------------|----------------------|
| IMAGE | $1.50 | 3 OMNI | 1.5 OMNI |
| AUDIO | $3.00 | 6 OMNI | 3 OMNI |
| VIDEO | $10.00 | 20 OMNI | 10 OMNI |
| DOCUMENT | $0.50 | 1 OMNI | 0.5 OMNI |
| BUNDLE | $15.00 | 30 OMNI | 15 OMNI |

**Governance-adjustable** via FORGE holder proposals.

---

### Revenue Distribution

When a user purchases content:

```
User pays: 20 OMNI (at $0.50/OMNI = $10)
           ↓
    ┌──────────────┴──────────────┐
    ↓                             ↓
Treasury (90%)                 Burn (10%)
18 OMNI                         2 OMNI
(Funds platform operations)     (Deflation)
```

**Impact**:
- Platform has predictable revenue stream
- Circulating supply gradually decreases
- OMNI becomes scarcer over time
- Value proposition improves for holders

---

## 📊 Governance Model

### FORGE Voting Rights

FORGE token holders can propose and vote on:

1. **PRICE_UPDATE**: Change content pricing (e.g., raise video from $10 to $15)
2. **TREASURY_CHANGE**: Update treasury address
3. **PARAMETER_UPDATE**: Adjust voting parameters
4. **EMERGENCY_PAUSE**: Pause all purchasing (security)

### Proposal Lifecycle

```
PENDING (voting delay)
   ↓
ACTIVE (voting period ~1 week)
   ↓
DEFEATED (if against votes > for votes)
   or
SUCCEEDED (if for votes > against votes)
   ↓
EXECUTED (by owner/DAO, with timelock)
```

### Voting Requirements

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Proposal Threshold | 100k FORGE | Prevent spam proposals |
| Voting Delay | 1 block | Minimal delay |
| Voting Period | 45,818 blocks (~1 week) | Time to deliberate |
| Vote Type | Simple Majority | Democratic |

---

## 🔧 Smart Contract Architecture

### ForgeToken.sol (100 lines)

```solidity
contract ForgeToken is ERC20, Ownable, Pausable
```

**Methods**:
- `mint(address to, uint256 amount)` - Owner/DAO mints
- `burn(uint256 amount)` - User-initiated burn
- `pause()` / `unpause()` - Emergency controls

---

### OmniToken.sol (120 lines)

```solidity
contract OmniToken is ERC20, Ownable, Pausable, ReentrancyGuard
```

**Methods**:
- `mint(address to, uint256 amount)` - Platform mints for users
- `burn(uint256 amount)` - User-initiated burn
- `setPriceOracle(address)` - Update Chainlink oracle
- `pause()` / `unpause()` - Emergency controls

---

### ContentPricing.sol (280+ lines) ⭐ CORE

```solidity
contract ContentPricing is Ownable, ReentrancyGuard, Pausable
```

**Key Methods**:

| Method | Purpose |
|--------|---------|
| `getOmniPriceUSD()` | Fetch current OMNI/USD from Chainlink |
| `calculateOmniNeeded(ContentType)` | Calculate OMNI needed for content |
| `purchaseContent(ContentType)` | Buy content (transfers, burns, tracks revenue) |
| `setContentPrice()` | Update USD pricing (governance) |

**Revenue Tracking**:
- `totalOmniCollected` - All-time revenue
- `userSpent[address]` - Per-user spending
- `contentTypeRevenue[type]` - Per-content-type revenue

---

### OmniForgeGovernance.sol (300+ lines) ⭐ CORE

```solidity
contract OmniForgeGovernance is Ownable, ReentrancyGuard
```

**Key Methods**:

| Method | Purpose |
|--------|---------|
| `createProposal()` | Propose changes (requires 100k FORGE) |
| `castVote()` | Vote on proposal |
| `finalizeVote()` | End voting, determine outcome |
| `executeProposal()` | Execute successful proposal |
| `updateGovernanceParameter()` | Adjust voting rules |

**Vote Types**:
- `0` = Against
- `1` = For
- `2` = Abstain

---

## 🚀 Deployment Steps

### Prerequisites

```bash
# Install dependencies
npm install @openzeppelin/contracts @chainlink/contracts hardhat ethers

# Get Base RPC (Sepolia testnet)
# https://rpc.ankr.com/base_sepolia
```

### Deployment Order

```
1. Deploy ForgeToken
   └─ Constructor: none
   └─ Initial supply: 100M FORGE → owner

2. Deploy OmniToken
   └─ Constructor: _priceOracle (Chainlink address)
   └─ Initial supply: 1B OMNI → owner

3. Deploy ContentPricing
   └─ Constructor: 
      ├─ _omniToken (OmniToken address)
      ├─ _forgeToken (ForgeToken address)
      ├─ _omniPriceFeed (Chainlink oracle)
      └─ _treasury (revenue address)

4. Deploy OmniForgeGovernance
   └─ Constructor:
      ├─ _forgeToken (ForgeToken address)
      └─ _contentPricingContract (ContentPricing address)

5. Setup Ownership
   └─ Transfer ContentPricing ownership to OmniForgeGovernance
   └─ Transfer OmniForgeGovernance ownership to DAO multisig
```

---

## 📍 Chainlink Oracle Integration

### Base Network OMNI/USD Feed

```javascript
// Base Mainnet
const OMNI_USD_FEED = "0x..."; // (To be determined)

// Base Sepolia (Testnet)
const OMNI_USD_FEED_TESTNET = "0x..."; // (To be configured)
```

**Price Feed Resolution**:
- Updates every 1 hour
- Staleness check: 3600 seconds max
- Decimal precision: 8 decimals (Chainlink standard)

---

## 🔐 Security Considerations

### Reentrancy Protection
✅ All payment methods use `nonReentrant` guard
✅ Transfers follow checks-effects-interactions pattern

### Oracle Staleness
✅ Checks timestamp >= block.timestamp - 3600 (1 hour)
✅ Prevents using stale prices

### Access Control
✅ Content pricing updates require governance
✅ Treasury address requires owner/governance
✅ Pausable mechanisms for emergency

### Burn Mechanism
✅ 10% of purchases automatically burned
✅ Deflationary by design
✅ Improves OMNI scarcity over time

---

## 📈 Economic Flow Diagram

```
User Timeline:
┌────────────────────────────────────────────────────┐
│ User wants VIDEO ($10)                            │
├────────────────────────────────────────────────────┤
│                                                    │
│ 1. Check OMNI balance ✓                           │
│    └─ Have 25 OMNI                                │
│                                                    │
│ 2. Call purchaseContent(VIDEO)                    │
│    └─ ContentPricing.getOmniPriceUSD()            │
│       └─ Chainlink returns: $0.50 per OMNI        │
│                                                    │
│ 3. Calculate OMNI needed                          │
│    └─ $10 / $0.50 = 20 OMNI                       │
│                                                    │
│ 4. Transfer 20 OMNI to ContentPricing             │
│    └─ User: 25 OMNI → 5 OMNI ✓                    │
│                                                    │
│ 5. Split revenue                                  │
│    ├─ 90% (18 OMNI) → Treasury                    │
│    └─ 10% (2 OMNI) → Burned ✓                     │
│                                                    │
│ 6. Content delivered ✓                            │
│                                                    │
│ 7. Metrics updated                                │
│    ├─ User spending: +$10                         │
│    ├─ Total revenue: +$10                         │
│    ├─ Content type revenue: +$10                  │
│    └─ Circulating supply: -2 OMNI                 │
└────────────────────────────────────────────────────┘
```

---

## 📊 Governance Flow Diagram

```
FORGE Holder Timeline:
┌────────────────────────────────────────────────────┐
│ Proposal: "Raise VIDEO price to $15"             │
├────────────────────────────────────────────────────┤
│                                                    │
│ 1. Holder has 200k FORGE (>100k threshold) ✓     │
│                                                    │
│ 2. Call createProposal(PRICE_UPDATE, ...)        │
│    └─ Proposal ID #5 created                      │
│    └─ Voting starts in 1 block                    │
│    └─ Voting lasts ~1 week                        │
│                                                    │
│ 3. FORGE holders vote                             │
│    ├─ Alice votes FOR with 50k FORGE              │
│    ├─ Bob votes AGAINST with 30k FORGE            │
│    └─ Carol votes FOR with 100k FORGE             │
│       └─ Total FOR: 150k, AGAINST: 30k            │
│                                                    │
│ 4. Voting period ends                             │
│                                                    │
│ 5. Call finalizeVote(5)                           │
│    └─ Status: SUCCEEDED (150k > 30k) ✓            │
│                                                    │
│ 6. DAO multisig calls executeProposal(5)          │
│    └─ ContentPricing.setContentPrice(            │
│       VIDEO, 1500000000 [15 * 10^8])              │
│    └─ Proposal status: EXECUTED ✓                │
│                                                    │
│ 7. Effect takes immediately                       │
│    └─ New VIDEO cost: $15 USD                     │
│    └─ Previous: 20 OMNI @ $0.50 = $10             │
│    └─ New: 30 OMNI @ $0.50 = $15 ✓               │
└────────────────────────────────────────────────────┘
```

---

## 🧪 Testing Scenarios

### Unit Tests

```solidity
// ForgeToken
✓ Initial supply correct (100M)
✓ Transfer works
✓ Burn works
✓ Pause/unpause toggles transfers

// OmniToken
✓ Initial supply correct (1B)
✓ Chainlink oracle integration
✓ Price updates work

// ContentPricing
✓ Calculate OMNI needed (various prices)
✓ Purchase updates treasury correctly (90%)
✓ Purchase burns correctly (10%)
✓ Revenue tracking increments
✓ Only governance can update prices
✓ Prevents purchase when paused

// OmniForgeGovernance
✓ Proposal creation requires 100k FORGE
✓ Voting works (FOR/AGAINST/ABSTAIN)
✓ Simple majority voting
✓ Execution updates prices
```

### Integration Tests

```
✓ User buys content → revenue flows → burn happens
✓ FORGE holder proposes → voting → execution → price changes
✓ Multiple purchases → revenue compounding
✓ Oracle price changes → OMNI needed changes
```

---

## 💡 Future Improvements

1. **Timelock**
   - Add 2-day timelock before governance execution
   - Allows community exit if bad governance

2. **Delegation**
   - Allow FORGE holders to delegate voting power
   - Easier participation for busy users

3. **Vesting**
   - Team FORGE tokens vest over 4 years
   - Prevents dumping

4. **Staking**
   - Earn rewards by staking FORGE/OMNI
   - Bootstrap initial adoption

5. **Cross-chain**
   - Bridge to Ethereum/Polygon
   - Multi-chain revenue streams

---

## 🎯 Grant Proposal Messaging

> "OmniForge introduces a **dual-token economy designed for content platform sustainability**. FORGE enables community governance, while OMNI provides USD-pegged pricing stability—ensuring creators and users experience predictable economics regardless of token volatility. Revenue is systematically deflated through burning, creating long-term value capture for token holders."

---

## ✅ Deployment Checklist

- [ ] Deploy ForgeToken to Base
- [ ] Deploy OmniToken with Chainlink oracle
- [ ] Deploy ContentPricing with treasury address
- [ ] Deploy OmniForgeGovernance
- [ ] Transfer ownership to governance contract
- [ ] Set treasury address
- [ ] Test all purchasing flows
- [ ] Test governance proposals
- [ ] Document oracle feeds
- [ ] Set up monitoring/alerts
- [ ] Audit smart contracts
- [ ] Launch on Base mainnet
