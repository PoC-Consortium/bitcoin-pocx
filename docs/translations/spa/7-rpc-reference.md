[← Anterior: Parámetros de red](6-network-parameters.md) | [Tabla de contenidos](index.md) | [Siguiente: Guía de cartera →](8-wallet-guide.md)

---

# Capítulo 7: Referencia de interfaz RPC

Referencia completa para los comandos RPC de Bitcoin-PoCX, incluyendo RPCs de minería, gestión de asignaciones y RPCs de blockchain modificados.

---

## Tabla de contenidos

1. [Configuración](#configuración)
2. [RPCs de minería PoCX](#rpcs-de-minería-pocx)
3. [RPCs de asignación](#rpcs-de-asignación)
4. [RPCs de blockchain modificados](#rpcs-de-blockchain-modificados)
5. [RPCs deshabilitados](#rpcs-deshabilitados)
6. [Ejemplos de integración](#ejemplos-de-integración)

---

## Configuración

### Modo servidor de minería

**Bandera**: `-miningserver`

**Propósito**: Habilita el acceso RPC para que los mineros externos llamen a los RPCs específicos de minería

**Requisitos**:
- Requerido para que funcione `submit_nonce`
- Requerido para la visibilidad del diálogo de asignación de forjado en la cartera Qt

**Uso**:
```bash
# Línea de comandos
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**Consideraciones de seguridad**:
- Sin autenticación adicional más allá de las credenciales RPC estándar
- Los RPCs de minería están limitados por la capacidad de la cola
- Aún se requiere la autenticación RPC estándar

**Implementación**: `src/pocx/rpc/mining.cpp`

---

## RPCs de minería PoCX

### get_mining_info

**Categoría**: minería
**Requiere servidor de minería**: No
**Requiere cartera**: No

**Propósito**: Devuelve los parámetros de minería actuales necesarios para que los mineros externos escaneen archivos de parcela y calculen plazos.

**Parámetros**: Ninguno

**Valores de retorno**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 caracteres
  "base_target": 36650387593,                // numérico
  "height": 12345,                           // numérico, altura del próximo bloque
  "block_hash": "def456...",                 // hex, bloque anterior
  "target_quality": 18446744073709551615,    // uint64_max (todas las soluciones aceptadas)
  "minimum_compression_level": 1,            // numérico
  "target_compression_level": 2              // numérico
}
```

**Descripción de campos**:
- `generation_signature`: Entropía de minería determinista para esta altura de bloque
- `base_target`: Dificultad actual (mayor = más fácil)
- `height`: Altura de bloque que los mineros deben apuntar
- `block_hash`: Hash del bloque anterior (informativo)
- `target_quality`: Umbral de calidad (actualmente uint64_max, sin filtrado)
- `minimum_compression_level`: Compresión mínima requerida para validación
- `target_compression_level`: Compresión recomendada para minería óptima

**Códigos de error**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Nodo aún sincronizando

**Ejemplo**:
```bash
bitcoin-cli get_mining_info
```

**Implementación**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Categoría**: minería
**Requiere servidor de minería**: Sí
**Requiere cartera**: Sí (para claves privadas)

**Propósito**: Enviar una solución de minería PoCX. Valida la prueba, la pone en cola para forjado con flexión temporal y crea automáticamente el bloque en el tiempo programado.

**Parámetros**:
1. `height` (numérico, requerido) - Altura de bloque
2. `generation_signature` (cadena hex, requerido) - Firma de generación (64 caracteres)
3. `account_id` (cadena, requerido) - ID de cuenta de parcela (40 caracteres hex = 20 bytes)
4. `seed` (cadena, requerido) - Semilla de parcela (64 caracteres hex = 32 bytes)
5. `nonce` (numérico, requerido) - Nonce de minería
6. `compression` (numérico, requerido) - Nivel de escalado/compresión usado (1-255)
7. `quality` (numérico, opcional) - Valor de calidad (recalculado si se omite)

**Valores de retorno** (éxito):
```json
{
  "accepted": true,
  "quality": 120,           // plazo ajustado por dificultad en segundos
  "poc_time": 45            // tiempo de forjado con flexión temporal en segundos
}
```

**Valores de retorno** (rechazado):
```json
{
  "accepted": false,
  "error": "Desajuste de firma de generación"
}
```

**Pasos de validación**:
1. **Validación de formato** (fallo rápido):
   - ID de cuenta: exactamente 40 caracteres hex
   - Semilla: exactamente 64 caracteres hex
2. **Validación de contexto**:
   - La altura debe coincidir con la punta actual + 1
   - La firma de generación debe coincidir con la actual
3. **Verificación de cartera**:
   - Determinar firmante efectivo (verificar asignaciones activas)
   - Verificar que la cartera tiene clave privada para el firmante efectivo
4. **Validación de prueba** (costosa):
   - Validar prueba PoCX con límites de compresión
   - Calcular calidad cruda
5. **Envío al programador**:
   - Poner nonce en cola para forjado con flexión temporal
   - El bloque se creará automáticamente en forge_time

**Códigos de error**:
- `RPC_INVALID_PARAMETER`: Formato inválido (account_id, seed) o desajuste de altura
- `RPC_VERIFY_REJECTED`: Desajuste de firma de generación o validación de prueba fallida
- `RPC_INVALID_ADDRESS_OR_KEY`: Sin clave privada para el firmante efectivo
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Cola de envío llena
- `RPC_INTERNAL_ERROR`: Falló al inicializar el programador PoCX

**Códigos de error de validación de prueba**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Ejemplo**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "semilla_parcela_64_caracteres_hex..." \
  999888777 \
  1
```

**Notas**:
- El envío es asincrónico - RPC retorna inmediatamente, el bloque se forja después
- La flexión temporal retrasa las buenas soluciones para permitir escaneo de parcelas en toda la red
- Sistema de asignación: si la parcela está asignada, la cartera debe tener la clave de la dirección de forjado
- Los límites de compresión se ajustan dinámicamente según la altura del bloque

**Implementación**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## RPCs de asignación

### get_assignment

**Categoría**: minería
**Requiere servidor de minería**: No
**Requiere cartera**: No

**Propósito**: Consultar el estado de asignación de forjado para una dirección de parcela. Solo lectura, no requiere cartera.

**Parámetros**:
1. `plot_address` (cadena, requerido) - Dirección de parcela (formato bech32 P2WPKH)
2. `height` (numérico, opcional) - Altura de bloque a consultar (predeterminado: punta actual)

**Valores de retorno** (sin asignación):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Valores de retorno** (asignación activa):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030
}
```

**Valores de retorno** (revocando):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "REVOKING",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030,
  "revoked": true,
  "revocation_txid": "def456...",
  "revocation_height": 12300,
  "revocation_effective_height": 13020
}
```

**Estados de asignación**:
- `UNASSIGNED`: No existe asignación
- `ASSIGNING`: Tx de asignación confirmada, retardo de activación en progreso
- `ASSIGNED`: Asignación activa, derechos de forjado delegados
- `REVOKING`: Tx de revocación confirmada, aún activa hasta que expire el retardo
- `REVOKED`: Revocación completa, derechos de forjado devueltos al propietario de parcela

**Códigos de error**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Dirección inválida o no es P2WPKH (bech32)

**Ejemplo**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implementación**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Categoría**: cartera
**Requiere servidor de minería**: No
**Requiere cartera**: Sí (debe estar cargada y desbloqueada)

**Propósito**: Crear transacción de asignación de forjado para delegar derechos de forjado a otra dirección (por ejemplo, pool de minería).

**Parámetros**:
1. `plot_address` (cadena, requerido) - Dirección del propietario de parcela (debe poseer clave privada, P2WPKH bech32)
2. `forging_address` (cadena, requerido) - Dirección a la que asignar derechos de forjado (P2WPKH bech32)
3. `fee_rate` (numérico, opcional) - Tasa de comisión en BTC/kvB (predeterminado: 10× minRelayFee)

**Valores de retorno**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Requisitos**:
- Cartera cargada y desbloqueada
- Clave privada para plot_address en la cartera
- Ambas direcciones deben ser P2WPKH (formato bech32: pocx1q... mainnet, tpocx1q... testnet)
- La dirección de parcela debe tener UTXOs confirmados (demuestra propiedad)
- La parcela no debe tener asignación activa (use revoke primero)

**Estructura de transacción**:
- Entrada: UTXO de la dirección de parcela (demuestra propiedad)
- Salida: OP_RETURN (46 bytes): marcador `POCX` + plot_address (20 bytes) + forging_address (20 bytes)
- Salida: Cambio devuelto a la cartera

**Activación**:
- La asignación se convierte en ASSIGNING en la confirmación
- Se convierte en ACTIVE después de `nForgingAssignmentDelay` bloques
- El retardo previene reasignación rápida durante bifurcaciones de cadena

**Códigos de error**:
- `RPC_WALLET_NOT_FOUND`: No hay cartera disponible
- `RPC_WALLET_UNLOCK_NEEDED`: Cartera encriptada y bloqueada
- `RPC_WALLET_ERROR`: Creación de transacción fallida
- `RPC_INVALID_ADDRESS_OR_KEY`: Formato de dirección inválido

**Ejemplo**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implementación**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Categoría**: cartera
**Requiere servidor de minería**: No
**Requiere cartera**: Sí (debe estar cargada y desbloqueada)

**Propósito**: Revocar asignación de forjado existente, devolviendo los derechos de forjado al propietario de parcela.

**Parámetros**:
1. `plot_address` (cadena, requerido) - Dirección de parcela (debe poseer clave privada, P2WPKH bech32)
2. `fee_rate` (numérico, opcional) - Tasa de comisión en BTC/kvB (predeterminado: 10× minRelayFee)

**Valores de retorno**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Requisitos**:
- Cartera cargada y desbloqueada
- Clave privada para plot_address en la cartera
- La dirección de parcela debe ser P2WPKH (formato bech32)
- La dirección de parcela debe tener UTXOs confirmados

**Estructura de transacción**:
- Entrada: UTXO de la dirección de parcela (demuestra propiedad)
- Salida: OP_RETURN (26 bytes): marcador `XCOP` + plot_address (20 bytes)
- Salida: Cambio devuelto a la cartera

**Efecto**:
- El estado transiciona a REVOKING inmediatamente
- La dirección de forjado aún puede forjar durante el período de retardo
- Se convierte en REVOKED después de `nForgingRevocationDelay` bloques
- El propietario de parcela puede forjar después de que la revocación sea efectiva
- Puede crear nueva asignación después de que la revocación se complete

**Códigos de error**:
- `RPC_WALLET_NOT_FOUND`: No hay cartera disponible
- `RPC_WALLET_UNLOCK_NEEDED`: Cartera encriptada y bloqueada
- `RPC_WALLET_ERROR`: Creación de transacción fallida

**Ejemplo**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Notas**:
- Idempotente: puede revocar incluso si no hay asignación activa
- No puede cancelar la revocación una vez enviada

**Implementación**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## RPCs de blockchain modificados

### getdifficulty

**Modificaciones PoCX**:
- **Cálculo**: `objetivo_base_referencia / objetivo_base_actual`
- **Referencia**: Capacidad de red de 1 TiB (base_target = 36650387593)
- **Interpretación**: Capacidad de almacenamiento estimada de la red en TiB
  - Ejemplo: `1.0` = ~1 TiB
  - Ejemplo: `1024.0` = ~1 PiB
- **Diferencia con PoW**: Representa capacidad, no poder de hash

**Ejemplo**:
```bash
bitcoin-cli getdifficulty
# Retorna: 2048.5 (red ~2 PiB)
```

**Implementación**: `src/rpc/blockchain.cpp`

---

### getblockheader

**Campos añadidos por PoCX**:
- `time_since_last_block` (numérico) - Segundos desde el bloque anterior (reemplaza mediantime)
- `poc_time` (numérico) - Tiempo de forjado con flexión temporal en segundos
- `base_target` (numérico) - Objetivo base de dificultad PoCX
- `generation_signature` (cadena hex) - Firma de generación
- `pocx_proof` (objeto):
  - `account_id` (cadena hex) - ID de cuenta de parcela (20 bytes)
  - `seed` (cadena hex) - Semilla de parcela (32 bytes)
  - `nonce` (numérico) - Nonce de minería
  - `compression` (numérico) - Nivel de escalado usado
  - `quality` (numérico) - Valor de calidad declarado
- `pubkey` (cadena hex) - Clave pública del firmante del bloque (33 bytes)
- `signer_address` (cadena) - Dirección del firmante del bloque
- `signature` (cadena hex) - Firma del bloque (65 bytes)

**Campos eliminados por PoCX**:
- `mediantime` - Eliminado (reemplazado por time_since_last_block)

**Ejemplo**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Implementación**: `src/rpc/blockchain.cpp`

---

### getblock

**Modificaciones PoCX**: Igual que getblockheader, más datos completos de transacción

**Ejemplo**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verboso con detalles de tx
```

**Implementación**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**Campos añadidos por PoCX**:
- `base_target` (numérico) - Objetivo base actual
- `generation_signature` (cadena hex) - Firma de generación actual

**Campos modificados por PoCX**:
- `difficulty` - Usa cálculo PoCX (basado en capacidad)

**Campos eliminados por PoCX**:
- `mediantime` - Eliminado

**Ejemplo**:
```bash
bitcoin-cli getblockchaininfo
```

**Implementación**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**Campos añadidos por PoCX**:
- `generation_signature` (cadena hex) - Para minería en pool
- `base_target` (numérico) - Para minería en pool

**Campos eliminados por PoCX**:
- `target` - Eliminado (específico de PoW)
- `noncerange` - Eliminado (específico de PoW)
- `bits` - Eliminado (específico de PoW)

**Notas**:
- Aún incluye datos completos de transacción para construcción de bloques
- Usado por servidores de pool para minería coordinada

**Ejemplo**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implementación**: `src/rpc/mining.cpp`

---

## RPCs deshabilitados

Los siguientes RPCs específicos de PoW están **deshabilitados** en modo PoCX:

### getnetworkhashps
- **Razón**: Tasa de hash no aplicable a Prueba de Capacidad
- **Alternativa**: Use `getdifficulty` para estimación de capacidad de red

### getmininginfo
- **Razón**: Devuelve información específica de PoW
- **Alternativa**: Use `get_mining_info` (específico de PoCX)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Razón**: Minería con CPU no aplicable a PoCX (requiere parcelas pregeneradas)
- **Alternativa**: Use graficador externo + minero + `submit_nonce`

**Implementación**: `src/rpc/mining.cpp` (RPCs devuelven error cuando ENABLE_POCX está definido)

---

## Ejemplos de integración

### Integración de minero externo

**Bucle básico de minería**:
```python
import requests
import time

RPC_URL = "http://usuario:contraseña@localhost:8332"

def rpc_call(method, params=[]):
    payload = {
        "jsonrpc": "2.0",
        "id": "minero",
        "method": method,
        "params": params
    }
    response = requests.post(RPC_URL, json=payload)
    return response.json()["result"]

# Bucle de minería
while True:
    # 1. Obtener parámetros de minería
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Escanear archivos de parcela (implementación externa)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Enviar mejor solución
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"¡Solución aceptada! Calidad: {result['quality']}s, "
              f"Tiempo de forjado: {result['poc_time']}s")

    # 4. Esperar siguiente bloque
    time.sleep(10)  # Intervalo de sondeo
```

---

### Patrón de integración de pool

**Flujo de trabajo del servidor de pool**:
1. Los mineros crean asignaciones de forjado a la dirección del pool
2. El pool ejecuta cartera con claves de dirección de forjado
3. El pool llama a `get_mining_info` y distribuye a los mineros
4. Los mineros envían soluciones a través del pool (no directamente a la cadena)
5. El pool valida y llama a `submit_nonce` con las claves del pool
6. El pool distribuye recompensas según la política del pool

**Gestión de asignaciones**:
```bash
# El minero crea asignación (desde la cartera del minero)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Esperar activación (30 bloques en mainnet)

# El pool verifica estado de asignación
bitcoin-cli get_assignment "pocx1qminer_plot..."

# El pool ahora puede enviar nonces para esta parcela
# (la cartera del pool debe tener la clave privada de pocx1qpool...)
```

---

### Consultas de explorador de bloques

**Consultando datos de bloque PoCX**:
```bash
# Obtener último bloque
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Obtener detalles del bloque con prueba PoCX
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Extraer campos específicos de PoCX
echo $BLOCK | jq '{
  height: .height,
  time_since_last: .time_since_last_block,
  poc_time: .poc_time,
  base_target: .base_target,
  generation_signature: .generation_signature,
  pocx_proof: .pocx_proof,
  miner_address: .tx[0].vout[0].scriptPubKey.address
}'
```

**Detectando transacciones de asignación**:
```bash
# Escanear transacción por OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Verificar marcador de asignación (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Manejo de errores

### Patrones de error comunes

**Desajuste de altura**:
```json
{
  "accepted": false,
  "error": "Desajuste de altura: enviada 12345, actual 12346"
}
```
**Solución**: Volver a obtener info de minería, la cadena avanzó

**Desajuste de firma de generación**:
```json
{
  "accepted": false,
  "error": "Desajuste de firma de generación"
}
```
**Solución**: Volver a obtener info de minería, llegó nuevo bloque

**Sin clave privada**:
```json
{
  "code": -5,
  "message": "No hay clave privada disponible para el firmante efectivo"
}
```
**Solución**: Importar clave para la dirección de parcela o forjado

**Activación de asignación pendiente**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Solución**: Esperar a que expire el retardo de activación

---

## Referencias de código

**RPCs de minería**: `src/pocx/rpc/mining.cpp`
**RPCs de asignación**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**RPCs de blockchain**: `src/rpc/blockchain.cpp`
**Validación de prueba**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**Estado de asignación**: `src/pocx/assignments/assignment_state.cpp`
**Creación de transacción**: `src/pocx/assignments/transactions.cpp`

---

## Referencias cruzadas

Capítulos relacionados:
- [Capítulo 3: Consenso y minería](3-consensus-and-mining.md) - Detalles del proceso de minería
- [Capítulo 4: Asignaciones de forjado](4-forging-assignments.md) - Arquitectura del sistema de asignación
- [Capítulo 6: Parámetros de red](6-network-parameters.md) - Valores de retardo de asignación
- [Capítulo 8: Guía de cartera](8-wallet-guide.md) - GUI para gestión de asignaciones

---

[← Anterior: Parámetros de red](6-network-parameters.md) | [Tabla de contenidos](index.md) | [Siguiente: Guía de cartera →](8-wallet-guide.md)
