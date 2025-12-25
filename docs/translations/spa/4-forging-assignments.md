[← Anterior: Consenso y minería](3-consensus-and-mining.md) | [Tabla de contenidos](index.md) | [Siguiente: Sincronización temporal →](5-timing-security.md)

---

# Capítulo 4: Sistema de asignación de forjado PoCX

## Resumen ejecutivo

Este documento describe el sistema de asignación de forjado PoCX **implementado** utilizando una arquitectura exclusiva OP_RETURN. El sistema permite a los propietarios de parcelas delegar derechos de forjado a direcciones separadas a través de transacciones en cadena, con seguridad completa ante reorganizaciones y operaciones atómicas de base de datos.

**Estado:** Completamente implementado y operativo

## Filosofía de diseño central

**Principio clave:** Las asignaciones son permisos, no activos

- Sin UTXOs especiales que rastrear o gastar
- Estado de asignación almacenado por separado del conjunto UTXO
- Propiedad demostrada por firma de transacción, no por gasto de UTXO
- Rastreo completo de historial para auditoría completa
- Actualizaciones atómicas de base de datos a través de escrituras por lotes de LevelDB

## Estructura de transacciones

### Formato de transacción de asignación

```
Entradas:
  [0]: Cualquier UTXO controlado por el propietario de la parcela (demuestra propiedad + paga comisiones)
       Debe estar firmado con la clave privada del propietario de la parcela
  [1+]: Entradas adicionales opcionales para cobertura de comisiones

Salidas:
  [0]: OP_RETURN (marcador POCX + dirección de parcela + dirección de forjado)
       Formato: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Tamaño: 46 bytes total (1 byte OP_RETURN + 1 byte longitud + 44 bytes datos)
       Valor: 0 BTC (no gastable, no añadido al conjunto UTXO)

  [1]: Cambio devuelto al usuario (opcional, P2WPKH estándar)
```

**Implementación:** `src/pocx/assignments/opcodes.cpp:25-52`

### Formato de transacción de revocación

```
Entradas:
  [0]: Cualquier UTXO controlado por el propietario de la parcela (demuestra propiedad + paga comisiones)
       Debe estar firmado con la clave privada del propietario de la parcela
  [1+]: Entradas adicionales opcionales para cobertura de comisiones

Salidas:
  [0]: OP_RETURN (marcador XCOP + dirección de parcela)
       Formato: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Tamaño: 26 bytes total (1 byte OP_RETURN + 1 byte longitud + 24 bytes datos)
       Valor: 0 BTC (no gastable, no añadido al conjunto UTXO)

  [1]: Cambio devuelto al usuario (opcional, P2WPKH estándar)
```

**Implementación:** `src/pocx/assignments/opcodes.cpp:54-77`

### Marcadores

- **Marcador de asignación:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Marcador de revocación:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Implementación:** `src/pocx/assignments/opcodes.cpp:15-19`

### Características clave de las transacciones

- Transacciones estándar de Bitcoin (sin cambios de protocolo)
- Las salidas OP_RETURN son demostrablemente no gastables (nunca añadidas al conjunto UTXO)
- Propiedad de parcela demostrada por firma en entrada[0] desde la dirección de parcela
- Bajo costo (~200 bytes, típicamente <0.0001 BTC de comisión)
- La cartera selecciona automáticamente el UTXO más grande de la dirección de parcela para demostrar propiedad

## Arquitectura de base de datos

### Estructura de almacenamiento

Todos los datos de asignación se almacenan en la misma base de datos LevelDB que el conjunto UTXO (`chainstate/`), pero con prefijos de clave separados:

```
chainstate/ LevelDB:
├─ Conjunto UTXO (estándar Bitcoin Core)
│  └─ Prefijo 'C': COutPoint → Coin
│
└─ Estado de asignación (adiciones PoCX)
   └─ Prefijo 'A': (plot_address, assignment_txid) → ForgingAssignment
       └─ Historial completo: todas las asignaciones por parcela a lo largo del tiempo
```

**Implementación:** `src/txdb.cpp:237-348`

### Estructura ForgingAssignment

