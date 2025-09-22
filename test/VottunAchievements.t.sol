// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/vottun_smart_contract.sol";

contract VottunAchievementsTest is Test {
    // Instancia del contrato que vamos a probar
    VottunAchievements public achievementsContract;

    // Direcciones para simular los diferentes roles
    address public owner = address(0x1);
    address public client = address(0x2);
    address public user1 = address(0x3);

    /**
     * @dev Se ejecuta antes de cada test. Despliega el contrato y prepara el entorno.
     */
    function setUp() public {
        // Hacemos "prank" para simular que el 'owner' es quien despliega el contrato
        vm.prank(owner);
        achievementsContract = new VottunAchievements();

        // --- Preparamos el entorno para los tests de minting ---

        // 1. El Owner crea un track para el 'client'
        vm.prank(owner);
        achievementsContract.createTrack("Bitcoin Basics", client, 0, 1 ether); // 0 free mints para simplificar el test

        // 2. El 'client' añade dos niveles al track
        vm.prank(client);
        achievementsContract.addLevelToTrack("Bitcoin Basics", 1, 0.01 ether); // Nivel 1 tiene un precio para consumir el free mint
        vm.prank(client);
        achievementsContract.addLevelToTrack("Bitcoin Basics", 2, 1 ether); // Nivel 2 cuesta 1 ETH

        // 3. El 'owner' registra al 'user1'
        vm.prank(owner);
        achievementsContract.linkUserAddress(user1, "test-user-id");
    }

    // ===================================
    //           TEST CASES
    // ===================================

    /**
     * @dev Test 1: Verifica que un track se puede crear correctamente.
     */
    function test_CreateTrack_Success() public {
        // Simulamos que la llamada la hace el 'owner'
        vm.prank(owner);

        // Llamamos a la función para crear un track con un nombre DIFERENTE al de setUp
        achievementsContract.createTrack(
            "Ethereum Basics", // trackName
            client,           // client address
            5,                // freeMintsPerUser
            1 ether           // basePriceAfterFree
        );

        // Verificamos que los datos del track se hayan guardado correctamente
        (, address trackClient, , bool active, uint256 freeMints, ) = achievementsContract.tracks("Ethereum Basics");

        assertEq(trackClient, client, "El cliente del track no es correcto");
        assertEq(freeMints, 5, "Los mints gratuitos no son correctos");
        assertTrue(active, "El track deberia estar activo");
    }

     /**
     * @dev Test 2: Verifica que solo el owner pueda crear un track.
     */
    function test_CreateTrack_Fail_NotOwner() public {
        // Esperamos que la siguiente llamada falle con un error específico de Ownable
        // El error es `OwnableUnauthorizedAccount(address sender)`
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, client));

        // Simulamos que la llamada la hace el 'client' (que no es el owner)
        vm.prank(client);
        achievementsContract.createTrack(
            "Ethereum Basics",
            client,
            5,
            1 ether
        );
    }

    /**
     * @dev Test 3: Verifica que un usuario puede mintear el primer nivel (pagando).
     */
    function test_MintAchievement_Success() public {
        // Le damos fondos al usuario para pagar el nivel 1
        vm.deal(user1, 0.01 ether);

        // El usuario mintea el nivel 1, pagando 0.01 ether
        vm.prank(user1);
        achievementsContract.mintAchievement{value: 0.01 ether}(user1, "Bitcoin Basics", 1, "ipfs://level1");

        // Verificamos que el NFT pertenece al usuario y su progreso se ha actualizado
        assertEq(achievementsContract.ownerOf(1), user1, "El propietario del NFT no es correcto");
        assertEq(achievementsContract.getTrackProgress(user1, "Bitcoin Basics"), 1, "El progreso del usuario no se actualizo");
    }

    /**
     * @dev Test 4: Verifica que un usuario no puede mintear el nivel 2 sin tener el nivel 1.
     */
    function test_MintAchievement_Fail_CannotSkipLevel() public {
        vm.expectRevert("Cannot access this level");
        vm.prank(user1);
        achievementsContract.mintAchievement(user1, "Bitcoin Basics", 2, "ipfs://level2");
    }

    /**
     * @dev Test 5: Verifica que un usuario puede mintear un nivel de pago.
     */
    function test_MintAchievement_Success_Paid() public {
        // Le damos al usuario fondos para pagar ambos niveles
        vm.deal(user1, 2 ether);

        // Primero, el usuario mintea el nivel 1 pagando 0.01 ether
        vm.prank(user1);
        achievementsContract.mintAchievement{value: 0.01 ether}(user1, "Bitcoin Basics", 1, "ipfs://level1");

        // El usuario mintea el nivel 2, pagando 1 ether
        vm.prank(user1);
        achievementsContract.mintAchievement{value: 1 ether}(user1, "Bitcoin Basics", 2, "ipfs://level2");

        assertEq(achievementsContract.ownerOf(2), user1, "El propietario del NFT #2 no es correcto");
        assertEq(achievementsContract.getTrackProgress(user1, "Bitcoin Basics"), 2, "El progreso del usuario no se actualizo al nivel 2");
    }

    /**
     * @dev Test 6: Verifica que la transacción falla si el pago es insuficiente.
     */
    function test_MintAchievement_Fail_InsufficientPayment() public {
        // Le damos fondos al usuario para pagar el nivel 1
        vm.deal(user1, 1 ether);

        // El usuario completa el nivel 1 pagando 0.01 ether
        vm.prank(user1);
        achievementsContract.mintAchievement{value: 0.01 ether}(user1, "Bitcoin Basics", 1, "ipfs://level1");

        // El usuario intenta mintear el nivel 2 con menos ETH del necesario
        vm.expectRevert("Insufficient payment");
        vm.prank(user1);
        achievementsContract.mintAchievement{value: 0.5 ether}(user1, "Bitcoin Basics", 2, "ipfs://level2");
    }

    /**
     * @dev Test 7: Verifica que un cliente puede retirar sus ganancias.
     */
    function test_WithdrawClientRevenue_Success() public {
        // Le damos fondos al usuario para pagar ambos niveles
        vm.deal(user1, 2 ether);

        // 1. El usuario mintea el Nivel 1 (cuesta 0.01 ether)
        vm.prank(user1);
        achievementsContract.mintAchievement{value: 0.01 ether}(user1, "Bitcoin Basics", 1, "ipfs://level1");

        // 2. El usuario mintea el Nivel 2 (cuesta 1 ether)
        vm.prank(user1);
        achievementsContract.mintAchievement{value: 1 ether}(user1, "Bitcoin Basics", 2, "ipfs://level2");

        // Calculamos las ganancias totales esperadas para el cliente
        uint256 totalPaid = 1.01 ether;
        uint256 platformFee = (totalPaid * achievementsContract.platformFeePercentage()) / 10000;
        uint256 expectedRevenue = totalPaid - platformFee;
        assertEq(achievementsContract.clientRevenue(client), expectedRevenue, "Las ganancias del cliente no se registraron correctamente");

        // El cliente retira sus ganancias
        uint256 balanceBefore = client.balance;
        vm.prank(client);
        achievementsContract.withdrawClientRevenue();

        // Verificamos que el saldo del cliente ha aumentado y las ganancias en el contrato son cero
        assertEq(client.balance, balanceBefore + expectedRevenue, "El saldo del cliente no aumento correctamente");
        assertEq(achievementsContract.clientRevenue(client), 0, "Las ganancias del cliente en el contrato no se resetearon a cero");
    }
}
