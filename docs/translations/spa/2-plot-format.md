[← Anterior: Introducción](1-introduction.md) | [Tabla de contenidos](index.md) | [Siguiente: Consenso y minería →](3-consensus-and-mining.md)

---

# Capítulo 2: Especificación del formato de parcelas PoCX

Este documento describe el formato de parcelas PoCX, una versión mejorada del formato POC2 con seguridad reforzada, optimizaciones SIMD y prueba de trabajo escalable.

## Panorama del formato

Los archivos de parcela PoCX contienen valores hash Shabal256 precalculados organizados para operaciones de minería eficientes. Siguiendo la tradición PoC desde POC1, **todos los metadatos están incrustados en el nombre del archivo** - no hay encabezado de archivo.

### Extensión de archivo
- **Estándar**: `.pocx` (parcelas completadas)
- **En progreso**: `.tmp` (durante el graficado, renombrado a `.pocx` al completarse)

## Contexto histórico y evolución de vulnerabilidades

### Formato POC1 (heredado)
**Dos vulnerabilidades principales (compensaciones tiempo-memoria):**

1. **Fallo de distribución PoW**
   - Distribución no uniforme de prueba de trabajo entre scoops
   - Los números bajos de scoop podían calcularse al vuelo
   - **Impacto**: Requisitos de almacenamiento reducidos para atacantes

2. **Ataque de compresión XOR** (compensación tiempo-memoria del 50%)
   - Explotaba propiedades matemáticas para lograr reducción del 50% en almacenamiento
   - **Impacto**: Los atacantes podían minar con la mitad del almacenamiento requerido

**Optimización de disposición**: Disposición secuencial básica de scoops para eficiencia en HDD

### Formato POC2 (Burstcoin)
- Fallo de distribución PoW corregido
- La vulnerabilidad XOR-transposición permaneció sin parchear
- **Disposición**: Mantuvo la optimización secuencial de scoops

### Formato PoCX (actual)
- Distribución PoW corregida (heredada de POC2)
- Vulnerabilidad XOR-transposición parcheada (exclusivo de PoCX)
- Disposición SIMD/GPU mejorada optimizada para procesamiento paralelo y coalescencia de memoria
- Prueba de trabajo escalable previene compensaciones tiempo-memoria a medida que crece el poder de cómputo (PoW se realiza solo al crear o actualizar archivos de parcela)

## Codificación XOR-transposición

### El problema: Compensación tiempo-memoria del 50%

En los formatos POC1/POC2, los atacantes podían explotar la relación matemática entre scoops para almacenar solo la mitad de los datos y computar el resto al vuelo durante la minería. Este "ataque de compresión XOR" socavaba la garantía de almacenamiento.

### La solución: Endurecimiento XOR-transposición

PoCX deriva su formato de minería (X1) aplicando codificación XOR-transposición a pares de warps base (X0):

**Para construir el scoop S del nonce N en un warp X1:**
1. Tomar el scoop S del nonce N del primer warp X0 (posición directa)
2. Tomar el scoop N del nonce S del segundo warp X0 (posición transpuesta)
3. Aplicar XOR a los dos valores de 64 bytes para obtener el scoop X1

El paso de transposición intercambia los índices de scoop y nonce. En términos matriciales, donde las filas representan scoops y las columnas representan nonces, combina el elemento en la posición (S, N) del primer warp con el elemento en (N, S) del segundo.

### Por qué esto elimina el ataque

La XOR-transposición entrelaza cada scoop con una fila completa y una columna completa de los datos X0 subyacentes. Recuperar un solo scoop X1 requiere acceso a datos que abarcan los 4096 índices de scoop. Cualquier intento de computar datos faltantes requeriría regenerar 4096 nonces completos en lugar de un solo nonce, eliminando la estructura de costos asimétrica explotada por el ataque XOR.

Como resultado, almacenar el warp X1 completo se convierte en la única estrategia computacionalmente viable para los mineros.

## Estructura de metadatos en el nombre de archivo

Todos los metadatos de parcela se codifican en el nombre de archivo usando este formato exacto:

