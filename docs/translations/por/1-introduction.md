[📘 Índice](index.md) | [Próximo: Formato de Plot →](2-plot-format.md)

---

# Capítulo 1: Introdução e Visão Geral

## O que é Bitcoin-PoCX?

Bitcoin-PoCX é uma integração ao Bitcoin Core que adiciona suporte ao consenso **Proof of Capacity neXt generation (PoCX)**. Ele mantém a arquitetura existente do Bitcoin Core enquanto habilita uma alternativa de mineração eficiente em energia baseada em Proof of Capacity como substituição completa do Proof of Work.

**Distinção Principal**: Esta é uma **nova blockchain** sem compatibilidade retroativa com o Bitcoin PoW. Blocos PoCX são incompatíveis com nós PoW por design.

---

## Identidade do Projeto

- **Organização**: Proof of Capacity Consortium
- **Nome do Projeto**: Bitcoin-PoCX
- **Nome Completo**: Bitcoin Core com Integração PoCX
- **Status**: Mainnet no Ar (desde 3 de maio de 2026)

---

## O que é Proof of Capacity?

Proof of Capacity (PoC) é um mecanismo de consenso onde o poder de mineração é proporcional ao **espaço em disco** em vez de poder computacional. Os mineradores pré-geram grandes arquivos de plot contendo hashes criptográficos e depois usam esses plots para encontrar soluções válidas de blocos.

**Eficiência Energética**: Arquivos de plot são gerados uma vez e reutilizados indefinidamente. A mineração consome potência mínima de CPU — principalmente operações de E/S em disco.

**Aprimoramentos do PoCX**:
- Correção do ataque de compressão XOR-transpose (tradeoff de 50% tempo-memória no POC2)
- Layout alinhado a 16 nonces para hardware moderno
- Proof-of-work escalável na geração de plots (níveis de escala Xn)
- Integração nativa em C++ diretamente no Bitcoin Core
- Algoritmo Time Bending para melhor distribuição de tempo de blocos

---

## Visão Geral da Arquitetura

### Estrutura do Repositório

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.2 + integração PoCX
│   └── src/pocx/        # Implementação PoCX
├── pocx/                # Framework core do PoCX (submódulo, somente leitura)
└── docs/                # Esta documentação
```

### Filosofia de Integração

**Superfície de Integração Mínima**: Alterações isoladas no diretório `/src/pocx/` com hooks limpos nas camadas de validação, mineração e RPC do Bitcoin Core.

**Feature Flagging**: Todas as modificações sob guardas de pré-processador `#ifdef ENABLE_POCX`. O Bitcoin Core compila normalmente quando desabilitado.

**Compatibilidade com Upstream**: Sincronização regular com atualizações do Bitcoin Core mantida através de pontos de integração isolados.

**Implementação Nativa em C++**: Algoritmos criptográficos escalares (Shabal256, cálculo de scoop, compressão) integrados diretamente no Bitcoin Core para validação de consenso.

---

## Recursos Principais

### 1. Substituição Completa do Consenso

- **Estrutura de Bloco**: Campos específicos do PoCX substituem nonce e difficulty bits do PoW
  - Assinatura de geração (entropia determinística de mineração)
  - Base target (inverso da dificuldade)
  - Prova PoCX (ID da conta, seed, nonce)
  - Assinatura de bloco (prova de propriedade do plot)

- **Validação**: Pipeline de validação em 5 estágios, desde verificação de cabeçalho até conexão de bloco

- **Ajuste de Dificuldade**: Ajuste a cada bloco usando média móvel de base targets recentes

### 2. Algoritmo Time Bending

**Problema**: Tempos de bloco tradicionais em PoC seguem distribuição exponencial, levando a blocos longos quando nenhum minerador encontra uma boa solução.

**Solução**: Transformação de distribuição de exponencial para qui-quadrado usando raiz cúbica: `Y = escala × (X^(1/3))`.

**Efeito**: Extremely fast blocks are delayed and extremely slow blocks are shortened, reducing variance while preserving average block time at 120 seconds.

**Detalhes**: [Capítulo 3: Consenso e Mineração](3-consensus-and-mining.md)

### 3. Sistema de Atribuição de Forja

**Capacidade**: Proprietários de plots podem delegar direitos de forja para outros endereços enquanto mantêm a propriedade do plot.

**Casos de Uso**:
- Mineração em pool (plots atribuídos ao endereço do pool)
- Armazenamento frio (chave de mineração separada da propriedade do plot)
- Mineração multipartidária (infraestrutura compartilhada)

