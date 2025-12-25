# Bitcoin-PoCX: Consenso energéticamente eficiente para Bitcoin Core

**Versión**: 2.0 Borrador
**Fecha**: Diciembre 2025
**Organización**: Proof of Capacity Consortium

---

## Resumen

El consenso de Prueba de Trabajo (PoW) de Bitcoin proporciona seguridad robusta pero consume energía sustancial debido al cálculo continuo de hashes en tiempo real. Presentamos Bitcoin-PoCX, una bifurcación de Bitcoin que reemplaza PoW con Prueba de Capacidad (PoC), donde los mineros precomputan y almacenan grandes conjuntos de hashes almacenados en disco durante el graficado y posteriormente minan realizando búsquedas ligeras en lugar de hashing continuo. Al trasladar la computación de la fase de minería a una fase de graficado única, Bitcoin-PoCX reduce drásticamente el consumo de energía mientras permite la minería con hardware genérico, bajando la barrera de participación y mitigando las presiones de centralización inherentes en el PoW dominado por ASICs, todo mientras preserva las suposiciones de seguridad y el comportamiento económico de Bitcoin.

Nuestra implementación introduce varias innovaciones clave:
(1) Un formato de parcela endurecido que elimina todos los ataques conocidos de compensación tiempo-memoria en sistemas PoC existentes, asegurando que el poder de minería efectivo permanezca estrictamente proporcional a la capacidad de almacenamiento comprometida;
(2) El algoritmo de flexión temporal, que transforma las distribuciones de plazos de exponencial a chi-cuadrado, reduciendo la varianza del tiempo de bloque sin alterar la media;
(3) Un mecanismo de asignación de forjado basado en OP_RETURN que permite minería en pool sin custodia; y
(4) Escalado de compresión dinámico, que aumenta la dificultad de generación de parcelas en alineación con los programas de halving para mantener márgenes de seguridad a largo plazo a medida que mejora el hardware.

Bitcoin-PoCX mantiene la arquitectura de Bitcoin Core a través de modificaciones mínimas marcadas con banderas de características, aislando la lógica PoC del código de consenso existente. El sistema preserva la política monetaria de Bitcoin apuntando a un intervalo de bloque de 120 segundos y ajustando el subsidio de bloque a 10 BTC. El subsidio reducido compensa el aumento de cinco veces en la frecuencia de bloques, manteniendo la tasa de emisión a largo plazo alineada con el programa original de Bitcoin y manteniendo el suministro máximo de ~21 millones.

---

## 1. Introducción

### 1.1 Motivación

El consenso de Prueba de Trabajo (PoW) de Bitcoin ha demostrado ser seguro durante más de una década, pero a un costo significativo: los mineros deben gastar continuamente recursos computacionales, resultando en un alto consumo de energía. Más allá de las preocupaciones de eficiencia, existe una motivación más amplia: explorar mecanismos de consenso alternativos que mantengan la seguridad mientras reducen la barrera de participación. PoC permite que prácticamente cualquier persona con hardware de almacenamiento genérico mine efectivamente, reduciendo las presiones de centralización vistas en la minería PoW dominada por ASICs.

La Prueba de Capacidad (PoC) logra esto derivando el poder de minería del compromiso de almacenamiento en lugar de la computación continua. Los mineros precomputan grandes conjuntos de hashes almacenados en disco (parcelas) durante una fase de graficado única. La minería consiste entonces en búsquedas ligeras, reduciendo drásticamente el uso de energía mientras preserva las suposiciones de seguridad del consenso basado en recursos.

### 1.2 Integración con Bitcoin Core

Bitcoin-PoCX integra el consenso PoC en Bitcoin Core en lugar de crear una nueva blockchain. Este enfoque aprovecha la seguridad probada de Bitcoin Core, su pila de red madura y las herramientas ampliamente adoptadas, mientras mantiene las modificaciones mínimas y marcadas con banderas de características. La lógica PoC está aislada del código de consenso existente, asegurando que la funcionalidad central (validación de bloques, operaciones de cartera, formatos de transacción) permanezca en gran parte sin cambios.

### 1.3 Objetivos de diseño

**Seguridad**: Retener robustez equivalente a Bitcoin; los ataques requieren capacidad de almacenamiento mayoritaria.

**Eficiencia**: Reducir la carga computacional continua a niveles de E/S de disco.

**Accesibilidad**: Permitir minería con hardware genérico, reduciendo barreras de entrada.

**Integración mínima**: Introducir consenso PoC con huella de modificación mínima.

---

## 2. Antecedentes: Prueba de Capacidad

### 2.1 Historia

La Prueba de Capacidad (PoC) fue introducida por Burstcoin en 2014 como una alternativa energéticamente eficiente a la Prueba de Trabajo (PoW). Burstcoin demostró que el poder de minería podía derivarse del almacenamiento comprometido en lugar del hashing continuo en tiempo real: los mineros precomputaban grandes conjuntos de datos ("parcelas") una vez y luego minaban leyendo pequeñas porciones fijas de ellos.

Las primeras implementaciones de PoC demostraron que el concepto era viable pero también revelaron que el formato de parcela y la estructura criptográfica son críticos para la seguridad. Varias compensaciones tiempo-memoria permitían a los atacantes minar efectivamente con menos almacenamiento que los participantes honestos. Esto destacó que la seguridad de PoC depende del diseño de las parcelas, no meramente del uso del almacenamiento como recurso.

El legado de Burstcoin estableció PoC como un mecanismo de consenso práctico y proporcionó la base sobre la cual PoCX se construye.

### 2.2 Conceptos fundamentales

La minería PoC se basa en grandes archivos de parcela precomputados almacenados en disco. Estas parcelas contienen "computación congelada": el hashing costoso se realiza una vez durante el graficado, y la minería consiste entonces en lecturas ligeras de disco y verificación simple. Los elementos centrales incluyen:

**Nonce:**
La unidad básica de datos de parcela. Cada nonce contiene 4096 scoops (256 KiB en total) generados vía Shabal256 desde la dirección del minero y el índice del nonce.

**Scoop:**
Un segmento de 64 bytes dentro de un nonce. Para cada bloque, la red selecciona determinísticamente un índice de scoop (0-4095) basado en la firma de generación del bloque anterior. Solo este scoop por nonce debe ser leído.

