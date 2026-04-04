[← Anterior: Parâmetros de Rede](6-network-parameters.md) | [📘 Índice](index.md) | [Próximo: Guia da Carteira →](8-wallet-guide.md)

---

# Capítulo 7: Referência da Interface RPC

Referência completa para comandos RPC do Bitcoin-PoCX, incluindo RPCs de mineração, gerenciamento de atribuições e RPCs de blockchain modificados.

---

## Índice

1. [Configuração](#configuração)
2. [RPCs de Mineração PoCX](#rpcs-de-mineração-pocx)
3. [RPCs de Atribuição](#rpcs-de-atribuição)
4. [RPCs de Blockchain Modificados](#rpcs-de-blockchain-modificados)
5. [RPCs Desabilitados](#rpcs-desabilitados)
6. [Exemplos de Integração](#exemplos-de-integração)

---

## Configuração

### Modo Servidor de Mineração

**Flag**: ``

**Propósito**: Habilita acesso RPC para mineradores externos chamarem RPCs específicos de mineração

**Requisitos**:
- Necessário para `submit_nonce` funcionar
- Necessário para visibilidade do diálogo de atribuição de forja na carteira Qt

**Uso**:
```bash
# Linha de comando
./bitcoind

# bitcoin.conf
```

**Considerações de Segurança**:
- Sem autenticação adicional além de credenciais RPC padrão
- RPCs de mineração são limitados pela capacidade da fila
- Autenticação RPC padrão ainda é necessária

**Implementação**: `src/pocx/rpc/mining.cpp`

---

## RPCs de Mineração PoCX

### get_mining_info

**Categoria**: mining
**Requer Servidor de Mineração**: Não
**Requer Carteira**: Não

**Propósito**: Retorna parâmetros de mineração atuais necessários para mineradores externos escanearem arquivos de plot e calcularem deadlines.

**Parâmetros**: Nenhum

**Valores de Retorno**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 caracteres
  "base_target": 36650387592,                // numérico
  "height": 12345,                           // numérico, altura do próximo bloco
  "block_hash": "def456...",                 // hex, bloco anterior
  "target_quality": 18446744073709551615,    // uint64_max (todas as soluções aceitas)
  "minimum_compression_level": 1,            // numérico
  "target_compression_level": 2              // numérico
}
```

**Descrições dos Campos**:
- `generation_signature`: Entropia determinística de mineração para esta altura de bloco
- `base_target`: Dificuldade atual (maior = mais fácil)
- `height`: Altura do bloco que mineradores devem mirar
- `block_hash`: Hash do bloco anterior (informativo)
- `target_quality`: Limiar de qualidade (atualmente uint64_max, sem filtragem)
- `minimum_compression_level`: Compressão mínima necessária para validação
- `target_compression_level`: Compressão recomendada para mineração ideal

**Códigos de Erro**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Nó ainda sincronizando

**Exemplo**:
```bash
bitcoin-cli get_mining_info
```

**Implementação**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Categoria**: mining
**Requer Servidor de Mineração**: Sim
**Requer Carteira**: Sim (para chaves privadas)

**Propósito**: Submeter uma solução de mineração PoCX. Valida prova, enfileira para forja com time bending e automaticamente cria bloco no tempo agendado.

**Parameters**:
1. `block_hash` (string hex, required) - Previous block hash
2. `height` (numeric, required) - Block height
3. `generation_signature` (string hex, required) - Generation signature (64 characters)
4. `base_target` (numeric, required) - Base target for this block
5. `account_id` (string, required) - Account ID (20-byte hex or address)
6. `seed` (string, required) - Plot seed (64 hex characters = 32 bytes)
7. `nonce` (numeric, required) - Mining nonce
8. `compression` (numeric, required) - Compression level used (1-6)
9. `raw_quality` (numeric, required) - Raw quality from proof validation

**Valores de Retorno** (sucesso):
```json
{
  "accepted": true,
  "quality": 120,           // deadline ajustado por dificuldade em segundos
  "poc_time": 45            // tempo de forja time-bended em segundos
}
```

**Valores de Retorno** (rejeitado):
```json
{
  "accepted": false,
  "error": "Incompatibilidade de assinatura de geração"
}
```

**Passos de Validação**:
1. **Validação de Formato** (fail-fast):
   - Account ID: exatamente 40 caracteres hex
   - Seed: exatamente 64 caracteres hex
2. **Validação de Contexto**:
   - Altura deve corresponder a tip atual + 1
   - Assinatura de geração deve corresponder à atual
3. **Verificação de Carteira**:
   - Determinar signatário efetivo (verificar atribuições ativas)
   - Verificar que carteira tem chave privada para signatário efetivo
4. **Validação de Prova** (cara):
   - Validar prova PoCX com limites de compressão
   - Calcular qualidade bruta
5. **Submissão ao Scheduler**:
   - Enfileirar nonce para forja time-bended
   - Bloco será criado automaticamente em forge_time

**Códigos de Erro**:
- `RPC_INVALID_PARAMETER`: Formato inválido (account_id, seed) ou incompatibilidade de altura
- `RPC_VERIFY_REJECTED`: Incompatibilidade de assinatura de geração ou validação de prova falhou
- `RPC_INVALID_ADDRESS_OR_KEY`: Sem chave privada para signatário efetivo
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Fila de submissão cheia
- `RPC_INTERNAL_ERROR`: Falha ao inicializar scheduler PoCX

**Códigos de Erro de Validação de Prova**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Exemplo**:
```bash
bitcoin-cli submit_nonce \
  "blockhash..." \
  12345 \
  "gensig..." \
  18325193796 \
  "1234567890abcdef1234567890abcdef12345678" \
  "seed..." \
  999888777 \
  1 \
  123456789
```

**Notas**:
- Submissão é assíncrona - RPC retorna imediatamente, bloco forjado depois
- Time Bending atrasa boas soluções para permitir escaneamento de plots em toda a rede
- Sistema de atribuição: se plot atribuído, carteira deve ter chave do endereço de forja
- Limites de compressão ajustados dinamicamente baseado na altura do bloco

**Implementação**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## RPCs de Atribuição

### get_assignment

**Categoria**: mining
**Requer Servidor de Mineração**: Não
**Requer Carteira**: Não

**Propósito**: Consultar status de atribuição de forja para um endereço de plot. Somente leitura, sem carteira necessária.

**Parâmetros**:
1. `plot_address` (string, obrigatório) - Endereço do plot (formato P2WPKH bech32)
2. `height` (numérico, opcional) - Altura do bloco para consulta (padrão: tip atual)

**Valores de Retorno** (sem atribuição):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Valores de Retorno** (atribuição ativa):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030
}
```

**Valores de Retorno** (revogando):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "REVOKING",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030,
  "revoked": true,
  "revocation_txid": "def456...",
  "revocation_height": 12300,
  "revocation_effective_height": 13020
}
```

**Estados de Atribuição**:
- `UNASSIGNED`: Nenhuma atribuição existe
- `ASSIGNING`: Tx de atribuição confirmada, atraso de ativação em andamento
- `ASSIGNED`: Atribuição ativa, direitos de forja delegados
- `REVOKING`: Tx de revogação confirmada, ainda ativa até atraso expirar
- `REVOKED`: Revogação completa, direitos de forja retornados ao proprietário do plot

**Códigos de Erro**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Endereço inválido ou não P2WPKH (bech32)

**Exemplo**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Implementação**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Categoria**: wallet
**Requer Servidor de Mineração**: Não
**Requer Carteira**: Sim (deve estar carregada e desbloqueada)

**Propósito**: Criar transação de atribuição de forja para delegar direitos de forja para outro endereço (ex: pool de mineração).

**Parâmetros**:
1. `plot_address` (string, obrigatório) - Endereço do proprietário do plot (deve possuir chave privada, P2WPKH bech32)
2. `forging_address` (string, obrigatório) - Endereço para atribuir direitos de forja (P2WPKH bech32)
3. `fee_rate` (numérico, opcional) - Taxa em BTC/kvB (padrão: 10× minRelayFee)

**Valores de Retorno**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Requisitos**:
- Carteira carregada e desbloqueada
- Chave privada para plot_address na carteira
- Ambos os endereços devem ser P2WPKH (formato bech32: pocx1q... mainnet, tpocx1q... testnet)
- Endereço do plot deve ter UTXOs confirmados (prova propriedade)
- Plot não deve ter atribuição ativa (use revoke primeiro)

**Estrutura de Transação**:
- Input: UTXO do endereço do plot (prova propriedade)
- Output: OP_RETURN (46 bytes): marcador `POCX` + plot_address (20 bytes) + forging_address (20 bytes)
- Output: Troco retornado para carteira

**Ativação**:
- Atribuição se torna ASSIGNING na confirmação
- Torna-se ACTIVE após `nForgingAssignmentDelay` blocos
- Atraso previne reatribuição rápida durante forks da cadeia

**Códigos de Erro**:
- `RPC_WALLET_NOT_FOUND`: Nenhuma carteira disponível
- `RPC_WALLET_UNLOCK_NEEDED`: Carteira criptografada e bloqueada
- `RPC_WALLET_ERROR`: Criação de transação falhou
- `RPC_INVALID_ADDRESS_OR_KEY`: Formato de endereço inválido

**Exemplo**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Implementação**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Categoria**: wallet
**Requer Servidor de Mineração**: Não
**Requer Carteira**: Sim (deve estar carregada e desbloqueada)

**Propósito**: Revogar atribuição de forja existente, retornando direitos de forja ao proprietário do plot.

**Parâmetros**:
1. `plot_address` (string, obrigatório) - Endereço do plot (deve possuir chave privada, P2WPKH bech32)
2. `fee_rate` (numérico, opcional) - Taxa em BTC/kvB (padrão: 10× minRelayFee)

**Valores de Retorno**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Requisitos**:
- Carteira carregada e desbloqueada
- Chave privada para plot_address na carteira
- Endereço do plot deve ser P2WPKH (formato bech32)
- Endereço do plot deve ter UTXOs confirmados

**Estrutura de Transação**:
- Input: UTXO do endereço do plot (prova propriedade)
- Output: OP_RETURN (26 bytes): marcador `XCOP` + plot_address (20 bytes)
- Output: Troco retornado para carteira

**Efeito**:
- Estado transiciona para REVOKING imediatamente
- Endereço de forja ainda pode forjar durante período de atraso
- Torna-se REVOKED após `nForgingRevocationDelay` blocos
- Proprietário do plot pode forjar após revogação efetiva
- Pode criar nova atribuição após revogação completa

**Códigos de Erro**:
- `RPC_WALLET_NOT_FOUND`: Nenhuma carteira disponível
- `RPC_WALLET_UNLOCK_NEEDED`: Carteira criptografada e bloqueada
- `RPC_WALLET_ERROR`: Criação de transação falhou

**Exemplo**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Notas**:
- Idempotente: pode revogar mesmo se não houver atribuição ativa
- Não pode cancelar revogação uma vez submetida

**Implementação**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## RPCs de Blockchain Modificados

### getdifficulty

**Modificações PoCX**:
- **Cálculo**: `reference_base_target / current_base_target`
- **Referência**: Capacidade de rede de 1 TiB (base_target = 36650387592)
- **Interpretação**: Capacidade estimada de armazenamento da rede em TiB
  - Exemplo: `1.0` = ~1 TiB
  - Exemplo: `1024.0` = ~1 PiB
- **Diferença do PoW**: Representa capacidade, não poder de hash

**Exemplo**:
```bash
bitcoin-cli getdifficulty
# Retorna: 2048.5 (rede ~2 PiB)
```

**Implementação**: `src/rpc/blockchain.cpp`

---

### getblockheader

**Campos Adicionados pelo PoCX**:
- `time_since_last_block` (numérico) - Segundos desde bloco anterior (substitui mediantime)
- `poc_time` (numérico) - Tempo de forja time-bended em segundos
- `base_target` (numérico) - Base target de dificuldade PoCX
- `generation_signature` (string hex) - Assinatura de geração
- `pocx_proof` (objeto):
  - `account_id` (string hex) - ID de conta do plot (20 bytes)
  - `seed` (string hex) - Seed do plot (32 bytes)
  - `nonce` (numérico) - Nonce de mineração
  - `compression` (numérico) - Nível de escala usado
  - `quality` (numérico) - Valor de qualidade reivindicado
- `pubkey` (string hex) - Chave pública do signatário do bloco (33 bytes)
- `signer_address` (string) - Endereço do signatário do bloco
- `signature` (string hex) - Assinatura do bloco (65 bytes)

**Campos Removidos pelo PoCX**:
- `mediantime` - Removido (substituído por time_since_last_block)

**Exemplo**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Implementação**: `src/rpc/blockchain.cpp`

---

### getblock

**Modificações PoCX**: Mesmo que getblockheader, mais dados completos de transação

**Exemplo**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbose com detalhes de tx
```

**Implementação**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**Campos Adicionados pelo PoCX**:
- `base_target` (numérico) - Base target atual
- `generation_signature` (string hex) - Assinatura de geração atual

**Campos Modificados pelo PoCX**:
- `difficulty` - Usa cálculo PoCX (baseado em capacidade)

**Campos Removidos pelo PoCX**:
- `mediantime` - Removido

**Exemplo**:
```bash
bitcoin-cli getblockchaininfo
```

**Implementação**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**Campos Adicionados pelo PoCX**:
- `generation_signature` (string hex) - Para mineração em pool
- `base_target` (numérico) - Para mineração em pool

**Campos Removidos pelo PoCX**:
- `target` - Removido (específico de PoW)
- `noncerange` - Removido (específico de PoW)
- `bits` - Removido (específico de PoW)

**Notas**:
- Ainda inclui dados completos de transação para construção de bloco
- Usado por servidores de pool para mineração coordenada

**Exemplo**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Implementação**: `src/rpc/mining.cpp`

---

## RPCs Desabilitados

Os seguintes RPCs específicos de PoW são **desabilitados** no modo PoCX:

### getnetworkhashps
- **Motivo**: Taxa de hash não aplicável a Proof of Capacity
- **Alternativa**: Use `getdifficulty` para estimativa de capacidade de rede

### getmininginfo
- **Motivo**: Retorna informações específicas de PoW
- **Alternativa**: Use `get_mining_info` (específico do PoCX)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Status**: Available as hidden commands (functional in regtest for testing)
- **Note**: In regtest PoCX mode, these commands scan for valid PoCX proofs on-the-fly
- **Production**: Use external plotter + miner + `submit_nonce`

**Implementation**: `src/rpc/mining.cpp`

---

## Exemplos de Integração

### Integração de Minerador Externo

**Loop Básico de Mineração**:
```python
import requests
import time

RPC_URL = "http://user:pass@localhost:8332"

def rpc_call(method, params=[]):
    payload = {
        "jsonrpc": "2.0",
        "id": "miner",
        "method": method,
        "params": params
    }
    response = requests.post(RPC_URL, json=payload)
    return response.json()["result"]

# Loop de mineração
while True:
    # 1. Obter parâmetros de mineração
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    compression_bounds.nPoCXMinCompression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Escanear arquivos de plot (implementação externa)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Submeter melhor solução
    result = rpc_call("submit_nonce", [
        info["block_hash"],
        height,
        gen_sig,
        base_target,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"],
        best_nonce["compression"],
        best_nonce["raw_quality"]
    ])

    if result["accepted"]:
        print(f"Solução aceita! Qualidade: {result['quality']}s, "
              f"Tempo de forja: {result['poc_time']}s")

    # 4. Aguardar próximo bloco
    time.sleep(10)  # Intervalo de polling
```

---

### Padrão de Integração de Pool

**Fluxo de Trabalho do Servidor de Pool**:
1. Mineradores criam atribuições de forja para endereço do pool
2. Pool executa carteira com chaves do endereço de forja
3. Pool chama `get_mining_info` e distribui para mineradores
4. Mineradores submetem soluções via pool (não diretamente para cadeia)
5. Pool valida e chama `submit_nonce` com chaves do pool
6. Pool distribui recompensas conforme política do pool

**Gerenciamento de Atribuição**:
```bash
# Minerador cria atribuição (da carteira do minerador)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Aguardar ativação (30 blocos mainnet)

# Pool verifica status de atribuição
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Pool pode agora submeter nonces para este plot
# (carteira do pool deve ter chave privada de pocx1qpool...)
```

---

### Consultas de Block Explorer

**Consultando Dados de Bloco PoCX**:
```bash
# Obter último bloco
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Obter detalhes do bloco com prova PoCX
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Extrair campos específicos do PoCX
echo $BLOCK | jq '{
  height: .height,
  time_since_last: .time_since_last_block,
  poc_time: .poc_time,
  base_target: .base_target,
  generation_signature: .generation_signature,
  pocx_proof: .pocx_proof,
  miner_address: .tx[0].vout[0].scriptPubKey.address
}'
```

**Detectando Transações de Atribuição**:
```bash
# Escanear transação por OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Verificar marcador de atribuição (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Tratamento de Erros

### Padrões Comuns de Erro

**Incompatibilidade de Altura**:
```json
{
  "accepted": false,
  "error": "Incompatibilidade de altura: submetido 12345, atual 12346"
}
```
**Solução**: Re-buscar info de mineração, cadeia avançou

**Incompatibilidade de Assinatura de Geração**:
```json
{
  "accepted": false,
  "error": "Incompatibilidade de assinatura de geração"
}
```
**Solução**: Re-buscar info de mineração, novo bloco chegou

**Sem Chave Privada**:
```json
{
  "code": -5,
  "message": "Sem chave privada disponível para signatário efetivo"
}
```
**Solução**: Importar chave para plot ou endereço de forja

**Ativação de Atribuição Pendente**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Solução**: Aguardar atraso de ativação expirar

---

## Referências de Código

**RPCs de Mineração**: `src/pocx/rpc/mining.cpp`
**RPCs de Atribuição**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**RPCs de Blockchain**: `src/rpc/blockchain.cpp`
**Validação de Prova**: `src/pocx/consensus/proof.cpp`, `src/pocx/consensus/signature.cpp`
**Estado de Atribuição**: `src/pocx/assignments/assignment_state.cpp`
**Criação de Transação**: `src/pocx/assignments/transactions.cpp`

---

## Referências Cruzadas

Capítulos relacionados:
- [Capítulo 3: Consenso e Mineração](3-consensus-and-mining.md) - Detalhes do processo de mineração
- [Capítulo 4: Atribuições de Forja](4-forging-assignments.md) - Arquitetura do sistema de atribuição
- [Capítulo 6: Parâmetros de Rede](6-network-parameters.md) - Valores de atraso de atribuição
- [Capítulo 8: Guia da Carteira](8-wallet-guide.md) - GUI para gerenciamento de atribuição

---

[← Anterior: Parâmetros de Rede](6-network-parameters.md) | [📘 Índice](index.md) | [Próximo: Guia da Carteira →](8-wallet-guide.md)