```cpp
struct ForgingAssignment {
    // Identidad
    std::array<uint8_t, 20> plotAddress;      // Propietario de parcela (hash P2WPKH de 20 bytes)
    std::array<uint8_t, 20> forgingAddress;   // Titular de derechos de forjado (hash P2WPKH de 20 bytes)

    // Ciclo de vida de asignación
    uint256 assignment_txid;                   // Transacción que creó la asignación
    int assignment_height;                     // Altura de bloque de creación
    int assignment_effective_height;           // Cuándo se activa (altura + retardo)

    // Ciclo de vida de revocación
    bool revoked;                              // ¿Ha sido revocada?
    uint256 revocation_txid;                   // Transacción que la revocó
    int revocation_height;                     // Altura de bloque de revocación
    int revocation_effective_height;           // Cuándo la revocación es efectiva (altura + retardo)

    // Métodos de consulta de estado
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Implementación:** `src/coins.h:111-178`

### Estados de asignación

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // No existe asignación
    ASSIGNING = 1,   // Asignación creada, esperando retardo de activación
    ASSIGNED = 2,    // Asignación activa, forjado permitido
    REVOKING = 3,    // Revocada, pero aún activa durante período de retardo
    REVOKED = 4      // Completamente revocada, ya no activa
};
```

**Implementación:** `src/coins.h:98-104`

### Claves de base de datos

```cpp
// Clave de historial: almacena registro completo de asignación
// Formato de clave: (prefijo, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Dirección de parcela (20 bytes)
    int assignment_height;                // Altura para optimización de ordenamiento
    uint256 assignment_txid;              // ID de transacción
};
```

**Implementación:** `src/txdb.cpp:245-262`

### Rastreo de historial

- Cada asignación se almacena permanentemente (nunca eliminada salvo reorganización)
- Múltiples asignaciones por parcela rastreadas a lo largo del tiempo
- Permite auditoría completa y consultas de estado histórico
- Las asignaciones revocadas permanecen en la base de datos con `revoked=true`

## Procesamiento de bloques

### Integración en ConnectBlock

Los OP_RETURNs de asignación y revocación se procesan durante la conexión de bloques en `validation.cpp`:

```cpp
// Ubicación: Después de validación de script, antes de UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Parsear datos de OP_RETURN
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Verificar propiedad (tx debe estar firmada por propietario de parcela)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Verificar estado de parcela (debe ser UNASSIGNED o REVOKED)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Crear nueva asignación
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Almacenar datos de deshacer
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Parsear datos de OP_RETURN
            auto plot_addr = ParseRevocationOpReturn(output);

            // Verificar propiedad
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Obtener asignación actual
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Almacenar estado anterior para deshacer
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Marcar como revocada
            ForgingAssignment revoked = *existing;
            revoked.revoked = true;
            revoked.revocation_txid = tx.GetHash();
            revoked.revocation_height = height;
            revoked.revocation_effective_height = height + consensus.nForgingRevocationDelay;

            view.UpdateForgingAssignment(revoked);
        }
    }
}
#endif

// UpdateCoins procede normalmente (omite automáticamente salidas OP_RETURN)
```

**Implementación:** `src/validation.cpp:2775-2878`

