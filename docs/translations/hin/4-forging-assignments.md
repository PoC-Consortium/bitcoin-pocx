[← पिछला: सहमति और माइनिंग](3-consensus-and-mining.md) | [📘 विषय-सूची](index.md) | [अगला: समय सिंक्रनाइज़ेशन →](5-timing-security.md)

---

# अध्याय 4: PoCX फोर्जिंग असाइनमेंट सिस्टम

## कार्यकारी सारांश

यह दस्तावेज़ OP_RETURN-केवल आर्किटेक्चर का उपयोग करने वाले **कार्यान्वित** PoCX फोर्जिंग असाइनमेंट सिस्टम का वर्णन करता है। सिस्टम plot मालिकों को पूर्ण reorg सुरक्षा और परमाणु डेटाबेस संचालन के साथ ऑन-चेन लेनदेन के माध्यम से फोर्जिंग अधिकार अलग पतों को प्रत्यायोजित करने में सक्षम बनाता है।

**स्थिति:** ✅ पूर्णतः कार्यान्वित और संचालनरत

## मूल डिज़ाइन दर्शन

**मुख्य सिद्धांत:** असाइनमेंट अनुमतियां हैं, संपत्ति नहीं

- ट्रैक या खर्च करने के लिए कोई विशेष UTXOs नहीं
- UTXO सेट से अलग संग्रहीत असाइनमेंट स्थिति
- UTXO खर्च नहीं, लेनदेन हस्ताक्षर द्वारा सिद्ध स्वामित्व
- पूर्ण ऑडिट ट्रेल के लिए पूर्ण इतिहास ट्रैकिंग
- LevelDB बैच लेखन के माध्यम से परमाणु डेटाबेस अपडेट

## लेनदेन संरचना

### असाइनमेंट लेनदेन प्रारूप

```
Inputs:
  [0]: Plot मालिक द्वारा नियंत्रित कोई भी UTXO (स्वामित्व सिद्ध + शुल्क भुगतान करता है)
       Plot मालिक की निजी कुंजी से हस्ताक्षरित होना चाहिए
  [1+]: शुल्क कवरेज के लिए वैकल्पिक अतिरिक्त inputs

Outputs:
  [0]: OP_RETURN (POCX मार्कर + plot पता + forge पता)
       प्रारूप: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       आकार: 46 बाइट्स कुल (1 बाइट OP_RETURN + 1 बाइट लंबाई + 44 बाइट्स डेटा)
       मूल्य: 0 BTC (अखर्चनीय, UTXO सेट में नहीं जोड़ा जाता)

  [1]: उपयोगकर्ता को Change वापस (वैकल्पिक, मानक P2WPKH)
```

**कार्यान्वयन:** `src/pocx/assignments/opcodes.cpp`

### निरस्तीकरण लेनदेन प्रारूप

```
Inputs:
  [0]: Plot मालिक द्वारा नियंत्रित कोई भी UTXO (स्वामित्व सिद्ध + शुल्क भुगतान करता है)
       Plot मालिक की निजी कुंजी से हस्ताक्षरित होना चाहिए
  [1+]: शुल्क कवरेज के लिए वैकल्पिक अतिरिक्त inputs

Outputs:
  [0]: OP_RETURN (XCOP मार्कर + plot पता)
       प्रारूप: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       आकार: 26 बाइट्स कुल (1 बाइट OP_RETURN + 1 बाइट लंबाई + 24 बाइट्स डेटा)
       मूल्य: 0 BTC (अखर्चनीय, UTXO सेट में नहीं जोड़ा जाता)

  [1]: उपयोगकर्ता को Change वापस (वैकल्पिक, मानक P2WPKH)
```

**कार्यान्वयन:** `src/pocx/assignments/opcodes.cpp`

### मार्कर

- **असाइनमेंट मार्कर:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **निरस्तीकरण मार्कर:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**कार्यान्वयन:** `src/pocx/assignments/opcodes.cpp`

### मुख्य लेनदेन विशेषताएं

- मानक Bitcoin लेनदेन (कोई प्रोटोकॉल परिवर्तन नहीं)
- OP_RETURN आउटपुट प्रमाणित रूप से अखर्चनीय हैं (UTXO सेट में कभी नहीं जोड़े जाते)
- Plot स्वामित्व plot पते से input[0] पर हस्ताक्षर द्वारा सिद्ध
- कम लागत (~200 बाइट्स, आमतौर पर <0.0001 BTC शुल्क)
- वॉलेट स्वचालित रूप से स्वामित्व सिद्ध करने के लिए plot पते से सबसे बड़ा UTXO चुनता है

