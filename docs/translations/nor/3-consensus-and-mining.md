[← Forrige: Plotformat](2-plot-format.md) | [Innholdsfortegnelse](index.md) | [Neste: Forging assignments →](4-forging-assignments.md)

---

# Kapittel 3: Bitcoin-PoCX konsensus og miningprosess

Fullstendig teknisk spesifikasjon av PoCX (Proof of Capacity neXt generation)-konsensusmekanismen og miningprosessen integrert i Bitcoin Core.

---

## Innholdsfortegnelse

1. [Oversikt](#oversikt)
2. [Konsensusarkitektur](#konsensusarkitektur)
3. [Miningprosess](#miningprosess)
4. [Blokkvalidering](#blokkvalidering)
5. [Tildelingssystem](#tildelingssystem)
6. [Nettverkspropagering](#nettverkspropagering)
7. [Tekniske detaljer](#tekniske-detaljer)

---

## Oversikt

Bitcoin-PoCX implementerer en ren Proof of Capacity-konsensusmekanisme som fullstendig erstatning for Bitcoins Proof of Work. Dette er en ny kjede uten bakoverkompatibilitetskrav.

**Nøkkelegenskaper:**
- **Energieffektiv:** Mining bruker forhåndsgenererte plotfiler i stedet for beregningsmessig hashing
- **Time-bended deadlines:** Fordelingstransformasjon (eksponentiell→kjikvadrat) reduserer lange blokker, forbedrer gjennomsnittlige blokktider
- **Tildelingsstøtte:** Ploteiere kan delegere forging-rettigheter til andre adresser
- **Native C++-integrasjon:** Kryptografiske algoritmer implementert i C++ for konsensusvalidering

**Miningflyt:**
```
Ekstern miner → get_mining_info → Beregn nonce → submit_nonce →
Forger-kø → Deadline-venting → Blokkforging → Nettverkspropagering →
Blokkvalidering → Kjedeutvidelse
```

---

## Konsensusarkitektur

### Blokkstruktur

PoCX-blokker utvider Bitcoins blokkstruktur med ekstra konsensusfelt:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Plot-seed (32 bytes)
    std::array<uint8_t, 20> account_id;       // Plotadresse (20-byte hash160)
    uint32_t compression;                     // Skaleringsnivå (1-255)
    uint64_t nonce;                           // Mining-nonce (64-bit)
    uint64_t quality;                         // Påstått kvalitet (PoC-hashutdata)
};

class CBlockHeader {
    // Standard Bitcoin-felt
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCX-konsensusfelt (erstatter nBits og nNonce)
    int nHeight;                              // Blokkhøyde (kontekstfri validering)
    uint256 generationSignature;              // Generasjonssignatur (mining-entropi)
    uint64_t nBaseTarget;                     // Vanskelighetsparameter (invers vanskelighetsgrad)
    PoCXProof pocxProof;                      // Miningbevis

    // Blokksignaturfelt
    std::array<uint8_t, 33> vchPubKey;        // Komprimert offentlig nøkkel (33 bytes)
    std::array<uint8_t, 65> vchSignature;     // Kompakt signatur (65 bytes)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Transaksjoner
};
```

**Merk:** Signaturen (`vchSignature`) er ekskludert fra blokkhash-beregningen for å forhindre formbarhet.

**Implementasjon:** `src/primitives/block.h`

### Generasjonssignatur

Generasjonssignaturen skaper mining-entropi og forhindrer forhåndsberegningsangrep.

**Beregning:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**Genesis-blokk:** Bruker en hardkodet initial generasjonssignatur

**Implementasjon:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Base target (vanskelighetsgrad)

Base target er det inverse av vanskelighetsgrad - høyere verdier betyr enklere mining.

**Justeringsalgoritme:**
- Målblokktid: 120 sekunder (mainnet), 1 sekund (regtest)
- Justeringsintervall: Hver blokk
- Bruker glidende gjennomsnitt av nylige base targets
- Begrenset for å forhindre ekstreme vanskelighetsvingninger

**Implementasjon:** `src/consensus/params.h`, vanskelighetsjustering i blokkoppretting

### Skaleringsnivåer

PoCX støtter skalerbar proof-of-work i plotfiler gjennom skaleringsnivåer (Xn).

**Dynamiske grenser:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimum akseptert nivå
    uint8_t nPoCXTargetCompression;  // Anbefalt nivå
};
```

**Skaleringsøkningsplan:**
- Eksponentielle intervaller: År 4, 12, 28, 60, 124 (halveringer 1, 3, 7, 15, 31)
- Minimum skaleringsnivå øker med 1
- Mål-skaleringsnivå øker med 1
- Opprettholder sikkerhetsmargin mellom plotoppretting og oppslagskostnader
- Maksimum skaleringsnivå: 255

**Implementasjon:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Miningprosess

### 1. Henting av mininginformasjon

**RPC-kommando:** `get_mining_info`

**Prosess:**
1. Kall `GetNewBlockContext(chainman)` for å hente nåværende blockchain-tilstand
2. Beregn dynamiske komprimeringsbegrensninger for gjeldende høyde
3. Returner miningparametere

**Respons:**
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

**Implementasjon:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Merknader:**
- Ingen låser holdt under responsgenerering
- Kontekstanskaffelse håndterer `cs_main` internt
- `block_hash` inkludert for referanse, men ikke brukt i validering

### 2. Ekstern mining

**Ekstern miner-ansvar:**
1. Les plotfiler fra disk
2. Beregn scoop basert på generasjonssignatur og høyde
3. Finn nonce med best deadline
4. Send til node via `submit_nonce`

**Plotfilformat:**
- Basert på POC2-format (Burstcoin)
- Forbedret med sikkerhetsfiks og skaleringsforbedringer
- Se attribusjon i `CLAUDE.md`

**Miner-implementasjon:** Ekstern (f.eks. basert på Scavenger)

### 3. Nonce-innsending og validering

**RPC-kommando:** `submit_nonce`

**Parametere:**
```
height, generation_signature, account_id, seed, nonce, quality (valgfritt)
```

**Valideringsflyt (optimalisert rekkefølge):**

#### Trinn 1: Rask formatvalidering
```cpp
// Konto-ID: 40 hex-tegn = 20 bytes
if (account_id.length() != 40 || !IsHex(account_id)) avvis;

// Seed: 64 hex-tegn = 32 bytes
if (seed.length() != 64 || !IsHex(seed)) avvis;
```

#### Trinn 2: Kontekstanskaffelse
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Returnerer: height, generation_signature, base_target, block_hash
```

**Låsing:** `cs_main` håndteres internt, ingen låser holdes i RPC-tråd

#### Trinn 3: Kontekstvalidering
```cpp
// Høydesjekk
if (height != context.height) avvis;

// Generasjonssignatursjekk
if (submitted_gen_sig != context.generation_signature) avvis;
```

#### Trinn 4: Lommebokverifisering
```cpp
// Bestem effektiv signerer (med tanke på tildelinger)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Sjekk om noden har privat nøkkel for effektiv signerer
if (!HaveAccountKey(effective_signer, wallet)) avvis;
```

**Tildelingsstøtte:** Ploteier kan tildele forging-rettigheter til en annen adresse. Lommeboken må ha nøkkel for den effektive signereren, ikke nødvendigvis ploteieren.

#### Trinn 5: Bevisvalidering
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

**Algoritme:**
1. Dekod generasjonssignatur fra hex
2. Beregn beste kvalitet i komprimeringsområde ved bruk av SIMD-optimaliserte algoritmer
3. Valider at kvalitet møter vanskelighetsgrad-krav
4. Returner rå kvalitetsverdi

**Implementasjon:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Trinn 6: Time Bending-beregning
```cpp
// Rå vanskelighetsjustert deadline (sekunder)
uint64_t deadline_seconds = quality / base_target;

// Time-bended forgetid (sekunder)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Time Bending-formel:**
```
Y = scale * (X^(1/3))
der:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Formål:** Transformerer eksponentiell til kjikvadratfordeling. Veldig gode løsninger forger senere (nettverket har tid til å skanne disker), dårlige løsninger forbedres. Reduserer lange blokker, opprettholder 120s gjennomsnitt.

**Implementasjon:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Trinn 7: Forger-innsending
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // IKKE deadline - beregnes på nytt i forger
    height,
    generation_signature
);
```

**Kø-basert design:**
- Innsending lykkes alltid (legges til i kø)
- RPC returnerer umiddelbart
- Arbeidertråd prosesserer asynkront

**Implementasjon:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Forger-køprosessering

**Arkitektur:**
- Enkelt vedvarende arbeidertråd
- FIFO-innsendingskø
- Låsfri forging-tilstand (kun arbeidertråd)
- Ingen nestede låser (deadlock-forebygging)

**Arbeidertråd hovedløkke:**
```cpp
while (!shutdown) {
    // 1. Sjekk for køede innsendinger
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Vent på deadline eller ny innsending
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**ProcessSubmission-logikk:**
```cpp
1. Hent fersk kontekst: GetNewBlockContext(*chainman)

2. Foreldelsessjekker (stille forkasting):
   - Høydemismatch → forkast
   - Generasjonssignaturmismatch → forkast
   - Tipp-blokkhash endret (reorg) → nullstill forging-tilstand

3. Kvalitetssammenligning:
   - Hvis quality >= current_best → forkast

4. Beregn time-bended deadline:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Oppdater forging-tilstand:
   - Kanseller eksisterende forging (hvis bedre funnet)
   - Lagre: account_id, seed, nonce, quality, deadline
   - Beregn: forge_time = block_time + deadline_seconds
   - Lagre tipp-hash for reorg-deteksjon
```

**Implementasjon:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Deadline-venting og blokkforging

**WaitForDeadlineOrNewSubmission:**

**Ventebetingelser:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Når deadline nås - fersk kontekstvalidering:**
```cpp
1. Hent gjeldende kontekst: GetNewBlockContext(*chainman)

2. Høydevalidering:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Generasjonssignaturvalidering:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Base target-grensetilfelle:
   if (forging_base_target != current_base_target) {
       // Beregn deadline på nytt med ny base target
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Vent igjen
   }

5. Alt gyldig → ForgeBlock()
```

**ForgeBlock-prosess:**

```cpp
1. Bestem effektiv signerer (tildelingsstøtte):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Opprett coinbase-skript:
   coinbase_script = P2WPKH(effective_signer);  // Betaler effektiv signerer

3. Opprett blokkmal:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Legg til PoCX-bevis:
   block.pocxProof.account_id = plot_address;    // Opprinnelig plotadresse
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Beregn merkle-rot på nytt:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Signer blokk:
   // Bruk effektiv signerers nøkkel (kan være forskjellig fra ploteier)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Send til kjede:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Resultathåndtering:
   if (accepted) {
       log_success();
       reset_forging_state();  // Klar for neste blokk
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implementasjon:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Viktige designbeslutninger:**
- Coinbase betaler effektiv signerer (respekterer tildelinger)
- Bevis inneholder opprinnelig plotadresse (for validering)
- Signatur fra effektiv signerers nøkkel (eierskapsbevis)
- Maloppretting inkluderer mempool-transaksjoner automatisk

---

## Blokkvalidering

### Innkommende blokkvalideringsflyt

Når en blokk mottas fra nettverket eller sendes inn lokalt, gjennomgår den validering i flere trinn:

### Trinn 1: Header-validering (CheckBlockHeader)

**Kontekstfri validering:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX-validering (når ENABLE_POCX er definert):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Grunnleggende signaturvalidering (ingen tildelingsstøtte ennå)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Grunnleggende signaturvalidering:**
1. Sjekk tilstedeværelse av pubkey- og signaturfelt
2. Valider pubkey-størrelse (33 bytes komprimert)
3. Valider signaturstørrelse (65 bytes kompakt)
4. Gjenopprett pubkey fra signatur: `pubkey.RecoverCompact(hash, signature)`
5. Verifiser at gjenopprettet pubkey samsvarer med lagret pubkey

**Implementasjon:** `src/validation.cpp:CheckBlockHeader()`
**Signaturlogikk:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Trinn 2: Blokkvalidering (CheckBlock)

**Validerer:**
- Merkle-rot-korrekthet
- Transaksjonsgyldighet
- Coinbase-krav
- Blokkstørrelsesbegrensninger
- Standard Bitcoin-konsensusregler

**Implementasjon:** `src/consensus/validation.cpp:CheckBlock()`

### Trinn 3: Kontekstuell header-validering (ContextualCheckBlockHeader)

**PoCX-spesifikk validering:**

```cpp
#ifdef ENABLE_POCX
    // Trinn 1: Valider generasjonssignatur
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Trinn 2: Valider base target
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Trinn 3: Valider proof of capacity
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

    // Trinn 4: Verifiser deadline-timing
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Valideringstrinn:**
1. **Generasjonssignatur:** Må samsvare med beregnet verdi fra forrige blokk
2. **Base target:** Må samsvare med vanskelighets-justeringsberegning
3. **Skaleringsnivå:** Må møte nettverksminimum (`compression >= min_compression`)
4. **Kvalitetspåstand:** Innsendt kvalitet må samsvare med beregnet kvalitet fra bevis
5. **Proof of Capacity:** Kryptografisk bevisvalidering (SIMD-optimalisert)
6. **Deadline-timing:** Time-bended deadline (`poc_time`) må være ≤ forløpt tid

**Implementasjon:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Trinn 4: Blokkforbindelse (ConnectBlock)

**Full kontekstuell validering:**

```cpp
#ifdef ENABLE_POCX
    // Utvidet signaturvalidering med tildelingsstøtte
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Utvidet signaturvalidering:**
1. Utfør grunnleggende signaturvalidering
2. Trekk ut konto-ID fra gjenopprettet pubkey
3. Hent effektiv signerer for plotadresse: `GetEffectiveSigner(plot_address, height, view)`
4. Verifiser at pubkey-konto samsvarer med effektiv signerer

**Tildelingslogikk:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Returner tildelt signerer
    }

    return plotAddress;  // Ingen tildeling - ploteier signerer
}
```

**Implementasjon:**
- Forbindelse: `src/validation.cpp:ConnectBlock()`
- Utvidet validering: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Tildelingslogikk: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Trinn 5: Kjedeaktivering

**ProcessNewBlock-flyt:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Valider og lagre til disk
    2. ActivateBestChain → Oppdater kjedetipp hvis dette er beste kjede
    3. Varsle nettverk om ny blokk
}
```

**Implementasjon:** `src/validation.cpp:ProcessNewBlock()`

### Valideringsoversikt

**Fullstendig valideringsbane:**
```
Motta blokk
    ↓
CheckBlockHeader (grunnleggende signatur)
    ↓
CheckBlock (transaksjoner, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, base target, PoC-bevis, deadline)
    ↓
ConnectBlock (utvidet signatur med tildelinger, tilstandsoverganger)
    ↓
ActivateBestChain (reorg-håndtering, kjedeutvidelse)
    ↓
Nettverkspropagering
```

---

## Tildelingssystem

### Oversikt

Tildelinger lar ploteiere delegere forging-rettigheter til andre adresser mens de beholder ploteierskap.

**Bruksområder:**
- Pool-mining (plotter tildeler til pool-adresse)
- Kald lagring (mining-nøkkel atskilt fra ploteierskap)
- Flerparts-mining (delt infrastruktur)

### Tildelingsarkitektur

**OP_RETURN-kun design:**
- Tildelinger lagret i OP_RETURN-utdata (ingen UTXO)
- Ingen brukskrav (ingen støv, ingen gebyrer for å holde)
- Sporet i CCoinsViewCache utvidet tilstand
- Aktivert etter forsinkelsesperiode (standard: 4 blokker)

**Tildelingstilstander:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Ingen tildeling eksisterer
    ASSIGNING = 1,   // Tildeling venter på aktivering (forsinkelsesperiode)
    ASSIGNED = 2,    // Tildeling aktiv, forging tillatt
    REVOKING = 3,    // Oppheving ventende (forsinkelsesperiode, fortsatt aktiv)
    REVOKED = 4      // Oppheving fullført, tildeling ikke lenger aktiv
};
```

### Opprette tildelinger

**Transaksjonsformat:**
```cpp
Transaction {
    inputs: [any]  // Beviser eierskap av plotadresse
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Valideringsregler:**
1. Input må være signert av ploteier (beviser eierskap)
2. OP_RETURN inneholder gyldige tildelingsdata
3. Plot må være UNASSIGNED eller REVOKED
4. Ingen dupliserte ventende tildelinger i mempool
5. Minimumstransaksjonsgebyr betalt

**Aktivering:**
- Tildeling blir ASSIGNING ved bekreftelseshøyde
- Blir ASSIGNED etter forsinkelsesperiode (4 blokker regtest, 30 blokker mainnet)
- Forsinkelse forhindrer raske omtildelinger under blokkras

**Implementasjon:** `src/script/forging_assignment.h`, validering i ConnectBlock

### Oppheve tildelinger

**Transaksjonsformat:**
```cpp
Transaction {
    inputs: [any]  // Beviser eierskap av plotadresse
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Effekt:**
- Umiddelbar tilstandsovergang til REVOKED
- Ploteier kan forge umiddelbart
- Kan opprette ny tildeling etterpå

### Tildelingsvalidering under mining

**Bestemmelse av effektiv signerer:**
```cpp
// I submit_nonce-validering
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) avvis;

// I blokkforging
coinbase_script = P2WPKH(effective_signer);  // Belønning går hit

// I blokksignatur
signature = effective_signer_key.SignCompact(hash);  // Må signere med effektiv signerer
```

**Blokkvalidering:**
```cpp
// I VerifyPoCXBlockCompactSignature (utvidet)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) avvis;
```

**Nøkkelegenskaper:**
- Bevis inneholder alltid opprinnelig plotadresse
- Signatur må være fra effektiv signerer
- Coinbase betaler effektiv signerer
- Validering bruker tildelingstilstand ved blokkhøyde

---

## Nettverkspropagering

### Blokkannonsering

**Standard Bitcoin P2P-protokoll:**
1. Forged blokk sendes via `ProcessNewBlock()`
2. Blokk valideres og legges til kjede
3. Nettverksvarsling: `GetMainSignals().BlockConnected()`
4. P2P-lag kringkaster blokk til peers

**Implementasjon:** Standard Bitcoin Core net_processing

### Blokkrele

**Kompakte blokker (BIP 152):**
- Brukes for effektiv blokkpropagering
- Kun transaksjons-ID-er sendes initialt
- Peers ber om manglende transaksjoner

**Full blokkrele:**
- Fallback når kompakte blokker feiler
- Fullstendige blokkdata overføres

### Kjede-reorganiseringer

**Reorg-håndtering:**
```cpp
// I forger-arbeidertråd
if (current_tip_hash != stored_tip_hash) {
    // Kjede-reorganisering oppdaget
    reset_forging_state();
    log("Kjedetipp endret, nullstiller forging");
}
```

**Blockchain-nivå:**
- Standard Bitcoin Core reorg-håndtering
- Beste kjede bestemt av kjedearbeid
- Frakoblede blokker returneres til mempool

---

## Tekniske detaljer

### Deadlock-forebygging

**ABBA-deadlock-mønster (forhindret):**
```
Tråd A: cs_main → cs_wallet
Tråd B: cs_wallet → cs_main
```

**Løsning:**
1. **submit_nonce:** Null cs_main-bruk
   - `GetNewBlockContext()` håndterer låsing internt
   - All validering før forger-innsending

2. **Forger:** Kø-basert arkitektur
   - Enkelt arbeidertråd (ingen tråd-joins)
   - Fersk kontekst ved hver tilgang
   - Ingen nestede låser

3. **Lommeboksjekker:** Utført før dyre operasjoner
   - Tidlig avvisning hvis ingen nøkkel tilgjengelig
   - Atskilt fra blockchain-tilstandstilgang

### Ytelsesoptimaliseringer

**Rask-feil-validering:**
```cpp
1. Formatsjekker (umiddelbart)
2. Kontekstvalidering (lettvekt)
3. Lommebokverifisering (lokal)
4. Bevisvalidering (dyr SIMD)
```

**Enkelt konteksthenting:**
- Én `GetNewBlockContext()`-kall per innsending
- Cache-resultater for flere sjekker
- Ingen gjentatte cs_main-anskaffelser

**Kø-effektivitet:**
- Lettvekt-innsendingsstruktur
- Ingen base_target/deadline i kø (beregnes fersk)
- Minimalt minnefotavtrykk

### Foreldelseshåndtering

**«Enkel» forger-design:**
- Ingen blockchain-hendelsesabonnementer
- Lat validering når nødvendig
- Stille forkasting av foreldede innsendinger

**Fordeler:**
- Enkel arkitektur
- Ingen kompleks synkronisering
- Robust mot grensetilfeller

**Grensetilfeller håndtert:**
- Høydeendringer → forkast
- Generasjonssignaturendringer → forkast
- Base target-endringer → beregn deadline på nytt
- Reorgs → nullstill forging-tilstand

### Kryptografiske detaljer

**Generasjonssignatur:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Blokksignaturhash:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Kompakt signaturformat:**
- 65 bytes: [recovery_id][r][s]
- Tillater gjenoppretting av offentlig nøkkel
- Brukes for plasseffektivitet

**Konto-ID:**
- 20-byte HASH160 av komprimert offentlig nøkkel
- Samsvarer med Bitcoin-adresseformater (P2PKH, P2WPKH)

### Fremtidige forbedringer

**Dokumenterte begrensninger:**
1. Ingen ytelsesmålinger (innsendingsrater, deadline-fordelinger)
2. Ingen detaljert feilkategorisering for minere
3. Begrenset forger-statusspørring (gjeldende deadline, kødybde)

**Potensielle forbedringer:**
- RPC for forger-status
- Målinger for miningeffektivitet
- Forbedret logging for feilsøking
- Pool-protokollstøtte

---

## Kodereferanser

**Kjerneimplementasjoner:**
- RPC-grensesnitt: `src/pocx/rpc/mining.cpp`
- Forger-kø: `src/pocx/mining/scheduler.cpp`
- Konsensusvalidering: `src/pocx/consensus/validation.cpp`
- Bevisvalidering: `src/pocx/consensus/pocx.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- Blokkvalidering: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Tildelingslogikk: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Konteksthåndtering: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Datastrukturer:**
- Blokkformat: `src/primitives/block.h`
- Konsensusparametere: `src/consensus/params.h`
- Tildelingssporing: `src/coins.h` (CCoinsViewCache-utvidelser)

---

## Tillegg: Algoritmespesifikasjoner

### Time Bending-formel

**Matematisk definisjon:**
```
deadline_seconds = quality / base_target  (rå)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

der:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Implementasjon:**
- Fastpunktaritmetikk (Q42-format)
- Kun heltallskubikkrot-beregning
- Optimalisert for 256-bit aritmetikk

### Kvalitetsberegning

**Prosess:**
1. Generer scoop fra generasjonssignatur og høyde
2. Les plotdata for beregnet scoop
3. Hash: `SHABAL256(generation_signature || scoop_data)`
4. Test skaleringsnivåer fra min til maks
5. Returner beste kvalitet funnet

**Skalering:**
- Nivå X0: POC2-grunnlinje (teoretisk)
- Nivå X1: XOR-transpose-grunnlinje
- Nivå Xn: 2^(n-1) × X1-arbeid innebygd
- Høyere skalering = mer plotgenereringsarbeid

### Base target-justering

**Justering ved hver blokk:**
1. Beregn glidende gjennomsnitt av nylige base targets
2. Beregn faktisk tidsrom vs. måltidsrom for rullende vindu
3. Juster base target proporsjonalt
4. Begrens for å forhindre ekstreme svingninger

**Formel:**
```
avg_base_target = moving_average(nylige base targets)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*Denne dokumentasjonen reflekterer den fullstendige PoCX-konsensusimplementasjonen per oktober 2025.*

---

[← Forrige: Plotformat](2-plot-format.md) | [Innholdsfortegnelse](index.md) | [Neste: Forging assignments →](4-forging-assignments.md)