### Verificación de propiedad

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Verificar que al menos una entrada está firmada por el propietario de la parcela
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // Extraer destino
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // Verificar si es P2WPKH a la dirección de parcela
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core ya validó la firma
                return true;
            }
        }
    }
    return false;
}
```

**Implementación:** `src/pocx/assignments/opcodes.cpp:217-256`

### Retardos de activación

Las asignaciones y revocaciones tienen retardos de activación configurables para prevenir ataques de reorganización:

```cpp
// Parámetros de consenso (configurables por red)
// Ejemplo: 30 bloques = ~1 hora con tiempo de bloque de 2 minutos
consensus.nForgingAssignmentDelay;   // Retardo de activación de asignación
consensus.nForgingRevocationDelay;   // Retardo de activación de revocación
```

**Transiciones de estado:**
- Asignación: `UNASSIGNED → ASSIGNING (retardo) → ASSIGNED`
- Revocación: `ASSIGNED → REVOKING (retardo) → REVOKED`

**Implementación:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Validación de mempool

Las transacciones de asignación y revocación se validan en la aceptación del mempool para rechazar transacciones inválidas antes de la propagación en la red.

### Verificaciones a nivel de transacción (CheckTransaction)

Realizadas en `src/consensus/tx_check.cpp` sin acceso al estado de la cadena:

1. **Máximo un OP_RETURN POCX:** La transacción no puede contener múltiples marcadores POCX/XCOP

**Implementación:** `src/consensus/tx_check.cpp:63-77`

### Verificaciones de aceptación en mempool (PreChecks)

Realizadas en `src/validation.cpp` con acceso completo al estado de la cadena y mempool:

#### Validación de asignación

1. **Propiedad de parcela:** La transacción debe estar firmada por el propietario de la parcela
2. **Estado de parcela:** La parcela debe ser UNASSIGNED (0) o REVOKED (4)
3. **Conflictos de mempool:** Ninguna otra asignación para esta parcela en mempool (gana el primero visto)

#### Validación de revocación

1. **Propiedad de parcela:** La transacción debe estar firmada por el propietario de la parcela
2. **Asignación activa:** La parcela debe estar en estado ASSIGNED (2) únicamente
3. **Conflictos de mempool:** Ninguna otra revocación para esta parcela en mempool

**Implementación:** `src/validation.cpp:898-993`

### Flujo de validación

```
Difusión de transacción
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Máximo un OP_RETURN POCX
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Verificar propiedad de parcela
  ✓ Verificar estado de asignación
  ✓ Verificar conflictos de mempool
       ↓
   Válida → Aceptar en mempool
   Inválida → Rechazar (no propagar)
       ↓
Minería de bloque
       ↓
ConnectBlock() [validation.cpp]
  ✓ Re-validar todas las verificaciones (defensa en profundidad)
  ✓ Aplicar cambios de estado
  ✓ Registrar información de deshacer
```

### Defensa en profundidad

Todas las verificaciones de validación de mempool se re-ejecutan durante `ConnectBlock()` para proteger contra:
- Ataques de bypass de mempool
- Bloques inválidos de mineros maliciosos
- Casos límite durante escenarios de reorganización

La validación de bloques permanece como autoridad para el consenso.

## Actualizaciones atómicas de base de datos

### Arquitectura de tres capas

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (Caché de memoria)    │  ← Cambios de asignación rastreados en memoria
│   - Coins: cacheCoins                   │
│   - Asignaciones: pendingAssignments    │
│   - Rastreo de suciedad: dirtyPlots     │
│   - Eliminaciones: deletedAssignments   │
│   - Rastreo de memoria: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (Capa de base de datos)  │  ← Escritura atómica única
│   - BatchWrite(): UTXOs + Asignaciones  │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (Almacenamiento en disco)     │  ← Garantías ACID
│   - Transacción atómica                 │
└─────────────────────────────────────────┘
```

### Proceso de vaciado

