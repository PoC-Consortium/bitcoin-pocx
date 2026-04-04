[← Anterior: Introdução](1-introduction.md) | [📘 Índice](index.md) | [Próximo: Consenso e Mineração →](3-consensus-and-mining.md)

---

# Capítulo 2: Especificação do Formato de Plot PoCX

Este documento descreve o formato de plot PoCX, uma versão aprimorada do formato POC2 com segurança melhorada, otimizações SIMD e proof-of-work escalável.

## Visão Geral do Formato

Arquivos de plot PoCX contêm valores de hash Shabal256 pré-computados organizados para operações eficientes de mineração. Seguindo a tradição PoC desde o POC1, **todos os metadados são embutidos no nome do arquivo** — não há cabeçalho de arquivo.

### Extensão de Arquivo
- **Padrão**: `.pocx` (plots concluídos)
- **Em Andamento**: `.tmp` (durante o plotting, renomeado para `.pocx` quando completo)

## Contexto Histórico e Evolução de Vulnerabilidades

### Formato POC1 (Legado)
**Duas Vulnerabilidades Principais (Tradeoffs Tempo-Memória):**

1. **Falha na Distribuição de PoW**
   - Distribuição não uniforme de proof-of-work entre scoops
   - Scoops de números baixos podiam ser calculados em tempo real
   - **Impacto**: Requisitos de armazenamento reduzidos para atacantes

2. **Ataque de Compressão XOR** (Tradeoff Tempo-Memória de 50%)
   - Explorava propriedades matemáticas para alcançar redução de 50% no armazenamento
   - **Impacto**: Atacantes podiam minerar com metade do armazenamento necessário

**Otimização de Layout**: Layout sequencial básico de scoops para eficiência em HDD

### Formato POC2 (Burstcoin)
- ✅ **Corrigida falha de distribuição de PoW**
- ❌ **Vulnerabilidade XOR-transpose permaneceu sem correção**
- **Layout**: Manteve otimização sequencial de scoops

### Formato PoCX (Atual)
- ✅ **Distribuição de PoW corrigida** (herdada do POC2)
- ✅ **Vulnerabilidade XOR-transpose corrigida** (exclusivo do PoCX)
- ✅ **Layout aprimorado para SIMD/GPU** otimizado para processamento paralelo e coalescência de memória
- ✅ **Proof-of-work escalável** previne tradeoffs tempo-memória conforme o poder computacional cresce (PoW é realizado apenas ao criar ou atualizar plotfiles)

## Codificação XOR-Transpose

### O Problema: Tradeoff Tempo-Memória de 50%

Nos formatos POC1/POC2, atacantes podiam explorar a relação matemática entre scoops para armazenar apenas metade dos dados e computar o resto em tempo real durante a mineração. Este "ataque de compressão XOR" comprometia a garantia de armazenamento.

### A Solução: Endurecimento XOR-Transpose

O PoCX deriva seu formato de mineração (X1) aplicando codificação XOR-transpose a pares de warps base (X0):

**Para construir o scoop S do nonce N em um warp X1:**
1. Pegue o scoop S do nonce N do primeiro warp X0 (posição direta)
2. Pegue o scoop N do nonce S do segundo warp X0 (posição transposta)
3. Aplique XOR nos dois valores de 64 bytes para obter o scoop X1

O passo de transposição troca os índices de scoop e nonce. Em termos de matriz — onde linhas representam scoops e colunas representam nonces — ele combina o elemento na posição (S, N) no primeiro warp com o elemento em (N, S) no segundo.

### Por Que Isso Elimina o Ataque

A codificação XOR-transpose interliga cada scoop com uma linha inteira e uma coluna inteira dos dados X0 subjacentes. Recuperar um único scoop X1 requer acesso a dados abrangendo todos os 4096 índices de scoop. Qualquer tentativa de computar dados faltantes exigiria regenerar 4096 nonces completos em vez de um único nonce — removendo a estrutura de custo assimétrica explorada pelo ataque XOR.

Como resultado, armazenar o warp X1 completo se torna a única estratégia computacionalmente viável para mineradores.

## Estrutura de Metadados no Nome do Arquivo