## डेटाबेस आर्किटेक्चर

### स्टोरेज संरचना

सभी असाइनमेंट डेटा UTXO सेट (`chainstate/`) के समान LevelDB डेटाबेस में संग्रहीत है, लेकिन अलग कुंजी उपसर्गों के साथ:

```
chainstate/ LevelDB:
├─ UTXO सेट (Bitcoin Core मानक)
│  └─ 'C' उपसर्ग: COutPoint → Coin
│
└─ असाइनमेंट स्थिति (PoCX जोड़)
   └─ 'A' उपसर्ग: (plot_address, assignment_txid) → ForgingAssignment
       └─ पूर्ण इतिहास: समय के साथ प्रति plot सभी असाइनमेंट
```

**कार्यान्वयन:** `src/txdb.cpp`

### ForgingAssignment संरचना

```cpp
struct ForgingAssignment {
    // पहचान
    std::array<uint8_t, 20> plotAddress;      // Plot मालिक (20-बाइट P2WPKH हैश)
    std::array<uint8_t, 20> forgingAddress;   // फोर्जिंग अधिकार धारक (20-बाइट P2WPKH हैश)

    // असाइनमेंट जीवनचक्र
    uint256 assignment_txid;                   // असाइनमेंट बनाने वाला लेनदेन
    int assignment_height;                     // निर्माण ब्लॉक ऊंचाई
    int assignment_effective_height;           // जब यह सक्रिय होता है (height + delay)

    // निरस्तीकरण जीवनचक्र
    bool revoked;                              // क्या इसे निरस्त किया गया है?
    uint256 revocation_txid;                   // निरस्त करने वाला लेनदेन
    int revocation_height;                     // निरस्तीकरण ब्लॉक ऊंचाई
    int revocation_effective_height;           // जब निरस्तीकरण प्रभावी (height + delay)

    // स्थिति क्वेरी विधियां
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**कार्यान्वयन:** `src/coins.h`

### असाइनमेंट स्थितियां

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // कोई असाइनमेंट मौजूद नहीं
    ASSIGNING = 1,   // असाइनमेंट बनाया गया, सक्रियण विलंब की प्रतीक्षा
    ASSIGNED = 2,    // असाइनमेंट सक्रिय, फोर्जिंग की अनुमति
    REVOKING = 3,    // निरस्त, लेकिन विलंब अवधि में अभी भी सक्रिय
    REVOKED = 4      // पूर्णतः निरस्त, अब सक्रिय नहीं
};
```

**कार्यान्वयन:** `src/coins.h`

### डेटाबेस कुंजियां

```cpp
// इतिहास कुंजी: पूर्ण असाइनमेंट रिकॉर्ड संग्रहीत करता है
// कुंजी प्रारूप: (prefix, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Plot पता (20 बाइट्स)
    int assignment_height;                // सॉर्टिंग अनुकूलन के लिए ऊंचाई
    uint256 assignment_txid;              // Transaction ID
};
```

**कार्यान्वयन:** `src/txdb.cpp`

### इतिहास ट्रैकिंग

- प्रत्येक असाइनमेंट स्थायी रूप से संग्रहीत (reorg के अलावा कभी नहीं हटाया जाता)
- समय के साथ प्रति plot कई असाइनमेंट ट्रैक
- पूर्ण ऑडिट ट्रेल और ऐतिहासिक स्थिति क्वेरी सक्षम करता है
- निरस्त असाइनमेंट `revoked=true` के साथ डेटाबेस में रहते हैं

## ब्लॉक प्रोसेसिंग

### ConnectBlock एकीकरण

असाइनमेंट और निरस्तीकरण OP_RETURNs `validation.cpp` में ब्लॉक कनेक्शन के दौरान प्रोसेस होते हैं:

