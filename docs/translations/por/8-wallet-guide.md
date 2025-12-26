[← Anterior: Referência RPC](7-rpc-reference.md) | [📘 Índice](index.md)

---

# Capítulo 8: Guia do Usuário da Carteira e Interface Gráfica

Guia completo para a carteira Qt do Bitcoin-PoCX e gerenciamento de atribuição de forja.

---

## Índice

1. [Visão Geral](#visão-geral)
2. [Unidades de Moeda](#unidades-de-moeda)
3. [Diálogo de Atribuição de Forja](#diálogo-de-atribuição-de-forja)
4. [Histórico de Transações](#histórico-de-transações)
5. [Requisitos de Endereço](#requisitos-de-endereço)
6. [Integração de Mineração](#integração-de-mineração)
7. [Resolução de Problemas](#resolução-de-problemas)
8. [Melhores Práticas de Segurança](#melhores-práticas-de-segurança)

---

## Visão Geral

### Recursos da Carteira Bitcoin-PoCX

A carteira Qt do Bitcoin-PoCX (`bitcoin-qt`) fornece:
- Funcionalidade padrão de carteira Bitcoin Core (enviar, receber, gerenciamento de transações)
- **Gerenciador de Atribuição de Forja**: GUI para criar/revogar atribuições de plots
- **Modo Servidor de Mineração**: Flag `-miningserver` habilita recursos relacionados a mineração
- **Histórico de Transações**: Exibição de transações de atribuição e revogação

### Iniciando a Carteira

**Apenas Nó** (sem mineração):
```bash
./build/bin/bitcoin-qt
```

**Com Mineração** (habilita diálogo de atribuição):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Alternativa de Linha de Comando**:
```bash
./build/bin/bitcoind -miningserver
```

### Requisitos de Mineração

**Para Operações de Mineração**:
- Flag `-miningserver` necessária
- Carteira com endereços P2WPKH e chaves privadas
- Plotter externo (`pocx_plotter`) para geração de plots
- Minerador externo (`pocx_miner`) para mineração

**Para Mineração em Pool**:
- Criar atribuição de forja para endereço do pool
- Carteira não necessária no servidor do pool (pool gerencia chaves)

---

## Unidades de Moeda

### Exibição de Unidade

O Bitcoin-PoCX usa a unidade de moeda **BTCX** (não BTC):

| Unidade | Satoshis | Exibição |
|---------|----------|----------|
| **BTCX** | 100000000 | 1,00000000 BTCX |
| **mBTCX** | 100000 | 1000,00 mBTCX |
| **µBTCX** | 100 | 1000000,00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**Configurações da GUI**: Preferências → Exibição → Unidade

---

## Diálogo de Atribuição de Forja

### Acessando o Diálogo

**Menu**: `Carteira → Atribuições de Forja`
**Barra de Ferramentas**: Ícone de mineração (visível apenas com flag `-miningserver`)
**Tamanho da Janela**: 600×450 pixels

### Modos do Diálogo

#### Modo 1: Criar Atribuição

**Propósito**: Delegar direitos de forja para pool ou outro endereço enquanto mantém propriedade do plot.

**Casos de Uso**:
- Mineração em pool (atribuir para endereço do pool)
- Armazenamento frio (chave de mineração separada da propriedade do plot)
- Infraestrutura compartilhada (delegar para carteira online)

**Requisitos**:
- Endereço do plot (P2WPKH bech32, deve possuir chave privada)
- Endereço de forja (P2WPKH bech32, diferente do endereço do plot)
- Carteira desbloqueada (se criptografada)
- Endereço do plot tem UTXOs confirmados

**Passos**:
1. Selecione o modo "Criar Atribuição"
2. Escolha o endereço do plot no dropdown ou insira manualmente
3. Insira o endereço de forja (pool ou delegado)
4. Clique em "Enviar Atribuição" (botão habilitado quando inputs válidos)
5. Transação transmitida imediatamente
6. Atribuição ativa após `nForgingAssignmentDelay` blocos:
   - Mainnet/Testnet: 30 blocos (~1 hora)
   - Regtest: 4 blocos (~4 segundos)

**Taxa de Transação**: Padrão 10× `minRelayFee` (personalizável)

**Estrutura de Transação**:
- Input: UTXO do endereço do plot (prova propriedade)
- Saída OP_RETURN: marcador `POCX` + plot_address + forging_address (46 bytes)
- Saída de troco: Retornado para carteira

#### Modo 2: Revogar Atribuição

**Propósito**: Cancelar atribuição de forja e retornar direitos ao proprietário do plot.

**Requisitos**:
- Endereço do plot (deve possuir chave privada)
- Carteira desbloqueada (se criptografada)
- Endereço do plot tem UTXOs confirmados

**Passos**:
1. Selecione o modo "Revogar Atribuição"
2. Escolha o endereço do plot
3. Clique em "Enviar Revogação"
4. Transação transmitida imediatamente
5. Revogação efetiva após `nForgingRevocationDelay` blocos:
   - Mainnet/Testnet: 720 blocos (~24 horas)
   - Regtest: 8 blocos (~8 segundos)

**Efeito**:
- Endereço de forja ainda pode forjar durante período de atraso
- Proprietário do plot recupera direitos após revogação completa
- Pode criar nova atribuição depois

**Estrutura de Transação**:
- Input: UTXO do endereço do plot (prova propriedade)
- Saída OP_RETURN: marcador `XCOP` + plot_address (26 bytes)
- Saída de troco: Retornado para carteira

#### Modo 3: Verificar Status de Atribuição

**Propósito**: Consultar estado atual de atribuição para qualquer endereço de plot.

**Requisitos**: Nenhum (somente leitura, sem carteira necessária)

**Passos**:
1. Selecione o modo "Verificar Status de Atribuição"
2. Insira o endereço do plot
3. Clique em "Verificar Status"
4. Caixa de status exibe estado atual com detalhes

**Indicadores de Estado** (codificados por cor):

**Cinza - UNASSIGNED**
```
UNASSIGNED - Nenhuma atribuição existe
```

**Laranja - ASSIGNING**
```
ASSIGNING - Atribuição pendente de ativação
Endereço de Forja: pocx1qforger...
Criada na altura: 12000
Ativa na altura: 12030 (5 blocos restantes)
```

**Verde - ASSIGNED**
```
ASSIGNED - Atribuição ativa
Endereço de Forja: pocx1qforger...
Criada na altura: 12000
Ativada na altura: 12030
```

**Vermelho-Laranja - REVOKING**
```
REVOKING - Revogação pendente
Endereço de Forja: pocx1qforger... (ainda ativo)
Atribuição criada na altura: 12000
Revogada na altura: 12300
Revogação efetiva na altura: 13020 (50 blocos restantes)
```

**Vermelho - REVOKED**
```
REVOKED - Atribuição revogada
Anteriormente atribuído para: pocx1qforger...
Atribuição criada na altura: 12000
Revogada na altura: 12300
Revogação efetiva na altura: 13020
```

---

## Histórico de Transações

### Exibição de Transação de Atribuição

**Tipo**: "Atribuição"
**Ícone**: Ícone de mineração (mesmo que blocos minerados)

**Coluna de Endereço**: Endereço do plot (endereço cujos direitos de forja estão sendo atribuídos)
**Coluna de Valor**: Taxa de transação (negativo, transação de saída)
**Coluna de Status**: Contagem de confirmações (0-6+)

**Detalhes** (quando clicado):
- ID da transação
- Endereço do plot
- Endereço de forja (parseado do OP_RETURN)
- Criada na altura
- Altura de ativação
- Taxa de transação
- Timestamp

### Exibição de Transação de Revogação

**Tipo**: "Revogação"
**Ícone**: Ícone de mineração

**Coluna de Endereço**: Endereço do plot
**Coluna de Valor**: Taxa de transação (negativo)
**Coluna de Status**: Contagem de confirmações

**Detalhes** (quando clicado):
- ID da transação
- Endereço do plot
- Revogada na altura
- Altura efetiva de revogação
- Taxa de transação
- Timestamp

### Filtragem de Transações

**Filtros Disponíveis**:
- "Todas" (padrão, inclui atribuições/revogações)
- Intervalo de datas
- Intervalo de valores
- Busca por endereço
- Busca por ID de transação
- Busca por rótulo (se endereço rotulado)

**Nota**: Transações de Atribuição/Revogação atualmente aparecem sob filtro "Todas". Filtro dedicado por tipo ainda não implementado.

### Ordenação de Transações

**Ordem de Ordenação** (por tipo):
- Geradas (tipo 0)
- Recebidas (tipo 1-3)
- Atribuição (tipo 4)
- Revogação (tipo 5)
- Enviadas (tipo 6+)

---

## Requisitos de Endereço

### Apenas P2WPKH (SegWit v0)

**Operações de forja requerem**:
- Endereços codificados em Bech32 (começando com "pocx1q" mainnet, "tpocx1q" testnet, "rpocx1q" regtest)
- Formato P2WPKH (Pay-to-Witness-Public-Key-Hash)
- Hash de chave de 20 bytes

**NÃO Suportados**:
- P2PKH (legado, começando com "1")
- P2SH (SegWit encapsulado, começando com "3")
- P2TR (Taproot, começando com "bc1p")

**Justificativa**: Assinaturas de bloco PoCX requerem formato específico witness v0 para validação de prova.

### Filtragem de Dropdown de Endereço

**ComboBox de Endereço do Plot**:
- Automaticamente populado com endereços de recebimento da carteira
- Filtra endereços não-P2WPKH
- Mostra formato: "Rótulo (endereço)" se rotulado, caso contrário apenas endereço
- Primeiro item: "-- Inserir endereço personalizado --" para entrada manual

**Entrada Manual**:
- Valida formato quando inserido
- Deve ser bech32 P2WPKH válido
- Botão desabilitado se formato inválido

### Mensagens de Erro de Validação

**Erros do Diálogo**:
- "Endereço do plot deve ser P2WPKH (bech32)"
- "Endereço de forja deve ser P2WPKH (bech32)"
- "Formato de endereço inválido"
- "Sem moedas disponíveis no endereço do plot. Não é possível provar propriedade."
- "Não é possível criar transações com carteira somente observação"
- "Carteira não disponível"
- "Carteira bloqueada" (do RPC)

---

## Integração de Mineração

### Requisitos de Configuração

**Configuração do Nó**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Requisitos de Carteira**:
- Endereços P2WPKH para propriedade de plot
- Chaves privadas para mineração (ou endereço de forja se usando atribuições)
- UTXOs confirmados para criação de transação

**Ferramentas Externas**:
- `pocx_plotter`: Gerar arquivos de plot
- `pocx_miner`: Escanear plots e submeter nonces

### Fluxo de Trabalho

#### Mineração Solo

1. **Gerar Arquivos de Plot**:
   ```bash
   pocx_plotter --account <hash160_endereco_plot> --seed <32_bytes> --nonces <contagem>
   ```

2. **Iniciar Nó** com servidor de mineração:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Configurar Minerador**:
   - Apontar para endpoint RPC do nó
   - Especificar diretórios de arquivos de plot
   - Configurar account ID (do endereço do plot)

4. **Iniciar Mineração**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /caminho/para/plots
   ```

5. **Monitorar**:
   - Minerador chama `get_mining_info` a cada bloco
   - Escaneia plots para melhor deadline
   - Chama `submit_nonce` quando solução encontrada
   - Nó valida e forja bloco automaticamente

#### Mineração em Pool

1. **Gerar Arquivos de Plot** (mesmo que mineração solo)

2. **Criar Atribuição de Forja**:
   - Abrir Diálogo de Atribuição de Forja
   - Selecionar endereço do plot
   - Inserir endereço de forja do pool
   - Clicar em "Enviar Atribuição"
   - Aguardar atraso de ativação (30 blocos testnet)

3. **Configurar Minerador**:
   - Apontar para endpoint do **pool** (não nó local)
   - Pool trata `submit_nonce` para cadeia

4. **Operação do Pool**:
   - Carteira do pool tem chaves privadas do endereço de forja
   - Pool valida submissões de mineradores
   - Pool chama `submit_nonce` para blockchain
   - Pool distribui recompensas conforme política do pool

### Recompensas Coinbase

**Sem Atribuição**:
- Coinbase paga diretamente ao endereço do proprietário do plot
- Verificar saldo no endereço do plot

**Com Atribuição**:
- Coinbase paga ao endereço de forja
- Pool recebe recompensas
- Minerador recebe parte do pool

**Cronograma de Recompensa**:
- Inicial: 10 BTCX por bloco
- Halving: A cada 1050000 blocos (~4 anos)
- Cronograma: 10 → 5 → 2,5 → 1,25 → ...

---

## Resolução de Problemas

### Problemas Comuns

#### "Carteira não possui chave privada para endereço do plot"

**Causa**: Carteira não é dona do endereço
**Solução**:
- Importar chave privada via RPC `importprivkey`
- Ou usar endereço de plot diferente que a carteira possui

#### "Atribuição já existe para este plot"

**Causa**: Plot já atribuído para outro endereço
**Solução**:
1. Revogar atribuição existente
2. Aguardar atraso de revogação (720 blocos testnet)
3. Criar nova atribuição

#### "Formato de endereço não suportado"

**Causa**: Endereço não é P2WPKH bech32
**Solução**:
- Usar endereços começando com "pocx1q" (mainnet) ou "tpocx1q" (testnet)
- Gerar novo endereço se necessário: `getnewaddress "" "bech32"`

#### "Taxa de transação muito baixa"

**Causa**: Congestionamento do mempool de rede ou taxa muito baixa para relay
**Solução**:
- Aumentar parâmetro de taxa
- Aguardar limpeza do mempool

#### "Atribuição ainda não ativa"

**Causa**: Atraso de ativação ainda não expirou
**Solução**:
- Verificar status: blocos restantes até ativação
- Aguardar período de atraso completar

#### "Sem moedas disponíveis no endereço do plot"

**Causa**: Endereço do plot não tem UTXOs confirmados
**Solução**:
1. Enviar fundos para endereço do plot
2. Aguardar 1 confirmação
3. Tentar novamente criação de atribuição

#### "Não é possível criar transações com carteira somente observação"

**Causa**: Carteira importou endereço sem chave privada
**Solução**: Importar chave privada completa, não apenas endereço

#### "Aba de Atribuição de Forja não visível"

**Causa**: Nó iniciado sem flag `-miningserver`
**Solução**: Reiniciar com `bitcoin-qt -server -miningserver`

### Passos de Depuração

1. **Verificar Status da Carteira**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Verificar Propriedade de Endereço**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Verificar: "iswatchonly": false, "ismine": true
   ```

3. **Verificar Status de Atribuição**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Ver Transações Recentes**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Verificar Sincronização do Nó**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Verificar: blocks == headers (totalmente sincronizado)
   ```

---

## Melhores Práticas de Segurança

### Segurança do Endereço do Plot

**Gerenciamento de Chaves**:
- Armazenar chaves privadas do endereço do plot com segurança
- Transações de atribuição provam propriedade via assinatura
- Apenas proprietário do plot pode criar/revogar atribuições

**Backup**:
- Fazer backup da carteira regularmente (`dumpwallet` ou `backupwallet`)
- Armazenar wallet.dat em local seguro
- Registrar frases de recuperação se usando carteira HD

### Delegação de Endereço de Forja

**Modelo de Segurança**:
- Endereço de forja recebe recompensas de bloco
- Endereço de forja pode assinar blocos (mineração)
- Endereço de forja **não pode** modificar ou revogar atribuição
- Proprietário do plot mantém controle total

**Casos de Uso**:
- **Delegação de Carteira Online**: Chave do plot em armazenamento frio, chave de forja em carteira online para mineração
- **Mineração em Pool**: Delegar para pool, manter propriedade do plot
- **Infraestrutura Compartilhada**: Múltiplos mineradores, um endereço de forja

### Sincronização de Tempo de Rede

**Importância**:
- Consenso PoCX requer tempo preciso
- Desvio de relógio >10s dispara aviso
- Desvio de relógio >15s impede mineração

**Solução**:
- Manter relógio do sistema sincronizado com NTP
- Monitorar: `bitcoin-cli getnetworkinfo` para avisos de offset de tempo
- Usar servidores NTP confiáveis

### Atrasos de Atribuição

**Atraso de Ativação** (30 blocos testnet):
- Previne reatribuição rápida durante forks de cadeia
- Permite rede atingir consenso
- Não pode ser contornado

**Atraso de Revogação** (720 blocos testnet):
- Fornece estabilidade para pools de mineração
- Previne ataques de "griefing" de atribuição
- Endereço de forja permanece ativo durante atraso

### Criptografia de Carteira

**Habilitar Criptografia**:
```bash
bitcoin-cli encryptwallet "sua_frase_secreta"
```

**Desbloquear para Transações**:
```bash
bitcoin-cli walletpassphrase "sua_frase_secreta" 300
```

**Melhores Práticas**:
- Usar frase secreta forte (20+ caracteres)
- Não armazenar frase secreta em texto simples
- Bloquear carteira após criar atribuições

---

## Referências de Código

**Diálogo de Atribuição de Forja**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Exibição de Transação**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Parsing de Transação**: `src/qt/transactionrecord.cpp`
**Integração de Carteira**: `src/pocx/assignments/transactions.cpp`
**RPCs de Atribuição**: `src/pocx/rpc/assignments_wallet.cpp`
**Main da GUI**: `src/qt/bitcoingui.cpp`

---

## Referências Cruzadas

Capítulos relacionados:
- [Capítulo 3: Consenso e Mineração](3-consensus-and-mining.md) - Processo de mineração
- [Capítulo 4: Atribuições de Forja](4-forging-assignments.md) - Arquitetura de atribuição
- [Capítulo 6: Parâmetros de Rede](6-network-parameters.md) - Valores de atraso de atribuição
- [Capítulo 7: Referência RPC](7-rpc-reference.md) - Detalhes de comandos RPC

---

[← Anterior: Referência RPC](7-rpc-reference.md) | [📘 Índice](index.md)
