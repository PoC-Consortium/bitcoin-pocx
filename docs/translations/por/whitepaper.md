# Bitcoin-PoCX: Consenso Eficiente em Energia para o Bitcoin Core

**Versão**: 2.0 Rascunho
**Data**: Dezembro de 2025
**Organização**: Proof of Capacity Consortium

---

## Resumo

O consenso Proof-of-Work (PoW) do Bitcoin oferece segurança robusta, mas consome energia substancial devido à computação contínua de hashes em tempo real. Apresentamos o Bitcoin-PoCX, um fork do Bitcoin que substitui o PoW por Proof of Capacity (PoC), onde os mineradores pré-computam e armazenam grandes conjuntos de hashes em disco durante o plotting e subsequentemente mineram realizando consultas leves em vez de hashing contínuo. Ao transferir a computação da fase de mineração para uma fase única de plotting, o Bitcoin-PoCX reduz drasticamente o consumo de energia enquanto permite mineração em hardware comum, reduzindo a barreira de participação e mitigando as pressões de centralização inerentes ao PoW dominado por ASICs, tudo isso preservando as premissas de segurança e comportamento econômico do Bitcoin.

Nossa implementação introduz várias inovações principais:
(1) Um formato de plot endurecido que elimina todos os ataques conhecidos de tradeoff tempo-memória em sistemas PoC existentes, garantindo que o poder efetivo de mineração permaneça estritamente proporcional à capacidade de armazenamento comprometida;
(2) O algoritmo Time-Bending, que transforma distribuições de deadline de exponencial para qui-quadrado, reduzindo a variância do tempo de bloco sem alterar a média;
(3) Um mecanismo de atribuição de forja baseado em OP_RETURN que permite mineração em pool sem custódia; e
(4) Escalonamento dinâmico de compressão, que aumenta a dificuldade de geração de plots alinhada com os cronogramas de halving para manter margens de segurança de longo prazo conforme o hardware melhora.

O Bitcoin-PoCX mantém a arquitetura do Bitcoin Core através de modificações mínimas e sinalizadas por feature flags, isolando a lógica PoC do código de consenso existente. O sistema preserva a política monetária do Bitcoin mirando um intervalo de bloco de 120 segundos e ajustando o subsídio de bloco para 10 BTC. O subsídio reduzido compensa o aumento de cinco vezes na frequência de blocos, mantendo a taxa de emissão de longo prazo alinhada com o cronograma original do Bitcoin e mantendo a oferta máxima de ~21 milhões.

---

## 1. Introdução

### 1.1 Motivação

O consenso Proof-of-Work (PoW) do Bitcoin provou ser seguro por mais de uma década, mas a um custo significativo: mineradores devem continuamente gastar recursos computacionais, resultando em alto consumo de energia. Além de preocupações com eficiência, há uma motivação mais ampla: explorar mecanismos alternativos de consenso que mantenham a segurança enquanto reduzem a barreira de participação. O PoC permite que virtualmente qualquer pessoa com hardware de armazenamento comum minere efetivamente, reduzindo as pressões de centralização vistas na mineração PoW dominada por ASICs.

Proof of Capacity (PoC) alcança isso derivando poder de mineração do comprometimento de armazenamento em vez de computação contínua. Mineradores pré-computam grandes conjuntos de hashes armazenados em disco — plots — durante uma fase única de plotting. A mineração então consiste em consultas leves, reduzindo drasticamente o uso de energia enquanto preserva as premissas de segurança do consenso baseado em recursos.

### 1.2 Integração com o Bitcoin Core

O Bitcoin-PoCX integra consenso PoC ao Bitcoin Core em vez de criar uma nova blockchain. Esta abordagem aproveita a segurança comprovada do Bitcoin Core, sua stack de rede madura e ferramentas amplamente adotadas, enquanto mantém modificações mínimas e sinalizadas por feature flags. A lógica PoC é isolada do código de consenso existente, garantindo que funcionalidades core — validação de blocos, operações de carteira, formatos de transação — permaneçam amplamente inalteradas.

### 1.3 Objetivos de Design

**Segurança**: Manter robustez equivalente ao Bitcoin; ataques requerem capacidade de armazenamento majoritária.

**Eficiência**: Reduzir carga computacional contínua a níveis de E/S de disco.

**Acessibilidade**: Permitir mineração com hardware comum, reduzindo barreiras de entrada.

**Integração Mínima**: Introduzir consenso PoC com footprint mínimo de modificação.

---

## 2. Contexto: Proof of Capacity

### 2.1 Histórico

Proof of Capacity (PoC) foi introduzido pelo Burstcoin em 2014 como uma alternativa eficiente em energia ao Proof-of-Work (PoW). O Burstcoin demonstrou que poder de mineração poderia ser derivado de armazenamento comprometido em vez de hashing contínuo em tempo real: mineradores pré-computavam grandes conjuntos de dados ("plots") uma vez e depois mineravam lendo pequenas porções fixas deles.

Implementações iniciais de PoC provaram o conceito viável, mas também revelaram que formato de plot e estrutura criptográfica são críticos para segurança. Vários tradeoffs tempo-memória permitiam que atacantes minerassem efetivamente com menos armazenamento que participantes honestos. Isso destacou que a segurança do PoC depende do design do plot — não meramente do uso de armazenamento como recurso.

O legado do Burstcoin estabeleceu o PoC como um mecanismo de consenso prático e forneceu a base sobre a qual o PoCX se constrói.

### 2.2 Conceitos Fundamentais

A mineração PoC é baseada em grandes arquivos de plot pré-computados armazenados em disco. Esses plots contêm "computação congelada": hashing caro é realizado uma vez durante o plotting, e a mineração então consiste em leituras leves de disco e verificação simples. Elementos core incluem:

**Nonce:**
A unidade básica de dados de plot. Cada nonce contém 4096 scoops (256 KiB total) gerados via Shabal256 a partir do endereço do minerador e índice de nonce.

