🎯 ESCENARIOS DE TEST PARA CERTIFICADOS NFT
👤 ESCENARIOS DE USUARIO
Escenario 1: Usuario Nuevo

Usuario completa su primera campaña
Recibe su primer certificado NFT
El certificado contiene metadatos de la campaña específica
Escenario 2: Usuario Veterano

Usuario ya tiene 3 certificados de campañas anteriores
Completa nueva campaña diferente
Obtiene certificado adicional sin conflictos
Escenario 3: Usuario Repetidor

Usuario intenta completar la misma campaña dos veces
Sistema debe rechazar el segundo minteo
Mantener integridad de "un certificado por campaña por usuario"
🏢 ESCENARIOS DE CAMPAÑAS
Escenario 4: Campaña Popular

1000+ usuarios completan la misma campaña
Todos reciben certificados únicos
Supply de la campaña se trackea correctamente
Escenario 5: Múltiples Campañas Activas

5 campañas diferentes ejecutándose simultáneamente
Usuarios participan en varias a la vez
Certificados se asignan a campañas correctas
Escenario 6: Campaña con Prerequisitos

Campaña "Avanzada" requiere certificado de campaña "Básica"
Usuario sin certificado básico no puede acceder
Usuario con certificado básico puede acceder
🔐 ESCENARIOS DE ACCESO NFT-GATED
Escenario 7: Acceso Denegado

Usuario intenta acceder a campaña premium
No posee el NFT requerido
Sistema bloquea acceso y muestra requisitos
Escenario 8: Acceso Concedido

Usuario posee certificado NFT requerido
Accede exitosamente a campaña premium
Puede completar actividades normalmente
Escenario 9: Verificación Cross-Campaign

Campaña "Marketing Avanzado" requiere certificado de "Ventas Básico"
Usuario con certificado correcto accede
Usuario con certificado incorrecto es rechazado
⚡ ESCENARIOS DE EDGE CASES
Escenario 10: Transfer de NFT

Usuario A completa campaña y recibe certificado
Usuario A transfiere NFT a Usuario B
Usuario B ahora puede acceder a campañas premium
Usuario A pierde acceso
Escenario 11: Wallet Comprometida

Usuario cambia de wallet por seguridad
Pierde acceso a campañas premium temporalmente
Admin puede re-mintear certificados en nueva wallet
Escenario 12: Campaña Discontinuada

Campaña se marca como inactiva
Usuarios existentes mantienen sus certificados
Nuevos usuarios no pueden obtener certificados
🔧 ESCENARIOS ADMINISTRATIVOS
Escenario 13: Minteo Masivo

Admin necesita mintear certificados para 500 usuarios
Batch minting para evento corporativo
Todos los certificados se asignan correctamente
Escenario 14: Corrección de Errores

Usuario reporta certificado incorrecto
Admin puede verificar y corregir
Historial de cambios se mantiene
Escenario 15: Migración de Datos

Importar certificados de sistema legacy
Mantener integridad de prerequisitos
Usuarios no pierden progreso
🌐 ESCENARIOS DE INTEGRACIÓN
Escenario 16: Múltiples Blockchains

Certificados en Ethereum y Polygon
Verificación cross-chain para prerequisitos
Usuario puede usar certificados de cualquier red
Escenario 17: Marketplace Integration

Certificados aparecen en OpenSea
Metadatos se renderizan correctamente
Usuarios pueden comercializar certificados
Escenario 18: Wallet Disconnection

Usuario desconecta wallet durante verificación
Sistema maneja gracefully
Re-conexión restaura estado
📊 ESCENARIOS DE PERFORMANCE
Escenario 19: Alto Volumen

10,000 usuarios intentan mintear simultáneamente
Gas fees se mantienen razonables
No hay fallos de red
Escenario 20: Consultas Masivas

Sistema verifica prerequisitos para 1000 usuarios
Respuesta en tiempo razonable
Cache optimiza consultas repetidas