**Arquitetura**: Design exclusivamente baseado em OP_RETURN — sem UTXOs especiais, atribuições rastreadas separadamente no banco de dados de chainstate.

**Detalhes**: [Capítulo 4: Atribuições de Forja](4-forging-assignments.md)

### 4. Forja Defensiva

**Problema**: Relógios rápidos poderiam fornecer vantagens de tempo dentro da tolerância de 15 segundos para o futuro.

**Solução**: Ao receber um bloco concorrente na mesma altura, automaticamente verifica a qualidade local. Se melhor, forja imediatamente.

**Efeito**: Elimina incentivo para manipulação de relógio — relógios rápidos só ajudam se você já tiver a melhor solução.

**Detalhes**: [Capítulo 5: Segurança de Tempo](5-timing-security.md)

### 5. Escalonamento Dinâmico de Compressão

**Alinhamento Econômico**: Requisitos de nível de escala aumentam em cronograma exponencial (Anos 4, 12, 28, 60, 124 = halvings 1, 3, 7, 15, 31).

**Efeito**: À medida que as recompensas de bloco diminuem, a dificuldade de geração de plots aumenta. Mantém margem de segurança entre custos de criação e consulta de plots.

**Previne**: Inflação de capacidade devido a hardware mais rápido ao longo do tempo.

**Detalhes**: [Capítulo 6: Parâmetros de Rede](6-network-parameters.md)

---

## Filosofia de Design

### Segurança de Código

- Práticas de programação defensiva em todo o código
- Tratamento abrangente de erros em caminhos de validação
- Sem locks aninhados (prevenção de deadlock)
- Operações atômicas de banco de dados (UTXO + atribuições juntos)

### Arquitetura Modular

- Separação limpa entre infraestrutura do Bitcoin Core e consenso PoCX
- Framework core do PoCX fornece primitivas criptográficas
- Bitcoin Core fornece framework de validação, banco de dados, rede

### Otimizações de Desempenho

- Ordenação de validação fail-fast (verificações baratas primeiro)
- Busca única de contexto por submissão (sem aquisições repetidas de cs_main)
- Operações atômicas de banco de dados para consistência

### Segurança em Reorganizações

- Dados de undo completos para mudanças de estado de atribuição
- Reset de estado de forja em mudanças de tip da cadeia
- Detecção de obsolescência em todos os pontos de validação

---

## Como o PoCX Difere do Proof of Work

| Aspecto | Bitcoin (PoW) | Bitcoin-PoCX |
|---------|---------------|--------------|
| **Recurso de Mineração** | Poder computacional (taxa de hash) | Espaço em disco (capacidade) |
| **Consumo de Energia** | Alto (hashing contínuo) | Baixo (apenas E/S em disco) |
| **Processo de Mineração** | Encontrar nonce com hash < target | Encontrar nonce com deadline < tempo decorrido |
| **Dificuldade** | Campo `bits`, ajustado a cada 2016 blocos | Campo `base_target`, ajustado a cada bloco |
| **Tempo de Bloco** | ~10 minutos (distribuição exponencial) | 120 segundos (time-bended, variância reduzida) |
| **Subsídio** | 50 BTC → 25 → 12,5 → ... | 10 BTC → 5 → 2,5 → ... |
| **Hardware** | ASICs (especializados) | HDDs (hardware comum) |
| **Identidade de Mineração** | Anônima | Proprietário do plot ou delegado |

---

## Requisitos de Sistema

### Operação de Nó

**Mesmo que o Bitcoin Core**:
- **CPU**: Processador x86_64 moderno
- **Memória**: 4-8 GB RAM
- **Armazenamento**: Nova cadeia, atualmente vazia (pode crescer ~5× mais rápido que o Bitcoin devido a blocos de 2 minutos e banco de dados de atribuições)
- **Rede**: Conexão estável com a internet
- **Relógio**: Sincronização NTP recomendada para operação ideal

**Nota**: Arquivos de plot NÃO são necessários para operação de nó.

### Requisitos de Mineração

**Requisitos adicionais para mineração**:
- **Arquivos de Plot**: Pré-gerados usando `pocx_plotter` (implementação de referência)
- **Software de Mineração**: `pocx_miner` (implementação de referência) conecta via RPC
- **Carteira**: `bitcoind` ou `bitcoin-qt` com chaves privadas para endereço de mineração. Mineração em pool não requer carteira local.

---

## Primeiros Passos

### 1. Compilar Bitcoin-PoCX

```bash
# Clone com submódulos
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Build
cmake -B build
cmake --build build
```

**Details**: See `bitcoin/doc/build-*.md` for platform-specific build instructions

### 2. Executar o Nó

