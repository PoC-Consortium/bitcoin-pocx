[← Ankstesnis: Grafiko formatas](2-plot-format.md) | [📘 Turinys](index.md) | [Toliau: Kalimo priskyrimai →](4-forging-assignments.md)

---

# 3 skyrius: Bitcoin-PoCX konsensusas ir kasimo procesas

Išsami PoCX (Proof of Capacity neXt generation) konsensuso mechanizmo ir kasimo proceso, integruoto į Bitcoin Core, techninė specifikacija.

---

## Turinys

1. [Apžvalga](#apžvalga)
2. [Konsensuso architektūra](#konsensuso-architektūra)
3. [Kasimo procesas](#kasimo-procesas)
4. [Bloko validacija](#bloko-validacija)
5. [Priskyrimo sistema](#priskyrimo-sistema)
6. [Tinklo sklaida](#tinklo-sklaida)
7. [Techninės detalės](#techninės-detalės)

---

## Apžvalga

Bitcoin-PoCX įgyvendina grynąjį Proof of Capacity konsensuso mechanizmą kaip visišką Bitcoin Proof of Work pakaitą. Tai nauja grandinė be atgalinio suderinamumo reikalavimų.

**Pagrindinės savybės:**
- **Energijos efektyvumas:** Kasimas naudoja iš anksto sugeneruotus grafiko failus vietoj skaičiavimo maišymo
- **Laiko lenkimo terminai:** Pasiskirstymo transformacija (eksponentinis→chi-kvadratinis) sumažina ilgus blokus, pagerina vidutinius bloko laikus
- **Priskyrimo palaikymas:** Grafiko savininkai gali deleguoti kalimo teises kitiems adresams
- **Natūrali C++ integracija:** Kriptografiniai algoritmai įgyvendinti C++ konsensuso validacijai

**Kasimo srautas:**
```
Išorinis kasėjas → get_mining_info → Skaičiuoti Nonce → submit_nonce →
Kalėjo eilė → Termino laukimas → Bloko kalimas → Tinklo sklaida →
Bloko validacija → Grandinės išplėtimas
```

---

## Konsensuso architektūra

### Bloko struktūra

PoCX blokai išplečia Bitcoin bloko struktūrą papildomais konsensuso laukais:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Grafiko sėkla (32 baitai)
    std::array<uint8_t, 20> account_id;       // Grafiko adresas (20 baitų hash160)
    uint32_t compression;                     // Mastelio lygis (1-255)
    uint64_t nonce;                           // Kasimo nonce (64 bitai)
    uint64_t quality;                         // Deklaruota kokybė (PoC maišos išvestis)
};

class CBlockHeader {
    // Standartiniai Bitcoin laukai
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCX konsensuso laukai (pakeičia nBits ir nNonce)
    int nHeight;                              // Bloko aukštis (be konteksto validacija)
    uint256 generationSignature;              // Generavimo parašas (kasimo entropija)
    uint64_t nBaseTarget;                     // Sudėtingumo parametras (atvirkštinis sudėtingumas)
    PoCXProof pocxProof;                      // Kasimo įrodymas

    // Bloko parašo laukai
    std::array<uint8_t, 33> vchPubKey;        // Suspaustas viešasis raktas (33 baitai)
    std::array<uint8_t, 65> vchSignature;     // Kompaktiškas parašas (65 baitai)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Transakcijos
};
```

**Pastaba:** Parašas (`vchSignature`) neįtrauktas į bloko maišos skaičiavimą, kad būtų išvengta kintamumo.

**Įgyvendinimas:** `src/primitives/block.h`

### Generavimo parašas

Generavimo parašas sukuria kasimo entropiją ir apsaugo nuo išankstinio skaičiavimo atakų.

**Skaičiavimas:**
```
generationSignature = SHA256(anksčiau_generationSignature || anksčiau_kasėjo_pubkey)
```

**Pradinis blokas:** Naudoja užkoduotą pradinį generavimo parašą

**Įgyvendinimas:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Bazinis tikslas (sudėtingumas)

Bazinis tikslas yra sudėtingumo atvirkštinė reikšmė - didesnės reikšmės reiškia lengvesnį kasimą.

**Koregavimo algoritmas:**
- Tikslinis bloko laikas: 120 sekundžių (pagrindinis tinklas), 1 sekundė (regtest)
- Koregavimo intervalas: Kiekvienas blokas
- Naudoja paskutinių bazinių tikslų slenkantį vidurkį
- Apribota, kad būtų išvengta ekstremalių sudėtingumo šuolių

**Įgyvendinimas:** `src/consensus/params.h`, sudėtingumo koregavimas bloko kūrime

### Mastelio lygiai

PoCX palaiko keičiamą darbo įrodymą grafiko failuose per mastelio lygius (Xn).

**Dinaminės ribos:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimalus priimamas lygis
    uint8_t nPoCXTargetCompression;  // Rekomenduojamas lygis
};
```

**Mastelio didinimo grafikas:**
- Eksponentiniai intervalai: 4, 12, 28, 60, 124 metai (pusės 1, 3, 7, 15, 31)
- Minimalus mastelio lygis didėja 1
- Tikslinis mastelio lygis didėja 1
- Išlaiko saugumo ribą tarp grafiko kūrimo ir paieškos kaštų
- Maksimalus mastelio lygis: 255

**Įgyvendinimas:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Kasimo procesas

### 1. Kasimo informacijos gavimas

**RPC komanda:** `get_mining_info`

**Procesas:**
1. Iškviesti `GetNewBlockContext(chainman)` dabartinei blockchain būsenai gauti
2. Apskaičiuoti dinamines suspaudimo ribas dabartiniam aukščiui
3. Grąžinti kasimo parametrus

**Atsakymas:**
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

**Įgyvendinimas:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Pastabos:**
- Jokie užraktai nelaikomi atsakymo generavimo metu
- Konteksto gavimas tvarko `cs_main` viduje
- `block_hash` įtrauktas nuorodai, bet nenaudojamas validacijoje

### 2. Išorinis kasimas

**Išorinio kasėjo atsakomybės:**
1. Skaityti grafiko failus iš disko
2. Apskaičiuoti scoop pagal generavimo parašą ir aukštį
3. Rasti nonce su geriausiu terminu
4. Pateikti mazgui per `submit_nonce`

**Grafiko failo formatas:**
- Paremtas POC2 formatu (Burstcoin)
- Patobulintas saugumo pataisymais ir keičiamumo patobulinimais
- Žr. autorystę `CLAUDE.md`

**Kasėjo įgyvendinimas:** Išorinis (pvz., paremtas Scavenger)

### 3. Nonce pateikimas ir validacija

**RPC komanda:** `submit_nonce`

**Parametrai:**
```
height, generation_signature, account_id, seed, nonce, quality (neprivaloma)
```

**Validacijos srautas (optimizuota tvarka):**

#### 1 žingsnis: Greita formato validacija
```cpp
// Paskyros ID: 40 šešioliktainių simbolių = 20 baitų
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Sėkla: 64 šešioliktainių simbolių = 32 baitai
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### 2 žingsnis: Konteksto gavimas
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Grąžina: height, generation_signature, base_target, block_hash
```

**Užrakinimas:** `cs_main` tvarkomas viduje, jokie užraktai nelaikomi RPC gijoje

#### 3 žingsnis: Konteksto validacija
```cpp
// Aukščio tikrinimas
if (height != context.height) reject;

// Generavimo parašo tikrinimas
if (submitted_gen_sig != context.generation_signature) reject;
```

#### 4 žingsnis: Piniginės verifikacija
```cpp
// Nustatyti efektyvųjį pasirašytoją (atsižvelgiant į priskyrimus)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Patikrinti ar mazgas turi privatų raktą efektyviajam pasirašytojui
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Priskyrimo palaikymas:** Grafiko savininkas gali priskirti kalimo teises kitam adresui. Piniginė turi turėti raktą efektyviajam pasirašytojui, nebūtinai grafiko savininkui.

#### 5 žingsnis: Įrodymo validacija
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 baitų
    block_height,
    nonce,
    seed,                // 32 baitai
    min_compression,
    max_compression,
    &result             // Išvestis: kokybė, terminas
);
```

**Algoritmas:**
1. Dekoduoti generavimo parašą iš šešioliktainės
2. Apskaičiuoti geriausią kokybę suspaudimo ribose naudojant SIMD optimizuotus algoritmus
3. Validuoti, kad kokybė atitinka sudėtingumo reikalavimus
4. Grąžinti neapdorotą kokybės reikšmę

**Įgyvendinimas:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### 6 žingsnis: Laiko lenkimo skaičiavimas
```cpp
// Neapdorotas sudėtingumo koreguotas terminas (sekundėmis)
uint64_t deadline_seconds = quality / base_target;

// Laiko lenktas kalimo laikas (sekundėmis)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Laiko lenkimo formulė:**
```
Y = skalė * (X^(1/3))
kur:
  X = kokybė / bazinis_tikslas
  skalė = bloko_laikas / (cbrt(bloko_laikas) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Paskirtis:** Transformuoja eksponentinį į chi-kvadratinį pasiskirstymą. Labai geri sprendimai kalami vėliau (tinklas turi laiko nuskaityti diskus), blogi sprendimai pagerinti. Sumažina ilgus blokus, išlaiko 120s vidurkį.

**Įgyvendinimas:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### 7 žingsnis: Kalėjo pateikimas
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // NE terminas - perskaičiuojamas kalėje
    height,
    generation_signature
);
```

**Eilės pagrįstas dizainas:**
- Pateikimas visada pavyksta (pridedama į eilę)
- RPC grąžina iš karto
- Darbuotojo gija apdoroja asinchroniškai

**Įgyvendinimas:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Kalėjo eilės apdorojimas

**Architektūra:**
- Viena pastovi darbuotojo gija
- FIFO pateikimo eilė
- Be užraktų kalimo būsena (tik darbuotojo gija)
- Jokių įdėtų užraktų (aklavietės prevencija)

**Darbuotojo gijos pagrindinis ciklas:**
```cpp
while (!shutdown) {
    // 1. Tikrinti eilėje esančius pateikimus
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Laukti termino arba naujo pateikimo
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**ProcessSubmission logika:**
```cpp
1. Gauti šviežią kontekstą: GetNewBlockContext(*chainman)

2. Pasenimo tikrinimai (tylus atmetimas):
   - Aukščio neatitikimas → atmesti
   - Generavimo parašo neatitikimas → atmesti
   - Viršūnės bloko maišos pasikeitimas (reorg) → atstatyti kalimo būseną

3. Kokybės palyginimas:
   - Jei kokybė >= dabartinė_geriausia → atmesti

4. Apskaičiuoti laiko lenktą terminą:
   terminas = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Atnaujinti kalimo būseną:
   - Atšaukti esamą kalimą (jei rastas geresnis)
   - Saugoti: account_id, seed, nonce, quality, deadline
   - Apskaičiuoti: forge_time = block_time + deadline_seconds
   - Saugoti viršūnės maišą reorg aptikimui
```

**Įgyvendinimas:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Termino laukimas ir bloko kalimas

**WaitForDeadlineOrNewSubmission:**

**Laukimo sąlygos:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Kai terminas pasiektas - šviežio konteksto validacija:**
```cpp
1. Gauti dabartinį kontekstą: GetNewBlockContext(*chainman)

2. Aukščio validacija:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Generavimo parašo validacija:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Bazinio tikslo ribinis atvejis:
   if (forging_base_target != current_base_target) {
       // Perskaičiuoti terminą su nauju baziniu tikslu
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Laukti vėl
   }

5. Viskas galioja → ForgeBlock()
```

**ForgeBlock procesas:**

```cpp
1. Nustatyti efektyvųjį pasirašytoją (priskyrimo palaikymas):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Sukurti coinbase scenarijų:
   coinbase_script = P2WPKH(effective_signer);  // Moka efektyviajam pasirašytojui

3. Sukurti bloko šabloną:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Pridėti PoCX įrodymą:
   block.pocxProof.account_id = plot_address;    // Originalus grafiko adresas
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Perskaičiuoti merkle šaknį:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Pasirašyti bloką:
   // Naudoti efektyviojo pasirašytojo raktą (gali skirtis nuo grafiko savininko)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Pateikti grandinei:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Rezultato tvarkymas:
   if (accepted) {
       log_success();
       reset_forging_state();  // Paruošta kitam blokui
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Įgyvendinimas:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Pagrindiniai projektavimo sprendimai:**
- Coinbase moka efektyviajam pasirašytojui (gerbia priskyrimus)
- Įrodymas turi originalų grafiko adresą (validacijai)
- Parašas nuo efektyviojo pasirašytojo rakto (nuosavybės įrodymas)
- Šablono kūrimas automatiškai įtraukia mempool transakcijas

---

## Bloko validacija

### Gaunamo bloko validacijos srautas

Kai blokas gaunamas iš tinklo arba pateikiamas lokaliai, jis pereina validaciją keliais etapais:

### 1 etapas: Antraštės validacija (CheckBlockHeader)

**Be konteksto validacija:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX validacija (kai ENABLE_POCX apibrėžta):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Bazinė parašo validacija (dar be priskyrimo palaikymo)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Bazinė parašo validacija:**
1. Patikrinti pubkey ir parašo laukų buvimą
2. Validuoti pubkey dydį (33 baitai suspaustas)
3. Validuoti parašo dydį (65 baitai kompaktiškas)
4. Atkurti pubkey iš parašo: `pubkey.RecoverCompact(hash, signature)`
5. Patikrinti, kad atkurtas pubkey atitinka saugomą pubkey

**Įgyvendinimas:** `src/validation.cpp:CheckBlockHeader()`
**Parašo logika:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### 2 etapas: Bloko validacija (CheckBlock)

**Validuoja:**
- Merkle šaknies teisingumą
- Transakcijų galiojimą
- Coinbase reikalavimus
- Bloko dydžio ribas
- Standartinius Bitcoin konsensuso taisykles

**Įgyvendinimas:** `src/consensus/validation.cpp:CheckBlock()`

### 3 etapas: Kontekstinė antraštės validacija (ContextualCheckBlockHeader)

**PoCX specifinė validacija:**

```cpp
#ifdef ENABLE_POCX
    // 1 žingsnis: Validuoti generavimo parašą
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // 2 žingsnis: Validuoti bazinį tikslą
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // 3 žingsnis: Validuoti talpos įrodymą
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

    // 4 žingsnis: Patikrinti termino laikymąsi
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Validacijos žingsniai:**
1. **Generavimo parašas:** Turi atitikti apskaičiuotą reikšmę iš ankstesnio bloko
2. **Bazinis tikslas:** Turi atitikti sudėtingumo koregavimo skaičiavimą
3. **Mastelio lygis:** Turi atitikti tinklo minimumą (`compression >= min_compression`)
4. **Kokybės deklaracija:** Pateikta kokybė turi atitikti apskaičiuotą kokybę iš įrodymo
5. **Talpos įrodymas:** Kriptografinio įrodymo validacija (SIMD optimizuota)
6. **Termino laikymas:** Laiko lenktas terminas (`poc_time`) turi būti ≤ praėjusio laiko

**Įgyvendinimas:** `src/validation.cpp:ContextualCheckBlockHeader()`

### 4 etapas: Bloko prijungimas (ConnectBlock)

**Pilna kontekstinė validacija:**

```cpp
#ifdef ENABLE_POCX
    // Išplėstinė parašo validacija su priskyrimo palaikymu
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Išplėstinė parašo validacija:**
1. Atlikti bazinę parašo validaciją
2. Išgauti paskyros ID iš atkurto pubkey
3. Gauti efektyvųjį pasirašytoją grafiko adresui: `GetEffectiveSigner(plot_address, height, view)`
4. Patikrinti, kad pubkey paskyra atitinka efektyvųjį pasirašytoją

**Priskyrimo logika:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Grąžinti priskirtą pasirašytoją
    }

    return plotAddress;  // Nėra priskyrimo - grafiko savininkas pasirašo
}
```

**Įgyvendinimas:**
- Prijungimas: `src/validation.cpp:ConnectBlock()`
- Išplėstinė validacija: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Priskyrimo logika: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### 5 etapas: Grandinės aktyvacija

**ProcessNewBlock srautas:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Validuoti ir saugoti į diską
    2. ActivateBestChain → Atnaujinti grandinės viršūnę jei tai geriausia grandinė
    3. Informuoti tinklą apie naują bloką
}
```

**Įgyvendinimas:** `src/validation.cpp:ProcessNewBlock()`

### Validacijos santrauka

**Pilnas validacijos kelias:**
```
Gauti bloką
    ↓
CheckBlockHeader (bazinis parašas)
    ↓
CheckBlock (transakcijos, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, bazinis tikslas, PoC įrodymas, terminas)
    ↓
ConnectBlock (išplėstinis parašas su priskyrimais, būsenos perėjimai)
    ↓
ActivateBestChain (reorg tvarkymas, grandinės išplėtimas)
    ↓
Tinklo sklaida
```

---

## Priskyrimo sistema

### Apžvalga

Priskyrimai leidžia grafiko savininkams deleguoti kalimo teises kitiems adresams, išlaikant grafiko nuosavybę.

**Naudojimo atvejai:**
- Baseinų kasimas (grafikai priskirti baseino adresui)
- Šaltoji saugykla (kasimo raktas atskirtas nuo grafiko nuosavybės)
- Daugiašalis kasimas (bendra infrastruktūra)

### Priskyrimo architektūra

**Tik OP_RETURN dizainas:**
- Priskyrimai saugomi OP_RETURN išvestyse (ne UTXO)
- Nėra išleidimo reikalavimų (nėra dulkių, nėra mokesčių už laikymą)
- Sekamas CCoinsViewCache išplėstoje būsenoje
- Aktyvuojamas po atidėjimo periodo (numatytas: 4 blokai)

**Priskyrimo būsenos:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Nėra priskyrimo
    ASSIGNING = 1,   // Priskyrimas laukia aktyvacijos (atidėjimo periodas)
    ASSIGNED = 2,    // Priskyrimas aktyvus, kalimas leidžiamas
    REVOKING = 3,    // Atšaukimas laukia (atidėjimo periodas, vis dar aktyvus)
    REVOKED = 4      // Atšaukimas užbaigtas, priskyrimas nebegalioja
};
```

### Priskyrimo kūrimas

**Transakcijos formatas:**
```cpp
Transaction {
    inputs: [any]  // Įrodo grafiko adreso nuosavybę
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <grafiko_adresas> <kalimo_adresas>
    ]
}
```

**Validacijos taisyklės:**
1. Įvestis turi būti pasirašyta grafiko savininko (įrodo nuosavybę)
2. OP_RETURN turi galiojančius priskyrimo duomenis
3. Grafikas turi būti UNASSIGNED arba REVOKED
4. Jokių dubliuotų laukiančių priskyrimų mempool
5. Sumokėtas minimalus transakcijos mokestis

**Aktyvacija:**
- Priskyrimas tampa ASSIGNING patvirtinimo aukštyje
- Tampa ASSIGNED po atidėjimo periodo (4 blokai regtest, 30 blokų pagrindiniame tinkle)
- Atidėjimas apsaugo nuo greitų perpriskyrimų blokų lenktynių metu

**Įgyvendinimas:** `src/script/forging_assignment.h`, validacija ConnectBlock

### Priskyrimo atšaukimas

**Transakcijos formatas:**
```cpp
Transaction {
    inputs: [any]  // Įrodo grafiko adreso nuosavybę
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <grafiko_adresas>
    ]
}
```

**Poveikis:**
- Iš karto būsenos perėjimas į REVOKED
- Grafiko savininkas gali kalti iš karto
- Gali sukurti naują priskyrimą vėliau

### Priskyrimo validacija kasimo metu

**Efektyviojo pasirašytojo nustatymas:**
```cpp
// submit_nonce validacijoje
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// Bloko kalime
coinbase_script = P2WPKH(effective_signer);  // Atlyginimas eina čia

// Bloko parašo
signature = effective_signer_key.SignCompact(hash);  // Turi pasirašyti efektyviuoju pasirašytoju
```

**Bloko validacija:**
```cpp
// VerifyPoCXBlockCompactSignature (išplėstinė)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Pagrindinės savybės:**
- Įrodymas visada turi originalų grafiko adresą
- Parašas turi būti nuo efektyviojo pasirašytojo
- Coinbase moka efektyviajam pasirašytojui
- Validacija naudoja priskyrimo būseną bloko aukštyje

---

## Tinklo sklaida

### Bloko paskelbimas

**Standartinis Bitcoin P2P protokolas:**
1. Nukaltas blokas pateiktas per `ProcessNewBlock()`
2. Blokas validuotas ir pridėtas į grandinę
3. Tinklo pranešimas: `GetMainSignals().BlockConnected()`
4. P2P sluoksnis transliuoja bloką kolegoms

**Įgyvendinimas:** Standartinis Bitcoin Core net_processing

### Bloko perdavimas

**Kompaktiški blokai (BIP 152):**
- Naudojami efektyviam bloko sklaidai
- Pradinai siunčiami tik transakcijų ID
- Kolegos prašo trūkstamų transakcijų

**Pilno bloko perdavimas:**
- Atsarginis variantas kai kompaktiški blokai nepavyksta
- Perduodami pilni bloko duomenys

### Grandinės reorganizacijos

**Reorg tvarkymas:**
```cpp
// Kalėjo darbuotojo gijoje
if (current_tip_hash != stored_tip_hash) {
    // Aptikta grandinės reorganizacija
    reset_forging_state();
    log("Grandinės viršūnė pasikeitė, atstatomos kalimo būsenos");
}
```

**Blockchain lygyje:**
- Standartinis Bitcoin Core reorg tvarkymas
- Geriausia grandinė nustatoma pagal chainwork
- Atjungti blokai grąžinami į mempool

---

## Techninės detalės

### Aklavietės prevencija

**ABBA aklavietės šablonas (išvengta):**
```
Gija A: cs_main → cs_wallet
Gija B: cs_wallet → cs_main
```

**Sprendimas:**
1. **submit_nonce:** Jokio cs_main naudojimo
   - `GetNewBlockContext()` tvarko užrakinimą viduje
   - Visa validacija prieš kalėjo pateikimą

2. **Kalėjas:** Eilės pagrįsta architektūra
   - Viena darbuotojo gija (jokių gijų sujungimų)
   - Šviežias kontekstas kiekvienai prieigai
   - Jokių įdėtų užraktų

3. **Piniginės tikrinimai:** Atliekami prieš brangias operacijas
   - Ankstyvasis atmetimas jei nėra rakto
   - Atskirta nuo blockchain būsenos prieigos

### Našumo optimizacijos

**Greito atmetimo validacija:**
```cpp
1. Formato tikrinimai (iš karto)
2. Konteksto validacija (lengvasvorė)
3. Piniginės verifikacija (lokalinė)
4. Įrodymo validacija (brangi SIMD)
```

**Vienas konteksto gavimas:**
- Vienas `GetNewBlockContext()` iškvietimas kiekvienam pateikimui
- Rezultatų podėlis keliems tikrinimams
- Jokių pakartotinių cs_main užgrobimų

**Eilės efektyvumas:**
- Lengvasvorė pateikimo struktūra
- Jokio base_target/deadline eilėje (perskaičiuojama šviežiai)
- Minimalus atminties pėdsakas

### Pasenimo tvarkymas

**"Paprastas" kalėjo dizainas:**
- Jokių blockchain įvykių prenumeratų
- Tingus validavimas kai reikia
- Tylus pasenusių pateikimų atmetimas

**Privalumai:**
- Paprasta architektūra
- Jokios sudėtingos sinchronizacijos
- Atsparus ribiniams atvejams

**Tvarkomi ribiniai atvejai:**
- Aukščio pasikeitimai → atmesti
- Generavimo parašo pasikeitimai → atmesti
- Bazinio tikslo pasikeitimai → perskaičiuoti terminą
- Reorganizacijos → atstatyti kalimo būseną

### Kriptografinės detalės

**Generavimo parašas:**
```cpp
SHA256(anksčiau_generavimo_parašas || anksčiau_kasėjo_pubkey_33baitai)
```

**Bloko parašo maiša:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || bloko_maišos_hex))
```

**Kompaktiško parašo formatas:**
- 65 baitai: [atkūrimo_id][r][s]
- Leidžia viešojo rakto atkūrimą
- Naudojamas vietos efektyvumui

**Paskyros ID:**
- 20 baitų HASH160 suspausto viešojo rakto
- Atitinka Bitcoin adresų formatus (P2PKH, P2WPKH)

### Ateities patobulinimai

**Dokumentuoti apribojimai:**
1. Jokie našumo metrikos (pateikimo dažniai, terminų pasiskirstymai)
2. Jokios detalios klaidų kategorizacijos kasėjams
3. Ribota kalėjo būsenos užklausa (dabartinis terminas, eilės gylis)

**Galimi patobulinimai:**
- RPC kalėjo būsenai
- Metrikos kasimo efektyvumui
- Patobulintas žurnalizavimas derinimui
- Baseino protokolo palaikymas

---

## Kodo nuorodos

**Pagrindiniai įgyvendinimai:**
- RPC sąsaja: `src/pocx/rpc/mining.cpp`
- Kalėjo eilė: `src/pocx/mining/scheduler.cpp`
- Konsensuso validacija: `src/pocx/consensus/validation.cpp`
- Įrodymo validacija: `src/pocx/consensus/pocx.cpp`
- Laiko lenkimas: `src/pocx/algorithms/time_bending.cpp`
- Bloko validacija: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Priskyrimo logika: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Konteksto valdymas: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Duomenų struktūros:**
- Bloko formatas: `src/primitives/block.h`
- Konsensuso parametrai: `src/consensus/params.h`
- Priskyrimo sekimas: `src/coins.h` (CCoinsViewCache išplėtimai)

---

## Priedas: Algoritmų specifikacijos

### Laiko lenkimo formulė

**Matematinis apibrėžimas:**
```
terminas_sekundėmis = kokybė / bazinis_tikslas  (neapdorota)

laiko_lenktas_terminas = skalė * (terminas_sekundėmis)^(1/3)

kur:
  skalė = bloko_laikas / (cbrt(bloko_laikas) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Įgyvendinimas:**
- Fiksuoto taško aritmetika (Q42 formatas)
- Tik sveikųjų skaičių kubinės šaknies skaičiavimas
- Optimizuota 256 bitų aritmetikai

### Kokybės skaičiavimas

**Procesas:**
1. Generuoti scoop iš generavimo parašo ir aukščio
2. Skaityti grafiko duomenis apskaičiuotam scoop
3. Maišyti: `SHABAL256(generavimo_parašas || scoop_duomenys)`
4. Testuoti mastelio lygius nuo min iki max
5. Grąžinti geriausią rastą kokybę

**Mastelio keitimas:**
- Lygis X0: POC2 bazinė linija (teorinis)
- Lygis X1: XOR-transpozicijos bazinė linija
- Lygis Xn: 2^(n-1) × X1 darbas įterptas
- Aukštesnis mastelis = daugiau grafiko generavimo darbo

### Bazinio tikslo koregavimas

**Kiekvieno bloko koregavimas:**
1. Apskaičiuoti paskutinių bazinių tikslų slenkantį vidurkį
2. Apskaičiuoti faktinį laiko tarpą prieš tikslinį slenkančio lango laiko tarpą
3. Koreguoti bazinį tikslą proporcingai
4. Apriboti, kad būtų išvengta ekstremalių šuolių

**Formulė:**
```
vid_bazinis_tikslas = slenkantis_vidurkis(paskutiniai baziniai tikslai)
koregavimo_koef = faktinis_laiko_tarpas / tikslinis_laiko_tarpas
naujas_bazinis_tikslas = vid_bazinis_tikslas * koregavimo_koef
naujas_bazinis_tikslas = apriboti(naujas_bazinis_tikslas, min, max)
```

---

*Ši dokumentacija atspindi išsamų PoCX konsensuso įgyvendinimą nuo 2025 m. spalio.*

---

[← Ankstesnis: Grafiko formatas](2-plot-format.md) | [📘 Turinys](index.md) | [Toliau: Kalimo priskyrimai →](4-forging-assignments.md)