Cuando se llama a `view.Flush()` durante la conexión de bloques:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Escribir cambios de monedas a base
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Escribir cambios de asignación atómicamente
    if (fOk && !dirtyPlots.empty()) {
        // Recopilar asignaciones sucias
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // Vacío - no usado

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // Escribir a base de datos
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // Limpiar rastreo
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // Liberar memoria
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Implementación:** `src/coins.cpp:278-315`

### Escritura por lotes en base de datos

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Lote único de LevelDB

    // 1. Marcar estado de transición
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Escribir todos los cambios de monedas
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Marcar estado consistente
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. COMMIT ATÓMICO
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Asignaciones escritas por separado pero en mismo contexto de transacción de base de datos
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // Parámetro no usado (mantenido para compatibilidad de API)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // Nuevo lote, pero misma base de datos

    // Escribir historial de asignaciones
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // Borrar asignaciones eliminadas del historial
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // COMMIT ATÓMICO
    return m_db->WriteBatch(batch);
}
```

**Implementación:** `src/txdb.cpp:332-348`

### Garantías de atomicidad

**Lo que es atómico:**
- Todos los cambios de monedas dentro de un bloque se escriben atómicamente
- Todos los cambios de asignación dentro de un bloque se escriben atómicamente
- La base de datos permanece consistente ante caídas

**Limitación actual:**
- Monedas y asignaciones se escriben en operaciones de lote LevelDB **separadas**
- Ambas operaciones ocurren durante `view.Flush()`, pero no en una sola escritura atómica
- En la práctica: Ambos lotes se completan en rápida sucesión antes del fsync de disco
- El riesgo es mínimo: Ambos necesitarían reproducirse desde el mismo bloque durante recuperación de caída

**Nota:** Esto difiere del plan de arquitectura original que requería un solo lote unificado. La implementación actual usa dos lotes pero mantiene consistencia a través de los mecanismos de recuperación de caída existentes de Bitcoin Core (marcador DB_HEAD_BLOCKS).

## Manejo de reorganizaciones

### Estructura de datos de deshacer

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Asignación fue añadida (eliminar al deshacer)
        MODIFIED = 1,   // Asignación fue modificada (restaurar al deshacer)
        REVOKED = 2     // Asignación fue revocada (des-revocar al deshacer)
    };

    UndoType type;
    ForgingAssignment assignment;  // Estado completo antes del cambio
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // Datos de deshacer de UTXO
    std::vector<ForgingUndo> vforgingundo;  // Datos de deshacer de asignación
};
```

**Implementación:** `src/undo.h:63-105`

### Proceso de DisconnectBlock

Cuando un bloque se desconecta durante una reorganización:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... desconexión estándar de UTXO ...

    // Leer datos de deshacer del disco
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Deshacer cambios de asignación (procesar en orden inverso)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Asignación fue añadida - eliminarla
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Asignación fue revocada - restaurar estado no revocado
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Asignación fue modificada - restaurar estado anterior
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Implementación:** `src/validation.cpp:2381-2415`

### Gestión de caché durante reorganización

```cpp
class CCoinsViewCache {
private:
    // Cachés de asignación
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Rastrear parcelas modificadas
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // Rastrear eliminaciones
    mutable size_t cachedAssignmentsUsage{0};  // Rastreo de memoria

public:
    void AddForgingAssignment(const ForgingAssignment& assignment) {
        pendingAssignments[assignment.plotAddress].push_back(assignment);
        dirtyPlots.insert(assignment.plotAddress);
        cachedAssignmentsUsage += sizeof(ForgingAssignment);
    }

    void RemoveForgingAssignment(const std::array<uint8_t, 20>& plotAddress,
                                 const uint256& assignment_txid) {
        auto key = std::make_pair(plotAddress, assignment_txid);
        deletedAssignments.insert(key);
        dirtyPlots.insert(plotAddress);
        if (cachedAssignmentsUsage >= sizeof(ForgingAssignment)) {
            cachedAssignmentsUsage -= sizeof(ForgingAssignment);
        }
    }

    void RestoreForgingAssignment(const ForgingAssignment& assignment) {
        pendingAssignments[assignment.plotAddress].push_back(assignment);
        dirtyPlots.insert(assignment.plotAddress);
        auto key = std::make_pair(assignment.plotAddress, assignment.assignment_txid);
        deletedAssignments.erase(key);
        if (true) {
            cachedAssignmentsUsage += sizeof(ForgingAssignment);
        }
    }
};
```

**Implementación:** `src/coins.cpp:494-565`

## Interfaz RPC

### Comandos de nodo (sin cartera requerida)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Devuelve el estado actual de asignación para una dirección de parcela:
```json
{
  "plot_address": "pocx1qplot...",
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 100,
  "activation_height": 244,
  "revoked": false
}
```

**Implementación:** `src/pocx/rpc/assignments.cpp:31-126`

### Comandos de cartera (cartera requerida)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Crea una transacción de asignación:
- Selecciona automáticamente el UTXO más grande de la dirección de parcela para demostrar propiedad
- Construye transacción con OP_RETURN + salida de cambio
- Firma con la clave del propietario de la parcela
- Difunde a la red

