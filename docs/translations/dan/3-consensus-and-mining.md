[<- Forrige: Plotformat](2-plot-format.md) | [Indholdsfortegnelse](index.md) | [Naeste: Forging Assignments ->](4-forging-assignments.md)

---

# Kapitel 3: Bitcoin-PoCX konsensus og miningproces

Komplet teknisk specifikation af PoCX (Proof of Capacity neXt generation) konsensusmekanismen og miningprocessen integreret i Bitcoin Core.

---

## Indholdsfortegnelse

1. [Oversigt](#oversigt)
2. [Konsensusarkitektur](#konsensusarkitektur)
3. [Miningproces](#miningproces)
4. [Blokvalidering](#blokvalidering)
5. [Assignment-system](#assignment-system)
6. [Netvaerkspropagering](#netvaerkspropagering)
7. [Tekniske detaljer](#tekniske-detaljer)

---

## Oversigt

Bitcoin-PoCX implementerer en ren Proof of Capacity-konsensusmekanisme som en komplet erstatning for Bitcoins Proof of Work. Dette er en ny kaede uden bagudkompatibilitetskrav.

**Nogleegenskaber:**
- **Energieffektiv:** Mining bruger forgenererede plotfiler i stedet for beregningsmaessig hashing
- **Time-bendede deadlines:** Fordelingstransformation (eksponentiel->chi-kvadrat) reducerer lange blokke, forbedrer gennemsnitlige bloktider
- **Assignment-understottelse:** Plotejere kan delegere forging-rettigheder til andre adresser
- **Nativ C++-integration:** Kryptografiske algoritmer implementeret i C++ til konsensusvalidering

**Mining-flow:**
```
Ekstern miner -> get_mining_info -> Beregn nonce -> submit_nonce ->
Forger-ko -> Deadline-ventetid -> Blokforging -> Netvaerkspropagering ->
Blokvalidering -> Kaedeudvidelse
```

---

## Konsensusarkitektur

### Blokstruktur

PoCX-blokke udvider Bitcoins blokstruktur med yderligere konsensusfelter:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Plotseed (32 bytes)
    std::array<uint8_t, 20> account_id;       // Plotadresse (20-byte hash160)
    uint32_t compression;                     // Skaleringsniveau (1-255)
    uint64_t nonce;                           // Miningnonce (64-bit)
    uint64_t quality;                         // Pastaet kvalitet (PoC-hashoutput)
};

class CBlockHeader {
    // Standard Bitcoin-felter
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCX-konsensusfelter (erstatter nBits og nNonce)
    int nHeight;                              // Blokhojde (kontekstfri validering)
    uint256 generationSignature;              // Generationssignatur (miningentropy)
    uint64_t nBaseTarget;                     // Svaerhedsparameter (omvendt svaerhed)
    PoCXProof pocxProof;                      // Miningbevis

    // Bloksignaturfelter
    std::array<uint8_t, 33> vchPubKey;        // Komprimeret offentlig nogle (33 bytes)
    std::array<uint8_t, 65> vchSignature;     // Kompakt signatur (65 bytes)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Transaktioner
};
```

**Bemaaerkning:** Signaturen (`vchSignature`) er ekskluderet fra blokhash-beregning for at forebygge formbarhed.

**Implementering:** `src/primitives/block.h`

### Generationssignatur

Generationssignaturen skaber miningentropy og forebygger forberegningsangreb.

**Beregning:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**Genesis-blok:** Bruger en hardkodet initial generationssignatur

**Implementering:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Base target (svaerhed)

Base target er det omvendte af svaerhed - hojere vaerdier betyder lettere mining.

**Justeringsalgoritme:**
- Malbloktid: 120 sekunder (mainnet), 1 sekund (regtest)
- Justeringsinterval: Hver blok
- Bruger glidende gennemsnit af nylige base targets
- Begraenset for at forebygge ekstreme svaerhedsudsving

**Implementering:** `src/consensus/params.h`, svaerhedsjustering i blokoprettelse

### Skaleringsniveauer

PoCX understotter skalerbar proof-of-work i plotfiler gennem skaleringsniveauer (Xn).

**Dynamiske graenser:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimum accepteret niveau
    uint8_t nPoCXTargetCompression;  // Anbefalet niveau
};
```

**Tidsplan for skaleringsforøgelse:**
- Eksponentielle intervaller: Ar 4, 12, 28, 60, 124 (halveringer 1, 3, 7, 15, 31)
- Minimum skaleringsniveau stiger med 1
- Malkaleringsniveau stiger med 1
- Opretholder sikkerhedsmargin mellem plotoprettelses- og opslagsomkostninger
- Maksimalt skaleringsniveau: 255

**Implementering:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Miningproces

### 1. Hentning af mininginformation

**RPC-kommando:** `get_mining_info`

**Proces:**
1. Kald `GetNewBlockContext(chainman)` for at hente nuvaerende blockchain-tilstand
2. Beregn dynamiske kompressionsgraenser for nuvaerende hojde
3. Returner miningparametre

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

**Implementering:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Bemaaerkninger:**
- Ingen lase holdt under svargenereringen
- Kontekstanskaffelse handterer `cs_main` internt
- `block_hash` inkluderet til reference, men bruges ikke i validering

### 2. Ekstern mining

**Ansvar for ekstern miner:**
1. Laes plotfiler fra disk
2. Beregn scoop baseret pa generationssignatur og hojde
3. Find nonce med bedste deadline
4. Indsend til node via `submit_nonce`

**Plotfilformat:**
- Baseret pa POC2-format (Burstcoin)
- Forbedret med sikkerhedsrettelser og skalerbarhedsforbedringer
- Se tilskrivning i `CLAUDE.md`

**Minerimplementering:** Ekstern (f.eks. baseret pa Scavenger)

### 3. Nonce-indsendelse og validering

**RPC-kommando:** `submit_nonce`

**Parametre:**
```
height, generation_signature, account_id, seed, nonce, quality (valgfri)
```

**Valideringsflow (optimeret raekkefolge):**

#### Trin 1: Hurtig formatvalidering
```cpp
// Konto-ID: 40 hex-tegn = 20 bytes
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 hex-tegn = 32 bytes
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Trin 2: Kontekstanskaffelse
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Returnerer: height, generation_signature, base_target, block_hash
```

**Lasning:** `cs_main` handteret internt, ingen lase holdt i RPC-trad

#### Trin 3: Kontekstvalidering
```cpp
// Hojdekontrol
if (height != context.height) reject;

// Generationssignaturkontrol
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Trin 4: Wallet-verifikation
```cpp
// Bestem effektiv underskriver (under hensyntagen til assignments)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Kontroller om node har privat nogle til effektiv underskriver
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Assignment-understottelse:** Plotejer kan tildele forging-rettigheder til en anden adresse. Wallet skal have nogle til den effektive underskriver, ikke nodvendigvis plotejeren.

#### Trin 5: Bevisvalidering
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
    &result             // Output: quality, deadline
);
```

**Algoritme:**
1. Dekod generationssignatur fra hex
2. Beregn bedste kvalitet i kompressionsomradet ved hjaelp af SIMD-optimerede algoritmer
3. Valider at kvalitet opfylder svaerhedskrav
4. Returner ra kvalitetsvaerdi

**Implementering:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Trin 6: Time Bending-beregning
```cpp
// Ra svaerhedsjusteret deadline (sekunder)
uint64_t deadline_seconds = quality / base_target;

// Time-bendet forgetid (sekunder)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Time Bending-formel:**
```
Y = scale * (X^(1/3))
hvor:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ca. 0,892979511
```

**Formal:** Transformerer eksponentiel til chi-kvadrat-fordeling. Meget gode losninger forger senere (netvaerket har tid til at scanne diske), darlige losninger forbedres. Reducerer lange blokke, opretholder 120s gennemsnit.

**Implementering:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Trin 7: Forger-indsendelse
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // IKKE deadline - genberegnes i forger
    height,
    generation_signature
);
```

**Ko-baseret design:**
- Indsendelse lykkes altid (tilfojet til ko)
- RPC returnerer med det samme
- Arbejdstrad behandler asynkront

**Implementering:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Forger-kobehandling

**Arkitektur:**
- Enkelt persistent arbejdstrad
- FIFO-indsendelsesenko
- Lasefri forging-tilstand (kun arbejdstrad)
- Ingen indlejrede lase (deadlock-forebyggelse)

**Hovedsloefe for arbejdstrad:**
```cpp
while (!shutdown) {
    // 1. Kontroller for koede indsendelser
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Vent pa deadline eller ny indsendelse
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**ProcessSubmission-logik:**
```cpp
1. Hent frisk kontekst: GetNewBlockContext(*chainman)

2. Foraeldelseskontroller (tavs kassering):
   - Hojdemismatch -> kasser
   - Generationssignaturmismatch -> kasser
   - Tip-blokhash aendret (reorg) -> nulstil forging-tilstand

3. Kvalitetssammenligning:
   - Hvis kvalitet >= current_best -> kasser

4. Beregn Time-bendet deadline:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Opdater forging-tilstand:
   - Annuller eksisterende forging (hvis bedre fundet)
   - Gem: account_id, seed, nonce, quality, deadline
   - Beregn: forge_time = block_time + deadline_seconds
   - Gem tip-hash til reorg-detektion
```

**Implementering:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Deadline-ventetid og blokforging

**WaitForDeadlineOrNewSubmission:**

**Ventebetingelser:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Nar deadline nas - validering af frisk kontekst:**
```cpp
1. Hent nuvaerende kontekst: GetNewBlockContext(*chainman)

2. Hojdevalidering:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Generationssignaturvalidering:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Base target-kanttilfeelde:
   if (forging_base_target != current_base_target) {
       // Genberegn deadline med ny base target
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Vent igen
   }

5. Alt gyldigt -> ForgeBlock()
```

**ForgeBlock-proces:**

```cpp
1. Bestem effektiv underskriver (assignment-understottelse):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Opret coinbase-script:
   coinbase_script = P2WPKH(effective_signer);  // Betaler effektiv underskriver

3. Opret blokskabelon:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Tiloj PoCX-bevis:
   block.pocxProof.account_id = plot_address;    // Original plotadresse
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Genberegn merkle-rod:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Signer blok:
   // Brug effektiv underskriverens nogle (kan vaere forskellig fra plotejer)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Indsend til kaede:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Resultathandtering:
   if (accepted) {
       log_success();
       reset_forging_state();  // Klar til naeste blok
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implementering:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Vigtige designbeslutninger:**
- Coinbase betaler effektiv underskriver (respekterer assignments)
- Bevis indeholder original plotadresse (til validering)
- Signatur fra effektiv underskriverens nogle (ejerskabsbevis)
- Skabelonoprettelse inkluderer mempool-transaktioner automatisk

---

## Blokvalidering

### Valideringsflow for indgaende blokke

Nar en blok modtages fra netvaerket eller indsendes lokalt, gennemgar den validering i flere faser:

### Fase 1: Header-validering (CheckBlockHeader)

**Kontekstfri validering:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX-validering (nar ENABLE_POCX er defineret):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Grundlaeggende signaturvalidering (ingen assignment-understottelse endnu)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Grundlaeggende signaturvalidering:**
1. Kontroller tilstedevaerelse af pubkey- og signaturfelter
2. Valider pubkey-storrelse (33 bytes komprimeret)
3. Valider signaturstorrelse (65 bytes kompakt)
4. Gendan pubkey fra signatur: `pubkey.RecoverCompact(hash, signature)`
5. Bekraeft at gendannet pubkey matcher gemt pubkey

**Implementering:** `src/validation.cpp:CheckBlockHeader()`
**Signaturlogik:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Fase 2: Blokvalidering (CheckBlock)

**Validerer:**
- Merkle-rod-korrekthed
- Transaktionsgyldighed
- Coinbase-krav
- Blokstorrelsesgraenser
- Standard Bitcoin-konsensusregler

**Implementering:** `src/consensus/validation.cpp:CheckBlock()`

### Fase 3: Kontekstuel header-validering (ContextualCheckBlockHeader)

**PoCX-specifik validering:**

```cpp
#ifdef ENABLE_POCX
    // Trin 1: Valider generationssignatur
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Trin 2: Valider base target
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Trin 3: Valider proof of capacity
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

    // Trin 4: Bekraeft deadline-timing
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Valideringstrin:**
1. **Generationssignatur:** Skal matche beregnet vaerdi fra forrige blok
2. **Base target:** Skal matche svaerhedsjusteringsberegning
3. **Skaleringsniveau:** Skal opfylde netvaerksminimum (`compression >= min_compression`)
4. **Kvalitetspastand:** Indsendt kvalitet skal matche beregnet kvalitet fra bevis
5. **Proof of Capacity:** Kryptografisk bevisvalidering (SIMD-optimeret)
6. **Deadline-timing:** Time-bendet deadline (`poc_time`) skal vaere <= forlobet tid

**Implementering:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Fase 4: Blokforbindelse (ConnectBlock)

**Fuld kontekstuel validering:**

```cpp
#ifdef ENABLE_POCX
    // Udvidet signaturvalidering med assignment-understottelse
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Udvidet signaturvalidering:**
1. Udfr grundlaeggende signaturvalidering
2. Udtræk konto-ID fra gendannet pubkey
3. Hent effektiv underskriver for plotadresse: `GetEffectiveSigner(plot_address, height, view)`
4. Bekraeft at pubkey-konto matcher effektiv underskriver

**Assignment-logik:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Returner tildelt underskriver
    }

    return plotAddress;  // Ingen assignment - plotejer underskriver
}
```

**Implementering:**
- Forbindelse: `src/validation.cpp:ConnectBlock()`
- Udvidet validering: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Assignment-logik: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Fase 5: Kaede-aktivering

**ProcessNewBlock-flow:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock -> Valider og gem pa disk
    2. ActivateBestChain -> Opdater kaede-tip, hvis dette er bedste kaede
    3. Notificer netvaerk om ny blok
}
```

**Implementering:** `src/validation.cpp:ProcessNewBlock()`

### Valideringsoversigt

**Komplet valideringssti:**
```
Modtag blok
    |
CheckBlockHeader (grundlaeggende signatur)
    |
CheckBlock (transaktioner, merkle)
    |
ContextualCheckBlockHeader (gen sig, base target, PoC-bevis, deadline)
    |
ConnectBlock (udvidet signatur med assignments, tilstandsovergange)
    |
ActivateBestChain (reorg-handtering, kaedeudvidelse)
    |
Netvaerkspropagering
```

---

## Assignment-system

### Oversigt

Assignments tillader plotejere at delegere forging-rettigheder til andre adresser, mens de bevarer plotejerskabet.

**Anvendelsestilfaelde:**
- Pool-mining (plots tildeler til pooladresse)
- Cold storage (miningnogle adskilt fra plotejerskab)
- Multi-party mining (delt infrastruktur)

### Assignment-arkitektur

**OP_RETURN-baseret design:**
- Assignments gemt i OP_RETURN-outputs (ingen UTXO)
- Ingen forbrugskrav (ingen dust, ingen gebyrer for opbevaring)
- Sporet i CCoinsViewCache udvidet tilstand
- Aktiveret efter forsinkelsesperiode (standard: 4 blokke)

**Assignment-tilstande:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Ingen assignment eksisterer
    ASSIGNING = 1,   // Assignment afventer aktivering (forsinkelsesperiode)
    ASSIGNED = 2,    // Assignment aktiv, forging tilladt
    REVOKING = 3,    // Tilbagekaldelse afventer (forsinkelsesperiode, stadig aktiv)
    REVOKED = 4      // Tilbagekaldelse faerdig, assignment ikke laengere aktiv
};
```

### Oprettelse af assignments

**Transaktionsformat:**
```cpp
Transaction {
    inputs: [any]  // Beviser ejerskab af plotadresse
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Valideringsregler:**
1. Input skal vaere underskrevet af plotejer (beviser ejerskab)
2. OP_RETURN indeholder gyldige assignment-data
3. Plot skal vaere UNASSIGNED eller REVOKED
4. Ingen duplikerede afventende assignments i mempool
5. Minimum transaktionsgebyr betalt

**Aktivering:**
- Assignment bliver ASSIGNING ved bekraeftelseshojde
- Bliver ASSIGNED efter forsinkelsesperiode (4 blokke regtest, 30 blokke mainnet)
- Forsinkelse forebygger hurtige omtildelinger under blokveddeloeb

**Implementering:** `src/script/forging_assignment.h`, validering i ConnectBlock

### Tilbagekaldelse af assignments

**Transaktionsformat:**
```cpp
Transaction {
    inputs: [any]  // Beviser ejerskab af plotadresse
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Effekt:**
- Ojeblikkelig tilstandsovergang til REVOKED
- Plotejer kan forge med det samme
- Kan oprette ny assignment bagefter

### Assignment-validering under mining

**Bestemmelse af effektiv underskriver:**
```cpp
// I submit_nonce-validering
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// I blokforging
coinbase_script = P2WPKH(effective_signer);  // Belonning gar hertil

// I bloksignatur
signature = effective_signer_key.SignCompact(hash);  // Skal underskrive med effektiv underskriver
```

**Blokvalidering:**
```cpp
// I VerifyPoCXBlockCompactSignature (udvidet)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Nogleegenskaber:**
- Bevis indeholder altid original plotadresse
- Signatur skal vaere fra effektiv underskriver
- Coinbase betaler effektiv underskriver
- Validering bruger assignment-tilstand ved blokhojde

---

## Netvaerkspropagering

### Blokannoncering

**Standard Bitcoin P2P-protokol:**
1. Forged blok indsendt via `ProcessNewBlock()`
2. Blok valideret og tilfojet til kaede
3. Netvaerksnotifikation: `GetMainSignals().BlockConnected()`
4. P2P-lag udsender blok til peers

**Implementering:** Standard Bitcoin Core net_processing

### Blokrelay

**Kompakte blokke (BIP 152):**
- Brugt til effektiv blokpropagering
- Kun transaktions-ID'er sendt indledningsvis
- Peers anmoder om manglende transaktioner

**Fuld blokrelay:**
- Fallback nar kompakte blokke fejler
- Komplette blokdata transmitteres

### Kaedereorganiseringer

**Reorg-handtering:**
```cpp
// I forger-arbejdstrad
if (current_tip_hash != stored_tip_hash) {
    // Kaedereorganisering detekteret
    reset_forging_state();
    log("Kaede-tip aendret, nulstiller forging");
}
```

**Blockchain-niveau:**
- Standard Bitcoin Core reorg-handtering
- Bedste kaede bestemt af chainwork
- Afkoblede blokke returneres til mempool

---

## Tekniske detaljer

### Deadlock-forebyggelse

**ABBA-deadlock-monster (forebygget):**
```
Trad A: cs_main -> cs_wallet
Trad B: cs_wallet -> cs_main
```

**Losning:**
1. **submit_nonce:** Nul cs_main-brug
   - `GetNewBlockContext()` handterer lasning internt
   - Al validering for forger-indsendelse

2. **Forger:** Ko-baseret arkitektur
   - Enkelt arbejdstrad (ingen trad-joins)
   - Frisk kontekst ved hver adgang
   - Ingen indlejrede lase

3. **Wallet-kontroller:** Udfort for dyre operationer
   - Tidlig afvisning, hvis ingen nogle tilgaengelig
   - Adskilt fra blockchain-tilstandsadgang

### Ydelsesoptimeringer

**Hurtig-fejl-validering:**
```cpp
1. Formatkontroller (ojeblikkelig)
2. Kontekstvalidering (letvaeegts)
3. Wallet-verifikation (lokal)
4. Bevisvalidering (dyr SIMD)
```

**Enkelt konteksthentning:**
- Et `GetNewBlockContext()`-kald pr. indsendelse
- Cache resultater til flere kontroller
- Ingen gentagne cs_main-anskaffelser

**Ko-effektivitet:**
- Letvaegts indsendelsesstruktur
- Ingen base_target/deadline i ko (genberegnes frisk)
- Minimalt hukommelsesaftryk

### Foraeldelseshandtering

**"Enkelt" forger-design:**
- Ingen blockchain-haendelses-abonnementer
- Doven validering nar nodvendigt
- Tavs kassering af foraeldede indsendelser

**Fordele:**
- Simpel arkitektur
- Ingen kompleks synkronisering
- Robust mod kanttilfaelde

**Kanttilfaelde handteret:**
- Hojdeaendringer -> kasser
- Generationssignaturaendringer -> kasser
- Base target-aendringer -> genberegn deadline
- Reorgs -> nulstil forging-tilstand

### Kryptografiske detaljer

**Generationssignatur:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Bloksignaturhash:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Kompakt signaturformat:**
- 65 bytes: [recovery_id][r][s]
- Tillader gendannelse af offentlig nogle
- Brugt til pladseffektivitet

**Konto-ID:**
- 20-byte HASH160 af komprimeret offentlig nogle
- Matcher Bitcoin-adresseformater (P2PKH, P2WPKH)

### Fremtidige forbedringer

**Dokumenterede begraensninger:**
1. Ingen ydelsesmetrikker (indsendelsesrater, deadline-fordelinger)
2. Ingen detaljeret fejlkategorisering for minere
3. Begraenset forger-statusforespoergsel (nuvaerende deadline, kodybde)

**Potentielle forbedringer:**
- RPC til forger-status
- Metrikker til miningeffektivitet
- Forbedret logning til fejlfinding
- Pool-protokolunderstottelse

---

## Kodereferencer

**Kerneimplementeringer:**
- RPC-graenseflade: `src/pocx/rpc/mining.cpp`
- Forger-ko: `src/pocx/mining/scheduler.cpp`
- Konsensusvalidering: `src/pocx/consensus/validation.cpp`
- Bevisvalidering: `src/pocx/consensus/pocx.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- Blokvalidering: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Assignment-logik: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Kontekststyring: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Datastrukturer:**
- Blokformat: `src/primitives/block.h`
- Konsensusparametre: `src/consensus/params.h`
- Assignment-sporing: `src/coins.h` (CCoinsViewCache-udvidelser)

---

## Appendiks: Algoritmespecifikationer

### Time Bending-formel

**Matematisk definition:**
```
deadline_seconds = quality / base_target  (ra)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

hvor:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ca. 0,892979511
```

**Implementering:**
- Fikspunkt-aritmetik (Q42-format)
- Kun heltalskubikrodsberegning
- Optimeret til 256-bit aritmetik

### Kvalitetsberegning

**Proces:**
1. Generer scoop fra generationssignatur og hojde
2. Laes plotdata for beregnet scoop
3. Hash: `SHABAL256(generation_signature || scoop_data)`
4. Test skaleringsniveauer fra min til max
5. Returner bedste fundne kvalitet

**Skalering:**
- Niveau X0: POC2-baseline (teoretisk)
- Niveau X1: XOR-transpose-baseline
- Niveau Xn: 2^(n-1) x X1-arbejde indlejret
- Hojere skalering = mere plotgenereringsarbejde

### Base target-justering

**Justering ved hver blok:**
1. Beregn glidende gennemsnit af nylige base targets
2. Beregn faktisk tidsrum vs. maltidsrum for rullende vindue
3. Juster base target proportionalt
4. Begraens for at forebygge ekstreme udsving

**Formel:**
```
avg_base_target = moving_average(nylige base targets)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*Denne dokumentation afspejler den komplette PoCX-konsensusimplementering pr. oktober 2025.*

---

[<- Forrige: Plotformat](2-plot-format.md) | [Indholdsfortegnelse](index.md) | [Naeste: Forging Assignments ->](4-forging-assignments.md)
