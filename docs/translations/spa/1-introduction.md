[Tabla de contenidos](index.md) | [Siguiente: Formato de parcelas →](2-plot-format.md)

---

# Capítulo 1: Introducción y panorama general

## ¿Qué es Bitcoin-PoCX?

Bitcoin-PoCX es una integración de Bitcoin Core que añade soporte para el consenso de **Prueba de Capacidad de Nueva Generación (PoCX)**. Mantiene la arquitectura existente de Bitcoin Core mientras habilita una alternativa de minería eficiente energéticamente mediante Prueba de Capacidad como reemplazo completo de la Prueba de Trabajo.

**Distinción clave**: Esta es una **nueva cadena** sin compatibilidad retroactiva con Bitcoin PoW. Los bloques PoCX son incompatibles con los nodos PoW por diseño.

---

## Identidad del proyecto

- **Organización**: Proof of Capacity Consortium
- **Nombre del proyecto**: Bitcoin-PoCX
- **Nombre completo**: Bitcoin Core con integración PoCX
- **Estado**: Fase de Testnet

---

## ¿Qué es la Prueba de Capacidad?

La Prueba de Capacidad (PoC) es un mecanismo de consenso donde el poder de minería es proporcional al **espacio en disco** en lugar del poder computacional. Los mineros pre-generan grandes archivos de parcela que contienen hashes criptográficos, luego usan estas parcelas para encontrar soluciones válidas de bloque.

**Eficiencia energética**: Los archivos de parcela se generan una vez y se reutilizan indefinidamente. La minería consume un poder de CPU mínimo, principalmente operaciones de E/S de disco.

**Mejoras de PoCX**:
- Ataque de compresión XOR-transposición corregido (compensación tiempo-memoria del 50% en POC2)
- Disposición alineada a 16 nonces para hardware moderno
- Prueba de trabajo escalable en la generación de parcelas (niveles de escalado Xn)
- Integración nativa en C++ directamente en Bitcoin Core
- Algoritmo de flexión temporal para mejor distribución del tiempo de bloque

---

## Panorama de la arquitectura

### Estructura del repositorio

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + integración PoCX
│   └── src/pocx/        # Implementación PoCX
├── pocx/                # Framework central PoCX (submódulo, solo lectura)
└── docs/                # Esta documentación
```

### Filosofía de integración

**Superficie de integración mínima**: Cambios aislados en el directorio `/src/pocx/` con enlaces limpios hacia las capas de validación, minería y RPC de Bitcoin Core.

**Marcado de características**: Todas las modificaciones bajo guardas de preprocesador `#ifdef ENABLE_POCX`. Bitcoin Core se compila normalmente cuando está deshabilitado.

**Compatibilidad ascendente**: Sincronización regular con actualizaciones de Bitcoin Core mantenida a través de puntos de integración aislados.

**Implementación nativa en C++**: Algoritmos criptográficos escalares (Shabal256, cálculo de scoop, compresión) integrados directamente en Bitcoin Core para validación de consenso.

---

## Características principales

### 1. Reemplazo completo del consenso

- **Estructura de bloque**: Campos específicos de PoCX reemplazan el nonce PoW y los bits de dificultad
  - Firma de generación (entropía de minería determinista)
  - Objetivo base (inverso de la dificultad)
  - Prueba PoCX (ID de cuenta, semilla, nonce)
  - Firma de bloque (demuestra propiedad de la parcela)

- **Validación**: Pipeline de validación de 5 etapas desde verificación de encabezado hasta conexión de bloque

- **Ajuste de dificultad**: Ajuste en cada bloque usando promedio móvil de objetivos base recientes

### 2. Algoritmo de flexión temporal

**Problema**: Los tiempos de bloque tradicionales de PoC siguen una distribución exponencial, causando bloques largos cuando ningún minero encuentra una buena solución.

**Solución**: Transformación de distribución de exponencial a chi-cuadrado usando raíz cúbica: `Y = escala × (X^(1/3))`.

**Efecto**: Las soluciones muy buenas se forjan más tarde (la red tiene tiempo de escanear todos los discos, reduciendo bloques rápidos), las soluciones pobres mejoran. El tiempo promedio de bloque se mantiene en 120 segundos, los bloques largos se reducen.

**Detalles**: [Capítulo 3: Consenso y minería](3-consensus-and-mining.md)

### 3. Sistema de asignación de forjado

**Capacidad**: Los propietarios de parcelas pueden delegar derechos de forjado a otras direcciones manteniendo la propiedad de la parcela.

**Casos de uso**:
- Minería en pool (las parcelas se asignan a la dirección del pool)
- Almacenamiento en frío (clave de minería separada de la propiedad de la parcela)
- Minería multipartita (infraestructura compartida)