**Firma de generación:**
Un valor de 256 bits derivado del bloque anterior. Proporciona entropía para la selección de scoop y previene que los mineros predigan futuros índices de scoop.

**Warp:**
Un grupo estructural de 4096 nonces (1 GiB). Los warps son la unidad relevante para formatos de parcela resistentes a compresión.

### 2.3 Proceso de minería y pipeline de calidad

La minería PoC consiste en un paso de graficado único y una rutina ligera por bloque:

**Configuración única:**
- Generación de parcela: Computar nonces vía Shabal256 y escribirlos en disco.

**Minería por bloque:**
- Selección de scoop: Determinar el índice de scoop desde la firma de generación.
- Escaneo de parcela: Leer ese scoop de todos los nonces en las parcelas del minero.

**Pipeline de calidad:**
- Calidad cruda: Hashear cada scoop con la firma de generación usando Shabal256Lite para obtener un valor de calidad de 64 bits (menor es mejor).
- Plazo: Convertir la calidad en un plazo usando el objetivo base (un parámetro ajustado por dificultad que asegura que la red alcance su intervalo de bloque objetivo): `plazo = calidad / objetivo_base`
- Plazo flexionado: Aplicar la transformación de flexión temporal para reducir la varianza mientras se preserva el tiempo de bloque esperado.

**Forjado de bloque:**
El minero con el plazo (flexionado) más corto forja el siguiente bloque una vez que ese tiempo ha transcurrido.

A diferencia de PoW, casi toda la computación ocurre durante el graficado; la minería activa está principalmente limitada por disco y consume muy poca energía.

### 2.4 Vulnerabilidades conocidas en sistemas anteriores

**Fallo de distribución POC1:**
El formato POC1 original de Burstcoin exhibía un sesgo estructural: los scoops de bajo índice eran significativamente más baratos de recomputar al vuelo que los de alto índice. Esto introdujo una compensación tiempo-memoria no uniforme, permitiendo a los atacantes reducir el almacenamiento requerido para esos scoops y rompiendo la suposición de que todos los datos precomputados eran igualmente costosos.

**Ataque de compresión XOR (POC2):**
En POC2, un atacante puede tomar cualquier conjunto de 8192 nonces y particionarlos en dos bloques de 4096 nonces (A y B). En lugar de almacenar ambos bloques, el atacante almacena solo una estructura derivada: `A ⊕ transponer(B)`, donde la transposición intercambia los índices de scoop y nonce; el scoop S del nonce N en el bloque B se convierte en el scoop N del nonce S.

Durante la minería, cuando se necesita el scoop S del nonce N, el atacante lo reconstruye:
1. Leyendo el valor XOR almacenado en la posición (S, N)
2. Computando el nonce N del bloque A para obtener el scoop S
3. Computando el nonce S del bloque B para obtener el scoop N transpuesto
4. Aplicando XOR a los tres valores para recuperar el scoop original de 64 bytes

Esto reduce el almacenamiento en un 50%, mientras requiere solo dos cómputos de nonce por búsqueda, un costo muy por debajo del umbral necesario para forzar la precomputación completa. El ataque es viable porque computar una fila (un nonce, 4096 scoops) es barato, mientras que computar una columna (un solo scoop a través de 4096 nonces) requeriría regenerar todos los nonces. La estructura de transposición expone este desequilibrio.

Esto demostró la necesidad de un formato de parcela que prevenga tal recombinación estructurada y elimine la compensación tiempo-memoria subyacente. La Sección 3.3 describe cómo PoCX aborda y resuelve esta debilidad.

### 2.5 Transición a PoCX

Las limitaciones de los sistemas PoC anteriores dejaron claro que la minería de almacenamiento segura, justa y descentralizada depende de estructuras de parcela cuidadosamente diseñadas. Bitcoin-PoCX aborda estos problemas con un formato de parcela endurecido, distribución de plazos mejorada y mecanismos para minería en pool descentralizada, descritos en la siguiente sección.

---

## 3. Formato de parcela PoCX

### 3.1 Construcción de nonce base

Un nonce es una estructura de datos de 256 KiB derivada determinísticamente de tres parámetros: una carga de dirección de 20 bytes, una semilla de 32 bytes y un índice de nonce de 64 bits.

La construcción comienza combinando estas entradas y hasheándolas con Shabal256 para producir un hash inicial. Este hash sirve como punto de partida para un proceso de expansión iterativo: Shabal256 se aplica repetidamente, con cada paso dependiendo de los datos previamente generados, hasta que se llena el buffer completo de 256 KiB. Este proceso encadenado representa el trabajo computacional realizado durante el graficado.

Un paso final de difusión hashea el buffer completado y aplica XOR del resultado a través de todos los bytes. Esto asegura que el buffer completo haya sido computado y que los mineros no puedan acortar el cálculo. Luego se aplica la reorganización POC2, intercambiando las mitades inferior y superior de cada scoop para garantizar que todos los scoops requieran esfuerzo computacional equivalente.

El nonce final consiste en 4096 scoops de 64 bytes cada uno y forma la unidad fundamental usada en la minería.

### 3.2 Disposición de parcela alineada para SIMD

Para maximizar el rendimiento en hardware moderno, PoCX organiza los datos de nonce en disco para facilitar el procesamiento vectorizado. En lugar de almacenar cada nonce secuencialmente, PoCX alinea las palabras correspondientes de 4 bytes a través de múltiples nonces consecutivos de forma contigua. Esto permite que una sola obtención de memoria proporcione datos para todos los carriles SIMD, minimizando los fallos de caché y eliminando la sobrecarga de dispersión-recolección.

```
Disposición tradicional:
Nonce0: [P0][P1][P2][P3]...
Nonce1: [P0][P1][P2][P3]...
Nonce2: [P0][P1][P2][P3]...

Disposición SIMD PoCX:
Pal0: [N0][N1][N2]...[N15]
Pal1: [N0][N1][N2]...[N15]
Pal2: [N0][N1][N2]...[N15]
```