```
{CARGA_CUENTA}_{SEMILLA}_{WARPS}_{ESCALADO}.pocx
```

### Componentes del nombre de archivo

1. **CARGA_CUENTA** (40 caracteres hexadecimales)
   - Carga de cuenta cruda de 20 bytes como hexadecimal mayúscula
   - Independiente de la red (sin ID de red ni suma de verificación)
   - Ejemplo: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEMILLA** (64 caracteres hexadecimales)
   - Valor de semilla de 32 bytes como hexadecimal minúscula
   - **Nuevo en PoCX**: Semilla aleatoria de 32 bytes en el nombre de archivo reemplaza la numeración consecutiva de nonces, previniendo superposiciones de parcelas
   - Ejemplo: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS** (número decimal)
   - **Nueva unidad de tamaño en PoCX**: Reemplaza el dimensionamiento basado en nonces de POC1/POC2
   - **Diseño resistente a XOR-transposición**: Cada warp = exactamente 4096 nonces (tamaño de partición requerido para la transformación resistente a XOR-transposición)
   - **Tamaño**: 1 warp = 1073741824 bytes = 1 GiB (unidad conveniente)
   - Ejemplo: `1024` (parcela de 1 TiB = 1024 warps)

4. **ESCALADO** (decimal prefijado con X)
   - Nivel de escalado como `X{nivel}`
   - Valores más altos = más prueba de trabajo requerida
   - Ejemplo: `X4` (2^4 = 16× dificultad POC2)

### Ejemplos de nombres de archivo
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Disposición de archivo y estructura de datos

### Organización jerárquica
```
Archivo de parcela (SIN ENCABEZADO)
├── Scoop 0
│   ├── Warp 0 (Todos los nonces para este scoop/warp)
│   ├── Warp 1
│   └── ...
├── Scoop 1
│   ├── Warp 0
│   ├── Warp 1
│   └── ...
└── Scoop 4095
    ├── Warp 0
    └── ...
```

### Constantes y tamaños

| Constante       | Tamaño                  | Descripción                                     |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                   | Salida de un solo hash Shabal256                |
| **SCOOP\_SIZE** | 64 B (2 × HASH\_SIZE)  | Par de hashes leído en una ronda de minería     |
| **NUM\_SCOOPS** | 4096 (2¹²)             | Scoops por nonce; uno seleccionado por ronda    |
| **NONCE\_SIZE** | 262144 B (256 KiB)     | Todos los scoops de un nonce (unidad mínima PoC1/PoC2) |
| **WARP\_SIZE**  | 1073741824 B (1 GiB)   | Unidad mínima en PoCX                           |

### Disposición de archivo de parcela optimizada para SIMD

PoCX implementa un patrón de acceso a nonces consciente de SIMD que permite el procesamiento vectorizado de múltiples nonces simultáneamente. Se basa en conceptos de la [investigación de optimización POC2×16](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) para maximizar el rendimiento de memoria y la eficiencia SIMD.

---

#### Disposición secuencial tradicional

Almacenamiento secuencial de nonces:

```
[Nonce 0: Datos Scoop] [Nonce 1: Datos Scoop] [Nonce 2: Datos Scoop] ...
```

Ineficiencia SIMD: Cada carril SIMD necesita la misma palabra a través de nonces:

```
Palabra 0 de Nonce 0 -> desplazamiento 0
Palabra 0 de Nonce 1 -> desplazamiento 512
Palabra 0 de Nonce 2 -> desplazamiento 1024
...
```

El acceso disperso-recolector reduce el rendimiento.

---

#### Disposición optimizada para SIMD de PoCX

PoCX almacena **posiciones de palabras a través de 16 nonces** de forma contigua:

```
Línea de caché (64 bytes):

Pal0_N0 Pal0_N1 Pal0_N2 ... Pal0_N15
Pal1_N0 Pal1_N1 Pal1_N2 ... Pal1_N15
...
```

**Diagrama ASCII**

```
Disposición tradicional:

Nonce0: [P0][P1][P2][P3]...
Nonce1: [P0][P1][P2][P3]...
Nonce2: [P0][P1][P2][P3]...

Disposición PoCX:

Pal0: [N0][N1][N2][N3]...[N15]
Pal1: [N0][N1][N2][N3]...[N15]
Pal2: [N0][N1][N2][N3]...[N15]
```