**Scoop:**
Um segmento de 64 bytes dentro de um nonce. Para cada bloco, a rede seleciona deterministicamente um índice de scoop (0-4095) baseado na assinatura de geração do bloco anterior. Apenas este scoop por nonce deve ser lido.

**Assinatura de Geração:**
Um valor de 256 bits derivado do bloco anterior. Ele fornece entropia para seleção de scoop e impede mineradores de prever índices futuros de scoop.

**Warp:**
Um grupo estrutural de 4096 nonces (1 GiB). Warps são a unidade relevante para formatos de plot resistentes a compressão.

### 2.3 Processo de Mineração e Pipeline de Qualidade

A mineração PoC consiste em um passo único de plotting e uma rotina leve por bloco:

**Configuração Única:**
- Geração de plot: Computar nonces via Shabal256 e escrevê-los em disco.

**Mineração Por Bloco:**
- Seleção de scoop: Determinar o índice de scoop a partir da assinatura de geração.
- Escaneamento de plot: Ler aquele scoop de todos os nonces nos plots do minerador.

**Pipeline de Qualidade:**
- Qualidade bruta: Hash de cada scoop com a assinatura de geração usando Shabal256Lite para obter um valor de qualidade de 64 bits (menor é melhor).
- Deadline: Converter qualidade em deadline usando o base target (um parâmetro ajustado por dificuldade garantindo que a rede atinja seu intervalo de bloco alvo): `deadline = quality / base_target`
- Deadline bended: Aplicar a transformação Time-Bending para reduzir variância enquanto preserva tempo esperado de bloco.

**Forja de Bloco:**
O minerador com o menor deadline (bended) forja o próximo bloco uma vez que aquele tempo tenha decorrido.

Diferente do PoW, quase toda a computação acontece durante o plotting; mineração ativa é principalmente limitada por disco e de consumo muito baixo.

### 2.4 Vulnerabilidades Conhecidas em Sistemas Anteriores

**Falha de Distribuição POC1:**
O formato original POC1 do Burstcoin exibia um viés estrutural: scoops de baixo índice eram significativamente mais baratos de recomputar em tempo real que scoops de alto índice. Isso introduziu um tradeoff tempo-memória não uniforme, permitindo que atacantes reduzissem o armazenamento necessário para esses scoops e quebrando a premissa de que todos os dados pré-computados eram igualmente caros.

**Ataque de Compressão XOR (POC2):**
No POC2, um atacante pode pegar qualquer conjunto de 8192 nonces e particioná-los em dois blocos de 4096 nonces (A e B). Em vez de armazenar ambos os blocos, o atacante armazena apenas uma estrutura derivada: `A ⊕ transpose(B)`, onde a transposição troca índices de scoop e nonce — scoop S do nonce N no bloco B se torna scoop N do nonce S.

Durante a mineração, quando scoop S do nonce N é necessário, o atacante o reconstrói:
1. Lendo o valor XOR armazenado na posição (S, N)
2. Computando nonce N do bloco A para obter scoop S
3. Computando nonce S do bloco B para obter o scoop transposto N
4. Aplicando XOR nos três valores para recuperar o scoop original de 64 bytes

Isso reduz armazenamento em 50%, enquanto requer apenas duas computações de nonce por consulta — um custo muito abaixo do limiar necessário para impor pré-computação completa. O ataque é viável porque computar uma linha (um nonce, 4096 scoops) é barato, enquanto computar uma coluna (um único scoop através de 4096 nonces) exigiria regenerar todos os nonces. A estrutura de transposição expõe este desequilíbrio.

Isso demonstrou a necessidade de um formato de plot que previna tal recombinação estruturada e remova o tradeoff tempo-memória subjacente. A Seção 3.3 descreve como o PoCX aborda e resolve esta fraqueza.

### 2.5 Transição para o PoCX

As limitações de sistemas PoC anteriores deixaram claro que mineração de armazenamento segura, justa e descentralizada depende de estruturas de plot cuidadosamente projetadas. O Bitcoin-PoCX aborda essas questões com um formato de plot endurecido, distribuição de deadline melhorada e mecanismos para mineração em pool descentralizada — descritos na próxima seção.

---

## 3. Formato de Plot PoCX

### 3.1 Construção de Nonce Base

Um nonce é uma estrutura de dados de 256 KiB derivada deterministicamente de três parâmetros: um payload de endereço de 20 bytes, um seed de 32 bytes e um índice de nonce de 64 bits.

A construção começa combinando essas entradas e aplicando hash com Shabal256 para produzir um hash inicial. Este hash serve como ponto de partida para um processo de expansão iterativa: Shabal256 é aplicado repetidamente, com cada passo dependendo de dados previamente gerados, até que todo o buffer de 256 KiB seja preenchido. Este processo encadeado representa o trabalho computacional realizado durante o plotting.

Um passo final de difusão aplica hash no buffer completado e aplica XOR do resultado em todos os bytes. Isso garante que todo o buffer foi computado e que mineradores não podem atalhar o cálculo. O shuffle POC2 é então aplicado, trocando as metades inferior e superior de cada scoop para garantir que todos os scoops requeiram esforço computacional equivalente.

O nonce final consiste em 4096 scoops de 64 bytes cada e forma a unidade fundamental usada na mineração.

### 3.2 Layout de Plot Alinhado a SIMD

Para maximizar throughput em hardware moderno, o PoCX organiza dados de nonce em disco para facilitar processamento vetorizado. Em vez de armazenar cada nonce sequencialmente, o PoCX alinha palavras de 4 bytes correspondentes através de múltiplos nonces consecutivos contiguamente. Isso permite que uma única busca de memória forneça dados para todos os lanes SIMD, minimizando cache misses e eliminando overhead de scatter-gather.

```
Layout tradicional:
Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

Layout SIMD do PoCX:
Palavra0: [N0][N1][N2]...[N15]
Palavra1: [N0][N1][N2]...[N15]
Palavra2: [N0][N1][N2]...[N15]
```