Esta disposición beneficia tanto a los mineros de CPU como de GPU, permitiendo evaluación de scoop de alto rendimiento y paralelizada mientras retiene un patrón de acceso escalar simple para la verificación de consenso. Asegura que la minería esté limitada por el ancho de banda de almacenamiento en lugar de la computación de CPU, manteniendo la naturaleza de bajo consumo de la Prueba de Capacidad.

### 3.3 Estructura de warp y codificación XOR-transposición

Un warp es la unidad fundamental de almacenamiento en PoCX, consistiendo en 4096 nonces (1 GiB). El formato sin comprimir, referido como X0, contiene nonces base exactamente como los produce la construcción en la Sección 3.1.

**Codificación XOR-transposición (X1)**

Para eliminar las compensaciones tiempo-memoria estructurales presentes en sistemas PoC anteriores, PoCX deriva un formato de minería endurecido, X1, aplicando codificación XOR-transposición a pares de warps X0.

Para construir el scoop S del nonce N en un warp X1:

1. Tomar el scoop S del nonce N del primer warp X0 (posición directa)
2. Tomar el scoop N del nonce S del segundo warp X0 (posición transpuesta)
3. Aplicar XOR a los dos valores de 64 bytes para obtener el scoop X1

El paso de transposición intercambia los índices de scoop y nonce. En términos matriciales, donde las filas representan scoops y las columnas representan nonces, combina el elemento en la posición (S, N) del primer warp con el elemento en (N, S) del segundo.

**Por qué esto elimina la superficie de ataque de compresión**

La XOR-transposición entrelaza cada scoop con una fila completa y una columna completa de los datos X0 subyacentes. Recuperar un solo scoop X1 requiere por tanto acceso a datos que abarcan los 4096 índices de scoop. Cualquier intento de computar datos faltantes requeriría regenerar 4096 nonces completos, en lugar de un solo nonce, eliminando la estructura de costos asimétrica explotada por el ataque XOR para POC2 (Sección 2.4).

Como resultado, almacenar el warp X1 completo se convierte en la única estrategia computacionalmente viable para los mineros, cerrando la compensación tiempo-memoria explotada en diseños anteriores.

### 3.4 Disposición en disco

Los archivos de parcela PoCX consisten en muchos warps X1 consecutivos. Para maximizar la eficiencia operacional durante la minería, los datos dentro de cada archivo se organizan por scoop: todos los datos del scoop 0 de cada warp se almacenan secuencialmente, seguidos por todos los datos del scoop 1, y así sucesivamente, hasta el scoop 4095.

Este **ordenamiento secuencial por scoop** permite a los mineros leer los datos completos requeridos para un scoop seleccionado en un solo acceso de disco secuencial, minimizando los tiempos de búsqueda y maximizando el rendimiento en dispositivos de almacenamiento genéricos.

Combinado con la codificación XOR-transposición de la Sección 3.3, esta disposición asegura que el archivo esté tanto **estructuralmente endurecido** como **operacionalmente eficiente**: el ordenamiento secuencial de scoops soporta E/S de disco óptima, mientras que las disposiciones de memoria alineadas para SIMD (ver Sección 3.2) permiten evaluación de scoop de alto rendimiento y paralelizada.

### 3.5 Escalado de prueba de trabajo (Xn)

PoCX implementa precomputación escalable a través del concepto de niveles de escalado, denotados Xn, para adaptarse a la evolución del rendimiento del hardware. El formato X1 de línea base representa la primera estructura de warp endurecida con XOR-transposición.

Cada nivel de escalado Xn aumenta la prueba de trabajo incrustada en cada warp exponencialmente relativo a X1: el trabajo requerido en el nivel Xn es 2^(n-1) veces el de X1. Transicionar de Xn a Xn+1 es operacionalmente equivalente a aplicar XOR a través de pares de warps adyacentes, incrustando incrementalmente más prueba de trabajo sin cambiar el tamaño de parcela subyacente.

Los archivos de parcela existentes creados en niveles de escalado más bajos aún pueden usarse para minería, pero contribuyen proporcionalmente menos trabajo hacia la generación de bloques, reflejando su menor prueba de trabajo incrustada. Este mecanismo asegura que las parcelas PoCX permanezcan seguras, flexibles y económicamente equilibradas a lo largo del tiempo.

### 3.6 Funcionalidad de semilla

El parámetro de semilla permite múltiples parcelas no superpuestas por dirección sin coordinación manual.

**Problema (POC2)**: Los mineros tenían que rastrear manualmente los rangos de nonce a través de los archivos de parcela para evitar superposición. Los nonces superpuestos desperdician almacenamiento sin aumentar el poder de minería.

**Solución**: Cada par `(dirección, semilla)` define un espacio de claves independiente. Las parcelas con diferentes semillas nunca se superponen, independientemente de los rangos de nonce. Los mineros pueden crear parcelas libremente sin coordinación.

---

## 4. Consenso de Prueba de Capacidad

PoCX extiende el consenso Nakamoto de Bitcoin con un mecanismo de prueba limitado por almacenamiento. En lugar de gastar energía en hashing repetido, los mineros comprometen grandes cantidades de datos precomputados (parcelas) en disco. Durante la generación de bloques, deben localizar una pequeña porción impredecible de estos datos y transformarla en una prueba. El minero que proporciona la mejor prueba dentro de la ventana de tiempo esperada gana el derecho de forjar el siguiente bloque.

Este capítulo describe cómo PoCX estructura los metadatos del bloque, deriva la impredecibilidad y transforma el almacenamiento estático en un mecanismo de consenso seguro y de baja varianza.

### 4.1 Estructura de bloque

PoCX retiene el encabezado de bloque de estilo Bitcoin familiar pero introduce campos de consenso adicionales requeridos para la minería basada en capacidad. Estos campos colectivamente vinculan el bloque a la parcela almacenada del minero, la dificultad de la red y la entropía criptográfica que define cada desafío de minería.

A alto nivel, un bloque PoCX contiene: la altura del bloque, registrada explícitamente para simplificar la validación contextual; la firma de generación, una fuente de entropía fresca que vincula cada bloque a su predecesor; el objetivo base, representando la dificultad de la red en forma inversa (valores más altos corresponden a minería más fácil); la prueba PoCX, identificando la parcela del minero, el nivel de compresión usado durante el graficado, el nonce seleccionado y la calidad derivada de él; y una clave de firma y firma, demostrando control de la capacidad usada para forjar el bloque (o de una clave de forjado asignada).

