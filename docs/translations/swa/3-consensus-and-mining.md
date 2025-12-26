[← Iliyotangulia: Muundo wa Plot](2-plot-format.md) | [Yaliyomo](index.md) | [Inayofuata: Ugawaji wa Kuunda →](4-forging-assignments.md)

---

# Sura ya 3: Makubaliano na Mchakato wa Uchimbaji wa Bitcoin-PoCX

Maelezo kamili ya kiufundi ya utaratibu wa makubaliano ya PoCX (Proof of Capacity neXt generation) na mchakato wa uchimbaji uliounganishwa katika Bitcoin Core.

---

## Yaliyomo

1. [Muhtasari](#muhtasari)
2. [Muundo wa Makubaliano](#muundo-wa-makubaliano)
3. [Mchakato wa Uchimbaji](#mchakato-wa-uchimbaji)
4. [Uthibitishaji wa Bloku](#uthibitishaji-wa-bloku)
5. [Mfumo wa Ugawaji](#mfumo-wa-ugawaji)
6. [Usambazaji wa Mtandao](#usambazaji-wa-mtandao)
7. [Maelezo ya Kiufundi](#maelezo-ya-kiufundi)

---

## Muhtasari

Bitcoin-PoCX inatekeleza utaratibu safi wa makubaliano ya Proof of Capacity kama mbadala kamili wa Proof of Work ya Bitcoin. Huu ni mtandao mpya bila mahitaji ya utangamano wa nyuma.

**Sifa Muhimu:**
- **Ufanisi wa Nishati:** Uchimbaji unatumia faili za plot zilizozalishwa mapema badala ya hashing ya kompyuta
- **Tarehe za Mwisho Zilizopindwa Muda:** Ubadilishaji wa usambazaji (exponential→chi-squared) unapunguza bloku ndefu, unaboresha muda wa wastani wa bloku
- **Msaada wa Ugawaji:** Wamiliki wa plot wanaweza kukabidhi haki za kuunda kwa anwani nyingine
- **Muungano wa Asili wa C++:** Algorithm za kriptografia zimetekelezwa katika C++ kwa uthibitishaji wa makubaliano

**Mtiririko wa Uchimbaji:**
```
Mchimbaji wa Nje → get_mining_info → Hesabu Nonce → submit_nonce →
Foleni ya Kuunda → Kusubiri Tarehe ya Mwisho → Kuunda Bloku → Usambazaji wa Mtandao →
Uthibitishaji wa Bloku → Kuendeleza Mtandao
```

---

## Muundo wa Makubaliano

### Muundo wa Bloku

Bloku za PoCX zinaendeleza muundo wa bloku wa Bitcoin na sehemu za ziada za makubaliano:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Mbegu ya plot (byte 32)
    std::array<uint8_t, 20> account_id;       // Anwani ya plot (hash160 ya byte 20)
    uint32_t compression;                     // Kiwango cha upanuzi (1-255)
    uint64_t nonce;                           // Nonce ya uchimbaji (64-bit)
    uint64_t quality;                         // Ubora uliodaiwa (matokeo ya hash ya PoC)
};

class CBlockHeader {
    // Sehemu za kawaida za Bitcoin
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // Sehemu za makubaliano ya PoCX (zinabadilisha nBits na nNonce)
    int nHeight;                              // Urefu wa bloku (uthibitishaji bila muktadha)
    uint256 generationSignature;              // Sahihi ya uzalishaji (entropi ya uchimbaji)
    uint64_t nBaseTarget;                     // Kigezo cha ugumu (ugumu wa kinyume)
    PoCXProof pocxProof;                      // Uthibitisho wa uchimbaji

    // Sehemu za sahihi ya bloku
    std::array<uint8_t, 33> vchPubKey;        // Ufunguo wa umma uliokandamizwa (byte 33)
    std::array<uint8_t, 65> vchSignature;     // Sahihi iliyoshikana (byte 65)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Miamala
};
```

**Kumbuka:** Sahihi (`vchSignature`) imetengwa na hesabu ya hash ya bloku kuzuia malleability.

**Utekelezaji:** `src/primitives/block.h`

### Sahihi ya Uzalishaji

Sahihi ya uzalishaji inaunda entropi ya uchimbaji na kuzuia mashambulizi ya prehesabu.

**Hesabu:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**Bloku ya Mwanzo:** Inatumia sahihi ya awali ya uzalishaji iliyosimbwa ngumu

**Utekelezaji:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Lengo la Msingi (Ugumu)

Lengo la msingi ni kinyume cha ugumu - thamani za juu zaidi zinamaanisha uchimbaji rahisi zaidi.

**Algorithm ya Marekebisho:**
- Lengo la muda wa bloku: sekunde 120 (mainnet), sekunde 1 (regtest)
- Muda wa marekebisho: Kila bloku
- Inatumia wastani unaosogea wa lengo la msingi la hivi karibuni
- Imezuiwa kuzuia mabadiliko makubwa ya ugumu

**Utekelezaji:** `src/consensus/params.h`, mantiki ya marekebisho ya ugumu katika uundaji wa bloku

### Viwango vya Upanuzi

PoCX inasaidia proof-of-work inayopanuka katika faili za plot kupitia viwango vya upanuzi (Xn).

**Mipaka Inayobadilika:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Kiwango cha chini kinachokubaliwa
    uint8_t nPoCXTargetCompression;  // Kiwango kinachopendekezwa
};
```

**Ratiba ya Kuongeza Upanuzi:**
- Vipindi vya exponential: Miaka 4, 12, 28, 60, 124 (nusu 1, 3, 7, 15, 31)
- Kiwango cha chini cha upanuzi kinaongezeka kwa 1
- Kiwango cha lengo la upanuzi kinaongezeka kwa 1
- Inadumisha ukingo wa usalama kati ya gharama za kuunda plot na kutafuta
- Kiwango cha juu cha upanuzi: 255

**Utekelezaji:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Mchakato wa Uchimbaji

### 1. Kupata Habari za Uchimbaji

**Amri ya RPC:** `get_mining_info`

**Mchakato:**
1. Ita `GetNewBlockContext(chainman)` kupata hali ya sasa ya blockchain
2. Hesabu mipaka ya ukandamizaji inayobadilika kwa urefu wa sasa
3. Rudisha vigezo vya uchimbaji

**Jibu:**
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

**Utekelezaji:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Madokezo:**
- Hakuna kufuli zilizoshikiliwa wakati wa uzalishaji wa jibu
- Kupata muktadha kunashughulikia `cs_main` ndani yake
- `block_hash` imejumuishwa kwa marejeleo lakini haitumiki katika uthibitishaji

### 2. Uchimbaji wa Nje

**Majukumu ya mchimbaji wa nje:**
1. Soma faili za plot kutoka diski
2. Hesabu scoop kulingana na sahihi ya uzalishaji na urefu
3. Pata nonce yenye tarehe ya mwisho bora zaidi
4. Wasilisha kwa nodi kupitia `submit_nonce`

**Muundo wa Faili ya Plot:**
- Imejengwa juu ya muundo wa POC2 (Burstcoin)
- Imeongezwa na marekebisho ya usalama na uboreshaji wa upanuzi
- Tazama utambuzi katika `CLAUDE.md`

**Utekelezaji wa Mchimbaji:** Wa nje (k.m., uliojengwa juu ya Scavenger)

### 3. Uwasilishaji na Uthibitishaji wa Nonce

**Amri ya RPC:** `submit_nonce`

**Vigezo:**
```
height, generation_signature, account_id, seed, nonce, quality (hiari)
```

**Mtiririko wa Uthibitishaji (Mpangilio Ulioboreshwa):**

#### Hatua ya 1: Uthibitishaji wa Haraka wa Muundo
```cpp
// Account ID: herufi 40 za hex = byte 20
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Mbegu: herufi 64 za hex = byte 32
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Hatua ya 2: Kupata Muktadha
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Inarudisha: height, generation_signature, base_target, block_hash
```

**Kufunga:** `cs_main` inashughulikiwa ndani, hakuna kufuli zilizoshikiliwa katika thread ya RPC

#### Hatua ya 3: Uthibitishaji wa Muktadha
```cpp
// Ukaguzi wa urefu
if (height != context.height) reject;

// Ukaguzi wa sahihi ya uzalishaji
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Hatua ya 4: Uthibitishaji wa Pochi
```cpp
// Tambua msaini anayefanya kazi (ukizingatia ugawaji)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Angalia kama nodi ina ufunguo wa kibinafsi wa msaini anayefanya kazi
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Msaada wa Ugawaji:** Mmiliki wa plot anaweza kukabidhi haki za kuunda kwa anwani nyingine. Pochi lazima iwe na ufunguo wa msaini anayefanya kazi, sio lazima mmiliki wa plot.

#### Hatua ya 5: Uthibitishaji wa Uthibitisho
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // byte 20
    block_height,
    nonce,
    seed,                // byte 32
    min_compression,
    max_compression,
    &result             // Matokeo: quality, deadline
);
```

**Algorithm:**
1. Decode sahihi ya uzalishaji kutoka hex
2. Hesabu ubora bora katika anuwai ya ukandamizaji kwa kutumia algorithm zilizoimarishwa kwa SIMD
3. Thibitisha ubora unakidhi mahitaji ya ugumu
4. Rudisha thamani ya ubora isiyo na mabadiliko

**Utekelezaji:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Hatua ya 6: Hesabu ya Kupinda Muda
```cpp
// Tarehe ya mwisho iliyorekebishwa na ugumu (sekunde)
uint64_t deadline_seconds = quality / base_target;

// Muda wa kuunda uliopindwa (sekunde)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Fomula ya Kupinda Muda:**
```
Y = scale * (X^(1/3))
ambapo:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Madhumuni:** Inabadilisha usambazaji wa exponential kuwa chi-squared. Suluhisho nzuri sana zinaunda baadaye (mtandao una muda wa kuchanganua diski), suluhisho duni zimeboreshwa. Inapunguza bloku ndefu, inadumisha wastani wa sekunde 120.

**Utekelezaji:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Hatua ya 7: Uwasilishaji kwa Kuunda
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // SIO tarehe ya mwisho - inahesabiwa tena katika kuunda
    height,
    generation_signature
);
```

**Usanifu wa Foleni:**
- Uwasilishaji daima unafanikiwa (unaongezwa kwenye foleni)
- RPC inarudi mara moja
- Thread ya mfanyakazi inachakata kwa asynchronous

**Utekelezaji:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Uchakataji wa Foleni ya Kuunda

**Muundo:**
- Thread moja ya mfanyakazi inayoendelea
- Foleni ya uwasilishaji ya FIFO
- Hali ya kuunda bila kufuli (thread ya mfanyakazi pekee)
- Hakuna kufuli zilizowekwa ndani kwa ndani (kuzuia deadlock)

**Mzunguko Mkuu wa Thread ya Mfanyakazi:**
```cpp
while (!shutdown) {
    // 1. Angalia kwa uwasilishaji uliofanya foleni
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Subiri tarehe ya mwisho au uwasilishaji mpya
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**Mantiki ya ProcessSubmission:**
```cpp
1. Pata muktadha mpya: GetNewBlockContext(*chainman)

2. Ukaguzi wa uchakavu (kutupa kimya):
   - Kutofautiana kwa urefu → tupa
   - Kutofautiana kwa sahihi ya uzalishaji → tupa
   - Hash ya bloku ya ncha imebadilika (reorg) → weka upya hali ya kuunda

3. Ulinganisho wa ubora:
   - Ikiwa quality >= current_best → tupa

4. Hesabu tarehe ya mwisho iliyopindwa muda:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Sasisha hali ya kuunda:
   - Ghairi kuunda kuliopo (ikiwa bora imepatikana)
   - Hifadhi: account_id, seed, nonce, quality, deadline
   - Hesabu: forge_time = block_time + deadline_seconds
   - Hifadhi hash ya ncha kwa kugundua reorg
```

**Utekelezaji:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Kusubiri Tarehe ya Mwisho na Kuunda Bloku

**WaitForDeadlineOrNewSubmission:**

**Masharti ya Kusubiri:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Tarehe ya Mwisho Inapofikiwa - Uthibitishaji wa Muktadha Mpya:**
```cpp
1. Pata muktadha wa sasa: GetNewBlockContext(*chainman)

2. Uthibitishaji wa urefu:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Uthibitishaji wa sahihi ya uzalishaji:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Kesi ya ukingo wa lengo la msingi:
   if (forging_base_target != current_base_target) {
       // Hesabu tena tarehe ya mwisho na lengo la msingi jipya
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Subiri tena
   }

5. Yote ni halali → ForgeBlock()
```

**Mchakato wa ForgeBlock:**

```cpp
1. Tambua msaini anayefanya kazi (msaada wa ugawaji):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Unda script ya coinbase:
   coinbase_script = P2WPKH(effective_signer);  // Inalipa msaini anayefanya kazi

3. Unda template ya bloku:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Ongeza uthibitisho wa PoCX:
   block.pocxProof.account_id = plot_address;    // Anwani ya awali ya plot
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Hesabu tena mzizi wa merkle:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Saini bloku:
   // Tumia ufunguo wa msaini anayefanya kazi (inaweza kuwa tofauti na mmiliki wa plot)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Wasilisha kwa mtandao:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Kushughulikia matokeo:
   if (accepted) {
       log_success();
       reset_forging_state();  // Tayari kwa bloku inayofuata
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Utekelezaji:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Maamuzi Muhimu ya Usanifu:**
- Coinbase inalipa msaini anayefanya kazi (inaheshimu ugawaji)
- Uthibitisho una anwani ya awali ya plot (kwa uthibitishaji)
- Sahihi kutoka kwa ufunguo wa msaini anayefanya kazi (uthibitisho wa umiliki)
- Uundaji wa template unajumuisha miamala ya mempool moja kwa moja

---

## Uthibitishaji wa Bloku

### Mtiririko wa Uthibitishaji wa Bloku Inayoingia

Bloku inapopokewa kutoka mtandao au kuwasilishwa ndani, inakabiliwa na uthibitishaji katika hatua nyingi:

### Hatua ya 1: Uthibitishaji wa Kichwa (CheckBlockHeader)

**Uthibitishaji Bila Muktadha:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**Uthibitishaji wa PoCX (wakati ENABLE_POCX imefafanuliwa):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Uthibitishaji wa msingi wa sahihi (hakuna msaada wa ugawaji bado)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Uthibitishaji wa Msingi wa Sahihi:**
1. Angalia uwepo wa sehemu za pubkey na sahihi
2. Thibitisha ukubwa wa pubkey (byte 33 zilizokandamizwa)
3. Thibitisha ukubwa wa sahihi (byte 65 iliyoshikana)
4. Rejesha pubkey kutoka sahihi: `pubkey.RecoverCompact(hash, signature)`
5. Thibitisha pubkey iliyorejeshwa inalingana na pubkey iliyohifadhiwa

**Utekelezaji:** `src/validation.cpp:CheckBlockHeader()`
**Mantiki ya Sahihi:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Hatua ya 2: Uthibitishaji wa Bloku (CheckBlock)

**Inathiditisha:**
- Usahihi wa mzizi wa merkle
- Uhalali wa miamala
- Mahitaji ya coinbase
- Vikomo vya ukubwa wa bloku
- Sheria za kawaida za makubaliano ya Bitcoin

**Utekelezaji:** `src/consensus/validation.cpp:CheckBlock()`

### Hatua ya 3: Uthibitishaji wa Kichwa kwa Muktadha (ContextualCheckBlockHeader)

**Uthibitishaji Mahususi wa PoCX:**

```cpp
#ifdef ENABLE_POCX
    // Hatua ya 1: Thibitisha sahihi ya uzalishaji
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Hatua ya 2: Thibitisha lengo la msingi
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Hatua ya 3: Thibitisha proof of capacity
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

    // Hatua ya 4: Thibitisha muda wa tarehe ya mwisho
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Hatua za Uthibitishaji:**
1. **Sahihi ya Uzalishaji:** Lazima ilingane na thamani iliyohesabiwa kutoka bloku iliyotangulia
2. **Lengo la Msingi:** Lazima ilingane na hesabu ya marekebisho ya ugumu
3. **Kiwango cha Upanuzi:** Lazima kikidhi kiwango cha chini cha mtandao (`compression >= min_compression`)
4. **Dai la Ubora:** Ubora uliowasilishwa lazima ulingane na ubora uliohesabiwa kutoka uthibitisho
5. **Proof of Capacity:** Uthibitishaji wa kriptografia wa uthibitisho (umeimarishwa kwa SIMD)
6. **Muda wa Tarehe ya Mwisho:** Tarehe ya mwisho iliyopindwa muda (`poc_time`) lazima iwe ≤ muda uliopita

**Utekelezaji:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Hatua ya 4: Muunganisho wa Bloku (ConnectBlock)

**Uthibitishaji Kamili kwa Muktadha:**

```cpp
#ifdef ENABLE_POCX
    // Uthibitishaji wa sahihi ulioongezwa na msaada wa ugawaji
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Uthibitishaji wa Sahihi Ulioongezwa:**
1. Fanya uthibitishaji wa msingi wa sahihi
2. Toa kitambulisho cha akaunti kutoka pubkey iliyorejeshwa
3. Pata msaini anayefanya kazi kwa anwani ya plot: `GetEffectiveSigner(plot_address, height, view)`
4. Thibitisha akaunti ya pubkey inalingana na msaini anayefanya kazi

**Mantiki ya Ugawaji:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Rudisha msaini aliyegawiwa
    }

    return plotAddress;  // Hakuna ugawaji - mmiliki wa plot anasaini
}
```

**Utekelezaji:**
- Muunganisho: `src/validation.cpp:ConnectBlock()`
- Uthibitishaji ulioongezwa: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Mantiki ya ugawaji: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Hatua ya 5: Uanzishaji wa Mtandao

**Mtiririko wa ProcessNewBlock:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Thibitisha na hifadhi kwenye diski
    2. ActivateBestChain → Sasisha ncha ya mtandao ikiwa huu ni mtandao bora
    3. Arifu mtandao kuhusu bloku mpya
}
```

**Utekelezaji:** `src/validation.cpp:ProcessNewBlock()`

### Muhtasari wa Uthibitishaji

**Njia Kamili ya Uthibitishaji:**
```
Pokea Bloku
    ↓
CheckBlockHeader (sahihi ya msingi)
    ↓
CheckBlock (miamala, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, base target, uthibitisho wa PoC, tarehe ya mwisho)
    ↓
ConnectBlock (sahihi iliyoongezwa na ugawaji, mabadiliko ya hali)
    ↓
ActivateBestChain (kushughulikia reorg, kuendeleza mtandao)
    ↓
Usambazaji wa Mtandao
```

---

## Mfumo wa Ugawaji

### Muhtasari

Ugawaji unaruhusu wamiliki wa plot kukabidhi haki za kuunda kwa anwani nyingine huku wakidumisha umiliki wa plot.

**Matumizi:**
- Uchimbaji wa dimbwi (plot zinagawa kwa anwani ya dimbwi)
- Hifadhi baridi (ufunguo wa uchimbaji tofauti na umiliki wa plot)
- Uchimbaji wa vyama vingi (miundombinu iliyoshirikiwa)

### Muundo wa Ugawaji

**Usanifu wa OP_RETURN Pekee:**
- Ugawaji umehifadhiwa katika matokeo ya OP_RETURN (hakuna UTXO)
- Hakuna mahitaji ya matumizi (hakuna vumbi, hakuna ada za kushikilia)
- Inafuatiliwa katika hali iliyoongezwa ya CCoinsViewCache
- Inawezeshwa baada ya kipindi cha ucheleweshaji (default: bloku 4)

**Hali za Ugawaji:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Hakuna ugawaji uliopo
    ASSIGNING = 1,   // Ugawaji unasubiri uanzishaji (kipindi cha ucheleweshaji)
    ASSIGNED = 2,    // Ugawaji unafanya kazi, kuunda kunaruhusiwa
    REVOKING = 3,    // Kubatilisha kunasubiri (kipindi cha ucheleweshaji, bado inafanya kazi)
    REVOKED = 4      // Kubatilisha kumekamilika, ugawaji haufanyi kazi tena
};
```

### Kuunda Ugawaji

**Muundo wa Muamala:**
```cpp
Transaction {
    inputs: [any]  // Inathibitisha umiliki wa anwani ya plot
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Sheria za Uthibitishaji:**
1. Ingizo lazima lisainiwe na mmiliki wa plot (linathibitisha umiliki)
2. OP_RETURN ina data halali ya ugawaji
3. Plot lazima iwe UNASSIGNED au REVOKED
4. Hakuna ugawaji unaosubiri unaorudiwa katika mempool
5. Ada ya chini ya muamala imelipwa

**Uanzishaji:**
- Ugawaji unakuwa ASSIGNING katika urefu wa uthibitisho
- Unakuwa ASSIGNED baada ya kipindi cha ucheleweshaji (bloku 4 regtest, bloku 30 mainnet)
- Ucheleweshaji unazuia ugawaji upya wa haraka wakati wa mashindano ya bloku

**Utekelezaji:** `src/script/forging_assignment.h`, uthibitishaji katika ConnectBlock

### Kubatilisha Ugawaji

**Muundo wa Muamala:**
```cpp
Transaction {
    inputs: [any]  // Inathibitisha umiliki wa anwani ya plot
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Athari:**
- Mabadiliko ya hali ya haraka kuwa REVOKED
- Mmiliki wa plot anaweza kuunda mara moja
- Anaweza kuunda ugawaji mpya baadaye

### Uthibitishaji wa Ugawaji Wakati wa Uchimbaji

**Uamuzi wa Msaini Anayefanya Kazi:**
```cpp
// Katika uthibitishaji wa submit_nonce
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// Katika kuunda bloku
coinbase_script = P2WPKH(effective_signer);  // Zawadi inakwenda hapa

// Katika sahihi ya bloku
signature = effective_signer_key.SignCompact(hash);  // Lazima asaini na msaini anayefanya kazi
```

**Uthibitishaji wa Bloku:**
```cpp
// Katika VerifyPoCXBlockCompactSignature (iliyoongezwa)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Sifa Muhimu:**
- Uthibitisho daima una anwani ya awali ya plot
- Sahihi lazima iwe kutoka kwa msaini anayefanya kazi
- Coinbase inalipa msaini anayefanya kazi
- Uthibitishaji unatumia hali ya ugawaji katika urefu wa bloku

---

## Usambazaji wa Mtandao

### Tangazo la Bloku

**Itifaki ya Kawaida ya P2P ya Bitcoin:**
1. Bloku iliyoundwa inawasilishwa kupitia `ProcessNewBlock()`
2. Bloku inathiditishwa na kuongezwa kwenye mtandao
3. Arifa ya mtandao: `GetMainSignals().BlockConnected()`
4. Tabaka la P2P linatangaza bloku kwa wenzake

**Utekelezaji:** Net_processing ya kawaida ya Bitcoin Core

### Upitishaji wa Bloku

**Bloku Zilizokandamizwa (BIP 152):**
- Inatumika kwa usambazaji bora wa bloku
- Vitambulisho vya miamala pekee vinatumwa awali
- Wenzake wanaomba miamala inayokosekana

**Upitishaji wa Bloku Kamili:**
- Mbadala wakati bloku zilizokandamizwa zinashindwa
- Data kamili ya bloku inapitishwa

### Upangaji upya wa Mtandao

**Kushughulikia Reorg:**
```cpp
// Katika thread ya mfanyakazi wa kuunda
if (current_tip_hash != stored_tip_hash) {
    // Upangaji upya wa mtandao umegunduliwa
    reset_forging_state();
    log("Chain tip changed, resetting forging");
}
```

**Ngazi ya Blockchain:**
- Kushughulikia reorg kwa kawaida kwa Bitcoin Core
- Mtandao bora unaamuliwa na chainwork
- Bloku zilizokataliwa zinarudishwa kwenye mempool

---

## Maelezo ya Kiufundi

### Kuzuia Deadlock

**Muundo wa Deadlock ya ABBA (Umezuiwa):**
```
Thread A: cs_main → cs_wallet
Thread B: cs_wallet → cs_main
```

**Suluhisho:**
1. **submit_nonce:** Matumizi ya sifuri ya cs_main
   - `GetNewBlockContext()` inashughulikia kufunga ndani
   - Uthibitishaji wote kabla ya uwasilishaji wa kuunda

2. **Kuunda:** Muundo wa msingi wa foleni
   - Thread moja ya mfanyakazi (hakuna kujiunga kwa thread)
   - Muktadha mpya kwa kila ufikiaji
   - Hakuna kufuli zilizowekwa ndani kwa ndani

3. **Ukaguzi wa pochi:** Unafanywa kabla ya operesheni ghali
   - Kukataa mapema ikiwa hakuna ufunguo unaopatikana
   - Tofauti na ufikiaji wa hali ya blockchain

### Uboreshaji wa Utendaji

**Uthibitishaji wa Kushindwa Haraka:**
```cpp
1. Ukaguzi wa muundo (mara moja)
2. Uthibitishaji wa muktadha (nyepesi)
3. Uthibitishaji wa pochi (wa ndani)
4. Uthibitishaji wa uthibitisho (SIMD ghali)
```

**Kupata Muktadha Mara Moja:**
- Ito moja ya `GetNewBlockContext()` kwa uwasilishaji
- Hifadhi matokeo kwa ukaguzi mwingi
- Hakuna kupata cs_main mara kwa mara

**Ufanisi wa Foleni:**
- Muundo wa uwasilishaji nyepesi
- Hakuna base_target/deadline katika foleni (inahesabiwa tena upya)
- Matumizi madogo ya kumbukumbu

### Kushughulikia Uchakavu

**Usanifu wa Kuunda "Mjinga":**
- Hakuna usajili wa matukio ya blockchain
- Uthibitishaji wa uvivu wakati inahitajika
- Kutupa kimya kwa uwasilishaji chakavu

**Faida:**
- Muundo rahisi
- Hakuna usawazishaji mgumu
- Imara dhidi ya hali za ukingo

**Hali za Ukingo Zinazoshughulikiwa:**
- Mabadiliko ya urefu → tupa
- Mabadiliko ya sahihi ya uzalishaji → tupa
- Mabadiliko ya lengo la msingi → hesabu tena tarehe ya mwisho
- Reorg → weka upya hali ya kuunda

### Maelezo ya Kriptografia

**Sahihi ya Uzalishaji:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Hash ya Sahihi ya Bloku:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Muundo wa Sahihi Iliyoshikana:**
- Byte 65: [recovery_id][r][s]
- Inaruhusu kurejesha ufunguo wa umma
- Inatumika kwa ufanisi wa nafasi

**Kitambulisho cha Akaunti:**
- HASH160 ya byte 20 ya ufunguo wa umma uliokandamizwa
- Inalingana na muundo wa anwani za Bitcoin (P2PKH, P2WPKH)

### Uboreshaji wa Baadaye

**Vikwazo Vilivyoandikwa:**
1. Hakuna vipimo vya utendaji (viwango vya uwasilishaji, usambazaji wa tarehe za mwisho)
2. Hakuna uainishaji wa kina wa makosa kwa wachimbaji
3. Uulizaji mdogo wa hali ya kuunda (tarehe ya mwisho ya sasa, kina cha foleni)

**Uboreshaji Unaowezekana:**
- RPC kwa hali ya kuunda
- Vipimo vya ufanisi wa uchimbaji
- Uandishi wa kumbukumbu ulioimarishwa kwa utatuzi
- Msaada wa itifaki ya dimbwi

---

## Marejeleo ya Msimbo

**Utekelezaji wa Msingi:**
- Kiolesura cha RPC: `src/pocx/rpc/mining.cpp`
- Foleni ya Kuunda: `src/pocx/mining/scheduler.cpp`
- Uthibitishaji wa Makubaliano: `src/pocx/consensus/validation.cpp`
- Uthibitishaji wa Uthibitisho: `src/pocx/consensus/pocx.cpp`
- Kupinda Muda: `src/pocx/algorithms/time_bending.cpp`
- Uthibitishaji wa Bloku: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Mantiki ya Ugawaji: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Usimamizi wa Muktadha: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Miundo ya Data:**
- Muundo wa Bloku: `src/primitives/block.h`
- Vigezo vya Makubaliano: `src/consensus/params.h`
- Ufuatiliaji wa Ugawaji: `src/coins.h` (viendelezi vya CCoinsViewCache)

---

## Kiambatisho: Maelezo ya Algorithm

### Fomula ya Kupinda Muda

**Ufafanuzi wa Kihisabati:**
```
deadline_seconds = quality / base_target  (isiyo na mabadiliko)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

ambapo:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Utekelezaji:**
- Hesabu za nukta maalum (muundo wa Q42)
- Hesabu ya mzizi wa tatu wa integer pekee
- Imeimarishwa kwa hesabu za 256-bit

### Hesabu ya Ubora

**Mchakato:**
1. Zalisha scoop kutoka sahihi ya uzalishaji na urefu
2. Soma data ya plot kwa scoop iliyohesabiwa
3. Hash: `SHABAL256(generation_signature || scoop_data)`
4. Jaribu viwango vya upanuzi kutoka min hadi max
5. Rudisha ubora bora uliopatikana

**Upanuzi:**
- Kiwango X0: Msingi wa POC2 (wa kinadharia)
- Kiwango X1: Msingi wa XOR-transpose
- Kiwango Xn: Kazi 2^(n-1) × ya X1 iliyojumuishwa
- Upanuzi wa juu zaidi = kazi zaidi ya uzalishaji wa plot

### Marekebisho ya Lengo la Msingi

**Marekebisho ya kila bloku:**
1. Hesabu wastani unaosogea wa lengo la msingi la hivi karibuni
2. Hesabu muda halisi dhidi ya muda unaolengwa kwa dirisha linalosongelea
3. Rekebisha lengo la msingi kwa uwiano
4. Zuia kuzuia mabadiliko makubwa

**Fomula:**
```
avg_base_target = moving_average(lengo la msingi la hivi karibuni)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*Nyaraka hizi zinaonyesha utekelezaji kamili wa makubaliano ya PoCX kufikia Oktoba 2025.*

---

[← Iliyotangulia: Muundo wa Plot](2-plot-format.md) | [Yaliyomo](index.md) | [Inayofuata: Ugawaji wa Kuunda →](4-forging-assignments.md)