Este layout beneficia tanto mineradores CPU quanto GPU, permitindo avaliação de scoop paralelizada de alto throughput enquanto mantém um padrão de acesso escalar simples para verificação de consenso. Ele garante que a mineração seja limitada pela largura de banda de armazenamento em vez de computação de CPU, mantendo a natureza de baixo consumo do Proof of Capacity.

### 3.3 Estrutura de Warp e Codificação XOR-Transpose

Um warp é a unidade fundamental de armazenamento no PoCX, consistindo de 4096 nonces (1 GiB). O formato não comprimido, referido como X0, contém nonces base exatamente como produzidos pela construção na Seção 3.1.

**Codificação XOR-Transpose (X1)**

Para remover os tradeoffs estruturais tempo-memória presentes em sistemas PoC anteriores, o PoCX deriva um formato de mineração endurecido, X1, aplicando uma codificação XOR-transpose a pares de warps X0.

Para construir scoop S do nonce N em um warp X1:

1. Pegue scoop S do nonce N do primeiro warp X0 (posição direta)
2. Pegue scoop N do nonce S do segundo warp X0 (posição transposta)
3. Aplique XOR nos dois valores de 64 bytes para obter o scoop X1

O passo de transposição troca índices de scoop e nonce. Em termos de matriz — onde linhas representam scoops e colunas representam nonces — ele combina o elemento na posição (S, N) no primeiro warp com o elemento em (N, S) no segundo.

**Por Que Isso Elimina a Superfície de Ataque de Compressão**

A codificação XOR-transpose interliga cada scoop com uma linha inteira e uma coluna inteira dos dados X0 subjacentes. Recuperar um único scoop X1 portanto requer acesso a dados abrangendo todos os 4096 índices de scoop. Qualquer tentativa de computar dados faltantes exigiria regenerar 4096 nonces completos, em vez de um único nonce — removendo a estrutura de custo assimétrica explorada pelo ataque XOR para POC2 (Seção 2.4).

Como resultado, armazenar o warp X1 completo se torna a única estratégia computacionalmente viável para mineradores, fechando o tradeoff tempo-memória explorado em designs anteriores.

### 3.4 Layout de Disco

Arquivos de plot PoCX consistem em muitos warps X1 consecutivos. Para maximizar eficiência operacional durante mineração, os dados dentro de cada arquivo são organizados por scoop: todos os dados do scoop 0 de cada warp são armazenados sequencialmente, seguidos por todos os dados do scoop 1, e assim por diante, até o scoop 4095.

Esta **ordenação sequencial por scoop** permite que mineradores leiam os dados completos necessários para um scoop selecionado em um único acesso sequencial de disco, minimizando tempos de seek e maximizando throughput em dispositivos de armazenamento comuns.

Combinado com a codificação XOR-transpose da Seção 3.3, este layout garante que o arquivo seja tanto **estruturalmente endurecido** quanto **operacionalmente eficiente**: ordenação sequencial por scoop suporta E/S de disco ideal, enquanto layouts de memória alinhados a SIMD (veja Seção 3.2) permitem avaliação de scoop paralelizada de alto throughput.

### 3.5 Escalonamento de Proof-of-Work (Xn)

O PoCX implementa pré-computação escalável através do conceito de níveis de escala, denotados Xn, para adaptar-se à evolução do desempenho de hardware. O formato baseline X1 representa a primeira estrutura de warp endurecida por XOR-transpose.

Cada nível de escala Xn aumenta o proof-of-work embutido em cada warp exponencialmente relativo a X1: o trabalho necessário no nível Xn é 2^(n-1) vezes o de X1. A transição de Xn para Xn+1 é operacionalmente equivalente a aplicar XOR entre pares de warps adjacentes, incrementalmente embutindo mais proof-of-work sem mudar o tamanho subjacente do plot.

Arquivos de plot existentes criados em níveis de escala inferiores ainda podem ser usados para mineração, mas eles contribuem proporcionalmente menos trabalho para geração de blocos, refletindo seu menor proof-of-work embutido. Este mecanismo garante que plots PoCX permaneçam seguros, flexíveis e economicamente equilibrados ao longo do tempo.

### 3.6 Funcionalidade de Seed

O parâmetro seed permite múltiplos plots não sobrepostos por endereço sem coordenação manual.

**Problema (POC2)**: Mineradores tinham que rastrear manualmente faixas de nonce entre arquivos de plot para evitar sobreposição. Nonces sobrepostos desperdiçam armazenamento sem aumentar poder de mineração.

**Solução**: Cada par `(endereço, seed)` define um keyspace independente. Plots com seeds diferentes nunca se sobrepõem, independentemente das faixas de nonce. Mineradores podem criar plots livremente sem coordenação.

---

## 4. Consenso Proof of Capacity

O PoCX estende o consenso Nakamoto do Bitcoin com um mecanismo de prova limitado por armazenamento. Em vez de gastar energia em hashing repetido, mineradores comprometem grandes quantidades de dados pré-computados — plots — em disco. Durante a geração de blocos, eles devem localizar uma pequena porção imprevisível destes dados e transformá-la em uma prova. O minerador que fornece a melhor prova dentro da janela de tempo esperada ganha o direito de forjar o próximo bloco.

Este capítulo descreve como o PoCX estrutura metadados de bloco, deriva imprevisibilidade e transforma armazenamento estático em um mecanismo de consenso seguro e de baixa variância.

### 4.1 Estrutura de Bloco

O PoCX mantém o cabeçalho de bloco familiar no estilo Bitcoin, mas introduz campos adicionais de consenso necessários para mineração baseada em capacidade. Esses campos coletivamente vinculam o bloco ao plot armazenado do minerador, à dificuldade da rede e à entropia criptográfica que define cada desafio de mineração.

Em alto nível, um bloco PoCX contém: a altura do bloco, registrada explicitamente para simplificar validação contextual; a assinatura de geração, uma fonte de entropia fresca vinculando cada bloco ao seu predecessor; o base target, representando dificuldade de rede em forma inversa (valores mais altos correspondem a mineração mais fácil); a prova PoCX, identificando o plot do minerador, o nível de compressão usado durante plotting, o nonce selecionado e a qualidade derivada dele; e uma chave de assinatura e assinatura, provando controle da capacidade usada para forjar o bloco (ou de uma chave de forja atribuída).

