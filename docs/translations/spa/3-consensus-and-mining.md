[← Anterior: Formato de parcelas](2-plot-format.md) | [Tabla de contenidos](index.md) | [Siguiente: Asignaciones de forjado →](4-forging-assignments.md)

---

# Capítulo 3: Proceso de consenso y minería de Bitcoin-PoCX

Especificación técnica completa del mecanismo de consenso y proceso de minería PoCX (Prueba de Capacidad de Nueva Generación) integrado en Bitcoin Core.

---

## Tabla de contenidos

1. [Panorama general](#panorama-general)
2. [Arquitectura de consenso](#arquitectura-de-consenso)
3. [Proceso de minería](#proceso-de-minería)
4. [Validación de bloques](#validación-de-bloques)
5. [Sistema de asignaciones](#sistema-de-asignaciones)
6. [Propagación en la red](#propagación-en-la-red)
7. [Detalles técnicos](#detalles-técnicos)

---

## Panorama general

Bitcoin-PoCX implementa un mecanismo de consenso de Prueba de Capacidad puro como reemplazo completo de la Prueba de Trabajo de Bitcoin. Esta es una nueva cadena sin requisitos de compatibilidad retroactiva.

**Propiedades clave:**
- **Eficiente energéticamente:** La minería usa archivos de parcela pregenerados en lugar de hashing computacional
- **Plazos con flexión temporal:** Transformación de distribución (exponencial→chi-cuadrado) reduce bloques largos, mejora tiempos promedio de bloque
- **Soporte de asignaciones:** Los propietarios de parcelas pueden delegar derechos de forjado a otras direcciones
- **Integración nativa en C++:** Algoritmos criptográficos implementados en C++ para validación de consenso

**Flujo de minería:**
```
Minero externo → get_mining_info → Calcular nonce → submit_nonce →
Cola de forjado → Espera de plazo → Forjado de bloque → Propagación en red →
Validación de bloque → Extensión de cadena
```

---

## Arquitectura de consenso

### Estructura de bloque

Los bloques PoCX extienden la estructura de bloque de Bitcoin con campos de consenso adicionales:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Semilla de parcela (32 bytes)
    std::array<uint8_t, 20> account_id;       // Dirección de parcela (hash160 de 20 bytes)
    uint32_t compression;                     // Nivel de escalado (1-255)
    uint64_t nonce;                           // Nonce de minería (64 bits)
    uint64_t quality;                         // Calidad declarada (salida de hash PoC)
};

class CBlockHeader {
    // Campos estándar de Bitcoin
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // Campos de consenso PoCX (reemplazan nBits y nNonce)
    int nHeight;                              // Altura de bloque (validación sin contexto)
    uint256 generationSignature;              // Firma de generación (entropía de minería)
    uint64_t nBaseTarget;                     // Parámetro de dificultad (dificultad inversa)
    PoCXProof pocxProof;                      // Prueba de minería

    // Campos de firma de bloque
    std::array<uint8_t, 33> vchPubKey;        // Clave pública comprimida (33 bytes)
    std::array<uint8_t, 65> vchSignature;     // Firma compacta (65 bytes)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Transacciones
};
```

**Nota:** La firma (`vchSignature`) se excluye del cálculo del hash del bloque para prevenir maleabilidad.

**Implementación:** `src/primitives/block.h`

### Firma de generación

La firma de generación crea entropía de minería y previene ataques de precomputación.

**Cálculo:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**Bloque génesis:** Usa una firma de generación inicial codificada

**Implementación:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Objetivo base (dificultad)

El objetivo base es el inverso de la dificultad - valores más altos significan minería más fácil.

**Algoritmo de ajuste:**
- Objetivo de tiempo de bloque: 120 segundos (mainnet), 1 segundo (regtest)
- Intervalo de ajuste: Cada bloque
- Usa promedio móvil de objetivos base recientes
- Limitado para prevenir oscilaciones extremas de dificultad

**Implementación:** `src/consensus/params.h`, lógica de dificultad en creación de bloques

### Niveles de escalado

PoCX soporta prueba de trabajo escalable en archivos de parcela a través de niveles de escalado (Xn).

**Límites dinámicos:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Nivel mínimo aceptado
    uint8_t nPoCXTargetCompression;  // Nivel recomendado
};
```

**Programa de incremento de escalado:**
- Intervalos exponenciales: Años 4, 12, 28, 60, 124 (halvings 1, 3, 7, 15, 31)
- El nivel mínimo de escalado aumenta en 1
- El nivel objetivo de escalado aumenta en 1
- Mantiene margen de seguridad entre costos de creación y consulta de parcelas
- Nivel máximo de escalado: 255

**Implementación:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Proceso de minería

### 1. Obtención de información de minería

**Comando RPC:** `get_mining_info`

**Proceso:**
1. Llamar a `GetNewBlockContext(chainman)` para obtener el estado actual de la blockchain
2. Calcular límites de compresión dinámicos para la altura actual
3. Devolver parámetros de minería

**Respuesta:**
```json
{
  "generation_signature": "abc123...",
  "base_target": 18325193796,
  "height": 12345,
  "block_hash": "def456...",
  "target_quality": 18446744073709551615,
  "minimum_compression_level": 0,
  "target_compression_level": 0
}
```

**Implementación:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Notas:**
- No se mantienen bloqueos durante la generación de respuesta
- La adquisición de contexto maneja `cs_main` internamente
- `block_hash` incluido como referencia pero no usado en validación

### 2. Minería externa

**Responsabilidades del minero externo:**
1. Leer archivos de parcela del disco
2. Calcular scoop basado en firma de generación y altura
3. Encontrar nonce con mejor plazo
4. Enviar al nodo vía `submit_nonce`

**Formato de archivo de parcela:**
- Basado en formato POC2 (Burstcoin)
- Mejorado con correcciones de seguridad y mejoras de escalabilidad
- Ver atribución en `CLAUDE.md`

**Implementación del minero:** Externa (por ejemplo, basada en Scavenger)

### 3. Envío y validación de nonce

**Comando RPC:** `submit_nonce`

**Parámetros:**
```
height, generation_signature, account_id, seed, nonce, quality (opcional)
```

**Flujo de validación (orden optimizado):**

#### Paso 1: Validación rápida de formato
```cpp
// ID de cuenta: 40 caracteres hex = 20 bytes
if (account_id.length() != 40 || !IsHex(account_id)) rechazar;

// Semilla: 64 caracteres hex = 32 bytes
if (seed.length() != 64 || !IsHex(seed)) rechazar;
```

#### Paso 2: Adquisición de contexto
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Devuelve: height, generation_signature, base_target, block_hash
```

**Bloqueo:** `cs_main` manejado internamente, sin bloqueos en el hilo RPC

#### Paso 3: Validación de contexto
```cpp
// Verificación de altura
if (height != context.height) rechazar;

// Verificación de firma de generación
if (submitted_gen_sig != context.generation_signature) rechazar;
```

#### Paso 4: Verificación de cartera
```cpp
// Determinar firmante efectivo (considerando asignaciones)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Verificar si el nodo tiene clave privada para el firmante efectivo
if (!HaveAccountKey(effective_signer, wallet)) rechazar;
```

**Soporte de asignaciones:** El propietario de la parcela puede asignar derechos de forjado a otra dirección. La cartera debe tener la clave del firmante efectivo, no necesariamente del propietario de la parcela.

#### Paso 5: Validación de prueba
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 bytes
    block_height,
    nonce,
    seed,                // 32 bytes
    min_compression,
    max_compression,
    &result             // Salida: quality, deadline
);
```

**Algoritmo:**
1. Decodificar firma de generación desde hex
2. Calcular mejor calidad en rango de compresión usando algoritmos optimizados con SIMD
3. Validar que la calidad cumple los requisitos de dificultad
4. Devolver valor de calidad crudo

**Implementación:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Paso 6: Cálculo de flexión temporal
```cpp
// Plazo crudo ajustado por dificultad (segundos)
uint64_t deadline_seconds = quality / base_target;

// Tiempo de forjado con flexión temporal (segundos)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Fórmula de flexión temporal:**
```
Y = escala * (X^(1/3))
donde:
  X = quality / base_target
  escala = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Propósito:** Transforma distribución exponencial a chi-cuadrado. Las soluciones muy buenas se forjan más tarde (la red tiene tiempo de escanear discos), las soluciones pobres mejoran. Reduce bloques largos, mantiene promedio de 120s.

**Implementación:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Paso 7: Envío al forjador
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // NO deadline - recalculado en forjador
    height,
    generation_signature
);
```

**Diseño basado en cola:**
- El envío siempre tiene éxito (añadido a la cola)
- RPC retorna inmediatamente
- Hilo trabajador procesa asincrónicamente

**Implementación:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Procesamiento de la cola de forjado

**Arquitectura:**
- Hilo trabajador persistente único
- Cola de envío FIFO
- Estado de forjado sin bloqueo (solo hilo trabajador)
- Sin bloqueos anidados (prevención de interbloqueo)

**Bucle principal del hilo trabajador:**
```cpp
while (!shutdown) {
    // 1. Verificar envíos en cola
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Esperar plazo o nuevo envío
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**Lógica de ProcessSubmission:**
```cpp
1. Obtener contexto fresco: GetNewBlockContext(*chainman)

2. Verificaciones de obsolescencia (descarte silencioso):
   - Desajuste de altura → descartar
   - Desajuste de firma de generación → descartar
   - Hash de bloque de punta cambió (reorg) → reiniciar estado de forjado

3. Comparación de calidad:
   - Si quality >= current_best → descartar

4. Calcular plazo con flexión temporal:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Actualizar estado de forjado:
   - Cancelar forjado existente (si se encontró mejor)
   - Almacenar: account_id, seed, nonce, quality, deadline
   - Calcular: forge_time = block_time + deadline_seconds
   - Almacenar hash de punta para detección de reorg
```

**Implementación:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Espera de plazo y forjado de bloque

**WaitForDeadlineOrNewSubmission:**

**Condiciones de espera:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Cuando se alcanza el plazo - Validación de contexto fresco:**
```cpp
1. Obtener contexto actual: GetNewBlockContext(*chainman)

2. Validación de altura:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Validación de firma de generación:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Caso límite de objetivo base:
   if (forging_base_target != current_base_target) {
       // Recalcular plazo con nuevo objetivo base
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Esperar de nuevo
   }

5. Todo válido → ForgeBlock()
```

**Proceso de ForgeBlock:**

```cpp
1. Determinar firmante efectivo (soporte de asignaciones):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Crear script de coinbase:
   coinbase_script = P2WPKH(effective_signer);  // Paga al firmante efectivo

3. Crear plantilla de bloque:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Añadir prueba PoCX:
   block.pocxProof.account_id = plot_address;    // Dirección de parcela original
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Recalcular raíz merkle:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Firmar bloque:
   // Usar clave del firmante efectivo (puede ser diferente del propietario de parcela)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Enviar a la cadena:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Manejo de resultado:
   if (accepted) {
       log_success();
       reset_forging_state();  // Listo para siguiente bloque
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implementación:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Decisiones de diseño clave:**
- Coinbase paga al firmante efectivo (respeta asignaciones)
- La prueba contiene la dirección de parcela original (para validación)
- Firma de la clave del firmante efectivo (prueba de propiedad)
- La creación de plantilla incluye transacciones del mempool automáticamente

---

## Validación de bloques

### Flujo de validación de bloques entrantes

Cuando se recibe un bloque de la red o se envía localmente, pasa por validación en múltiples etapas:

### Etapa 1: Validación de encabezado (CheckBlockHeader)

**Validación sin contexto:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**Validación PoCX (cuando ENABLE_POCX está definido):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Validación básica de firma (sin soporte de asignaciones aún)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Validación básica de firma:**
1. Verificar presencia de campos de clave pública y firma
2. Validar tamaño de clave pública (33 bytes comprimida)
3. Validar tamaño de firma (65 bytes compacta)
4. Recuperar clave pública de la firma: `pubkey.RecoverCompact(hash, signature)`
5. Verificar que la clave pública recuperada coincide con la almacenada

**Implementación:** `src/validation.cpp:CheckBlockHeader()`
**Lógica de firma:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Etapa 2: Validación de bloque (CheckBlock)

**Valida:**
- Corrección de raíz merkle
- Validez de transacciones
- Requisitos de coinbase
- Límites de tamaño de bloque
- Reglas de consenso estándar de Bitcoin

**Implementación:** `src/consensus/validation.cpp:CheckBlock()`

### Etapa 3: Validación contextual de encabezado (ContextualCheckBlockHeader)

**Validación específica de PoCX:**

```cpp
#ifdef ENABLE_POCX
    // Paso 1: Validar firma de generación
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Paso 2: Validar objetivo base
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Paso 3: Validar prueba de capacidad
    auto compression_bounds = GetPoCXCompressionBounds(block.nHeight, halving_interval);
    auto result = ValidateProofOfCapacity(
        block.generationSignature,
        block.pocxProof,
        block.nBaseTarget,
        block.nHeight,
        compression_bounds.nPoCXMinCompression,
        compression_bounds.nPoCXTargetCompression,
        block_time
    );

    if (!result.is_valid) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-proof");
    }

    // Paso 4: Verificar temporización del plazo
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Pasos de validación:**
1. **Firma de generación:** Debe coincidir con el valor calculado del bloque anterior
2. **Objetivo base:** Debe coincidir con el cálculo de ajuste de dificultad
3. **Nivel de escalado:** Debe cumplir el mínimo de la red (`compression >= min_compression`)
4. **Declaración de calidad:** La calidad enviada debe coincidir con la calidad computada de la prueba
5. **Prueba de capacidad:** Validación de prueba criptográfica (optimizada con SIMD)
6. **Temporización del plazo:** El plazo con flexión temporal (`poc_time`) debe ser ≤ tiempo transcurrido

**Implementación:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Etapa 4: Conexión de bloque (ConnectBlock)

**Validación contextual completa:**

```cpp
#ifdef ENABLE_POCX
    // Validación extendida de firma con soporte de asignaciones
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Validación extendida de firma:**
1. Realizar validación básica de firma
2. Extraer ID de cuenta de la clave pública recuperada
3. Obtener firmante efectivo para la dirección de parcela: `GetEffectiveSigner(plot_address, height, view)`
4. Verificar que la cuenta de la clave pública coincide con el firmante efectivo

**Lógica de asignación:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Devolver firmante asignado
    }

    return plotAddress;  // Sin asignación - el propietario de parcela firma
}
```

**Implementación:**
- Conexión: `src/validation.cpp:ConnectBlock()`
- Validación extendida: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Lógica de asignación: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Etapa 5: Activación de cadena

**Flujo de ProcessNewBlock:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Validar y almacenar en disco
    2. ActivateBestChain → Actualizar punta de cadena si esta es la mejor cadena
    3. Notificar a la red del nuevo bloque
}
```

**Implementación:** `src/validation.cpp:ProcessNewBlock()`

### Resumen de validación

**Ruta completa de validación:**
```
Recibir bloque
    ↓
CheckBlockHeader (firma básica)
    ↓
CheckBlock (transacciones, merkle)
    ↓
ContextualCheckBlockHeader (firma gen, objetivo base, prueba PoC, plazo)
    ↓
ConnectBlock (firma extendida con asignaciones, transiciones de estado)
    ↓
ActivateBestChain (manejo de reorg, extensión de cadena)
    ↓
Propagación en red
```

---

## Sistema de asignaciones

### Panorama general

Las asignaciones permiten a los propietarios de parcelas delegar derechos de forjado a otras direcciones mientras mantienen la propiedad de la parcela.

**Casos de uso:**
- Minería en pool (las parcelas se asignan a la dirección del pool)
- Almacenamiento en frío (clave de minería separada de la propiedad de la parcela)
- Minería multipartita (infraestructura compartida)

### Arquitectura de asignaciones

**Diseño exclusivo OP_RETURN:**
- Asignaciones almacenadas en salidas OP_RETURN (sin UTXO)
- Sin requisitos de gasto (sin polvo, sin comisiones por mantener)
- Rastreadas en estado extendido de CCoinsViewCache
- Activadas después de período de retardo (por defecto: 4 bloques)

**Estados de asignación:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // No existe asignación
    ASSIGNING = 1,   // Asignación pendiente de activación (período de retardo)
    ASSIGNED = 2,    // Asignación activa, forjado permitido
    REVOKING = 3,    // Revocación pendiente (período de retardo, aún activa)
    REVOKED = 4      // Revocación completa, asignación ya no activa
};
```

### Creación de asignaciones

**Formato de transacción:**
```cpp
Transaction {
    inputs: [cualquiera]  // Demuestra propiedad de dirección de parcela
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Reglas de validación:**
1. La entrada debe estar firmada por el propietario de la parcela (demuestra propiedad)
2. OP_RETURN contiene datos de asignación válidos
3. La parcela debe estar UNASSIGNED o REVOKED
4. Sin asignaciones pendientes duplicadas en mempool
5. Comisión mínima de transacción pagada

**Activación:**
- La asignación se convierte en ASSIGNING en la altura de confirmación
- Se convierte en ASSIGNED después del período de retardo (4 bloques regtest, 30 bloques mainnet)
- El retardo previene reasignaciones rápidas durante carreras de bloques

**Implementación:** `src/script/forging_assignment.h`, validación en ConnectBlock

### Revocación de asignaciones

**Formato de transacción:**
```cpp
Transaction {
    inputs: [cualquiera]  // Demuestra propiedad de dirección de parcela
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Efecto:**
- Transición de estado inmediata a REVOKED
- El propietario de la parcela puede forjar inmediatamente
- Puede crear nueva asignación después

### Validación de asignaciones durante minería

**Determinación del firmante efectivo:**
```cpp
// En validación de submit_nonce
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) rechazar;

// En forjado de bloque
coinbase_script = P2WPKH(effective_signer);  // La recompensa va aquí

// En firma de bloque
signature = effective_signer_key.SignCompact(hash);  // Debe firmar con firmante efectivo
```

**Validación de bloque:**
```cpp
// En VerifyPoCXBlockCompactSignature (extendida)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) rechazar;
```

**Propiedades clave:**
- La prueba siempre contiene la dirección de parcela original
- La firma debe ser del firmante efectivo
- Coinbase paga al firmante efectivo
- La validación usa el estado de asignación a la altura del bloque

---

## Propagación en la red

### Anuncio de bloque

**Protocolo P2P estándar de Bitcoin:**
1. Bloque forjado enviado vía `ProcessNewBlock()`
2. Bloque validado y añadido a la cadena
3. Notificación de red: `GetMainSignals().BlockConnected()`
4. Capa P2P difunde bloque a pares

**Implementación:** net_processing estándar de Bitcoin Core

### Retransmisión de bloques

**Bloques compactos (BIP 152):**
- Usados para propagación eficiente de bloques
- Solo IDs de transacciones enviados inicialmente
- Pares solicitan transacciones faltantes

**Retransmisión de bloque completo:**
- Respaldo cuando los bloques compactos fallan
- Datos completos del bloque transmitidos

### Reorganizaciones de cadena

**Manejo de reorganizaciones:**
```cpp
// En hilo trabajador del forjador
if (current_tip_hash != stored_tip_hash) {
    // Reorganización de cadena detectada
    reset_forging_state();
    log("Punta de cadena cambió, reiniciando forjado");
}
```

**Nivel de blockchain:**
- Manejo estándar de reorganizaciones de Bitcoin Core
- Mejor cadena determinada por chainwork
- Bloques desconectados devueltos al mempool

---

## Detalles técnicos

### Prevención de interbloqueo

**Patrón de interbloqueo ABBA (prevenido):**
```
Hilo A: cs_main → cs_wallet
Hilo B: cs_wallet → cs_main
```

**Solución:**
1. **submit_nonce:** Uso cero de cs_main
   - `GetNewBlockContext()` maneja bloqueo internamente
   - Toda validación antes del envío al forjador

2. **Forjador:** Arquitectura basada en cola
   - Hilo trabajador único (sin uniones de hilos)
   - Contexto fresco en cada acceso
   - Sin bloqueos anidados

3. **Verificaciones de cartera:** Realizadas antes de operaciones costosas
   - Rechazo temprano si no hay clave disponible
   - Separado del acceso al estado de blockchain

### Optimizaciones de rendimiento

**Validación con fallo rápido:**
```cpp
1. Verificaciones de formato (inmediato)
2. Validación de contexto (ligero)
3. Verificación de cartera (local)
4. Validación de prueba (SIMD costoso)
```

**Obtención de contexto única:**
- Una llamada a `GetNewBlockContext()` por envío
- Cachear resultados para múltiples verificaciones
- Sin adquisiciones repetidas de cs_main

**Eficiencia de cola:**
- Estructura de envío ligera
- Sin base_target/deadline en cola (recalculado fresco)
- Huella de memoria mínima

### Manejo de obsolescencia

**Diseño de forjador "simple":**
- Sin suscripciones a eventos de blockchain
- Validación perezosa cuando se necesita
- Descartes silenciosos de envíos obsoletos

**Beneficios:**
- Arquitectura simple
- Sin sincronización compleja
- Robusto ante casos límite

**Casos límite manejados:**
- Cambios de altura → descartar
- Cambios de firma de generación → descartar
- Cambios de objetivo base → recalcular plazo
- Reorganizaciones → reiniciar estado de forjado

### Detalles criptográficos

**Firma de generación:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Hash de firma de bloque:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Formato de firma compacta:**
- 65 bytes: [recovery_id][r][s]
- Permite recuperación de clave pública
- Usado para eficiencia de espacio

**ID de cuenta:**
- HASH160 de 20 bytes de clave pública comprimida
- Coincide con formatos de dirección de Bitcoin (P2PKH, P2WPKH)

### Mejoras futuras

**Limitaciones documentadas:**
1. Sin métricas de rendimiento (tasas de envío, distribuciones de plazo)
2. Sin categorización detallada de errores para mineros
3. Consulta limitada de estado del forjador (plazo actual, profundidad de cola)

**Mejoras potenciales:**
- RPC para estado del forjador
- Métricas para eficiencia de minería
- Registro mejorado para depuración
- Soporte de protocolo de pool

---

## Referencias de código

**Implementaciones centrales:**
- Interfaz RPC: `src/pocx/rpc/mining.cpp`
- Cola del forjador: `src/pocx/mining/scheduler.cpp`
- Validación de consenso: `src/pocx/consensus/validation.cpp`
- Validación de prueba: `src/pocx/consensus/pocx.cpp`
- Flexión temporal: `src/pocx/algorithms/time_bending.cpp`
- Validación de bloque: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Lógica de asignación: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Gestión de contexto: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Estructuras de datos:**
- Formato de bloque: `src/primitives/block.h`
- Parámetros de consenso: `src/consensus/params.h`
- Rastreo de asignaciones: `src/coins.h` (extensiones de CCoinsViewCache)

---

## Apéndice: Especificaciones de algoritmos

### Fórmula de flexión temporal

**Definición matemática:**
```
deadline_seconds = quality / base_target  (crudo)

time_bended_deadline = escala * (deadline_seconds)^(1/3)

donde:
  escala = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Implementación:**
- Aritmética de punto fijo (formato Q42)
- Cálculo de raíz cúbica solo con enteros
- Optimizado para aritmética de 256 bits

### Cálculo de calidad

**Proceso:**
1. Generar scoop desde firma de generación y altura
2. Leer datos de parcela para el scoop calculado
3. Hash: `SHABAL256(generation_signature || scoop_data)`
4. Probar niveles de escalado desde mínimo a máximo
5. Devolver mejor calidad encontrada

**Escalado:**
- Nivel X0: Línea base POC2 (teórico)
- Nivel X1: Línea base XOR-transposición
- Nivel Xn: 2^(n-1) × trabajo X1 incrustado
- Mayor escalado = más trabajo de generación de parcela

### Ajuste de objetivo base

**Ajuste en cada bloque:**
1. Calcular promedio móvil de objetivos base recientes
2. Calcular intervalo real vs intervalo objetivo para ventana deslizante
3. Ajustar objetivo base proporcionalmente
4. Limitar para prevenir oscilaciones extremas

**Fórmula:**
```
avg_base_target = promedio_movil(objetivos base recientes)
factor_ajuste = intervalo_real / intervalo_objetivo
nuevo_base_target = avg_base_target * factor_ajuste
nuevo_base_target = limitar(nuevo_base_target, min, max)
```

---

*Esta documentación refleja la implementación completa de consenso PoCX a octubre de 2025.*

---

[← Anterior: Formato de parcelas](2-plot-format.md) | [Tabla de contenidos](index.md) | [Siguiente: Asignaciones de forjado →](4-forging-assignments.md)
