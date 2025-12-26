[← Iepriekšējā: Plotfaila formāts](2-plot-format.md) | [📘 Satura rādītājs](index.md) | [Nākamā: Kalšanas piešķīrumi →](4-forging-assignments.md)

---

# 3. nodaļa: Bitcoin-PoCX konsensa un kalnrūpniecības process

Pilnīga PoCX (jaunās paaudzes jaudas pierādījums) konsensa mehānisma un kalnrūpniecības procesa tehniskā specifikācija, kas integrēta Bitcoin Core.

---

## Satura rādītājs

1. [Pārskats](#pārskats)
2. [Konsensa arhitektūra](#konsensa-arhitektūra)
3. [Kalnrūpniecības process](#kalnrūpniecības-process)
4. [Bloku validācija](#bloku-validācija)
5. [Piešķīrumu sistēma](#piešķīrumu-sistēma)
6. [Tīkla izplatīšana](#tīkla-izplatīšana)
7. [Tehniskās detaļas](#tehniskās-detaļas)

---

## Pārskats

Bitcoin-PoCX implementē tīru jaudas pierādījuma konsensa mehānismu kā pilnīgu Bitcoin darba pierādījuma aizstājēju. Šī ir jauna ķēde bez atpakaļejošas saderības prasībām.

**Galvenās īpašības:**
- **Energoefektīvs:** Kalnrūpniecība izmanto iepriekš ģenerētus plotfailus, nevis skaitļošanas jaukšanu
- **Laika līkumo termiņi:** Sadalījuma transformācija (eksponenciālais→hī-kvadrāta) samazina garus blokus, uzlabo vidējos bloku laikus
- **Piešķīrumu atbalsts:** Plotfailu īpašnieki var deleģēt kalšanas tiesības citām adresēm
- **Vietēja C++ integrācija:** Kriptogrāfiskie algoritmi implementēti C++ konsensa validācijai

**Kalnrūpniecības plūsma:**
```
Ārējais kalnracis → get_mining_info → Aprēķināt nonce → submit_nonce →
Kalšanas rinda → Termiņa gaidīšana → Bloka kalšana → Tīkla izplatīšana →
Bloka validācija → Ķēdes paplašināšana
```

---

## Konsensa arhitektūra

### Bloka struktūra

PoCX bloki paplašina Bitcoin bloka struktūru ar papildu konsensa laukiem:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Plotfaila sēkla (32 baiti)
    std::array<uint8_t, 20> account_id;       // Plotfaila adrese (20 baitu hash160)
    uint32_t compression;                     // Mērogošanas līmenis (1-255)
    uint64_t nonce;                           // Kalnrūpniecības nonce (64 biti)
    uint64_t quality;                         // Deklarētā kvalitāte (PoC jaucējvērtības izvade)
};

class CBlockHeader {
    // Standarta Bitcoin lauki
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCX konsensa lauki (aizstāj nBits un nNonce)
    int nHeight;                              // Bloka augstums (konteksta brīva validācija)
    uint256 generationSignature;              // Ģenerēšanas paraksts (kalnrūpniecības entropija)
    uint64_t nBaseTarget;                     // Grūtības parametrs (apgrieztā grūtība)
    PoCXProof pocxProof;                      // Kalnrūpniecības pierādījums

    // Bloka paraksta lauki
    std::array<uint8_t, 33> vchPubKey;        // Kompresēta publiskā atslēga (33 baiti)
    std::array<uint8_t, 65> vchSignature;     // Kompakts paraksts (65 baiti)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Darījumi
};
```

**Piezīme:** Paraksts (`vchSignature`) ir izslēgts no bloka jaucējvērtības aprēķina, lai novērstu maināmību.

**Implementācija:** `src/primitives/block.h`

### Ģenerēšanas paraksts

Ģenerēšanas paraksts rada kalnrūpniecības entropiju un novērš iepriekšaprēķina uzbrukumus.

**Aprēķins:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**Ģenēzes bloks:** Izmanto cieti kodētu sākotnējo ģenerēšanas parakstu

**Implementācija:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Bāzes mērķis (grūtība)

Bāzes mērķis ir grūtības apgrieztā vērtība — augstākas vērtības nozīmē vieglāku kalnrūpniecību.

**Pielāgošanas algoritms:**
- Mērķa bloka laiks: 120 sekundes (mainnet), 1 sekunde (regtest)
- Pielāgošanas intervāls: Katru bloku
- Izmanto neseno bāzes mērķu mainīgo vidējo
- Ierobežots, lai novērstu ekstrēmas grūtības svārstības

**Implementācija:** `src/consensus/params.h`, grūtības pielāgošana bloka izveidē

### Mērogošanas līmeņi

PoCX atbalsta mērogojamu darba pierādījumu plotfailos caur mērogošanas līmeņiem (Xn).

**Dinamiskas robežas:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimālais pieņemtais līmenis
    uint8_t nPoCXTargetCompression;  // Ieteicamais līmenis
};
```

**Mērogošanas palielināšanas grafiks:**
- Eksponenciāli intervāli: 4., 12., 28., 60., 124. gads (1., 3., 7., 15., 31. dalīšana uz pusēm)
- Minimālais mērogošanas līmenis palielinās par 1
- Mērķa mērogošanas līmenis palielinās par 1
- Uztur drošības rezervi starp plotfailu izveides un meklēšanas izmaksām
- Maksimālais mērogošanas līmenis: 255

**Implementācija:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Kalnrūpniecības process

### 1. Kalnrūpniecības informācijas iegūšana

**RPC komanda:** `get_mining_info`

**Process:**
1. Izsaukt `GetNewBlockContext(chainman)`, lai iegūtu pašreizējo blokķēdes stāvokli
2. Aprēķināt dinamiskas kompresijas robežas pašreizējam augstumam
3. Atgriezt kalnrūpniecības parametrus

**Atbilde:**
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

**Implementācija:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Piezīmes:**
- Nav bloķējumu atbildes ģenerēšanas laikā
- Konteksta iegūšana apstrādā `cs_main` iekšēji
- `block_hash` iekļauts atsaucei, bet netiek izmantots validācijā

### 2. Ārējā kalnrūpniecība

**Ārējā kalnrača pienākumi:**
1. Lasīt plotfailus no diska
2. Aprēķināt scoopu, balstoties uz ģenerēšanas parakstu un augstumu
3. Atrast nonce ar labāko termiņu
4. Iesniegt mezglam caur `submit_nonce`

**Plotfaila formāts:**
- Balstīts uz POC2 formātu (Burstcoin)
- Uzlabots ar drošības labojumiem un mērogojamības uzlabojumiem
- Skatiet atsauces `CLAUDE.md`

**Kalnraču implementācija:** Ārēja (piem., balstīta uz Scavenger)

### 3. Nonces iesniegšana un validācija

**RPC komanda:** `submit_nonce`

**Parametri:**
```
height, generation_signature, account_id, seed, nonce, quality (neobligāti)
```

**Validācijas plūsma (optimizēta secība):**

#### 1. solis: Ātrā formāta validācija
```cpp
// Konta ID: 40 heksadecimālie simboli = 20 baiti
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Sēkla: 64 heksadecimālie simboli = 32 baiti
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### 2. solis: Konteksta iegūšana
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Atgriež: height, generation_signature, base_target, block_hash
```

**Bloķēšana:** `cs_main` apstrādāts iekšēji, nav bloķējumu RPC pavedienā

#### 3. solis: Konteksta validācija
```cpp
// Augstuma pārbaude
if (height != context.height) reject;

// Ģenerēšanas paraksta pārbaude
if (submitted_gen_sig != context.generation_signature) reject;
```

#### 4. solis: Maka verifikācija
```cpp
// Noteikt efektīvo parakstītāju (ņemot vērā piešķīrumus)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Pārbaudīt, vai mezglam ir privātā atslēga efektīvajam parakstītājam
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Piešķīrumu atbalsts:** Plotfaila īpašnieks var piešķirt kalšanas tiesības citai adresei. Makam jābūt atslēgai efektīvajam parakstītājam, ne obligāti plotfaila īpašniekam.

#### 5. solis: Pierādījuma validācija
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 baiti
    block_height,
    nonce,
    seed,                // 32 baiti
    min_compression,
    max_compression,
    &result             // Izvade: quality, deadline
);
```

**Algoritms:**
1. Dekodēt ģenerēšanas parakstu no heksadecimālā
2. Aprēķināt labāko kvalitāti kompresijas diapazonā, izmantojot SIMD optimizētus algoritmus
3. Validēt, ka kvalitāte atbilst grūtības prasībām
4. Atgriezt neapstrādātu kvalitātes vērtību

**Implementācija:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### 6. solis: Laika līkumo aprēķins
```cpp
// Neapstrādāts grūtībai pielāgots termiņš (sekundēs)
uint64_t deadline_seconds = quality / base_target;

// Laika līkumo kalšanas laiks (sekundēs)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Laika līkumo formula:**
```
Y = scale * (X^(1/3))
kur:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Mērķis:** Transformē eksponenciālo uz hī-kvadrāta sadalījumu. Ļoti labi risinājumi tiek kalti vēlāk (tīklam ir laiks skenēt diskus), slikti risinājumi uzlaboti. Samazina garus blokus, uztur 120s vidējo.

**Implementācija:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### 7. solis: Kalšanas iesniegšana
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // NAV termiņš - pārrēķināts kalšanā
    height,
    generation_signature
);
```

**Rindas balstīts dizains:**
- Iesniegšana vienmēr izdodas (pievienots rindai)
- RPC atgriežas nekavējoties
- Darba pavediens apstrādā asinhroni

**Implementācija:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Kalšanas rindas apstrāde

**Arhitektūra:**
- Viens pastāvīgs darba pavediens
- FIFO iesniegumu rinda
- Bloķēšanas brīvs kalšanas stāvoklis (tikai darba pavediens)
- Nav ligzdotu bloķējumu (strupceļu novēršana)

**Darba pavediena galvenā cilpa:**
```cpp
while (!shutdown) {
    // 1. Pārbaudīt rindā esošos iesniegums
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Gaidīt termiņu vai jaunu iesniegumu
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**ProcessSubmission loģika:**
```cpp
1. Iegūt svaigu kontekstu: GetNewBlockContext(*chainman)

2. Novecojušuma pārbaudes (klusa atmešana):
   - Augstuma nesakritība → atmest
   - Ģenerēšanas paraksta nesakritība → atmest
   - Virsotnes bloka jaucējvērtība mainījusies (reorg) → atiestatīt kalšanas stāvokli

3. Kvalitātes salīdzināšana:
   - Ja quality >= current_best → atmest

4. Aprēķināt laika līkumo termiņu:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Atjaunināt kalšanas stāvokli:
   - Atcelt esošo kalšanu (ja atrasts labāks)
   - Saglabāt: account_id, seed, nonce, quality, deadline
   - Aprēķināt: forge_time = block_time + deadline_seconds
   - Saglabāt virsotnes jaucējvērtību reorganizāciju noteikšanai
```

**Implementācija:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Termiņa gaidīšana un bloka kalšana

**WaitForDeadlineOrNewSubmission:**

**Gaidīšanas nosacījumi:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Kad termiņš sasniegts - svaiga konteksta validācija:**
```cpp
1. Iegūt pašreizējo kontekstu: GetNewBlockContext(*chainman)

2. Augstuma validācija:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Ģenerēšanas paraksta validācija:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Bāzes mērķa robežgadījums:
   if (forging_base_target != current_base_target) {
       // Pārrēķināt termiņu ar jauno bāzes mērķi
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Gaidīt vēlreiz
   }

5. Viss derīgs → ForgeBlock()
```

**ForgeBlock process:**

```cpp
1. Noteikt efektīvo parakstītāju (piešķīrumu atbalsts):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Izveidot coinbase skriptu:
   coinbase_script = P2WPKH(effective_signer);  // Maksā efektīvajam parakstītājam

3. Izveidot bloka veidni:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Pievienot PoCX pierādījumu:
   block.pocxProof.account_id = plot_address;    // Oriģinālā plotfaila adrese
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Pārrēķināt merkle sakni:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Parakstīt bloku:
   // Izmantot efektīvā parakstītāja atslēgu (var atšķirties no plotfaila īpašnieka)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Iesniegt ķēdei:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Rezultāta apstrāde:
   if (accepted) {
       log_success();
       reset_forging_state();  // Gatavs nākamajam blokam
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implementācija:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Galvenie dizaina lēmumi:**
- Coinbase maksā efektīvajam parakstītājam (respektē piešķīrumus)
- Pierādījums satur oriģinālo plotfaila adresi (validācijai)
- Paraksts no efektīvā parakstītāja atslēgas (īpašumtiesību pierādījums)
- Veidnes izveidē automātiski iekļauj mempool darījumus

---

## Bloku validācija

### Ienākošā bloka validācijas plūsma

Kad bloks tiek saņemts no tīkla vai iesniegts lokāli, tas iziet validāciju vairākos posmos:

### 1. posms: Galvenes validācija (CheckBlockHeader)

**Konteksta brīva validācija:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX validācija (kad definēts ENABLE_POCX):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Pamata paraksta validācija (vēl nav piešķīrumu atbalsta)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Pamata paraksta validācija:**
1. Pārbaudīt publiskās atslēgas un paraksta lauku klātbūtni
2. Validēt publiskās atslēgas izmēru (33 baiti kompresēti)
3. Validēt paraksta izmēru (65 baiti kompakti)
4. Atgūt publisko atslēgu no paraksta: `pubkey.RecoverCompact(hash, signature)`
5. Verificēt, ka atgūtā publiskā atslēga sakrīt ar saglabāto publisko atslēgu

**Implementācija:** `src/validation.cpp:CheckBlockHeader()`
**Paraksta loģika:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### 2. posms: Bloka validācija (CheckBlock)

**Validē:**
- Merkle saknes pareizību
- Darījumu derīgumu
- Coinbase prasības
- Bloka izmēra ierobežojumus
- Standarta Bitcoin konsensa noteikumus

**Implementācija:** `src/consensus/validation.cpp:CheckBlock()`

### 3. posms: Kontekstuāla galvenes validācija (ContextualCheckBlockHeader)

**PoCX specifiska validācija:**

```cpp
#ifdef ENABLE_POCX
    // 1. solis: Validēt ģenerēšanas parakstu
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // 2. solis: Validēt bāzes mērķi
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // 3. solis: Validēt jaudas pierādījumu
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

    // 4. solis: Verificēt termiņa laiku
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Validācijas soļi:**
1. **Ģenerēšanas paraksts:** Jāsakrīt ar aprēķināto vērtību no iepriekšējā bloka
2. **Bāzes mērķis:** Jāsakrīt ar grūtības pielāgošanas aprēķinu
3. **Mērogošanas līmenis:** Jāatbilst tīkla minimumam (`compression >= min_compression`)
4. **Kvalitātes pretenzija:** Iesniegtajai kvalitātei jāsakrīt ar aprēķināto kvalitāti no pierādījuma
5. **Jaudas pierādījums:** Kriptogrāfiskā pierādījuma validācija (SIMD optimizēta)
6. **Termiņa laiks:** Laika līkumo termiņam (`poc_time`) jābūt ≤ pagājušajam laikam

**Implementācija:** `src/validation.cpp:ContextualCheckBlockHeader()`

### 4. posms: Bloka savienošana (ConnectBlock)

**Pilna kontekstuāla validācija:**

```cpp
#ifdef ENABLE_POCX
    // Paplašināta paraksta validācija ar piešķīrumu atbalstu
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Paplašināta paraksta validācija:**
1. Veikt pamata paraksta validāciju
2. Iegūt konta ID no atgūtās publiskās atslēgas
3. Iegūt efektīvo parakstītāju plotfaila adresei: `GetEffectiveSigner(plot_address, height, view)`
4. Verificēt, ka publiskās atslēgas konts sakrīt ar efektīvo parakstītāju

**Piešķīrumu loģika:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Atgriezt piešķirto parakstītāju
    }

    return plotAddress;  // Nav piešķīruma - plotfaila īpašnieks paraksta
}
```

**Implementācija:**
- Savienošana: `src/validation.cpp:ConnectBlock()`
- Paplašināta validācija: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Piešķīrumu loģika: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### 5. posms: Ķēdes aktivizācija

**ProcessNewBlock plūsma:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Validēt un saglabāt diskā
    2. ActivateBestChain → Atjaunināt ķēdes virsotni, ja šī ir labākā ķēde
    3. Paziņot tīklam par jauno bloku
}
```

**Implementācija:** `src/validation.cpp:ProcessNewBlock()`

### Validācijas kopsavilkums

**Pilns validācijas ceļš:**
```
Saņemt bloku
    ↓
CheckBlockHeader (pamata paraksts)
    ↓
CheckBlock (darījumi, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, base target, PoC pierādījums, termiņš)
    ↓
ConnectBlock (paplašināts paraksts ar piešķīrumiem, stāvokļa pārejas)
    ↓
ActivateBestChain (reorganizāciju apstrāde, ķēdes paplašināšana)
    ↓
Tīkla izplatīšana
```

---

## Piešķīrumu sistēma

### Pārskats

Piešķīrumi ļauj plotfailu īpašniekiem deleģēt kalšanas tiesības citām adresēm, saglabājot plotfailu īpašumtiesības.

**Lietošanas gadījumi:**
- Pūla kalnrūpniecība (plotfaili piešķir pūla adresei)
- Aukstā glabāšana (kalnrūpniecības atslēga atdalīta no plotfailu īpašumtiesībām)
- Daudzpušu kalnrūpniecība (dalīta infrastruktūra)

### Piešķīrumu arhitektūra

**Tikai OP_RETURN dizains:**
- Piešķīrumi glabāti OP_RETURN izvadēs (nav UTXO)
- Nav tēriņu prasību (nav putekļu, nav maksu turēšanai)
- Izsekoti CCoinsViewCache paplašinātajā stāvoklī
- Aktivizēti pēc aizkaves perioda (noklusējums: 4 bloki)

**Piešķīrumu stāvokļi:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Piešķīrums neeksistē
    ASSIGNING = 1,   // Piešķīrums gaida aktivizāciju (aizkaves periods)
    ASSIGNED = 2,    // Piešķīrums aktīvs, kalšana atļauta
    REVOKING = 3,    // Atsaukšana gaida (aizkaves periods, joprojām aktīvs)
    REVOKED = 4      // Atsaukšana pabeigta, piešķīrums vairs nav aktīvs
};
```

### Piešķīrumu izveidošana

**Darījuma formāts:**
```cpp
Transaction {
    inputs: [any]  // Pierāda plotfaila adreses īpašumtiesības
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Validācijas noteikumi:**
1. Ievadei jābūt parakstītai ar plotfaila īpašnieku (pierāda īpašumtiesības)
2. OP_RETURN satur derīgus piešķīruma datus
3. Plotfailam jābūt UNASSIGNED vai REVOKED
4. Nav dublikātu gaida piešķīrumu mempool
5. Samaksāta minimālā darījuma maksa

**Aktivizācija:**
- Piešķīrums kļūst ASSIGNING apstiprinājuma augstumā
- Kļūst ASSIGNED pēc aizkaves perioda (4 bloki regtest, 30 bloki mainnet)
- Aizkave novērš ātru pārpiešķiršanu bloku sacensību laikā

**Implementācija:** `src/script/forging_assignment.h`, validācija ConnectBlock

### Piešķīrumu atsaukšana

**Darījuma formāts:**
```cpp
Transaction {
    inputs: [any]  // Pierāda plotfaila adreses īpašumtiesības
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Efekts:**
- Tūlītēja stāvokļa pāreja uz REVOKED
- Plotfaila īpašnieks var kalst nekavējoties
- Var izveidot jaunu piešķīrumu pēc tam

### Piešķīrumu validācija kalnrūpniecības laikā

**Efektīvā parakstītāja noteikšana:**
```cpp
// submit_nonce validācijā
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// Bloka kalšanā
coinbase_script = P2WPKH(effective_signer);  // Atlīdzība iet šeit

// Bloka parakstā
signature = effective_signer_key.SignCompact(hash);  // Jāparaksta ar efektīvo parakstītāju
```

**Bloka validācija:**
```cpp
// VerifyPoCXBlockCompactSignature (paplašināts)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Galvenās īpašības:**
- Pierādījums vienmēr satur oriģinālo plotfaila adresi
- Parakstam jābūt no efektīvā parakstītāja
- Coinbase maksā efektīvajam parakstītājam
- Validācija izmanto piešķīruma stāvokli bloka augstumā

---

## Tīkla izplatīšana

### Bloka paziņošana

**Standarta Bitcoin P2P protokols:**
1. Kalts bloks iesniegts caur `ProcessNewBlock()`
2. Bloks validēts un pievienots ķēdei
3. Tīkla paziņojums: `GetMainSignals().BlockConnected()`
4. P2P slānis pārraida bloku vienaudžiem

**Implementācija:** Standarta Bitcoin Core net_processing

### Bloku retranslācija

**Kompaktie bloki (BIP 152):**
- Izmantoti efektīvai bloku izplatīšanai
- Sākotnēji nosūtīti tikai darījumu ID
- Vienaudži pieprasa trūkstošos darījumus

**Pilna bloka retranslācija:**
- Rezerves variants, kad kompaktie bloki neizdodas
- Pilni bloka dati tiek pārsūtīti

### Ķēdes reorganizācijas

**Reorganizāciju apstrāde:**
```cpp
// Kalšanas darba pavedienā
if (current_tip_hash != stored_tip_hash) {
    // Ķēdes reorganizācija noteikta
    reset_forging_state();
    log("Ķēdes virsotne mainījusies, atiestatot kalšanu");
}
```

**Blokķēdes līmenī:**
- Standarta Bitcoin Core reorganizāciju apstrāde
- Labākā ķēde noteikta pēc ķēdes darba
- Atvienotie bloki atgriezti mempool

---

## Tehniskās detaļas

### Strupceļu novēršana

**ABBA strupceļa modelis (novērsts):**
```
Pavediens A: cs_main → cs_wallet
Pavediens B: cs_wallet → cs_main
```

**Risinājums:**
1. **submit_nonce:** Nulle cs_main lietojuma
   - `GetNewBlockContext()` apstrādā bloķēšanu iekšēji
   - Visa validācija pirms kalšanas iesniegšanas

2. **Kalšana:** Rindas balstīta arhitektūra
   - Viens darba pavediens (nav pavedienu savienojumu)
   - Svaigs konteksts katrā piekļuvē
   - Nav ligzdotu bloķējumu

3. **Maka pārbaudes:** Veiktas pirms dārgām operācijām
   - Agrīna noraidīšana, ja nav pieejama atslēga
   - Atdalīts no blokķēdes stāvokļa piekļuves

### Veiktspējas optimizācijas

**Ātrās neveiksmes validācija:**
```cpp
1. Formāta pārbaudes (tūlītējas)
2. Konteksta validācija (viegla)
3. Maka verifikācija (lokāla)
4. Pierādījuma validācija (dārga SIMD)
```

**Viena konteksta ielāde:**
- Viens `GetNewBlockContext()` izsaukums uz iesniegumu
- Rezultātu kešošana vairākām pārbaudēm
- Nav atkārtotu cs_main iegūšanu

**Rindas efektivitāte:**
- Viegla iesnieguma struktūra
- Nav base_target/deadline rindā (pārrēķināts svaigi)
- Minimāls atmiņas pēdas nospiedums

### Novecojušuma apstrāde

**"Vienkāršais" kalšanas dizains:**
- Nav blokķēdes notikumu abonementu
- Slinka validācija, kad nepieciešams
- Klusa novecojušu iesniegumu atmešana

**Ieguvumi:**
- Vienkārša arhitektūra
- Nav sarežģītas sinhronizācijas
- Izturīgs pret robežgadījumiem

**Apstrādātie robežgadījumi:**
- Augstuma izmaiņas → atmest
- Ģenerēšanas paraksta izmaiņas → atmest
- Bāzes mērķa izmaiņas → pārrēķināt termiņu
- Reorganizācijas → atiestatīt kalšanas stāvokli

### Kriptogrāfiskās detaļas

**Ģenerēšanas paraksts:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Bloka paraksta jaucējvērtība:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Kompakta paraksta formāts:**
- 65 baiti: [recovery_id][r][s]
- Ļauj publiskās atslēgas atgūšanu
- Izmantots vietas efektivitātei

**Konta ID:**
- 20 baitu HASH160 no kompresētās publiskās atslēgas
- Sakrīt ar Bitcoin adrešu formātiem (P2PKH, P2WPKH)

### Nākotnes uzlabojumi

**Dokumentētie ierobežojumi:**
1. Nav veiktspējas metrikas (iesniegumu ātrumi, termiņu sadalījumi)
2. Nav detalizētas kļūdu kategorizācijas kalnračiem
3. Ierobežota kalšanas statusa vaicāšana (pašreizējais termiņš, rindas dziļums)

**Potenciālie uzlabojumi:**
- RPC kalšanas statusam
- Metrikas kalnrūpniecības efektivitātei
- Uzlabota žurnalizācija atkļūdošanai
- Pūla protokola atbalsts

---

## Koda atsauces

**Pamata implementācijas:**
- RPC saskarne: `src/pocx/rpc/mining.cpp`
- Kalšanas rinda: `src/pocx/mining/scheduler.cpp`
- Konsensa validācija: `src/pocx/consensus/validation.cpp`
- Pierādījuma validācija: `src/pocx/consensus/pocx.cpp`
- Laika līkumo: `src/pocx/algorithms/time_bending.cpp`
- Bloka validācija: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Piešķīrumu loģika: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Konteksta pārvaldība: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Datu struktūras:**
- Bloka formāts: `src/primitives/block.h`
- Konsensa parametri: `src/consensus/params.h`
- Piešķīrumu izsekošana: `src/coins.h` (CCoinsViewCache paplašinājumi)

---

## Pielikums: Algoritmu specifikācijas

### Laika līkumo formula

**Matemātiskā definīcija:**
```
deadline_seconds = quality / base_target  (neapstrādāts)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

kur:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Implementācija:**
- Fiksēta punkta aritmētika (Q42 formāts)
- Tikai veselo skaitļu kubsaknes aprēķins
- Optimizēts 256 bitu aritmētikai

### Kvalitātes aprēķins

**Process:**
1. Ģenerēt scoopu no ģenerēšanas paraksta un augstuma
2. Lasīt plotfaila datus aprēķinātajam scoopam
3. Jaukšana: `SHABAL256(generation_signature || scoop_data)`
4. Testēt mērogošanas līmeņus no min līdz max
5. Atgriezt labāko atrasto kvalitāti

**Mērogošana:**
- Līmenis X0: POC2 bāzlīnija (teorētisks)
- Līmenis X1: XOR-transpozīcijas bāzlīnija
- Līmenis Xn: 2^(n-1) × X1 darbs iegults
- Augstāka mērogošana = vairāk plotfailu ģenerēšanas darba

### Bāzes mērķa pielāgošana

**Pielāgošana katru bloku:**
1. Aprēķināt neseno bāzes mērķu mainīgo vidējo
2. Aprēķināt faktisko laika posmu pret mērķa laika posmu ritošā logā
3. Proporcionāli pielāgot bāzes mērķi
4. Ierobežot, lai novērstu ekstrēmas svārstības

**Formula:**
```
avg_base_target = moving_average(nesenie bāzes mērķi)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*Šī dokumentācija atspoguļo pilnīgu PoCX konsensa implementāciju uz 2025. gada oktobri.*

---

[← Iepriekšējā: Plotfaila formāts](2-plot-format.md) | [📘 Satura rādītājs](index.md) | [Nākamā: Kalšanas piešķīrumi →](4-forging-assignments.md)
