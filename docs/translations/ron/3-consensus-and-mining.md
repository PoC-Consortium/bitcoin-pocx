[← Anterior: Formatul plot](2-plot-format.md) | [📘 Cuprins](index.md) | [Următorul: Atribuiri de forjare →](4-forging-assignments.md)

---

# Capitolul 3: Procesul de consens și minerit Bitcoin-PoCX

Specificația tehnică completă a mecanismului de consens PoCX (Proof of Capacity neXt generation) și a procesului de minerit integrat în Bitcoin Core.

---

## Cuprins

1. [Prezentare generală](#prezentare-generală)
2. [Arhitectura consensului](#arhitectura-consensului)
3. [Procesul de minerit](#procesul-de-minerit)
4. [Validarea blocurilor](#validarea-blocurilor)
5. [Sistemul de atribuiri](#sistemul-de-atribuiri)
6. [Propagarea în rețea](#propagarea-în-rețea)
7. [Detalii tehnice](#detalii-tehnice)

---

## Prezentare generală

Bitcoin-PoCX implementează un mecanism de consens pur Proof of Capacity ca înlocuitor complet pentru Proof of Work al Bitcoin. Acesta este un lanț nou fără cerințe de compatibilitate retroactivă.

**Proprietăți cheie:**
- **Eficient energetic:** Mineritul folosește fișiere plot pre-generate în loc de hashing computațional
- **Deadline-uri Time Bended:** Transformarea distribuției (exponențială→chi-pătrat) reduce blocurile lungi, îmbunătățește timpii medii ai blocurilor
- **Suport pentru atribuiri:** Proprietarii de plot-uri pot delega drepturile de forjare către alte adrese
- **Integrare nativă C++:** Algoritmi criptografici implementați în C++ pentru validarea consensului

**Fluxul de minerit:**
```
Miner extern → get_mining_info → Calculare nonce → submit_nonce →
Coadă forjare → Așteptare deadline → Forjare bloc → Propagare în rețea →
Validare bloc → Extindere lanț
```

---

## Arhitectura consensului

### Structura blocului

Blocurile PoCX extind structura blocului Bitcoin cu câmpuri de consens suplimentare:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Seed plot (32 octeți)
    std::array<uint8_t, 20> account_id;       // Adresa plot (hash160 de 20 octeți)
    uint32_t compression;                     // Nivel de scalare (1-255)
    uint64_t nonce;                           // Nonce de minerit (64 biți)
    uint64_t quality;                         // Calitate declarată (ieșirea hash-ului PoC)
};

class CBlockHeader {
    // Câmpuri standard Bitcoin
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // Câmpuri de consens PoCX (înlocuiesc nBits și nNonce)
    int nHeight;                              // Înălțimea blocului (validare fără context)
    uint256 generationSignature;              // Semnătura de generare (entropie minerit)
    uint64_t nBaseTarget;                     // Parametru dificultate (dificultate inversă)
    PoCXProof pocxProof;                      // Dovada de minerit

    // Câmpuri pentru semnătura blocului
    std::array<uint8_t, 33> vchPubKey;        // Cheie publică comprimată (33 octeți)
    std::array<uint8_t, 65> vchSignature;     // Semnătură compactă (65 octeți)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Tranzacții
};
```

**Notă:** Semnătura (`vchSignature`) este exclusă din calculul hash-ului blocului pentru a preveni maleabilitatea.

**Implementare:** `src/primitives/block.h`

### Semnătura de generare

Semnătura de generare creează entropia pentru minerit și previne atacurile de precalculare.

**Calcul:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**Blocul genesis:** Folosește o semnătură de generare inițială codificată static

**Implementare:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Ținta de bază (Dificultatea)

Ținta de bază este inversul dificultății - valori mai mari înseamnă minerit mai ușor.

**Algoritm de ajustare:**
- Țintă timp bloc: 120 secunde (mainnet), 1 secundă (regtest)
- Interval de ajustare: La fiecare bloc
- Folosește media mobilă a țintelor de bază recente
- Limitată pentru a preveni variații extreme ale dificultății

**Implementare:** `src/consensus/params.h`, ajustarea dificultății în crearea blocului

### Niveluri de scalare

PoCX suportă proof-of-work scalabil în fișierele plot prin niveluri de scalare (Xn).

**Limite dinamice:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Nivel minim acceptat
    uint8_t nPoCXTargetCompression;  // Nivel recomandat
};
```

**Calendarul creșterii scalării:**
- Intervale exponențiale: Anii 4, 12, 28, 60, 124 (înjumătățirile 1, 3, 7, 15, 31)
- Nivelul minim de scalare crește cu 1
- Nivelul țintă de scalare crește cu 1
- Menține marja de siguranță între costurile de creare și căutare a plot-urilor
- Nivel maxim de scalare: 255

**Implementare:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Procesul de minerit

### 1. Obținerea informațiilor de minerit

**Comandă RPC:** `get_mining_info`

**Proces:**
1. Apelează `GetNewBlockContext(chainman)` pentru a obține starea curentă a blockchain-ului
2. Calculează limitele dinamice de compresie pentru înălțimea curentă
3. Returnează parametrii de minerit

**Răspuns:**
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

**Implementare:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Note:**
- Nicio blocare menținută în timpul generării răspunsului
- Achiziția contextului gestionează `cs_main` intern
- `block_hash` inclus pentru referință dar nu folosit în validare

### 2. Mineritul extern

**Responsabilitățile minerului extern:**
1. Citește fișierele plot de pe disc
2. Calculează scoop-ul bazat pe semnătura de generare și înălțime
3. Găsește nonce-ul cu cel mai bun deadline
4. Trimite la nod prin `submit_nonce`

**Formatul fișierului plot:**
- Bazat pe formatul POC2 (Burstcoin)
- Îmbunătățit cu corecții de securitate și îmbunătățiri de scalabilitate
- Consultați atribuirea în `CLAUDE.md`

**Implementare miner:** Extern (ex. bazat pe Scavenger)

### 3. Trimiterea și validarea nonce-ului

**Comandă RPC:** `submit_nonce`

**Parametri:**
```
height, generation_signature, account_id, seed, nonce, quality (opțional)
```

**Fluxul de validare (ordine optimizată):**

#### Pasul 1: Validare rapidă a formatului
```cpp
// Account ID: 40 caractere hex = 20 octeți
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 caractere hex = 32 octeți
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Pasul 2: Achiziția contextului
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Returnează: height, generation_signature, base_target, block_hash
```

**Blocare:** `cs_main` gestionat intern, nicio blocare menținută în thread-ul RPC

#### Pasul 3: Validarea contextului
```cpp
// Verificare înălțime
if (height != context.height) reject;

// Verificare semnătură de generare
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Pasul 4: Verificarea portofelului
```cpp
// Determină semnatarul efectiv (considerând atribuirile)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Verifică dacă nodul are cheia privată pentru semnatarul efectiv
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Suport pentru atribuiri:** Proprietarul plot-ului poate atribui drepturile de forjare unei alte adrese. Portofelul trebuie să aibă cheia pentru semnatarul efectiv, nu neapărat proprietarul plot-ului.

#### Pasul 5: Validarea dovezii
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 octeți
    block_height,
    nonce,
    seed,                // 32 octeți
    min_compression,
    max_compression,
    &result             // Ieșire: quality, deadline
);
```

**Algoritm:**
1. Decodează semnătura de generare din hex
2. Calculează cea mai bună calitate în intervalul de compresie folosind algoritmi optimizați SIMD
3. Validează că calitatea îndeplinește cerințele de dificultate
4. Returnează valoarea brută a calității

**Implementare:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Pasul 6: Calculul Time Bending
```cpp
// Deadline brut ajustat la dificultate (secunde)
uint64_t deadline_seconds = quality / base_target;

// Timp de forjare Time Bended (secunde)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Formula Time Bending:**
```
Y = scale * (X^(1/3))
unde:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Scop:** Transformă distribuția din exponențială în chi-pătrat. Soluțiile foarte bune sunt forjate mai târziu (rețeaua are timp să scaneze discurile), soluțiile slabe sunt îmbunătățite. Reduce blocurile lungi, menține media de 120s.

**Implementare:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Pasul 7: Trimiterea la forjare
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // NU deadline - recalculat în forger
    height,
    generation_signature
);
```

**Design bazat pe coadă:**
- Trimiterea reușește întotdeauna (adăugată în coadă)
- RPC returnează imediat
- Thread-ul worker procesează asincron

**Implementare:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Procesarea cozii de forjare

**Arhitectură:**
- Un singur thread worker persistent
- Coadă de trimitere FIFO
- Stare de forjare fără blocări (doar thread-ul worker)
- Fără blocări imbricate (prevenirea deadlock-urilor)

**Bucla principală a thread-ului worker:**
```cpp
while (!shutdown) {
    // 1. Verifică pentru trimiteri în coadă
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Așteaptă deadline sau trimitere nouă
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**Logica ProcessSubmission:**
```cpp
1. Obține context proaspăt: GetNewBlockContext(*chainman)

2. Verificări de învechire (respingere silențioasă):
   - Nepotrivire înălțime → respinge
   - Nepotrivire semnătură de generare → respinge
   - Hash-ul blocului vârf s-a schimbat (reorg) → resetează starea de forjare

3. Compararea calității:
   - Dacă quality >= current_best → respinge

4. Calculează deadline-ul Time Bended:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Actualizează starea de forjare:
   - Anulează forjarea existentă (dacă s-a găsit una mai bună)
   - Stochează: account_id, seed, nonce, quality, deadline
   - Calculează: forge_time = block_time + deadline_seconds
   - Stochează hash-ul vârfului pentru detectarea reorg-urilor
```

**Implementare:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Așteptarea deadline-ului și forjarea blocului

**WaitForDeadlineOrNewSubmission:**

**Condiții de așteptare:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Când deadline-ul este atins - validarea contextului proaspăt:**
```cpp
1. Obține contextul curent: GetNewBlockContext(*chainman)

2. Validare înălțime:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Validare semnătură de generare:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Caz marginal țintă de bază:
   if (forging_base_target != current_base_target) {
       // Recalculează deadline-ul cu noua țintă de bază
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Așteaptă din nou
   }

5. Toate valide → ForgeBlock()
```

**Procesul ForgeBlock:**

```cpp
1. Determină semnatarul efectiv (suport pentru atribuiri):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Creează scriptul coinbase:
   coinbase_script = P2WPKH(effective_signer);  // Plătește semnatarului efectiv

3. Creează șablonul de bloc:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Adaugă dovada PoCX:
   block.pocxProof.account_id = plot_address;    // Adresa plot-ului original
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Recalculează rădăcina Merkle:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Semnează blocul:
   // Folosește cheia semnatarului efectiv (poate fi diferit de proprietarul plot-ului)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Trimite la lanț:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Gestionarea rezultatului:
   if (accepted) {
       log_success();
       reset_forging_state();  // Gata pentru următorul bloc
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implementare:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Decizii de design cheie:**
- Coinbase plătește semnatarului efectiv (respectă atribuirile)
- Dovada conține adresa originală a plot-ului (pentru validare)
- Semnătura de la cheia semnatarului efectiv (dovada proprietății)
- Crearea șablonului include automat tranzacțiile din mempool

---

## Validarea blocurilor

### Fluxul de validare a blocurilor primite

Când un bloc este primit din rețea sau trimis local, trece prin validare în mai multe etape:

### Etapa 1: Validarea header-ului (CheckBlockHeader)

**Validare fără context:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**Validare PoCX (când ENABLE_POCX este definit):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Validare de bază a semnăturii (fără suport pentru atribuiri încă)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Validarea de bază a semnăturii:**
1. Verifică prezența câmpurilor pubkey și semnătură
2. Validează dimensiunea pubkey (33 octeți comprimat)
3. Validează dimensiunea semnăturii (65 octeți compact)
4. Recuperează pubkey din semnătură: `pubkey.RecoverCompact(hash, signature)`
5. Verifică că pubkey-ul recuperat corespunde cu cel stocat

**Implementare:** `src/validation.cpp:CheckBlockHeader()`
**Logica semnăturii:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Etapa 2: Validarea blocului (CheckBlock)

**Validează:**
- Corectitudinea rădăcinii Merkle
- Validitatea tranzacțiilor
- Cerințele coinbase
- Limitele dimensiunii blocului
- Reguli standard de consens Bitcoin

**Implementare:** `src/consensus/validation.cpp:CheckBlock()`

### Etapa 3: Validarea contextuală a header-ului (ContextualCheckBlockHeader)

**Validare specifică PoCX:**

```cpp
#ifdef ENABLE_POCX
    // Pasul 1: Validează semnătura de generare
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Pasul 2: Validează ținta de bază
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Pasul 3: Validează proof of capacity
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

    // Pasul 4: Verifică sincronizarea deadline-ului
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Pașii de validare:**
1. **Semnătura de generare:** Trebuie să corespundă cu valoarea calculată din blocul anterior
2. **Ținta de bază:** Trebuie să corespundă cu calculul ajustării dificultății
3. **Nivel de scalare:** Trebuie să îndeplinească minimul rețelei (`compression >= min_compression`)
4. **Declarația calității:** Calitatea trimisă trebuie să corespundă cu calitatea calculată din dovadă
5. **Proof of Capacity:** Validarea criptografică a dovezii (optimizată SIMD)
6. **Sincronizarea deadline-ului:** Deadline-ul time-bended (`poc_time`) trebuie să fie ≤ timpul scurs

**Implementare:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Etapa 4: Conectarea blocului (ConnectBlock)

**Validare contextuală completă:**

```cpp
#ifdef ENABLE_POCX
    // Validare extinsă a semnăturii cu suport pentru atribuiri
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Validarea extinsă a semnăturii:**
1. Efectuează validarea de bază a semnăturii
2. Extrage ID-ul contului din pubkey-ul recuperat
3. Obține semnatarul efectiv pentru adresa plot-ului: `GetEffectiveSigner(plot_address, height, view)`
4. Verifică că contul pubkey-ului corespunde cu semnatarul efectiv

**Logica atribuirilor:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Returnează semnatarul atribuit
    }

    return plotAddress;  // Fără atribuire - proprietarul plot-ului semnează
}
```

**Implementare:**
- Conectare: `src/validation.cpp:ConnectBlock()`
- Validare extinsă: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Logica atribuirilor: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Etapa 5: Activarea lanțului

**Fluxul ProcessNewBlock:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Validează și stochează pe disc
    2. ActivateBestChain → Actualizează vârful lanțului dacă acesta este cel mai bun lanț
    3. Notifică rețeaua despre noul bloc
}
```

**Implementare:** `src/validation.cpp:ProcessNewBlock()`

### Rezumatul validării

**Calea completă de validare:**
```
Primire bloc
    ↓
CheckBlockHeader (semnătură de bază)
    ↓
CheckBlock (tranzacții, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, țintă bază, dovadă PoC, deadline)
    ↓
ConnectBlock (semnătură extinsă cu atribuiri, tranziții de stare)
    ↓
ActivateBestChain (gestionare reorg, extindere lanț)
    ↓
Propagare în rețea
```

---

## Sistemul de atribuiri

### Prezentare generală

Atribuirile permit proprietarilor de plot-uri să delege drepturile de forjare către alte adrese, menținând în același timp proprietatea plot-ului.

**Cazuri de utilizare:**
- Minerit în pool (plot-urile se atribuie adresei pool-ului)
- Stocare la rece (cheia de minerit separată de proprietatea plot-ului)
- Minerit multi-parte (infrastructură partajată)

### Arhitectura atribuirilor

**Design bazat exclusiv pe OP_RETURN:**
- Atribuirile stocate în ieșiri OP_RETURN (fără UTXO)
- Fără cerințe de cheltuire (fără praf, fără taxe pentru păstrare)
- Urmărite în starea extinsă CCoinsViewCache
- Activate după perioada de întârziere (implicit: 4 blocuri)

**Stările atribuirilor:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Nu există atribuire
    ASSIGNING = 1,   // Atribuire în așteptarea activării (perioada de întârziere)
    ASSIGNED = 2,    // Atribuire activă, forjarea permisă
    REVOKING = 3,    // Revocare în așteptare (perioada de întârziere, încă activă)
    REVOKED = 4      // Revocare completă, atribuirea nu mai este activă
};
```

### Crearea atribuirilor

**Formatul tranzacției:**
```cpp
Transaction {
    inputs: [any]  // Demonstrează proprietatea adresei plot-ului
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Reguli de validare:**
1. Intrarea trebuie semnată de proprietarul plot-ului (demonstrează proprietatea)
2. OP_RETURN conține date de atribuire valide
3. Plot-ul trebuie să fie UNASSIGNED sau REVOKED
4. Fără atribuiri în așteptare duplicate în mempool
5. Taxa minimă de tranzacție plătită

**Activare:**
- Atribuirea devine ASSIGNING la înălțimea confirmării
- Devine ASSIGNED după perioada de întârziere (4 blocuri regtest, 30 blocuri mainnet)
- Întârzierea previne reatribuirile rapide în timpul curselor de blocuri

**Implementare:** `src/script/forging_assignment.h`, validare în ConnectBlock

### Revocarea atribuirilor

**Formatul tranzacției:**
```cpp
Transaction {
    inputs: [any]  // Demonstrează proprietatea adresei plot-ului
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Efect:**
- Tranziție imediată a stării la REVOKED
- Proprietarul plot-ului poate forja imediat
- Poate crea o atribuire nouă după aceea

### Validarea atribuirilor în timpul mineritului

**Determinarea semnatarului efectiv:**
```cpp
// În validarea submit_nonce
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// În forjarea blocului
coinbase_script = P2WPKH(effective_signer);  // Recompensa merge aici

// În semnătura blocului
signature = effective_signer_key.SignCompact(hash);  // Trebuie semnat cu semnatarul efectiv
```

**Validarea blocului:**
```cpp
// În VerifyPoCXBlockCompactSignature (extinsă)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Proprietăți cheie:**
- Dovada conține întotdeauna adresa originală a plot-ului
- Semnătura trebuie să fie de la semnatarul efectiv
- Coinbase plătește semnatarului efectiv
- Validarea folosește starea atribuirii la înălțimea blocului

---

## Propagarea în rețea

### Anunțarea blocului

**Protocol P2P standard Bitcoin:**
1. Blocul forjat trimis prin `ProcessNewBlock()`
2. Blocul validat și adăugat la lanț
3. Notificare rețea: `GetMainSignals().BlockConnected()`
4. Stratul P2P transmite blocul către peer-i

**Implementare:** Standard Bitcoin Core net_processing

### Retransmiterea blocului

**Blocuri compacte (BIP 152):**
- Folosite pentru propagarea eficientă a blocurilor
- Doar ID-urile tranzacțiilor trimise inițial
- Peer-ii solicită tranzacțiile lipsă

**Retransmitere bloc complet:**
- Alternativă când blocurile compacte eșuează
- Date complete ale blocului transmise

### Reorganizările lanțului

**Gestionarea reorganizărilor:**
```cpp
// În thread-ul worker al forger-ului
if (current_tip_hash != stored_tip_hash) {
    // Reorganizare de lanț detectată
    reset_forging_state();
    log("Vârful lanțului s-a schimbat, resetez forjarea");
}
```

**La nivel de blockchain:**
- Gestionare standard Bitcoin Core a reorganizărilor
- Cel mai bun lanț determinat de chainwork
- Blocurile deconectate returnate în mempool

---

## Detalii tehnice

### Prevenirea deadlock-urilor

**Modelul de deadlock ABBA (prevenit):**
```
Thread A: cs_main → cs_wallet
Thread B: cs_wallet → cs_main
```

**Soluție:**
1. **submit_nonce:** Fără utilizare cs_main
   - `GetNewBlockContext()` gestionează blocarea intern
   - Toată validarea înainte de trimiterea la forger

2. **Forger:** Arhitectură bazată pe coadă
   - Un singur thread worker (fără join-uri de thread)
   - Context proaspăt la fiecare acces
   - Fără blocări imbricate

3. **Verificările portofelului:** Efectuate înainte de operațiunile costisitoare
   - Respingere timpurie dacă nu este disponibilă nicio cheie
   - Separate de accesul la starea blockchain

### Optimizări de performanță

**Validare cu eșec rapid:**
```cpp
1. Verificări de format (imediate)
2. Validare context (ușoară)
3. Verificare portofel (locală)
4. Validare dovadă (SIMD costisitor)
```

**O singură achiziție de context:**
- Un singur apel `GetNewBlockContext()` per trimitere
- Rezultatele sunt cached pentru verificări multiple
- Fără achiziții repetate de cs_main

**Eficiența cozii:**
- Structură de trimitere ușoară
- Fără base_target/deadline în coadă (recalculate proaspăt)
- Amprentă de memorie minimă

### Gestionarea învechirilor

**Design de forger "stupid":**
- Fără abonamente la evenimente blockchain
- Validare leneșă când este necesar
- Respingeri silențioase ale trimiterilor învechite

**Beneficii:**
- Arhitectură simplă
- Fără sincronizare complexă
- Robust împotriva cazurilor marginale

**Cazuri marginale gestionate:**
- Schimbări de înălțime → respinge
- Schimbări semnătură de generare → respinge
- Schimbări țintă de bază → recalculează deadline
- Reorganizări → resetează starea de forjare

### Detalii criptografice

**Semnătura de generare:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Hash-ul semnăturii blocului:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Format semnătură compactă:**
- 65 octeți: [recovery_id][r][s]
- Permite recuperarea cheii publice
- Folosit pentru eficiența spațiului

**ID cont:**
- HASH160 de 20 de octeți al cheii publice comprimate
- Corespunde formatelor de adrese Bitcoin (P2PKH, P2WPKH)

### Îmbunătățiri viitoare

**Limitări documentate:**
1. Fără metrici de performanță (rate de trimitere, distribuții deadline)
2. Fără categorizare detaliată a erorilor pentru mineri
3. Interogare limitată a stării forger-ului (deadline curent, adâncime coadă)

**Îmbunătățiri potențiale:**
- RPC pentru starea forger-ului
- Metrici pentru eficiența mineritului
- Logging îmbunătățit pentru depanare
- Suport pentru protocolul de pool

---

## Referințe cod

**Implementări de bază:**
- Interfață RPC: `src/pocx/rpc/mining.cpp`
- Coadă forger: `src/pocx/mining/scheduler.cpp`
- Validare consens: `src/pocx/consensus/validation.cpp`
- Validare dovadă: `src/pocx/consensus/pocx.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- Validare bloc: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Logica atribuirilor: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Gestionare context: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Structuri de date:**
- Format bloc: `src/primitives/block.h`
- Parametri consens: `src/consensus/params.h`
- Urmărire atribuiri: `src/coins.h` (extensii CCoinsViewCache)

---

## Anexă: Specificații algoritmi

### Formula Time Bending

**Definiție matematică:**
```
deadline_seconds = quality / base_target  (brut)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

unde:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Implementare:**
- Aritmetică în virgulă fixă (format Q42)
- Calcul rădăcină cubică doar cu numere întregi
- Optimizat pentru aritmetică pe 256 biți

### Calculul calității

**Proces:**
1. Generează scoop din semnătura de generare și înălțime
2. Citește datele plot pentru scoop-ul calculat
3. Hash: `SHABAL256(generation_signature || scoop_data)`
4. Testează nivelurile de scalare de la min la max
5. Returnează cea mai bună calitate găsită

**Scalare:**
- Nivel X0: Linie de bază POC2 (teoretic)
- Nivel X1: Linie de bază XOR-transpose
- Nivel Xn: 2^(n-1) × munca X1 încorporată
- Scalare mai mare = mai multă muncă de generare plot

### Ajustarea țintei de bază

**Ajustare la fiecare bloc:**
1. Calculează media mobilă a țintelor de bază recente
2. Calculează intervalul de timp real vs intervalul țintă pentru fereastra rulantă
3. Ajustează ținta de bază proporțional
4. Limitează pentru a preveni variații extreme

**Formulă:**
```
avg_base_target = medie_mobilă(ținte de bază recente)
factor_ajustare = interval_timp_real / interval_timp_țintă
new_base_target = avg_base_target * factor_ajustare
new_base_target = clamp(new_base_target, min, max)
```

---

*Această documentație reflectă implementarea completă a consensului PoCX din octombrie 2025.*

---

[← Anterior: Formatul plot](2-plot-format.md) | [📘 Cuprins](index.md) | [Următorul: Atribuiri de forjare →](4-forging-assignments.md)
