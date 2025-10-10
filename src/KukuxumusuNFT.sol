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
 * @dev Simple NFT contract for Story Protocol with auction integration
 * @notice Allows authorized minters (backend/relayer) to mint NFTs to auction winners
 */
contract KukuxumusuNFT is ERC721, ERC721URIStorage, ERC2981, Ownable, ReentrancyGuard, Pausable {

    /// @notice Base URI for token metadata (e.g., "ipfs://")
    string private _baseTokenURI;

    /// @notice Maximum supply of NFTs (0 = unlimited)
    uint256 public immutable maxSupply;

    /// @notice Total number of NFTs minted
    uint256 public totalMinted;

    /// @notice Mapping of authorized minters (backend addresses)
    mapping(address => bool) public authorizedMinters;

    // Events
    event NFTMinted(address indexed to, uint256 indexed tokenId, string tokenURI, uint256 timestamp);
    event BatchMinted(address[] to, uint256[] tokenIds, uint256 timestamp);
    event AuthorizedMinterUpdated(address indexed minter, bool authorized);
    event BaseURIUpdated(string newBaseURI);
    event RoyaltyUpdated(address receiver, uint96 feeNumerator);

    /**
     * @dev Modifier to restrict function access to authorized minters only
     */
    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender], "Not an authorized minter");
        _;
    }

    /**
     * @dev Constructor to initialize the NFT contract
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param baseURI_ Base URI for metadata
     * @param maxSupply_ Maximum supply (0 = unlimited)
     * @param initialOwner Address of the contract owner
     * @param royaltyReceiver Address to receive royalties
     * @param royaltyFee Royalty fee in basis points (e.g., 500 = 5%)
     */
    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        uint256 maxSupply_,
        address initialOwner,
        address royaltyReceiver,
        uint96 royaltyFee
    ) ERC721(name_, symbol_) Ownable(initialOwner) {
        _baseTokenURI = baseURI_;
        maxSupply = maxSupply_;

        // Set default royalty if specified
        if (royaltyReceiver != address(0) && royaltyFee > 0) {
            _setDefaultRoyalty(royaltyReceiver, royaltyFee);
        }
    }

    /**
     * @notice Mint a single NFT to a specific address
     * @param to Address to mint the NFT to
     * @param tokenId The token ID to mint
     * @param tokenURI_ The token URI for metadata (hash or full URI)
     */
    function mint(
        address to,
        uint256 tokenId,
        string memory tokenURI_
    ) external onlyAuthorizedMinter nonReentrant whenNotPaused {
        require(to != address(0), "Cannot mint to zero address");
        require(maxSupply == 0 || totalMinted < maxSupply, "Max supply reached");
        require(bytes(tokenURI_).length > 0, "Token URI cannot be empty");

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI_);

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
        require(
            maxSupply == 0 || totalMinted + recipients.length <= maxSupply,
            "Would exceed max supply"
        );

        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Cannot mint to zero address");
            require(bytes(tokenURIs[i]).length > 0, "Token URI cannot be empty");

            _safeMint(recipients[i], tokenIds[i]);
            _setTokenURI(tokenIds[i], tokenURIs[i]);

            totalMinted++;
        }

        emit BatchMinted(recipients, tokenIds, block.timestamp);
    }

    /**
     * @notice Set or remove an authorized minter
     * @param minter Address of the minter
     * @param authorized True to authorize, false to revoke
     */
    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        require(minter != address(0), "Invalid minter address");
        authorizedMinters[minter] = authorized;
        emit AuthorizedMinterUpdated(minter, authorized);
    }

    /**
     * @notice Update the base URI for token metadata
     * @param newBaseURI New base URI
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @notice Update royalty information
     * @param receiver Address to receive royalties
     * @param feeNumerator Royalty fee in basis points (e.g., 500 = 5%)
     */
    function updateRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        require(receiver != address(0), "Invalid royalty receiver");
        _setDefaultRoyalty(receiver, feeNumerator);
        emit RoyaltyUpdated(receiver, feeNumerator);
    }

    /**
     * @notice Pause all minting operations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause all minting operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Withdraw stuck ETH from contract (emergency)
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    /**
     * @notice Get the base URI for token metadata
     * @return The base URI string
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @notice Check how many more NFTs can be minted
     * @return The remaining supply (0 if unlimited)
     */
    function remainingSupply() external view returns (uint256) {
        if (maxSupply == 0) return type(uint256).max;
        return maxSupply - totalMinted;
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
}