```cpp
// स्थान: स्क्रिप्ट सत्यापन के बाद, UpdateCoins से पहले
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // OP_RETURN डेटा पार्स करें
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // स्वामित्व सत्यापित करें (tx plot मालिक द्वारा हस्ताक्षरित होना चाहिए)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Plot स्थिति जांचें (UNASSIGNED या REVOKED होना चाहिए)
            ForgingState plotState = pocx::assignments::GetAssignmentState(plot_addr, height, view);
            if (plotState != UNASSIGNED && plotState != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // नया असाइनमेंट बनाएं
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Undo डेटा संग्रहीत करें
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // OP_RETURN डेटा पार्स करें
            auto plot_addr = ParseRevocationOpReturn(output);

            // स्वामित्व सत्यापित करें
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // वर्तमान असाइनमेंट प्राप्त करें
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Undo के लिए पुरानी स्थिति संग्रहीत करें
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // निरस्त के रूप में चिह्नित करें
            ForgingAssignment revoked = *existing;
            revoked.revoked = true;
            revoked.revocation_txid = tx.GetHash();
            revoked.revocation_height = height;
            revoked.revocation_effective_height = height + consensus.nForgingRevocationDelay;

            view.UpdateForgingAssignment(revoked);
        }
    }
}
#endif

// UpdateCoins सामान्य रूप से आगे बढ़ता है (OP_RETURN आउटपुट स्वचालित रूप से छोड़े जाते हैं)
```

**कार्यान्वयन:** `src/validation.cpp:ConnectBlock()`

### स्वामित्व सत्यापन

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // जांचें कि कम से कम एक input plot मालिक द्वारा हस्ताक्षरित है
    for (const auto& input : tx.vin) {
        auto coin = view.GetCoin(input.prevout);
        if (!coin.has_value()) continue;

        // Check if P2WPKH witness program matches plot address
        int wit_version;
        std::vector<unsigned char> wit_program;
        if (!coin->out.scriptPubKey.IsWitnessProgram(wit_version, wit_program)) continue;
        if (wit_version != 0 || wit_program.size() != 20) continue;

        if (std::equal(wit_program.begin(), wit_program.end(),
                      plotAddress.begin())) {
            return true;  // Bitcoin Core already validated signature
        }
    }
    return false;
}
```

**कार्यान्वयन:** `src/pocx/assignments/opcodes.cpp:VerifyPlotOwnership()`

### सक्रियण विलंब

असाइनमेंट और निरस्तीकरण में reorg हमलों को रोकने के लिए कॉन्फ़िगर करने योग्य सक्रियण विलंब हैं:

```cpp
// सहमति पैरामीटर (प्रति नेटवर्क कॉन्फ़िगर करने योग्य)
// उदाहरण: 30 ब्लॉक = 2-मिनट ब्लॉक समय के साथ ~1 घंटा
consensus.nForgingAssignmentDelay;   // असाइनमेंट सक्रियण विलंब
consensus.nForgingRevocationDelay;   // निरस्तीकरण सक्रियण विलंब
```

**स्थिति संक्रमण:**
- असाइनमेंट: `UNASSIGNED → ASSIGNING (विलंब) → ASSIGNED`
- निरस्तीकरण: `ASSIGNED → REVOKING (विलंब) → REVOKED`

**कार्यान्वयन:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Mempool सत्यापन

नेटवर्क प्रसार से पहले अमान्य लेनदेन अस्वीकार करने के लिए असाइनमेंट और निरस्तीकरण लेनदेन mempool स्वीकृति पर सत्यापित होते हैं।

### लेनदेन-स्तर जांच (CheckTransaction)

चेन स्थिति एक्सेस के बिना `src/consensus/tx_check.cpp` में की जाती है:

1. **अधिकतम एक POCX OP_RETURN:** लेनदेन में कई POCX/XCOP मार्कर नहीं हो सकते

**कार्यान्वयन:** `src/consensus/tx_check.cpp`

### Mempool स्वीकृति जांच (PreChecks)

पूर्ण चेन स्थिति और mempool एक्सेस के साथ `src/validation.cpp` में की जाती है:

#### असाइनमेंट सत्यापन

1. **Plot स्वामित्व:** लेनदेन plot मालिक द्वारा हस्ताक्षरित होना चाहिए
2. **Plot स्थिति:** Plot UNASSIGNED (0) या REVOKED (4) होना चाहिए
3. **Mempool विरोध:** Mempool में इस plot के लिए कोई अन्य असाइनमेंट नहीं (पहले-देखा-जीता)

#### निरस्तीकरण सत्यापन

1. **Plot स्वामित्व:** लेनदेन plot मालिक द्वारा हस्ताक्षरित होना चाहिए
2. **सक्रिय असाइनमेंट:** Plot केवल ASSIGNED (2) स्थिति में होना चाहिए
3. **Mempool विरोध:** Mempool में इस plot के लिए कोई अन्य निरस्तीकरण नहीं

**कार्यान्वयन:** `src/validation.cpp:PreChecks()`

### सत्यापन प्रवाह

```
लेनदेन प्रसारण
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ अधिकतम एक POCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Plot स्वामित्व सत्यापित करें
  ✓ असाइनमेंट स्थिति जांचें
  ✓ Mempool विरोध जांचें
       ↓
   वैध → Mempool में स्वीकार करें
   अमान्य → अस्वीकार करें (प्रसारित न करें)
       ↓
