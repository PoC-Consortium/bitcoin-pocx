[← Anterior: Formato de Plot](2-plot-format.md) | [📘 Índice](index.md) | [Próximo: Atribuições de Forja →](4-forging-assignments.md)

---

# Capítulo 3: Processo de Consenso e Mineração do Bitcoin-PoCX

Especificação técnica completa do mecanismo de consenso PoCX (Proof of Capacity neXt generation) e processo de mineração integrado ao Bitcoin Core.

---

## Índice

1. [Visão Geral](#visão-geral)
2. [Arquitetura de Consenso](#arquitetura-de-consenso)
3. [Processo de Mineração](#processo-de-mineração)
4. [Validação de Bloco](#validação-de-bloco)
5. [Sistema de Atribuição](#sistema-de-atribuição)
6. [Propagação na Rede](#propagação-na-rede)
7. [Detalhes Técnicos](#detalhes-técnicos)

---

## Visão Geral

O Bitcoin-PoCX implementa um mecanismo de consenso puro de Proof of Capacity como substituição completa do Proof of Work do Bitcoin. Esta é uma nova blockchain sem requisitos de compatibilidade retroativa.

**Propriedades Principais:**
- **Eficiente em Energia:** A mineração usa arquivos de plot pré-gerados em vez de hashing computacional
- **Deadlines com Time Bending:** Transformação de distribuição (exponencial→qui-quadrado) reduz blocos longos, melhora tempos médios de bloco
- **Suporte a Atribuição:** Proprietários de plots podem delegar direitos de forja para outros endereços
- **Integração Nativa em C++:** Algoritmos criptográficos implementados em C++ para validação de consenso

**Fluxo de Mineração:**
```
Minerador Externo → get_mining_info → Calcular Nonce → submit_nonce →
Fila de Forja → Espera de Deadline → Forja de Bloco → Propagação na Rede →
Validação de Bloco → Extensão da Cadeia
```

---

## Arquitetura de Consenso

### Estrutura de Bloco

Blocos PoCX estendem a estrutura de bloco do Bitcoin com campos de consenso adicionais:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Seed do plot (32 bytes)
    std::array<uint8_t, 20> account_id;       // Endereço do plot (20-byte hash160)
    uint32_t compression;                     // Nível de escala (1-255)
    uint64_t nonce;                           // Nonce de mineração (64-bit)
    uint64_t quality;                         // Qualidade declarada (saída do hash PoC)
};

class CBlockHeader {
    // Campos padrão do Bitcoin
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // Campos de consenso PoCX (substituem nBits e nNonce)
    int nHeight;                              // Altura do bloco (validação sem contexto)
    uint256 generationSignature;              // Assinatura de geração (entropia de mineração)
    uint64_t nBaseTarget;                     // Parâmetro de dificuldade (dificuldade inversa)
    PoCXProof pocxProof;                      // Prova de mineração

    // Campos de assinatura de bloco
    std::array<uint8_t, 33> vchPubKey;        // Chave pública comprimida (33 bytes)
    std::array<uint8_t, 65> vchSignature;     // Assinatura compacta (65 bytes)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Transações
};
```

**Nota:** A assinatura (`vchSignature`) é excluída do cálculo do hash do bloco para prevenir maleabilidade.

**Implementação:** `src/primitives/block.h`

### Assinatura de Geração

A assinatura de geração cria entropia de mineração e previne ataques de pré-computação.

**Cálculo:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**Bloco Gênesis:** Usa uma assinatura de geração inicial hardcoded

**Implementação:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Base Target (Dificuldade)

O base target é o inverso da dificuldade — valores mais altos significam mineração mais fácil.

**Algoritmo de Ajuste:**
- Tempo de bloco alvo: 120 segundos (mainnet), 1 segundo (regtest)
- Intervalo de ajuste: A cada bloco
- Usa média móvel de base targets recentes
- Limitado para prevenir oscilações extremas de dificuldade

**Implementação:** `src/consensus/params.h`, ajuste de dificuldade na criação de blocos

### Níveis de Escala

O PoCX suporta proof-of-work escalável em arquivos de plot através de níveis de escala (Xn).

**Limites Dinâmicos:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Nível mínimo aceito
    uint8_t nPoCXTargetCompression;  // Nível recomendado
};
```

**Cronograma de Aumento de Escala:**
- Intervalos exponenciais: Anos 4, 12, 28, 60, 124 (halvings 1, 3, 7, 15, 31)
- Nível mínimo de escala aumenta em 1
- Nível alvo de escala aumenta em 1
- Mantém margem de segurança entre custos de criação e consulta de plots
- Nível máximo de escala: 255

**Implementação:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Processo de Mineração

### 1. Recuperação de Informações de Mineração

**Comando RPC:** `get_mining_info`

**Processo:**
1. Chama `GetNewBlockContext(chainman)` para buscar estado atual da blockchain
2. Calcula limites dinâmicos de compressão para altura atual
3. Retorna parâmetros de mineração

**Resposta:**
```json
{
  "generation_signature": "abc123...",
  "base_target": 18325193796,
  "height": 12345,
  "block_hash": "def456...",
  "target_quality": 18446744073709551615,
  "minimum_compression_level": 0,
  "target_compression_level": 0
}
```

**Implementação:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Notas:**
- Nenhum lock mantido durante geração de resposta
- Aquisição de contexto trata `cs_main` internamente
- `block_hash` incluído para referência mas não usado na validação

### 2. Mineração Externa

**Responsabilidades do minerador externo:**
1. Ler arquivos de plot do disco
2. Calcular scoop baseado na assinatura de geração e altura
3. Encontrar nonce com melhor deadline
4. Submeter ao nó via `submit_nonce`

**Formato de Arquivo de Plot:**
- Baseado no formato POC2 (Burstcoin)
- Aprimorado com correções de segurança e melhorias de escalabilidade
- Veja atribuição em `CLAUDE.md`

**Implementação do Minerador:** Externa (ex: baseada no Scavenger)

### 3. Submissão e Validação de Nonce

**Comando RPC:** `submit_nonce`

**Parâmetros:**
```
height, generation_signature, account_id, seed, nonce, quality (opcional)
```

**Fluxo de Validação (Ordem Otimizada):**

#### Passo 1: Validação Rápida de Formato
```cpp
// Account ID: 40 caracteres hex = 20 bytes
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 caracteres hex = 32 bytes
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Passo 2: Aquisição de Contexto
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Retorna: height, generation_signature, base_target, block_hash
```

**Locking:** `cs_main` tratado internamente, nenhum lock mantido na thread RPC

#### Passo 3: Validação de Contexto
```cpp
// Verificação de altura
if (height != context.height) reject;

// Verificação de assinatura de geração
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Passo 4: Verificação de Carteira
```cpp
// Determinar signatário efetivo (considerando atribuições)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Verificar se o nó tem chave privada para signatário efetivo
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Suporte a Atribuição:** Proprietário do plot pode atribuir direitos de forja para outro endereço. A carteira deve ter a chave do signatário efetivo, não necessariamente do proprietário do plot.

#### Passo 5: Validação de Prova
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 bytes
    block_height,
    nonce,
    seed,                // 32 bytes
    min_compression,
    max_compression,
    &result             // Saída: quality, deadline
);
```

**Algoritmo:**
1. Decodifica assinatura de geração de hex
2. Calcula melhor qualidade na faixa de compressão usando algoritmos otimizados para SIMD
3. Valida que qualidade atende requisitos de dificuldade
4. Retorna valor de qualidade bruto

**Implementação:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Passo 6: Cálculo de Time Bending
```cpp
// Deadline bruto ajustado por dificuldade (segundos)
uint64_t deadline_seconds = quality / base_target;

// Tempo de forja com Time Bending (segundos)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Fórmula de Time Bending:**
```
Y = scale * (X^(1/3))
onde:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Propósito:** Transforma distribuição exponencial para qui-quadrado. Soluções muito boas são forjadas mais tarde (rede tem tempo para escanear discos), soluções fracas são melhoradas. Reduz blocos longos, mantém média de 120s.

**Implementação:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Passo 7: Submissão ao Forjador
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // NÃO deadline - recalculado no forjador
    height,
    generation_signature
);
```

**Design Baseado em Fila:**
- Submissão sempre tem sucesso (adicionada à fila)
- RPC retorna imediatamente
- Thread worker processa assincronamente

**Implementação:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Processamento da Fila do Forjador

**Arquitetura:**
- Thread worker única e persistente
- Fila de submissão FIFO
- Estado de forja livre de locks (apenas thread worker)
- Sem locks aninhados (prevenção de deadlock)

**Loop Principal da Thread Worker:**
```cpp
while (!shutdown) {
    // 1. Verificar submissões em fila
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Aguardar deadline ou nova submissão
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**Lógica de ProcessSubmission:**
```cpp
1. Obter contexto atualizado: GetNewBlockContext(*chainman)

2. Verificações de obsolescência (descarte silencioso):
   - Incompatibilidade de altura → descartar
   - Incompatibilidade de assinatura de geração → descartar
   - Hash do bloco tip mudou (reorg) → resetar estado de forja

3. Comparação de qualidade:
   - Se quality >= current_best → descartar

4. Calcular deadline com Time Bending:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Atualizar estado de forja:
   - Cancelar forja existente (se melhor encontrada)
   - Armazenar: account_id, seed, nonce, quality, deadline
   - Calcular: forge_time = block_time + deadline_seconds
   - Armazenar hash do tip para detecção de reorg
```

**Implementação:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Espera de Deadline e Forja de Bloco

**WaitForDeadlineOrNewSubmission:**

**Condições de Espera:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Quando o Deadline é Atingido - Validação de Contexto Atualizado:**
```cpp
1. Obter contexto atual: GetNewBlockContext(*chainman)

2. Validação de altura:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Validação de assinatura de geração:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Caso especial de base target:
   if (forging_base_target != current_base_target) {
       // Recalcular deadline com novo base target
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Aguardar novamente
   }

5. Tudo válido → ForgeBlock()
```

**Processo ForgeBlock:**

```cpp
1. Determinar signatário efetivo (suporte a atribuição):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Criar script de coinbase:
   coinbase_script = P2WPKH(effective_signer);  // Paga ao signatário efetivo

3. Criar template de bloco:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Adicionar prova PoCX:
   block.pocxProof.account_id = plot_address;    // Endereço original do plot
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Recalcular merkle root:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Assinar bloco:
   // Usar chave do signatário efetivo (pode ser diferente do proprietário do plot)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Submeter à cadeia:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Tratamento de resultado:
   if (accepted) {
       log_success();
       reset_forging_state();  // Pronto para próximo bloco
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implementação:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Decisões de Design Principais:**
- Coinbase paga ao signatário efetivo (respeita atribuições)
- Prova contém endereço original do plot (para validação)
- Assinatura da chave do signatário efetivo (prova de propriedade)
- Criação de template inclui transações do mempool automaticamente

---

## Validação de Bloco

### Fluxo de Validação de Bloco Recebido

Quando um bloco é recebido da rede ou submetido localmente, ele passa por validação em múltiplos estágios:

### Estágio 1: Validação de Cabeçalho (CheckBlockHeader)

**Validação Sem Contexto:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**Validação PoCX (quando ENABLE_POCX definido):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Validação básica de assinatura (sem suporte a atribuição ainda)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Validação Básica de Assinatura:**
1. Verificar presença de campos pubkey e signature
2. Validar tamanho de pubkey (33 bytes comprimidos)
3. Validar tamanho de assinatura (65 bytes compactos)
4. Recuperar pubkey da assinatura: `pubkey.RecoverCompact(hash, signature)`
5. Verificar que pubkey recuperada corresponde à pubkey armazenada

**Implementação:** `src/validation.cpp:CheckBlockHeader()`
**Lógica de Assinatura:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Estágio 2: Validação de Bloco (CheckBlock)

**Valida:**
- Correção da merkle root
- Validade de transações
- Requisitos de coinbase
- Limites de tamanho de bloco
- Regras padrão de consenso do Bitcoin

**Implementação:** `src/consensus/validation.cpp:CheckBlock()`

### Estágio 3: Validação Contextual de Cabeçalho (ContextualCheckBlockHeader)

**Validação Específica do PoCX:**

```cpp
#ifdef ENABLE_POCX
    // Passo 1: Validar assinatura de geração
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Passo 2: Validar base target
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Passo 3: Validar proof of capacity
    auto compression_bounds = GetPoCXCompressionBounds(block.nHeight, halving_interval);
    auto result = ValidateProofOfCapacity(
        block.generationSignature,
        block.pocxProof,
        block.nBaseTarget,
        block.nHeight,
        compression_bounds.nPoCXMinCompression,
        compression_bounds.nPoCXTargetCompression,
        block_time
    );

    if (!result.is_valid) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-proof");
    }

    // Passo 4: Verificar timing do deadline
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Passos de Validação:**
1. **Assinatura de Geração:** Deve corresponder ao valor calculado do bloco anterior
2. **Base Target:** Deve corresponder ao cálculo de ajuste de dificuldade
3. **Nível de Escala:** Deve atender ao mínimo da rede (`compression >= min_compression`)
4. **Reivindicação de Qualidade:** Qualidade submetida deve corresponder à qualidade computada da prova
5. **Proof of Capacity:** Validação de prova criptográfica (otimizada para SIMD)
6. **Timing do Deadline:** Deadline time-bended (`poc_time`) deve ser ≤ tempo decorrido

**Implementação:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Estágio 4: Conexão de Bloco (ConnectBlock)

**Validação Contextual Completa:**

```cpp
#ifdef ENABLE_POCX
    // Validação estendida de assinatura com suporte a atribuição
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Validação Estendida de Assinatura:**
1. Realizar validação básica de assinatura
2. Extrair account ID da pubkey recuperada
3. Obter signatário efetivo para endereço do plot: `GetEffectiveSigner(plot_address, height, view)`
4. Verificar que account da pubkey corresponde ao signatário efetivo

**Lógica de Atribuição:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Retornar signatário atribuído
    }

    return plotAddress;  // Sem atribuição - proprietário do plot assina
}
```

**Implementação:**
- Conexão: `src/validation.cpp:ConnectBlock()`
- Validação estendida: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Lógica de atribuição: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Estágio 5: Ativação da Cadeia

**Fluxo de ProcessNewBlock:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Validar e armazenar em disco
    2. ActivateBestChain → Atualizar tip da cadeia se esta for a melhor cadeia
    3. Notificar rede do novo bloco
}
```

**Implementação:** `src/validation.cpp:ProcessNewBlock()`

### Resumo de Validação

**Caminho Completo de Validação:**
```
Receber Bloco
    ↓
CheckBlockHeader (assinatura básica)
    ↓
CheckBlock (transações, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, base target, prova PoC, deadline)
    ↓
ConnectBlock (assinatura estendida com atribuições, transições de estado)
    ↓
ActivateBestChain (tratamento de reorg, extensão da cadeia)
    ↓
Propagação na Rede
```

---

## Sistema de Atribuição

### Visão Geral

Atribuições permitem que proprietários de plots deleguem direitos de forja para outros endereços enquanto mantêm a propriedade do plot.

**Casos de Uso:**
- Mineração em pool (plots atribuídos ao endereço do pool)
- Armazenamento frio (chave de mineração separada da propriedade do plot)
- Mineração multipartidária (infraestrutura compartilhada)

### Arquitetura de Atribuição

**Design Exclusivamente OP_RETURN:**
- Atribuições armazenadas em saídas OP_RETURN (sem UTXO)
- Sem requisitos de gasto (sem dust, sem taxas para manter)
- Rastreadas no estado estendido do CCoinsViewCache
- Ativadas após período de atraso (padrão: 4 blocos)

**Estados de Atribuição:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Nenhuma atribuição existe
    ASSIGNING = 1,   // Atribuição pendente de ativação (período de atraso)
    ASSIGNED = 2,    // Atribuição ativa, forja permitida
    REVOKING = 3,    // Revogação pendente (período de atraso, ainda ativa)
    REVOKED = 4      // Revogação completa, atribuição não mais ativa
};
```

### Criando Atribuições

**Formato de Transação:**
```cpp
Transaction {
    inputs: [any]  // Prova propriedade do endereço do plot
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Regras de Validação:**
1. Input deve ser assinado pelo proprietário do plot (prova propriedade)
2. OP_RETURN contém dados de atribuição válidos
3. Plot deve estar UNASSIGNED ou REVOKED
4. Sem atribuições pendentes duplicadas no mempool
5. Taxa mínima de transação paga

**Ativação:**
- Atribuição se torna ASSIGNING na altura de confirmação
- Torna-se ASSIGNED após período de atraso (4 blocos regtest, 30 blocos mainnet)
- Atraso previne reatribuições rápidas durante disputas de blocos

**Implementação:** `src/script/forging_assignment.h`, validação em ConnectBlock

### Revogando Atribuições

**Formato de Transação:**
```cpp
Transaction {
    inputs: [any]  // Prova propriedade do endereço do plot
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Efeito:**
- Transição imediata de estado para REVOKED
- Proprietário do plot pode forjar imediatamente
- Pode criar nova atribuição depois

### Validação de Atribuição Durante Mineração

**Determinação de Signatário Efetivo:**
```cpp
// Na validação de submit_nonce
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// Na forja de bloco
coinbase_script = P2WPKH(effective_signer);  // Recompensa vai para aqui

// Na assinatura de bloco
signature = effective_signer_key.SignCompact(hash);  // Deve assinar com signatário efetivo
```

**Validação de Bloco:**
```cpp
// Em VerifyPoCXBlockCompactSignature (estendido)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Propriedades Principais:**
- Prova sempre contém endereço original do plot
- Assinatura deve ser do signatário efetivo
- Coinbase paga ao signatário efetivo
- Validação usa estado de atribuição na altura do bloco

---

## Propagação na Rede

### Anúncio de Bloco

**Protocolo P2P Padrão do Bitcoin:**
1. Bloco forjado submetido via `ProcessNewBlock()`
2. Bloco validado e adicionado à cadeia
3. Notificação de rede: `GetMainSignals().BlockConnected()`
4. Camada P2P transmite bloco para peers

**Implementação:** net_processing padrão do Bitcoin Core

### Retransmissão de Bloco

**Blocos Compactos (BIP 152):**
- Usado para propagação eficiente de blocos
- Apenas IDs de transação enviados inicialmente
- Peers solicitam transações faltantes

**Retransmissão de Bloco Completo:**
- Fallback quando blocos compactos falham
- Dados completos de bloco transmitidos

### Reorganizações de Cadeia

**Tratamento de Reorg:**
```cpp
// Na thread worker do forjador
if (current_tip_hash != stored_tip_hash) {
    // Reorganização de cadeia detectada
    reset_forging_state();
    log("Tip da cadeia mudou, resetando forja");
}
```

**Nível de Blockchain:**
- Tratamento padrão de reorg do Bitcoin Core
- Melhor cadeia determinada por chainwork
- Blocos desconectados retornam ao mempool

---

## Detalhes Técnicos

### Prevenção de Deadlock

**Padrão de Deadlock ABBA (Prevenido):**
```
Thread A: cs_main → cs_wallet
Thread B: cs_wallet → cs_main
```

**Solução:**
1. **submit_nonce:** Zero uso de cs_main
   - `GetNewBlockContext()` trata locking internamente
   - Toda validação antes de submissão ao forjador

2. **Forjador:** Arquitetura baseada em fila
   - Thread worker única (sem joins de thread)
   - Contexto atualizado em cada acesso
   - Sem locks aninhados

3. **Verificações de carteira:** Realizadas antes de operações caras
   - Rejeição antecipada se nenhuma chave disponível
   - Separado do acesso ao estado da blockchain

### Otimizações de Desempenho

**Validação Fail-Fast:**
```cpp
1. Verificações de formato (imediatas)
2. Validação de contexto (leve)
3. Verificação de carteira (local)
4. Validação de prova (SIMD caro)
```

**Busca Única de Contexto:**
- Uma chamada `GetNewBlockContext()` por submissão
- Resultados em cache para múltiplas verificações
- Sem aquisições repetidas de cs_main

**Eficiência de Fila:**
- Estrutura de submissão leve
- Sem base_target/deadline na fila (recalculados atualizados)
- Footprint mínimo de memória

### Tratamento de Obsolescência

**Design de Forjador "Burro":**
- Sem assinaturas de eventos de blockchain
- Validação lazy quando necessário
- Descartes silenciosos de submissões obsoletas

**Benefícios:**
- Arquitetura simples
- Sem sincronização complexa
- Robusto contra casos especiais

**Casos Especiais Tratados:**
- Mudanças de altura → descartar
- Mudanças de assinatura de geração → descartar
- Mudanças de base target → recalcular deadline
- Reorgs → resetar estado de forja

### Detalhes Criptográficos

**Assinatura de Geração:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Hash de Assinatura de Bloco:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Formato de Assinatura Compacta:**
- 65 bytes: [recovery_id][r][s]
- Permite recuperação de chave pública
- Usado para eficiência de espaço

**Account ID:**
- HASH160 de 20 bytes de chave pública comprimida
- Corresponde a formatos de endereço Bitcoin (P2PKH, P2WPKH)

### Melhorias Futuras

**Limitações Documentadas:**
1. Sem métricas de desempenho (taxas de submissão, distribuições de deadline)
2. Sem categorização detalhada de erros para mineradores
3. Consulta limitada de status do forjador (deadline atual, profundidade da fila)

**Melhorias Potenciais:**
- RPC para status do forjador
- Métricas para eficiência de mineração
- Logging aprimorado para depuração
- Suporte a protocolo de pool

---

## Referências de Código

**Implementações Core:**
- Interface RPC: `src/pocx/rpc/mining.cpp`
- Fila do Forjador: `src/pocx/mining/scheduler.cpp`
- Validação de Consenso: `src/pocx/consensus/validation.cpp`
- Validação de Prova: `src/pocx/consensus/pocx.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- Validação de Bloco: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Lógica de Atribuição: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Gerenciamento de Contexto: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Estruturas de Dados:**
- Formato de Bloco: `src/primitives/block.h`
- Parâmetros de Consenso: `src/consensus/params.h`
- Rastreamento de Atribuição: `src/coins.h` (extensões do CCoinsViewCache)

---

## Apêndice: Especificações de Algoritmos

### Fórmula de Time Bending

**Definição Matemática:**
```
deadline_seconds = quality / base_target  (bruto)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

onde:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Implementação:**
- Aritmética de ponto fixo (formato Q42)
- Cálculo de raiz cúbica apenas com inteiros
- Otimizado para aritmética de 256 bits

### Cálculo de Qualidade

**Processo:**
1. Gerar scoop a partir de assinatura de geração e altura
2. Ler dados do plot para scoop calculado
3. Hash: `SHABAL256(generation_signature || scoop_data)`
4. Testar níveis de escala do mínimo ao máximo
5. Retornar melhor qualidade encontrada

**Escala:**
- Nível X0: Baseline POC2 (teórico)
- Nível X1: Baseline XOR-transpose
- Nível Xn: 2^(n-1) × trabalho X1 embutido
- Escala maior = mais trabalho de geração de plot

### Ajuste de Base Target

**Ajuste a cada bloco:**
1. Calcular média móvel de base targets recentes
2. Calcular timespan real vs timespan alvo para janela rolante
3. Ajustar base target proporcionalmente
4. Limitar para prevenir oscilações extremas

**Fórmula:**
```
avg_base_target = moving_average(base targets recentes)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*Esta documentação reflete a implementação completa do consenso PoCX em outubro de 2025.*

---

[← Anterior: Formato de Plot](2-plot-format.md) | [📘 Índice](index.md) | [Próximo: Atribuições de Forja →](4-forging-assignments.md)