**Arquitectura**: Diseño exclusivo OP_RETURN, sin UTXOs especiales, las asignaciones se rastrean por separado en la base de datos de chainstate.

**Detalles**: [Capítulo 4: Asignaciones de forjado](4-forging-assignments.md)

### 4. Forjado defensivo

**Problema**: Los relojes adelantados podrían proporcionar ventajas de temporización dentro de la tolerancia de 15 segundos hacia el futuro.

**Solución**: Al recibir un bloque competidor a la misma altura, verificar automáticamente la calidad local. Si es mejor, forjar inmediatamente.

**Efecto**: Elimina el incentivo para manipular el reloj; los relojes adelantados solo ayudan si ya tienes la mejor solución.

**Detalles**: [Capítulo 5: Seguridad temporal](5-timing-security.md)

### 5. Escalado de compresión dinámico

**Alineación económica**: Los requisitos de nivel de escalado aumentan en un programa exponencial (Años 4, 12, 28, 60, 124 = halvings 1, 3, 7, 15, 31).

**Efecto**: A medida que las recompensas de bloque disminuyen, la dificultad de generación de parcelas aumenta. Mantiene el margen de seguridad entre los costos de creación y consulta de parcelas.

**Previene**: Inflación de capacidad por hardware más rápido con el tiempo.

**Detalles**: [Capítulo 6: Parámetros de red](6-network-parameters.md)

---

## Filosofía de diseño

### Seguridad del código

- Prácticas de programación defensiva en todo el código
- Manejo exhaustivo de errores en rutas de validación
- Sin bloqueos anidados (prevención de interbloqueo)
- Operaciones atómicas de base de datos (UTXO + asignaciones juntas)

### Arquitectura modular

- Separación clara entre la infraestructura de Bitcoin Core y el consenso PoCX
- El framework central PoCX proporciona primitivas criptográficas
- Bitcoin Core proporciona el marco de validación, base de datos y red

### Optimizaciones de rendimiento

- Ordenamiento de validación con fallo rápido (verificaciones económicas primero)
- Obtención de contexto única por envío (sin adquisiciones repetidas de cs_main)
- Operaciones atómicas de base de datos para consistencia

### Seguridad ante reorganizaciones

- Datos de deshacer completos para cambios de estado de asignación
- Reinicio del estado de forjado en cambios de punta de cadena
- Detección de obsolescencia en todos los puntos de validación

---

## Diferencias entre PoCX y la Prueba de Trabajo

| Aspecto | Bitcoin (PoW) | Bitcoin-PoCX |
|---------|---------------|--------------|
| **Recurso de minería** | Poder computacional (tasa de hash) | Espacio en disco (capacidad) |
| **Consumo energético** | Alto (hashing continuo) | Bajo (solo E/S de disco) |
| **Proceso de minería** | Encontrar nonce con hash < objetivo | Encontrar nonce con plazo < tiempo transcurrido |
| **Dificultad** | Campo `bits`, ajustado cada 2016 bloques | Campo `base_target`, ajustado cada bloque |
| **Tiempo de bloque** | ~10 minutos (distribución exponencial) | 120 segundos (flexión temporal, varianza reducida) |
| **Subsidio** | 50 BTC → 25 → 12.5 → ... | 10 BTC → 5 → 2.5 → ... |
| **Hardware** | ASICs (especializado) | HDDs (hardware genérico) |
| **Identidad de minería** | Anónimo | Propietario de parcela o delegado |

---

## Requisitos del sistema

### Operación de nodo

**Igual que Bitcoin Core**:
- **CPU**: Procesador x86_64 moderno
- **Memoria**: 4-8 GB de RAM
- **Almacenamiento**: Nueva cadena, actualmente vacía (puede crecer ~4× más rápido que Bitcoin debido a bloques de 2 minutos y base de datos de asignaciones)
- **Red**: Conexión a internet estable
- **Reloj**: Sincronización NTP recomendada para operación óptima

**Nota**: Los archivos de parcela NO son necesarios para la operación del nodo.

### Requisitos de minería

**Requisitos adicionales para minería**:
- **Archivos de parcela**: Pre-generados usando `pocx_plotter` (implementación de referencia)
- **Software minero**: `pocx_miner` (implementación de referencia) se conecta vía RPC
- **Cartera**: `bitcoind` o `bitcoin-qt` con claves privadas para la dirección de minería. La minería en pool no requiere cartera local.

---

## Primeros pasos

### 1. Compilar Bitcoin-PoCX