Todos os metadados do plot são codificados no nome do arquivo usando exatamente este formato:

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Componentes do Nome do Arquivo

1. **ACCOUNT_PAYLOAD** (40 caracteres hexadecimais)
   - Payload de conta bruto de 20 bytes como hex maiúsculo
   - Independente de rede (sem ID de rede ou checksum)
   - Exemplo: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD0`

2. **SEED** (64 caracteres hexadecimais)
   - Valor de seed de 32 bytes como hex minúsculo
   - **Novo no PoCX**: Seed aleatório de 32 bytes no nome do arquivo substitui numeração consecutiva de nonces — prevenindo sobreposições de plots
   - Exemplo: `C0FFEEBEEFCAFEBABEDEADBEEF1337C0DE42424242FEEDFACECAFED00DABAD1D`

3. **WARPS** (número decimal)
   - **Nova unidade de tamanho no PoCX**: Substitui dimensionamento baseado em nonces do POC1/POC2
   - **Design resistente a XOR-transpose**: Cada warp = exatamente 4096 nonces (tamanho de partição necessário para transformação resistente a XOR-transpose)
   - **Tamanho**: 1 warp = 1073741824 bytes = 1 GiB (unidade conveniente)
   - Exemplo: `1024` (plot de 1 TiB = 1024 warps)

4. **SCALING** (decimal com prefixo X)
   - Nível de escala como `X{nível}`
   - Valores mais altos = mais proof-of-work necessário
   - Exemplo: `X4` (2^4 = 16× a dificuldade do POC2)

### Exemplos de Nomes de Arquivo
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_C0FFEEBEEFCAFEBABEDEADBEEF1337C0DE42424242FEEDFACECAFED00DABAD1D_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_B00B1E5FEEDC0DEBABEFACE5DEA1DEADC0DE1337C0FFEEBABEFACE5BAD1DEA50_2048_X1.pocx
```


## Layout do Arquivo e Estrutura de Dados

### Organização Hierárquica
```
Arquivo de Plot (SEM CABEÇALHO)
├── Scoop 0
│   ├── Warp 0 (Todos os nonces para este scoop/warp)
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

### Constantes e Tamanhos

| Constante       | Tamanho                 | Descrição                                       |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                   | Saída de um único hash Shabal256                |
| **SCOOP\_SIZE** | 64 B (2 × HASH\_SIZE)  | Par de hashes lido em uma rodada de mineração   |
| **NUM\_SCOOPS** | 4096 (2¹²)             | Scoops por nonce; um selecionado por rodada     |
| **NONCE\_SIZE** | 262144 B (256 KiB)     | Todos os scoops de um nonce (menor unidade PoC1/PoC2) |
| **WARP\_SIZE**  | 1073741824 B (1 GiB)   | Menor unidade no PoCX                           |

### Layout de Arquivo de Plot Otimizado para SIMD

O PoCX implementa um padrão de acesso a nonces consciente de SIMD que permite processamento vetorizado
de múltiplos nonces simultaneamente. Ele se baseia em conceitos da [pesquisa de otimização
POC2×16](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) para maximizar throughput de memória e eficiência SIMD.

---

#### Layout Sequencial Tradicional

Armazenamento sequencial de nonces:

```
[Nonce 0: Dados do Scoop] [Nonce 1: Dados do Scoop] [Nonce 2: Dados do Scoop] ...
```

Ineficiência SIMD: Cada lane SIMD precisa da mesma palavra entre nonces:

```
Palavra 0 do Nonce 0 -> offset 0
Palavra 0 do Nonce 1 -> offset 512
Palavra 0 do Nonce 2 -> offset 1024
...
```

Acesso scatter-gather reduz throughput.

---

#### Layout Otimizado para SIMD do PoCX

O PoCX armazena **posições de palavras através de 16 nonces** contiguamente:

```
Linha de Cache (64 bytes):

Palavra0_N0 Palavra0_N1 Palavra0_N2 ... Palavra0_N15
Palavra1_N0 Palavra1_N1 Palavra1_N2 ... Palavra1_N15
...
```

**Diagrama ASCII**

```
Layout tradicional:

Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

Layout PoCX:

