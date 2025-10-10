// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title KukuxumusuNFT
 * @dev ERC721 NFT contract for Kukuxumusu on Story Protocol
 * @notice Mints NFTs with restricted access control for authorized minters only
 */
contract KukuxumusuNFT is
    ERC721,
    ERC721URIStorage,
    ERC2981,
    Ownable,
    ReentrancyGuard,
    Pausable
{
    /// @notice Base URI for computing tokenURI
    string private _baseTokenURI;

    /// @notice Maximum supply of NFTs that can be minted
    uint256 public maxSupply;

    /// @notice Current number of minted NFTs
    uint256 public totalMinted;

    /// @notice Mapping of authorized minter addresses
    mapping(address => bool) public authorizedMinters;

    /// @notice Metadata structure for each token
    struct TokenMetadata {
        string uri;
        uint256 mintedAt;
    }

    /// @notice Mapping of token ID to metadata
    mapping(uint256 => TokenMetadata) public tokenMetadata;

    // Events
    event NFTMinted(
        address indexed to,
        uint256 indexed tokenId,
        string tokenURI,
        uint256 timestamp
    );

    event BatchMinted(
        address[] recipients,
        uint256[] tokenIds,
        uint256 timestamp
    );

    event AuthorizedMinterUpdated(
        address indexed minter,
        bool authorized
    );

    event BaseURIUpdated(string newBaseURI);

    event MaxSupplyUpdated(uint256 newMaxSupply);

    event RoyaltyUpdated(address indexed receiver, uint96 feeNumerator);

    /// @dev Modifier to restrict function access to authorized minters only
    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender], "Not an authorized minter");
        _;
    }

    /**
     * @dev Constructor to initialize the NFT contract
     * @param name_ The name of the NFT collection
     * @param symbol_ The symbol of the NFT collection
     * @param baseURI_ The base URI for token metadata
     * @param _maxSupply The maximum supply of NFTs
     * @param initialOwner The initial owner of the contract
     * @notice Royalties are set to 0 by default and can be configured later via setDefaultRoyalty()
     */
    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        uint256 _maxSupply,
        address initialOwner
    ) ERC721(name_, symbol_) Ownable(initialOwner) {
        require(_maxSupply > 0, "Max supply must be greater than 0");

        _baseTokenURI = baseURI_;
        maxSupply = _maxSupply;

        // Royalties set to 0 by default, can be configured later via setDefaultRoyalty
    }

    /**
     * @notice Set or update an authorized minter
     * @param minter The address to authorize or unauthorize
     * @param authorized Whether the address should be authorized
     */
    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        require(minter != address(0), "Invalid minter address");
        authorizedMinters[minter] = authorized;
        emit AuthorizedMinterUpdated(minter, authorized);
    }

    /**
     * @notice Set the base URI for all tokens
     * @param baseURI_ The new base URI
     */
    function setBaseURI(string memory baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
        emit BaseURIUpdated(baseURI_);
    }

    /**
     * @notice Update the max supply (can only be decreased or set once)
     * @param _maxSupply The new max supply
     */
    function setMaxSupply(uint256 _maxSupply) external onlyOwner {
        require(_maxSupply >= totalMinted, "Cannot set max supply below current minted amount");
        maxSupply = _maxSupply;
        emit MaxSupplyUpdated(_maxSupply);
    }

    /**
     * @notice Set the default royalty for all tokens
     * @param receiver The address to receive royalties
     * @param feeNumerator The royalty fee in basis points (e.g., 500 = 5%)
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        require(receiver != address(0), "Invalid receiver address");
        require(feeNumerator <= 10000, "Royalty fee too high");
        _setDefaultRoyalty(receiver, feeNumerator);
        emit RoyaltyUpdated(receiver, feeNumerator);
    }

    /**
     * @notice Mint a new NFT to a specific address
     * @param to The address to mint to
     * @param tokenId The token ID to mint
     * @param tokenURI_ The token URI for metadata
     */
    function mint(
        address to,
        uint256 tokenId,
        string memory tokenURI_
    ) external onlyAuthorizedMinter nonReentrant whenNotPaused {
        require(to != address(0), "Cannot mint to zero address");
        require(totalMinted < maxSupply, "Max supply reached");
        require(bytes(tokenURI_).length > 0, "Token URI cannot be empty");

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI_);

        tokenMetadata[tokenId] = TokenMetadata({
            uri: tokenURI_,
            mintedAt: block.timestamp
        });

        totalMinted++;

        emit NFTMinted(to, tokenId, tokenURI_, block.timestamp);
    }

    /**
     * @notice Batch mint NFTs to multiple addresses
     * @param recipients Array of addresses to mint to
     * @param tokenIds Array of token IDs to mint
     * @param tokenURIs Array of token URIs for metadata
     */
    function batchMint(
        address[] calldata recipients,
        uint256[] calldata tokenIds,
        string[] calldata tokenURIs
    ) external onlyAuthorizedMinter nonReentrant whenNotPaused {
        require(recipients.length > 0, "Recipients array is empty");
        require(
            recipients.length == tokenIds.length && tokenIds.length == tokenURIs.length,
            "Array lengths mismatch"
        );
        require(totalMinted + recipients.length <= maxSupply, "Would exceed max supply");

        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Cannot mint to zero address");
            require(bytes(tokenURIs[i]).length > 0, "Token URI cannot be empty");

            _safeMint(recipients[i], tokenIds[i]);
            _setTokenURI(tokenIds[i], tokenURIs[i]);

            tokenMetadata[tokenIds[i]] = TokenMetadata({
                uri: tokenURIs[i],
                mintedAt: block.timestamp
            });

            totalMinted++;
        }

        emit BatchMinted(recipients, tokenIds, block.timestamp);
    }

    /**
     * @notice Pause all token transfers and minting
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause all token transfers and minting
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Get the base URI for token metadata
     * @return The base URI string
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @notice Override to check pause status before transfers
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override whenNotPaused returns (address) {
        return super._update(to, tokenId, auth);
    }

    /**
     * @notice Get token URI - overrides required for ERC721URIStorage
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @notice Check if contract supports an interface
     * @param interfaceId The interface identifier
     * @return True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721URIStorage, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Get metadata for a specific token
     * @param tokenId The token ID
     * @return The token metadata struct
     */
    function getTokenMetadata(uint256 tokenId) external view returns (TokenMetadata memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return tokenMetadata[tokenId];
    }

    /**
     * @notice Check how many more NFTs can be minted
     * @return The remaining supply
     */
    function remainingSupply() external view returns (uint256) {
        return maxSupply - totalMinted;
    }
}