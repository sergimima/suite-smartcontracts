// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RSKQuest
 * @dev Contrato NFT global para certificados de RSK Quest (OpenZeppelin v5.x)
 * 
 * Características:
 * - Un solo contrato para campañas y actividades
 * - Metadatos dinámicos por campaña/actividad
 * - Tracking de ID por token (definido por backend)
 * - Un NFT por usuario por ID
 * - Backend controla la estructura de IDs
 */
contract RSKQuest is ERC721, ERC721URIStorage, ERC721Enumerable, Ownable {
    uint256 private _nextTokenId;
    
    // Mapping: Token ID → Campaign ID
    mapping(uint256 => string) public tokenToCampaign;
    
    // Mapping: Token ID → Activity ID (vacío si es NFT de campaña)
    mapping(uint256 => string) public tokenToActivity;
    
    // Mapping: Campaign ID → Total Supply
    mapping(string => uint256) public campaignSupply;
    
    // Mapping: Campaign ID + Activity ID → Total Supply
    mapping(string => mapping(string => uint256)) public activitySupply;
    
    // Mapping: User Address + Campaign ID → Has Minted Campaign
    mapping(address => mapping(string => bool)) public userHasCampaignCertificate;
    
    // Mapping: User Address + Campaign ID + Activity ID → Has Minted Activity
    mapping(address => mapping(string => mapping(string => bool))) public userHasActivityCertificate;

    event CertificateMinted(
        address indexed to,
        uint256 indexed tokenId,
        string indexed campaignId,
        string activityId,
        string tokenURI
    );

    constructor(address initialOwner) ERC721("RSK Quest", "RSKQ") Ownable(initialOwner) {
        _nextTokenId = 1; // Empezar desde 1 en lugar de 0
    }

    /**
     * @dev Mintea un certificado NFT (usuario paga)
     * @param tokenURI Metadatos del NFT (procesados por backend)
     * @param campaignId ID de la campaña (obligatorio)
     * @param activityId ID de la actividad (opcional, vacío si es NFT de campaña)
     */
    function mintCertificate(
        string memory tokenURI,
        string memory campaignId,
        string memory activityId
    ) external payable returns (uint256) {
        require(bytes(tokenURI).length > 0, "Token URI cannot be empty");
        require(bytes(campaignId).length > 0, "Campaign ID cannot be empty");
        
        uint256 tokenId = _nextTokenId;
        _nextTokenId++;
        
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenURI);
        
        // Store campaign and activity IDs
        tokenToCampaign[tokenId] = campaignId;
        tokenToActivity[tokenId] = activityId;
        
        // Check if it's a campaign certificate or activity certificate
        if (bytes(activityId).length == 0) {
            // NFT de campaña
            require(!userHasCampaignCertificate[msg.sender][campaignId], "User already minted campaign certificate");
            userHasCampaignCertificate[msg.sender][campaignId] = true;
            campaignSupply[campaignId]++;
        } else {
            // NFT de actividad
            require(!userHasActivityCertificate[msg.sender][campaignId][activityId], "User already minted activity certificate");
            userHasActivityCertificate[msg.sender][campaignId][activityId] = true;
            activitySupply[campaignId][activityId]++;
        }
        
        emit CertificateMinted(msg.sender, tokenId, campaignId, activityId, tokenURI);
        return tokenId;
    }

    /**
     * @dev Verifica si una dirección tiene un certificado de campaña
     */
    function hasCampaignCertificate(address user, string memory campaignId) 
        public view returns (bool) {
        return userHasCampaignCertificate[user][campaignId];
    }
    
    /**
     * @dev Verifica si una dirección tiene un certificado de actividad
     */
    function hasActivityCertificate(address user, string memory campaignId, string memory activityId) 
        public view returns (bool) {
        return userHasActivityCertificate[user][campaignId][activityId];
    }
    
    /**
     * @dev Obtiene el Campaign ID de un token
     */
    function getCampaignId(uint256 tokenId) public view returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return tokenToCampaign[tokenId];
    }
    
    /**
     * @dev Obtiene el Activity ID de un token
     */
    function getActivityId(uint256 tokenId) public view returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return tokenToActivity[tokenId];
    }

    /**
     * @dev Obtiene el siguiente token ID que será minteado
     */
    function getNextTokenId() public view returns (uint256) {
        return _nextTokenId;
    }

    // Required overrides para OpenZeppelin v5.x
    function _update(address to, uint256 tokenId, address auth)
        internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, ERC721Enumerable, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