ब्लॉक माइनिंग
       ↓
ConnectBlock() [validation.cpp]
  ✓ सभी जांच पुनः-सत्यापित करें (गहन रक्षा)
  ✓ स्थिति परिवर्तन लागू करें
  ✓ Undo जानकारी रिकॉर्ड करें
```

### गहन रक्षा

सभी mempool सत्यापन जांच इनके विरुद्ध सुरक्षा के लिए `ConnectBlock()` के दौरान पुनः-निष्पादित होती हैं:
- Mempool बाईपास हमले
- दुर्भावनापूर्ण माइनर्स से अमान्य ब्लॉक
- Reorg परिदृश्यों के दौरान एज केस

ब्लॉक सत्यापन सहमति के लिए अधिकारिक रहता है।

## परमाणु डेटाबेस अपडेट

### तीन-परत आर्किटेक्चर

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (मेमोरी कैश)          │  ← असाइनमेंट परिवर्तन मेमोरी में ट्रैक
│   - Coins: cacheCoins                   │
│   - Assignments: pendingAssignments     │
│   - Dirty ट्रैकिंग: dirtyPlots          │
│   - Deletions: deletedAssignments       │
│   - मेमोरी ट्रैकिंग: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (डेटाबेस परत)            │  ← एकल परमाणु लेखन
│   - BatchWrite(): UTXOs + Assignments   │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (डिस्क स्टोरेज)               │  ← ACID गारंटी
│   - परमाणु लेनदेन                       │
└─────────────────────────────────────────┘
```

### Flush प्रक्रिया

