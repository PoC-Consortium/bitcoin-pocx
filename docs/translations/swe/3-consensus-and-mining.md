[<- Föregående: Plotformat](2-plot-format.md) | [Innehållsförteckning](index.md) | [Nästa: Forging Assignments ->](4-forging-assignments.md)

---

# Kapitel 3: Bitcoin-PoCX konsensus och miningprocess

Fullständig teknisk specifikation av PoCX (Proof of Capacity neXt generation)-konsensusmekanismen och miningprocessen integrerad i Bitcoin Core.

---

## Innehållsförteckning

1. [Översikt](#översikt)
2. [Konsensusarkitektur](#konsensusarkitektur)
3. [Miningprocess](#miningprocess)
4. [Blockvalidering](#blockvalidering)
5. [Tilldelningssystem](#tilldelningssystem)
6. [Nätverkspropagering](#nätverkspropagering)
7. [Tekniska detaljer](#tekniska-detaljer)

---

## Översikt

Bitcoin-PoCX implementerar en ren Proof of Capacity-konsensusmekanism som fullständig ersättning för Bitcoins Proof of Work. Detta är en ny kedja utan krav på bakåtkompatibilitet.

**Nyckeiegenskaper:**
- **Energieffektiv:** Mining använder förgenererade plotfiler istället för beräkningshashning
- **Tidsböjda deadlines:** Fördelningsomvandling (exponentiell->chi-kvadrat) minskar långa block, förbättrar genomsnittliga blocktider
- **Tilldelningsstöd:** Plotägare kan delegera forgingrättigheter till andra adresser
- **Native C++-integration:** Kryptografiska algoritmer implementerade i C++ för konsensusvalidering

**Miningflöde:**
```
Extern miner -> get_mining_info -> Beräkna nonce -> submit_nonce ->
Forger-kö -> Deadline-väntan -> Blockforgning -> Nätverkspropagering ->
Blockvalidering -> Kedjeutökning
```

---

## Konsensusarkitektur

### Blockstruktur

PoCX-block utökar Bitcoins blockstruktur med ytterligare konsensusfält:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Plot-seed (32 bytes)
    std::array<uint8_t, 20> account_id;       // Plotadress (20-byte hash160)
    uint32_t compression;                     // Skalningsnivå (1-255)
    uint64_t nonce;                           // Miningnonce (64-bit)
    uint64_t quality;                         // Hävdad kvalitet (PoC-hashutdata)
};

class CBlockHeader {
    // Standard Bitcoin-fält
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCX-konsensusfält (ersätter nBits och nNonce)
    int nHeight;                              // Blockhöjd (kontextfri validering)
    uint256 generationSignature;              // Generationssignatur (miningenttropi)
    uint64_t nBaseTarget;                     // Svårighetsparameter (inverterad svårighet)
    PoCXProof pocxProof;                      // Miningbevis

    // Blocksignaturfält
    std::array<uint8_t, 33> vchPubKey;        // Komprimerad publik nyckel (33 bytes)
    std::array<uint8_t, 65> vchSignature;     // Kompakt signatur (65 bytes)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Transaktioner
};
```

**Notera:** Signaturen (`vchSignature`) exkluderas från blockhashberäkning för att förhindra formbarhet.

**Implementation:** `src/primitives/block.h`

### Generationssignatur

Generationssignaturen skapar miningenttropi och förhindrar förberäkningsattacker.

**Beräkning:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**Genesisblock:** Använder en hårdkodad initial generationssignatur

**Implementation:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Basmål (svårighet)

Basmål är det inverterade av svårighet - högre värden betyder enklare mining.

**Justeringsalgoritm:**
- Målblocktid: 120 sekunder (mainnet), 1 sekund (regtest)
- Justeringsintervall: Varje block
- Använder glidande medelvärde av senaste basmål
- Begränsad för att förhindra extrema svårighetssvängningar

**Implementation:** `src/consensus/params.h`, svårighetslogik i blockskapande

### Skalningsnivåer

PoCX stöder skalbart proof-of-work i plotfiler genom skalningsnivåer (Xn).

**Dynamiska gränser:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minsta accepterade nivå
    uint8_t nPoCXTargetCompression;  // Rekommenderad nivå
};
```

**Schema för skalningsökning:**
- Exponentiella intervall: År 4, 12, 28, 60, 124 (halveringar 1, 3, 7, 15, 31)
- Minsta skalningsnivå ökar med 1
- Målskalningsnivå ökar med 1
- Bibehåller säkerhetsmarginal mellan plotskapande och uppslagskostnader
- Maximal skalningsnivå: 255

**Implementation:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Miningprocess

### 1. Hämtning av mininginformation

**RPC-kommando:** `get_mining_info`

**Process:**
1. Anropa `GetNewBlockContext(chainman)` för att hämta aktuellt blockchainstillstånd
2. Beräkna dynamiska kompressionsgränser för aktuell höjd
3. Returnera miningparametrar

**Svar:**
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

**Implementation:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Noteringar:**
- Inga lås hålls under svargenerering
- Kontextinhämtning hanterar `cs_main` internt
- `block_hash` inkluderad för referens men används inte i validering

### 2. Extern mining

**Externa miners ansvar:**
1. Läs plotfiler från disk
2. Beräkna scoop baserat på generationssignatur och höjd
3. Hitta nonce med bästa deadline
4. Skicka till nod via `submit_nonce`

**Plotfilformat:**
- Baserat på POC2-format (Burstcoin)
- Förbättrat med säkerhetsfixar och skalbarhetförbättringar
- Se attribution i `CLAUDE.md`

**Minerimplementation:** Extern (t.ex. baserad på Scavenger)

### 3. Nonce-inlämning och validering

**RPC-kommando:** `submit_nonce`

**Parametrar:**
```
height, generation_signature, account_id, seed, nonce, quality (valfritt)
```

**Valideringsflöde (optimerad ordning):**

#### Steg 1: Snabb formatvalidering
```cpp
// Konto-ID: 40 hex-tecken = 20 bytes
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 hex-tecken = 32 bytes
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Steg 2: Kontextinhämtning
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Returnerar: height, generation_signature, base_target, block_hash
```

**Låsning:** `cs_main` hanteras internt, inga lås hålls i RPC-tråden

#### Steg 3: Kontextvalidering
```cpp
// Höjdkontroll
if (height != context.height) reject;

// Generationssignaturkontroll
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Steg 4: Plånboksverifiering
```cpp
// Bestäm effektiv signerare (med hänsyn till tilldelningar)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Kontrollera om noden har privat nyckel för effektiv signerare
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Tilldelningsstöd:** Plotägare kan tilldela forgingrättigheter till annan adress. Plånboken måste ha nyckel för den effektiva signeraren, inte nödvändigtvis plotägaren.

#### Steg 5: Bevisvalidering
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
    &result             // Utdata: quality, deadline
);
```

**Algoritm:**
1. Avkoda generationssignatur från hex
2. Beräkna bästa kvalitet i kompressionsintervall med SIMD-optimerade algoritmer
3. Validera att kvalitet uppfyller svårighetskrav
4. Returnera rått kvalitetsvärde

**Implementation:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Steg 6: Time Bending-beräkning
```cpp
// Rå svårighetsjusterad deadline (sekunder)
uint64_t deadline_seconds = quality / base_target;

// Tidsböjd forgningstid (sekunder)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Time Bending-formel:**
```
Y = scale * (X^(1/3))
där:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Syfte:** Omvandlar exponentiell till chi-kvadratfördelning. Mycket bra lösningar forgas senare (nätverket har tid att skanna diskar), dåliga lösningar förbättras. Minskar långa block, bibehåller 120s genomsnitt.

**Implementation:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Steg 7: Forger-inlämning
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // INTE deadline - omberäknas i forger
    height,
    generation_signature
);
```

**Köbaserad design:**
- Inlämning lyckas alltid (läggs till i kö)
- RPC returnerar omedelbart
- Arbetartråd bearbetar asynkront

**Implementation:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Forger-köbearbetning

**Arkitektur:**
- Enskild persistent arbetartråd
- FIFO-inlämningskö
- Låsfritt forgningstillstånd (endast arbetartråd)
- Inga nästlade lås (deadlock-förebyggande)

**Arbetartrådens huvudloop:**
```cpp
while (!shutdown) {
    // 1. Kontrollera efter köade inlämningar
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Vänta på deadline eller ny inlämning
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**ProcessSubmission-logik:**
```cpp
1. Hämta färsk kontext: GetNewBlockContext(*chainman)

2. Inaktualitetskontroller (tyst kassering):
   - Höjdmismatch -> kassera
   - Generationssignaturmismatch -> kassera
   - Tippblockhash ändrad (reorg) -> återställ forgningstillstånd

3. Kvalitetsjämförelse:
   - Om kvalitet >= current_best -> kassera

4. Beräkna tidsböjd deadline:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Uppdatera forgningstillstånd:
   - Avbryt befintlig forgning (om bättre hittad)
   - Lagra: account_id, seed, nonce, quality, deadline
   - Beräkna: forge_time = block_time + deadline_seconds
   - Lagra tipphash för reorg-detektering
```

**Implementation:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Deadline-väntan och blockforgning

**WaitForDeadlineOrNewSubmission:**

**Väntevillkor:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**När deadline nåtts - färsk kontextvalidering:**
```cpp
1. Hämta aktuell kontext: GetNewBlockContext(*chainman)

2. Höjdvalidering:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Generationssignaturvalidering:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Basmål-kantfall:
   if (forging_base_target != current_base_target) {
       // Omberäkna deadline med nytt basmål
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Vänta igen
   }

5. Allt giltigt -> ForgeBlock()
```

**ForgeBlock-process:**

```cpp
1. Bestäm effektiv signerare (tilldelningsstöd):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Skapa coinbase-skript:
   coinbase_script = P2WPKH(effective_signer);  // Betalar effektiv signerare

3. Skapa blockmall:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Lägg till PoCX-bevis:
   block.pocxProof.account_id = plot_address;    // Original plotadress
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Omberäkna merkle root:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Signera block:
   // Använd effektiv signerares nyckel (kan skilja sig från plotägare)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Skicka till kedja:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Resultathantering:
   if (accepted) {
       log_success();
       reset_forging_state();  // Redo för nästa block
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implementation:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Viktiga designbeslut:**
- Coinbase betalar effektiv signerare (respekterar tilldelningar)
- Bevis innehåller original plotadress (för validering)
- Signatur från effektiv signerares nyckel (ägarskapsbevis)
- Mallskapande inkluderar mempooltransaktioner automatiskt

---

## Blockvalidering

### Valideringsflöde för inkommande block

När ett block tas emot från nätverket eller skickas lokalt genomgår det validering i flera steg:

### Steg 1: Headervalidering (CheckBlockHeader)

**Kontextfri validering:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX-validering (när ENABLE_POCX definierad):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Grundläggande signaturvalidering (inget tilldelningsstöd ännu)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Grundläggande signaturvalidering:**
1. Kontrollera närvaro av pubkey- och signaturfält
2. Validera pubkey-storlek (33 bytes komprimerad)
3. Validera signaturstorlek (65 bytes kompakt)
4. Återställ pubkey från signatur: `pubkey.RecoverCompact(hash, signature)`
5. Verifiera att återställd pubkey matchar lagrad pubkey

**Implementation:** `src/validation.cpp:CheckBlockHeader()`
**Signaturlogik:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Steg 2: Blockvalidering (CheckBlock)

**Validerar:**
- Merkle root-korrekthet
- Transaktionsgiltighet
- Coinbase-krav
- Blockstorleksgränser
- Standard Bitcoin-konsensusregler

**Implementation:** `src/consensus/validation.cpp:CheckBlock()`

### Steg 3: Kontextuell headervalidering (ContextualCheckBlockHeader)

**PoCX-specifik validering:**

```cpp
#ifdef ENABLE_POCX
    // Steg 1: Validera generationssignatur
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Steg 2: Validera basmål
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Steg 3: Validera proof of capacity
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

    // Steg 4: Verifiera deadline-timing
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Valideringssteg:**
1. **Generationssignatur:** Måste matcha beräknat värde från föregående block
2. **Basmål:** Måste matcha svårighetsjusteringsberäkning
3. **Skalningsnivå:** Måste uppfylla nätverkets minimum (`compression >= min_compression`)
4. **Kvalitetspåstående:** Skickad kvalitet måste matcha beräknad kvalitet från bevis
5. **Proof of Capacity:** Kryptografisk bevisvalidering (SIMD-optimerad)
6. **Deadline-timing:** Tidsböjd deadline (`poc_time`) måste vara <= förfluten tid

**Implementation:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Steg 4: Blockanslutning (ConnectBlock)

**Fullständig kontextuell validering:**

```cpp
#ifdef ENABLE_POCX
    // Utökad signaturvalidering med tilldelningsstöd
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Utökad signaturvalidering:**
1. Utför grundläggande signaturvalidering
2. Extrahera konto-ID från återställd pubkey
3. Hämta effektiv signerare för plotadress: `GetEffectiveSigner(plot_address, height, view)`
4. Verifiera att pubkey-konto matchar effektiv signerare

**Tilldelningslogik:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Returnera tilldelad signerare
    }

    return plotAddress;  // Ingen tilldelning - plotägare signerar
}
```

**Implementation:**
- Anslutning: `src/validation.cpp:ConnectBlock()`
- Utökad validering: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Tilldelningslogik: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Steg 5: Kedjeaktivering

**ProcessNewBlock-flöde:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock -> Validera och lagra på disk
    2. ActivateBestChain -> Uppdatera kedjetipp om detta är bästa kedja
    3. Meddela nätverk om nytt block
}
```

**Implementation:** `src/validation.cpp:ProcessNewBlock()`

### Valideringssammanfattning

**Komplett valideringsväg:**
```
Ta emot block
    |
CheckBlockHeader (grundläggande signatur)
    |
CheckBlock (transaktioner, merkle)
    |
ContextualCheckBlockHeader (gen sig, basmål, PoC-bevis, deadline)
    |
ConnectBlock (utökad signatur med tilldelningar, tillståndsövergångar)
    |
ActivateBestChain (reorg-hantering, kedjeutökning)
    |
Nätverkspropagering
```

---

## Tilldelningssystem

### Översikt

Tilldelningar tillåter plotägare att delegera forgingrättigheter till andra adresser samtidigt som plotägarskapet bibehålls.

**Användningsfall:**
- Poolmining (plottar tilldelar till pooladress)
- Kall lagring (miningnyckel separat från plotägarskap)
- Flerpartsmining (delad infrastruktur)

### Tilldelningsarkitektur

**OP_RETURN-baserad design:**
- Tilldelningar lagrade i OP_RETURN-utdata (ingen UTXO)
- Inga utgiftskrav (ingen dust, inga avgifter för att hålla)
- Spårade i CCoinsViewCache-utökat tillstånd
- Aktiverade efter fördröjningsperiod (standard: 4 block)

**Tilldelningsstatus:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Ingen tilldelning existerar
    ASSIGNING = 1,   // Tilldelning väntar på aktivering (fördröjningsperiod)
    ASSIGNED = 2,    // Tilldelning aktiv, forgning tillåten
    REVOKING = 3,    // Återkallelse väntar (fördröjningsperiod, fortfarande aktiv)
    REVOKED = 4      // Återkallelse slutförd, tilldelning inte längre aktiv
};
```

### Skapa tilldelningar

**Transaktionsformat:**
```cpp
Transaction {
    inputs: [any]  // Bevisar ägarskap av plotadress
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Valideringsregler:**
1. Input måste vara signerad av plotägare (bevisar ägarskap)
2. OP_RETURN innehåller giltig tilldelningsdata
3. Plot måste vara UNASSIGNED eller REVOKED
4. Inga dubbletter av väntande tilldelningar i mempool
5. Minsta transaktionsavgift betald

**Aktivering:**
- Tilldelning blir ASSIGNING vid bekräftelsehöjd
- Blir ASSIGNED efter fördröjningsperiod (4 block regtest, 30 block mainnet)
- Fördröjning förhindrar snabba omtilldelningar under blockrace

**Implementation:** `src/script/forging_assignment.h`, validering i ConnectBlock

### Återkalla tilldelningar

**Transaktionsformat:**
```cpp
Transaction {
    inputs: [any]  // Bevisar ägarskap av plotadress
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Effekt:**
- Omedelbar tillståndsövergång till REVOKED
- Plotägare kan forga omedelbart
- Kan skapa ny tilldelning efteråt

### Tilldelningsvalidering under mining

**Bestämning av effektiv signerare:**
```cpp
// I submit_nonce-validering
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// I blockforgning
coinbase_script = P2WPKH(effective_signer);  // Belöning går hit

// I blocksignatur
signature = effective_signer_key.SignCompact(hash);  // Måste signera med effektiv signerare
```

**Blockvalidering:**
```cpp
// I VerifyPoCXBlockCompactSignature (utökad)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Nyckelgenskaper:**
- Bevis innehåller alltid original plotadress
- Signatur måste vara från effektiv signerare
- Coinbase betalar effektiv signerare
- Validering använder tilldelningsstatus vid blockhöjd

---

## Nätverkspropagering

### Blockannonsering

**Standard Bitcoin P2P-protokoll:**
1. Forgat block skickas via `ProcessNewBlock()`
2. Block valideras och läggs till kedja
3. Nätverksnotifiering: `GetMainSignals().BlockConnected()`
4. P2P-lagret sänder block till peers

**Implementation:** Standard Bitcoin Core net_processing

### Blockrelä

**Compact Blocks (BIP 152):**
- Används för effektiv blockpropagering
- Endast transaktions-ID:n skickas initialt
- Peers begär saknade transaktioner

**Full blockrelä:**
- Fallback när compact blocks misslyckas
- Fullständig blockdata överförs

### Kedjereorganiseringar

**Reorg-hantering:**
```cpp
// I forger-arbetartråd
if (current_tip_hash != stored_tip_hash) {
    // Kedjereorganisering detekterad
    reset_forging_state();
    log("Chain tip changed, resetting forging");
}
```

**Blockchainnivå:**
- Standard Bitcoin Core reorg-hantering
- Bästa kedja bestäms av chainwork
- Frånkopplade block returneras till mempool

---

## Tekniska detaljer

### Deadlock-förebyggande

**ABBA-deadlock-mönster (förhindrat):**
```
Tråd A: cs_main -> cs_wallet
Tråd B: cs_wallet -> cs_main
```

**Lösning:**
1. **submit_nonce:** Noll cs_main-användning
   - `GetNewBlockContext()` hanterar låsning internt
   - All validering före forger-inlämning

2. **Forger:** Köbaserad arkitektur
   - Enskild arbetartråd (inga trådjoinsar)
   - Färsk kontext vid varje åtkomst
   - Inga nästlade lås

3. **Plånbokskontroller:** Utförs före dyra operationer
   - Tidig avvisning om ingen nyckel tillgänglig
   - Separerad från blockchain-tillståndsåtkomst

### Prestandaoptimeringar

**Fail-fast-validering:**
```cpp
1. Formatkontroller (omedelbart)
2. Kontextvalidering (lättviktig)
3. Plånboksverifiering (lokal)
4. Bevisvalidering (dyr SIMD)
```

**Enskild kontextinhämtning:**
- Ett `GetNewBlockContext()`-anrop per inlämning
- Cacheresultat för flera kontroller
- Inga upprepade cs_main-förvärvningar

**Köeffektivitet:**
- Lättviktig inlämningsstruktur
- Inget basmål/deadline i kö (omberäknas färskt)
- Minimalt minnesavtryck

### Inaktualitetshantering

**"Dum" forger-design:**
- Inga blockchain-händelseprenumerationer
- Lat validering vid behov
- Tyst kassering av inaktuella inlämningar

**Fördelar:**
- Enkel arkitektur
- Ingen komplex synkronisering
- Robust mot kantfall

**Kantfall som hanteras:**
- Höjdändringar -> kassera
- Generationssignaturändringar -> kassera
- Basmåländringar -> omberäkna deadline
- Reorgar -> återställ forgningstillstånd

### Kryptografiska detaljer

**Generationssignatur:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Blocksignaturhash:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Kompakt signaturformat:**
- 65 bytes: [recovery_id][r][s]
- Möjliggör återställning av publik nyckel
- Används för utrymmeseffektivitet

**Konto-ID:**
- 20-byte HASH160 av komprimerad publik nyckel
- Matchar Bitcoin-adressformat (P2PKH, P2WPKH)

### Framtida förbättringar

**Dokumenterade begränsningar:**
1. Inga prestandamått (inlämningsfrekvenser, deadline-fördelningar)
2. Ingen detaljerad felkategorisering för miners
3. Begränsad forger-statusförfrågning (aktuell deadline, ködjup)

**Potentiella förbättringar:**
- RPC för forgerstatus
- Mått för miningeffektivitet
- Förbättrad loggning för felsökning
- Poolprotokollstöd

---

## Kodreferenser

**Kärnimplementationer:**
- RPC-gränssnitt: `src/pocx/rpc/mining.cpp`
- Forgerkö: `src/pocx/mining/scheduler.cpp`
- Konsensusvalidering: `src/pocx/consensus/validation.cpp`
- Bevisvalidering: `src/pocx/consensus/pocx.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- Blockvalidering: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Tilldelningslogik: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Kontexthantering: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Datastrukturer:**
- Blockformat: `src/primitives/block.h`
- Konsensusparametrar: `src/consensus/params.h`
- Tilldelningsspårning: `src/coins.h` (CCoinsViewCache-utökningar)

---

## Appendix: Algoritmspecifikationer

### Time Bending-formel

**Matematisk definition:**
```
deadline_seconds = quality / base_target  (rå)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

där:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Implementation:**
- Fastpunktsaritmetik (Q42-format)
- Endast heltals-kubikrotsberäkning
- Optimerad för 256-bitars aritmetik

### Kvalitetsberäkning

**Process:**
1. Generera scoop från generationssignatur och höjd
2. Läs plotdata för beräknad scoop
3. Hash: `SHABAL256(generation_signature || scoop_data)`
4. Testa skalningsnivåer från min till max
5. Returnera bästa kvalitet hittad

**Skalning:**
- Nivå X0: POC2-baslinje (teoretisk)
- Nivå X1: XOR-transponeringsbaslinje
- Nivå Xn: 2^(n-1) × X1-arbete inbäddat
- Högre skalning = mer plotgenereringsarbete

### Basmåljustering

**Justering varje block:**
1. Beräkna glidande medelvärde av senaste basmål
2. Beräkna faktisk tidsrymd vs måltidsrymd för rullande fönster
3. Justera basmål proportionellt
4. Begränsa för att förhindra extrema svängningar

**Formel:**
```
avg_base_target = moving_average(senaste basmål)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*Denna dokumentation återspeglar den fullständiga PoCX-konsensusimplementationen per oktober 2025.*

---

[<- Föregående: Plotformat](2-plot-format.md) | [Innehållsförteckning](index.md) | [Nästa: Forging Assignments ->](4-forging-assignments.md)
