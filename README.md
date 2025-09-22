# 🚀 Smart Contract Testing & Deployment Suite

**A comprehensive, production-ready suite for testing and deploying smart contracts using Foundry.**

Built with security, scalability, and developer experience in mind.

## 🎯 Features

- ✅ **Complete Testing Suite** - Basic + Comprehensive tests covering 20+ scenarios
- ✅ **Secure Deployment** - Multi-network deployment with security best practices
- ✅ **Cross-Platform** - Windows (PowerShell) and Linux/Mac (Bash) support
- ✅ **Multi-Network** - Ethereum, Polygon, Arbitrum, Optimism support
- ✅ **Auto-Verification** - Automatic contract verification on block explorers
- ✅ **Production Ready** - Environment management and security hardening

## 📦 Contracts

### ActivitiesPlatformCertificates

NFT contract for issuing certificates for completed activities/campaigns.

**Key Features:**
- ERC721 compliant with URI storage and enumerable extensions
- One certificate per user per campaign (prevents duplicates)
- Campaign-based organization with supply tracking
- Owner-controlled minting with access control
- Transfer support while maintaining original minting records
- OpenZeppelin v5 compatible

**Contract Address:** `src/ActivitiesPlatformCertificates.sol`

## 🧪 Testing

### Quick Test
```bash
# Run all tests
forge test

# Run specific contract tests
forge test --match-contract ActivitiesPlatformCertificates

# Run with detailed output
forge test -vvv
```

### Test Suites

1. **Basic Tests** (`test/ActivitiesPlatformCertificates.t.sol`)
   - 7 core functionality tests
   - Deployment, minting, access control, events

2. **Comprehensive Tests** (`test/ActivitiesPlatformCertificatesComprehensive.t.sol`)
   - 18 advanced scenario tests
   - Edge cases, performance, integration flows
   - Based on 20 business scenarios in `scenarios/NFT.md`

### Test Results
```
✅ Basic Suite: 7/7 tests passed
✅ Comprehensive Suite: 18/18 tests passed
✅ Total: 25/25 tests passed (100% success rate)
```

## 🚀 Deployment

### Quick Start

1. **Setup Environment**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

2. **Deploy to Testnet**
   ```bash
   # Windows
   .\deploy.ps1 sepolia -Verify
   
   # Linux/Mac
   ./deploy.sh sepolia --verify
   ```

3. **Verify Deployment**
   ```bash
   .\verify.ps1 0xCONTRACT_ADDRESS sepolia
   ```

### Supported Networks

| Network | Type | Currency | Chain ID |
|---------|------|----------|----------|
| Sepolia | Testnet | ETH | 11155111 |
| Mumbai | Testnet | MATIC | 80001 |
| Ethereum | Mainnet | ETH | 1 |
| Polygon | Mainnet | MATIC | 137 |
| Arbitrum | Mainnet | ETH | 42161 |
| Optimism | Mainnet | ETH | 10 |

### Security Features

- 🔐 **No Private Key Exposure** - Uses environment variables and keystore files
- 🛡️ **Network Validation** - Confirms mainnet deployments with user
- 📝 **Deployment Artifacts** - Automatic saving of deployment information
- ✅ **Post-Deploy Verification** - Automated contract verification
- 🔍 **Functionality Testing** - Post-deployment contract validation

## 📁 Project Structure

```
suite-smartcontracts/
├── src/                                    # Smart contracts
│   └── ActivitiesPlatformCertificates.sol
├── test/                                   # Test suites
│   ├── ActivitiesPlatformCertificates.t.sol
│   └── ActivitiesPlatformCertificatesComprehensive.t.sol
├── script/                                 # Deployment scripts
│   └── DeployActivitiesPlatformCertificates.s.sol
├── scenarios/                              # Business scenarios
│   └── NFT.md
├── deployments/                            # Deployment artifacts
├── deploy.ps1                             # Windows deployment script
├── deploy.sh                              # Linux/Mac deployment script
├── verify.ps1                             # Contract verification script
├── .env.example                           # Environment template
├── DEPLOYMENT.md                          # Detailed deployment guide
└── foundry.toml                           # Foundry configuration
```

## 🛠️ Development

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git
- Node.js (optional, for additional tooling)

### Setup
```bash
# Clone dependencies
git submodule update --init --recursive

# Install Foundry dependencies
forge install

# Build contracts
forge build

# Run tests
forge test
```

### Adding New Contracts

1. Add contract to `src/`
2. Create test file in `test/`
3. Add deployment script in `script/`
4. Update documentation

## 📚 Documentation

- **[Deployment Guide](DEPLOYMENT.md)** - Complete deployment documentation
- **[Foundry Book](https://book.getfoundry.sh/)** - Official Foundry documentation
- **[Test Scenarios](scenarios/NFT.md)** - Business scenarios and edge cases

## 🔧 Foundry Commands

### Build
```shell
forge build
```

### Test
```shell
# Run all tests
forge test

# Run specific test
forge test --match-test test_MintCertificate

# Run with gas reporting
forge test --gas-report
```

### Format
```shell
forge fmt
```

### Gas Snapshots
```shell
forge snapshot
```

### Local Development
```shell
# Start local node
anvil

# Deploy to local node
forge script script/DeployActivitiesPlatformCertificates.s.sol:DeployActivitiesPlatformCertificates --rpc-url http://localhost:8545 --broadcast
```

### Cast (Contract Interaction)
```shell
# Call contract function
cast call 0xCONTRACT_ADDRESS "name()" --rpc-url $RPC_URL

# Send transaction
cast send 0xCONTRACT_ADDRESS "mintCertificate(address,string,string)" 0xUSER_ADDRESS "https://metadata.uri" "campaign1" --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

---

**⚠️ Security Notice**: Never commit private keys, mnemonics, or sensitive data. Always use environment variables and follow security best practices.
