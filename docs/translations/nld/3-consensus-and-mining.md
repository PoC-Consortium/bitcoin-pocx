[Vorige: Plotformaat](2-plot-format.md) | [Inhoudsopgave](index.md) | [Volgende: Forging-toewijzingen](4-forging-assignments.md)

---

# Hoofdstuk 3: Bitcoin-PoCX Consensus- en miningproces

Volledige technische specificatie van het PoCX (Proof of Capacity neXt generation) consensusmechanisme en miningproces geintegreerd in Bitcoin Core.

---

## Inhoudsopgave

1. [Overzicht](#overzicht)
2. [Consensusarchitectuur](#consensusarchitectuur)
3. [Miningproces](#miningproces)
4. [Blokvalidatie](#blokvalidatie)
5. [Toewijzingssysteem](#toewijzingssysteem)
6. [Netwerkpropagatie](#netwerkpropagatie)
7. [Technische details](#technische-details)

---

## Overzicht

Bitcoin-PoCX implementeert een puur Proof of Capacity-consensusmechanisme als volledige vervanging voor Bitcoin's Proof of Work. Dit is een nieuwe keten zonder achterwaartse compatibiliteitsvereisten.

**Belangrijkste eigenschappen:**
- **Energie-efficient:** Mining gebruikt vooraf gegenereerde plotbestanden in plaats van computationeel hashen
- **Time-bended deadlines:** Distributietransformatie (exponentieel naar chi-kwadraat) vermindert lange blokken, verbetert gemiddelde bloktijden
- **Toewijzingsondersteuning:** Ploteigenaren kunnen forgingrechten delegeren aan andere adressen
- **Native C++-integratie:** Cryptografische algoritmen geimplementeerd in C++ voor consensusvalidatie

**Miningflow:**
```
Externe miner -> get_mining_info -> Bereken nonce -> submit_nonce ->
Forgerwachtrij -> Deadline-wachten -> Blok forgen -> Netwerkpropagatie ->
Blokvalidatie -> Ketenuitbreiding
```

---

## Consensusarchitectuur

### Blokstructuur

PoCX-blokken breiden de blokstructuur van Bitcoin uit met aanvullende consensusvelden:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Plotseed (32 bytes)
    std::array<uint8_t, 20> account_id;       // Plotadres (20-byte hash160)
    uint32_t compression;                     // Schaalniveau (1-255)
    uint64_t nonce;                           // Mining-nonce (64-bit)
    uint64_t quality;                         // Geclaimde kwaliteit (PoC-hash-uitvoer)
};

class CBlockHeader {
    // Standaard Bitcoin-velden
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCX-consensusvelden (vervangen nBits en nNonce)
    int nHeight;                              // Blokhoogte (contextvrije validatie)
    uint256 generationSignature;              // Generatiehandtekening (mining-entropie)
    uint64_t nBaseTarget;                     // Moeilijkheidsparameter (inverse moeilijkheid)
    PoCXProof pocxProof;                      // Miningbewijs

    // Blokhandtekeningvelden
    std::array<uint8_t, 33> vchPubKey;        // Gecomprimeerde publieke sleutel (33 bytes)
    std::array<uint8_t, 65> vchSignature;     // Compacte handtekening (65 bytes)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Transacties
};
```

**Opmerking:** De handtekening (`vchSignature`) is uitgesloten van blokhash-berekening om malleability te voorkomen.

**Implementatie:** `src/primitives/block.h`

### Generatiehandtekening

De generatiehandtekening creert mining-entropie en voorkomt precomputatie-aanvallen.

**Berekening:**
```
generationSignature = SHA256(vorige_generationSignature || vorige_miner_pubkey)
```

**Genesisblok:** Gebruikt een hardcoded initiele generatiehandtekening

**Implementatie:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Base Target (moeilijkheid)

Base target is de inverse van moeilijkheid - hogere waarden betekenen eenvoudiger minen.

**Aanpassingsalgoritme:**
- Doelbloktijd: 120 seconden (mainnet), 1 seconde (regtest)
- Aanpassingsinterval: Elk blok
- Gebruikt voortschrijdend gemiddelde van recente base targets
- Begrensd om extreme moeilijkheidsschommelingen te voorkomen

**Implementatie:** `src/consensus/params.h`, moeilijkheidsaanpassing in blokcreatie

### Schaalniveaus

PoCX ondersteunt schaalbare proof-of-work in plotbestanden via schaalniveaus (Xn).

**Dynamische grenzen:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimum geaccepteerd niveau
    uint8_t nPoCXTargetCompression;  // Aanbevolen niveau
};
```

**Schema voor schaalverhoging:**
- Exponentiele intervallen: Jaren 4, 12, 28, 60, 124 (halveringen 1, 3, 7, 15, 31)
- Minimum schaalniveau neemt toe met 1
- Doelschaalniveau neemt toe met 1
- Behoudt veiligheidsmarge tussen plotcreatie- en opzoekkosten
- Maximaal schaalniveau: 255

**Implementatie:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Miningproces

### 1. Mininginformatie ophalen

**RPC-opdracht:** `get_mining_info`

**Proces:**
1. Roep `GetNewBlockContext(chainman)` aan om huidige blockchainstatus op te halen
2. Bereken dynamische compressiegrenzen voor huidige hoogte
3. Retourneer miningparameters

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

**Implementatie:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Opmerkingen:**
- Geen locks gehouden tijdens responsgeneratie
- Contextacquisitie handelt `cs_main` intern af
- `block_hash` opgenomen ter referentie maar niet gebruikt in validatie

### 2. Externe mining

**Verantwoordelijkheden externe miner:**
1. Lees plotbestanden van schijf
2. Bereken scoop op basis van generatiehandtekening en hoogte
3. Vind nonce met beste deadline
4. Verstuur naar node via `submit_nonce`

**Plotbestandsformaat:**
- Gebaseerd op POC2-formaat (Burstcoin)
- Verbeterd met beveiligingsreparaties en schaalbaarheidsverbeteringen
- Zie attributie in `CLAUDE.md`

**Miner-implementatie:** Extern (bijv. gebaseerd op Scavenger)

### 3. Nonce-indiening en validatie

**RPC-opdracht:** `submit_nonce`

**Parameters:**
```
height, generation_signature, account_id, seed, nonce, quality (optioneel)
```

**Validatieflow (geoptimaliseerde volgorde):**

#### Stap 1: Snelle formaatvalidatie
```cpp
// Account-ID: 40 hex-tekens = 20 bytes
if (account_id.length() != 40 || !IsHex(account_id)) weiger;

// Seed: 64 hex-tekens = 32 bytes
if (seed.length() != 64 || !IsHex(seed)) weiger;
```

#### Stap 2: Contextacquisitie
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Retourneert: height, generation_signature, base_target, block_hash
```

**Locking:** `cs_main` intern afgehandeld, geen locks gehouden in RPC-thread

#### Stap 3: Contextvalidatie
```cpp
// Hoogtecontrole
if (height != context.height) weiger;

// Generatiehandtekeningcontrole
if (submitted_gen_sig != context.generation_signature) weiger;
```

#### Stap 4: Walletverificatie
```cpp
// Bepaal effectieve ondertekenaar (rekening houdend met toewijzingen)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Controleer of node privesleutel heeft voor effectieve ondertekenaar
if (!HaveAccountKey(effective_signer, wallet)) weiger;
```

**Toewijzingsondersteuning:** Ploteigenaar kan forgingrechten toewijzen aan een ander adres. Wallet moet sleutel hebben voor de effectieve ondertekenaar, niet noodzakelijk de ploteigenaar.

#### Stap 5: Bewijsvalidatie
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
    &result             // Uitvoer: quality, deadline
);
```

**Algoritme:**
1. Decodeer generatiehandtekening van hex
2. Bereken beste kwaliteit in compressiebereik met SIMD-geoptimaliseerde algoritmen
3. Valideer dat kwaliteit voldoet aan moeilijkheidsvereisten
4. Retourneer ruwe kwaliteitswaarde

**Implementatie:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Stap 6: Time Bending-berekening
```cpp
// Ruwe moeilijkheidsaangepaste deadline (seconden)
uint64_t deadline_seconds = quality / base_target;

// Time-bended forgetijd (seconden)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Time Bending-formule:**
```
Y = scale * (X^(1/3))
waarbij:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0,892979511
```

**Doel:** Transformeert exponentiele naar chi-kwadraatverdeling. Zeer goede oplossingen forgen later (netwerk heeft tijd om schijven te scannen), slechte oplossingen worden verbeterd. Vermindert lange blokken, behoudt 120s gemiddelde.

**Implementatie:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Stap 7: Forger-indiening
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // GEEN deadline - herberekend in forger
    height,
    generation_signature
);
```

**Wachtrij-gebaseerd ontwerp:**
- Indiening slaagt altijd (toegevoegd aan wachtrij)
- RPC keert onmiddellijk terug
- Werkthread verwerkt asynchroon

**Implementatie:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Forger-wachtrijverwerking

**Architectuur:**
- Enkele persistente werkthread
- FIFO-indieningswachtrij
- Lock-vrije forging-status (alleen werkthread)
- Geen geneste locks (deadlock-preventie)

**Werkthread-hoofdlus:**
```cpp
while (!shutdown) {
    // 1. Controleer op wachtende indieningen
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Wacht op deadline of nieuwe indiening
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**ProcessSubmission-logica:**
```cpp
1. Haal verse context op: GetNewBlockContext(*chainman)

2. Verouderingscontroles (stille verwijdering):
   - Hoogte komt niet overeen -> verwijder
   - Generatiehandtekening komt niet overeen -> verwijder
   - Tip-blokhash gewijzigd (reorg) -> reset forging-status

3. Kwaliteitsvergelijking:
   - Als kwaliteit >= huidige_beste -> verwijder

4. Bereken Time-bended deadline:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Update forging-status:
   - Annuleer bestaande forging (indien beter gevonden)
   - Sla op: account_id, seed, nonce, quality, deadline
   - Bereken: forge_time = block_time + deadline_seconds
   - Sla tip-hash op voor reorg-detectie
```

**Implementatie:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Deadline-wachten en blok forgen

**WaitForDeadlineOrNewSubmission:**

**Wachtcondities:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Wanneer deadline bereikt - verse contextvalidatie:**
```cpp
1. Haal huidige context op: GetNewBlockContext(*chainman)

2. Hoogtevalidatie:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Generatiehandtekeningvalidatie:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Base target-randgeval:
   if (forging_base_target != current_base_target) {
       // Herbereken deadline met nieuwe base target
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Wacht opnieuw
   }

5. Alles geldig -> ForgeBlock()
```

**ForgeBlock-proces:**

```cpp
1. Bepaal effectieve ondertekenaar (toewijzingsondersteuning):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Creeer coinbase-script:
   coinbase_script = P2WPKH(effective_signer);  // Betaalt effectieve ondertekenaar

3. Creeer bloktemplate:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Voeg PoCX-bewijs toe:
   block.pocxProof.account_id = plot_address;    // Originele plotadres
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Herbereken merkle-root:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Onderteken blok:
   // Gebruik sleutel van effectieve ondertekenaar (kan verschillen van ploteigenaar)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Dien in bij keten:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Resultaatafhandeling:
   if (accepted) {
       log_success();
       reset_forging_state();  // Klaar voor volgend blok
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implementatie:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Belangrijke ontwerpbeslissingen:**
- Coinbase betaalt effectieve ondertekenaar (respecteert toewijzingen)
- Bewijs bevat originele plotadres (voor validatie)
- Handtekening van sleutel effectieve ondertekenaar (eigenaarschapsbewijs)
- Templatecreatie omvat mempool-transacties automatisch

---

## Blokvalidatie

### Inkomende blokvalidatieflow

Wanneer een blok wordt ontvangen van het netwerk of lokaal wordt ingediend, ondergaat het validatie in meerdere fasen:

### Fase 1: Headervalidatie (CheckBlockHeader)

**Contextvrije validatie:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX-validatie (wanneer ENABLE_POCX gedefinieerd):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Basishandtekeningvalidatie (nog geen toewijzingsondersteuning)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Basishandtekeningvalidatie:**
1. Controleer aanwezigheid van pubkey- en handtekeningvelden
2. Valideer pubkey-grootte (33 bytes gecomprimeerd)
3. Valideer handtekeninggrootte (65 bytes compact)
4. Herstel pubkey uit handtekening: `pubkey.RecoverCompact(hash, signature)`
5. Verifieer dat herstelde pubkey overeenkomt met opgeslagen pubkey

**Implementatie:** `src/validation.cpp:CheckBlockHeader()`
**Handtekeninglogica:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Fase 2: Blokvalidatie (CheckBlock)

**Valideert:**
- Merkle-root-correctheid
- Transactiegeldigheid
- Coinbase-vereisten
- Blokgroottelimieten
- Standaard Bitcoin-consensusregels

**Implementatie:** `src/consensus/validation.cpp:CheckBlock()`

### Fase 3: Contextuele headervalidatie (ContextualCheckBlockHeader)

**PoCX-specifieke validatie:**

```cpp
#ifdef ENABLE_POCX
    // Stap 1: Valideer generatiehandtekening
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Stap 2: Valideer base target
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Stap 3: Valideer proof of capacity
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

    // Stap 4: Verifieer deadline-timing
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Validatiestappen:**
1. **Generatiehandtekening:** Moet overeenkomen met berekende waarde van vorig blok
2. **Base target:** Moet overeenkomen met moeilijkheidsaanpassingsberekening
3. **Schaalniveau:** Moet voldoen aan netwerkminimum (`compression >= min_compression`)
4. **Kwaliteitsclaim:** Ingediende kwaliteit moet overeenkomen met berekende kwaliteit uit bewijs
5. **Proof of Capacity:** Cryptografische bewijsvalidatie (SIMD-geoptimaliseerd)
6. **Deadline-timing:** Time-bended deadline (`poc_time`) moet <= verstreken tijd zijn

**Implementatie:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Fase 4: Blokverbinding (ConnectBlock)

**Volledige contextuele validatie:**

```cpp
#ifdef ENABLE_POCX
    // Uitgebreide handtekeningvalidatie met toewijzingsondersteuning
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Uitgebreide handtekeningvalidatie:**
1. Voer basishandtekeningvalidatie uit
2. Extraheer account-ID uit herstelde pubkey
3. Haal effectieve ondertekenaar op voor plotadres: `GetEffectiveSigner(plot_address, height, view)`
4. Verifieer dat pubkey-account overeenkomt met effectieve ondertekenaar

**Toewijzingslogica:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Retourneer toegewezen ondertekenaar
    }

    return plotAddress;  // Geen toewijzing - ploteigenaar ondertekent
}
```

**Implementatie:**
- Verbinding: `src/validation.cpp:ConnectBlock()`
- Uitgebreide validatie: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Toewijzingslogica: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Fase 5: Ketenactivering

**ProcessNewBlock-flow:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock -> Valideer en sla op schijf op
    2. ActivateBestChain -> Update ketentip als dit de beste keten is
    3. Informeer netwerk over nieuw blok
}
```

**Implementatie:** `src/validation.cpp:ProcessNewBlock()`

### Validatiesamenvatting

**Volledig validatiepad:**
```
Ontvang blok
    |
CheckBlockHeader (basishandtekening)
    |
CheckBlock (transacties, merkle)
    |
ContextualCheckBlockHeader (gen sig, base target, PoC-bewijs, deadline)
    |
ConnectBlock (uitgebreide handtekening met toewijzingen, statusovergangen)
    |
ActivateBestChain (reorg-afhandeling, ketenuitbreiding)
    |
Netwerkpropagatie
```

---

## Toewijzingssysteem

### Overzicht

Toewijzingen stellen ploteigenaren in staat om forgingrechten te delegeren aan andere adressen terwijl ze ploteigenaarschap behouden.

**Gebruiksscenario's:**
- Pool-mining (plots wijzen toe aan pooladres)
- Cold storage (mining-sleutel gescheiden van ploteigenaarschap)
- Multi-party mining (gedeelde infrastructuur)

### Toewijzingsarchitectuur

**Alleen-OP_RETURN-ontwerp:**
- Toewijzingen opgeslagen in OP_RETURN-uitvoer (geen UTXO)
- Geen bestedingsvereisten (geen dust, geen kosten voor houden)
- Bijgehouden in CCoinsViewCache uitgebreide status
- Geactiveerd na vertragingsperiode (standaard: 4 blokken)

**Toewijzingsstatussen:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Geen toewijzing bestaat
    ASSIGNING = 1,   // Toewijzing wacht op activering (vertragingsperiode)
    ASSIGNED = 2,    // Toewijzing actief, forgen toegestaan
    REVOKING = 3,    // Intrekking wachtend (vertragingsperiode, nog actief)
    REVOKED = 4      // Intrekking voltooid, toewijzing niet langer actief
};
```

### Toewijzingen maken

**Transactieformaat:**
```cpp
Transaction {
    inputs: [any]  // Bewijst eigenaarschap van plotadres
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Validatieregels:**
1. Invoer moet ondertekend zijn door ploteigenaar (bewijst eigenaarschap)
2. OP_RETURN bevat geldige toewijzingsgegevens
3. Plot moet UNASSIGNED of REVOKED zijn
4. Geen dubbele wachtende toewijzingen in mempool
5. Minimale transactiekosten betaald

**Activering:**
- Toewijzing wordt ASSIGNING op bevestigingshoogte
- Wordt ASSIGNED na vertragingsperiode (4 blokken regtest, 30 blokken mainnet)
- Vertraging voorkomt snelle hertoewijzingen tijdens blokraces

**Implementatie:** `src/script/forging_assignment.h`, validatie in ConnectBlock

### Toewijzingen intrekken

**Transactieformaat:**
```cpp
Transaction {
    inputs: [any]  // Bewijst eigenaarschap van plotadres
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Effect:**
- Onmiddellijke statusovergang naar REVOKED
- Ploteigenaar kan onmiddellijk forgen
- Kan daarna nieuwe toewijzing maken

### Toewijzingsvalidatie tijdens mining

**Bepaling effectieve ondertekenaar:**
```cpp
// In submit_nonce-validatie
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) weiger;

// In blok forgen
coinbase_script = P2WPKH(effective_signer);  // Beloning gaat hierheen

// In blokhandtekening
signature = effective_signer_key.SignCompact(hash);  // Moet ondertekenen met effectieve ondertekenaar
```

**Blokvalidatie:**
```cpp
// In VerifyPoCXBlockCompactSignature (uitgebreid)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) weiger;
```

**Belangrijke eigenschappen:**
- Bewijs bevat altijd originele plotadres
- Handtekening moet van effectieve ondertekenaar zijn
- Coinbase betaalt effectieve ondertekenaar
- Validatie gebruikt toewijzingsstatus op blokhoogte

---

## Netwerkpropagatie

### Blokaankondiging

**Standaard Bitcoin P2P-protocol:**
1. Geforged blok ingediend via `ProcessNewBlock()`
2. Blok gevalideerd en toegevoegd aan keten
3. Netwerknotificatie: `GetMainSignals().BlockConnected()`
4. P2P-laag zendt blok uit naar peers

**Implementatie:** Standaard Bitcoin Core net_processing

### Blokrelay

**Compacte blokken (BIP 152):**
- Gebruikt voor efficiente blokpropagatie
- Alleen transactie-ID's initieel verzonden
- Peers vragen ontbrekende transacties op

**Volledige blokrelay:**
- Terugval wanneer compacte blokken falen
- Volledige blokgegevens verzonden

### Ketenherschikkingen

**Reorg-afhandeling:**
```cpp
// In forger-werkthread
if (current_tip_hash != stored_tip_hash) {
    // Ketenherschikking gedetecteerd
    reset_forging_state();
    log("Ketentip gewijzigd, forging resetten");
}
```

**Blockchain-niveau:**
- Standaard Bitcoin Core reorg-afhandeling
- Beste keten bepaald door chainwork
- Losgekoppelde blokken terug naar mempool

---

## Technische details

### Deadlock-preventie

**ABBA-deadlock-patroon (voorkomen):**
```
Thread A: cs_main -> cs_wallet
Thread B: cs_wallet -> cs_main
```

**Oplossing:**
1. **submit_nonce:** Nul cs_main-gebruik
   - `GetNewBlockContext()` handelt locking intern af
   - Alle validatie voor forger-indiening

2. **Forger:** Wachtrij-gebaseerde architectuur
   - Enkele werkthread (geen thread-joins)
   - Verse context bij elke toegang
   - Geen geneste locks

3. **Walletcontroles:** Uitgevoerd voor dure operaties
   - Vroege afwijzing als geen sleutel beschikbaar
   - Gescheiden van blockchain-statustoegang

### Prestatie-optimalisaties

**Fast-fail validatie:**
```cpp
1. Formaatcontroles (onmiddellijk)
2. Contextvalidatie (lichtgewicht)
3. Walletverificatie (lokaal)
4. Bewijsvalidatie (dure SIMD)
```

**Enkele contextophaling:**
- Een `GetNewBlockContext()`-aanroep per indiening
- Cache resultaten voor meerdere controles
- Geen herhaalde cs_main-acquisities

**Wachtrij-efficientie:**
- Lichtgewicht indieningsstructuur
- Geen base_target/deadline in wachtrij (vers herberekend)
- Minimale geheugenvoetafdruk

### Verouderingsafhandeling

**"Simpel" forger-ontwerp:**
- Geen blockchain-event-abonnementen
- Luie validatie wanneer nodig
- Stille verwijdering van verouderde indieningen

**Voordelen:**
- Eenvoudige architectuur
- Geen complexe synchronisatie
- Robuust tegen randgevallen

**Randgevallen afgehandeld:**
- Hoogtewijzigingen -> verwijder
- Generatiehandtekeningwijzigingen -> verwijder
- Base target-wijzigingen -> herbereken deadline
- Reorgs -> reset forging-status

### Cryptografische details

**Generatiehandtekening:**
```cpp
SHA256(vorige_generatiehandtekening || vorige_miner_pubkey_33bytes)
```

**Blokhandtekening-hash:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Compact handtekeningformaat:**
- 65 bytes: [recovery_id][r][s]
- Staat publieke sleutelherstel toe
- Gebruikt voor ruimte-efficientie

**Account-ID:**
- 20-byte HASH160 van gecomprimeerde publieke sleutel
- Komt overeen met Bitcoin-adresformaten (P2PKH, P2WPKH)

### Toekomstige verbeteringen

**Gedocumenteerde beperkingen:**
1. Geen prestatiemetrieken (indieningssnelheden, deadline-distributies)
2. Geen gedetailleerde foutcategorisatie voor miners
3. Beperkte forger-statusbevraging (huidige deadline, wachtrijdiepte)

**Mogelijke verbeteringen:**
- RPC voor forger-status
- Metrieken voor mining-efficientie
- Verbeterde logging voor debugging
- Pool-protocolondersteuning

---

## Codereferenties

**Kernimplementaties:**
- RPC-interface: `src/pocx/rpc/mining.cpp`
- Forger-wachtrij: `src/pocx/mining/scheduler.cpp`
- Consensusvalidatie: `src/pocx/consensus/validation.cpp`
- Bewijsvalidatie: `src/pocx/consensus/pocx.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- Blokvalidatie: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Toewijzingslogica: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Contextbeheer: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Gegevensstructuren:**
- Blokformaat: `src/primitives/block.h`
- Consensusparameters: `src/consensus/params.h`
- Toewijzingsbijhouding: `src/coins.h` (CCoinsViewCache-extensies)

---

## Bijlage: Algoritmespecificaties

### Time Bending-formule

**Wiskundige definitie:**
```
deadline_seconds = quality / base_target  (ruw)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

waarbij:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0,892979511
```

**Implementatie:**
- Fixed-point rekenkunde (Q42-formaat)
- Alleen-integer derdemachtswortelberekening
- Geoptimaliseerd voor 256-bit rekenkunde

### Kwaliteitsberekening

**Proces:**
1. Genereer scoop uit generatiehandtekening en hoogte
2. Lees plotgegevens voor berekende scoop
3. Hash: `SHABAL256(generation_signature || scoop_data)`
4. Test schaalniveaus van min tot max
5. Retourneer beste gevonden kwaliteit

**Schaling:**
- Niveau X0: POC2-basislijn (theoretisch)
- Niveau X1: XOR-transpose-basislijn
- Niveau Xn: 2^(n-1) x X1 werk ingebed
- Hogere schaling = meer plotgeneratiewerk

### Base target-aanpassing

**Aanpassing elk blok:**
1. Bereken voortschrijdend gemiddelde van recente base targets
2. Bereken werkelijke tijdsduur vs. doeltijdsduur voor rollend venster
3. Pas base target proportioneel aan
4. Begrens om extreme schommelingen te voorkomen

**Formule:**
```
avg_base_target = voortschrijdend_gemiddelde(recente base targets)
adjustment_factor = werkelijke_tijdsduur / doel_tijdsduur
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*Deze documentatie weerspiegelt de volledige PoCX-consensusimplementatie per oktober 2025.*

---

[Vorige: Plotformaat](2-plot-format.md) | [Inhoudsopgave](index.md) | [Volgende: Forging-toewijzingen](4-forging-assignments.md)
