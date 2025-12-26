[← Předchozí: Formát plotů](2-plot-format.md) | [Obsah](index.md) | [Další: Forging přiřazení →](4-forging-assignments.md)

---

# Kapitola 3: Konsenzus a proces těžby Bitcoin-PoCX

Kompletní technická specifikace konsensuálního mechanismu a procesu těžby PoCX (Proof of Capacity neXt generation) integrovaného do Bitcoin Core.

---

## Obsah

1. [Přehled](#přehled)
2. [Architektura konsenzu](#architektura-konsenzu)
3. [Proces těžby](#proces-těžby)
4. [Validace bloků](#validace-bloků)
5. [Systém přiřazení](#systém-přiřazení)
6. [Šíření po síti](#šíření-po-síti)
7. [Technické podrobnosti](#technické-podrobnosti)

---

## Přehled

Bitcoin-PoCX implementuje čistý konsensuální mechanismus Proof of Capacity jako kompletní náhradu za Proof of Work Bitcoinu. Jedná se o nový řetězec bez požadavků na zpětnou kompatibilitu.

**Klíčové vlastnosti:**
- **Energeticky účinný:** Těžba používá předgenerované plot soubory místo výpočetního hashování
- **Time-bended deadliny:** Transformace distribuce (exponenciální→chí-kvadrát) redukuje dlouhé bloky, zlepšuje průměrné časy bloků
- **Podpora přiřazení:** Vlastníci plotů mohou delegovat práva na forging na jiné adresy
- **Nativní C++ integrace:** Kryptografické algoritmy implementovány v C++ pro validaci konsenzu

**Tok těžby:**
```
Externí miner → get_mining_info → Výpočet nonce → submit_nonce →
Fronta forgeru → Čekání na deadline → Forging bloku → Šíření po síti →
Validace bloku → Rozšíření řetězce
```

---

## Architektura konsenzu

### Struktura bloku

PoCX bloky rozšiřují strukturu bloku Bitcoinu o další konsensuální pole:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Seed plotu (32 bajtů)
    std::array<uint8_t, 20> account_id;       // Adresa plotu (20bajtový hash160)
    uint32_t compression;                     // Úroveň škálování (1-255)
    uint64_t nonce;                           // Těžební nonce (64bitový)
    uint64_t quality;                         // Deklarovaná kvalita (výstup PoC hashe)
};

class CBlockHeader {
    // Standardní pole Bitcoinu
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // Konsensuální pole PoCX (nahrazují nBits a nNonce)
    int nHeight;                              // Výška bloku (validace bez kontextu)
    uint256 generationSignature;              // Generační podpis (entropie těžby)
    uint64_t nBaseTarget;                     // Parametr obtížnosti (inverzní obtížnost)
    PoCXProof pocxProof;                      // Těžební důkaz

    // Pole podpisu bloku
    std::array<uint8_t, 33> vchPubKey;        // Komprimovaný veřejný klíč (33 bajtů)
    std::array<uint8_t, 65> vchSignature;     // Kompaktní podpis (65 bajtů)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Transakce
};
```

**Poznámka:** Podpis (`vchSignature`) je vyloučen z výpočtu hashe bloku, aby se zabránilo maleabilitě.

**Implementace:** `src/primitives/block.h`

### Generační podpis

Generační podpis vytváří entropii těžby a zabraňuje útokům předpočítáním.

**Výpočet:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**Genesis blok:** Používá hardkódovaný počáteční generační podpis

**Implementace:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Base Target (obtížnost)

Base target je inverzí obtížnosti - vyšší hodnoty znamenají jednodušší těžbu.

**Algoritmus úpravy:**
- Cílový čas bloku: 120 sekund (mainnet), 1 sekunda (regtest)
- Interval úpravy: Každý blok
- Používá klouzavý průměr nedávných base targets
- Omezeno pro prevenci extrémních výkyvů obtížnosti

**Implementace:** `src/consensus/params.h`, logika úpravy obtížnosti při vytváření bloků

### Úrovně škálování

PoCX podporuje škálovatelný proof-of-work v plot souborech prostřednictvím úrovní škálování (Xn).

**Dynamické hranice:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimální přijatá úroveň
    uint8_t nPoCXTargetCompression;  // Doporučená úroveň
};
```

**Harmonogram zvyšování škálování:**
- Exponenciální intervaly: Roky 4, 12, 28, 60, 124 (halvings 1, 3, 7, 15, 31)
- Minimální úroveň škálování se zvyšuje o 1
- Cílová úroveň škálování se zvyšuje o 1
- Udržuje bezpečnostní marži mezi náklady na vytvoření plotu a vyhledávání
- Maximální úroveň škálování: 255

**Implementace:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Proces těžby

### 1. Získání informací o těžbě

**RPC příkaz:** `get_mining_info`

**Proces:**
1. Zavolat `GetNewBlockContext(chainman)` pro získání aktuálního stavu blockchainu
2. Vypočítat dynamické hranice komprese pro aktuální výšku
3. Vrátit parametry těžby

**Odpověď:**
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

**Implementace:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Poznámky:**
- Žádné zámky držené během generování odpovědi
- Získání kontextu zpracovává `cs_main` interně
- `block_hash` zahrnuto pro referenci, ale nepoužívá se při validaci

### 2. Externí těžba

**Odpovědnosti externího mineru:**
1. Číst plot soubory z disku
2. Vypočítat scoop na základě generačního podpisu a výšky
3. Najít nonce s nejlepším deadline
4. Odeslat do uzlu přes `submit_nonce`

**Formát plot souboru:**
- Založeno na formátu POC2 (Burstcoin)
- Vylepšeno o bezpečnostní opravy a vylepšení škálovatelnosti
- Viz atribuce v `CLAUDE.md`

**Implementace mineru:** Externí (např. založeno na Scavenger)

### 3. Odeslání a validace nonce

**RPC příkaz:** `submit_nonce`

**Parametry:**
```
height, generation_signature, account_id, seed, nonce, quality (volitelné)
```

**Tok validace (optimalizované pořadí):**

#### Krok 1: Rychlá validace formátu
```cpp
// Account ID: 40 hex znaků = 20 bajtů
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 hex znaků = 32 bajtů
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Krok 2: Získání kontextu
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Vrací: height, generation_signature, base_target, block_hash
```

**Zamykání:** `cs_main` zpracováno interně, žádné zámky držené ve vláknu RPC

#### Krok 3: Validace kontextu
```cpp
// Kontrola výšky
if (height != context.height) reject;

// Kontrola generačního podpisu
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Krok 4: Ověření peněženky
```cpp
// Určit efektivního podpisujícího (s ohledem na přiřazení)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Zkontrolovat, zda má uzel privátní klíč pro efektivního podpisujícího
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Podpora přiřazení:** Vlastník plotu může přiřadit práva na forging jiné adrese. Peněženka musí mít klíč pro efektivního podpisujícího, ne nutně vlastníka plotu.

#### Krok 5: Validace důkazu
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 bajtů
    block_height,
    nonce,
    seed,                // 32 bajtů
    min_compression,
    max_compression,
    &result             // Výstup: quality, deadline
);
```

**Algoritmus:**
1. Dekódovat generační podpis z hex
2. Vypočítat nejlepší kvalitu v rozsahu komprese pomocí algoritmů optimalizovaných pro SIMD
3. Validovat, že kvalita splňuje požadavky obtížnosti
4. Vrátit surovou hodnotu kvality

**Implementace:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Krok 6: Výpočet Time Bending
```cpp
// Surový deadline upravený na obtížnost (sekundy)
uint64_t deadline_seconds = quality / base_target;

// Čas forgu s Time Bending (sekundy)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Vzorec Time Bending:**
```
Y = scale * (X^(1/3))
kde:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Účel:** Transformuje exponenciální na chí-kvadrát distribuci. Velmi dobrá řešení se vytvářejí později (síť má čas prohledat disky), špatná řešení jsou vylepšena. Redukuje dlouhé bloky, udržuje průměr 120s.

**Implementace:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Krok 7: Odeslání do forgeru
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // NE deadline - přepočítáno ve forgeru
    height,
    generation_signature
);
```

**Design založený na frontě:**
- Odeslání vždy uspěje (přidáno do fronty)
- RPC vrací okamžitě
- Pracovní vlákno zpracovává asynchronně

**Implementace:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Zpracování fronty forgeru

**Architektura:**
- Jedno perzistentní pracovní vlákno
- FIFO fronta odesílání
- Stav forgingu bez zámků (pouze pracovní vlákno)
- Žádné vnořené zámky (prevence deadlocků)

**Hlavní smyčka pracovního vlákna:**
```cpp
while (!shutdown) {
    // 1. Zkontrolovat zda jsou ve frontě odesílání
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Čekat na deadline nebo nové odesílání
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**Logika ProcessSubmission:**
```cpp
1. Získat čerstvý kontext: GetNewBlockContext(*chainman)

2. Kontroly zastarání (tiché zahození):
   - Nesoulad výšky → zahodit
   - Nesoulad generačního podpisu → zahodit
   - Změna hashe tip bloku (reorg) → reset stavu forgingu

3. Porovnání kvality:
   - Pokud quality >= current_best → zahodit

4. Vypočítat Time Bended deadline:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Aktualizovat stav forgingu:
   - Zrušit existující forging (pokud nalezeno lepší)
   - Uložit: account_id, seed, nonce, quality, deadline
   - Vypočítat: forge_time = block_time + deadline_seconds
   - Uložit hash tipu pro detekci reorgu
```

**Implementace:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Čekání na deadline a forging bloku

**WaitForDeadlineOrNewSubmission:**

**Podmínky čekání:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Když je dosaženo deadline - validace čerstvého kontextu:**
```cpp
1. Získat aktuální kontext: GetNewBlockContext(*chainman)

2. Validace výšky:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Validace generačního podpisu:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Hraniční případ base target:
   if (forging_base_target != current_base_target) {
       // Přepočítat deadline s novým base target
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Čekat znovu
   }

5. Vše platné → ForgeBlock()
```

**Proces ForgeBlock:**

```cpp
1. Určit efektivního podpisujícího (podpora přiřazení):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Vytvořit coinbase skript:
   coinbase_script = P2WPKH(effective_signer);  // Platí efektivnímu podpisujícímu

3. Vytvořit šablonu bloku:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Přidat PoCX důkaz:
   block.pocxProof.account_id = plot_address;    // Původní adresa plotu
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Přepočítat merkle root:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Podepsat blok:
   // Použít klíč efektivního podpisujícího (může být jiný než vlastník plotu)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Odeslat do řetězce:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Zpracování výsledku:
   if (accepted) {
       log_success();
       reset_forging_state();  // Připraven na další blok
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implementace:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Klíčová designová rozhodnutí:**
- Coinbase platí efektivnímu podpisujícímu (respektuje přiřazení)
- Důkaz obsahuje původní adresu plotu (pro validaci)
- Podpis od klíče efektivního podpisujícího (důkaz vlastnictví)
- Vytvoření šablony automaticky zahrnuje transakce z mempoolu

---

## Validace bloků

### Tok validace příchozích bloků

Když je blok přijat ze sítě nebo odeslán lokálně, prochází validací v několika fázích:

### Fáze 1: Validace hlavičky (CheckBlockHeader)

**Validace bez kontextu:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX validace (když je definováno ENABLE_POCX):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Základní validace podpisu (zatím bez podpory přiřazení)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Základní validace podpisu:**
1. Zkontrolovat přítomnost polí pubkey a signature
2. Validovat velikost pubkey (33 bajtů komprimovaný)
3. Validovat velikost podpisu (65 bajtů kompaktní)
4. Obnovit pubkey z podpisu: `pubkey.RecoverCompact(hash, signature)`
5. Ověřit, že obnovený pubkey odpovídá uloženému pubkey

**Implementace:** `src/validation.cpp:CheckBlockHeader()`
**Logika podpisu:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Fáze 2: Validace bloku (CheckBlock)

**Validuje:**
- Správnost merkle root
- Platnost transakcí
- Požadavky coinbase
- Limity velikosti bloku
- Standardní konsensuální pravidla Bitcoinu

**Implementace:** `src/consensus/validation.cpp:CheckBlock()`

### Fáze 3: Kontextová validace hlavičky (ContextualCheckBlockHeader)

**PoCX-specifická validace:**

```cpp
#ifdef ENABLE_POCX
    // Krok 1: Validovat generační podpis
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Krok 2: Validovat base target
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Krok 3: Validovat proof of capacity
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

    // Krok 4: Ověřit časování deadline
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Kroky validace:**
1. **Generační podpis:** Musí odpovídat vypočítané hodnotě z předchozího bloku
2. **Base Target:** Musí odpovídat výpočtu úpravy obtížnosti
3. **Úroveň škálování:** Musí splňovat síťové minimum (`compression >= min_compression`)
4. **Deklarace kvality:** Odeslaná kvalita musí odpovídat vypočítané kvalitě z důkazu
5. **Proof of Capacity:** Validace kryptografického důkazu (optimalizovaná pro SIMD)
6. **Časování deadline:** Time-bended deadline (`poc_time`) musí být ≤ uplynulý čas

**Implementace:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Fáze 4: Připojení bloku (ConnectBlock)

**Úplná kontextová validace:**

```cpp
#ifdef ENABLE_POCX
    // Rozšířená validace podpisu s podporou přiřazení
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Rozšířená validace podpisu:**
1. Provést základní validaci podpisu
2. Extrahovat account ID z obnoveného pubkey
3. Získat efektivního podpisujícího pro adresu plotu: `GetEffectiveSigner(plot_address, height, view)`
4. Ověřit, že pubkey účet odpovídá efektivnímu podpisujícímu

**Logika přiřazení:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Vrátit přiřazeného podpisujícího
    }

    return plotAddress;  // Žádné přiřazení - podepisuje vlastník plotu
}
```

**Implementace:**
- Připojení: `src/validation.cpp:ConnectBlock()`
- Rozšířená validace: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Logika přiřazení: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Fáze 5: Aktivace řetězce

**Tok ProcessNewBlock:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Validovat a uložit na disk
    2. ActivateBestChain → Aktualizovat tip řetězce, pokud je to nejlepší řetězec
    3. Oznámit síti nový blok
}
```

**Implementace:** `src/validation.cpp:ProcessNewBlock()`

### Souhrn validace

**Kompletní validační cesta:**
```
Přijetí bloku
    ↓
CheckBlockHeader (základní podpis)
    ↓
CheckBlock (transakce, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, base target, PoC důkaz, deadline)
    ↓
ConnectBlock (rozšířený podpis s přiřazeními, přechody stavů)
    ↓
ActivateBestChain (zpracování reorgů, rozšíření řetězce)
    ↓
Šíření po síti
```

---

## Systém přiřazení

### Přehled

Přiřazení umožňují vlastníkům plotů delegovat práva na forging na jiné adresy při zachování vlastnictví plotů.

**Případy použití:**
- Poolová těžba (ploty přiřazeny k adrese poolu)
- Studené úložiště (těžební klíč oddělený od vlastnictví plotu)
- Vícestranná těžba (sdílená infrastruktura)

### Architektura přiřazení

**Design pouze s OP_RETURN:**
- Přiřazení uložena ve výstupech OP_RETURN (žádné UTXO)
- Žádné požadavky na utracení (žádný dust, žádné poplatky za držení)
- Sledováno v rozšířeném stavu CCoinsViewCache
- Aktivováno po období zpoždění (výchozí: 4 bloky)

**Stavy přiřazení:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Přiřazení neexistuje
    ASSIGNING = 1,   // Přiřazení čeká na aktivaci (období zpoždění)
    ASSIGNED = 2,    // Přiřazení aktivní, forging povolen
    REVOKING = 3,    // Revokace čeká (období zpoždění, stále aktivní)
    REVOKED = 4      // Revokace dokončena, přiřazení již není aktivní
};
```

### Vytváření přiřazení

**Formát transakce:**
```cpp
Transaction {
    inputs: [any]  // Prokazuje vlastnictví adresy plotu
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Pravidla validace:**
1. Vstup musí být podepsán vlastníkem plotu (prokazuje vlastnictví)
2. OP_RETURN obsahuje platná data přiřazení
3. Plot musí být UNASSIGNED nebo REVOKED
4. Žádná duplicitní čekající přiřazení v mempoolu
5. Zaplacen minimální transakční poplatek

**Aktivace:**
- Přiřazení se stává ASSIGNING při výšce potvrzení
- Stává se ASSIGNED po období zpoždění (4 bloky regtest, 30 bloků mainnet)
- Zpoždění zabraňuje rychlým přeřazením během závodů o bloky

**Implementace:** `src/script/forging_assignment.h`, validace v ConnectBlock

### Revokace přiřazení

**Formát transakce:**
```cpp
Transaction {
    inputs: [any]  // Prokazuje vlastnictví adresy plotu
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Efekt:**
- Okamžitý přechod stavu na REVOKED
- Vlastník plotu může okamžitě provádět forging
- Poté může vytvořit nové přiřazení

### Validace přiřazení během těžby

**Určení efektivního podpisujícího:**
```cpp
// Ve validaci submit_nonce
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// Ve forgingu bloku
coinbase_script = P2WPKH(effective_signer);  // Odměna jde sem

// V podpisu bloku
signature = effective_signer_key.SignCompact(hash);  // Musí podepsat efektivním podpisujícím
```

**Validace bloku:**
```cpp
// Ve VerifyPoCXBlockCompactSignature (rozšířená)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Klíčové vlastnosti:**
- Důkaz vždy obsahuje původní adresu plotu
- Podpis musí být od efektivního podpisujícího
- Coinbase platí efektivnímu podpisujícímu
- Validace používá stav přiřazení při výšce bloku

---

## Šíření po síti

### Oznámení bloku

**Standardní P2P protokol Bitcoinu:**
1. Vykovaný blok odeslán přes `ProcessNewBlock()`
2. Blok validován a přidán do řetězce
3. Síťová notifikace: `GetMainSignals().BlockConnected()`
4. P2P vrstva vysílá blok peerům

**Implementace:** Standardní Bitcoin Core net_processing

### Přenos bloků

**Kompaktní bloky (BIP 152):**
- Použity pro efektivní šíření bloků
- Odesílají se pouze ID transakcí
- Peeři požadují chybějící transakce

**Přenos plných bloků:**
- Záložní metoda, když kompaktní bloky selžou
- Přenášena kompletní data bloku

### Reorganizace řetězce

**Zpracování reorgů:**
```cpp
// V pracovním vláknu forgeru
if (current_tip_hash != stored_tip_hash) {
    // Detekována reorganizace řetězce
    reset_forging_state();
    log("Tip řetězce se změnil, resetuji forging");
}
```

**Na úrovni blockchainu:**
- Standardní zpracování reorgů Bitcoin Core
- Nejlepší řetězec určen chainwork
- Odpojené bloky vráceny do mempoolu

---

## Technické podrobnosti

### Prevence deadlocků

**Vzor ABBA deadlocku (zamezeno):**
```
Vlákno A: cs_main → cs_wallet
Vlákno B: cs_wallet → cs_main
```

**Řešení:**
1. **submit_nonce:** Nulové použití cs_main
   - `GetNewBlockContext()` zpracovává zamykání interně
   - Veškerá validace před odesláním do forgeru

2. **Forger:** Architektura založená na frontě
   - Jedno pracovní vlákno (žádná spojení vláken)
   - Čerstvý kontext při každém přístupu
   - Žádné vnořené zámky

3. **Kontroly peněženky:** Prováděny před drahými operacemi
   - Brzké odmítnutí, pokud není k dispozici klíč
   - Odděleno od přístupu ke stavu blockchainu

### Optimalizace výkonu

**Validace s rychlým selháním:**
```cpp
1. Kontroly formátu (okamžité)
2. Validace kontextu (lehká)
3. Ověření peněženky (lokální)
4. Validace důkazu (drahý SIMD)
```

**Jedno získání kontextu:**
- Jedno volání `GetNewBlockContext()` na odeslání
- Cachování výsledků pro více kontrol
- Žádné opakované získávání cs_main

**Efektivita fronty:**
- Lehká struktura odesílání
- Žádný base_target/deadline ve frontě (přepočítáno čerstvě)
- Minimální paměťová stopa

### Zpracování zastarání

**"Hloupý" design forgeru:**
- Žádné odběry událostí blockchainu
- Líná validace, když je potřeba
- Tiché zahazování zastaralých odesílání

**Výhody:**
- Jednoduchá architektura
- Žádná složitá synchronizace
- Robustní vůči hraničním případům

**Zpracované hraniční případy:**
- Změny výšky → zahodit
- Změny generačního podpisu → zahodit
- Změny base target → přepočítat deadline
- Reorgy → reset stavu forgingu

### Kryptografické detaily

**Generační podpis:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Hash podpisu bloku:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Formát kompaktního podpisu:**
- 65 bajtů: [recovery_id][r][s]
- Umožňuje obnovu veřejného klíče
- Použito pro úsporu místa

**Account ID:**
- 20bajtový HASH160 komprimovaného veřejného klíče
- Odpovídá formátům adres Bitcoinu (P2PKH, P2WPKH)

### Budoucí vylepšení

**Dokumentovaná omezení:**
1. Žádné metriky výkonu (míry odesílání, distribuce deadlinů)
2. Žádná detailní kategorizace chyb pro těžaře
3. Omezené dotazování stavu forgeru (aktuální deadline, hloubka fronty)

**Potenciální vylepšení:**
- RPC pro stav forgeru
- Metriky pro efektivitu těžby
- Vylepšené logování pro ladění
- Podpora protokolu poolů

---

## Reference kódu

**Hlavní implementace:**
- RPC rozhraní: `src/pocx/rpc/mining.cpp`
- Fronta forgeru: `src/pocx/mining/scheduler.cpp`
- Validace konsenzu: `src/pocx/consensus/validation.cpp`
- Validace důkazu: `src/pocx/consensus/pocx.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- Validace bloků: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Logika přiřazení: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Správa kontextu: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Datové struktury:**
- Formát bloku: `src/primitives/block.h`
- Konsensuální parametry: `src/consensus/params.h`
- Sledování přiřazení: `src/coins.h` (rozšíření CCoinsViewCache)

---

## Příloha: Specifikace algoritmů

### Vzorec Time Bending

**Matematická definice:**
```
deadline_seconds = quality / base_target  (surový)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

kde:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Implementace:**
- Aritmetika s pevnou řádovou čárkou (formát Q42)
- Výpočet třetí odmocniny pouze s celými čísly
- Optimalizováno pro 256bitovou aritmetiku

### Výpočet kvality

**Proces:**
1. Vygenerovat scoop z generačního podpisu a výšky
2. Přečíst data plotu pro vypočítaný scoop
3. Hash: `SHABAL256(generation_signature || scoop_data)`
4. Testovat úrovně škálování od min do max
5. Vrátit nejlepší nalezenou kvalitu

**Škálování:**
- Úroveň X0: POC2 baseline (teoretická)
- Úroveň X1: XOR-transpose baseline
- Úroveň Xn: 2^(n-1) × práce X1 vloženo
- Vyšší škálování = více práce při generování plotu

### Úprava base target

**Úprava při každém bloku:**
1. Vypočítat klouzavý průměr nedávných base targets
2. Vypočítat skutečný časový rozsah vs cílový časový rozsah pro klouzavé okno
3. Upravit base target proporcionálně
4. Omezit pro prevenci extrémních výkyvů

**Vzorec:**
```
avg_base_target = moving_average(nedávné base targets)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*Tato dokumentace odráží kompletní implementaci konsenzu PoCX k říjnu 2025.*

---

[← Předchozí: Formát plotů](2-plot-format.md) | [Obsah](index.md) | [Další: Forging přiřazení →](4-forging-assignments.md)
