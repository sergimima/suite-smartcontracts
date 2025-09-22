# RSKQuest - Smart Contract for RSK

## 📋 Overview

**RSKQuest** is an NFT smart contract (ERC721) deployed on **RSK Testnet** that allows users to mint certificate NFTs upon completing campaigns and activities on the RSK Quest Hub platform.

### 🎯 Purpose
- **Campaign Certificates**: NFTs minted when completing an entire campaign
- **Activity Certificates**: NFTs minted when completing specific activities within a campaign
- **Payment System**: Users pay to mint their certificates (prices defined by backend)

## 🏗️ Contract Architecture

### Contract Information
- **Name**: RSK Quest
- **Symbol**: RSKQ
- **Standard**: ERC721 (NFT)
- **Network**: RSK Testnet
- **Address**: `0xA9bc478A44a8c8FE6fd505C1964dEB3cEe3b7abC`
- **Explorer**: [View on RSK Explorer](https://explorer.testnet.rootstock.io/address/0xA9bc478A44a8c8FE6fd505C1964dEB3cEe3b7abC)

### Technical Features
- ✅ **OpenZeppelin v5.x**: Secure and standard implementation
- ✅ **ERC721Enumerable**: Enumerable and queryable NFTs
- ✅ **ERC721URIStorage**: Dynamic metadata per token
- ✅ **Ownable**: Access control for administrative functions
- ✅ **Pausable**: Ability to pause the contract if needed

## 🔧 Main Features

### 1. Certificate Minting
```solidity
function mintCertificate(
    string memory tokenURI,    // NFT metadata (IPFS)
    string memory campaignId,  // Campaign ID (required)
    string memory activityId   // Activity ID (optional)
) external payable returns (uint256)
```

**Parameters:**
- `tokenURI`: Metadata URL (processed by backend and IPFS)
- `campaignId`: Unique campaign identifier
- `activityId`: Activity identifier (empty for campaign NFTs)

**Restrictions:**
- A user can only mint **one NFT per campaign**
- A user can only mint **one NFT per specific activity**
- The user must pay the price defined by the backend

### 2. Queries and Verifications

#### Check User Certificates
```solidity
// Check if a user has a campaign certificate
function hasCampaignCertificate(address user, string memory campaignId) 
    public view returns (bool)

// Check if a user has an activity certificate
function hasActivityCertificate(address user, string memory campaignId, string memory activityId) 
    public view returns (bool)
```

#### Get Token Information
```solidity
// Get Campaign ID of a token
function getCampaignId(uint256 tokenId) public view returns (string memory)

// Get Activity ID of a token
function getActivityId(uint256 tokenId) public view returns (string memory)

// Get the next token ID that will be minted
function getNextTokenId() public view returns (uint256)
```

#### Query Supply
```solidity
// Total NFTs minted for a campaign
mapping(string => uint256) public campaignSupply;

// Total NFTs minted for a specific activity
mapping(string => mapping(string => uint256)) public activitySupply;
```

## 🌐 Backend Integration

### Workflow
1. **Backend creates campaign/activity** (off-chain)
2. **User completes the task** on the platform
3. **Backend processes metadata** and uploads to IPFS
4. **Backend calculates price** (some are free, others have cost)
5. **User mints NFT** paying the corresponding price
6. **NFT is assigned to user** with unique metadata

### ID Structure
- **Campaign ID**: Unique campaign identifier
- **Activity ID**: Specific activity identifier (optional)

### Metadata
- **Processing**: Backend combines fixed and dynamic metadata
- **Storage**: IPFS for decentralization
- **Format**: Standard ERC721 JSON

## 💰 Payment System

### Price Types
- **Free**: Only gas fees (e.g.: first 100 users)
- **With Cost**: Price defined by backend + gas fees
- **Payment**: Users pay directly when minting

### Currency
- **RSK Testnet**: tRBTC (Test RBTC)
- **Gas Fees**: Paid in tRBTC

## 🔒 Security and Restrictions

### Duplicate Prevention
- A user cannot mint the same certificate twice
- Automatic verification before minting

### Access Control
- **Minting**: Any user can mint (public)
- **Administrative functions**: Only the contract owner

### Validations
- TokenURI cannot be empty
- CampaignID cannot be empty
- Token existence verification before queries

## 📊 Contract Events

```solidity
event CertificateMinted(
    address indexed to,        // User who received the NFT
    uint256 indexed tokenId,   // ID of the minted token
    string indexed campaignId, // Campaign ID
    string activityId,         // Activity ID
    string tokenURI           // Metadata URI
);
```

## 🛠️ Contract Interaction

### For Developers
```javascript
// Example of minting from frontend
const contract = new ethers.Contract(contractAddress, abi, signer);

const tx = await contract.mintCertificate(
    "https://ipfs.io/ipfs/QmYourMetadataHash",
    "campaign_123",
    "activity_456", // or "" for campaign NFT
    { value: ethers.utils.parseEther("0.01") } // Price in tRBTC
);
```

### For Users
1. Connect wallet (MetaMask with RSK Testnet)
2. Complete campaign/activity on RSK Quest Hub
3. Click "Claim NFT"
4. Confirm transaction and pay
5. Receive NFT in wallet

## 🔗 Useful Links

- **Contract on RSK Explorer**: [View Contract](https://explorer.testnet.rootstock.io/address/0xA9bc478A44a8c8FE6fd505C1964dEB3cEe3b7abC)
- **RSK Testnet Faucet**: [Get tRBTC](https://faucet.testnet.rootstock.io/)
- **RSK Testnet RPC**: `https://public-node.testnet.rsk.co`
- **Chain ID**: 31

## 📝 Important Notes

- **Testnet**: This contract is on RSK Testnet, not mainnet
- **tRBTC**: Uses test tokens, not real RBTC
- **Metadata**: Processed and stored by backend on IPFS
- **Prices**: Dynamically defined by backend
- **Owner**: The contract has an owner who can perform administrative functions

## 🚀 Next Steps

1. **Testing**: Test minting on RSK Testnet
2. **Integration**: Connect with RSK Quest Hub backend
3. **Frontend**: Implement user interface
4. **Mainnet**: Deploy on RSK Mainnet when ready

---

**Developed by**: RSK Quest Hub Team  
**Deploy Date**: January 2025  
**Network**: RSK Testnet  
**Version**: 1.0.0  
**Transaction Hash**: `0x9ccc0ca5e14824c6d66c73500f748e17e23b843ba745ab6e7497b85309d9c7f2`  
**Block Number**: 6852116