A prova embute toda informação relevante ao consenso necessária por validadores para recomputar o desafio, verificar o scoop escolhido e confirmar a qualidade resultante. Ao estender em vez de redesenhar a estrutura de bloco, o PoCX permanece conceitualmente alinhado com o Bitcoin enquanto habilita uma fonte fundamentalmente diferente de trabalho de mineração.

### 4.2 Cadeia de Assinatura de Geração

A assinatura de geração fornece a imprevisibilidade necessária para mineração segura de Proof of Capacity. Cada bloco deriva sua assinatura de geração da assinatura e signatário do bloco anterior, garantindo que mineradores não possam antecipar desafios futuros ou pré-computar regiões vantajosas do plot:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

Isso produz uma sequência de valores de entropia criptograficamente fortes e dependentes do minerador. Como a chave pública de um minerador é desconhecida até o bloco anterior ser publicado, nenhum participante pode prever seleções futuras de scoop. Isso previne pré-computação seletiva ou plotting estratégico e garante que cada bloco introduza trabalho de mineração genuinamente novo.

### 4.3 Processo de Forja

Mineração no PoCX consiste em transformar dados armazenados em uma prova impulsionada inteiramente pela assinatura de geração. Embora o processo seja determinístico, a imprevisibilidade da assinatura garante que mineradores não possam se preparar antecipadamente e devem repetidamente acessar seus plots armazenados.

**Derivação de Desafio (Seleção de Scoop):** O minerador aplica hash na assinatura de geração atual com a altura do bloco para obter um índice de scoop na faixa 0-4095. Este índice determina qual segmento de 64 bytes de cada nonce armazenado participa na prova. Como a assinatura de geração depende do signatário do bloco anterior, a seleção de scoop se torna conhecida apenas no momento da publicação do bloco.

**Avaliação de Prova (Cálculo de Qualidade):** Para cada nonce em um plot, o minerador recupera o scoop selecionado e aplica hash nele junto com a assinatura de geração para obter uma qualidade — um valor de 64 bits cuja magnitude determina a competitividade do minerador. Qualidade menor corresponde a uma prova melhor.

**Formação de Deadline (Time Bending):** O deadline bruto é proporcional à qualidade e inversamente proporcional ao base target. Em designs PoC legados, esses deadlines seguiam uma distribuição exponencial altamente assimétrica, produzindo atrasos de cauda longa que não forneciam segurança adicional. O PoCX transforma o deadline bruto usando Time Bending (Seção 4.4), reduzindo variância e garantindo intervalos de bloco previsíveis. Uma vez que o deadline bended expira, o minerador forja um bloco embutindo a prova e assinando-a com a chave de forja efetiva.

### 4.4 Time Bending

Proof of Capacity produz deadlines distribuídos exponencialmente. Após um curto período — tipicamente algumas dezenas de segundos — cada minerador já identificou sua melhor prova, e qualquer tempo de espera adicional contribui apenas latência, não segurança.

Time Bending remodela a distribuição aplicando uma transformação de raiz cúbica:

`deadline_bended = scale × (quality / base_target)^(1/3)`

O fator de escala preserva o tempo esperado de bloco (120 segundos) enquanto reduz dramaticamente a variância. Deadlines curtos são expandidos, melhorando propagação de blocos e segurança de rede. Deadlines longos são comprimidos, prevenindo outliers de atrasar a cadeia.

![Distribuições de Tempo de Bloco](blocktime_distributions.svg)

Time Bending mantém o conteúdo informacional da prova subjacente. Ele não modifica competitividade entre mineradores; ele apenas realoca tempo de espera para produzir intervalos de bloco mais suaves e previsíveis. A implementação usa aritmética de ponto fixo (formato Q42) e inteiros de 256 bits para garantir resultados determinísticos em todas as plataformas.

### 4.5 Ajuste de Dificuldade

O PoCX regula produção de blocos usando o base target, uma medida de dificuldade inversa. O tempo esperado de bloco é proporcional à razão `quality / base_target`, então aumentar o base target acelera criação de blocos enquanto diminuí-lo desacelera a cadeia.

A dificuldade ajusta a cada bloco usando o tempo medido entre blocos recentes comparado ao intervalo alvo. Este ajuste frequente é necessário porque capacidade de armazenamento pode ser adicionada ou removida rapidamente — diferente do hashpower do Bitcoin, que muda mais lentamente.

O ajuste segue duas restrições guia: **Gradualidade** — mudanças por bloco são limitadas (±20% máximo) para evitar oscilações ou manipulação; **Endurecimento** — o base target não pode exceder seu valor de gênesis, prevenindo a rede de alguma vez diminuir dificuldade abaixo das premissas de segurança originais.

### 4.6 Validade de Bloco

Um bloco no PoCX é válido quando apresenta uma prova verificável derivada de armazenamento consistente com o estado de consenso. Validadores recomputam independentemente a seleção de scoop, derivam a qualidade esperada do nonce submetido e metadados do plot, aplicam a transformação Time Bending e confirmam que o minerador era elegível para forjar o bloco no tempo declarado.

Especificamente, um bloco válido requer: o deadline decorreu desde o bloco pai; a qualidade submetida corresponde à qualidade computada para a prova; o nível de escala atende ao mínimo da rede; a assinatura de geração corresponde ao valor esperado; o base target corresponde ao valor esperado; a assinatura do bloco vem do signatário efetivo; e o coinbase paga ao endereço do signatário efetivo.

---

## 5. Atribuições de Forja

### 5.1 Motivação

Atribuições de forja permitem que proprietários de plots deleguem autoridade de forja de blocos sem jamais abrir mão da propriedade de seus plots. Este mecanismo habilita mineração em pool e configurações de armazenamento frio enquanto preserva as garantias de segurança do PoCX.