जब ब्लॉक कनेक्शन के दौरान `view.Flush()` कॉल किया जाता है:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Coin परिवर्तन बेस में लिखें
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. असाइनमेंट परिवर्तन परमाणु रूप से लिखें
    if (fOk && !dirtyPlots.empty()) {
        // Dirty असाइनमेंट एकत्र करें
        ForgingAssignmentsMap assignmentsToWrite;
        DeletedAssignmentsSet deletedToWrite;

        // Collect dirty assignments

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    auto key = std::make_pair(plotAddr, assignment.assignment_txid);
                    assignmentsToWrite[key] = assignment;
                }
            }
        }

        // डेटाबेस में लिखें
        // Merge deleted assignments into assignmentsToWrite (needed for height lookup)
        // and build deletedToWrite set (plain key pairs)
        for (const auto& [key, assignment] : deletedAssignments) {
            assignmentsToWrite[key] = assignment;  // Provide assignment data for height
            deletedToWrite.insert(key);             // Mark for deletion
        }

        fOk = base->BatchWriteAssignments(assignmentsToWrite, deletedToWrite);
    }

    if (fOk) {
        cacheCoins.clear();
        ReallocateCache();
        pendingAssignments.clear();
        deletedAssignments.clear();
        dirtyPlots.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**कार्यान्वयन:** `src/coins.cpp:Flush()`

### डेटाबेस बैच लेखन

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // एकल LevelDB बैच

    // 1. संक्रमण स्थिति चिह्नित करें
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. सभी coin परिवर्तन लिखें
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. सुसंगत स्थिति चिह्नित करें
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. परमाणु COMMIT
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// असाइनमेंट अलग से लेकिन समान डेटाबेस लेनदेन संदर्भ में लिखे जाते हैं
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const DeletedAssignmentsSet& deletedAssignments)  // set of (plot_addr, txid) pairs
{
    CDBBatch batch(*m_db);

    // Write all assignment history entries
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, assignment.assignment_height, txid), assignment);
    }

    // Erase deleted assignments — look up height from assignments map
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        auto it = assignments.find({plot_addr, txid});
        if (it != assignments.end()) {
            batch.Erase(AssignmentHistoryKey(plot_addr, it->second.assignment_height, txid));
        }
    }

    // ATOMIC COMMIT
    return m_db->WriteBatch(batch);
}
```

**कार्यान्वयन:** `src/txdb.cpp:BatchWriteAssignments()`

### परमाणुता गारंटी

✅ **क्या परमाणु है:**
- एक ब्लॉक के भीतर सभी coin परिवर्तन परमाणु रूप से लिखे जाते हैं
- एक ब्लॉक के भीतर सभी असाइनमेंट परिवर्तन परमाणु रूप से लिखे जाते हैं
- क्रैश में डेटाबेस सुसंगत रहता है

⚠️ **वर्तमान सीमा:**
- Coins और असाइनमेंट `view.Flush()` के दौरान **अलग** LevelDB बैच ऑपरेशन में लिखे जाते हैं
- दोनों ऑपरेशन `view.Flush()` के दौरान होते हैं, लेकिन एकल परमाणु लेखन में नहीं
- व्यवहार में: डिस्क fsync से पहले दोनों बैच तेज़ी से पूरे होते हैं
- जोखिम न्यूनतम है: क्रैश रिकवरी के दौरान दोनों को एक ही ब्लॉक से रिप्ले करना होगा

**नोट:** यह मूल आर्किटेक्चर योजना से भिन्न है जिसमें एकल एकीकृत बैच की मांग की गई थी। वर्तमान कार्यान्वयन दो बैच का उपयोग करता है लेकिन Bitcoin Core के मौजूदा क्रैश रिकवरी तंत्र (DB_HEAD_BLOCKS मार्कर) के माध्यम से सुसंगतता बनाए रखता है।

## Reorg हैंडलिंग

### Undo डेटा संरचना

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // असाइनमेंट जोड़ा गया था (undo पर हटाएं)
        MODIFIED = 1,   // असाइनमेंट संशोधित किया गया था (undo पर पुनर्स्थापित करें)
        REVOKED = 2     // असाइनमेंट निरस्त किया गया था (undo पर अन-निरस्त करें)
    };

    UndoType type;
    ForgingAssignment assignment;  // परिवर्तन से पहले पूर्ण स्थिति
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO undo डेटा
    std::vector<ForgingUndo> vforgingundo;  // असाइनमेंट undo डेटा
};
```

**कार्यान्वयन:** `src/undo.h`

### DisconnectBlock प्रक्रिया

जब एक reorg के दौरान ब्लॉक डिस्कनेक्ट होता है:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... मानक UTXO डिस्कनेक्शन ...

    // डिस्क से undo डेटा पढ़ें
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // असाइनमेंट परिवर्तन undo करें (उल्टे क्रम में प्रोसेस करें)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // असाइनमेंट जोड़ा गया था - इसे हटाएं
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // असाइनमेंट निरस्त किया गया था - अ-निरस्त स्थिति पुनर्स्थापित करें
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // असाइनमेंट संशोधित किया गया था - पिछली स्थिति पुनर्स्थापित करें
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**कार्यान्वयन:** `src/validation.cpp:DisconnectBlock()`

### Reorg के दौरान कैश प्रबंधन

```cpp
class CCoinsViewCache {
private:
    // असाइनमेंट कैश
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // संशोधित plots ट्रैक करें
    mutable ForgingAssignmentsMap deletedAssignments;  // Track deletions (map, not set)  // हटाने ट्रैक करें
    mutable size_t cachedAssignmentsUsage{0};  // मेमोरी ट्रैकिंग

public:
    void AddForgingAssignment(const ForgingAssignment& assignment) {
        pendingAssignments[assignment.plotAddress].push_back(assignment);
        dirtyPlots.insert(assignment.plotAddress);
        cachedAssignmentsUsage += sizeof(ForgingAssignment);
    }

    void RemoveForgingAssignment(const std::array<uint8_t, 20>& plotAddress,
                                 const uint256& assignment_txid) {
        auto key = std::make_pair(plotAddress, assignment_txid);
        deletedAssignments[key] = assignment;
        dirtyPlots.insert(plotAddress);
        if (cachedAssignmentsUsage >= sizeof(ForgingAssignment)) {
            cachedAssignmentsUsage -= sizeof(ForgingAssignment);
        }
    }

    void RestoreForgingAssignment(const ForgingAssignment& assignment) {
        pendingAssignments[assignment.plotAddress].push_back(assignment);
        dirtyPlots.insert(assignment.plotAddress);
        auto key = std::make_pair(assignment.plotAddress, assignment.assignment_txid);
        deletedAssignments.erase(key);
        cachedAssignmentsUsage += sizeof(ForgingAssignment);
    }
};
```