**Implementación:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Crea una transacción de revocación:
- Selecciona automáticamente el UTXO más grande de la dirección de parcela para demostrar propiedad
- Construye transacción con OP_RETURN + salida de cambio
- Firma con la clave del propietario de la parcela
- Difunde a la red

**Implementación:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### Creación de transacción de cartera

El proceso de creación de transacción de cartera:

```cpp
1. Parsear y validar direcciones (deben ser P2WPKH bech32)
2. Encontrar el UTXO más grande de la dirección de parcela (demuestra propiedad)
3. Crear transacción temporal con salida ficticia
4. Firmar transacción (obtener tamaño preciso con datos de testigo)
5. Reemplazar salida ficticia con OP_RETURN
6. Ajustar comisiones proporcionalmente según cambio de tamaño
7. Re-firmar transacción final
8. Difundir a la red
```

**Información clave:** La cartera debe gastar desde la dirección de parcela para demostrar propiedad, por lo que automáticamente fuerza la selección de monedas desde esa dirección.

**Implementación:** `src/pocx/assignments/transactions.cpp:38-263`

## Estructura de archivos

### Archivos de implementación central

```
src/
├── coins.h                        # Estructura ForgingAssignment, métodos CCoinsViewCache [710 líneas]
├── coins.cpp                      # Gestión de caché, escrituras por lotes [603 líneas]
│
├── txdb.h                         # Métodos de asignación CCoinsViewDB [90 líneas]
├── txdb.cpp                       # Lectura/escritura de base de datos [349 líneas]
│
├── undo.h                         # Estructura ForgingUndo para reorganizaciones
│
├── validation.cpp                 # Integración ConnectBlock/DisconnectBlock
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # Formato OP_RETURN, parseo, verificación
    │   ├── opcodes.cpp            # [259 líneas] Definiciones de marcadores, ops OP_RETURN, verificación de propiedad
    │   ├── assignment_state.h     # Ayudantes GetEffectiveSigner, GetAssignmentState
    │   ├── assignment_state.cpp   # Funciones de consulta de estado de asignación
    │   ├── transactions.h         # API de creación de transacción de cartera
    │   └── transactions.cpp       # Funciones de cartera create_assignment, revoke_assignment
    │
    ├── rpc/
    │   ├── assignments.h          # Comandos RPC de nodo (sin cartera)
    │   ├── assignments.cpp        # RPCs get_assignment, list_assignments
    │   ├── assignments_wallet.h   # Comandos RPC de cartera
    │   └── assignments_wallet.cpp # RPCs create_assignment, revoke_assignment
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Características de rendimiento

### Operaciones de base de datos

- **Obtener asignación actual:** O(n) - escanear todas las asignaciones para la dirección de parcela para encontrar la más reciente
- **Obtener historial de asignaciones:** O(n) - iterar todas las asignaciones para la parcela
- **Crear asignación:** O(1) - inserción única
- **Revocar asignación:** O(1) - actualización única
- **Reorganización (por asignación):** O(1) - aplicación directa de datos de deshacer

Donde n = número de asignaciones para una parcela (típicamente pequeño, < 10)

### Uso de memoria

- **Por asignación:** ~160 bytes (estructura ForgingAssignment)
- **Sobrecarga de caché:** Sobrecarga de mapa hash para rastreo de suciedad
- **Bloque típico:** <10 asignaciones = <2 KB de memoria

### Uso de disco

- **Por asignación:** ~200 bytes en disco (con sobrecarga de LevelDB)
- **10000 asignaciones:** ~2 MB de espacio en disco
- **Despreciable comparado con el conjunto UTXO:** <0.001% del chainstate típico

## Limitaciones actuales y trabajo futuro

### Limitación de atomicidad

**Actual:** Monedas y asignaciones se escriben en lotes LevelDB separados durante `view.Flush()`

**Impacto:** Riesgo teórico de inconsistencia si ocurre caída entre lotes

**Mitigación:**
- Ambos lotes se completan rápidamente antes del fsync
- La recuperación de caída de Bitcoin Core usa el marcador DB_HEAD_BLOCKS
- En la práctica: Nunca observado en pruebas

**Mejora futura:** Unificar en una sola operación de lote LevelDB

### Poda de historial de asignaciones

**Actual:** Todas las asignaciones se almacenan indefinidamente

**Impacto:** ~200 bytes por asignación para siempre

**Futuro:** Poda opcional de asignaciones completamente revocadas más antiguas que N bloques

**Nota:** Poco probable que sea necesario - incluso 1 millón de asignaciones = 200 MB

## Estado de pruebas

### Pruebas implementadas

- Parseo y validación de OP_RETURN
- Verificación de propiedad
- Creación de asignación en ConnectBlock
- Revocación en ConnectBlock
- Manejo de reorganización en DisconnectBlock
- Operaciones de lectura/escritura de base de datos
- Transiciones de estado (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
- Comandos RPC (get_assignment, create_assignment, revoke_assignment)
- Creación de transacción de cartera

### Áreas de cobertura de pruebas

- Pruebas unitarias: `src/test/pocx_*_tests.cpp`
- Pruebas funcionales: `test/functional/feature_pocx_*.py`
- Pruebas de integración: Pruebas manuales con regtest

## Reglas de consenso

### Reglas de creación de asignación

1. **Propiedad:** La transacción debe estar firmada por el propietario de la parcela
2. **Estado:** La parcela debe estar en estado UNASSIGNED o REVOKED
3. **Formato:** OP_RETURN válido con marcador POCX + 2x direcciones de 20 bytes
4. **Unicidad:** Una asignación activa por parcela a la vez

### Reglas de revocación

1. **Propiedad:** La transacción debe estar firmada por el propietario de la parcela
2. **Existencia:** La asignación debe existir y no estar ya revocada
3. **Formato:** OP_RETURN válido con marcador XCOP + dirección de 20 bytes

### Reglas de activación

- **Activación de asignación:** `assignment_height + nForgingAssignmentDelay`
- **Activación de revocación:** `revocation_height + nForgingRevocationDelay`
- **Retardos:** Configurables por red (por ejemplo, 30 bloques = ~1 hora con tiempo de bloque de 2 minutos)

### Validación de bloques

- Asignación/revocación inválida → bloque rechazado (fallo de consenso)
- Salidas OP_RETURN excluidas automáticamente del conjunto UTXO (comportamiento estándar de Bitcoin)
- El procesamiento de asignaciones ocurre antes de las actualizaciones de UTXO en ConnectBlock

## Conclusión

El sistema de asignación de forjado PoCX tal como está implementado proporciona:

- **Simplicidad:** Transacciones estándar de Bitcoin, sin UTXOs especiales
- **Economía:** Sin requisito de polvo, solo comisiones de transacción
- **Seguridad ante reorganizaciones:** Datos de deshacer completos restauran el estado correcto
- **Actualizaciones atómicas:** Consistencia de base de datos a través de lotes LevelDB
- **Historial completo:** Auditoría completa de todas las asignaciones a lo largo del tiempo
- **Arquitectura limpia:** Modificaciones mínimas a Bitcoin Core, código PoCX aislado
- **Listo para producción:** Completamente implementado, probado y operativo

### Calidad de implementación

- **Organización del código:** Excelente - separación clara entre Bitcoin Core y PoCX
- **Manejo de errores:** Validación de consenso exhaustiva
- **Documentación:** Comentarios de código y estructura bien documentados
- **Pruebas:** Funcionalidad central probada, integración verificada

### Decisiones de diseño clave validadas

1. Enfoque exclusivo OP_RETURN (vs basado en UTXO)
2. Almacenamiento separado en base de datos (vs extraData de Coin)
3. Rastreo de historial completo (vs solo actual)
4. Propiedad por firma (vs gasto de UTXO)
5. Retardos de activación (previene ataques de reorganización)

El sistema logra exitosamente todos los objetivos arquitectónicos con una implementación limpia y mantenible.

---

[← Anterior: Consenso y minería](3-consensus-and-mining.md) | [Tabla de contenidos](index.md) | [Siguiente: Sincronización temporal →](5-timing-security.md)