La prueba incrusta toda la información relevante para el consenso que los validadores necesitan para recomputar el desafío, verificar el scoop elegido y confirmar la calidad resultante. Al extender en lugar de rediseñar la estructura del bloque, PoCX permanece conceptualmente alineado con Bitcoin mientras habilita una fuente fundamentalmente diferente de trabajo de minería.

### 4.2 Cadena de firma de generación

La firma de generación proporciona la impredecibilidad requerida para la minería segura de Prueba de Capacidad. Cada bloque deriva su firma de generación de la firma y el firmante del bloque anterior, asegurando que los mineros no puedan anticipar futuros desafíos o precomputar regiones ventajosas de parcela:

`firmaGeneración[n] = SHA256(firmaGeneración[n-1] || pubkey_minero[n-1])`

Esto produce una secuencia de valores de entropía criptográficamente fuertes y dependientes del minero. Debido a que la clave pública de un minero es desconocida hasta que se publica el bloque anterior, ningún participante puede predecir futuras selecciones de scoop. Esto previene la precomputación selectiva o el graficado estratégico y asegura que cada bloque introduzca trabajo de minería genuinamente fresco.

### 4.3 Proceso de forjado

La minería en PoCX consiste en transformar datos almacenados en una prueba impulsada enteramente por la firma de generación. Aunque el proceso es determinista, la impredecibilidad de la firma asegura que los mineros no puedan prepararse de antemano y deban acceder repetidamente a sus parcelas almacenadas.

**Derivación del desafío (selección de scoop):** El minero hashea la firma de generación actual con la altura del bloque para obtener un índice de scoop en el rango 0-4095. Este índice determina qué segmento de 64 bytes de cada nonce almacenado participa en la prueba. Debido a que la firma de generación depende del firmante del bloque anterior, la selección de scoop se conoce solo en el momento de la publicación del bloque.

**Evaluación de prueba (cálculo de calidad):** Para cada nonce en una parcela, el minero recupera el scoop seleccionado y lo hashea junto con la firma de generación para obtener una calidad, un valor de 64 bits cuya magnitud determina la competitividad del minero. Una calidad más baja corresponde a una mejor prueba.

**Formación de plazo (flexión temporal):** El plazo crudo es proporcional a la calidad e inversamente proporcional al objetivo base. En diseños PoC heredados, estos plazos seguían una distribución exponencial altamente sesgada, produciendo retrasos de cola larga que no proporcionaban seguridad adicional. PoCX transforma el plazo crudo usando flexión temporal (Sección 4.4), reduciendo la varianza y asegurando intervalos de bloque predecibles. Una vez que el plazo flexionado expira, el minero forja un bloque incrustando la prueba y firmándolo con la clave de forjado efectiva.

### 4.4 Flexión temporal

La Prueba de Capacidad produce plazos distribuidos exponencialmente. Después de un corto período (típicamente unas pocas docenas de segundos), cada minero ya ha identificado su mejor prueba, y cualquier tiempo de espera adicional contribuye solo latencia, no seguridad.

La flexión temporal reformula la distribución aplicando una transformación de raíz cúbica:

`plazo_flexionado = escala × (calidad / objetivo_base)^(1/3)`

El factor de escala preserva el tiempo de bloque esperado (120 segundos) mientras reduce dramáticamente la varianza. Los plazos cortos se expanden, mejorando la propagación de bloques y la seguridad de la red. Los plazos largos se comprimen, previniendo que los valores atípicos retrasen la cadena.

![Distribuciones de tiempo de bloque](blocktime_distributions.svg)

La flexión temporal mantiene el contenido informacional de la prueba subyacente. No modifica la competitividad entre mineros; solo reasigna el tiempo de espera para producir intervalos de bloque más suaves y predecibles. La implementación usa aritmética de punto fijo (formato Q42) y enteros de 256 bits para asegurar resultados deterministas en todas las plataformas.

### 4.5 Ajuste de dificultad

PoCX regula la producción de bloques usando el objetivo base, una medida de dificultad inversa. El tiempo de bloque esperado es proporcional a la relación `calidad / objetivo_base`, por lo que aumentar el objetivo base acelera la creación de bloques mientras que disminuirlo desacelera la cadena.

La dificultad se ajusta cada bloque usando el tiempo medido entre bloques recientes comparado con el intervalo objetivo. Este ajuste frecuente es necesario porque la capacidad de almacenamiento puede añadirse o eliminarse rápidamente, a diferencia del poder de hash de Bitcoin, que cambia más lentamente.

El ajuste sigue dos restricciones guía: **Gradualidad**, los cambios por bloque están acotados (±20% máximo) para evitar oscilaciones o manipulación; **Endurecimiento**, el objetivo base no puede exceder su valor del génesis, previniendo que la red alguna vez baje la dificultad por debajo de las suposiciones de seguridad originales.

### 4.6 Validez de bloque

Un bloque en PoCX es válido cuando presenta una prueba verificable derivada de almacenamiento consistente con el estado de consenso. Los validadores recomputan independientemente la selección de scoop, derivan la calidad esperada del nonce enviado y los metadatos de parcela, aplican la transformación de flexión temporal y confirman que el minero era elegible para forjar el bloque en el tiempo declarado.

Específicamente, un bloque válido requiere: el plazo ha expirado desde el bloque padre; la calidad enviada coincide con la calidad computada para la prueba; el nivel de escalado cumple el mínimo de la red; la firma de generación coincide con el valor esperado; el objetivo base coincide con el valor esperado; la firma del bloque proviene del firmante efectivo; y el coinbase paga a la dirección del firmante efectivo.

---

## 5. Asignaciones de forjado

### 5.1 Motivación

Las asignaciones de forjado permiten a los propietarios de parcelas delegar autoridad de forjado de bloques sin nunca renunciar a la propiedad de sus parcelas. Este mecanismo permite minería en pool y configuraciones de almacenamiento en frío mientras preserva las garantías de seguridad de PoCX.

En la minería en pool, los propietarios de parcelas pueden autorizar a un pool a forjar bloques en su nombre. El pool ensambla bloques y distribuye recompensas, pero nunca obtiene custodia sobre las parcelas mismas. La delegación es reversible en cualquier momento, y los propietarios de parcelas permanecen libres de dejar un pool o cambiar configuraciones sin volver a graficar.

