 ---
  🔷 PROMPT PARA GENERACIÓN DE SMART CONTRACTS - KUKUXUMUSU NFT MARKETPLACE

  📋 CONTEXTO DEL PROYECTO

  Necesito desarrollar un marketplace de NFTs con arquitectura cross-chain para la marca Kukuxumusu. El sistema utiliza dos blockchains diferentes:
  - Base: Para gestionar pagos y subastas
  - Story Protocol: Para mintear NFTs

  Los usuarios pagan en Base (con múltiples tokens) y reciben automáticamente sus NFTs en Story Protocol mediante un relayer automatizado.

  ---
  🎯 CONTRATOS A DESARROLLAR

  1️⃣ PAYMENT CONTRACT (BASE NETWORK)

  Nombre del contrato: KukuxumusuPayment.sol

  Funcionalidad principal: Gestionar pagos multi-token y sistema de subastas

  Características requeridas:

  Pagos Multi-Token:

  - Aceptar pagos en ETH (nativo), VTN (ERC-20), y USDT (ERC-20)
  - Función directPurchase(uint256 nftId, address paymentToken, uint256 amount) para compra directa
  - Validación de token permitido (whitelist de tokens)
  - Validación de monto correcto según precio configurado por token
  - Transferencia de fondos a treasury multisig wallet

  Sistema de Subastas:

  - Crear múltiples subastas simultáneas con createAuction(uint256 nftId, uint256 duration, address[] allowedTokens, uint256[] minPrices)
  - Función placeBid(uint256 auctionId, address paymentToken, uint256 amount) para realizar pujas
  - Registro de todos los bidders con información de: dirección, token usado, monto, timestamp
  - Validación de tiempo límite de subasta
  - Determinar ganador automáticamente cuando expira el tiempo
  - Devolver fondos a bidders que no ganaron
  - Sistema anti-sniping (extensión de tiempo si hay bid en últimos X minutos)

  Gestión de Precios:

  - Función setPrice(uint256 nftId, address token, uint256 price) - solo owner
  - Precios diferentes por token (VTN, ETH, USDT)
  - Mapping de precios: mapping(uint256 => mapping(address => uint256)) public prices

  Treasury y Fondos:

  - Treasury multisig wallet configurable
  - Función withdraw(address token, uint256 amount) - solo owner
  - Soporte para withdraw de ETH y tokens ERC-20
  - Emergency pause functionality

  Eventos importantes:

  event PaymentReceived(address indexed buyer, uint256 indexed nftId, address token, uint256 amount, uint256 timestamp);
  event DirectPurchase(address indexed buyer, uint256 indexed nftId, address token, uint256 amount);
  event AuctionCreated(uint256 indexed auctionId, uint256 indexed nftId, uint256 endTime, address[] allowedTokens);
  event BidPlaced(uint256 indexed auctionId, address indexed bidder, address token, uint256 amount, uint256 timestamp);
  event AuctionWon(uint256 indexed auctionId, address indexed winner, uint256 indexed nftId, address token, uint256 finalAmount);

  Seguridad:

  - ReentrancyGuard para funciones de pago
  - Pausable pattern
  - Ownable para funciones admin
  - Validaciones de montos y tokens
  - Checks-effects-interactions pattern

  ---
  2️⃣ NFT CONTRACT (STORY PROTOCOL)

  Nombre del contrato: KukuxumusuNFT.sol

  Funcionalidad principal: Mintear NFTs con control de acceso restringido

  Características requeridas:

  Control de Acceso:

  - Solo una wallet autorizada (relayer) puede mintear
  - Mapping mapping(address => bool) public authorizedMinters
  - Modifier onlyAuthorizedMinter
  - Función setAuthorizedMinter(address minter, bool authorized) - solo owner

  Minting:

  - Estándar ERC-721 (OpenZeppelin)
  - Función mint(address to, uint256 tokenId, string memory tokenURI) - solo authorized minter
  - Función batchMint(address[] memory recipients, uint256[] memory tokenIds, string[] memory tokenURIs) - solo authorized minter
  - Base URI configurable para metadatos IPFS
  - Max supply configurable

  Metadatos:

  - Token URI apuntando a IPFS
  - Función setBaseURI(string memory baseURI) - solo owner
  - Override de tokenURI() para construir URI completo

  Royalties:

  - Implementar ERC-2981 (NFT Royalty Standard)
  - Royalty fee configurable (5-10%)
  - Función setDefaultRoyalty(address receiver, uint96 feeNumerator) - solo owner
  - Enviar royalties a treasury wallet

  Transferencias:

  - Transferencias estándar ERC-721
  - Sin restricciones una vez minteado

  Eventos importantes:

  event NFTMinted(address indexed to, uint256 indexed tokenId, string tokenURI, uint256 timestamp);
  event BatchMinted(address[] recipients, uint256[] tokenIds, uint256 timestamp);
  event AuthorizedMinterUpdated(address indexed minter, bool authorized);

  Seguridad:

  - Pausable pattern
  - Ownable
  - ReentrancyGuard si es necesario
  - Validaciones de tokenId único

  ---
  🔧 REQUISITOS TÉCNICOS

  Versión y Dependencias:

  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;

  // Usar OpenZeppelin Contracts v5.0
  import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
  import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
  import "@openzeppelin/contracts/token/common/ERC2981.sol";
  import "@openzeppelin/contracts/access/Ownable.sol";
  import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
  import "@openzeppelin/contracts/security/Pausable.sol";

  Optimización de Gas:

  - Usar uint256 en lugar de tipos más pequeños donde sea posible
  - Minimizar operaciones de storage
  - Usar calldata en lugar de memory para arrays en funciones external
  - Evitar loops donde sea posible
  - Usar eventos en lugar de storage para históricos

  Documentación:

  - Añadir NatSpec completo a todas las funciones públicas y externas
  - Comentarios explicativos en lógica compleja
  - Descripción clara de cada evento

  ---
  📊 ESTRUCTURAS DE DATOS SUGERIDAS

  Para Payment Contract:

  struct Auction {
      uint256 nftId;
      uint256 startTime;
      uint256 endTime;
      address highestBidder;
      address highestBidToken;
      uint256 highestBid;
      bool finalized;
      mapping(address => bool) allowedTokens;
  }

  struct Bid {
      address bidder;
      address token;
      uint256 amount;
      uint256 timestamp;
  }

  mapping(uint256 => Auction) public auctions;
  mapping(uint256 => Bid[]) public auctionBids;
  mapping(address => bool) public allowedPaymentTokens;

  Para NFT Contract:

  struct TokenMetadata {
      string uri;
      uint256 mintedAt;
  }

  mapping(uint256 => TokenMetadata) public tokenMetadata;

  ---
  ✅ TESTING REQUIREMENTS

  Para cada contrato, necesito también tests completos en Hardhat/Foundry que cubran:

  Payment Contract Tests:

  1. ✅ Direct purchase con ETH
  2. ✅ Direct purchase con tokens ERC-20 (VTN, USDT)
  3. ✅ Crear subasta
  4. ✅ Realizar pujas
  5. ✅ Determinar ganador al finalizar subasta
  6. ✅ Devolver fondos a perdedores
  7. ✅ Withdraw de fondos por owner
  8. ✅ Pause/unpause functionality
  9. ✅ Validaciones de tokens no permitidos
  10. ✅ Validaciones de montos incorrectos
  11. ✅ Anti-sniping functionality

  NFT Contract Tests:

  1. ✅ Mint por authorized minter
  2. ✅ Batch mint
  3. ✅ Rechazo de mint por wallet no autorizada
  4. ✅ Set base URI
  5. ✅ Token URI correcto
  6. ✅ Royalties funcionando (ERC-2981)
  7. ✅ Pause/unpause functionality
  8. ✅ Transferencias
  9. ✅ Max supply enforcement
  10. ✅ Authorized minter management

  Coverage objetivo: >90% en ambos contratos

  ---
  🔐 CONSIDERACIONES DE SEGURIDAD

  1. ReentrancyGuard: En todas las funciones que manejan fondos
  2. Pull over Push: Para devolver fondos a bidders perdedores
  3. Checks-Effects-Interactions: Pattern estricto
  4. Input validation: Validar todos los inputs
  5. Access control: Roles bien definidos
  6. Emergency stop: Pausable en ambos contratos
  7. Safe ERC20: Usar SafeERC20 de OpenZeppelin para transfers
  8. Events: Emitir eventos en todas las acciones importantes

  ---
  📝 DELIVERABLES ESPERADOS

  1. KukuxumusuPayment.sol - Contrato completo con todas las funcionalidades
  2. KukuxumusuNFT.sol - Contrato ERC-721 completo
  3. Tests - Suite completa de tests en Hardhat o Foundry
  4. Deploy scripts - Scripts para deploy en Base y Story Protocol testnets
  5. README.md - Documentación de:
    - Cómo compilar
    - Cómo correr tests
    - Cómo hacer deploy
    - Direcciones de contratos desplegados
    - ABIs exportados

  ---
  🎨 NOTAS ADICIONALES

  - Los contratos deben ser gas-efficient
  - Código limpio y bien comentado
  - Seguir best practices de Solidity
  - Los NFTs tendrán imágenes de 2000x2000px almacenadas en IPFS
  - El proyecto se inspira en el diseño de nouns.wtf
