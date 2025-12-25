[← Anterior: Sincronización temporal](5-timing-security.md) | [Tabla de contenidos](index.md) | [Siguiente: Referencia RPC →](7-rpc-reference.md)

---

# Capítulo 6: Parámetros de red y configuración

Referencia completa para la configuración de red de Bitcoin-PoCX en todos los tipos de red.

---

## Tabla de contenidos

1. [Parámetros del bloque génesis](#parámetros-del-bloque-génesis)
2. [Configuración de chainparams](#configuración-de-chainparams)
3. [Parámetros de consenso](#parámetros-de-consenso)
4. [Coinbase y recompensas de bloque](#coinbase-y-recompensas-de-bloque)
5. [Escalado dinámico](#escalado-dinámico)
6. [Configuración de red](#configuración-de-red)
7. [Estructura del directorio de datos](#estructura-del-directorio-de-datos)

---

## Parámetros del bloque génesis

### Cálculo del objetivo base

**Fórmula**: `objetivo_base_genesis = 2^42 / tiempo_bloque_segundos`

**Justificación**:
- Cada nonce representa 256 KiB (64 bytes × 4096 scoops)
- 1 TiB = 2^22 nonces (suposición de capacidad inicial de red)
- Calidad mínima esperada para n nonces ≈ 2^64 / n
- Para 1 TiB: E(calidad) = 2^64 / 2^22 = 2^42
- Por lo tanto: objetivo_base = 2^42 / tiempo_bloque

**Valores calculados**:
- Mainnet/Testnet/Signet (120s): `36650387592`
- Regtest (1s): Usa modo de calibración de baja capacidad

### Mensaje del génesis

Todas las redes comparten el mensaje del génesis de Bitcoin:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Implementación**: `src/kernel/chainparams.cpp`

---

## Configuración de chainparams

### Parámetros de Mainnet

**Identidad de red**:
- **Bytes mágicos**: `0xa7 0x3c 0x91 0x5e`
- **Puerto predeterminado**: `8888`
- **HRP Bech32**: `pocx`

**Prefijos de dirección** (Base58):
- PUBKEY_ADDRESS: `85` (direcciones comienzan con 'P')
- SCRIPT_ADDRESS: `90` (direcciones comienzan con 'R')
- SECRET_KEY: `128`

**Temporización de bloques**:
- **Objetivo de tiempo de bloque**: `120` segundos (2 minutos)
- **Intervalo objetivo**: `1209600` segundos (14 días)
- **MAX_FUTURE_BLOCK_TIME**: `15` segundos

**Recompensas de bloque**:
- **Subsidio inicial**: `10 BTC`
- **Intervalo de halving**: `1050000` bloques (~4 años)
- **Conteo de halvings**: 64 halvings máximo

**Ajuste de dificultad**:
- **Ventana móvil**: `24` bloques
- **Ajuste**: Cada bloque
- **Algoritmo**: Promedio móvil exponencial

**Retardos de asignación**:
- **Activación**: `30` bloques (~1 hora)
- **Revocación**: `720` bloques (~24 horas)

### Parámetros de Testnet

**Identidad de red**:
- **Bytes mágicos**: `0x6d 0xf2 0x48 0xb3`
- **Puerto predeterminado**: `18888`
- **HRP Bech32**: `tpocx`

**Prefijos de dirección** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Temporización de bloques**:
- **Objetivo de tiempo de bloque**: `120` segundos
- **MAX_FUTURE_BLOCK_TIME**: `15` segundos
- **Permitir dificultad mínima**: `true`

**Recompensas de bloque**:
- **Subsidio inicial**: `10 BTC`
- **Intervalo de halving**: `1050000` bloques

**Ajuste de dificultad**:
- **Ventana móvil**: `24` bloques

**Retardos de asignación**:
- **Activación**: `30` bloques (~1 hora)
- **Revocación**: `720` bloques (~24 horas)

### Parámetros de Regtest

**Identidad de red**:
- **Bytes mágicos**: `0xfa 0xbf 0xb5 0xda`
- **Puerto predeterminado**: `18444`
- **HRP Bech32**: `rpocx`

**Prefijos de dirección** (compatibles con Bitcoin):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Temporización de bloques**:
- **Objetivo de tiempo de bloque**: `1` segundo (minería instantánea para pruebas)
- **Intervalo objetivo**: `86400` segundos (1 día)
- **MAX_FUTURE_BLOCK_TIME**: `15` segundos

**Recompensas de bloque**:
- **Subsidio inicial**: `10 BTC`
- **Intervalo de halving**: `500` bloques

**Ajuste de dificultad**:
- **Ventana móvil**: `24` bloques
- **Permitir dificultad mínima**: `true`
- **Sin reajuste**: `true`
- **Calibración de baja capacidad**: `true` (usa calibración de 16 nonces en lugar de 1 TiB)

**Retardos de asignación**:
- **Activación**: `4` bloques (~4 segundos)
- **Revocación**: `8` bloques (~8 segundos)

### Parámetros de Signet

**Identidad de red**:
- **Bytes mágicos**: Primeros 4 bytes de SHA256d(signet_challenge)
- **Puerto predeterminado**: `38333`
- **HRP Bech32**: `tpocx`

**Temporización de bloques**:
- **Objetivo de tiempo de bloque**: `120` segundos
- **MAX_FUTURE_BLOCK_TIME**: `15` segundos

**Recompensas de bloque**:
- **Subsidio inicial**: `10 BTC`
- **Intervalo de halving**: `1050000` bloques

**Ajuste de dificultad**:
- **Ventana móvil**: `24` bloques

---

## Parámetros de consenso

### Parámetros de temporización

**MAX_FUTURE_BLOCK_TIME**: `15` segundos
- Específico de PoCX (Bitcoin usa 2 horas)
- Justificación: La temporización PoC requiere validación casi en tiempo real
- Los bloques más de 15s en el futuro son rechazados

**Advertencia de desfase temporal**: `10` segundos
- Los operadores son advertidos cuando el reloj del nodo se desvía >10s del tiempo de la red
- Sin aplicación, solo informativo

**Objetivos de tiempo de bloque**:
- Mainnet/Testnet/Signet: `120` segundos
- Regtest: `1` segundo

**TIMESTAMP_WINDOW**: `15` segundos (igual a MAX_FUTURE_BLOCK_TIME)

**Implementación**: `src/chain.h`, `src/validation.cpp`

### Parámetros de ajuste de dificultad

**Tamaño de ventana móvil**: `24` bloques (todas las redes)
- Promedio móvil exponencial de tiempos de bloque recientes
- Ajuste en cada bloque
- Responde a cambios de capacidad

**Implementación**: `src/consensus/params.h`, lógica de dificultad en creación de bloques

### Parámetros del sistema de asignación

**nForgingAssignmentDelay** (retardo de activación):
- Mainnet: `30` bloques (~1 hora)
- Testnet: `30` bloques (~1 hora)
- Regtest: `4` bloques (~4 segundos)

**nForgingRevocationDelay** (retardo de revocación):
- Mainnet: `720` bloques (~24 horas)
- Testnet: `720` bloques (~24 horas)
- Regtest: `8` bloques (~8 segundos)

**Justificación**:
- El retardo de activación previene reasignación rápida durante carreras de bloques
- El retardo de revocación proporciona estabilidad y previene abuso

**Implementación**: `src/consensus/params.h`

---

## Coinbase y recompensas de bloque

### Programa de subsidio de bloque

**Subsidio inicial**: `10 BTC` (todas las redes)

**Programa de halving**:
- Cada `1050000` bloques (mainnet/testnet)
- Cada `500` bloques (regtest)
- Continúa por 64 halvings máximo

**Progresión de halving**:
```
Halving 0: 10.00000000 BTC  (bloques 0 - 1049999)
Halving 1:  5.00000000 BTC  (bloques 1050000 - 2099999)
Halving 2:  2.50000000 BTC  (bloques 2100000 - 3149999)
Halving 3:  1.25000000 BTC  (bloques 3150000 - 4199999)
...
```

**Suministro total**: ~21 millones de BTC (igual que Bitcoin)

### Reglas de salida de coinbase

**Destino de pago**:
- **Sin asignación**: Coinbase paga a la dirección de parcela (proof.account_id)
- **Con asignación**: Coinbase paga a la dirección de forjado (firmante efectivo)

**Formato de salida**: Solo P2WPKH
- Coinbase debe pagar a dirección SegWit v0 bech32
- Generada desde la clave pública del firmante efectivo

**Resolución de asignación**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implementación**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Escalado dinámico

### Límites de escalado

**Propósito**: Aumentar la dificultad de generación de parcelas a medida que la red madura para prevenir inflación de capacidad

**Estructura**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Nivel mínimo aceptado
    uint8_t nPoCXTargetCompression;  // Nivel recomendado
};
```

**Relación**: `objetivo = mínimo + 1` (siempre un nivel por encima del mínimo)

### Programa de incremento de escalado

Los niveles de escalado aumentan en **programa exponencial** basado en intervalos de halving:

| Período | Altura de bloque | Halvings | Mín | Objetivo |
|---------|------------------|----------|-----|----------|
| Años 0-4 | 0 a 1049999 | 0 | X1 | X2 |
| Años 4-12 | 1050000 a 3149999 | 1-2 | X2 | X3 |
| Años 12-28 | 3150000 a 7349999 | 3-6 | X3 | X4 |
| Años 28-60 | 7350000 a 15749999 | 7-14 | X4 | X5 |
| Años 60-124 | 15750000 a 32549999 | 15-30 | X5 | X6 |
| Años 124+ | 32550000+ | 31+ | X6 | X7 |

**Alturas clave** (años → halvings → bloques):
- Año 4: Halving 1 en bloque 1050000
- Año 12: Halving 3 en bloque 3150000
- Año 28: Halving 7 en bloque 7350000
- Año 60: Halving 15 en bloque 15750000
- Año 124: Halving 31 en bloque 32550000

### Dificultad del nivel de escalado

**Escalado de PoW**:
- Nivel de escalado X0: Línea base POC2 (teórico)
- Nivel de escalado X1: Línea base XOR-transposición
- Nivel de escalado Xn: 2^(n-1) × trabajo X1 incrustado
- Cada nivel duplica el trabajo de generación de parcela

**Alineación económica**:
- Las recompensas de bloque se reducen a la mitad → la dificultad de generación de parcela aumenta
- Mantiene margen de seguridad: costo de creación de parcela > costo de consulta
- Previene inflación de capacidad por mejoras de hardware

### Validación de parcelas

**Reglas de validación**:
- Las pruebas enviadas deben tener nivel de escalado ≥ mínimo
- Las pruebas con escalado > objetivo son aceptadas pero ineficientes
- Las pruebas por debajo del mínimo: rechazadas (PoW insuficiente)

**Obtención de límites**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implementación**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Configuración de red

### Nodos semilla y semillas DNS

**Estado**: Marcador de posición para lanzamiento de mainnet

**Configuración planeada**:
- Nodos semilla: Por determinar
- Semillas DNS: Por determinar

**Estado actual** (testnet/regtest):
- Sin infraestructura de semillas dedicada
- Conexiones manuales de pares soportadas vía `-addnode`

**Implementación**: `src/kernel/chainparams.cpp`

### Puntos de control

**Punto de control del génesis**: Siempre bloque 0

**Puntos de control adicionales**: Ninguno configurado actualmente

**Futuro**: Los puntos de control se añadirán a medida que avance la mainnet

---

## Configuración del protocolo P2P

### Versión del protocolo

**Base**: Protocolo Bitcoin Core v30.0
- **Versión del protocolo**: Heredada de Bitcoin Core
- **Bits de servicio**: Servicios estándar de Bitcoin
- **Tipos de mensaje**: Mensajes P2P estándar de Bitcoin

**Extensiones PoCX**:
- Los encabezados de bloque incluyen campos específicos de PoCX
- Los mensajes de bloque incluyen datos de prueba PoCX
- Las reglas de validación aplican el consenso PoCX

**Compatibilidad**: Los nodos PoCX son incompatibles con los nodos Bitcoin PoW (consenso diferente)

**Implementación**: `src/protocol.h`, `src/net_processing.cpp`

---

## Estructura del directorio de datos

### Directorio predeterminado

**Ubicación**: `.bitcoin/` (igual que Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Contenido del directorio

```
.bitcoin/
├── blocks/              # Datos de bloques
│   ├── blk*.dat        # Archivos de bloques
│   ├── rev*.dat        # Datos de deshacer
│   └── index/          # Índice de bloques (LevelDB)
├── chainstate/         # Conjunto UTXO + asignaciones de forjado (LevelDB)
├── wallets/            # Archivos de cartera
│   └── wallet.dat      # Cartera predeterminada
├── bitcoin.conf        # Archivo de configuración
├── debug.log           # Registro de depuración
├── peers.dat           # Direcciones de pares
├── mempool.dat         # Persistencia del mempool
└── banlist.dat         # Pares baneados
```

### Diferencias clave con Bitcoin

**Base de datos chainstate**:
- Estándar: Conjunto UTXO
- **Adición PoCX**: Estado de asignación de forjado
- Actualizaciones atómicas: UTXO + asignaciones actualizados juntos
- Datos de deshacer seguros ante reorganizaciones para asignaciones

**Archivos de bloques**:
- Formato de bloque estándar de Bitcoin
- **Adición PoCX**: Extendido con campos de prueba PoCX (account_id, seed, nonce, signature, pubkey)

### Ejemplo de archivo de configuración

**bitcoin.conf**:
```ini
# Selección de red
#testnet=1
#regtest=1

# Servidor de minería PoCX (requerido para mineros externos)
miningserver=1

# Configuración RPC
server=1
rpcuser=tuusuario
rpcpassword=tucontraseña
rpcallowip=127.0.0.1
rpcport=8332

# Configuración de conexión
listen=1
port=8888
maxconnections=125

# Objetivo de tiempo de bloque (informativo, aplicado por consenso)
# 120 segundos para mainnet/testnet
```

---

## Referencias de código

**Chainparams**: `src/kernel/chainparams.cpp`
**Parámetros de consenso**: `src/consensus/params.h`
**Límites de compresión**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Cálculo de objetivo base del génesis**: `src/pocx/consensus/params.cpp`
**Lógica de pago de coinbase**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Almacenamiento de estado de asignación**: `src/coins.h`, `src/coins.cpp` (extensiones de CCoinsViewCache)

---

## Referencias cruzadas

Capítulos relacionados:
- [Capítulo 2: Formato de parcelas](2-plot-format.md) - Niveles de escalado en generación de parcelas
- [Capítulo 3: Consenso y minería](3-consensus-and-mining.md) - Validación de escalado, sistema de asignación
- [Capítulo 4: Asignaciones de forjado](4-forging-assignments.md) - Parámetros de retardo de asignación
- [Capítulo 5: Seguridad temporal](5-timing-security.md) - Justificación de MAX_FUTURE_BLOCK_TIME

---

[← Anterior: Sincronización temporal](5-timing-security.md) | [Tabla de contenidos](index.md) | [Siguiente: Referencia RPC →](7-rpc-reference.md)