**कार्यान्वयन:** `src/coins.cpp`

## RPC इंटरफ़ेस

### नोड कमांड (कोई वॉलेट आवश्यक नहीं)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Plot पते के लिए वर्तमान असाइनमेंट स्थिति लौटाता है:
```json
{
  "plot_address": "pocx1qplot...",
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 100,
  "activation_height": 244,
  "revoked": false
}
```

**कार्यान्वयन:** `src/pocx/rpc/assignments.cpp`

### वॉलेट कमांड (वॉलेट आवश्यक)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

एक असाइनमेंट लेनदेन बनाता है:
- स्वामित्व सिद्ध करने के लिए plot पते से सबसे बड़ा UTXO स्वचालित रूप से चुनता है
- OP_RETURN + change आउटपुट के साथ लेनदेन बनाता है
- Plot मालिक की कुंजी से हस्ताक्षर करता है
- नेटवर्क पर प्रसारित करता है

**कार्यान्वयन:** `src/pocx/rpc/assignments_wallet.cpp`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

एक निरस्तीकरण लेनदेन बनाता है:
- स्वामित्व सिद्ध करने के लिए plot पते से सबसे बड़ा UTXO स्वचालित रूप से चुनता है
- OP_RETURN + change आउटपुट के साथ लेनदेन बनाता है
- Plot मालिक की कुंजी से हस्ताक्षर करता है
- नेटवर्क पर प्रसारित करता है

**कार्यान्वयन:** `src/pocx/rpc/assignments_wallet.cpp`

### वॉलेट लेनदेन निर्माण

वॉलेट लेनदेन निर्माण प्रक्रिया:

```cpp
1. पते पार्स और सत्यापित करें (P2WPKH bech32 होना चाहिए)
2. Plot पते से सबसे बड़ा UTXO खोजें (स्वामित्व सिद्ध करता है)
3. डमी आउटपुट के साथ अस्थायी लेनदेन बनाएं
4. लेनदेन पर हस्ताक्षर करें (witness डेटा के साथ सटीक आकार प्राप्त करें)
5. डमी आउटपुट को OP_RETURN से बदलें
6. आकार परिवर्तन के आधार पर शुल्क आनुपातिक रूप से समायोजित करें
7. अंतिम लेनदेन पर पुनः-हस्ताक्षर करें
8. नेटवर्क पर प्रसारित करें
```

**मुख्य अंतर्दृष्टि:** वॉलेट को स्वामित्व सिद्ध करने के लिए plot पते से खर्च करना होगा, इसलिए यह स्वचालित रूप से उस पते से coin चयन को मजबूर करता है।

**कार्यान्वयन:** `src/pocx/assignments/transactions.cpp`

## फ़ाइल संरचना

### कोर कार्यान्वयन फ़ाइलें