Na mineração em pool, proprietários de plots podem autorizar um pool a forjar blocos em seu nome. O pool monta blocos e distribui recompensas, mas nunca ganha custódia sobre os plots em si. Delegação é reversível a qualquer momento, e proprietários de plots permanecem livres para deixar um pool ou mudar configurações sem replottar.

Atribuições também suportam uma separação limpa entre chaves frias e quentes. A chave privada controlando o plot pode permanecer offline, enquanto uma chave de forja separada — armazenada em uma máquina online — produz blocos. Um comprometimento da chave de forja portanto compromete apenas autoridade de forja, não propriedade. O plot permanece seguro e a atribuição pode ser revogada, fechando a brecha de segurança imediatamente.

Atribuições de forja assim fornecem flexibilidade operacional enquanto mantêm o princípio de que controle sobre capacidade armazenada nunca deve ser transferido para intermediários.

### 5.2 Protocolo de Atribuição

Atribuições são declaradas através de transações OP_RETURN para evitar crescimento desnecessário do conjunto UTXO. Uma transação de atribuição especifica o endereço do plot e o endereço de forja que está autorizado a produzir blocos usando a capacidade daquele plot. Uma transação de revogação contém apenas o endereço do plot. Em ambos os casos, o proprietário do plot prova controle assinando o input de gasto da transação.

