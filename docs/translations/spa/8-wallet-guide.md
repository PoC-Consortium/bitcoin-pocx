[← Anterior: Referencia RPC](7-rpc-reference.md) | [Tabla de contenidos](index.md)

---

# Capítulo 8: Guía de usuario de cartera y GUI

Guía completa para la cartera Qt de Bitcoin-PoCX y gestión de asignaciones de forjado.

---

## Tabla de contenidos

1. [Panorama general](#panorama-general)
2. [Unidades de moneda](#unidades-de-moneda)
3. [Diálogo de asignación de forjado](#diálogo-de-asignación-de-forjado)
4. [Historial de transacciones](#historial-de-transacciones)
5. [Requisitos de direcciones](#requisitos-de-direcciones)
6. [Integración de minería](#integración-de-minería)
7. [Solución de problemas](#solución-de-problemas)
8. [Mejores prácticas de seguridad](#mejores-prácticas-de-seguridad)

---

## Panorama general

### Características de la cartera Bitcoin-PoCX

La cartera Qt de Bitcoin-PoCX (`bitcoin-qt`) proporciona:
- Funcionalidad estándar de cartera de Bitcoin Core (enviar, recibir, gestión de transacciones)
- **Gestor de asignaciones de forjado**: GUI para crear/revocar asignaciones de parcelas
- **Modo servidor de minería**: La bandera `-miningserver` habilita características relacionadas con minería
- **Historial de transacciones**: Visualización de transacciones de asignación y revocación

### Iniciar la cartera

**Solo nodo** (sin minería):
```bash
./build/bin/bitcoin-qt
```

**Con minería** (habilita diálogo de asignación):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Alternativa de línea de comandos**:
```bash
./build/bin/bitcoind -miningserver
```

### Requisitos de minería

**Para operaciones de minería**:
- Bandera `-miningserver` requerida
- Cartera con direcciones P2WPKH y claves privadas
- Graficador externo (`pocx_plotter`) para generación de parcelas
- Minero externo (`pocx_miner`) para minería

**Para minería en pool**:
- Crear asignación de forjado a la dirección del pool
- Cartera no requerida en el servidor del pool (el pool gestiona las claves)

---

## Unidades de moneda

### Visualización de unidades

Bitcoin-PoCX usa la unidad de moneda **BTCX** (no BTC):

| Unidad | Satoshis | Visualización |
|--------|----------|---------------|
| **BTCX** | 100000000 | 1.00000000 BTCX |
| **mBTCX** | 100000 | 1000.00 mBTCX |
| **µBTCX** | 100 | 1000000.00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**Configuración de GUI**: Preferencias → Visualización → Unidad

---

## Diálogo de asignación de forjado

### Acceso al diálogo

**Menú**: `Cartera → Asignaciones de forjado`
**Barra de herramientas**: Icono de minería (visible solo con bandera `-miningserver`)
**Tamaño de ventana**: 600×450 píxeles

### Modos del diálogo

#### Modo 1: Crear asignación

**Propósito**: Delegar derechos de forjado a un pool u otra dirección mientras se retiene la propiedad de la parcela.

**Casos de uso**:
- Minería en pool (asignar a dirección del pool)
- Almacenamiento en frío (clave de minería separada de propiedad de parcela)
- Infraestructura compartida (delegar a cartera caliente)

**Requisitos**:
- Dirección de parcela (P2WPKH bech32, debe poseer clave privada)
- Dirección de forjado (P2WPKH bech32, diferente de la dirección de parcela)
- Cartera desbloqueada (si está encriptada)
- La dirección de parcela tiene UTXOs confirmados

**Pasos**:
1. Seleccionar modo "Crear asignación"
2. Elegir dirección de parcela del desplegable o ingresar manualmente
3. Ingresar dirección de forjado (pool o delegado)
4. Hacer clic en "Enviar asignación" (botón habilitado cuando las entradas son válidas)
5. La transacción se difunde inmediatamente
6. La asignación se activa después de `nForgingAssignmentDelay` bloques:
   - Mainnet/Testnet: 30 bloques (~1 hora)
   - Regtest: 4 bloques (~4 segundos)

**Comisión de transacción**: Por defecto 10× `minRelayFee` (personalizable)

**Estructura de transacción**:
- Entrada: UTXO de la dirección de parcela (demuestra propiedad)
- Salida OP_RETURN: marcador `POCX` + plot_address + forging_address (46 bytes)
- Salida de cambio: Devuelto a la cartera

#### Modo 2: Revocar asignación

**Propósito**: Cancelar asignación de forjado y devolver derechos al propietario de parcela.

**Requisitos**:
- Dirección de parcela (debe poseer clave privada)
- Cartera desbloqueada (si está encriptada)
- La dirección de parcela tiene UTXOs confirmados

**Pasos**:
1. Seleccionar modo "Revocar asignación"
2. Elegir dirección de parcela
3. Hacer clic en "Enviar revocación"
4. La transacción se difunde inmediatamente
5. La revocación es efectiva después de `nForgingRevocationDelay` bloques:
   - Mainnet/Testnet: 720 bloques (~24 horas)
   - Regtest: 8 bloques (~8 segundos)

**Efecto**:
- La dirección de forjado aún puede forjar durante el período de retardo
- El propietario de parcela recupera derechos después de que la revocación se complete
- Puede crear nueva asignación después

**Estructura de transacción**:
- Entrada: UTXO de la dirección de parcela (demuestra propiedad)
- Salida OP_RETURN: marcador `XCOP` + plot_address (26 bytes)
- Salida de cambio: Devuelto a la cartera

#### Modo 3: Verificar estado de asignación

**Propósito**: Consultar el estado actual de asignación para cualquier dirección de parcela.

**Requisitos**: Ninguno (solo lectura, no requiere cartera)

**Pasos**:
1. Seleccionar modo "Verificar estado de asignación"
2. Ingresar dirección de parcela
3. Hacer clic en "Verificar estado"
4. El cuadro de estado muestra el estado actual con detalles

**Indicadores de estado** (codificados por color):

**Gris - UNASSIGNED**
```
UNASSIGNED - No existe asignación
```

**Naranja - ASSIGNING**
```
ASSIGNING - Asignación pendiente de activación
Dirección de forjado: pocx1qforger...
Creada en altura: 12000
Se activa en altura: 12030 (5 bloques restantes)
```

**Verde - ASSIGNED**
```
ASSIGNED - Asignación activa
Dirección de forjado: pocx1qforger...
Creada en altura: 12000
Activada en altura: 12030
```

**Rojo-naranja - REVOKING**
```
REVOKING - Revocación pendiente
Dirección de forjado: pocx1qforger... (aún activa)
Asignación creada en altura: 12000
Revocada en altura: 12300
Revocación efectiva en altura: 13020 (50 bloques restantes)
```

**Rojo - REVOKED**
```
REVOKED - Asignación revocada
Previamente asignada a: pocx1qforger...
Asignación creada en altura: 12000
Revocada en altura: 12300
Revocación efectiva en altura: 13020
```

---

## Historial de transacciones

### Visualización de transacción de asignación

**Tipo**: "Asignación"
**Icono**: Icono de minería (igual que bloques minados)

**Columna de dirección**: Dirección de parcela (dirección cuyos derechos de forjado se están asignando)
**Columna de cantidad**: Comisión de transacción (negativa, transacción saliente)
**Columna de estado**: Conteo de confirmaciones (0-6+)

**Detalles** (al hacer clic):
- ID de transacción
- Dirección de parcela
- Dirección de forjado (parseada del OP_RETURN)
- Creada en altura
- Altura de activación
- Comisión de transacción
- Marca de tiempo

### Visualización de transacción de revocación

**Tipo**: "Revocación"
**Icono**: Icono de minería

**Columna de dirección**: Dirección de parcela
**Columna de cantidad**: Comisión de transacción (negativa)
**Columna de estado**: Conteo de confirmaciones

**Detalles** (al hacer clic):
- ID de transacción
- Dirección de parcela
- Revocada en altura
- Altura efectiva de revocación
- Comisión de transacción
- Marca de tiempo

### Filtrado de transacciones

**Filtros disponibles**:
- "Todo" (predeterminado, incluye asignaciones/revocaciones)
- Rango de fechas
- Rango de cantidades
- Búsqueda por dirección
- Búsqueda por ID de transacción
- Búsqueda por etiqueta (si la dirección está etiquetada)

**Nota**: Las transacciones de asignación/revocación actualmente aparecen bajo el filtro "Todo". El filtro de tipo dedicado aún no está implementado.

### Ordenamiento de transacciones

**Orden de clasificación** (por tipo):
- Generado (tipo 0)
- Recibido (tipo 1-3)
- Asignación (tipo 4)
- Revocación (tipo 5)
- Enviado (tipo 6+)

---

## Requisitos de direcciones

### Solo P2WPKH (SegWit v0)

**Las operaciones de forjado requieren**:
- Direcciones codificadas en bech32 (comenzando con "pocx1q" mainnet, "tpocx1q" testnet, "rpocx1q" regtest)
- Formato P2WPKH (Pay-to-Witness-Public-Key-Hash)
- Hash de clave de 20 bytes

**NO soportado**:
- P2PKH (legacy, comenzando con "1")
- P2SH (SegWit envuelto, comenzando con "3")
- P2TR (Taproot, comenzando con "bc1p")

**Justificación**: Las firmas de bloque PoCX requieren formato witness v0 específico para validación de prueba.

### Filtrado del desplegable de direcciones

**ComboBox de dirección de parcela**:
- Se rellena automáticamente con las direcciones de recepción de la cartera
- Filtra direcciones que no son P2WPKH
- Muestra formato: "Etiqueta (dirección)" si está etiquetada, sino solo la dirección
- Primer elemento: "-- Ingresar dirección personalizada --" para entrada manual

**Entrada manual**:
- Valida formato al ingresar
- Debe ser bech32 P2WPKH válido
- Botón deshabilitado si el formato es inválido

### Mensajes de error de validación

**Errores del diálogo**:
- "La dirección de parcela debe ser P2WPKH (bech32)"
- "La dirección de forjado debe ser P2WPKH (bech32)"
- "Formato de dirección inválido"
- "No hay monedas disponibles en la dirección de parcela. No se puede demostrar propiedad."
- "No se pueden crear transacciones con cartera de solo observación"
- "Cartera no disponible"
- "Cartera bloqueada" (desde RPC)

---

## Integración de minería

### Requisitos de configuración

**Configuración del nodo**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Requisitos de cartera**:
- Direcciones P2WPKH para propiedad de parcela
- Claves privadas para minería (o dirección de forjado si usa asignaciones)
- UTXOs confirmados para creación de transacciones

**Herramientas externas**:
- `pocx_plotter`: Generar archivos de parcela
- `pocx_miner`: Escanear parcelas y enviar nonces

### Flujo de trabajo

#### Minería en solitario

1. **Generar archivos de parcela**:
   ```bash
   pocx_plotter --account <hash160_direccion_parcela> --seed <32_bytes> --nonces <cantidad>
   ```

2. **Iniciar nodo** con servidor de minería:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Configurar minero**:
   - Apuntar al endpoint RPC del nodo
   - Especificar directorios de archivos de parcela
   - Configurar ID de cuenta (de dirección de parcela)

4. **Iniciar minería**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /ruta/a/parcelas
   ```

5. **Monitorear**:
   - El minero llama a `get_mining_info` cada bloque
   - Escanea parcelas para el mejor plazo
   - Llama a `submit_nonce` cuando encuentra una solución
   - El nodo valida y forja el bloque automáticamente

#### Minería en pool

1. **Generar archivos de parcela** (igual que minería en solitario)

2. **Crear asignación de forjado**:
   - Abrir diálogo de asignación de forjado
   - Seleccionar dirección de parcela
   - Ingresar dirección de forjado del pool
   - Hacer clic en "Enviar asignación"
   - Esperar retardo de activación (30 bloques en testnet)

3. **Configurar minero**:
   - Apuntar al endpoint del **pool** (no al nodo local)
   - El pool maneja `submit_nonce` a la cadena

4. **Operación del pool**:
   - La cartera del pool tiene claves privadas de la dirección de forjado
   - El pool valida envíos de mineros
   - El pool llama a `submit_nonce` a la blockchain
   - El pool distribuye recompensas según política del pool

### Recompensas de coinbase

**Sin asignación**:
- Coinbase paga directamente a la dirección del propietario de parcela
- Verificar balance en la dirección de parcela

**Con asignación**:
- Coinbase paga a la dirección de forjado
- El pool recibe las recompensas
- El minero recibe su parte del pool

**Programa de recompensas**:
- Inicial: 10 BTCX por bloque
- Halving: Cada 1050000 bloques (~4 años)
- Programa: 10 → 5 → 2.5 → 1.25 → ...

---

## Solución de problemas

### Problemas comunes

#### "La cartera no tiene clave privada para la dirección de parcela"

**Causa**: La cartera no es propietaria de la dirección
**Solución**:
- Importar clave privada vía RPC `importprivkey`
- O usar dirección de parcela diferente propiedad de la cartera

#### "Ya existe asignación para esta parcela"

**Causa**: La parcela ya está asignada a otra dirección
**Solución**:
1. Revocar asignación existente
2. Esperar retardo de revocación (720 bloques en testnet)
3. Crear nueva asignación

#### "Formato de dirección no soportado"

**Causa**: La dirección no es P2WPKH bech32
**Solución**:
- Usar direcciones que comiencen con "pocx1q" (mainnet) o "tpocx1q" (testnet)
- Generar nueva dirección si es necesario: `getnewaddress "" "bech32"`

#### "Comisión de transacción muy baja"

**Causa**: Congestión del mempool de red o comisión muy baja para retransmisión
**Solución**:
- Aumentar parámetro de tasa de comisión
- Esperar a que se despeje el mempool

#### "Asignación aún no activa"

**Causa**: El retardo de activación aún no ha expirado
**Solución**:
- Verificar estado: bloques restantes hasta activación
- Esperar a que se complete el período de retardo

#### "No hay monedas disponibles en la dirección de parcela"

**Causa**: La dirección de parcela no tiene UTXOs confirmados
**Solución**:
1. Enviar fondos a la dirección de parcela
2. Esperar 1 confirmación
3. Reintentar creación de asignación

#### "No se pueden crear transacciones con cartera de solo observación"

**Causa**: La cartera importó la dirección sin clave privada
**Solución**: Importar clave privada completa, no solo la dirección

#### "Pestaña de asignación de forjado no visible"

**Causa**: El nodo se inició sin la bandera `-miningserver`
**Solución**: Reiniciar con `bitcoin-qt -server -miningserver`

### Pasos de depuración

1. **Verificar estado de cartera**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Verificar propiedad de dirección**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Verificar: "iswatchonly": false, "ismine": true
   ```

3. **Verificar estado de asignación**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Ver transacciones recientes**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Verificar sincronización del nodo**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Verificar: blocks == headers (completamente sincronizado)
   ```

---

## Mejores prácticas de seguridad

### Seguridad de dirección de parcela

**Gestión de claves**:
- Almacenar claves privadas de direcciones de parcela de forma segura
- Las transacciones de asignación demuestran propiedad mediante firma
- Solo el propietario de la parcela puede crear/revocar asignaciones

**Respaldo**:
- Respaldar cartera regularmente (`dumpwallet` o `backupwallet`)
- Almacenar wallet.dat en ubicación segura
- Registrar frases de recuperación si usa cartera HD

### Delegación de dirección de forjado

**Modelo de seguridad**:
- La dirección de forjado recibe recompensas de bloque
- La dirección de forjado puede firmar bloques (minería)
- La dirección de forjado **NO puede** modificar o revocar la asignación
- El propietario de la parcela retiene control total

**Casos de uso**:
- **Delegación de cartera caliente**: Clave de parcela en almacenamiento frío, clave de forjado en cartera caliente para minería
- **Minería en pool**: Delegar al pool, retener propiedad de parcela
- **Infraestructura compartida**: Múltiples mineros, una dirección de forjado

### Sincronización de tiempo de red

**Importancia**:
- El consenso PoCX requiere tiempo preciso
- Deriva del reloj >10s activa advertencia
- Deriva del reloj >15s previene minería

**Solución**:
- Mantener el reloj del sistema sincronizado con NTP
- Monitorear: `bitcoin-cli getnetworkinfo` para advertencias de desfase temporal
- Usar servidores NTP confiables

### Retardos de asignación

**Retardo de activación** (30 bloques en testnet):
- Previene reasignación rápida durante bifurcaciones de cadena
- Permite que la red alcance consenso
- No puede evitarse

**Retardo de revocación** (720 bloques en testnet):
- Proporciona estabilidad para pools de minería
- Previene ataques de "cambio de asignación"
- La dirección de forjado permanece activa durante el retardo

### Encriptación de cartera

**Habilitar encriptación**:
```bash
bitcoin-cli encryptwallet "tu_frase_secreta"
```

**Desbloquear para transacciones**:
```bash
bitcoin-cli walletpassphrase "tu_frase_secreta" 300
```

**Mejores prácticas**:
- Usar frase secreta fuerte (20+ caracteres)
- No almacenar frase secreta en texto plano
- Bloquear cartera después de crear asignaciones

---

## Referencias de código

**Diálogo de asignación de forjado**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Visualización de transacciones**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Parseo de transacciones**: `src/qt/transactionrecord.cpp`
**Integración de cartera**: `src/pocx/assignments/transactions.cpp`
**RPCs de asignación**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI principal**: `src/qt/bitcoingui.cpp`

---

## Referencias cruzadas

Capítulos relacionados:
- [Capítulo 3: Consenso y minería](3-consensus-and-mining.md) - Proceso de minería
- [Capítulo 4: Asignaciones de forjado](4-forging-assignments.md) - Arquitectura de asignaciones
- [Capítulo 6: Parámetros de red](6-network-parameters.md) - Valores de retardo de asignación
- [Capítulo 7: Referencia RPC](7-rpc-reference.md) - Detalles de comandos RPC

---

[← Anterior: Referencia RPC](7-rpc-reference.md) | [Tabla de contenidos](index.md)