```bash
# Clonar con submódulos
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Compilar con PoCX habilitado
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Detalles**: Consulte `CLAUDE.md` en la raíz del repositorio

### 2. Ejecutar el nodo

**Solo nodo**:
```bash
./build/bin/bitcoind
# o
./build/bin/bitcoin-qt
```

**Para minería** (habilita acceso RPC para mineros externos):
```bash
./build/bin/bitcoind -miningserver
# o
./build/bin/bitcoin-qt -server -miningserver
```

**Detalles**: [Capítulo 6: Parámetros de red](6-network-parameters.md)

### 3. Generar archivos de parcela

Use `pocx_plotter` (implementación de referencia) para generar archivos de parcela en formato PoCX.

**Detalles**: [Capítulo 2: Formato de parcelas](2-plot-format.md)

### 4. Configurar la minería

Use `pocx_miner` (implementación de referencia) para conectarse a la interfaz RPC de su nodo.

**Detalles**: [Capítulo 7: Referencia RPC](7-rpc-reference.md) y [Capítulo 8: Guía de cartera](8-wallet-guide.md)

---

## Atribución

### Formato de parcela

Basado en el formato POC2 (Burstcoin) con mejoras:
- Fallo de seguridad corregido (ataque de compresión XOR-transposición)
- Prueba de trabajo escalable
- Disposición optimizada para SIMD
- Funcionalidad de semilla

### Proyectos fuente

- **pocx_miner**: Implementación de referencia basada en [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Implementación de referencia basada en [engraver](https://github.com/PoC-Consortium/engraver)

**Atribución completa**: [Capítulo 2: Formato de parcelas](2-plot-format.md)

---

## Resumen de especificaciones técnicas

- **Tiempo de bloque**: 120 segundos (mainnet), 1 segundo (regtest)
- **Subsidio de bloque**: 10 BTC inicial, halving cada 1050000 bloques (~4 años)
- **Suministro total**: ~21 millones de BTC (igual que Bitcoin)
- **Tolerancia futura**: 15 segundos (bloques hasta 15s adelante aceptados)
- **Advertencia de reloj**: 10 segundos (advierte a operadores de deriva temporal)
- **Retardo de asignación**: 30 bloques (~1 hora)
- **Retardo de revocación**: 720 bloques (~24 horas)
- **Formato de dirección**: Solo P2WPKH (bech32, pocx1q...) para operaciones de minería PoCX y asignaciones de forjado

---

## Organización del código

**Modificaciones de Bitcoin Core**: Cambios mínimos a archivos centrales, marcados con `#ifdef ENABLE_POCX`

**Nueva implementación PoCX**: Aislada en el directorio `src/pocx/`

---

## Consideraciones de seguridad

### Seguridad temporal

- Tolerancia de 15 segundos hacia el futuro previene fragmentación de red
- Umbral de advertencia de 10 segundos alerta a operadores sobre deriva del reloj
- El forjado defensivo elimina el incentivo para manipulación del reloj
- La flexión temporal reduce el impacto de la varianza de temporización

**Detalles**: [Capítulo 5: Seguridad temporal](5-timing-security.md)

### Seguridad de asignaciones

- Diseño exclusivo OP_RETURN (sin manipulación de UTXO)
- La firma de transacción demuestra propiedad de la parcela
- Los retardos de activación previenen manipulación rápida del estado
- Datos de deshacer seguros ante reorganizaciones para todos los cambios de estado

**Detalles**: [Capítulo 4: Asignaciones de forjado](4-forging-assignments.md)

### Seguridad del consenso

- Firma excluida del hash de bloque (previene maleabilidad)
- Tamaños de firma acotados (previene DoS)
- Validación de límites de compresión (previene pruebas débiles)
- Ajuste de dificultad en cada bloque (responde a cambios de capacidad)

**Detalles**: [Capítulo 3: Consenso y minería](3-consensus-and-mining.md)

---

## Estado de la red

**Mainnet**: Aún no lanzada
**Testnet**: Disponible para pruebas
**Regtest**: Completamente funcional para desarrollo

**Parámetros del bloque génesis**: [Capítulo 6: Parámetros de red](6-network-parameters.md)

---

## Próximos pasos

**Para entender PoCX**: Continúe al [Capítulo 2: Formato de parcelas](2-plot-format.md) para aprender sobre la estructura de archivos de parcela y la evolución del formato.

**Para configurar minería**: Salte al [Capítulo 7: Referencia RPC](7-rpc-reference.md) para detalles de integración.

**Para ejecutar un nodo**: Revise el [Capítulo 6: Parámetros de red](6-network-parameters.md) para opciones de configuración.

---

[Tabla de contenidos](index.md) | [Siguiente: Formato de parcelas →](2-plot-format.md)
