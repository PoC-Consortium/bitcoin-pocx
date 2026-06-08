[← Edellinen: Plottimuoto](2-plot-format.md) | [Sisällysluettelo](index.md) | [Seuraava: Forging-delegoinnit →](4-forging-assignments.md)

---

# Luku 3: Bitcoin-PoCX Konsensus ja louhintaprosessi

PoCX (Proof of Capacity neXt generation) -konsensusmekanismin ja louhintaprosessin täydellinen tekninen määrittely integroituna Bitcoin Coreen.

---

## Sisällysluettelo

1. [Yleiskatsaus](#yleiskatsaus)
2. [Konsensusarkkitehtuuri](#konsensusarkkitehtuuri)
3. [Louhintaprosessi](#louhintaprosessi)
4. [Lohkon validointi](#lohkon-validointi)
5. [Delegointijärjestelmä](#delegointijärjestelmä)
6. [Verkkopropagaatio](#verkkopropagaatio)
7. [Tekniset yksityiskohdat](#tekniset-yksityiskohdat)

---

## Yleiskatsaus

Bitcoin-PoCX toteuttaa puhtaan Proof of Capacity -konsensusmekanismin täydellisenä korvaajana Bitcoinin Proof of Workille. Tämä on uusi ketju ilman taaksepäin yhteensopivuusvaatimuksia.

**Keskeiset ominaisuudet:**
- **Energiatehokas:** Louhinta käyttää esigeneroituja plottitiedostoja laskennallisen tiivistämisen sijaan
- **Aikataivutetut deadlinet:** Jakauman muunnos (eksponentiaalinen→Weibull, muoto k=3) vähentää pitkiä lohkoja, parantaa keskimääräisiä lohkoaikoja
- **Delegointituki:** Plotin omistajat voivat delegoida forging-oikeudet muille osoitteille
- **Natiivi C++-integraatio:** Kryptografiset algoritmit toteutettu C++:lla konsensusvalidointia varten

**Louhintavirta:**
```
Ulkoinen louhija → get_mining_info → Laske nonce → submit_nonce →
Forger-jono → Deadlinen odotus → Lohkon forging → Verkkopropagaatio →
Lohkon validointi → Ketjun laajennus
```

---

## Konsensusarkkitehtuuri

### Lohkorakenne

PoCX-lohkot laajentavat Bitcoinin lohkorakennetta lisäkonsensuskentillä:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Plotin seed (32 tavua)
    std::array<uint8_t, 20> account_id;       // Plotin osoite (20-tavuinen hash160)
    uint32_t compression;                     // Skaalaustaso (1-6)
    uint64_t nonce;                           // Louhinnan nonce (64-bittinen)
    uint64_t quality;                         // Väitetty laatu (PoC-tiivisteen tuloste)
};

class CBlockHeader {
    // Vakio Bitcoin-kentät
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCX-konsensuskentät (korvaavat nBits ja nNonce)
    int nHeight;                              // Lohkon korkeus (kontekstivapaa validointi)
    uint256 generationSignature;              // Generoinnin allekirjoitus (louhinnan entropia)
    uint64_t nBaseTarget;                     // Vaikeusparametri (käänteinen vaikeus)
    PoCXProof pocxProof;                      // Louhintatodiste

    // Lohkon allekirjoituskentät
    std::array<uint8_t, 33> vchPubKey;        // Pakattu julkinen avain (33 tavua)
    std::array<uint8_t, 65> vchSignature;     // Kompakti allekirjoitus (65 tavua)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Transaktiot
};
```

**Huomautus:** Allekirjoitus (`vchSignature`) on poissuljettu lohkon tiivisteen laskennasta muunneltavuuden estämiseksi.

**Toteutus:** `src/primitives/block.h`

### Generoinnin allekirjoitus

Generoinnin allekirjoitus luo louhinnan entropian ja estää esivalmisteluyhyökkäykset.

**Laskenta:**
```
generationSignature = dSHA256(prev_generationSignature || prev_account_id_20bytes)
```

**Genesis-lohko:** Käyttää kovakoodattua alkuperäistä generoinnin allekirjoitusta

**Toteutus:** `src/pocx/consensus/difficulty.cpp:GetNextGenerationSignature()` (kutsutaan tiedostosta `src/pocx/mining/block_context.cpp:GetNewBlockContext()`)

### Perustavoite (vaikeus)

Perustavoite on vaikeuden käänteisluku – korkeammat arvot tarkoittavat helpompaa louhintaa.

**Säätöalgoritmi:**
- Tavoitelohkoaika: 120 sekuntia (kaikki verkot)
- Säätöväli: Jokainen lohko
- Käyttää viimeaikaisten perustavoitteiden liukuvaa keskiarvoa
- Rajoitettu estämään äärimmäiset vaikeuden heilahtelut

**Toteutus:** `src/consensus/params.h`, vaikeuslogiikka lohkon luonnissa

### Skaalaustasot

PoCX tukee skaalautuvaa proof-of-workia plottitiedostoissa skaalaustason (Xn) kautta.

**Dynaamiset rajat:**
```cpp
struct PoCXCompressionBounds {
    uint32_t nPoCXMinCompression;     // Vähimmäishyväksytty taso
    uint32_t nPoCXTargetCompression;  // Suositeltu taso
};
```

**Skaalauksen kasvatusaikataulu:**
- Eksponentiaaliset välit: Vuodet 4, 12, 28, 60, 124 (puolittamiset 1, 3, 7, 15, 31)
- Vähimmäisskaalaustaso kasvaa yhdellä
- Tavoiteskaalaustaso kasvaa yhdellä
- Ylläpitää turvamarginaalia plotin luomis- ja hakukustannusten välillä
- Maksimiskaalaustaso: 255

**Toteutus:** `src/pocx/consensus/params.h:GetPoCXCompressionBounds()`

---

## Louhintaprosessi

### 1. Louhintatietojen haku

**RPC-komento:** `get_mining_info`

**Prosessi:**
1. Kutsu `GetNewBlockContext(chainman)` hakeaksesi nykyisen lohkoketjun tilan
2. Laske dynaamiset pakkausrajat nykyiselle korkeudelle
3. Palauta louhintaparametrit

**Vastaus:**
```json
{
  "generation_signature": "abc123...",
  "base_target": 18325193796,
  "height": 12345,
  "block_hash": "def456...",
  "target_quality": 18446744073709551615,
  "minimum_compression_level": 1,
  "target_compression_level": 2
}
```

**Toteutus:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Huomautukset:**
- Lukkoja ei pidetä vastauksen generoinnin aikana
- Kontekstin hankinta käsittelee `cs_main`-lukon sisäisesti
- `block_hash` mukana viitteenä mutta ei käytetä validoinnissa

### 2. Ulkoinen louhinta

**Ulkoisen louhijan vastuut:**
1. Lue plottitiedostot levyltä
2. Laske scoop generoinnin allekirjoituksen ja korkeuden perusteella
3. Etsi nonce parhaalla deadlinella
4. Lähetä solmulle `submit_nonce`-komennolla

**Plottitiedostomuoto:**
- Perustuu POC2-muotoon (Burstcoin)
- Parannettu turvallisuuskorjauksilla ja skaalautuvuusparannuksilla
- Katso attribuutio `CLAUDE.md`:ssä

**Louhijatoteutus:** Ulkoinen (esim. perustuu Scavengeriin)

### 3. Noncen lähetys ja validointi

**RPC-komento:** `submit_nonce`

**Parametrit:**
```
height, generation_signature, account_id, seed, nonce, quality (valinnainen)
```

**Validointivirta (optimoitu järjestys):**

#### Vaihe 1: Nopea muotovalidointi
```cpp
// Tilitunniste: 40 heksamerkkiä = 20 tavua
if (account_id.length() != 40 || !IsHex(account_id)) hylkää;

// Seed: 64 heksamerkkiä = 32 tavua
if (seed.length() != 64 || !IsHex(seed)) hylkää;
```

#### Vaihe 2: Kontekstin hankinta
```cpp
auto context = pocx::mining::GetNewBlockContext(chainman);
// Palauttaa: height, generation_signature, base_target, block_hash
```

**Lukitus:** `cs_main` käsitellään sisäisesti, RPC-säikeessä ei lukkoja

#### Vaihe 3: Kontekstin validointi
```cpp
// Korkeuden tarkistus
if (height != context.height) hylkää;

// Generoinnin allekirjoituksen tarkistus
if (submitted_gen_sig != context.generation_signature) hylkää;
```

#### Vaihe 4: Lompakon varmennus
```cpp
// Määritä tehokas allekirjoittaja (huomioiden delegoinnit)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Tarkista onko solmulla yksityinen avain tehokkaalle allekirjoittajalle
if (!HaveAccountKey(effective_signer, wallet)) hylkää;
```

**Delegointituki:** Plotin omistaja voi delegoida forging-oikeudet toiselle osoitteelle. Lompakolla on oltava avain tehokkaalle allekirjoittajalle, ei välttämättä plotin omistajalle.

#### Step 5: Compression Validation
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
if (compression < bounds.nPoCXMinCompression || compression > bounds.nPoCXTargetCompression)
    reject;
```

#### Step 6: Proof Validation
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    account_id_hex,
    base_target,
    block_height,
    nonce,
    seed,                // 32 bytes
    compression,
    &result             // Output: quality
);
```

**Algorithm:**
1. Decode generation signature from hex
2. Calculate quality at specified compression level
3. Validate quality meets difficulty requirements
4. Return raw quality value

**Implementation:** `src/pocx/consensus/proof.cpp:pocx_validate_block()`

#### Step 7: Time Bendingtaivutuksen laskenta
```cpp
// Raaka vaikeussäädetty deadline (sekunteja)
uint64_t deadline_seconds = quality / base_target;

// Aikataivutettu forging-aika (sekunteja)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Aikataivutuskaava:**
```
Y = scale * (X^(1/3))
missä:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Tarkoitus:** Muuntaa eksponentiaalijakauman Weibull (muoto k=3) -jakaumaksi. Erittäin hyvät ratkaisut forgataan myöhemmin (verkolla on aikaa skannata levyt), huonot ratkaisut parannetaan. Vähentää pitkiä lohkoja, säilyttää 120s keskiarvon.

**Toteutus:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Step 8: Forger Submission-lähetys
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,
    compression,
    block_hash        // sole staleness indicator
);
```

**Jonopohjaisuus:**
- Lähetys onnistuu aina (lisätään jonoon)
- RPC palaa välittömästi
- Työsäie käsittelee asynkronisesti

**Toteutus:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Forger-jonon käsittely

**Arkkitehtuuri:**
- Yksi pysyvä työsäie
- FIFO-lähetysjono
- Lukiton forging-tila (vain työsäie)
- Ei sisäkkäisiä lukkoja (deadlock-esto)

**Työsäikeen pääsilmukka:**
```cpp
while (!shutdown) {
    // 1. Tarkista jonossa olevat lähetykset
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Odota deadlinea tai uutta lähetystä
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**ProcessSubmission-logiikka:**
```cpp
1. Hae tuore konteksti: GetNewBlockContext(*chainman)

2. Vanhentumistarkistukset (hiljainen hylkäys):
   - Korkeusero → hylkää
   - Generoinnin allekirjoitusero → hylkää
   - Kärkilohkon tiiviste muuttunut (reorg) → nollaa forging-tila

3. Quality comparison (lower = better):
   - Jos quality >= current_best → hylkää

4. Laske aikataivutettu deadline:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Päivitä forging-tila:
   - Peruuta olemassa oleva forging (jos parempi löytyi)
   - Tallenna: account_id, seed, nonce, quality, deadline
   - Laske: forge_time = block_time + deadline_seconds
   - Tallenna kärjen tiiviste reorg-tunnistusta varten
```

**Toteutus:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Deadlinen odotus ja lohkon forging

**WaitForDeadlineOrNewSubmission:**

**Odotuskondiot:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Kun deadline saavutetaan – tuoreen kontekstin validointi:**
```cpp
1. Hae nykyinen konteksti: GetNewBlockContext(*chainman)

2. Korkeusvalidointi:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Generoinnin allekirjoituksen validointi:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Perustavoitteen reunatapaus:
   if (forging_base_target != current_base_target) {
       // Laske deadline uudelleen uudella perustavoitteella
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Odota uudelleen
   }

5. Kaikki kelvollisia → ForgeBlock()
```

**ForgeBlock-prosessi:**

```cpp
1. Määritä tehokas allekirjoittaja (delegointituki):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Luo coinbase-skripti:
   coinbase_script = P2WPKH(effective_signer);  // Maksaa tehokkaalle allekirjoittajalle

3. Luo lohkopohja:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Lisää PoCX-todiste:
   block.pocxProof.account_id = plot_address;    // Alkuperäinen plotin osoite
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;
   block.pocxProof.compression = compression;

5. Laske merkle-juuri uudelleen:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Allekirjoita lohko:
   // Käytä tehokkaan allekirjoittajan avainta (voi erota plotin omistajasta)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Lähetä ketjuun:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Tuloksen käsittely:
   if (accepted) {
       log_success();
       reset_forging_state();  // Valmis seuraavaa lohkoa varten
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Toteutus:** `src/pocx/mining/block_builder.cpp:BuildBlock()`

**Keskeiset suunnittelupäätökset:**
- Coinbase maksaa tehokkaalle allekirjoittajalle (kunnioittaa delegointeja)
- Todiste sisältää alkuperäisen plotin osoitteen (validointia varten)
- Allekirjoitus tehokkaan allekirjoittajan avaimella (omistajuuden todiste)
- Pohjan luonti sisältää mempool-transaktiot automaattisesti

---

## Lohkon validointi

### Saapuvan lohkon validointivirta

Kun lohko vastaanotetaan verkosta tai lähetetään paikallisesti, se käy läpi validoinnin useissa vaiheissa:

### Vaihe 1: Otsikon validointi (CheckBlockHeader)

**Kontekstivapaa validointi:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX-validointi (kun ENABLE_POCX määritelty):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Perus allekirjoituksen validointi (ei vielä delegointitukea)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Perus allekirjoituksen validointi:**
1. Tarkista pubkey- ja allekirjoituskenttien olemassaolo
2. Validoi pubkeyn koko (33 tavua pakattu)
3. Validoi allekirjoituksen koko (65 tavua kompakti)
4. Palauta pubkey allekirjoituksesta: `pubkey.RecoverCompact(hash, signature)`
5. Varmenna palautettu pubkey vastaa tallennettua pubkeytä

**Toteutus:** `src/validation.cpp:CheckBlockHeader()`
**Allekirjoituslogiikka:** `src/pocx/consensus/signature.cpp:VerifyPoCXBlockCompactSignature()`

### Vaihe 2: Lohkon validointi (CheckBlock)

**Validoi:**
- Merkle-juuren oikeellisuus
- Transaktioiden kelvollisuus
- Coinbase-vaatimukset
- Lohkokokorajoitukset
- Vakio Bitcoin-konsensussäännöt

**Toteutus:** `src/consensus/validation.cpp:CheckBlock()`

### Vaihe 3: Kontekstuaalinen otsikon validointi (ContextualCheckBlockHeader)

**PoCX-spesifinen validointi:**

```cpp
#ifdef ENABLE_POCX
    // Step 1: Validate block height
    if (block.nHeight != pindexPrev->nHeight + 1) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-height");
    }

    // Step 2: Validate generation signature
    uint256 expected_gen_sig = GetNextGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gensig");
    }

    // Step 3: Validate base target
    uint64_t expected_base_target = pindexPrev->nNextBaseTarget;
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Step 4: Verify deadline timing
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (poc_time > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-timing");
    }
#endif
```

**Validation Steps:**
1. **Height:** Must be previous height + 1
2. **Generation Signature:** Must match calculated value from previous block
3. **Base Target:** Must match pre-computed value from previous block
4. **Deadline Timing:** Time-bended deadline (`poc_time`) must be ≤ elapsed time

**Toteutus:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Vaihe 4: Lohkon liittäminen (ConnectBlock)

**Täysi kontekstuaalinen validointi:**

```cpp
#ifdef ENABLE_POCX
    // Laajennettu allekirjoituksen validointi delegointituella
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Laajennettu allekirjoituksen validointi:**
1. Suorita perus allekirjoituksen validointi
2. Poimi tilitunniste palautetusta pubkeystä
3. Hae tehokas allekirjoittaja plotin osoitteelle: `GetEffectiveSigner(plot_address, height, view)`
4. Varmenna pubkeyn tili vastaa tehokasta allekirjoittajaa

**Delegointilogiikka:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Palauta delegoitu allekirjoittaja
    }

    return plotAddress;  // Ei delegointia – plotin omistaja allekirjoittaa
}
```

**Toteutus:**
- Liittäminen: `src/validation.cpp:ConnectBlock()`
- Laajennettu validointi: `src/pocx/consensus/signature.cpp:VerifyPoCXBlockCompactSignature()`
- Delegointilogiikka: `src/pocx/assignments/assignment_state.cpp:GetEffectiveSigner()`

### Vaihe 5: Ketjun aktivointi

**ProcessNewBlock-virta:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Validoi ja tallenna levylle
    2. ActivateBestChain → Päivitä ketjun kärki jos tämä on paras ketju
    3. Ilmoita verkkolle uudesta lohkosta
}
```

**Toteutus:** `src/validation.cpp:ProcessNewBlock()`

### Validointiyhteenveto

**Täydellinen validointipolku:**
```
Vastaanota lohko
    ↓
CheckBlockHeader (signature, compression, PoC proof, quality match)
    ↓
CheckBlock (transaktiot, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, base target, PoC-todiste, deadline)
    ↓
ConnectBlock (laajennettu allekirjoitus delegoinneilla, tilasiirtymät)
    ↓
ActivateBestChain (reorg-käsittely, ketjun laajennus)
    ↓
Verkkopropagaatio
```

---

## Delegointijärjestelmä

### Yleiskatsaus

Delegoinnit mahdollistavat plotin omistajien delegoida forging-oikeudet muille osoitteille säilyttäen plotin omistajuuden.

**Käyttötapaukset:**
- Poolilouhinta (plotit delegoidaan poolin osoitteelle)
- Kylmäsäilytys (louhinta-avain erillään plotin omistajuudesta)
- Monen osapuolen louhinta (jaettu infrastruktuuri)

### Delegointiarkkitehtuuri

**Vain OP_RETURN -pohjainen suunnittelu:**
- Delegoinnit tallennetaan OP_RETURN-tulosteisiin (ei UTXO:ta)
- Ei kulutusvaatimuksia (ei pölyä, ei maksuja pitämisestä)
- Seurataan CCoinsViewCache-laajennettua tilaa
- Aktivoidaan viivejakson jälkeen (oletus: 30 lohkoa; 4 regtestissä)

**Delegointitilat:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Ei delegointia
    ASSIGNING = 1,   // Delegointi odottaa aktivointia (viivejakso)
    ASSIGNED = 2,    // Delegointi aktiivinen, forging sallittu
    REVOKING = 3,    // Peruutus odottaa (viivejakso, yhä aktiivinen)
    REVOKED = 4      // Peruutus valmis, delegointi ei enää aktiivinen
};
```

### Delegointien luominen

**Transaktiomuoto:**
```cpp
Transaction {
    inputs: [any]  // Todistaa plotin osoitteen omistajuuden
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Validointisäännöt:**
1. Syötteen on oltava plotin omistajan allekirjoittama (todistaa omistajuuden)
2. OP_RETURN sisältää kelvollista delegointidataa
3. Plotin on oltava UNASSIGNED tai REVOKED
4. Ei duplikaatteja odottavia delegointeja mempoolissa
5. Vähimmäistransaktiomaksu maksettu

**Aktivointi:**
- Delegoinnin tila muuttuu ASSIGNING:ksi vahvistuksen korkeudessa
- Muuttuu ASSIGNED:ksi viivejakson jälkeen (4 lohkoa regtest, 30 lohkoa mainnet)
- Viive estää nopeat uudelleendelegoinnit lohkokiistojen aikana

**Toteutus:** `src/pocx/assignments/opcodes.h`, validointi ConnectBlockissa

### Delegointien peruuttaminen

**Transaktiomuoto:**
```cpp
Transaction {
    inputs: [any]  // Todistaa plotin osoitteen omistajuuden
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Vaikutus:**
- State transitions to REVOKING
- After `nForgingRevocationDelay` blocks (720 mainnet, 8 regtest), transitions to REVOKED
- Plot owner can forge again after revocation becomes effective
- Can create new assignment afterward

### Delegoinnin validointi louhinnan aikana

**Tehokkaan allekirjoittajan määritys:**
```cpp
// submit_nonce-validoinnissa
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) hylkää;

// Lohkon forging-vaiheessa
coinbase_script = P2WPKH(effective_signer);  // Palkkio menee tänne

// Lohkon allekirjoituksessa
signature = effective_signer_key.SignCompact(hash);  // On allekirjoitettava tehokkaalla allekirjoittajalla
```

**Lohkon validointi:**
```cpp
// VerifyPoCXBlockCompactSignature-funktiossa (laajennettu)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) hylkää;
```

**Keskeiset ominaisuudet:**
- Todiste sisältää aina alkuperäisen plotin osoitteen
- Allekirjoituksen on oltava tehokkaalta allekirjoittajalta
- Coinbase maksaa tehokkaalle allekirjoittajalle
- Validointi käyttää delegointitilaa lohkon korkeudessa

---

## Verkkopropagaatio

### Lohkon julkistaminen

**Vakio Bitcoin P2P-protokolla:**
1. Forgattu lohko lähetetään `ProcessNewBlock()`-kautta
2. Lohko validoidaan ja lisätään ketjuun
3. Verkkoilmoitus: `GetMainSignals().BlockConnected()`
4. P2P-kerros lähettää lohkon vertaisille

**Toteutus:** Vakio Bitcoin Core net_processing

### Lohkon välitys

**Compact Blocks (BIP 152):**
- Käytetään tehokkaaseen lohkon propagaatioon
- Vain transaktiotunnisteet lähetetään aluksi
- Vertaiset pyytävät puuttuvat transaktiot

**Täyden lohkon välitys:**
- Varajärjestelmä kun compact blocks epäonnistuu
- Täydellinen lohkodata lähetetään

### Ketjun uudelleenjärjestelyt

**Reorg-käsittely:**
```cpp
// Forger-työsäikeessä
if (current_tip_hash != stored_tip_hash) {
    // Ketjun uudelleenjärjestely havaittu
    reset_forging_state();
    log("Ketjun kärki muuttui, nollataan forging");
}
```

**Lohkoketjutasolla:**
- Vakio Bitcoin Core reorg-käsittely
- Paras ketju määritetään chainwork-arvon perusteella
- Irrotetut lohkot palautetaan mempooliin

---

## Tekniset yksityiskohdat

### Deadlock-esto

**ABBA-deadlock-kuvio (estetty):**
```
Säie A: cs_main → cs_wallet
Säie B: cs_wallet → cs_main
```

**Ratkaisu:**
1. **submit_nonce:** Nolla cs_main-käyttöä
   - `GetNewBlockContext()` käsittelee lukituksen sisäisesti
   - Kaikki validointi ennen forger-lähetystä

2. **Forger:** Jonopohjainen arkkitehtuuri
   - Yksi työsäie (ei säie-liitoksia)
   - Tuore konteksti jokaisella käyttökerralla
   - Ei sisäkkäisiä lukkoja

3. **Lompakon tarkistukset:** Suoritetaan ennen kalliita operaatioita
   - Aikainen hylkäys jos avainta ei ole
   - Erillään lohkoketjun tilan käytöstä

### Suorituskykyoptimoinnit

**Nopean epäonnistumisen validointi:**
```cpp
1. Muototarkistukset (välitön)
2. Kontekstivalidointi (kevyt)
3. Lompakkovarmistus (paikallinen)
4. Todisteen validointi (kallis SIMD)
```

**Yksittäinen kontekstihaku:**
- Yksi `GetNewBlockContext()`-kutsu lähetystä kohti
- Välimuistita tulokset useisiin tarkistuksiin
- Ei toistuvia cs_main-hankintoja

**Jonon tehokkuus:**
- Kevyt lähetysrakenne
- Ei base_targetia/deadlinea jonossa (lasketaan tuoreena)
- Minimaalinen muistijalanjälki

### Vanhentumisen käsittely

**"Tyhmä" forger-suunnittelu:**
- Ei lohkoketjutapahtumien tilauksia
- Laiska validointi kun tarvitaan
- Hiljaiset hylkäykset vanhentuneille lähetyksille

**Hyödyt:**
- Yksinkertainen arkkitehtuuri
- Ei monimutkaista synkronointia
- Robusti reunatapauksille

**Käsitellyt reunatapaukset:**
- Korkeusmuutokset → hylkää
- Generoinnin allekirjoituksen muutokset → hylkää
- Perustavoitteen muutokset → laske deadline uudelleen
- Reorgit → nollaa forging-tila

### Kryptografiset yksityiskohdat

**Generoinnin allekirjoitus:**
```cpp
dSHA256(prev_generation_signature || prev_account_id_20bytes)
```

**Lohkon allekirjoituksen tiiviste:**
```cpp
// Uses HashWriter (double-SHA256) with Bitcoin serialization (length-prefixed strings)
HashWriter hasher{};
hasher << POCX_BLOCK_MAGIC << block_hash.ToString();
hash = hasher.GetHash();  // double-SHA256
```

**Kompakti allekirjoitusmuoto:**
- 65 tavua: [recovery_id][r][s]
- Mahdollistaa julkisen avaimen palauttamisen
- Käytetään tilan säästämiseksi

**Tilitunniste:**
- 20-tavuinen pakatun julkisen avaimen HASH160
- Vastaa Bitcoin-osoitemuotoja (P2PKH, P2WPKH)

### Tulevat parannukset

**Dokumentoidut rajoitukset:**
1. Ei suorituskykymittareita (lähetysnopeudet, deadline-jakaumat)
2. Ei yksityiskohtaista virhekategorisointia louhijoille
3. Rajoitettu forger-tilan kysely (nykyinen deadline, jonon syvyys)

**Mahdolliset parannukset:**
- RPC forger-tilaa varten
- Mittarit louhintatehokkuudelle
- Laajennettu lokitus virheenkorjausta varten
- Pool-protokollatuki

---

## Koodiviittaukset

**Ydintoteutukset:**
- RPC-rajapinta: `src/pocx/rpc/mining.cpp`
- Forger-jono: `src/pocx/mining/scheduler.cpp`
- Konsensusvalidointi: `src/pocx/consensus/proof.cpp`
- Todisteen validointi: `src/pocx/consensus/signature.cpp`
- Aikataivutus: `src/pocx/algorithms/time_bending.cpp`
- Lohkon validointi: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Delegointilogiikka: `src/pocx/assignments/assignment_state.cpp:GetEffectiveSigner()`
- Kontekstin hallinta: `src/pocx/mining/block_context.cpp:GetNewBlockContext()`

**Datarakenteet:**
- Lohkomuoto: `src/primitives/block.h`
- Konsensusparametrit: `src/consensus/params.h`
- Delegointien seuranta: `src/coins.h` (CCoinsViewCache-laajennukset)

---

## Liite: Algoritmimäärittelyt

### Aikataivutuskaava

**Matemaattinen määritelmä:**
```
deadline_seconds = quality / base_target  (raaka)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

missä:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Toteutus:**
- Kiintopistearitmetiikka (Q42-muoto)
- Vain kokonaislukujen kuutiojuurilaskenta
- Optimoitu 256-bittiselle aritmetiikalle

### Laadun laskenta

**Prosessi:**
1. Generoi scoop generoinnin allekirjoituksesta ja korkeudesta
2. Lue plottidataa lasketulle scoopille
3. Tiivistä: `Shabal256Lite(scoop_data, generation_signature)`
4. Testaa skaalaustasot minimistä maksimiin
5. Palauta paras löydetty laatu

**Skaalaus:**
- Taso X0: POC2-perustaso (teoreettinen)
- Taso X1: XOR-transpose-perustaso
- Taso Xn: 2^(n-1) × X1-työ upotettuna
- Korkeampi skaalaus = enemmän plotin generointityötä

### Perustavoitteen säätö

**Joka lohkon säätö:**
1. Laske viimeaikaisten perustavoitteiden liukuva keskiarvo
2. Laske todellinen aikaväli vs tavoiteaikaväli liukuvalle ikkunalle
3. Säädä perustavoite suhteellisesti
4. Rajoita estämään äärimmäiset heilahtelut

**Kaava:**
```
avg_base_target = moving_average(viimeaikaiset perustavoitteet)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, ±20% of prev_base_target)
```

---

*Tämä dokumentaatio heijastaa täydellistä PoCX-konsensustoteutusta lokakuussa 2025.*

---

[← Edellinen: Plottimuoto](2-plot-format.md) | [Sisällysluettelo](index.md) | [Seuraava: Forging-delegoinnit →](4-forging-assignments.md)