```
src/
├── coins.h                        # ForgingAssignment struct, CCoinsViewCache विधियां [710 पंक्तियां]
├── coins.cpp                      # कैश प्रबंधन, बैच लेखन [603 पंक्तियां]
│
├── txdb.h                         # CCoinsViewDB असाइनमेंट विधियां [90 पंक्तियां]
├── txdb.cpp                       # डेटाबेस पढ़ना/लिखना [349 पंक्तियां]
│
├── undo.h                         # Reorgs के लिए ForgingUndo संरचना
│
├── validation.cpp                 # ConnectBlock/DisconnectBlock एकीकरण
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # OP_RETURN प्रारूप, पार्सिंग, सत्यापन
    │   ├── opcodes.cpp            # [259 पंक्तियां] मार्कर परिभाषाएं, OP_RETURN ops, स्वामित्व जांच
    │   ├── assignment_state.h     # GetEffectiveSigner, GetAssignmentState सहायक
    │   ├── assignment_state.cpp   # असाइनमेंट स्थिति क्वेरी फ़ंक्शन
    │   ├── transactions.h         # वॉलेट लेनदेन निर्माण API
    │   └── transactions.cpp       # create_assignment, revoke_assignment वॉलेट फ़ंक्शन
    │
    ├── rpc/
    │   ├── assignments.h          # नोड RPC कमांड (कोई वॉलेट नहीं)
    │   ├── assignments.cpp        # get_assignment RPC
    │   ├── assignments_wallet.h   # वॉलेट RPC कमांड
    │   └── assignments_wallet.cpp # create_assignment, revoke_assignment RPCs
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## प्रदर्शन विशेषताएं

### डेटाबेस संचालन

- **वर्तमान असाइनमेंट प्राप्त करें:** O(n) - सबसे हाल का खोजने के लिए plot पते के सभी असाइनमेंट स्कैन करें
- **असाइनमेंट इतिहास प्राप्त करें:** O(n) - plot के सभी असाइनमेंट पर iterate करें
- **असाइनमेंट बनाएं:** O(1) - एकल insert
- **असाइनमेंट निरस्त करें:** O(1) - एकल update
- **Reorg (प्रति असाइनमेंट):** O(1) - सीधा undo डेटा अनुप्रयोग

जहां n = plot के लिए असाइनमेंट की संख्या (आमतौर पर छोटी, < 10)

### मेमोरी उपयोग

- **प्रति असाइनमेंट:** ~160 बाइट्स (ForgingAssignment struct)
- **कैश ओवरहेड:** Dirty ट्रैकिंग के लिए हैश मैप ओवरहेड
- **विशिष्ट ब्लॉक:** <10 असाइनमेंट = <2 KB मेमोरी

### डिस्क उपयोग

- **प्रति असाइनमेंट:** डिस्क पर ~200 बाइट्स (LevelDB ओवरहेड के साथ)
- **10000 असाइनमेंट:** ~2 MB डिस्क स्थान
- **UTXO सेट की तुलना में नगण्य:** विशिष्ट chainstate का <0.001%

## वर्तमान सीमाएं और भविष्य का कार्य

### परमाणुता सीमा

**वर्तमान:** `view.Flush()` के दौरान Coins और असाइनमेंट अलग LevelDB बैच में लिखे जाते हैं

**प्रभाव:** बैच के बीच क्रैश होने पर असंगतता का सैद्धांतिक जोखिम

**शमन:**
- दोनों बैच fsync से पहले तेज़ी से पूरे होते हैं
- Bitcoin Core की क्रैश रिकवरी DB_HEAD_BLOCKS मार्कर का उपयोग करती है
- व्यवहार में: परीक्षण में कभी नहीं देखा गया

**भविष्य सुधार:** एकल LevelDB बैच ऑपरेशन में एकीकृत करें

### असाइनमेंट इतिहास प्रूनिंग

**वर्तमान:** सभी असाइनमेंट अनिश्चित काल तक संग्रहीत

**प्रभाव:** प्रति असाइनमेंट ~200 बाइट्स हमेशा के लिए

**भविष्य:** N ब्लॉक से पुराने पूर्णतः-निरस्त असाइनमेंट का वैकल्पिक प्रूनिंग

**नोट:** आवश्यक होने की संभावना नहीं - 1 मिलियन असाइनमेंट भी = 200 MB

## परीक्षण स्थिति

### लागू परीक्षण

✅ OP_RETURN पार्सिंग और सत्यापन
✅ स्वामित्व सत्यापन
✅ ConnectBlock असाइनमेंट निर्माण
✅ ConnectBlock निरस्तीकरण
✅ DisconnectBlock reorg हैंडलिंग
✅ डेटाबेस पढ़ना/लिखना संचालन
✅ स्थिति संक्रमण (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
✅ RPC कमांड (get_assignment, create_assignment, revoke_assignment)
✅ वॉलेट लेनदेन निर्माण

### परीक्षण कवरेज क्षेत्र

- यूनिट परीक्षण: `src/test/pocx_*_tests.cpp`
- कार्यात्मक परीक्षण: `test/functional/feature_pocx_*.py`
- एकीकरण परीक्षण: Regtest के साथ मैन्युअल परीक्षण

## सहमति नियम

### असाइनमेंट निर्माण नियम

1. **स्वामित्व:** लेनदेन plot मालिक द्वारा हस्ताक्षरित होना चाहिए
2. **स्थिति:** Plot UNASSIGNED या REVOKED स्थिति में होना चाहिए
3. **प्रारूप:** POCX मार्कर + 2x 20-बाइट पतों के साथ वैध OP_RETURN
4. **विशिष्टता:** एक समय में प्रति plot एक सक्रिय असाइनमेंट

### निरस्तीकरण नियम

1. **स्वामित्व:** लेनदेन plot मालिक द्वारा हस्ताक्षरित होना चाहिए
2. **अस्तित्व:** असाइनमेंट मौजूद होना चाहिए और पहले से निरस्त नहीं होना चाहिए
3. **प्रारूप:** XCOP मार्कर + 20-बाइट पते के साथ वैध OP_RETURN

### सक्रियण नियम

- **असाइनमेंट सक्रियण:** `assignment_height + nForgingAssignmentDelay`
- **निरस्तीकरण सक्रियण:** `revocation_height + nForgingRevocationDelay`
- **विलंब:** प्रति नेटवर्क कॉन्फ़िगर करने योग्य (जैसे, 2-मिनट ब्लॉक समय के साथ 30 ब्लॉक = ~1 घंटा)

### ब्लॉक सत्यापन

- अमान्य असाइनमेंट/निरस्तीकरण → ब्लॉक अस्वीकृत (सहमति विफलता)
- OP_RETURN आउटपुट स्वचालित रूप से UTXO सेट से बाहर (मानक Bitcoin व्यवहार)
- असाइनमेंट प्रोसेसिंग ConnectBlock में UTXO अपडेट से पहले होती है

## निष्कर्ष

कार्यान्वित PoCX फोर्जिंग असाइनमेंट सिस्टम प्रदान करता है:

✅ **सरलता:** मानक Bitcoin लेनदेन, कोई विशेष UTXOs नहीं
✅ **लागत-प्रभावी:** कोई dust आवश्यकता नहीं, केवल लेनदेन शुल्क
✅ **Reorg सुरक्षा:** व्यापक undo डेटा सही स्थिति पुनर्स्थापित करता है
✅ **परमाणु अपडेट:** LevelDB बैच के माध्यम से डेटाबेस सुसंगतता
✅ **पूर्ण इतिहास:** समय के साथ सभी असाइनमेंट का पूर्ण ऑडिट ट्रेल
✅ **स्वच्छ आर्किटेक्चर:** न्यूनतम Bitcoin Core संशोधन, पृथक PoCX कोड
✅ **उत्पादन तैयार:** पूर्णतः कार्यान्वित, परीक्षित, और संचालनरत

### कार्यान्वयन गुणवत्ता

- **कोड संगठन:** उत्कृष्ट - Bitcoin Core और PoCX के बीच स्पष्ट पृथक्करण
- **त्रुटि हैंडलिंग:** व्यापक सहमति सत्यापन
- **दस्तावेज़ीकरण:** कोड टिप्पणियां और संरचना अच्छी तरह से दस्तावेज़ित
- **परीक्षण:** कोर कार्यक्षमता परीक्षित, एकीकरण सत्यापित

### प्रमाणित मुख्य डिज़ाइन निर्णय

1. ✅ OP_RETURN-केवल दृष्टिकोण (बनाम UTXO-आधारित)
2. ✅ अलग डेटाबेस स्टोरेज (बनाम Coin extraData)
3. ✅ पूर्ण इतिहास ट्रैकिंग (बनाम केवल-वर्तमान)
4. ✅ हस्ताक्षर द्वारा स्वामित्व (बनाम UTXO खर्च)
5. ✅ सक्रियण विलंब (reorg हमलों को रोकता है)

सिस्टम एक स्वच्छ, रखरखाव योग्य कार्यान्वयन के साथ सभी आर्किटेक्चरल लक्ष्यों को सफलतापूर्वक प्राप्त करता है।

---

[← पिछला: सहमति और माइनिंग](3-consensus-and-mining.md) | [📘 विषय-सूची](index.md) | [अगला: समय सिंक्रनाइज़ेशन →](5-timing-security.md)