---

#### Beneficios de acceso a memoria

- Una línea de caché suministra todos los carriles SIMD.
- Elimina operaciones de dispersión-recolección.
- Reduce fallos de caché.
- Acceso a memoria completamente secuencial para cómputo vectorizado.
- Las GPUs también se benefician de la alineación a 16 nonces, maximizando la eficiencia de caché.

---

#### Escalado SIMD

| SIMD       | Ancho de vector* | Nonces | Ciclos de procesamiento por línea de caché |
|------------|------------------|--------|--------------------------------------------|
| SSE2/AVX   | 128 bits         | 4      | 4 ciclos                                   |
| AVX2       | 256 bits         | 8      | 2 ciclos                                   |
| AVX512     | 512 bits         | 16     | 1 ciclo                                    |

\* Para operaciones con enteros

---



## Escalado de prueba de trabajo

### Niveles de escalado
- **X0**: Nonces base sin codificación XOR-transposición (teórico, no usado para minería)
- **X1**: Línea base XOR-transposición, primer formato endurecido (1× trabajo)
- **X2**: 2× trabajo X1 (XOR a través de 2 warps)
- **X3**: 4× trabajo X1 (XOR a través de 4 warps)
- **…**
- **Xn**: 2^(n-1) × trabajo X1 incrustado

### Beneficios
- **Dificultad PoW ajustable**: Aumenta los requisitos computacionales para seguir el ritmo de hardware más rápido
- **Longevidad del formato**: Permite escalado flexible de la dificultad de minería a lo largo del tiempo

### Actualización de parcelas / Compatibilidad retroactiva

Cuando la red aumenta la escala PoW (Prueba de Trabajo) en 1, las parcelas existentes requieren una actualización para mantener el mismo tamaño efectivo de parcela. Esencialmente, ahora necesitas el doble de PoW en tus archivos de parcela para lograr la misma contribución a tu cuenta.

La buena noticia es que el PoW que ya has completado al crear tus archivos de parcela no se pierde; simplemente necesitas añadir PoW adicional a los archivos existentes. No es necesario volver a graficar.

Alternativamente, puedes continuar usando tus parcelas actuales sin actualizar, pero ten en cuenta que ahora solo contribuirán el 50% de su tamaño efectivo anterior hacia tu cuenta. Tu software de minería puede escalar un archivo de parcela al vuelo.

## Comparación con formatos heredados

| Característica | POC1 | POC2 | PoCX |
|----------------|------|------|------|
| Distribución PoW | Con fallas | Corregida | Corregida |
| Resistencia XOR-transposición | Vulnerable | Vulnerable | Corregida |
| Optimización SIMD | Ninguna | Ninguna | Avanzada |
| Optimización GPU | Ninguna | Ninguna | Optimizada |
| Prueba de trabajo escalable | Ninguna | Ninguna | Sí |
| Soporte de semilla | Ninguno | Ninguno | Sí |

El formato PoCX representa el estado del arte actual en formatos de parcela de Prueba de Capacidad, abordando todas las vulnerabilidades conocidas mientras proporciona mejoras significativas de rendimiento para hardware moderno.

## Referencias y lecturas adicionales

- **Antecedentes POC1/POC2**: [Panorama de minería Burstcoin](https://www.burstcoin.community/burstcoin-mining/) - Guía completa de formatos tradicionales de minería de Prueba de Capacidad
- **Investigación POC2×16**: [Anuncio CIP: POC2×16 - Un nuevo formato de parcela optimizado](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Investigación original de optimización SIMD que inspiró PoCX
- **Algoritmo hash Shabal**: [El proyecto Saphir: Shabal, una propuesta para la competencia de algoritmos hash criptográficos del NIST](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Especificación técnica del algoritmo Shabal256 usado en minería PoC

---

[← Anterior: Introducción](1-introduction.md) | [Tabla de contenidos](index.md) | [Siguiente: Consenso y minería →](3-consensus-and-mining.md)
