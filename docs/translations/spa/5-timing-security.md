[← Anterior: Asignaciones de forjado](4-forging-assignments.md) | [Tabla de contenidos](index.md) | [Siguiente: Parámetros de red →](6-network-parameters.md)

---

# Capítulo 5: Sincronización temporal y seguridad

## Panorama general

El consenso PoCX requiere sincronización temporal precisa en toda la red. Este capítulo documenta los mecanismos de seguridad relacionados con el tiempo, la tolerancia a la deriva del reloj y el comportamiento de forjado defensivo.

**Mecanismos clave**:
- Tolerancia de 15 segundos hacia el futuro para marcas de tiempo de bloques
- Sistema de advertencia de deriva del reloj de 10 segundos
- Forjado defensivo (anti-manipulación del reloj)
- Integración del algoritmo de flexión temporal

---

## Tabla de contenidos

1. [Requisitos de sincronización temporal](#requisitos-de-sincronización-temporal)
2. [Detección y advertencias de deriva del reloj](#detección-y-advertencias-de-deriva-del-reloj)
3. [Mecanismo de forjado defensivo](#mecanismo-de-forjado-defensivo)
4. [Análisis de amenazas de seguridad](#análisis-de-amenazas-de-seguridad)
5. [Mejores prácticas para operadores de nodos](#mejores-prácticas-para-operadores-de-nodos)

---

## Requisitos de sincronización temporal

### Constantes y parámetros

**Configuración de Bitcoin-PoCX:**
```cpp
// src/chain.h:31
static constexpr int64_t MAX_FUTURE_BLOCK_TIME = 15;  // 15 segundos

// src/node/timeoffsets.h:27
static constexpr std::chrono::seconds WARN_THRESHOLD{10};  // 10 segundos
```

### Verificaciones de validación

**Validación de marca de tiempo de bloque** (`src/validation.cpp:4547-4561`):
```cpp
// 1. Verificación monótona: marca de tiempo >= marca de tiempo del bloque anterior
if (block.nTime < pindexPrev->nTime) {
    return state.Invalid("time-too-old");
}

// 2. Verificación de futuro: marca de tiempo <= ahora + 15 segundos
if (block.Time() > NodeClock::now() + std::chrono::seconds{MAX_FUTURE_BLOCK_TIME}) {
    return state.Invalid("time-too-new");
}

// 3. Verificación de plazo: tiempo transcurrido >= plazo
uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
if (result.deadline > elapsed_time) {
    return state.Invalid("bad-pocx-timing");
}
```

### Tabla de impacto de deriva del reloj

| Desviación del reloj | ¿Puede sincronizar? | ¿Puede minar? | Estado de validación | Efecto competitivo |
|----------------------|---------------------|---------------|---------------------|-------------------|
| -30s atrasado | NO - Falla verificación de futuro | N/A | **NODO MUERTO** | No puede participar |
| -14s atrasado | Sí | Sí | Forjado tardío, pasa validación | Pierde carreras |
| 0s perfecto | Sí | Sí | Óptimo | Óptimo |
| +14s adelantado | Sí | Sí | Forjado temprano, pasa validación | Gana carreras |
| +16s adelantado | Sí | NO - Falla verificación de futuro | No puede propagar bloques | Puede sincronizar, no puede minar |

**Información clave**: La ventana de 15 segundos es simétrica para participación (±14.9s), pero los relojes adelantados proporcionan una ventaja competitiva injusta dentro de la tolerancia.

### Integración de flexión temporal

El algoritmo de flexión temporal (detallado en el [Capítulo 3](3-consensus-and-mining.md#cálculo-de-flexión-temporal)) transforma los plazos crudos usando raíz cúbica:

```
plazo_flexionado = escala × (plazo_segundos)^(1/3)
```

**Interacción con deriva del reloj**:
- Las mejores soluciones se forjan antes (la raíz cúbica amplifica las diferencias de calidad)
- La deriva del reloj afecta el tiempo de forjado relativo a la red
- El forjado defensivo asegura competencia basada en calidad a pesar de la varianza de temporización

---

## Detección y advertencias de deriva del reloj

### Sistema de advertencia

Bitcoin-PoCX monitorea el desfase temporal entre el nodo local y los pares de la red.

**Mensaje de advertencia** (cuando la deriva excede 10 segundos):
> "La fecha y hora de su computadora parecen estar desfasadas más de 10 segundos respecto a la red, esto puede causar fallas de consenso PoCX. Por favor verifique el reloj de su sistema."

**Implementación**: `src/node/timeoffsets.cpp`

### Justificación del diseño

**¿Por qué 10 segundos?**
- Proporciona un margen de seguridad de 5 segundos antes del límite de tolerancia de 15 segundos
- Más estricto que el valor predeterminado de Bitcoin Core (10 minutos)
- Apropiado para los requisitos de temporización de PoC

**Enfoque preventivo**:
- Advertencia temprana antes de fallo crítico
- Permite a los operadores corregir problemas proactivamente
- Reduce la fragmentación de red por fallos relacionados con el tiempo

---

## Mecanismo de forjado defensivo

### Qué es

El forjado defensivo es un comportamiento estándar del minero en Bitcoin-PoCX que elimina las ventajas basadas en temporización en la producción de bloques. Cuando su minero recibe un bloque competidor a la misma altura, verifica automáticamente si usted tiene una mejor solución. Si es así, forja su bloque inmediatamente, asegurando competencia basada en calidad en lugar de competencia basada en manipulación del reloj.

### El problema

El consenso PoCX permite bloques con marcas de tiempo hasta 15 segundos en el futuro. Esta tolerancia es necesaria para la sincronización global de la red. Sin embargo, crea una oportunidad para manipulación del reloj:

**Sin forjado defensivo:**
- Minero A: Tiempo correcto, calidad 800 (mejor), espera el plazo correcto
- Minero B: Reloj adelantado (+14s), calidad 1000 (peor), forja 14 segundos antes
- Resultado: El minero B gana la carrera a pesar de tener un trabajo de prueba de capacidad inferior

**El problema:** La manipulación del reloj proporciona ventaja incluso con peor calidad, socavando el principio de prueba de capacidad.

### La solución: Defensa de dos capas

#### Capa 1: Advertencia de deriva del reloj (preventiva)

Bitcoin-PoCX monitorea el desfase temporal entre su nodo y los pares de la red. Si su reloj se desvía más de 10 segundos del consenso de la red, recibe una advertencia que le alerta a corregir los problemas del reloj antes de que causen problemas.

#### Capa 2: Forjado defensivo (reactivo)

Cuando otro minero publica un bloque a la misma altura que usted está minando:

1. **Detección**: Su nodo identifica competencia a la misma altura
2. **Validación**: Extrae y valida la calidad del bloque competidor
3. **Comparación**: Verifica si su calidad es mejor
4. **Respuesta**: Si es mejor, forja su bloque inmediatamente

**Resultado:** La red recibe ambos bloques y elige el de mejor calidad a través de la resolución estándar de bifurcaciones.

### Cómo funciona

#### Escenario: Competencia a la misma altura

```
Tiempo 150s: Minero B (reloj +10s) forja con calidad 1000
           → Marca de tiempo del bloque muestra 160s (10s en el futuro)

Tiempo 150s: Su nodo recibe el bloque del Minero B
           → Detecta: misma altura, calidad 1000
           → Usted tiene: calidad 800 (¡mejor!)
           → Acción: Forjar inmediatamente con marca de tiempo correcta (150s)

Tiempo 152s: La red valida ambos bloques
           → Ambos válidos (dentro de tolerancia de 15s)
           → Calidad 800 gana (menor = mejor)
           → Su bloque se convierte en punta de cadena
```

#### Escenario: Reorganización genuina

```
Su altura de minería 100, competidor publica bloque 99
→ No es competencia a la misma altura
→ El forjado defensivo NO se activa
→ El manejo normal de reorganización procede
```

### Beneficios

**Cero incentivo para manipulación del reloj**
- Los relojes adelantados solo ayudan si ya tienes la mejor calidad
- La manipulación del reloj se vuelve económicamente inútil

**Competencia basada en calidad reforzada**
- Obliga a los mineros a competir en trabajo real de prueba de capacidad
- Preserva la integridad del consenso PoCX

**Seguridad de red**
- Resistente a estrategias de juego basadas en temporización
- No requiere cambios de consenso - comportamiento puro del minero

**Completamente automático**
- No requiere configuración
- Se activa solo cuando es necesario
- Comportamiento estándar en todos los nodos Bitcoin-PoCX

### Compensaciones

**Aumento mínimo de tasa de huérfanos**
- Intencional - los bloques de ataque quedan huérfanos
- Solo ocurre durante intentos reales de manipulación del reloj
- Resultado natural de la resolución de bifurcaciones basada en calidad

**Breve competencia en la red**
- La red ve brevemente dos bloques competidores
- Se resuelve en segundos a través de validación estándar
- Mismo comportamiento que la minería simultánea en Bitcoin

### Detalles técnicos

**Impacto en rendimiento:** Despreciable
- Se activa solo en competencia a la misma altura
- Usa datos en memoria (sin E/S de disco)
- La validación se completa en milisegundos

**Uso de recursos:** Mínimo
- ~20 líneas de lógica central
- Reutiliza infraestructura de validación existente
- Adquisición de bloqueo única

**Compatibilidad:** Completa
- Sin cambios de reglas de consenso
- Funciona con todas las características de Bitcoin Core
- Monitoreo opcional vía registros de depuración

**Estado**: Activo en todos los lanzamientos de Bitcoin-PoCX
**Primera introducción**: 2025-10-10

---

## Análisis de amenazas de seguridad

### Ataque de reloj adelantado (mitigado por forjado defensivo)

**Vector de ataque**:
Un minero con un reloj **+14s adelantado** puede:
1. Recibir bloques normalmente (les parecen antiguos)
2. Forjar bloques inmediatamente cuando pasa el plazo
3. Difundir bloques que parecen 14s "tempranos" a la red
4. **Los bloques son aceptados** (dentro de tolerancia de 15s)
5. **Gana carreras** contra mineros honestos

**Impacto sin forjado defensivo**:
La ventaja está limitada a 14.9 segundos (no suficiente para saltarse trabajo PoC significativo), pero proporciona una ventaja consistente en carreras de bloques.

**Mitigación (forjado defensivo)**:
- Los mineros honestos detectan competencia a la misma altura
- Comparan valores de calidad
- Forjan inmediatamente si la calidad es mejor
- **Resultado**: El reloj adelantado solo ayuda si ya tienes la mejor calidad
- **Incentivo**: Cero - la manipulación del reloj se vuelve económicamente inútil

### Fallo de reloj atrasado (crítico)

**Modo de fallo**:
Un nodo **>15s atrasado** es catastrófico:
- No puede validar bloques entrantes (falla la verificación de futuro)
- Queda aislado de la red
- No puede minar ni sincronizar

**Mitigación**:
- La advertencia fuerte a 10s de deriva proporciona un margen de 5 segundos antes del fallo crítico
- Los operadores pueden corregir problemas del reloj proactivamente
- Los mensajes de error claros guían la solución de problemas

---

## Mejores prácticas para operadores de nodos

### Configuración de sincronización temporal

**Configuración recomendada**:
1. **Habilitar NTP**: Use el Protocolo de Tiempo de Red para sincronización automática
   ```bash
   # Linux (systemd-timesyncd)
   sudo timedatectl set-ntp true

   # Verificar estado
   timedatectl status
   ```

2. **Verificar precisión del reloj**: Compruebe regularmente el desfase temporal
   ```bash
   # Verificar estado de sincronización NTP
   ntpq -p

   # O con chrony
   chronyc tracking
   ```

3. **Monitorear advertencias**: Observe las advertencias de deriva del reloj de Bitcoin-PoCX en los registros

### Para mineros

**No se requiere acción**:
- La función siempre está activa
- Opera automáticamente
- Solo mantenga su reloj del sistema preciso

**Mejores prácticas**:
- Use sincronización de tiempo NTP
- Monitoree las advertencias de deriva del reloj
- Atienda las advertencias rápidamente si aparecen

**Comportamiento esperado**:
- Minería en solitario: El forjado defensivo rara vez se activa (sin competencia)
- Minería en red: Protege contra intentos de manipulación del reloj
- Operación transparente: La mayoría de los mineros nunca lo notan

### Solución de problemas

**Advertencia: "10 segundos desfasado de la sincronización"**
- Acción: Verifique y corrija la sincronización del reloj del sistema
- Impacto: Margen de 5 segundos antes del fallo crítico
- Herramientas: NTP, chrony, systemd-timesyncd

**Error: "time-too-new" en bloques entrantes**
- Causa: Su reloj está >15 segundos atrasado
- Impacto: No puede validar bloques, nodo aislado
- Solución: Sincronice el reloj del sistema inmediatamente

**Error: No puede propagar bloques forjados**
- Causa: Su reloj está >15 segundos adelantado
- Impacto: Bloques rechazados por la red
- Solución: Sincronice el reloj del sistema inmediatamente

---

## Decisiones de diseño y justificación

### ¿Por qué tolerancia de 15 segundos?

**Justificación**:
- La temporización variable de plazos de Bitcoin-PoCX es menos crítica en tiempo que el consenso de temporización fija
- 15s proporciona protección adecuada mientras previene fragmentación de red

**Compensaciones**:
- Tolerancia más estricta = más fragmentación de red por deriva menor
- Tolerancia más laxa = más oportunidad para ataques de temporización
- 15s equilibra seguridad y robustez

### ¿Por qué advertencia de 10 segundos?

**Razonamiento**:
- Proporciona margen de seguridad de 5 segundos
- Más apropiado para PoC que los 10 minutos predeterminados de Bitcoin
- Permite correcciones proactivas antes del fallo crítico

### ¿Por qué forjado defensivo?

**Problema abordado**:
- La tolerancia de 15 segundos permite ventaja de reloj adelantado
- El consenso basado en calidad podría ser socavado por manipulación de temporización

**Beneficios de la solución**:
- Defensa sin costo (sin cambios de consenso)
- Operación automática
- Elimina el incentivo de ataque
- Preserva los principios de prueba de capacidad

### ¿Por qué no sincronización temporal intra-red?

**Razonamiento de seguridad**:
- Bitcoin Core moderno eliminó el ajuste de tiempo basado en pares
- Vulnerable a ataques Sybil en el tiempo de red percibido
- PoCX evita deliberadamente depender de fuentes de tiempo internas de la red
- El reloj del sistema es más confiable que el consenso de pares
- Los operadores deben sincronizar usando NTP o fuente de tiempo externa equivalente
- Los nodos monitorean su propia deriva y emiten advertencias si el reloj local diverge de las marcas de tiempo de bloques recientes

---

## Referencias de implementación

**Archivos centrales**:
- Validación temporal: `src/validation.cpp:4547-4561`
- Constante de tolerancia futura: `src/chain.h:31`
- Umbral de advertencia: `src/node/timeoffsets.h:27`
- Monitoreo de desfase temporal: `src/node/timeoffsets.cpp`
- Forjado defensivo: `src/pocx/mining/scheduler.cpp`

**Documentación relacionada**:
- Algoritmo de flexión temporal: [Capítulo 3: Consenso y minería](3-consensus-and-mining.md#cálculo-de-flexión-temporal)
- Validación de bloques: [Capítulo 3: Validación de bloques](3-consensus-and-mining.md#validación-de-bloques)

---

**Generado**: 2025-10-10
**Estado**: Implementación completa
**Cobertura**: Requisitos de sincronización temporal, manejo de deriva del reloj, forjado defensivo

---

[← Anterior: Asignaciones de forjado](4-forging-assignments.md) | [Tabla de contenidos](index.md) | [Siguiente: Parámetros de red →](6-network-parameters.md)
