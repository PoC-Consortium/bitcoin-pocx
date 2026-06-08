[← पिछला: Plot प्रारूप](2-plot-format.md) | [📘 विषय-सूची](index.md) | [अगला: फोर्जिंग असाइनमेंट →](4-forging-assignments.md)

---

# अध्याय 3: Bitcoin-PoCX सहमति और माइनिंग प्रक्रिया

Bitcoin Core में एकीकृत PoCX (Proof of Capacity neXt generation) सहमति तंत्र और माइनिंग प्रक्रिया का संपूर्ण तकनीकी विनिर्देश।

---

## विषय-सूची

1. [अवलोकन](#अवलोकन)
2. [सहमति आर्किटेक्चर](#सहमति-आर्किटेक्चर)
3. [माइनिंग प्रक्रिया](#माइनिंग-प्रक्रिया)
4. [ब्लॉक सत्यापन](#ब्लॉक-सत्यापन)
5. [असाइनमेंट सिस्टम](#असाइनमेंट-सिस्टम)
6. [नेटवर्क प्रसार](#नेटवर्क-प्रसार)
7. [तकनीकी विवरण](#तकनीकी-विवरण)

---

## अवलोकन

Bitcoin-PoCX Bitcoin के Proof of Work के पूर्ण प्रतिस्थापन के रूप में एक शुद्ध Proof of Capacity सहमति तंत्र लागू करता है। यह पश्चगामी संगतता आवश्यकताओं के बिना एक नई चेन है।

**मुख्य गुण:**
- **ऊर्जा कुशल:** माइनिंग कम्प्यूटेशनल हैशिंग के बजाय पूर्व-उत्पन्न plot फ़ाइलों का उपयोग करती है
- **Time Bended Deadlines:** वितरण परिवर्तन (घातांकीय→Weibull, आकार k=3) लंबे ब्लॉक कम करता है, औसत ब्लॉक समय में सुधार
- **असाइनमेंट समर्थन:** Plot मालिक फोर्जिंग अधिकार अन्य पतों को प्रत्यायोजित कर सकते हैं
- **नेटिव C++ एकीकरण:** सहमति सत्यापन के लिए C++ में लागू क्रिप्टोग्राफिक एल्गोरिथम

**माइनिंग प्रवाह:**
```
बाहरी माइनर → get_mining_info → Nonce गणना → submit_nonce →
Forger कतार → Deadline प्रतीक्षा → ब्लॉक फोर्जिंग → नेटवर्क प्रसार →
ब्लॉक सत्यापन → चेन विस्तार
```

---

## सहमति आर्किटेक्चर

### ब्लॉक संरचना

PoCX ब्लॉक अतिरिक्त सहमति फ़ील्ड के साथ Bitcoin की ब्लॉक संरचना का विस्तार करते हैं:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Plot seed (32 बाइट्स)
    std::array<uint8_t, 20> account_id;       // Plot पता (20-बाइट hash160)
    uint32_t compression;                     // स्केलिंग स्तर (1-6)
    uint64_t nonce;                           // माइनिंग nonce (64-bit)
    uint64_t quality;                         // दावा की गई गुणवत्ता (PoC हैश आउटपुट)
};

class CBlockHeader {
    // मानक Bitcoin फ़ील्ड
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCX सहमति फ़ील्ड (nBits और nNonce को प्रतिस्थापित करते हैं)
    int nHeight;                              // ब्लॉक ऊंचाई (संदर्भ-मुक्त सत्यापन)
    uint256 generationSignature;              // Generation signature (माइनिंग एन्ट्रॉपी)
    uint64_t nBaseTarget;                     // कठिनाई पैरामीटर (विलोम कठिनाई)
    PoCXProof pocxProof;                      // माइनिंग प्रमाण

    // ब्लॉक हस्ताक्षर फ़ील्ड
    std::array<uint8_t, 33> vchPubKey;        // संपीड़ित सार्वजनिक कुंजी (33 बाइट्स)
    std::array<uint8_t, 65> vchSignature;     // कॉम्पैक्ट हस्ताक्षर (65 बाइट्स)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // लेनदेन
};
```

**नोट:** malleability रोकने के लिए हस्ताक्षर (`vchSignature`) ब्लॉक हैश गणना से बाहर रखा गया है।

**कार्यान्वयन:** `src/primitives/block.h`

### Generation Signature

Generation signature माइनिंग एन्ट्रॉपी बनाता है और precomputation हमलों को रोकता है।

**गणना:**
```
generationSignature = dSHA256(prev_generationSignature || prev_account_id_20bytes)
```

**Genesis ब्लॉक:** हार्डकोडेड प्रारंभिक generation signature का उपयोग करता है

**कार्यान्वयन:** `src/pocx/consensus/difficulty.cpp:GetNextGenerationSignature()` (`src/pocx/mining/block_context.cpp:GetNewBlockContext()` से कॉल किया जाता है)

### Base Target (कठिनाई)

Base target कठिनाई का विलोम है - उच्च मान का अर्थ आसान माइनिंग।

**समायोजन एल्गोरिथम:**
- लक्ष्य ब्लॉक समय: 120 सेकंड (सभी नेटवर्क)
- समायोजन अंतराल: प्रत्येक ब्लॉक
- हाल के base targets के मूविंग एवरेज का उपयोग
- अत्यधिक कठिनाई स्विंग रोकने के लिए क्लैंप

**कार्यान्वयन:** `src/consensus/params.h`, ब्लॉक निर्माण में कठिनाई समायोजन

### स्केलिंग स्तर

PoCX स्केलिंग स्तरों (Xn) के माध्यम से plot फ़ाइलों में स्केलेबल proof-of-work का समर्थन करता है।

**डायनामिक सीमाएं:**
```cpp
struct PoCXCompressionBounds {
    uint32_t nPoCXMinCompression;     // न्यूनतम स्वीकृत स्तर
    uint32_t nPoCXTargetCompression;  // अनुशंसित स्तर
};
```

**स्केलिंग वृद्धि अनुसूची:**
- घातांकीय अंतराल: वर्ष 4, 12, 28, 60, 124 (halvings 1, 3, 7, 15, 31)
- न्यूनतम स्केलिंग स्तर 1 से बढ़ता है
- लक्ष्य स्केलिंग स्तर 1 से बढ़ता है
- Plot निर्माण और लुकअप लागत के बीच सुरक्षा मार्जिन बनाए रखता है
- अधिकतम स्केलिंग स्तर: 255

**कार्यान्वयन:** `src/pocx/consensus/params.h:GetPoCXCompressionBounds()`

---

## माइनिंग प्रक्रिया

### 1. माइनिंग जानकारी पुनर्प्राप्ति

**RPC कमांड:** `get_mining_info`

**प्रक्रिया:**
1. वर्तमान ब्लॉकचेन स्थिति प्राप्त करने के लिए `GetNewBlockContext(chainman)` कॉल करें
2. वर्तमान ऊंचाई के लिए डायनामिक compression सीमाओं की गणना करें
3. माइनिंग पैरामीटर लौटाएं

**प्रतिक्रिया:**
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

**कार्यान्वयन:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**नोट्स:**
- प्रतिक्रिया जनरेशन के दौरान कोई लॉक नहीं रखे जाते
- संदर्भ अधिग्रहण आंतरिक रूप से `cs_main` को संभालता है
- `block_hash` संदर्भ के लिए शामिल लेकिन सत्यापन में उपयोग नहीं

### 2. बाहरी माइनिंग

**बाहरी माइनर जिम्मेदारियां:**
1. डिस्क से plot फ़ाइलें पढ़ें
2. Generation signature और ऊंचाई के आधार पर scoop गणना करें
3. सर्वोत्तम deadline वाला nonce खोजें
4. `submit_nonce` के माध्यम से नोड को सबमिट करें

**Plot फ़ाइल प्रारूप:**
- POC2 प्रारूप (Burstcoin) पर आधारित
- सुरक्षा सुधार और स्केलेबिलिटी संवर्द्धन के साथ
- `CLAUDE.md` में एट्रिब्यूशन देखें

**माइनर कार्यान्वयन:** बाहरी (जैसे, Scavenger पर आधारित)

### 3. Nonce सबमिशन और सत्यापन

**RPC कमांड:** `submit_nonce`

**पैरामीटर:**
```
height, generation_signature, account_id, seed, nonce, quality (वैकल्पिक)
```

**सत्यापन प्रवाह (अनुकूलित क्रम):**

#### चरण 1: तेज़ प्रारूप सत्यापन
```cpp
// Account ID: 40 हेक्स अक्षर = 20 बाइट्स
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 हेक्स अक्षर = 32 बाइट्स
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### चरण 2: संदर्भ अधिग्रहण
```cpp
auto context = pocx::mining::GetNewBlockContext(chainman);
// लौटाता है: height, generation_signature, base_target, block_hash
```

**लॉकिंग:** `cs_main` आंतरिक रूप से संभाला, RPC थ्रेड में कोई लॉक नहीं

#### चरण 3: संदर्भ सत्यापन
```cpp
// ऊंचाई जांच
if (height != context.height) reject;

// Generation signature जांच
if (submitted_gen_sig != context.generation_signature) reject;
```

#### चरण 4: वॉलेट सत्यापन
```cpp
// प्रभावी हस्ताक्षरकर्ता निर्धारित करें (असाइनमेंट पर विचार करते हुए)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// जांचें कि नोड के पास प्रभावी हस्ताक्षरकर्ता के लिए निजी कुंजी है
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**असाइनमेंट समर्थन:** Plot मालिक दूसरे पते को फोर्जिंग अधिकार असाइन कर सकता है। वॉलेट के पास प्रभावी हस्ताक्षरकर्ता के लिए कुंजी होनी चाहिए, जरूरी नहीं कि plot मालिक के लिए।

#### Step 5: Compression Validation
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
if (compression < bounds.nPoCXMinCompression || compression > bounds.nPoCXTargetCompression)
    reject;
```

#### Step 7: Time Bending: Proof Validation
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 बाइट्स
    block_height,
    nonce,
    seed,                // 32 bytes
    compression,
    &result             // Output: quality
);
```

**एल्गोरिथम:**
1. हेक्स से generation signature डिकोड करें
2. SIMD-अनुकूलित एल्गोरिथम का उपयोग करके compression रेंज में सर्वोत्तम गुणवत्ता गणना करें
3. सत्यापित करें कि गुणवत्ता कठिनाई आवश्यकताओं को पूरा करती है
4. रॉ गुणवत्ता मान लौटाएं

**कार्यान्वयन:** `src/pocx/consensus/proof.cpp:pocx_validate_block()`

#### चरण 6: Time Bending गणना
```cpp
// रॉ कठिनाई-समायोजित deadline (सेकंड)
uint64_t deadline_seconds = quality / base_target;

// Time Bended फोर्ज समय (सेकंड)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Time Bending सूत्र:**
```
Y = scale * (X^(1/3))
जहां:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**उद्देश्य:** घातांकीय को Weibull (आकार k=3) वितरण में बदलता है। बहुत अच्छे समाधान बाद में फोर्ज होते हैं (नेटवर्क के पास डिस्क स्कैन करने का समय होता है), खराब समाधान में सुधार। लंबे ब्लॉक कम, 120s औसत बनाए रखा।

**कार्यान्वयन:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Step 8: Forger Submission: Forger सबमिशन
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

**कतार-आधारित डिज़ाइन:**
- सबमिशन हमेशा सफल (कतार में जोड़ा गया)
- RPC तुरंत लौटता है
- वर्कर थ्रेड असिंक्रोनस रूप से प्रोसेस करता है

**कार्यान्वयन:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Forger कतार प्रोसेसिंग

**आर्किटेक्चर:**
- एकल स्थायी वर्कर थ्रेड
- FIFO सबमिशन कतार
- लॉक-फ्री फोर्जिंग स्थिति (केवल वर्कर थ्रेड)
- कोई नेस्टेड लॉक नहीं (डेडलॉक रोकथाम)

**वर्कर थ्रेड मुख्य लूप:**
```cpp
while (!shutdown) {
    // 1. कतारबद्ध सबमिशन की जांच करें
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Deadline या नए सबमिशन की प्रतीक्षा करें
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**ProcessSubmission लॉजिक:**
```cpp
1. ताज़ा संदर्भ प्राप्त करें: GetNewBlockContext(*chainman)

2. Staleness जांच (मौन त्याग):
   - ऊंचाई बेमेल → त्याग
   - Generation signature बेमेल → त्याग
   - टिप ब्लॉक हैश बदला (reorg) → फोर्जिंग स्थिति रीसेट

3. गुणवत्ता तुलना:
   - यदि quality >= current_best → त्याग

4. Time Bended deadline गणना करें:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. फोर्जिंग स्थिति अपडेट करें:
   - मौजूदा फोर्जिंग रद्द करें (यदि बेहतर मिला)
   - संग्रहीत करें: account_id, seed, nonce, quality, deadline
   - गणना करें: forge_time = block_time + deadline_seconds
   - Reorg पहचान के लिए टिप हैश संग्रहीत करें
```

**कार्यान्वयन:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Deadline प्रतीक्षा और ब्लॉक फोर्जिंग

**WaitForDeadlineOrNewSubmission:**

**प्रतीक्षा शर्तें:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**जब Deadline पहुंचा - ताज़ा संदर्भ सत्यापन:**
```cpp
1. वर्तमान संदर्भ प्राप्त करें: GetNewBlockContext(*chainman)

2. ऊंचाई सत्यापन:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Generation signature सत्यापन:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Base target एज केस:
   if (forging_base_target != current_base_target) {
       // नए base target के साथ deadline पुनर्गणना करें
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // फिर से प्रतीक्षा करें
   }

5. सभी वैध → ForgeBlock()
```

**ForgeBlock प्रक्रिया:**

```cpp
1. प्रभावी हस्ताक्षरकर्ता निर्धारित करें (असाइनमेंट समर्थन):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Coinbase स्क्रिप्ट बनाएं:
   coinbase_script = P2WPKH(effective_signer);  // प्रभावी हस्ताक्षरकर्ता को भुगतान

3. ब्लॉक टेम्पलेट बनाएं:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. PoCX प्रमाण जोड़ें:
   block.pocxProof.account_id = plot_address;    // मूल plot पता
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;
   block.pocxProof.compression = compression;

5. Merkle root पुनर्गणना करें:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. ब्लॉक पर हस्ताक्षर करें:
   // प्रभावी हस्ताक्षरकर्ता की कुंजी का उपयोग करें (plot मालिक से भिन्न हो सकती है)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. चेन में सबमिट करें:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. परिणाम हैंडलिंग:
   if (accepted) {
       log_success();
       reset_forging_state();  // अगले ब्लॉक के लिए तैयार
   } else {
       log_failure();
       reset_forging_state();
   }
```

**कार्यान्वयन:** `src/pocx/mining/block_builder.cpp:BuildBlock()`

**मुख्य डिज़ाइन निर्णय:**
- Coinbase प्रभावी हस्ताक्षरकर्ता को भुगतान करता है (असाइनमेंट का सम्मान)
- प्रमाण में मूल plot पता होता है (सत्यापन के लिए)
- प्रभावी हस्ताक्षरकर्ता की कुंजी से हस्ताक्षर (स्वामित्व प्रमाण)
- टेम्पलेट निर्माण स्वचालित रूप से mempool लेनदेन शामिल करता है

---

## ब्लॉक सत्यापन

### आने वाले ब्लॉक सत्यापन प्रवाह

जब कोई ब्लॉक नेटवर्क से प्राप्त होता है या स्थानीय रूप से सबमिट किया जाता है, तो यह कई चरणों में सत्यापन से गुजरता है:

### चरण 1: हेडर सत्यापन (CheckBlockHeader)

**संदर्भ-मुक्त सत्यापन:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX सत्यापन (जब ENABLE_POCX परिभाषित):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // बुनियादी हस्ताक्षर सत्यापन (अभी तक असाइनमेंट समर्थन नहीं)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**बुनियादी हस्ताक्षर सत्यापन:**
1. Pubkey और signature फ़ील्ड की उपस्थिति जांचें
2. Pubkey आकार सत्यापित करें (33 बाइट्स संपीड़ित)
3. Signature आकार सत्यापित करें (65 बाइट्स कॉम्पैक्ट)
4. Signature से pubkey पुनर्प्राप्त करें: `pubkey.RecoverCompact(hash, signature)`
5. सत्यापित करें कि पुनर्प्राप्त pubkey संग्रहीत pubkey से मेल खाता है

**कार्यान्वयन:** `src/validation.cpp:CheckBlockHeader()`
**हस्ताक्षर लॉजिक:** `src/pocx/consensus/signature.cpp:VerifyPoCXBlockCompactSignature()`

### चरण 2: ब्लॉक सत्यापन (CheckBlock)

**सत्यापित करता है:**
- Merkle root शुद्धता
- लेनदेन वैधता
- Coinbase आवश्यकताएं
- ब्लॉक आकार सीमाएं
- मानक Bitcoin सहमति नियम

**कार्यान्वयन:** `src/consensus/validation.cpp:CheckBlock()`

### चरण 3: संदर्भात्मक हेडर सत्यापन (ContextualCheckBlockHeader)

**PoCX-विशिष्ट सत्यापन:**

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

**कार्यान्वयन:** `src/validation.cpp:ContextualCheckBlockHeader()`

### चरण 4: ब्लॉक कनेक्शन (ConnectBlock)

**पूर्ण संदर्भात्मक सत्यापन:**

```cpp
#ifdef ENABLE_POCX
    // असाइनमेंट समर्थन के साथ विस्तारित हस्ताक्षर सत्यापन
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**विस्तारित हस्ताक्षर सत्यापन:**
1. बुनियादी हस्ताक्षर सत्यापन करें
2. पुनर्प्राप्त pubkey से account ID निकालें
3. Plot पते के लिए प्रभावी हस्ताक्षरकर्ता प्राप्त करें: `GetEffectiveSigner(plot_address, height, view)`
4. सत्यापित करें कि pubkey account प्रभावी हस्ताक्षरकर्ता से मेल खाता है

**असाइनमेंट लॉजिक:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // असाइन किया गया हस्ताक्षरकर्ता लौटाएं
    }

    return plotAddress;  // कोई असाइनमेंट नहीं - plot मालिक हस्ताक्षर करता है
}
```

**Coinbase प्राप्तकर्ता** (कंसेंसस द्वारा लागू नहीं):

माइनर coinbase आउटपुट को प्रभावी हस्ताक्षरकर्ता को भुगतान करने के लिए सेट करता है (`src/pocx/mining/block_builder.cpp:CreateCoinbaseScript()`), लेकिन कंसेंसस इसे सत्यापित **नहीं** करता। कंसेंसस केवल यह लागू करता है कि *ब्लॉक हस्ताक्षर* प्रभावी हस्ताक्षरकर्ता द्वारा उत्पन्न हो — ऊपर दी गई `bad-pocx-assignment-sig` जाँच। कोई `bad-pocx-coinbase` नियम नहीं है; coinbase प्राप्तकर्ता माइनर द्वारा चुना जाता है।

**कार्यान्वयन:**
- कनेक्शन: `src/validation.cpp:ConnectBlock()`
- विस्तारित सत्यापन: `src/pocx/consensus/signature.cpp:VerifyPoCXBlockCompactSignature()`
- असाइनमेंट लॉजिक: `src/pocx/assignments/assignment_state.cpp:GetEffectiveSigner()`

### चरण 5: चेन सक्रियण

**ProcessNewBlock प्रवाह:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → सत्यापित करें और डिस्क में संग्रहीत करें
    2. ActivateBestChain → यदि यह सर्वोत्तम चेन है तो चेन टिप अपडेट करें
    3. नए ब्लॉक की नेटवर्क को सूचना दें
}
```

**कार्यान्वयन:** `src/validation.cpp:ProcessNewBlock()`

### सत्यापन सारांश

**पूर्ण सत्यापन पथ:**
```
ब्लॉक प्राप्त करें
    ↓
CheckBlockHeader (बुनियादी हस्ताक्षर)
    ↓
CheckBlock (लेनदेन, merkle)
    ↓
ContextualCheckBlockHeader (height, gen sig, base target, deadline)
    ↓
ConnectBlock (असाइनमेंट के साथ विस्तारित हस्ताक्षर, स्थिति संक्रमण)
    ↓
ActivateBestChain (reorg हैंडलिंग, चेन विस्तार)
    ↓
नेटवर्क प्रसार
```

---

## असाइनमेंट सिस्टम

### अवलोकन

असाइनमेंट plot मालिकों को plot स्वामित्व बनाए रखते हुए फोर्जिंग अधिकार अन्य पतों को प्रत्यायोजित करने की अनुमति देते हैं।

**उपयोग के मामले:**
- पूल माइनिंग (plots पूल पते को असाइन करते हैं)
- कोल्ड स्टोरेज (माइनिंग कुंजी plot स्वामित्व से अलग)
- बहु-पक्षीय माइनिंग (साझा बुनियादी ढांचा)

### असाइनमेंट आर्किटेक्चर

**OP_RETURN-केवल डिज़ाइन:**
- असाइनमेंट OP_RETURN आउटपुट में संग्रहीत (कोई UTXO नहीं)
- कोई खर्च आवश्यकताएं नहीं (कोई dust नहीं, होल्डिंग के लिए कोई शुल्क नहीं)
- CCoinsViewCache विस्तारित स्थिति में ट्रैक
- विलंब अवधि के बाद सक्रिय (डिफ़ॉल्ट: 30 ब्लॉक; regtest पर 4)

**असाइनमेंट स्थितियां:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // कोई असाइनमेंट मौजूद नहीं
    ASSIGNING = 1,   // असाइनमेंट सक्रियण लंबित (विलंब अवधि)
    ASSIGNED = 2,    // असाइनमेंट सक्रिय, फोर्जिंग की अनुमति
    REVOKING = 3,    // निरस्तीकरण लंबित (विलंब अवधि, अभी भी सक्रिय)
    REVOKED = 4      // निरस्तीकरण पूर्ण, असाइनमेंट अब सक्रिय नहीं
};
```

### असाइनमेंट बनाना

**लेनदेन प्रारूप:**
```cpp
Transaction {
    inputs: [any]  // Plot पते का स्वामित्व सिद्ध करता है
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**सत्यापन नियम:**
1. इनपुट plot मालिक द्वारा हस्ताक्षरित होना चाहिए (स्वामित्व सिद्ध करता है)
2. OP_RETURN में वैध असाइनमेंट डेटा होता है
3. Plot UNASSIGNED या REVOKED होना चाहिए
4. Mempool में कोई डुप्लिकेट लंबित असाइनमेंट नहीं
5. न्यूनतम लेनदेन शुल्क भुगतान किया गया

**सक्रियण:**
- असाइनमेंट पुष्टि ऊंचाई पर ASSIGNING बन जाता है
- विलंब अवधि के बाद ASSIGNED बन जाता है (4 ब्लॉक regtest, 30 ब्लॉक mainnet)
- विलंब ब्लॉक दौड़ के दौरान त्वरित पुनर्असाइनमेंट रोकता है

**कार्यान्वयन:** `src/pocx/assignments/opcodes.h`, ConnectBlock में सत्यापन

### असाइनमेंट निरस्त करना

**लेनदेन प्रारूप:**
```cpp
Transaction {
    inputs: [any]  // Plot पते का स्वामित्व सिद्ध करता है
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**प्रभाव:**
- REVOKED में तत्काल स्थिति संक्रमण
- Plot मालिक तुरंत फोर्ज कर सकता है
- बाद में नया असाइनमेंट बना सकता है

### माइनिंग के दौरान असाइनमेंट सत्यापन

**प्रभावी हस्ताक्षरकर्ता निर्धारण:**
```cpp
// submit_nonce सत्यापन में
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// ब्लॉक फोर्जिंग में
coinbase_script = P2WPKH(effective_signer);  // पुरस्कार यहां जाता है

// ब्लॉक हस्ताक्षर में
signature = effective_signer_key.SignCompact(hash);  // प्रभावी हस्ताक्षरकर्ता से हस्ताक्षर होना चाहिए
```

**ब्लॉक सत्यापन:**
```cpp
// VerifyPoCXBlockCompactSignature (विस्तारित) में
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**मुख्य गुण:**
- प्रमाण में हमेशा मूल plot पता होता है
- हस्ताक्षर प्रभावी हस्ताक्षरकर्ता से होना चाहिए
- Coinbase प्रभावी हस्ताक्षरकर्ता को भुगतान करता है
- सत्यापन ब्लॉक ऊंचाई पर असाइनमेंट स्थिति का उपयोग करता है

---

## नेटवर्क प्रसार

### ब्लॉक घोषणा

**मानक Bitcoin P2P प्रोटोकॉल:**
1. `ProcessNewBlock()` के माध्यम से फोर्ज किया गया ब्लॉक सबमिट
2. ब्लॉक सत्यापित और चेन में जोड़ा गया
3. नेटवर्क सूचना: `GetMainSignals().BlockConnected()`
4. P2P परत peers को ब्लॉक प्रसारित करती है

**कार्यान्वयन:** मानक Bitcoin Core net_processing

### ब्लॉक रिले

**Compact Blocks (BIP 152):**
- कुशल ब्लॉक प्रसार के लिए उपयोग
- शुरू में केवल transaction IDs भेजे गए
- Peers लुप्त लेनदेन का अनुरोध करते हैं

**पूर्ण ब्लॉक रिले:**
- जब compact blocks विफल हों तो फ़ॉलबैक
- पूर्ण ब्लॉक डेटा प्रेषित

### चेन पुनर्गठन

**Reorg हैंडलिंग:**
```cpp
// forger वर्कर थ्रेड में
if (current_tip_hash != stored_tip_hash) {
    // चेन पुनर्गठन का पता चला
    reset_forging_state();
    log("Chain tip changed, resetting forging");
}
```

**ब्लॉकचेन-स्तर:**
- मानक Bitcoin Core reorg हैंडलिंग
- Chainwork द्वारा सर्वोत्तम चेन निर्धारित
- डिस्कनेक्ट किए गए ब्लॉक mempool में लौटाए गए

---

## तकनीकी विवरण

### डेडलॉक रोकथाम

**ABBA डेडलॉक पैटर्न (रोका गया):**
```
Thread A: cs_main → cs_wallet
Thread B: cs_wallet → cs_main
```

**समाधान:**
1. **submit_nonce:** शून्य cs_main उपयोग
   - `GetNewBlockContext()` आंतरिक रूप से लॉकिंग संभालता है
   - Forger सबमिशन से पहले सभी सत्यापन

2. **Forger:** कतार-आधारित आर्किटेक्चर
   - एकल वर्कर थ्रेड (कोई थ्रेड जॉइन नहीं)
   - प्रत्येक एक्सेस पर ताज़ा संदर्भ
   - कोई नेस्टेड लॉक नहीं

3. **वॉलेट जांच:** महंगे ऑपरेशन से पहले की जाती है
   - कोई कुंजी उपलब्ध नहीं होने पर जल्दी अस्वीकृति
   - ब्लॉकचेन स्थिति एक्सेस से अलग

### प्रदर्शन अनुकूलन

**फास्ट-फेल सत्यापन:**
```cpp
1. प्रारूप जांच (तत्काल)
2. संदर्भ सत्यापन (हल्का)
3. वॉलेट सत्यापन (स्थानीय)
4. प्रमाण सत्यापन (महंगा SIMD)
```

**एकल संदर्भ फ़ेच:**
- प्रति सबमिशन एक `GetNewBlockContext()` कॉल
- कई जांचों के लिए परिणाम कैश करें
- कोई दोहराया cs_main अधिग्रहण नहीं

**कतार दक्षता:**
- हल्की सबमिशन संरचना
- कतार में कोई base_target/deadline नहीं (ताज़ा पुनर्गणना)
- न्यूनतम मेमोरी फ़ुटप्रिंट

### Staleness हैंडलिंग

**"Stupid" Forger डिज़ाइन:**
- कोई ब्लॉकचेन ईवेंट सब्सक्रिप्शन नहीं
- जब आवश्यक हो तब आलसी सत्यापन
- Stale सबमिशन का मौन त्याग

**लाभ:**
- सरल आर्किटेक्चर
- कोई जटिल सिंक्रनाइज़ेशन नहीं
- एज केस के प्रति मज़बूत

**संभाले गए एज केस:**
- ऊंचाई परिवर्तन → त्याग
- Generation signature परिवर्तन → त्याग
- Base target परिवर्तन → deadline पुनर्गणना
- Reorgs → फोर्जिंग स्थिति रीसेट

### क्रिप्टोग्राफिक विवरण

**Generation Signature:**
```cpp
dSHA256(prev_generation_signature || prev_account_id_20bytes)
```

**ब्लॉक हस्ताक्षर हैश:**
```cpp
// Uses HashWriter (double-SHA256) with Bitcoin serialization (length-prefixed strings)
HashWriter hasher{};
hasher << POCX_BLOCK_MAGIC << block_hash.ToString();
hash = hasher.GetHash();  // double-SHA256
```

**कॉम्पैक्ट हस्ताक्षर प्रारूप:**
- 65 बाइट्स: [recovery_id][r][s]
- सार्वजनिक कुंजी पुनर्प्राप्ति की अनुमति देता है
- स्थान दक्षता के लिए उपयोग

**Account ID:**
- संपीड़ित सार्वजनिक कुंजी का 20-बाइट HASH160
- Bitcoin पता प्रारूपों से मेल खाता है (P2PKH, P2WPKH)

### भविष्य के संवर्द्धन

**दस्तावेज़ित सीमाएं:**
1. कोई प्रदर्शन मेट्रिक्स नहीं (सबमिशन दर, deadline वितरण)
2. माइनर्स के लिए कोई विस्तृत त्रुटि वर्गीकरण नहीं
3. सीमित forger स्थिति क्वेरीइंग (वर्तमान deadline, कतार गहराई)

**संभावित सुधार:**
- Forger स्थिति के लिए RPC
- माइनिंग दक्षता के लिए मेट्रिक्स
- डीबगिंग के लिए उन्नत लॉगिंग
- पूल प्रोटोकॉल समर्थन

---

## कोड संदर्भ

**कोर कार्यान्वयन:**
- RPC इंटरफ़ेस: `src/pocx/rpc/mining.cpp`
- Forger कतार: `src/pocx/mining/scheduler.cpp`
- सहमति सत्यापन: `src/pocx/consensus/proof.cpp`
- प्रमाण सत्यापन: `src/pocx/consensus/signature.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- ब्लॉक सत्यापन: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- असाइनमेंट लॉजिक: `src/pocx/assignments/assignment_state.cpp:GetEffectiveSigner()`
- संदर्भ प्रबंधन: `src/pocx/mining/block_context.cpp:GetNewBlockContext()`

**डेटा संरचनाएं:**
- ब्लॉक प्रारूप: `src/primitives/block.h`
- सहमति पैरामीटर: `src/consensus/params.h`
- असाइनमेंट ट्रैकिंग: `src/coins.h` (CCoinsViewCache एक्सटेंशन)

---

## परिशिष्ट: एल्गोरिथम विनिर्देश

### Time Bending सूत्र

**गणितीय परिभाषा:**
```
deadline_seconds = quality / base_target  (रॉ)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

जहां:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**कार्यान्वयन:**
- फिक्स्ड-पॉइंट अंकगणित (Q42 प्रारूप)
- पूर्णांक-केवल घन मूल गणना
- 256-bit अंकगणित के लिए अनुकूलित

### गुणवत्ता गणना

**प्रक्रिया:**
1. Generation signature और ऊंचाई से scoop उत्पन्न करें
2. गणना किए गए scoop के लिए plot डेटा पढ़ें
3. हैश: `Shabal256Lite(scoop_data, generation_signature)`
4. Min से max तक स्केलिंग स्तरों का परीक्षण करें
5. मिली सर्वोत्तम गुणवत्ता लौटाएं

**स्केलिंग:**
- स्तर X0: POC2 बेसलाइन (सैद्धांतिक)
- स्तर X1: XOR-transpose बेसलाइन
- स्तर Xn: 2^(n-1) × X1 कार्य एम्बेडेड
- उच्च स्केलिंग = अधिक plot जनरेशन कार्य

### Base Target समायोजन

**प्रत्येक ब्लॉक समायोजन:**
1. हाल के base targets के मूविंग एवरेज की गणना करें
2. रोलिंग विंडो के लिए वास्तविक timespan बनाम लक्ष्य timespan गणना करें
3. Base target को आनुपातिक रूप से समायोजित करें
4. अत्यधिक स्विंग रोकने के लिए क्लैंप करें

**सूत्र:**
```
avg_base_target = moving_average(recent base targets)

// Hybrid correction: wall-clock time adjusted by bended deadlines
actual_timespan = total_wait - Σ(bended_deadlines) + Σ(quality_adj)

adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, ±20% of prev_base_target)
```

---

*यह दस्तावेज़ीकरण अक्टूबर 2025 तक पूर्ण PoCX सहमति कार्यान्वयन को दर्शाता है।*

---

[← पिछला: Plot प्रारूप](2-plot-format.md) | [📘 विषय-सूची](index.md) | [अगला: फोर्जिंग असाइनमेंट →](4-forging-assignments.md)
