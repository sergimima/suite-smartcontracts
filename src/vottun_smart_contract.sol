// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
// En OpenZeppelin v5, Counters está deprecado, usamos un contador simple

// Para OpenZeppelin v5, necesitamos importar IERC4906 para los metadatos
import "@openzeppelin/contracts/interfaces/IERC4906.sol";

/**
 * @title VottunAchievements
 * @dev Smart contract for Vottun's gamified learning platform
 * @dev Manages NFT achievements for completing educational tracks and levels
 */
contract VottunAchievements is ERC721, ERC721URIStorage, Ownable, Pausable, ReentrancyGuard {
    uint256 private _tokenIds; // Contador simple para los IDs de los tokens
    
    // ============ STRUCTS ============
    
    struct Achievement {
        string trackName;
        uint256 level;
        address originalMinter;
        string userId;
        uint256 timestamp;
        address client;
    }
    
    struct Track {
        string name;
        address client;
        uint256 maxLevel;
        bool active;
        uint256 freeMintsPerUser;
        uint256 basePriceAfterFree;
    }
    
    struct UserStats {
        uint256 totalMints;
        mapping(string => uint256) trackProgress; // trackName => highest level completed
    }
    
    // ============ STATE VARIABLES ============
    
    // Mapping from token ID to achievement details
    mapping(uint256 => Achievement) public achievements;
    
    // Mapping from track name to track details
    mapping(string => Track) public tracks;
    
    // Mapping from track name and level to price
    mapping(string => mapping(uint256 => uint256)) public levelPrices;
    
    // Mapping from user address to user statistics
    mapping(address => UserStats) private userStats;
    
    // Mapping from user address to userId (for verification)
    mapping(address => string) public userIds;
    
    // Mapping to track user's mints for free mint limit
    mapping(address => uint256) public userMintCount;
    
    // Mapping to track client revenue
    mapping(address => uint256) public clientRevenue;
    
    // Platform fee percentage (basis points, e.g., 500 = 5%)
    uint256 public platformFeePercentage = 500;
    
    // Platform fees collected
    uint256 public platformFees;
    
    // Array of all track names (for enumeration)
    string[] public trackNames;
    
    // ============ EVENTS ============
    
    event TrackCreated(string indexed trackName, address indexed client);
    event LevelAdded(string indexed trackName, uint256 level, uint256 price);
    event AchievementMinted(
        uint256 indexed tokenId,
        address indexed user,
        string indexed trackName,
        uint256 level,
        string userId
    );
    event PriceUpdated(string indexed trackName, uint256 level, uint256 newPrice);
    event RevenueWithdrawn(address indexed client, uint256 amount);
    event PaymentDistributed(string indexed trackName, address indexed client, uint256 amount, uint256 fee);
    
    // ============ MODIFIERS ============
    
    modifier trackExists(string memory trackName) {
        require(tracks[trackName].active, "Track does not exist");
        _;
    }
    
    modifier onlyTrackClient(string memory trackName) {
        require(tracks[trackName].client == msg.sender, "Not authorized for this track");
        _;
    }
    
    modifier validLevel(string memory trackName, uint256 level) {
        require(level > 0 && level <= tracks[trackName].maxLevel, "Invalid level");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor() ERC721("Vottun Achievements", "VOTTUN") Ownable(msg.sender) {}
    
    // ============ TRACK MANAGEMENT ============
    
    /**
     * @dev Creates a new educational track
     * @param trackName Unique name for the track
     * @param client Address of the client creating the track
     * @param freeMintsPerUser Number of free mints per user for this track
     * @param basePriceAfterFree Price after free mints are exhausted
     */
    function createTrack(
        string memory trackName,
        address client,
        uint256 freeMintsPerUser,
        uint256 basePriceAfterFree
    ) external onlyOwner {
        require(!tracks[trackName].active, "Track already exists");
        require(client != address(0), "Invalid client address");
        require(bytes(trackName).length > 0, "Track name cannot be empty");
        
        tracks[trackName] = Track({
            name: trackName,
            client: client,
            maxLevel: 0,
            active: true,
            freeMintsPerUser: freeMintsPerUser,
            basePriceAfterFree: basePriceAfterFree
        });
        
        trackNames.push(trackName);
        
        emit TrackCreated(trackName, client);
    }
    
    /**
     * @dev Adds a new level to an existing track
     * @param trackName Name of the track
     * @param level Level number (must be sequential)
     * @param price Price to mint this level's NFT
     */
    function addLevelToTrack(
        string memory trackName,
        uint256 level,
        uint256 price
    ) external trackExists(trackName) onlyTrackClient(trackName) {
        require(level == tracks[trackName].maxLevel + 1, "Level must be sequential");
        
        tracks[trackName].maxLevel = level;
        levelPrices[trackName][level] = price;
        
        emit LevelAdded(trackName, level, price);
    }
    
    /**
     * @dev Updates the price for a specific level
     * @param trackName Name of the track
     * @param level Level to update
     * @param newPrice New price for the level
     */
    function updateLevelPrice(
        string memory trackName,
        uint256 level,
        uint256 newPrice
    ) external trackExists(trackName) onlyTrackClient(trackName) validLevel(trackName, level) {
        levelPrices[trackName][level] = newPrice;
        emit PriceUpdated(trackName, level, newPrice);
    }
    
    // ============ USER MANAGEMENT ============
    
    /**
     * @dev Links a user's wallet address with their platform user ID
     * @param userAddress Wallet address of the user
     * @param userId Platform user ID
     */
    function linkUserAddress(address userAddress, string memory userId) external onlyOwner {
        require(userAddress != address(0), "Invalid user address");
        require(bytes(userId).length > 0, "User ID cannot be empty");
        
        userIds[userAddress] = userId;
    }
    
    // ============ NFT MINTING ============
    
    /**
     * @dev Mints an achievement NFT for completing a level
     * @param user Address of the user earning the achievement
     * @param trackName Name of the track
     * @param level Level completed
     * @param metadataURI IPFS URI containing the NFT metadata
     */
    function mintAchievement(
        address user,
        string memory trackName,
        uint256 level,
        string memory metadataURI
    ) external payable trackExists(trackName) validLevel(trackName, level) nonReentrant whenNotPaused {
        require(user != address(0), "Invalid user address");
        require(bytes(userIds[user]).length > 0, "User not registered");
        require(canAccessLevel(user, trackName, level), "Cannot access this level");
        
        // Check if user already has this achievement
        require(!hasAchievement(user, trackName, level), "Achievement already earned");
        
        // Calculate and validate payment
        uint256 requiredPayment = calculatePrice(user, trackName, level);
        require(msg.value >= requiredPayment, "Insufficient payment");
        
        // Increment counter
        _tokenIds++;
        uint256 newTokenId = _tokenIds;
        userMintCount[user]++;
        userStats[user].totalMints++;
        userStats[user].trackProgress[trackName] = level;
        
        // Mint the NFT
        _safeMint(user, newTokenId);
        _setTokenURI(newTokenId, metadataURI);
        
        // Store achievement details
        achievements[newTokenId] = Achievement({
            trackName: trackName,
            level: level,
            originalMinter: user,
            userId: userIds[user],
            timestamp: block.timestamp,
            client: tracks[trackName].client
        });
        
        // Handle payment distribution
        if (msg.value > 0) {
            _distributePayment(trackName, msg.value);
        }
        
        // Refund excess payment
        if (msg.value > requiredPayment) {
            payable(msg.sender).transfer(msg.value - requiredPayment);
        }
        
        emit AchievementMinted(newTokenId, user, trackName, level, userIds[user]);
    }
    
    /**
     * @dev Batch mint multiple achievements for a user (admin only)
     * @param user Address of the user
     * @param _trackNames Array of track names
     * @param _levels Array of levels
     * @param _metadataURIs Array of metadata URIs
     */
    function batchMintAchievements(
        address user,
        string[] memory _trackNames,
        uint256[] memory _levels,
        string[] memory _metadataURIs
    ) external onlyOwner nonReentrant whenNotPaused {
        require(_trackNames.length == _levels.length && _levels.length == _metadataURIs.length, "Array length mismatch");
        
        for (uint256 i = 0; i < _trackNames.length; i++) {
            if (tracks[_trackNames[i]].active && !hasAchievement(user, _trackNames[i], _levels[i])) {
                _mintAchievementInternal(user, _trackNames[i], _levels[i], _metadataURIs[i]);
            }
        }
    }
    
    // ============ INTERNAL FUNCTIONS ============
    
    /**
     * @dev Internal function to mint achievement without payment validation
     */
    function _mintAchievementInternal(
        address user,
        string memory trackName,
        uint256 level,
        string memory metadataURI
    ) internal {
        _tokenIds++;
        uint256 newTokenId = _tokenIds;
        
        userMintCount[user]++;
        userStats[user].totalMints++;
        userStats[user].trackProgress[trackName] = level;
        
        _safeMint(user, newTokenId);
        _setTokenURI(newTokenId, metadataURI);
        
        achievements[newTokenId] = Achievement({
            trackName: trackName,
            level: level,
            originalMinter: user,
            userId: userIds[user],
            timestamp: block.timestamp,
            client: tracks[trackName].client
        });
        
        emit AchievementMinted(newTokenId, user, trackName, level, userIds[user]);
    }
    
    /**
     * @dev Distributes payment between platform and client
     */
    function _distributePayment(string memory trackName, uint256 amount) internal {
        Track storage track = tracks[trackName];

        // La comisión se calcula en puntos base (10000 = 100%)
        uint256 fee = (amount * platformFeePercentage) / 10000;
        uint256 clientAmount = amount - fee;
        
        platformFees += fee;
        clientRevenue[track.client] += clientAmount;
        
        emit PaymentDistributed(trackName, track.client, amount, fee);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Calculates the price for minting a specific achievement
     * @param user Address of the user
     * @param trackName Name of the track
     * @param level Level to mint
     * @return price Price in wei
     */
    function calculatePrice(address user, string memory trackName, uint256 level) 
        public view returns (uint256) {

        uint256 price = levelPrices[trackName][level];
        Track memory track = tracks[trackName];

        // Si el nivel tiene un precio y el usuario tiene un crédito de mint gratuito, es gratis.
        // Si el nivel no tiene precio (price == 0), siempre es gratis.
        if (price > 0 && userMintCount[user] < track.freeMintsPerUser) {
            return 0;
        }
        
        return price;
    }
    
    /**
     * @dev Checks if a user can access a specific level
     * @param user Address of the user
     * @param trackName Name of the track
     * @param level Level to check access for
     * @return canAccess True if user can access the level
     */
    function canAccessLevel(address user, string memory trackName, uint256 level) 
        public view returns (bool canAccess) {
        if (level == 1) {
            return true; // Anyone can access level 1
        }
        
        // Must have completed previous level
        return userStats[user].trackProgress[trackName] >= (level - 1);
    }
    
    /**
     * @dev Checks if user has a specific achievement
     * @param user Address of the user
     * @param trackName Name of the track
     * @param level Level to check
     * @return hasIt True if user has the achievement
     */
    function hasAchievement(address user, string memory trackName, uint256 level) 
        public view returns (bool hasIt) {
        return userStats[user].trackProgress[trackName] >= level;
    }
    
    /**
     * @dev Gets user's progress in a specific track
     * @param user Address of the user
     * @param trackName Name of the track
     * @return progress Highest level completed
     */
    function getTrackProgress(address user, string memory trackName) 
        external view returns (uint256 progress) {
        return userStats[user].trackProgress[trackName];
    }
    
    /**
     * @dev Gets user's total mint count
     * @param user Address of the user
     * @return count Total number of NFTs minted
     */
    function getUserMintCount(address user) external view returns (uint256 count) {
        return userStats[user].totalMints;
    }
    
    /**
     * @dev Gets all track names
     * @return names Array of track names
     */
    function getAllTrackNames() external view returns (string[] memory names) {
        return trackNames;
    }
    
    /**
     * @dev Gets track details
     * @param trackName Name of the track
     * @return track Track struct
     */
    function getTrackDetails(string memory trackName) 
        external view returns (Track memory track) {
        return tracks[trackName];
    }
    
    // ============ REVENUE MANAGEMENT ============
    
    /**
     * @dev Allows clients to withdraw their earned revenue
     */
    function withdrawClientRevenue() external nonReentrant {
        uint256 amount = clientRevenue[msg.sender];
        require(amount > 0, "No revenue to withdraw");
        
        clientRevenue[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        
        emit RevenueWithdrawn(msg.sender, amount);
    }
    
    /**
     * @dev Allows owner to withdraw platform fees
     */
    function withdrawPlatformFees() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        
        payable(owner()).transfer(balance);
    }
    
    /**
     * @dev Updates platform fee percentage
     * @param newFeePercentage New fee percentage in basis points
     */
    function setPlatformFeePercentage(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage <= 2000, "Fee cannot exceed 20%"); // Max 20%
        platformFeePercentage = newFeePercentage;
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Pauses all contract operations
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpauses contract operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Deactivates a track (emergency use)
     * @param trackName Name of the track to deactivate
     */
    function deactivateTrack(string memory trackName) external onlyOwner {
        tracks[trackName].active = false;
    }
    
    // ============ OVERRIDES ============

    /**
     * @dev See {IERC721-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning. We add the whenNotPaused modifier for security.
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721)
        whenNotPaused
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }
    
    // ============ EMERGENCY FUNCTIONS ============
    
    /**
     * @dev Emergency function to recover stuck ETH
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    /**
     * @dev Updates contract metadata base URI (for reveals, etc.)
     */
    function setBaseURI(string memory baseURI) external onlyOwner {
        // Implementation would depend on specific requirements
        // This is a placeholder for potential future use
    }
}