**Apenas nó**:
```bash
./build/bin/bitcoind
# ou
./build/bin/bitcoin-qt
```

**Para mineração** (habilita acesso RPC para mineradores externos):
```bash
./build/bin/bitcoind
# ou
./build/bin/bitcoin-qt -server
```

**Detalhes**: [Capítulo 6: Parâmetros de Rede](6-network-parameters.md)

### 3. Gerar Arquivos de Plot

Use `pocx_plotter` (implementação de referência) para gerar arquivos de plot no formato PoCX.

**Detalhes**: [Capítulo 2: Formato de Plot](2-plot-format.md)

### 4. Configurar Mineração

Use `pocx_miner` (implementação de referência) para conectar à interface RPC do seu nó.

**Detalhes**: [Capítulo 7: Referência RPC](7-rpc-reference.md) e [Capítulo 8: Guia da Carteira](8-wallet-guide.md)

---

## Atribuição

### Formato de Plot

Baseado no formato POC2 (Burstcoin) com aprimoramentos:
- Correção de falha de segurança (ataque de compressão XOR-transpose)
- Proof-of-work escalável
- Layout otimizado para SIMD
- Funcionalidade de seed

### Projetos Fonte

- **pocx_miner**: Implementação de referência baseada no [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Implementação de referência baseada no [engraver](https://github.com/PoC-Consortium/engraver)

**Atribuição Completa**: [Capítulo 2: Formato de Plot](2-plot-format.md)

---

## Resumo das Especificações Técnicas

- **Tempo de Bloco**: 120 segundos (mainnet), 1 segundo (regtest)
- **Subsídio de Bloco**: 10 BTC inicial, halving a cada 1050000 blocos (~4 anos)
- **Oferta Total**: ~21 milhões de BTC (mesmo que Bitcoin)
- **Tolerância Futura**: 15 segundos (blocos até 15s à frente são aceitos)
- **Aviso de Relógio**: 10 segundos (alerta operadores sobre desvio de tempo)
- **Atraso de Atribuição**: 30 blocos (~1 hora)
- **Atraso de Revogação**: 720 blocos (~24 horas)
- **Formato de Endereço**: Apenas P2WPKH (bech32, pocx1q...) para operações de mineração PoCX e atribuições de forja

---

## Organização do Código

**Modificações no Bitcoin Core**: Alterações mínimas em arquivos core, sinalizadas com `#ifdef ENABLE_POCX`

**Nova Implementação PoCX**: Isolada no diretório `src/pocx/`

---

## Considerações de Segurança

### Segurança de Tempo

- Tolerância de 15 segundos para o futuro previne fragmentação de rede
- Limiar de aviso de 10 segundos alerta operadores sobre desvio de relógio
- Forja defensiva elimina incentivo para manipulação de relógio
- Time Bending reduz impacto de variância de tempo

**Detalhes**: [Capítulo 5: Segurança de Tempo](5-timing-security.md)

### Segurança de Atribuição

- Design exclusivamente OP_RETURN (sem manipulação de UTXO)
- Assinatura de transação prova propriedade do plot
- Atrasos de ativação previnem manipulação rápida de estado
- Dados de undo seguros para reorganização para todas as mudanças de estado

**Detalhes**: [Capítulo 4: Atribuições de Forja](4-forging-assignments.md)

### Segurança de Consenso

- Assinatura excluída do hash do bloco (previne maleabilidade)
- Tamanhos de assinatura limitados (previne DoS)
- Validação de limites de compressão (previne provas fracas)
- Ajuste de dificuldade a cada bloco (responsivo a mudanças de capacidade)

**Detalhes**: [Capítulo 3: Consenso e Mineração](3-consensus-and-mining.md)

---

## Status da Rede

**Mainnet**: No ar (desde 3 de maio de 2026)
**Testnet**: Disponível para testes
**Regtest**: Totalmente funcional para desenvolvimento

**Parâmetros do Bloco Gênesis**: [Capítulo 6: Parâmetros de Rede](6-network-parameters.md)

---

## Próximos Passos

**Para Entender o PoCX**: Continue para o [Capítulo 2: Formato de Plot](2-plot-format.md) para aprender sobre estrutura de arquivos de plot e evolução do formato.

**Para Configurar Mineração**: Vá para o [Capítulo 7: Referência RPC](7-rpc-reference.md) para detalhes de integração.

**Para Executar um Nó**: Revise o [Capítulo 6: Parâmetros de Rede](6-network-parameters.md) para opções de configuração.

---

[📘 Índice](index.md) | [Próximo: Formato de Plot →](2-plot-format.md)
