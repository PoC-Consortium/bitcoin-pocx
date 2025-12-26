[← Anterior: Sincronização de Tempo](5-timing-security.md) | [📘 Índice](index.md) | [Próximo: Referência RPC →](7-rpc-reference.md)

---

# Capítulo 6: Parâmetros de Rede e Configuração

Referência completa para configuração de rede do Bitcoin-PoCX em todos os tipos de rede.

---

## Índice

1. [Parâmetros do Bloco Gênesis](#parâmetros-do-bloco-gênesis)
2. [Configuração de Chainparams](#configuração-de-chainparams)
3. [Parâmetros de Consenso](#parâmetros-de-consenso)
4. [Coinbase e Recompensas de Bloco](#coinbase-e-recompensas-de-bloco)
5. [Escalonamento Dinâmico](#escalonamento-dinâmico)
6. [Configuração de Rede](#configuração-de-rede)
7. [Estrutura do Diretório de Dados](#estrutura-do-diretório-de-dados)

---

## Parâmetros do Bloco Gênesis

### Cálculo do Base Target

**Fórmula**: `genesis_base_target = 2^42 / block_time_seconds`

**Justificativa**:
- Cada nonce representa 256 KiB (64 bytes × 4096 scoops)
- 1 TiB = 2^22 nonces (suposição de capacidade inicial da rede)
- Qualidade mínima esperada para n nonces ≈ 2^64 / n
- Para 1 TiB: E(quality) = 2^64 / 2^22 = 2^42
- Portanto: base_target = 2^42 / block_time

**Valores Calculados**:
- Mainnet/Testnet/Signet (120s): `36650387592`
- Regtest (1s): Usa modo de calibração de baixa capacidade

### Mensagem do Gênesis

Todas as redes compartilham a mensagem do gênesis do Bitcoin:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Implementação**: `src/kernel/chainparams.cpp`

---

## Configuração de Chainparams

### Parâmetros da Mainnet

**Identidade de Rede**:
- **Magic Bytes**: `0xa7 0x3c 0x91 0x5e`
- **Porta Padrão**: `8888`
- **HRP Bech32**: `pocx`

**Prefixos de Endereço** (Base58):
- PUBKEY_ADDRESS: `85` (endereços começam com 'P')
- SCRIPT_ADDRESS: `90` (endereços começam com 'R')
- SECRET_KEY: `128`

**Timing de Blocos**:
- **Tempo Alvo de Bloco**: `120` segundos (2 minutos)
- **Timespan Alvo**: `1209600` segundos (14 dias)
- **MAX_FUTURE_BLOCK_TIME**: `15` segundos

**Recompensas de Bloco**:
- **Subsídio Inicial**: `10 BTC`
- **Intervalo de Halving**: `1050000` blocos (~4 anos)
- **Contagem de Halvings**: 64 halvings máximo

**Ajuste de Dificuldade**:
- **Janela Móvel**: `24` blocos
- **Ajuste**: A cada bloco
- **Algoritmo**: Média móvel exponencial

**Atrasos de Atribuição**:
- **Ativação**: `30` blocos (~1 hora)
- **Revogação**: `720` blocos (~24 horas)

### Parâmetros da Testnet

**Identidade de Rede**:
- **Magic Bytes**: `0x6d 0xf2 0x48 0xb3`
- **Porta Padrão**: `18888`
- **HRP Bech32**: `tpocx`

**Prefixos de Endereço** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Timing de Blocos**:
- **Tempo Alvo de Bloco**: `120` segundos
- **MAX_FUTURE_BLOCK_TIME**: `15` segundos
- **Permitir Dificuldade Mínima**: `true`

**Recompensas de Bloco**:
- **Subsídio Inicial**: `10 BTC`
- **Intervalo de Halving**: `1050000` blocos

**Ajuste de Dificuldade**:
- **Janela Móvel**: `24` blocos

**Atrasos de Atribuição**:
- **Ativação**: `30` blocos (~1 hora)
- **Revogação**: `720` blocos (~24 horas)

### Parâmetros do Regtest

**Identidade de Rede**:
- **Magic Bytes**: `0xfa 0xbf 0xb5 0xda`
- **Porta Padrão**: `18444`
- **HRP Bech32**: `rpocx`

**Prefixos de Endereço** (compatível com Bitcoin):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Timing de Blocos**:
- **Tempo Alvo de Bloco**: `1` segundo (mineração instantânea para testes)
- **Timespan Alvo**: `86400` segundos (1 dia)
- **MAX_FUTURE_BLOCK_TIME**: `15` segundos

**Recompensas de Bloco**:
- **Subsídio Inicial**: `10 BTC`
- **Intervalo de Halving**: `500` blocos

**Ajuste de Dificuldade**:
- **Janela Móvel**: `24` blocos
- **Permitir Dificuldade Mínima**: `true`
- **Sem Retargeting**: `true`
- **Calibração de Baixa Capacidade**: `true` (usa calibração de 16 nonces em vez de 1 TiB)

**Atrasos de Atribuição**:
- **Ativação**: `4` blocos (~4 segundos)
- **Revogação**: `8` blocos (~8 segundos)

### Parâmetros do Signet

**Identidade de Rede**:
- **Magic Bytes**: Primeiros 4 bytes de SHA256d(signet_challenge)
- **Porta Padrão**: `38333`
- **HRP Bech32**: `tpocx`

**Timing de Blocos**:
- **Tempo Alvo de Bloco**: `120` segundos
- **MAX_FUTURE_BLOCK_TIME**: `15` segundos

**Recompensas de Bloco**:
- **Subsídio Inicial**: `10 BTC`
- **Intervalo de Halving**: `1050000` blocos

**Ajuste de Dificuldade**:
- **Janela Móvel**: `24` blocos

---

## Parâmetros de Consenso

### Parâmetros de Timing

**MAX_FUTURE_BLOCK_TIME**: `15` segundos
- Específico do PoCX (Bitcoin usa 2 horas)
- Justificativa: Timing de PoC requer validação quase em tempo real
- Blocos mais de 15s no futuro são rejeitados

**Aviso de Offset de Tempo**: `10` segundos
- Operadores são avisados quando relógio do nó desvia >10s do tempo de rede
- Sem enforcement, apenas informativo

**Alvos de Tempo de Bloco**:
- Mainnet/Testnet/Signet: `120` segundos
- Regtest: `1` segundo

**TIMESTAMP_WINDOW**: `15` segundos (igual a MAX_FUTURE_BLOCK_TIME)

**Implementação**: `src/chain.h`, `src/validation.cpp`

### Parâmetros de Ajuste de Dificuldade

**Tamanho da Janela Móvel**: `24` blocos (todas as redes)
- Média móvel exponencial de tempos de blocos recentes
- Ajuste a cada bloco
- Responsivo a mudanças de capacidade

**Implementação**: `src/consensus/params.h`, lógica de dificuldade na criação de blocos

### Parâmetros do Sistema de Atribuição

**nForgingAssignmentDelay** (atraso de ativação):
- Mainnet: `30` blocos (~1 hora)
- Testnet: `30` blocos (~1 hora)
- Regtest: `4` blocos (~4 segundos)

**nForgingRevocationDelay** (atraso de revogação):
- Mainnet: `720` blocos (~24 horas)
- Testnet: `720` blocos (~24 horas)
- Regtest: `8` blocos (~8 segundos)

**Justificativa**:
- Atraso de ativação previne reatribuição rápida durante disputas de blocos
- Atraso de revogação fornece estabilidade e previne abuso

**Implementação**: `src/consensus/params.h`

---

## Coinbase e Recompensas de Bloco

### Cronograma de Subsídio de Bloco

**Subsídio Inicial**: `10 BTC` (todas as redes)

**Cronograma de Halving**:
- A cada `1050000` blocos (mainnet/testnet)
- A cada `500` blocos (regtest)
- Continua por 64 halvings máximo

**Progressão de Halving**:
```
Halving 0: 10,00000000 BTC  (blocos 0 - 1049999)
Halving 1:  5,00000000 BTC  (blocos 1050000 - 2099999)
Halving 2:  2,50000000 BTC  (blocos 2100000 - 3149999)
Halving 3:  1,25000000 BTC  (blocos 3150000 - 4199999)
...
```

**Oferta Total**: ~21 milhões de BTC (mesmo que Bitcoin)

### Regras de Saída do Coinbase

**Destino de Pagamento**:
- **Sem Atribuição**: Coinbase paga ao endereço do plot (proof.account_id)
- **Com Atribuição**: Coinbase paga ao endereço de forja (signatário efetivo)

**Formato de Saída**: Apenas P2WPKH
- Coinbase deve pagar para endereço bech32 SegWit v0
- Gerado a partir da chave pública do signatário efetivo

**Resolução de Atribuição**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implementação**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Escalonamento Dinâmico

### Limites de Escala

**Propósito**: Aumentar dificuldade de geração de plots conforme a rede amadurece para prevenir inflação de capacidade

**Estrutura**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Nível mínimo aceito
    uint8_t nPoCXTargetCompression;  // Nível recomendado
};
```

**Relação**: `target = min + 1` (sempre um nível acima do mínimo)

### Cronograma de Aumento de Escala

Níveis de escala aumentam em **cronograma exponencial** baseado em intervalos de halving:

| Período | Altura do Bloco | Halvings | Mín | Alvo |
|---------|-----------------|----------|-----|------|
| Anos 0-4 | 0 a 1049999 | 0 | X1 | X2 |
| Anos 4-12 | 1050000 a 3149999 | 1-2 | X2 | X3 |
| Anos 12-28 | 3150000 a 7349999 | 3-6 | X3 | X4 |
| Anos 28-60 | 7350000 a 15749999 | 7-14 | X4 | X5 |
| Anos 60-124 | 15750000 a 32549999 | 15-30 | X5 | X6 |
| Anos 124+ | 32550000+ | 31+ | X6 | X7 |

**Alturas Chave** (anos → halvings → blocos):
- Ano 4: Halving 1 no bloco 1050000
- Ano 12: Halving 3 no bloco 3150000
- Ano 28: Halving 7 no bloco 7350000
- Ano 60: Halving 15 no bloco 15750000
- Ano 124: Halving 31 no bloco 32550000

### Dificuldade de Nível de Escala

**Escalonamento de PoW**:
- Nível de escala X0: Baseline POC2 (teórico)
- Nível de escala X1: Baseline XOR-transpose
- Nível de escala Xn: 2^(n-1) × trabalho X1 embutido
- Cada nível dobra o trabalho de geração de plot

**Alinhamento Econômico**:
- Recompensas de bloco são reduzidas pela metade → dificuldade de geração de plot aumenta
- Mantém margem de segurança: custo de criação de plot > custo de consulta
- Previne inflação de capacidade por melhorias de hardware

### Validação de Plot

**Regras de Validação**:
- Provas submetidas devem ter nível de escala ≥ mínimo
- Provas com escala > alvo são aceitas mas ineficientes
- Provas abaixo do mínimo: rejeitadas (PoW insuficiente)

**Recuperação de Limites**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implementação**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Configuração de Rede

### Nós Seed e Seeds DNS

**Status**: Placeholder para lançamento da mainnet

**Configuração Planejada**:
- Nós seed: A ser definido
- Seeds DNS: A ser definido

**Estado Atual** (testnet/regtest):
- Sem infraestrutura de seed dedicada
- Conexões manuais de peers suportadas via `-addnode`

**Implementação**: `src/kernel/chainparams.cpp`

### Checkpoints

**Checkpoint do Gênesis**: Sempre bloco 0

**Checkpoints Adicionais**: Nenhum configurado atualmente

**Futuro**: Checkpoints serão adicionados conforme a mainnet progride

---

## Configuração do Protocolo P2P

### Versão do Protocolo

**Base**: Protocolo do Bitcoin Core v30.0
- **Versão do Protocolo**: Herdada do Bitcoin Core
- **Bits de Serviço**: Serviços padrão do Bitcoin
- **Tipos de Mensagem**: Mensagens P2P padrão do Bitcoin

**Extensões PoCX**:
- Cabeçalhos de bloco incluem campos específicos do PoCX
- Mensagens de bloco incluem dados de prova PoCX
- Regras de validação aplicam consenso PoCX

**Compatibilidade**: Nós PoCX incompatíveis com nós Bitcoin PoW (consenso diferente)

**Implementação**: `src/protocol.h`, `src/net_processing.cpp`

---

## Estrutura do Diretório de Dados

### Diretório Padrão

**Localização**: `.bitcoin/` (mesmo que Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Conteúdo do Diretório

```
.bitcoin/
├── blocks/              # Dados de blocos
│   ├── blk*.dat        # Arquivos de blocos
│   ├── rev*.dat        # Dados de undo
│   └── index/          # Índice de blocos (LevelDB)
├── chainstate/         # Conjunto UTXO + atribuições de forja (LevelDB)
├── wallets/            # Arquivos de carteira
│   └── wallet.dat      # Carteira padrão
├── bitcoin.conf        # Arquivo de configuração
├── debug.log           # Log de depuração
├── peers.dat           # Endereços de peers
├── mempool.dat         # Persistência do mempool
└── banlist.dat         # Peers banidos
```

### Diferenças Principais do Bitcoin

**Banco de Dados Chainstate**:
- Padrão: Conjunto UTXO
- **Adição PoCX**: Estado de atribuição de forja
- Atualizações atômicas: UTXO + atribuições atualizados juntos
- Dados de undo seguros para reorganização para atribuições

**Arquivos de Bloco**:
- Formato de bloco padrão do Bitcoin
- **Adição PoCX**: Estendido com campos de prova PoCX (account_id, seed, nonce, signature, pubkey)

### Exemplo de Arquivo de Configuração

**bitcoin.conf**:
```ini
# Seleção de rede
#testnet=1
#regtest=1

# Servidor de mineração PoCX (necessário para mineradores externos)
miningserver=1

# Configurações RPC
server=1
rpcuser=seuusuario
rpcpassword=suasenha
rpcallowip=127.0.0.1
rpcport=8332

# Configurações de conexão
listen=1
port=8888
maxconnections=125

# Alvo de tempo de bloco (informativo, consenso é aplicado)
# 120 segundos para mainnet/testnet
```

---

## Referências de Código

**Chainparams**: `src/kernel/chainparams.cpp`
**Parâmetros de Consenso**: `src/consensus/params.h`
**Limites de Compressão**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Cálculo de Base Target do Gênesis**: `src/pocx/consensus/params.cpp`
**Lógica de Pagamento Coinbase**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Armazenamento de Estado de Atribuição**: `src/coins.h`, `src/coins.cpp` (extensões CCoinsViewCache)

---

## Referências Cruzadas

Capítulos relacionados:
- [Capítulo 2: Formato de Plot](2-plot-format.md) - Níveis de escala na geração de plots
- [Capítulo 3: Consenso e Mineração](3-consensus-and-mining.md) - Validação de escala, sistema de atribuição
- [Capítulo 4: Atribuições de Forja](4-forging-assignments.md) - Parâmetros de atraso de atribuição
- [Capítulo 5: Segurança de Tempo](5-timing-security.md) - Justificativa de MAX_FUTURE_BLOCK_TIME

---

[← Anterior: Sincronização de Tempo](5-timing-security.md) | [📘 Índice](index.md) | [Próximo: Referência RPC →](7-rpc-reference.md)