Cada atribuição progride através de uma sequência de estados bem definidos (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Após uma transação de atribuição confirmar, o sistema entra em uma curta fase de ativação. Este atraso — 30 blocos, aproximadamente uma hora — garante estabilidade durante disputas de blocos e previne troca adversarial rápida de identidades de forja. Uma vez que este período de ativação expira, a atribuição se torna ativa e permanece assim até o proprietário do plot emitir uma revogação.

Revogações transicionam para um período de atraso mais longo de 720 blocos, aproximadamente um dia. Durante este tempo, o endereço de forja anterior permanece ativo. Este atraso mais longo fornece estabilidade operacional para pools, prevenindo "hopping de atribuição" estratégico e dando aos provedores de infraestrutura certeza suficiente para operar eficientemente. Após o atraso de revogação expirar, a revogação completa e o proprietário do plot está livre para designar uma nova chave de forja.

O estado de atribuição é mantido em uma estrutura de camada de consenso paralela ao conjunto UTXO e suporta dados de undo para tratamento seguro de reorganizações de cadeia.

### 5.3 Regras de Validação

Para cada bloco, validadores determinam o signatário efetivo — o endereço que deve assinar o bloco e receber a recompensa coinbase. Este signatário depende exclusivamente do estado de atribuição na altura do bloco.

Se nenhuma atribuição existe ou a atribuição ainda não completou sua fase de ativação, o proprietário do plot permanece o signatário efetivo. Uma vez que uma atribuição se torna ativa, o endereço de forja atribuído deve assinar. Durante revogação, o endereço de forja continua a assinar até o atraso de revogação expirar. Somente então a autoridade retorna ao proprietário do plot.

Validadores aplicam que a assinatura do bloco é produzida pelo signatário efetivo, que o coinbase paga ao mesmo endereço e que todas as transições seguem os atrasos prescritos de ativação e revogação. Apenas o proprietário do plot pode criar ou revogar atribuições; chaves de forja não podem modificar ou estender suas próprias permissões.

Atribuições de forja portanto introduzem delegação flexível sem introduzir confiança. Propriedade da capacidade subjacente sempre permanece criptograficamente ancorada ao proprietário do plot, enquanto autoridade de forja pode ser delegada, rotacionada ou revogada conforme necessidades operacionais evoluem.

---

## 6. Escalonamento Dinâmico

Conforme hardware evolui, o custo de computar plots diminui relativo a ler trabalho pré-computado de disco. Sem contramedidas, atacantes poderiam eventualmente gerar provas em tempo real mais rápido que mineradores lendo trabalho armazenado, comprometendo o modelo de segurança do Proof of Capacity.

Para preservar a margem de segurança pretendida, o PoCX implementa um cronograma de escalonamento: o nível de escala mínimo requerido para plots aumenta ao longo do tempo. Cada nível de escala Xn, como descrito na Seção 3.5, embute exponencialmente mais proof-of-work dentro da estrutura do plot, garantindo que mineradores continuem a comprometer recursos substanciais de armazenamento mesmo conforme computação se torna mais barata.

O cronograma alinha-se com os incentivos econômicos da rede, particularmente halvings de recompensa de bloco. Conforme a recompensa por bloco diminui, o nível mínimo gradualmente aumenta, preservando o equilíbrio entre esforço de plotting e potencial de mineração:

| Período | Anos | Halvings | Escala Mín | Multiplicador de Trabalho de Plot |
|---------|------|----------|------------|----------------------------------|
| Época 0 | 0-4 | 0 | X1 | 2× baseline |
| Época 1 | 4-12 | 1-2 | X2 | 4× baseline |
| Época 2 | 12-28 | 3-6 | X3 | 8× baseline |
| Época 3 | 28-60 | 7-14 | X4 | 16× baseline |
| Época 4 | 60-124 | 15-30 | X5 | 32× baseline |
| Época 5 | 124+ | 31+ | X6 | 64× baseline |

Mineradores podem opcionalmente preparar plots excedendo o mínimo atual por um nível, permitindo-lhes planejar antecipadamente e evitar atualizações imediatas quando a rede transiciona para a próxima época. Este passo opcional não confere vantagem adicional em termos de probabilidade de bloco — ele meramente permite uma transição operacional mais suave.

Blocos contendo provas abaixo do nível de escala mínimo para sua altura são considerados inválidos. Validadores verificam o nível de escala declarado na prova contra o requisito atual da rede durante validação de consenso, garantindo que todos os mineradores participantes atendam às expectativas de segurança em evolução.

---

## 7. Arquitetura de Mineração

O PoCX separa operações críticas de consenso das tarefas intensivas em recursos de mineração, permitindo tanto segurança quanto eficiência. O nó mantém a blockchain, valida blocos, gerencia o mempool e expõe uma interface RPC. Mineradores externos tratam armazenamento de plots, leitura de scoops, cálculo de qualidade e gerenciamento de deadlines. Esta separação mantém a lógica de consenso simples e auditável enquanto permite que mineradores otimizem para throughput de disco.

### 7.1 Interface RPC de Mineração

Mineradores interagem com o nó através de um conjunto mínimo de chamadas RPC. O RPC get_mining_info fornece a altura atual do bloco, assinatura de geração, base target, deadline alvo e a faixa aceitável de níveis de escala de plot. Usando esta informação, mineradores computam nonces candidatos. O RPC submit_nonce permite que mineradores submetam uma solução proposta, incluindo o identificador de plot, índice de nonce, nível de escala e conta do minerador. O nó avalia a submissão e responde com o deadline computado se a prova for válida.

### 7.2 Scheduler de Forja

O nó mantém um scheduler de forja, que rastreia submissões recebidas e retém apenas a melhor solução para cada altura de bloco. Nonces submetidos são enfileirados com proteções embutidas contra flooding de submissão ou ataques de negação de serviço. O scheduler espera até o deadline calculado expirar ou uma solução superior chegar, momento em que monta um bloco, assina-o usando a chave de forja efetiva e publica-o para a rede.

### 7.3 Forja Defensiva

Para prevenir ataques de timing ou incentivos para manipulação de relógio, o PoCX implementa forja defensiva. Se um bloco concorrente chega para a mesma altura, o scheduler compara a solução local com o novo bloco. Se a qualidade local for superior, o nó forja imediatamente em vez de esperar pelo deadline original. Isso garante que mineradores não possam ganhar vantagem meramente ajustando relógios locais; a melhor solução sempre prevalece, preservando justiça e segurança de rede.

---

## 8. Análise de Segurança

### 8.1 Modelo de Ameaça

O PoCX modela adversários com capacidades substanciais mas limitadas. Atacantes podem tentar sobrecarregar a rede com transações inválidas, blocos malformados ou provas fabricadas para testar caminhos de validação. Eles podem livremente manipular seus relógios locais e podem tentar explorar casos especiais em comportamento de consenso como tratamento de timestamp, dinâmicas de ajuste de dificuldade ou regras de reorganização. Adversários também devem tentar reescrever histórico através de forks de cadeia direcionados.

O modelo assume que nenhuma parte única controla maioria da capacidade total de armazenamento da rede. Como com qualquer mecanismo de consenso baseado em recursos, um atacante com 51% de capacidade pode unilateralmente reorganizar a cadeia; esta limitação fundamental não é específica ao PoCX. O PoCX também assume que atacantes não podem computar dados de plot mais rápido que mineradores honestos podem lê-los de disco. O cronograma de escalonamento (Seção 6) garante que a lacuna computacional necessária para segurança cresça ao longo do tempo conforme hardware melhora.

As seções seguintes examinam cada classe principal de ataque em detalhe e descrevem as contramedidas embutidas no PoCX.

### 8.2 Ataques de Capacidade

Como PoW, um atacante com capacidade majoritária pode reescrever histórico (um ataque de 51%). Alcançar isso requer adquirir um footprint físico de armazenamento maior que a rede honesta — uma empreitada cara e logisticamente exigente. Uma vez que o hardware é obtido, custos operacionais são baixos, mas o investimento inicial cria um forte incentivo econômico para comportar-se honestamente: comprometer a cadeia danificaria o valor da própria base de ativos do atacante.

O PoC também evita o problema de nothing-at-stake associado ao PoS. Embora mineradores possam escanear plots contra múltiplos forks concorrentes, cada escaneamento consome tempo real — tipicamente na ordem de dezenas de segundos por cadeia. Com um intervalo de bloco de 120 segundos, isso inerentemente limita mineração multi-fork, e tentar minerar muitos forks simultaneamente degrada desempenho em todos eles. Mineração de fork portanto não é sem custo; ela é fundamentalmente limitada por throughput de E/S.

Mesmo se hardware futuro permitisse escaneamento de plot quase instantâneo (ex: SSDs de alta velocidade), um atacante ainda enfrentaria um requisito substancial de recursos físicos para controlar maioria da capacidade de rede, tornando um ataque estilo 51% caro e logisticamente desafiador.

Finalmente, ataques de capacidade são muito mais difíceis de alugar que ataques de hashpower. Computação GPU pode ser adquirida sob demanda e redirecionada para qualquer cadeia PoW instantaneamente. Em contraste, PoC requer hardware físico, plotting intensivo em tempo e operações contínuas de E/S. Essas restrições tornam ataques oportunistas de curto prazo muito menos viáveis.

### 8.3 Ataques de Timing

Timing desempenha papel mais crítico em Proof of Capacity que em Proof of Work. Em PoW, timestamps influenciam principalmente ajuste de dificuldade; em PoC, eles determinam se o deadline de um minerador decorreu e portanto se um bloco é elegível para forja. Deadlines são medidos relativos ao timestamp do bloco pai, mas o relógio local de um nó é usado para julgar se um bloco recebido está muito no futuro. Por esta razão o PoCX aplica uma tolerância de timestamp apertada: blocos não podem desviar mais de 15 segundos do relógio local do nó (comparado à janela de 2 horas do Bitcoin). Este limite funciona em ambas as direções — blocos muito no futuro são rejeitados, e nós com relógios lentos podem incorretamente rejeitar blocos válidos recebidos.

Nós portanto devem sincronizar seus relógios usando NTP ou fonte de tempo equivalente. O PoCX deliberadamente evita depender de fontes de tempo internas à rede para prevenir atacantes de manipular tempo percebido de rede. Nós monitoram seu próprio desvio e emitem avisos se o relógio local começa a divergir de timestamps de blocos recentes.

Aceleração de relógio — executar um relógio local rápido para forjar ligeiramente mais cedo — fornece apenas benefício marginal. Dentro da tolerância permitida, forja defensiva (Seção 7.3) garante que um minerador com uma solução melhor publicará imediatamente ao ver um bloco antecipado inferior. Um relógio rápido só ajuda um minerador a publicar uma solução já vencedora alguns segundos mais cedo; ele não pode converter uma prova inferior em vencedora.

Tentativas de manipular dificuldade via timestamps são limitadas por um cap de ajuste por bloco de ±20% e uma janela móvel de 24 blocos, prevenindo mineradores de influenciar significativamente dificuldade através de jogos de timing de curto prazo.

### 8.4 Ataques de Tradeoff Tempo-Memória

Tradeoffs tempo-memória tentam reduzir requisitos de armazenamento recomputando partes do plot sob demanda. Sistemas Proof of Capacity anteriores eram vulneráveis a tais ataques, mais notavelmente a falha de desbalanceamento de scoop do POC1 e o ataque de compressão XOR-transpose do POC2 (Seção 2.4). Ambos exploravam assimetrias em quão caro era regenerar certas porções de dados de plot, permitindo que adversários cortassem armazenamento enquanto pagavam apenas uma pequena penalidade computacional. Além disso, formatos alternativos de plot ao PoC2 sofrem de fraquezas similares de TMTO; um exemplo proeminente é Chia, cujo formato de plot pode ser arbitrariamente reduzido por um fator maior que 4.

O PoCX remove essas superfícies de ataque inteiramente através de sua construção de nonce e formato de warp. Dentro de cada nonce, o passo final de difusão aplica hash no buffer totalmente computado e aplica XOR do resultado em todos os bytes, garantindo que cada parte do buffer dependa de cada outra parte e não possa ser atalhada. Depois, o shuffle POC2 troca as metades inferior e superior de cada scoop, equalizando o custo computacional de recuperar qualquer scoop.

O PoCX ainda elimina o ataque de compressão XOR-transpose do POC2 derivando seu formato endurecido X1, onde cada scoop é o XOR de uma posição direta e uma transposta entre warps emparelhados; isso interliga cada scoop com uma linha inteira e uma coluna inteira de dados X0 subjacentes, tornando reconstrução requerendo milhares de nonces completos e assim removendo o tradeoff tempo-memória assimétrico inteiramente.

Como resultado, armazenar o plot completo é a única estratégia computacionalmente viável para mineradores. Nenhum atalho conhecido — seja plotting parcial, regeneração seletiva, compressão estruturada ou abordagens híbridas compute-armazenamento — fornece uma vantagem significativa. O PoCX garante que mineração permaneça estritamente limitada por armazenamento e que capacidade reflita comprometimento real e físico.

### 8.5 Ataques de Atribuição

O PoCX usa uma máquina de estados determinística para governar todas as atribuições plot-para-forjador. Cada atribuição progride através de estados bem definidos — UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED — com atrasos forçados de ativação e revogação. Isso garante que um minerador não pode instantaneamente mudar atribuições para trapacear o sistema ou trocar rapidamente autoridade de forja.

Como todas as transições requerem provas criptográficas — especificamente, assinaturas pelo proprietário do plot que são verificáveis contra o input UTXO — a rede pode confiar na legitimidade de cada atribuição. Tentativas de contornar a máquina de estados ou forjar atribuições são automaticamente rejeitadas durante validação de consenso. Ataques de replay são igualmente prevenidos por proteções padrão de replay de transação estilo Bitcoin, garantindo que cada ação de atribuição é unicamente vinculada a um input válido e não gasto.

A combinação de governança por máquina de estados, atrasos forçados e prova criptográfica torna trapaça baseada em atribuição praticamente impossível: mineradores não podem sequestrar atribuições, realizar reatribuição rápida durante disputas de blocos ou contornar cronogramas de revogação.

### 8.6 Segurança de Assinatura

Assinaturas de bloco no PoCX servem como um link crítico entre uma prova e a chave de forja efetiva, garantindo que apenas mineradores autorizados possam produzir blocos válidos.

Para prevenir ataques de maleabilidade, assinaturas são excluídas do cálculo de hash do bloco. Isso elimina riscos de assinaturas maleáveis que poderiam comprometer validação ou permitir ataques de substituição de bloco.

Para mitigar vetores de negação de serviço, tamanhos de assinatura e chave pública são fixos — 65 bytes para assinaturas compactas e 33 bytes para chaves públicas comprimidas — prevenindo atacantes de inflar blocos para disparar exaustão de recursos ou retardar propagação de rede.

---

## 9. Implementação

O PoCX é implementado como uma extensão modular ao Bitcoin Core, com todo código relevante contido em seu próprio subdiretório dedicado e ativado através de uma feature flag. Este design preserva a integridade do código original, permitindo que o PoCX seja habilitado ou desabilitado limpamente, o que simplifica testes, auditoria e manutenção de sincronização com mudanças upstream.

A integração toca apenas os pontos essenciais necessários para suportar Proof of Capacity. O cabeçalho de bloco foi estendido para incluir campos específicos do PoCX, e validação de consenso foi adaptada para processar provas baseadas em armazenamento junto com verificações tradicionais do Bitcoin. O sistema de forja, responsável por gerenciar deadlines, agendamento e submissões de mineradores, é totalmente contido dentro dos módulos PoCX, enquanto extensões RPC expõem funcionalidade de mineração e atribuição para clientes externos. Para usuários, a interface de carteira foi aprimorada para gerenciar atribuições através de transações OP_RETURN, permitindo interação fluida com os novos recursos de consenso.

Todas as operações críticas de consenso são implementadas em C++ determinístico sem dependências externas, garantindo consistência cross-platform. Shabal256 é usado para hashing, enquanto Time Bending e cálculo de qualidade dependem de aritmética de ponto fixo e operações de 256 bits. Operações criptográficas como verificação de assinatura aproveitam a biblioteca secp256k1 existente do Bitcoin Core.

Ao isolar funcionalidade do PoCX desta forma, a implementação permanece auditável, manutenível e totalmente compatível com desenvolvimento contínuo do Bitcoin Core, demonstrando que um mecanismo de consenso fundamentalmente novo limitado por armazenamento pode coexistir com uma base de código proof-of-work madura sem interromper sua integridade ou usabilidade.

---

## 10. Parâmetros de Rede

O PoCX se constrói sobre a infraestrutura de rede do Bitcoin e reutiliza seu framework de parâmetros de cadeia. Para suportar mineração baseada em capacidade, intervalos de bloco, tratamento de atribuição e escalonamento de plot, vários parâmetros foram estendidos ou sobrescritos. Isso inclui alvo de tempo de bloco, subsídio inicial, cronograma de halving, atrasos de ativação e revogação de atribuição, bem como identificadores de rede como magic bytes, portas e prefixos Bech32. Ambientes de Testnet e regtest ainda ajustam esses parâmetros para permitir iteração rápida e testes de baixa capacidade.

As tabelas abaixo resumem as configurações resultantes de mainnet, testnet e regtest, destacando como o PoCX adapta os parâmetros core do Bitcoin para um modelo de consenso limitado por armazenamento.

### 10.1 Mainnet

| Parâmetro | Valor |
|-----------|-------|
| Magic bytes | `0xa7 0x3c 0x91 0x5e` |
| Porta padrão | 8888 |
| HRP Bech32 | `pocx` |
| Alvo de tempo de bloco | 120 segundos |
| Subsídio inicial | 10 BTC |
| Intervalo de halving | 1050000 blocos (~4 anos) |
| Oferta total | ~21 milhões de BTC |
| Ativação de atribuição | 30 blocos |
| Revogação de atribuição | 720 blocos |
| Janela móvel | 24 blocos |

### 10.2 Testnet

| Parâmetro | Valor |
|-----------|-------|
| Magic bytes | `0x6d 0xf2 0x48 0xb3` |
| Porta padrão | 18888 |
| HRP Bech32 | `tpocx` |
| Alvo de tempo de bloco | 120 segundos |
| Outros parâmetros | Mesmo que mainnet |

### 10.3 Regtest

| Parâmetro | Valor |
|-----------|-------|
| Magic bytes | `0xfa 0xbf 0xb5 0xda` |
| Porta padrão | 18444 |
| HRP Bech32 | `rpocx` |
| Alvo de tempo de bloco | 1 segundo |
| Intervalo de halving | 500 blocos |
| Ativação de atribuição | 4 blocos |
| Revogação de atribuição | 8 blocos |
| Modo baixa-capacidade | Habilitado (~4 MB plots) |

---

## 11. Trabalhos Relacionados

Ao longo dos anos, vários projetos de blockchain e consenso exploraram modelos de mineração baseados em armazenamento ou híbridos. O PoCX se constrói sobre esta linhagem enquanto introduz aprimoramentos em segurança, eficiência e compatibilidade.

**Burstcoin / Signum.** Burstcoin introduziu o primeiro sistema prático de Proof-of-Capacity (PoC) em 2014, definindo conceitos core como plots, nonces, scoops e mineração baseada em deadline. Seus sucessores, notavelmente Signum (anteriormente Burstcoin), estenderam o ecossistema e eventualmente evoluíram para o que é conhecido como Proof-of-Commitment (PoC+), combinando comprometimento de armazenamento com staking opcional para influenciar capacidade efetiva. O PoCX herda a fundação de mineração baseada em armazenamento destes projetos, mas diverge significativamente através de um formato de plot endurecido (codificação XOR-transpose), escalonamento dinâmico de trabalho de plot, suavização de deadline ("Time Bending") e um sistema flexível de atribuição — tudo enquanto se ancora na base de código do Bitcoin Core em vez de manter um fork de rede standalone.

**Chia.** Chia implementa Proof of Space and Time, combinando provas de armazenamento baseadas em disco com um componente de tempo aplicado via Verifiable Delay Functions (VDFs). Seu design aborda certas preocupações sobre reuso de prova e geração de desafio fresco, distintas do PoC clássico. O PoCX não adota aquele modelo de prova ancorada em tempo; em vez disso, ele mantém um consenso limitado por armazenamento com intervalos previsíveis, otimizado para compatibilidade de longo prazo com economia UTXO e ferramentas derivadas de Bitcoin.

**Spacemesh.** Spacemesh propõe um esquema de Proof-of-Space-Time (PoST) usando uma topologia de rede baseada em DAG (mesh). Neste modelo, participantes devem periodicamente provar que armazenamento alocado permanece intacto ao longo do tempo, em vez de depender de um único conjunto de dados pré-computado. O PoCX, em contraste, verifica comprometimento de armazenamento apenas no tempo de bloco — com formatos de plot endurecidos e validação rigorosa de prova — evitando o overhead de provas contínuas de armazenamento enquanto preserva eficiência e descentralização.

---

## 12. Conclusão

O Bitcoin-PoCX demonstra que consenso eficiente em energia pode ser integrado ao Bitcoin Core enquanto preserva propriedades de segurança e modelo econômico. Contribuições principais incluem a codificação XOR-transpose (força atacantes a computar 4096 nonces por consulta, eliminando o ataque de compressão), o algoritmo Time Bending (transformação de distribuição reduz variância de tempo de bloco), o sistema de atribuição de forja (delegação baseada em OP_RETURN habilita mineração em pool sem custódia), escalonamento dinâmico (alinhado com halvings para manter margens de segurança) e integração mínima (código sinalizado por feature flag isolado em diretório dedicado).

O sistema está atualmente em fase de testnet. Poder de mineração deriva de capacidade de armazenamento em vez de taxa de hash, reduzindo consumo de energia por ordens de magnitude enquanto mantém o modelo econômico comprovado do Bitcoin.

---

## Referências

Bitcoin Core. *Bitcoin Core Repository.* https://github.com/bitcoin/bitcoin

Burstcoin. *Proof of Capacity Technical Documentation.* 2014.

NIST. *SHA-3 Competition: Shabal.* 2008.

Cohen, B., Pietrzak, K. *The Chia Network Blockchain.* 2019.

Spacemesh. *Spacemesh Protocol Documentation.* 2021.

PoC Consortium. *PoCX Framework.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Bitcoin-PoCX Integration.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Licença**: MIT
**Organização**: Proof of Capacity Consortium
**Status**: Fase de Testnet
