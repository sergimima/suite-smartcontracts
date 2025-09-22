# 🚀 Smart Contract Deployment Guide

Complete guide for deploying `ActivitiesPlatformCertificates` smart contract securely.

## 📋 Prerequisites

1. **Foundry installed** - [Installation Guide](https://book.getfoundry.sh/getting-started/installation)
2. **Git** (for cloning dependencies)
3. **Wallet with funds** for deployment
4. **RPC endpoint** (Alchemy, Infura, etc.)
5. **API keys** for contract verification (optional)

## 🔧 Setup

### 1. Environment Configuration

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your configuration
nano .env  # or use your preferred editor
```

### 2. Required Environment Variables

```bash
# === WALLET CONFIGURATION ===
# Choose ONE method:

# Option 1: Private Key (NOT RECOMMENDED for production)
PRIVATE_KEY=your_private_key_here

# Option 2: Mnemonic (NOT RECOMMENDED for production)
MNEMONIC="your twelve word mnemonic phrase here"

# Option 3: Keystore (RECOMMENDED)
KEYSTORE_PATH=./keystore/wallet.json
KEYSTORE_PASSWORD=your_keystore_password

# === NETWORK CONFIGURATION ===
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
ETH_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_API_KEY
POLYGON_RPC_URL=https://polygon-mainnet.alchemyapi.io/v2/YOUR_API_KEY

# === CONTRACT CONFIGURATION ===
INITIAL_OWNER=0x1234567890123456789012345678901234567890  # Optional

# === VERIFICATION ===
ETHERSCAN_API_KEY=your_etherscan_api_key_here
POLYGONSCAN_API_KEY=your_polygonscan_api_key_here
```

## 🌐 Supported Networks

| Network | Chain ID | Currency | Type |
|---------|----------|----------|------|
| Sepolia | 11155111 | ETH | Testnet |
| Mumbai | 80001 | MATIC | Testnet |
| Ethereum | 1 | ETH | Mainnet |
| Polygon | 137 | MATIC | Mainnet |
| Arbitrum | 42161 | ETH | Mainnet |
| Optimism | 10 | ETH | Mainnet |

## 🚀 Deployment Methods

### Method 1: Using Scripts (Recommended)

#### Windows (PowerShell)
```powershell
# Test deployment (dry run)
.\deploy.ps1 sepolia -DryRun

# Deploy to testnet
.\deploy.ps1 sepolia -Verify

# Deploy to mainnet with custom owner
.\deploy.ps1 eth -Owner 0x1234... -Verify
```

#### Linux/Mac (Bash)
```bash
# Make script executable
chmod +x deploy.sh

# Test deployment (dry run)
./deploy.sh sepolia --dry-run

# Deploy to testnet
./deploy.sh sepolia --verify

# Deploy to mainnet with custom owner
./deploy.sh eth --owner 0x1234... --verify
```

### Method 2: Direct Forge Commands

#### Basic Deployment
```bash
# Load environment variables
source .env

# Deploy to Sepolia testnet
forge script script/DeployActivitiesPlatformCertificates.s.sol:DeployActivitiesPlatformCertificates \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    -vvvv
```

#### With Custom Configuration
```bash
# Set initial owner
export INITIAL_OWNER=0x1234567890123456789012345678901234567890

# Deploy to Polygon mainnet
forge script script/DeployActivitiesPlatformCertificates.s.sol:DeployActivitiesPlatformCertificates \
    --rpc-url $POLYGON_RPC_URL \
    --broadcast \
    --verify \
    -vvvv
```

### Method 3: Using Foundry Cast (Advanced)

```bash
# Deploy contract directly
forge create \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --verify \
    src/ActivitiesPlatformCertificates.sol:ActivitiesPlatformCertificates \
    --constructor-args 0x1234567890123456789012345678901234567890
```

## 🔐 Security Best Practices

### 1. Private Key Management

**❌ NEVER DO:**
- Hardcode private keys in scripts
- Commit .env files to git
- Share private keys in chat/email
- Use production keys on testnets

**✅ RECOMMENDED:**
- Use hardware wallets (Ledger/Trezor)
- Use keystore files with strong passwords
- Use environment variables
- Separate keys for different environments

### 2. Network Safety

**For Testnets:**
- Always test on testnets first
- Use testnet tokens (free from faucets)
- Verify contract functionality

**For Mainnet:**
- Double-check all parameters
- Start with small amounts
- Have emergency procedures ready
- Monitor gas prices

### 3. Verification

Always verify contracts on block explorers:
- Increases trust and transparency
- Enables easy interaction
- Allows source code review

## 📁 Deployment Artifacts

After successful deployment, check these locations:

```
deployments/
├── ActivitiesPlatformCertificates_1.json      # Ethereum mainnet
├── ActivitiesPlatformCertificates_11155111.json # Sepolia testnet
├── ActivitiesPlatformCertificates_137.json     # Polygon mainnet
└── ActivitiesPlatformCertificates_80001.json   # Mumbai testnet

broadcast/
└── DeployActivitiesPlatformCertificates.s.sol/
    ├── 1/                                      # Ethereum mainnet
    ├── 11155111/                              # Sepolia testnet
    └── run-latest.json                        # Latest deployment
```

## 🔍 Post-Deployment Verification

### 1. Contract Verification
```bash
# Manual verification if auto-verify failed
forge verify-contract \
    --chain-id 11155111 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address)" 0x1234...) \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    0xCONTRACT_ADDRESS \
    src/ActivitiesPlatformCertificates.sol:ActivitiesPlatformCertificates
```

### 2. Basic Functionality Test
```bash
# Check contract name
cast call 0xCONTRACT_ADDRESS "name()" --rpc-url $SEPOLIA_RPC_URL

# Check owner
cast call 0xCONTRACT_ADDRESS "owner()" --rpc-url $SEPOLIA_RPC_URL

# Check next token ID
cast call 0xCONTRACT_ADDRESS "getNextTokenId()" --rpc-url $SEPOLIA_RPC_URL
```

### 3. Integration Test
```bash
# Run integration tests against deployed contract
forge test --match-contract ActivitiesPlatformCertificatesTest --fork-url $SEPOLIA_RPC_URL
```

## 🚨 Troubleshooting

### Common Issues

**1. "Insufficient funds for gas"**
- Solution: Add more ETH/MATIC to your wallet

**2. "Nonce too low/high"**
- Solution: Reset wallet nonce or wait for pending transactions

**3. "Contract verification failed"**
- Solution: Check constructor arguments and optimization settings

**4. "RPC URL not responding"**
- Solution: Check RPC endpoint or try alternative provider

### Gas Optimization

```bash
# Check gas estimation
forge script script/DeployActivitiesPlatformCertificates.s.sol:DeployActivitiesPlatformCertificates \
    --rpc-url $SEPOLIA_RPC_URL \
    --gas-estimate

# Set custom gas price (in gwei)
export GAS_PRICE=20
```

## 📞 Support

- **Documentation**: [Foundry Book](https://book.getfoundry.sh/)
- **Issues**: Create an issue in this repository
- **Community**: [Foundry Telegram](https://t.me/foundry_rs)

## 🔄 Upgrade Path

For future contract upgrades:
1. Deploy new contract version
2. Update deployment artifacts
3. Migrate data if necessary
4. Update frontend/backend integrations

---

**⚠️ IMPORTANT**: Always test deployments on testnets before mainnet deployment!