Palavra0: [N0][N1][N2][N3]...[N15]
Palavra1: [N0][N1][N2][N3]...[N15]
Palavra2: [N0][N1][N2][N3]...[N15]
```

---

#### Benefícios de Acesso à Memória

- Uma linha de cache supre todos os lanes SIMD.
- Elimina operações scatter-gather.
- Reduz cache misses.
- Acesso totalmente sequencial à memória para computação vetorizada.
- GPUs também se beneficiam do alinhamento de 16 nonces, maximizando eficiência de cache.

---

#### Escalabilidade SIMD

| SIMD       | Largura do Vetor* | Nonces | Ciclos de Processamento por Linha de Cache |
|------------|-------------------|--------|---------------------------------------------|
| SSE2/AVX   | 128-bit           | 4      | 4 ciclos                                    |
| AVX2       | 256-bit           | 8      | 2 ciclos                                    |
| AVX512     | 512-bit           | 16     | 1 ciclo                                     |

\* Para operações com inteiros

---



## Escalabilidade de Proof-of-Work

### Níveis de Escala
- **X0**: Nonces base sem codificação XOR-transpose (teórico, não usado para mineração)
- **X1**: Baseline XOR-transpose — primeiro formato endurecido (1× trabalho)
- **X2**: 2× trabalho X1 (XOR entre 2 warps)
- **X3**: 4× trabalho X1 (XOR entre 4 warps)
- **...**
- **Xn**: 2^(n-1) × trabalho X1 embutido

### Benefícios
- **Dificuldade de PoW ajustável**: Aumenta requisitos computacionais para acompanhar hardware mais rápido
- **Longevidade do formato**: Permite escalabilidade flexível da dificuldade de mineração ao longo do tempo

### Atualização de Plot / Compatibilidade Retroativa

Quando a rede aumenta a escala de PoW (Proof of Work) em 1, plots existentes requerem uma atualização para manter o mesmo tamanho efetivo de plot. Essencialmente, você agora precisa de duas vezes o PoW em seus arquivos de plot para alcançar a mesma contribuição para sua conta.

A boa notícia é que o PoW que você já completou ao criar seus arquivos de plot não é perdido — você simplesmente precisa adicionar PoW adicional aos arquivos existentes. Não é necessário replottear.

Alternativamente, você pode continuar usando seus plots atuais sem atualizar, mas note que eles agora contribuirão apenas 50% do seu tamanho efetivo anterior para sua conta. Seu software de mineração pode escalar um plotfile em tempo real.

## Comparação com Formatos Legados

| Recurso | POC1 | POC2 | PoCX |
|---------|------|------|------|
| Distribuição de PoW | ❌ Falha | ✅ Corrigida | ✅ Corrigida |
| Resistência XOR-Transpose | ❌ Vulnerável | ❌ Vulnerável | ✅ Corrigida |
| Otimização SIMD | ❌ Nenhuma | ❌ Nenhuma | ✅ Avançada |
| Otimização GPU | ❌ Nenhuma | ❌ Nenhuma | ✅ Otimizada |
| Proof-of-Work Escalável | ❌ Nenhum | ❌ Nenhum | ✅ Sim |
| Suporte a Seed | ❌ Nenhum | ❌ Nenhum | ✅ Sim |

O formato PoCX representa o estado da arte atual em formatos de plot para Proof of Capacity, abordando todas as vulnerabilidades conhecidas enquanto fornece melhorias significativas de desempenho para hardware moderno.

## Referências e Leitura Adicional

- **Contexto POC1/POC2**: [Visão Geral de Mineração Burstcoin](https://www.burstcoin.community/burstcoin-mining/) - Guia abrangente sobre formatos tradicionais de mineração Proof of Capacity
- **Pesquisa POC2×16**: [Anúncio CIP: POC2×16 - Um novo formato de plot otimizado](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Pesquisa original de otimização SIMD que inspirou o PoCX
- **Algoritmo de Hash Shabal**: [O Projeto Saphir: Shabal, Uma Submissão para a Competição de Algoritmos de Hash Criptográficos do NIST](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Especificação técnica do algoritmo Shabal256 usado em mineração PoC

---

[← Anterior: Introdução](1-introduction.md) | [📘 Índice](index.md) | [Próximo: Consenso e Mineração →](3-consensus-and-mining.md)
