// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/vottun_smart_contract.sol";

contract VottunAchievementsExtendedTest is Test {
    // Instancia del contrato que vamos a probar
    VottunAchievements public achievementsContract;

    // Direcciones para simular los diferentes roles
    address public owner = address(0x1);
    address public client = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public emergencyRecipient = address(0x5);

    /**
     * @dev Se ejecuta antes de cada test. Despliega el contrato y prepara el entorno.
     */
    function setUp() public {
        // Hacemos "prank" para simular que el 'owner' es quien despliega el contrato
        vm.prank(owner);
        achievementsContract = new VottunAchievements();

        // --- Preparamos el entorno para los tests ---

        // 1. El Owner crea un track para el 'client'
        vm.prank(owner);
        achievementsContract.createTrack("Bitcoin Basics", client, 2, 1 ether); // 2 free mints por usuario

        // 2. El 'client' anade tres niveles al track
        vm.prank(client);
        achievementsContract.addLevelToTrack("Bitcoin Basics", 1, 0.01 ether);
        vm.prank(client);
        achievementsContract.addLevelToTrack("Bitcoin Basics", 2, 1 ether);
        vm.prank(client);
        achievementsContract.addLevelToTrack("Bitcoin Basics", 3, 2 ether);

        // 3. El 'owner' registra a los usuarios
        vm.prank(owner);
        achievementsContract.linkUserAddress(user1, "test-user-id-1");
        vm.prank(owner);
        achievementsContract.linkUserAddress(user2, "test-user-id-2");
    }

    // ===================================
    //      TESTS DE FUNCIONES DE PAUSA
    // ===================================

    /**
     * @dev Test 1: Verifica que el owner puede pausar el contrato
     */
    function test_Pause_Success() public {
        // El owner pausa el contrato
        vm.prank(owner);
        achievementsContract.pause();
        
        // Verificamos que el contrato esta pausado
        assertTrue(achievementsContract.paused(), "El contrato deberia estar pausado");
        
        // Intentamos mintear un NFT mientras el contrato esta pausado
        vm.deal(user1, 0.01 ether);
        vm.expectRevert("EnforcedPause()");
        vm.prank(user1);
        achievementsContract.mintAchievement{value: 0.01 ether}(user1, "Bitcoin Basics", 1, "ipfs://level1");
    }

    /**
     * @dev Test 2: Verifica que solo el owner puede pausar el contrato
     */
    function test_Pause_Fail_NotOwner() public {
        // Intentamos pausar el contrato desde una cuenta que no es el owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, client));
        vm.prank(client);
        achievementsContract.pause();
    }

    /**
     * @dev Test 3: Verifica que el owner puede reanudar el contrato
     */
    function test_Unpause_Success() public {
        // Primero pausamos el contrato
        vm.prank(owner);
        achievementsContract.pause();
        
        // Verificamos que el contrato esta pausado
        assertTrue(achievementsContract.paused(), "El contrato deberia estar pausado");
        
        // Reanudamos el contrato
        vm.prank(owner);
        achievementsContract.unpause();
        
        // Verificamos que el contrato ya no esta pausado
        assertFalse(achievementsContract.paused(), "El contrato no deberia estar pausado");
        
        // Verificamos que ahora se puede mintear un NFT
        vm.deal(user1, 0.01 ether);
        vm.prank(user1);
        achievementsContract.mintAchievement{value: 0.01 ether}(user1, "Bitcoin Basics", 1, "ipfs://level1");
        
        // Verificamos que el NFT se minteo correctamente
        assertEq(achievementsContract.ownerOf(1), user1, "El propietario del NFT no es correcto");
    }

    // ===================================
    //    TESTS DE GESTION DE TRACKS
    // ===================================

    /**
     * @dev Test 4: Verifica que se puede desactivar un track
     */
    function test_DeactivateTrack_Success() public {
        // El owner desactiva el track
        vm.prank(owner);
        achievementsContract.deactivateTrack("Bitcoin Basics");
        
        // Verificamos que el track esta desactivado
        (, , , bool active, , ) = achievementsContract.tracks("Bitcoin Basics");
        assertFalse(active, "El track deberia estar desactivado");
        
        // Intentamos mintear un NFT de un track desactivado
        vm.deal(user1, 0.01 ether);
        vm.expectRevert("Track does not exist");
        vm.prank(user1);
        achievementsContract.mintAchievement{value: 0.01 ether}(user1, "Bitcoin Basics", 1, "ipfs://level1");
    }

    /**
     * @dev Test 5: Verifica que solo el owner puede desactivar un track
     */
    function test_DeactivateTrack_Fail_NotOwner() public {
        // Intentamos desactivar el track desde una cuenta que no es el owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, client));
        vm.prank(client);
        achievementsContract.deactivateTrack("Bitcoin Basics");
    }

    // ===================================
    //    TESTS DE GESTION DE USUARIOS
    // ===================================

    /**
     * @dev Test 6: Verifica que solo usuarios registrados pueden mintear NFTs
     */
    function test_MintAchievement_Fail_UserNotRegistered() public {
        // Creamos una direccion no registrada
        address nonRegisteredUser = address(0x999);
        
        // Le damos fondos al usuario no registrado
        vm.deal(nonRegisteredUser, 0.01 ether);
        
        // Intentamos mintear un NFT con un usuario no registrado
        vm.expectRevert("User not registered");
        vm.prank(nonRegisteredUser);
        achievementsContract.mintAchievement{value: 0.01 ether}(nonRegisteredUser, "Bitcoin Basics", 1, "ipfs://level1");
    }

    /**
     * @dev Test 7: Verifica que el owner puede vincular una dirección a un ID de usuario
     */
    function test_LinkUserAddress_Success() public {
        // Creamos una nueva direccion para vincular
        address newUser = address(0x999);
        
        // El owner vincula la direccion al ID de usuario
        vm.prank(owner);
        achievementsContract.linkUserAddress(newUser, "new-user-id");
        
        // Verificamos que el usuario esta registrado
        assertTrue(bytes(achievementsContract.userIds(newUser)).length > 0, "El usuario deberia estar registrado");
        
        // Verificamos que el usuario puede mintear un NFT
        vm.deal(newUser, 0.01 ether);
        vm.prank(newUser);
        achievementsContract.mintAchievement{value: 0.01 ether}(newUser, "Bitcoin Basics", 1, "ipfs://level1");
        
        // Verificamos que el NFT se minteo correctamente
        assertEq(achievementsContract.ownerOf(1), newUser, "El propietario del NFT no es correcto");
    }

    // ===================================
    //  TESTS DE FUNCIONES DE PLATAFORMA
    // ===================================

    /**
     * @dev Test 8: Verifica que el owner puede cambiar el porcentaje de comision de la plataforma
     */
    function test_SetPlatformFeePercentage_Success() public {
        // El owner cambia el porcentaje de comision
        vm.prank(owner);
        achievementsContract.setPlatformFeePercentage(1000); // 10%
        
        // Verificamos que el porcentaje de comision ha cambiado
        assertEq(achievementsContract.platformFeePercentage(), 1000, "El porcentaje de comision no se actualizo correctamente");
    }

    /**
     * @dev Test 9: Verifica que no se puede establecer un porcentaje de comision superior al 20%
     */
    function test_SetPlatformFeePercentage_Fail_TooHigh() public {
        // Intentamos establecer un porcentaje de comision superior al 20%
        vm.expectRevert("Fee cannot exceed 20%");
        vm.prank(owner);
        achievementsContract.setPlatformFeePercentage(2100); // 21%
    }

    /**
     * @dev Test 10: Verifica que el owner puede retirar las comisiones de la plataforma
     */
    function test_WithdrawPlatformFees_Success() public {
        // Establecemos un porcentaje de comision para asegurarnos que se generen comisiones
        vm.prank(owner);
        achievementsContract.setPlatformFeePercentage(1000); // 10%
        
        // Agotamos los mints gratuitos del usuario
        vm.startPrank(user1);
        // Mint nivel 1 (gratis)
        achievementsContract.mintAchievement{value: 0 ether}(user1, "Bitcoin Basics", 1, "ipfs://free1");
        // Mint nivel 2 (gratis)
        achievementsContract.mintAchievement{value: 0 ether}(user1, "Bitcoin Basics", 2, "ipfs://free2");
        vm.stopPrank();
        
        // Le damos fondos al usuario para pagar el nivel 3
        vm.deal(user1, 2 ether);
        
        // El usuario mintea el nivel 3 pagando el precio completo
        vm.prank(user1);
        achievementsContract.mintAchievement{value: 2 ether}(user1, "Bitcoin Basics", 3, "ipfs://level3");
        
        // Verificamos que el contrato tiene fondos
        uint256 contractBalance = address(achievementsContract).balance;
        assertGt(contractBalance, 0, "El contrato deberia tener fondos");
        
        // Damos balance inicial al owner para que pueda recibir ETH
        vm.deal(owner, 0);
        
        // El owner retira las comisiones
        uint256 balanceBefore = owner.balance;
        vm.prank(owner);
        achievementsContract.withdrawPlatformFees();
        
        // Verificamos que el saldo del owner ha aumentado
        assertEq(owner.balance, balanceBefore + contractBalance, "El saldo del owner no aumento correctamente");
        // Verificamos que el contrato ya no tiene fondos
        assertEq(address(achievementsContract).balance, 0, "El contrato deberia estar vacio");
    }

    // ===================================
    //      TESTS DE MINTEO MASIVO
    // ===================================

    /**
     * @dev Test 11: Verifica que el owner puede mintear NFTs en masa
     */
    function test_BatchMintAchievements_Success() public {
        // Preparamos los arrays para el minteo masivo
        string[] memory trackNames = new string[](2);
        trackNames[0] = "Bitcoin Basics";
        trackNames[1] = "Bitcoin Basics";
        
        uint256[] memory levels = new uint256[](2);
        levels[0] = 1;
        levels[1] = 2;
        
        string[] memory tokenURIs = new string[](2);
        tokenURIs[0] = "ipfs://batch1";
        tokenURIs[1] = "ipfs://batch2";
        
        // El owner mintea los NFTs en masa
        vm.prank(owner);
        achievementsContract.batchMintAchievements(user1, trackNames, levels, tokenURIs);
        
        // Verificamos que los NFTs se mintearon correctamente
        assertEq(achievementsContract.ownerOf(1), user1, "El propietario del NFT #1 no es correcto");
        assertEq(achievementsContract.ownerOf(2), user1, "El propietario del NFT #2 no es correcto");
        
        // Verificamos que el progreso del usuario se actualizo correctamente
        assertEq(achievementsContract.getTrackProgress(user1, "Bitcoin Basics"), 2, "El progreso del usuario no se actualizo correctamente");
    }

    /**
     * @dev Test 12: Verifica que solo el owner puede mintear NFTs en masa
     */
    function test_BatchMintAchievements_Fail_NotOwner() public {
        // Preparamos los arrays para el minteo masivo
        string[] memory trackNames = new string[](1);
        trackNames[0] = "Bitcoin Basics";
        
        uint256[] memory levels = new uint256[](1);
        levels[0] = 1;
        
        string[] memory tokenURIs = new string[](1);
        tokenURIs[0] = "ipfs://batch1";
        
        // Intentamos mintear NFTs en masa desde una cuenta que no es el owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, client));
        vm.prank(client);
        achievementsContract.batchMintAchievements(user1, trackNames, levels, tokenURIs);
    }

    // ===================================
    //   TESTS DE FUNCIONES DE EMERGENCIA
    // ===================================

    /**
     * @dev Test 13: Verifica que el owner puede retirar todos los fondos en caso de emergencia
     */
    function test_EmergencyWithdraw_Success() public {
        // Primero agotamos los mints gratuitos
        vm.startPrank(user1);
        achievementsContract.mintAchievement{value: 0 ether}(user1, "Bitcoin Basics", 1, "ipfs://free1");
        achievementsContract.mintAchievement{value: 0 ether}(user1, "Bitcoin Basics", 2, "ipfs://free2");
        vm.stopPrank();
        
        // Damos fondos al usuario para el mint pagado
        vm.deal(user1, 5 ether);
        
        // El usuario mintea el nivel 3 pagando el precio completo
        vm.prank(user1);
        achievementsContract.mintAchievement{value: 2 ether}(user1, "Bitcoin Basics", 3, "ipfs://level3");
        
        // Verificamos que el contrato tiene fondos
        uint256 contractBalance = address(achievementsContract).balance;
        assertGt(contractBalance, 0, "El contrato deberia tener fondos");
        
        // Damos balance inicial al owner para que pueda recibir ETH
        vm.deal(owner, 0);
        
        // El owner retira todos los fondos en caso de emergencia
        uint256 balanceBefore = owner.balance;
        vm.prank(owner);
        achievementsContract.emergencyWithdraw();
        
        // Verificamos que el saldo del owner ha aumentado y el contrato esta vacio
        assertEq(owner.balance, balanceBefore + contractBalance, "El saldo del owner no aumento correctamente");
        assertEq(address(achievementsContract).balance, 0, "El contrato deberia estar vacio");
    }

    /**
     * @dev Test 14: Verifica que solo el owner puede retirar fondos en caso de emergencia
     */
    function test_EmergencyWithdraw_Fail_NotOwner() public {
        // Intentamos retirar fondos en caso de emergencia desde una cuenta que no es el owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, client));
        vm.prank(client);
        achievementsContract.emergencyWithdraw();
    }

    // ===================================
    //      TESTS DE MINTS GRATUITOS
    // ===================================

    /**
     * @dev Test 15: Verifica que los usuarios pueden usar mints gratuitos
     */
    function test_FreeMints_Success() public {
        // Verificamos que el usuario tiene 2 mints gratuitos disponibles
        (, , , , uint256 freeMints, ) = achievementsContract.tracks("Bitcoin Basics");
        assertEq(freeMints, 2, "El numero de mints gratuitos no es correcto");
        
        // El usuario mintea el nivel 1 sin pagar (usando un mint gratuito)
        vm.prank(user1);
        achievementsContract.mintAchievement{value: 0 ether}(user1, "Bitcoin Basics", 1, "ipfs://free1");
        
        // Verificamos que el NFT se minteo correctamente
        assertEq(achievementsContract.ownerOf(1), user1, "El propietario del NFT no es correcto");
        
        // Verificamos que el contador de mints del usuario se incremento
        assertEq(achievementsContract.userMintCount(user1), 1, "El contador de mints del usuario no se incremento");
        
        // El usuario mintea el nivel 2 sin pagar (usando otro mint gratuito)
        vm.prank(user1);
        achievementsContract.mintAchievement{value: 0 ether}(user1, "Bitcoin Basics", 2, "ipfs://free2");
        
        // Verificamos que el NFT se minteo correctamente
        assertEq(achievementsContract.ownerOf(2), user1, "El propietario del NFT #2 no es correcto");
        
        // Verificamos que el contador de mints del usuario se incremento
        assertEq(achievementsContract.userMintCount(user1), 2, "El contador de mints del usuario no se incremento");
        
        // Intentamos mintear el nivel 3 sin pagar (ya no hay mints gratuitos disponibles)
        vm.expectRevert("Insufficient payment");
        vm.prank(user1);
        achievementsContract.mintAchievement{value: 0 ether}(user1, "Bitcoin Basics", 3, "ipfs://level3");
    }

    // ===================================
    //   TESTS DE ACTUALIZACION DE PRECIOS
    // ===================================

    /**
     * @dev Test 16: Verifica que un cliente puede actualizar el precio de un nivel
     */
    function test_UpdateLevelPrice_Success() public {
        // Verificamos el precio original
        uint256 originalPrice = achievementsContract.levelPrices("Bitcoin Basics", 1);
        assertEq(originalPrice, 0.01 ether, "El precio original no es correcto");
        
        // El cliente actualiza el precio del nivel 1
        vm.prank(client);
        achievementsContract.updateLevelPrice("Bitcoin Basics", 1, 0.05 ether);
        
        // Verificamos que el precio base se actualizo correctamente
        uint256 newPrice = achievementsContract.levelPrices("Bitcoin Basics", 1);
        assertEq(newPrice, 0.05 ether, "El precio del nivel no se actualizo correctamente");
        
        // Agotamos los mints gratuitos del usuario
        vm.startPrank(user1);
        // Mint nivel 1 (gratis)
        achievementsContract.mintAchievement{value: 0 ether}(user1, "Bitcoin Basics", 1, "ipfs://free1");
        // Mint nivel 2 (gratis)
        achievementsContract.mintAchievement{value: 0 ether}(user1, "Bitcoin Basics", 2, "ipfs://free2");
        vm.stopPrank();
        
        // Creamos un nuevo usuario para probar el precio actualizado
        address newUser = address(0x999);
        vm.prank(owner);
        achievementsContract.linkUserAddress(newUser, "new-test-user");
        
        // Agotamos los mints gratuitos del nuevo usuario
        vm.startPrank(newUser);
        // Mint nivel 1 (gratis)
        achievementsContract.mintAchievement{value: 0 ether}(newUser, "Bitcoin Basics", 1, "ipfs://free1-new");
        // Mint nivel 2 (gratis)
        achievementsContract.mintAchievement{value: 0 ether}(newUser, "Bitcoin Basics", 2, "ipfs://free2-new");
        vm.stopPrank();
        
        // Verificamos que ahora el usuario necesita pagar el precio completo
        uint256 requiredPayment = achievementsContract.calculatePrice(newUser, "Bitcoin Basics", 3);
        assertEq(requiredPayment, 2 ether, "El precio requerido para nivel 3 no es correcto");
        
        // Le damos fondos al usuario para probar el nuevo precio
        vm.deal(newUser, 2 ether);
        
        // El usuario mintea el nivel 3 con el precio completo
        vm.prank(newUser);
        achievementsContract.mintAchievement{value: 2 ether}(newUser, "Bitcoin Basics", 3, "ipfs://level3");
        
        // Verificamos que el NFT se minteo correctamente
        assertEq(achievementsContract.ownerOf(5), newUser, "El propietario del NFT no es correcto");
    }

    /**
     * @dev Test 17: Verifica que solo el cliente del track puede actualizar precios
     */
    function test_UpdateLevelPrice_Fail_NotClient() public {
        // Intentamos actualizar el precio desde una cuenta que no es el cliente del track
        vm.expectRevert("Not authorized for this track");
        vm.prank(user1);
        achievementsContract.updateLevelPrice("Bitcoin Basics", 1, 0.05 ether);
    }
}