Las asignaciones también soportan una separación limpia entre claves frías y calientes. La clave privada que controla la parcela puede permanecer fuera de línea, mientras que una clave de forjado separada, almacenada en una máquina en línea, produce bloques. Un compromiso de la clave de forjado por tanto compromete solo la autoridad de forjado, no la propiedad. La parcela permanece segura y la asignación puede ser revocada, cerrando la brecha de seguridad inmediatamente.

Las asignaciones de forjado proporcionan así flexibilidad operacional mientras mantienen el principio de que el control sobre la capacidad almacenada nunca debe transferirse a intermediarios.

### 5.2 Protocolo de asignación

Las asignaciones se declaran a través de transacciones OP_RETURN para evitar el crecimiento innecesario del conjunto UTXO. Una transacción de asignación especifica la dirección de parcela y la dirección de forjado que está autorizada para producir bloques usando la capacidad de esa parcela. Una transacción de revocación contiene solo la dirección de parcela. En ambos casos, el propietario de la parcela demuestra control firmando la entrada de gasto de la transacción.

Cada asignación progresa a través de una secuencia de estados bien definidos (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Después de que una transacción de asignación confirma, el sistema entra en una fase de activación corta. Este retardo (30 bloques, aproximadamente una hora) asegura estabilidad durante carreras de bloques y previene el cambio rápido adversarial de identidades de forjado. Una vez que este período de activación expira, la asignación se vuelve activa y permanece así hasta que el propietario de la parcela emite una revocación.

Las revocaciones transicionan a un período de retardo más largo de 720 bloques, aproximadamente un día. Durante este tiempo, la dirección de forjado anterior permanece activa. Este retardo más largo proporciona estabilidad operacional para los pools, previniendo el "salto de asignación" estratégico y dando a los proveedores de infraestructura suficiente certeza para operar eficientemente. Después de que el retardo de revocación expira, la revocación se completa, y el propietario de la parcela es libre de designar una nueva clave de forjado.

El estado de asignación se mantiene en una estructura de capa de consenso paralela al conjunto UTXO y soporta datos de deshacer para el manejo seguro de reorganizaciones de cadena.

### 5.3 Reglas de validación

Para cada bloque, los validadores determinan el firmante efectivo, la dirección que debe firmar el bloque y recibir la recompensa de coinbase. Este firmante depende únicamente del estado de asignación a la altura del bloque.

Si no existe asignación o la asignación aún no ha completado su fase de activación, el propietario de la parcela permanece como el firmante efectivo. Una vez que una asignación se vuelve activa, la dirección de forjado asignada debe firmar. Durante la revocación, la dirección de forjado continúa firmando hasta que el retardo de revocación expira. Solo entonces la autoridad regresa al propietario de la parcela.

Los validadores hacen cumplir que la firma del bloque es producida por el firmante efectivo, que el coinbase paga a la misma dirección, y que todas las transiciones siguen los retardos prescritos de activación y revocación. Solo el propietario de la parcela puede crear o revocar asignaciones; las claves de forjado no pueden modificar o extender sus propios permisos.

Las asignaciones de forjado por tanto introducen delegación flexible sin introducir confianza. La propiedad de la capacidad subyacente siempre permanece criptográficamente anclada al propietario de la parcela, mientras que la autoridad de forjado puede ser delegada, rotada o revocada a medida que evolucionan las necesidades operacionales.

---

## 6. Escalado dinámico

A medida que el hardware evoluciona, el costo de computar parcelas disminuye relativo a leer trabajo precomputado del disco. Sin contramedidas, los atacantes eventualmente podrían generar pruebas al vuelo más rápido que los mineros leyendo trabajo almacenado, socavando el modelo de seguridad de la Prueba de Capacidad.

Para preservar el margen de seguridad previsto, PoCX implementa un programa de escalado: el nivel mínimo de escalado requerido para las parcelas aumenta con el tiempo. Cada nivel de escalado Xn, como se describe en la Sección 3.5, incrusta exponencialmente más prueba de trabajo dentro de la estructura de la parcela, asegurando que los mineros continúen comprometiendo recursos sustanciales de almacenamiento incluso a medida que la computación se vuelve más barata.

El programa se alinea con los incentivos económicos de la red, particularmente los halvings de recompensa de bloque. A medida que la recompensa por bloque disminuye, el nivel mínimo aumenta gradualmente, preservando el equilibrio entre el esfuerzo de graficado y el potencial de minería:

| Período | Años | Halvings | Escalado mín | Multiplicador de trabajo de parcela |
|---------|------|----------|--------------|-------------------------------------|
| Época 0 | 0-4 | 0 | X1 | 2× línea base |
| Época 1 | 4-12 | 1-2 | X2 | 4× línea base |
| Época 2 | 12-28 | 3-6 | X3 | 8× línea base |
| Época 3 | 28-60 | 7-14 | X4 | 16× línea base |
| Época 4 | 60-124 | 15-30 | X5 | 32× línea base |
| Época 5 | 124+ | 31+ | X6 | 64× línea base |

Los mineros pueden opcionalmente preparar parcelas que excedan el mínimo actual por un nivel, permitiéndoles planificar con anticipación y evitar actualizaciones inmediatas cuando la red transiciona a la siguiente época. Este paso opcional no confiere ventaja adicional en términos de probabilidad de bloque; simplemente permite una transición operacional más suave.

Los bloques que contienen pruebas por debajo del nivel mínimo de escalado para su altura se consideran inválidos. Los validadores verifican el nivel de escalado declarado en la prueba contra el requisito actual de la red durante la validación de consenso, asegurando que todos los mineros participantes cumplan las expectativas de seguridad en evolución.

---

## 7. Arquitectura de minería

PoCX separa las operaciones críticas de consenso de las tareas intensivas en recursos de la minería, habilitando tanto seguridad como eficiencia. El nodo mantiene la blockchain, valida bloques, gestiona el mempool y expone una interfaz RPC. Los mineros externos manejan el almacenamiento de parcelas, lectura de scoops, cálculo de calidad y gestión de plazos. Esta separación mantiene la lógica de consenso simple y auditable mientras permite a los mineros optimizar para el rendimiento de disco.

### 7.1 Interfaz RPC de minería

Los mineros interactúan con el nodo a través de un conjunto mínimo de llamadas RPC. El RPC get_mining_info proporciona la altura actual del bloque, firma de generación, objetivo base, plazo objetivo y el rango aceptable de niveles de escalado de parcela. Usando esta información, los mineros computan nonces candidatos. El RPC submit_nonce permite a los mineros enviar una solución propuesta, incluyendo el identificador de parcela, índice de nonce, nivel de escalado y cuenta del minero. El nodo evalúa el envío y responde con el plazo computado si la prueba es válida.

### 7.2 Programador de forjado

El nodo mantiene un programador de forjado, que rastrea los envíos entrantes y retiene solo la mejor solución para cada altura de bloque. Los nonces enviados se ponen en cola con protecciones incorporadas contra la inundación de envíos o ataques de denegación de servicio. El programador espera hasta que el plazo calculado expire o llegue una solución superior, momento en el cual ensambla un bloque, lo firma usando la clave de forjado efectiva y lo publica a la red.

### 7.3 Forjado defensivo

Para prevenir ataques de temporización o incentivos para manipulación del reloj, PoCX implementa forjado defensivo. Si llega un bloque competidor para la misma altura, el programador compara la solución local con el nuevo bloque. Si la calidad local es superior, el nodo forja inmediatamente en lugar de esperar el plazo original. Esto asegura que los mineros no puedan obtener ventaja meramente ajustando los relojes locales; la mejor solución siempre prevalece, preservando la justicia y la seguridad de la red.

---

## 8. Análisis de seguridad

### 8.1 Modelo de amenazas

PoCX modela adversarios con capacidades sustanciales pero acotadas. Los atacantes pueden intentar sobrecargar la red con transacciones inválidas, bloques malformados o pruebas fabricadas para poner a prueba las rutas de validación. Pueden manipular libremente sus relojes locales y pueden intentar explotar casos límite en el comportamiento de consenso como el manejo de marcas de tiempo, la dinámica de ajuste de dificultad o las reglas de reorganización. También se espera que los adversarios busquen oportunidades para reescribir la historia a través de bifurcaciones de cadena dirigidas.

El modelo asume que ninguna parte controla la mayoría de la capacidad total de almacenamiento de la red. Como con cualquier mecanismo de consenso basado en recursos, un atacante con 51% de capacidad puede reorganizar unilateralmente la cadena; esta limitación fundamental no es específica de PoCX. PoCX también asume que los atacantes no pueden computar datos de parcela más rápido de lo que los mineros honestos pueden leerlos del disco. El programa de escalado (Sección 6) asegura que la brecha computacional requerida para la seguridad crezca con el tiempo a medida que mejora el hardware.

Las secciones siguientes examinan cada clase principal de ataque en detalle y describen las contramedidas incorporadas en PoCX.

### 8.2 Ataques de capacidad

Como PoW, un atacante con capacidad mayoritaria puede reescribir la historia (un ataque del 51%). Lograr esto requiere adquirir una huella de almacenamiento físico mayor que la de la red honesta, una empresa costosa y logísticamente demandante. Una vez que se obtiene el hardware, los costos operativos son bajos, pero la inversión inicial crea un fuerte incentivo económico para comportarse honestamente: socavar la cadena dañaría el valor de la base de activos propia del atacante.

PoC también evita el problema de nothing-at-stake asociado con PoS. Aunque los mineros pueden escanear parcelas contra múltiples bifurcaciones competidoras, cada escaneo consume tiempo real, típicamente del orden de decenas de segundos por cadena. Con un intervalo de bloque de 120 segundos, esto limita inherentemente la minería multi-bifurcación, e intentar minar muchas bifurcaciones simultáneamente degrada el rendimiento en todas ellas. La minería de bifurcaciones no es por tanto sin costo; está fundamentalmente limitada por el rendimiento de E/S.

Incluso si el hardware futuro permitiera escaneo de parcelas casi instantáneo (por ejemplo, SSDs de alta velocidad), un atacante aún enfrentaría un requisito sustancial de recursos físicos para controlar la mayoría de la capacidad de la red, haciendo un ataque de estilo 51% costoso y logísticamente desafiante.

Finalmente, los ataques de capacidad son mucho más difíciles de alquilar que los ataques de poder de hash. El cómputo de GPU puede adquirirse bajo demanda y redirigirse a cualquier cadena PoW instantáneamente. En contraste, PoC requiere hardware físico, graficado que consume tiempo y operaciones de E/S continuas. Estas restricciones hacen que los ataques oportunistas a corto plazo sean mucho menos factibles.

### 8.3 Ataques de temporización

La temporización juega un papel más crítico en la Prueba de Capacidad que en la Prueba de Trabajo. En PoW, las marcas de tiempo principalmente influyen en el ajuste de dificultad; en PoC, determinan si el plazo de un minero ha expirado y por tanto si un bloque es elegible para forjado. Los plazos se miden relativos a la marca de tiempo del bloque padre, pero el reloj local de un nodo se usa para juzgar si un bloque entrante está demasiado en el futuro. Por esta razón PoCX hace cumplir una tolerancia de marca de tiempo estricta: los bloques no pueden desviarse más de 15 segundos del reloj local del nodo (comparado con la ventana de 2 horas de Bitcoin). Este límite funciona en ambas direcciones: los bloques muy en el futuro son rechazados, y los nodos con relojes lentos pueden rechazar incorrectamente bloques entrantes válidos.

Los nodos deberían por tanto sincronizar sus relojes usando NTP o una fuente de tiempo equivalente. PoCX evita deliberadamente depender de fuentes de tiempo internas de la red para prevenir que los atacantes manipulen el tiempo de red percibido. Los nodos monitorean su propia deriva y emiten advertencias si el reloj local comienza a divergir de las marcas de tiempo de bloques recientes.

La aceleración del reloj, ejecutar un reloj local rápido para forjar ligeramente antes, proporciona solo beneficio marginal. Dentro de la tolerancia permitida, el forjado defensivo (Sección 7.3) asegura que un minero con una mejor solución publicará inmediatamente al ver un bloque temprano inferior. Un reloj rápido solo ayuda a un minero a publicar una solución ya ganadora unos segundos antes; no puede convertir una prueba inferior en ganadora.

Los intentos de manipular la dificultad vía marcas de tiempo están acotados por un límite de ajuste de ±20% por bloque y una ventana móvil de 24 bloques, previniendo que los mineros influyan significativamente en la dificultad a través de juegos de temporización a corto plazo.

### 8.4 Ataques de compensación tiempo-memoria

Las compensaciones tiempo-memoria intentan reducir los requisitos de almacenamiento recomputando partes de la parcela bajo demanda. Los sistemas de Prueba de Capacidad anteriores eran vulnerables a tales ataques, más notablemente el fallo de desequilibrio de scoop de POC1 y el ataque de compresión XOR-transposición de POC2 (Sección 2.4). Ambos explotaban asimetrías en cuán costoso era regenerar ciertas porciones de datos de parcela, permitiendo a los adversarios recortar almacenamiento mientras pagaban solo una pequeña penalidad computacional. Además, los formatos de parcela alternativos a PoC2 sufren debilidades TMTO similares; un ejemplo prominente es Chia, cuyo formato de parcela puede reducirse arbitrariamente por un factor mayor que 4.

PoCX elimina estas superficies de ataque completamente a través de su construcción de nonce y formato de warp. Dentro de cada nonce, el paso final de difusión hashea el buffer completamente computado y aplica XOR del resultado a través de todos los bytes, asegurando que cada parte del buffer dependa de cada otra parte y no pueda acortarse. Después, la reorganización POC2 intercambia las mitades inferior y superior de cada scoop, igualando el costo computacional de recuperar cualquier scoop.

PoCX además elimina el ataque de compresión XOR-transposición de POC2 derivando su formato X1 endurecido, donde cada scoop es el XOR de una posición directa y una transpuesta a través de warps emparejados; esto entrelaza cada scoop con una fila completa y una columna completa de datos X0 subyacentes, haciendo que la reconstrucción requiera miles de nonces completos y por tanto eliminando la compensación tiempo-memoria asimétrica completamente.

Como resultado, almacenar la parcela completa es la única estrategia computacionalmente viable para los mineros. Ningún atajo conocido, ya sea graficado parcial, regeneración selectiva, compresión estructurada o enfoques híbridos de cómputo-almacenamiento, proporciona una ventaja significativa. PoCX asegura que la minería permanezca estrictamente limitada por almacenamiento y que la capacidad refleje un compromiso físico real.

### 8.5 Ataques de asignación

PoCX usa una máquina de estados determinista para gobernar todas las asignaciones de parcela a forjador. Cada asignación progresa a través de estados bien definidos (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED) con retardos forzados de activación y revocación. Esto asegura que un minero no pueda cambiar instantáneamente las asignaciones para engañar al sistema o cambiar rápidamente la autoridad de forjado.

Debido a que todas las transiciones requieren pruebas criptográficas, específicamente, firmas por el propietario de la parcela que son verificables contra el UTXO de entrada, la red puede confiar en la legitimidad de cada asignación. Los intentos de evadir la máquina de estados o falsificar asignaciones son rechazados automáticamente durante la validación de consenso. Los ataques de repetición se previenen igualmente por las protecciones estándar de repetición de transacciones de estilo Bitcoin, asegurando que cada acción de asignación esté vinculada únicamente a una entrada válida no gastada.

La combinación de gobernanza por máquina de estados, retardos forzados y prueba criptográfica hace que el engaño basado en asignaciones sea prácticamente imposible: los mineros no pueden secuestrar asignaciones, realizar reasignación rápida durante carreras de bloques o evadir los programas de revocación.

### 8.6 Seguridad de firmas

Las firmas de bloque en PoCX sirven como un vínculo crítico entre una prueba y la clave de forjado efectiva, asegurando que solo los mineros autorizados puedan producir bloques válidos.

Para prevenir ataques de maleabilidad, las firmas se excluyen del cálculo del hash del bloque. Esto elimina riesgos de firmas maleables que podrían socavar la validación o permitir ataques de reemplazo de bloques.

Para mitigar vectores de denegación de servicio, los tamaños de firma y clave pública son fijos (65 bytes para firmas compactas y 33 bytes para claves públicas comprimidas) previniendo que los atacantes inflen bloques para desencadenar agotamiento de recursos o ralentizar la propagación en la red.

---

## 9. Implementación

PoCX se implementa como una extensión modular a Bitcoin Core, con todo el código relevante contenido dentro de su propio subdirectorio dedicado y activado a través de una bandera de características. Este diseño preserva la integridad del código original, permitiendo que PoCX sea habilitado o deshabilitado limpiamente, lo que simplifica las pruebas, la auditoría y el mantenimiento de la sincronización con los cambios ascendentes.

La integración toca solo los puntos esenciales necesarios para soportar la Prueba de Capacidad. El encabezado de bloque ha sido extendido para incluir campos específicos de PoCX, y la validación de consenso ha sido adaptada para procesar pruebas basadas en almacenamiento junto con las verificaciones tradicionales de Bitcoin. El sistema de forjado, responsable de gestionar plazos, programación y envíos de mineros, está completamente contenido dentro de los módulos PoCX, mientras que las extensiones RPC exponen la funcionalidad de minería y asignación a clientes externos. Para los usuarios, la interfaz de cartera ha sido mejorada para gestionar asignaciones a través de transacciones OP_RETURN, permitiendo interacción sin fricciones con las nuevas características de consenso.

Todas las operaciones críticas de consenso se implementan en C++ determinista sin dependencias externas, asegurando consistencia entre plataformas. Shabal256 se usa para hashing, mientras que la flexión temporal y el cálculo de calidad dependen de aritmética de punto fijo y operaciones de 256 bits. Las operaciones criptográficas como la verificación de firmas aprovechan la biblioteca secp256k1 existente de Bitcoin Core.

Al aislar la funcionalidad PoCX de esta manera, la implementación permanece auditable, mantenible y completamente compatible con el desarrollo continuo de Bitcoin Core, demostrando que un mecanismo de consenso fundamentalmente nuevo limitado por almacenamiento puede coexistir con una base de código de prueba de trabajo madura sin perturbar su integridad o usabilidad.

---

## 10. Parámetros de red

PoCX se basa en la infraestructura de red de Bitcoin y reutiliza su marco de parámetros de cadena. Para soportar minería basada en capacidad, intervalos de bloque, manejo de asignaciones y escalado de parcelas, varios parámetros han sido extendidos o sobrescritos. Esto incluye el objetivo de tiempo de bloque, subsidio inicial, programa de halving, retardos de activación y revocación de asignación, así como identificadores de red como bytes mágicos, puertos y prefijos Bech32. Los entornos de testnet y regtest ajustan adicionalmente estos parámetros para permitir iteración rápida y pruebas de baja capacidad.

Las tablas a continuación resumen las configuraciones resultantes de mainnet, testnet y regtest, destacando cómo PoCX adapta los parámetros centrales de Bitcoin a un modelo de consenso limitado por almacenamiento.

### 10.1 Mainnet

| Parámetro | Valor |
|-----------|-------|
| Bytes mágicos | `0xa7 0x3c 0x91 0x5e` |
| Puerto predeterminado | 8888 |
| HRP Bech32 | `pocx` |
| Objetivo de tiempo de bloque | 120 segundos |
| Subsidio inicial | 10 BTC |
| Intervalo de halving | 1050000 bloques (~4 años) |
| Suministro total | ~21 millones BTC |
| Activación de asignación | 30 bloques |
| Revocación de asignación | 720 bloques |
| Ventana móvil | 24 bloques |

### 10.2 Testnet

| Parámetro | Valor |
|-----------|-------|
| Bytes mágicos | `0x6d 0xf2 0x48 0xb3` |
| Puerto predeterminado | 18888 |
| HRP Bech32 | `tpocx` |
| Objetivo de tiempo de bloque | 120 segundos |
| Otros parámetros | Igual que mainnet |

### 10.3 Regtest

| Parámetro | Valor |
|-----------|-------|
| Bytes mágicos | `0xfa 0xbf 0xb5 0xda` |
| Puerto predeterminado | 18444 |
| HRP Bech32 | `rpocx` |
| Objetivo de tiempo de bloque | 1 segundo |
| Intervalo de halving | 500 bloques |
| Activación de asignación | 4 bloques |
| Revocación de asignación | 8 bloques |
| Modo baja capacidad | Habilitado (~4 MB parcelas) |

---

## 11. Trabajo relacionado

A lo largo de los años, varios proyectos de blockchain y consenso han explorado modelos de minería basados en almacenamiento o híbridos. PoCX se basa en este linaje mientras introduce mejoras en seguridad, eficiencia y compatibilidad.

**Burstcoin / Signum.** Burstcoin introdujo el primer sistema práctico de Prueba de Capacidad (PoC) en 2014, definiendo conceptos centrales como parcelas, nonces, scoops y minería basada en plazos. Sus sucesores, notablemente Signum (anteriormente Burstcoin), extendieron el ecosistema y eventualmente evolucionaron a lo que se conoce como Prueba de Compromiso (PoC+), combinando compromiso de almacenamiento con staking opcional para influir en la capacidad efectiva. PoCX hereda la base de minería basada en almacenamiento de estos proyectos, pero diverge significativamente a través de un formato de parcela endurecido (codificación XOR-transposición), escalado dinámico de trabajo de parcela, suavizado de plazos ("flexión temporal") y un sistema de asignación flexible, todo mientras se ancla en la base de código de Bitcoin Core en lugar de mantener una bifurcación de red independiente.

**Chia.** Chia implementa Prueba de Espacio y Tiempo, combinando pruebas de almacenamiento basadas en disco con un componente temporal aplicado a través de Funciones de Retardo Verificable (VDFs). Su diseño aborda ciertas preocupaciones sobre la reutilización de pruebas y la generación de desafíos frescos, distinto del PoC clásico. PoCX no adopta ese modelo de prueba anclado en el tiempo; en cambio, mantiene un consenso limitado por almacenamiento con intervalos predecibles, optimizado para compatibilidad a largo plazo con la economía UTXO y las herramientas derivadas de Bitcoin.

**Spacemesh.** Spacemesh propone un esquema de Prueba de Espacio-Tiempo (PoST) usando una topología de red basada en DAG (malla). En este modelo, los participantes deben probar periódicamente que el almacenamiento asignado permanece intacto a lo largo del tiempo, en lugar de depender de un solo conjunto de datos precomputado. PoCX, en contraste, verifica el compromiso de almacenamiento solo en el momento del bloque, con formatos de parcela endurecidos y validación de prueba rigurosa, evitando la sobrecarga de pruebas de almacenamiento continuas mientras preserva la eficiencia y la descentralización.

---

## 12. Conclusión

Bitcoin-PoCX demuestra que el consenso energéticamente eficiente puede integrarse en Bitcoin Core mientras preserva las propiedades de seguridad y el modelo económico. Las contribuciones clave incluyen la codificación XOR-transposición (obliga a los atacantes a computar 4096 nonces por búsqueda, eliminando el ataque de compresión), el algoritmo de flexión temporal (la transformación de distribución reduce la varianza del tiempo de bloque), el sistema de asignación de forjado (la delegación basada en OP_RETURN permite minería en pool sin custodia), el escalado dinámico (alineado con halvings para mantener márgenes de seguridad) y la integración mínima (código marcado con banderas de características aislado en un directorio dedicado).

El sistema está actualmente en fase de testnet. El poder de minería deriva de la capacidad de almacenamiento en lugar de la tasa de hash, reduciendo el consumo de energía en órdenes de magnitud mientras mantiene el modelo económico probado de Bitcoin.

---

## Referencias

Bitcoin Core. *Repositorio de Bitcoin Core.* https://github.com/bitcoin/bitcoin

Burstcoin. *Documentación técnica de Prueba de Capacidad.* 2014.

NIST. *Competencia SHA-3: Shabal.* 2008.

Cohen, B., Pietrzak, K. *The Chia Network Blockchain.* 2019.

Spacemesh. *Documentación del protocolo Spacemesh.* 2021.

PoC Consortium. *Framework PoCX.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Integración Bitcoin-PoCX.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Licencia**: MIT
**Organización**: Proof of Capacity Consortium
**Estado**: Fase de Testnet
