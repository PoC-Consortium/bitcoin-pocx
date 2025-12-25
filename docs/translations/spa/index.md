# Documentación Técnica de Bitcoin-PoCX

**Versión**: 1.0
**Base de Bitcoin Core**: v30.0
**Estado**: Fase de Testnet
**Última actualización**: 2025-12-25

---

## Acerca de esta documentación

Esta es la documentación técnica completa de Bitcoin-PoCX, una integración de Bitcoin Core que añade soporte para el consenso de Prueba de Capacidad de Nueva Generación (PoCX). La documentación está organizada como una guía navegable con capítulos interconectados que cubren todos los aspectos del sistema.

**Audiencias objetivo**:
- **Operadores de nodos**: Capítulos 1, 5, 6, 8
- **Mineros**: Capítulos 2, 3, 7
- **Desarrolladores**: Todos los capítulos
- **Investigadores**: Capítulos 3, 4, 5

Traducciones: [Alemán](translations/deu/index.md)
---

## Tabla de contenidos

### Parte I: Fundamentos

**[Capítulo 1: Introducción y panorama general](1-introduction.md)**
Visión general del proyecto, arquitectura, filosofía de diseño, características principales y diferencias entre PoCX y la Prueba de Trabajo.

**[Capítulo 2: Formato de archivos de parcela](2-plot-format.md)**
Especificación completa del formato de parcelas PoCX, incluyendo optimización SIMD, escalado de prueba de trabajo y evolución desde POC1/POC2.

**[Capítulo 3: Consenso y minería](3-consensus-and-mining.md)**
Especificación técnica completa del mecanismo de consenso PoCX: estructura de bloques, firmas de generación, ajuste de objetivo base, proceso de minería, validación y algoritmo de flexión temporal.

---

### Parte II: Características avanzadas

**[Capítulo 4: Sistema de asignación de forjado](4-forging-assignments.md)**
Arquitectura exclusiva OP_RETURN para delegar derechos de forjado: estructura de transacciones, diseño de base de datos, máquina de estados, manejo de reorganizaciones e interfaz RPC.

**[Capítulo 5: Sincronización temporal y seguridad](5-timing-security.md)**
Tolerancia a la deriva del reloj, mecanismo de forjado defensivo, protección contra manipulación del reloj y consideraciones de seguridad relacionadas con la temporización.

**[Capítulo 6: Parámetros de red](6-network-parameters.md)**
Configuración de chainparams, bloque génesis, parámetros de consenso, reglas de coinbase, escalado dinámico y modelo económico.

---

### Parte III: Uso e integración

**[Capítulo 7: Referencia de interfaz RPC](7-rpc-reference.md)**
Referencia completa de comandos RPC para minería, asignaciones y consultas de blockchain. Esencial para la integración de mineros y pools.

**[Capítulo 8: Guía de cartera y GUI](8-wallet-guide.md)**
Guía de usuario para la cartera Qt de Bitcoin-PoCX: diálogo de asignación de forjado, historial de transacciones, configuración de minería y solución de problemas.

---

## Navegación rápida

### Para operadores de nodos
→ Comience con el [Capítulo 1: Introducción](1-introduction.md)
→ Luego revise el [Capítulo 6: Parámetros de red](6-network-parameters.md)
→ Configure la minería con el [Capítulo 8: Guía de cartera](8-wallet-guide.md)

### Para mineros
→ Comprenda el [Capítulo 2: Formato de parcelas](2-plot-format.md)
→ Aprenda el proceso en el [Capítulo 3: Consenso y minería](3-consensus-and-mining.md)
→ Integre usando el [Capítulo 7: Referencia RPC](7-rpc-reference.md)

### Para operadores de pools
→ Revise el [Capítulo 4: Asignaciones de forjado](4-forging-assignments.md)
→ Estudie el [Capítulo 7: Referencia RPC](7-rpc-reference.md)
→ Implemente usando los RPC de asignación y submit_nonce

### Para desarrolladores
→ Lea todos los capítulos secuencialmente
→ Consulte los archivos de implementación referenciados
→ Examine la estructura del directorio `src/pocx/`
→ Compile versiones con [GUIX](../bitcoin/contrib/guix/README.md)

---

## Convenciones de la documentación

**Referencias a archivos**: Los detalles de implementación referencian archivos fuente como `ruta/al/archivo.cpp:línea`

**Integración de código**: Todos los cambios están marcados con `#ifdef ENABLE_POCX`

**Referencias cruzadas**: Los capítulos enlazan a secciones relacionadas usando enlaces markdown relativos

**Nivel técnico**: La documentación asume familiaridad con Bitcoin Core y desarrollo en C++

---

## Compilación

### Compilación de desarrollo

```bash
# Clonar con submódulos
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Configurar con PoCX habilitado
cmake -B build -DENABLE_POCX=ON

# Compilar
cmake --build build -j$(nproc)
```

**Variantes de compilación**:
```bash
# Con GUI Qt
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Compilación de depuración
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Dependencias**: Dependencias estándar de compilación de Bitcoin Core. Consulte la [documentación de compilación de Bitcoin Core](https://github.com/bitcoin/bitcoin/tree/master/doc#building) para requisitos específicos de cada plataforma.

### Compilaciones de lanzamiento

Para binarios reproducibles de lanzamiento, use el sistema de compilación GUIX: Consulte [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Recursos adicionales

**Repositorio**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**Framework central PoCX**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Proyectos relacionados**:
- Graficador: Basado en [engraver](https://github.com/PoC-Consortium/engraver)
- Minero: Basado en [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Cómo leer esta documentación

**Lectura secuencial**: Los capítulos están diseñados para leerse en orden, construyendo sobre conceptos anteriores.

**Lectura de referencia**: Use la tabla de contenidos para saltar directamente a temas específicos. Cada capítulo es autónomo con referencias cruzadas a material relacionado.

**Navegación en el navegador**: Abra `index.md` en un visor de markdown o navegador. Todos los enlaces internos son relativos y funcionan sin conexión.

**Exportación a PDF**: Esta documentación puede concatenarse en un solo PDF para lectura sin conexión.

---

## Estado del proyecto

**Funcionalidad completa**: Todas las reglas de consenso, minería, asignaciones y características de cartera implementadas.

**Documentación completa**: Los 8 capítulos completos y verificados contra el código fuente.

**Testnet activa**: Actualmente en fase de testnet para pruebas de la comunidad.

---

## Contribuir

Las contribuciones a la documentación son bienvenidas. Por favor mantenga:
- Precisión técnica sobre verbosidad
- Explicaciones breves y directas
- Sin código ni pseudocódigo en la documentación (referencie archivos fuente en su lugar)
- Solo lo implementado (sin características especulativas)

---

## Licencia

Bitcoin-PoCX hereda la licencia MIT de Bitcoin Core. Consulte `COPYING` en la raíz del repositorio.

Atribución del framework central PoCX documentada en el [Capítulo 2: Formato de parcelas](2-plot-format.md).

---

**Comenzar a leer**: [Capítulo 1: Introducción y panorama general →](1-introduction.md)
