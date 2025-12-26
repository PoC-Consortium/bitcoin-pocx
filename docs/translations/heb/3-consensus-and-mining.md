[← הקודם: פורמט Plot](2-plot-format.md) | [📘 תוכן העניינים](index.md) | [הבא: הקצאות כרייה →](4-forging-assignments.md)

---

# פרק 3: קונצנזוס ותהליך כרייה של Bitcoin-PoCX

מפרט טכני מלא של מנגנון קונצנזוס PoCX (Proof of Capacity neXt generation) ותהליך הכרייה המשולב ב-Bitcoin Core.

---

## תוכן העניינים

1. [סקירה](#סקירה)
2. [ארכיטקטורת קונצנזוס](#ארכיטקטורת-קונצנזוס)
3. [תהליך כרייה](#תהליך-כרייה)
4. [אימות בלוק](#אימות-בלוק)
5. [מערכת הקצאות](#מערכת-הקצאות)
6. [הפצת רשת](#הפצת-רשת)
7. [פרטים טכניים](#פרטים-טכניים)

---

## סקירה

Bitcoin-PoCX מיישם מנגנון קונצנזוס טהור של Proof of Capacity כתחליף מלא ל-Proof of Work של Bitcoin. זוהי שרשרת חדשה ללא דרישות תאימות לאחור.

**תכונות מפתח:**
- **יעיל אנרגטית:** הכרייה משתמשת בקובצי plot מיוצרים מראש במקום hashing חישובי
- **Deadlines עם עיקום זמן:** טרנספורמציית התפלגות (מעריכית→כי-ריבוע) מפחיתה בלוקים ארוכים, משפרת זמני בלוק ממוצעים
- **תמיכת הקצאות:** בעלי plots יכולים להאציל זכויות כרייה לכתובות אחרות
- **אינטגרציית C++ טבעית:** אלגוריתמים קריפטוגרפיים מיושמים ב-C++ לאימות קונצנזוס

**זרימת כרייה:**
```
כורה חיצוני → get_mining_info → חישוב Nonce → submit_nonce →
תור כרייה → המתנת Deadline → כריית בלוק → הפצת רשת →
אימות בלוק → הרחבת שרשרת
```

---

## ארכיטקטורת קונצנזוס

### מבנה בלוק

בלוקי PoCX מרחיבים את מבנה הבלוק של Bitcoin עם שדות קונצנזוס נוספים:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Seed של plot (32 בתים)
    std::array<uint8_t, 20> account_id;       // כתובת plot (hash160 של 20 בתים)
    uint32_t compression;                     // רמת סילום (1-255)
    uint64_t nonce;                           // Nonce כרייה (64-bit)
    uint64_t quality;                         // איכות מוצהרת (פלט hash של PoC)
};

class CBlockHeader {
    // שדות Bitcoin סטנדרטיים
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // שדות קונצנזוס PoCX (מחליפים nBits ו-nNonce)
    int nHeight;                              // גובה בלוק (אימות ללא הקשר)
    uint256 generationSignature;              // חתימת יצירה (אנטרופיית כרייה)
    uint64_t nBaseTarget;                     // פרמטר קושי (קושי הפוך)
    PoCXProof pocxProof;                      // הוכחת כרייה

    // שדות חתימת בלוק
    std::array<uint8_t, 33> vchPubKey;        // מפתח ציבורי דחוס (33 בתים)
    std::array<uint8_t, 65> vchSignature;     // חתימה קומפקטית (65 בתים)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // עסקאות
};
```

**הערה:** החתימה (`vchSignature`) מוחרגת מחישוב hash הבלוק למניעת גמישות.

**יישום:** `src/primitives/block.h`

### חתימת יצירה

חתימת היצירה יוצרת אנטרופיית כרייה ומונעת התקפות חישוב מראש.

**חישוב:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**בלוק בראשית:** משתמש בחתימת יצירה ראשונית קבועה בקוד

**יישום:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Base Target (קושי)

Base target הוא ההפוך של קושי - ערכים גבוהים יותר משמעותם כרייה קלה יותר.

**אלגוריתם התאמה:**
- זמן בלוק יעד: 120 שניות (mainnet), שנייה אחת (regtest)
- מרווח התאמה: כל בלוק
- משתמש בממוצע נע של base targets אחרונים
- מוגבל למניעת תנודות קושי קיצוניות

**יישום:** `src/consensus/params.h`, לוגיקת התאמת קושי ביצירת בלוק

### רמות סילום

PoCX תומך ב-proof-of-work מדורג בקובצי plot דרך רמות סילום (Xn).

**גבולות דינמיים:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // רמה מינימלית מתקבלת
    uint8_t nPoCXTargetCompression;  // רמה מומלצת
};
```

**לוח זמנים להגדלת סילום:**
- מרווחים מעריכיים: שנים 4, 12, 28, 60, 124 (חצאיות 1, 3, 7, 15, 31)
- רמת סילום מינימלית עולה ב-1
- רמת סילום יעד עולה ב-1
- שומר על מרווח בטיחות בין עלויות יצירת plot לעלויות חיפוש
- רמת סילום מקסימלית: 255

**יישום:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## תהליך כרייה

### 1. אחזור מידע כרייה

**פקודת RPC:** `get_mining_info`

**תהליך:**
1. קרא ל-`GetNewBlockContext(chainman)` לאחזור מצב blockchain נוכחי
2. חשב גבולות דחיסה דינמיים לגובה הנוכחי
3. החזר פרמטרי כרייה

**תשובה:**
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

**יישום:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**הערות:**
- אין נעילות מוחזקות במהלך יצירת התשובה
- רכישת הקשר מטפלת ב-`cs_main` פנימית
- `block_hash` נכלל לעיון אך לא משמש באימות

### 2. כרייה חיצונית

**אחריות הכורה החיצוני:**
1. קרא קובצי plot מהדיסק
2. חשב scoop על בסיס חתימת יצירה וגובה
3. מצא nonce עם ה-deadline הטוב ביותר
4. הגש לצומת דרך `submit_nonce`

**פורמט קובץ Plot:**
- מבוסס על פורמט POC2 (Burstcoin)
- משופר עם תיקוני אבטחה ושיפורי מדרוגיות
- ראו ייחוס ב-`CLAUDE.md`

**יישום כורה:** חיצוני (למשל, מבוסס על Scavenger)

### 3. הגשת Nonce ואימות

**פקודת RPC:** `submit_nonce`

**פרמטרים:**
```
height, generation_signature, account_id, seed, nonce, quality (אופציונלי)
```

**זרימת אימות (סדר מותאם):**

#### שלב 1: אימות פורמט מהיר
```cpp
// Account ID: 40 תווי hex = 20 בתים
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 תווי hex = 32 בתים
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### שלב 2: רכישת הקשר
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// מחזיר: height, generation_signature, base_target, block_hash
```

**נעילה:** `cs_main` מטופל פנימית, אין נעילות מוחזקות ב-thread RPC

#### שלב 3: אימות הקשר
```cpp
// בדיקת גובה
if (height != context.height) reject;

// בדיקת חתימת יצירה
if (submitted_gen_sig != context.generation_signature) reject;
```

#### שלב 4: אימות ארנק
```cpp
// קבע חותם אפקטיבי (בהתחשב בהקצאות)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// בדוק אם לצומת יש מפתח פרטי לחותם האפקטיבי
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**תמיכת הקצאות:** בעל plot עשוי להקצות זכויות כרייה לכתובת אחרת. הארנק חייב להחזיק במפתח לחותם האפקטיבי, לא בהכרח לבעל ה-plot.

#### שלב 5: אימות הוכחה
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 בתים
    block_height,
    nonce,
    seed,                // 32 בתים
    min_compression,
    max_compression,
    &result             // פלט: quality, deadline
);
```

**אלגוריתם:**
1. פענח חתימת יצירה מ-hex
2. חשב את האיכות הטובה ביותר בטווח דחיסה באמצעות אלגוריתמים מותאמי SIMD
3. אמת שהאיכות עומדת בדרישות קושי
4. החזר ערך איכות גולמי

**יישום:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### שלב 6: חישוב עיקום זמן
```cpp
// Deadline גולמי מותאם קושי (שניות)
uint64_t deadline_seconds = quality / base_target;

// זמן כרייה עם עיקום זמן (שניות)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**נוסחת עיקום זמן:**
```
Y = scale * (X^(1/3))
כאשר:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**מטרה:** טרנספורמציה מהתפלגות מעריכית לכי-ריבוע. פתרונות טובים מאוד מתכווצים מאוחר יותר (לרשת יש זמן לסרוק דיסקים), פתרונות גרועים משופרים. מפחית בלוקים ארוכים, שומר על ממוצע 120 שניות.

**יישום:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### שלב 7: הגשה לכורה
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // לא deadline - מחושב מחדש בכורה
    height,
    generation_signature
);
```

**עיצוב מבוסס תור:**
- הגשה תמיד מצליחה (נוספת לתור)
- RPC חוזר מיד
- Thread עובד מעבד באופן אסינכרוני

**יישום:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. עיבוד תור כרייה

**ארכיטקטורה:**
- Thread עובד יחיד מתמיד
- תור הגשות FIFO
- מצב כרייה ללא נעילה (thread עובד בלבד)
- ללא נעילות מקוננות (מניעת קיפאון)

**לולאה ראשית של Thread עובד:**
```cpp
while (!shutdown) {
    // 1. בדוק הגשות בתור
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. המתן ל-deadline או הגשה חדשה
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**לוגיקת ProcessSubmission:**
```cpp
1. קבל הקשר טרי: GetNewBlockContext(*chainman)

2. בדיקות התיישנות (ביטול שקט):
   - חוסר התאמה בגובה → ביטול
   - חוסר התאמה בחתימת יצירה → ביטול
   - Hash בלוק קצה השתנה (reorg) → איפוס מצב כרייה

3. השוואת איכות:
   - אם quality >= current_best → ביטול

4. חשב deadline עם עיקום זמן:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. עדכן מצב כרייה:
   - בטל כרייה קיימת (אם נמצא טוב יותר)
   - אחסן: account_id, seed, nonce, quality, deadline
   - חשב: forge_time = block_time + deadline_seconds
   - אחסן tip hash לזיהוי reorg
```

**יישום:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. המתנת Deadline וכריית בלוק

**WaitForDeadlineOrNewSubmission:**

**תנאי המתנה:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**כאשר Deadline מגיע - אימות הקשר טרי:**
```cpp
1. קבל הקשר נוכחי: GetNewBlockContext(*chainman)

2. אימות גובה:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. אימות חתימת יצירה:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. מקרה קצה base target:
   if (forging_base_target != current_base_target) {
       // חשב מחדש deadline עם base target חדש
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // המתן שוב
   }

5. הכל תקף → ForgeBlock()
```

**תהליך ForgeBlock:**

```cpp
1. קבע חותם אפקטיבי (תמיכת הקצאות):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. צור סקריפט coinbase:
   coinbase_script = P2WPKH(effective_signer);  // משלם לחותם אפקטיבי

3. צור תבנית בלוק:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. הוסף הוכחת PoCX:
   block.pocxProof.account_id = plot_address;    // כתובת plot מקורית
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. חשב מחדש שורש merkle:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. חתום על בלוק:
   // השתמש במפתח החותם האפקטיבי (עשוי להיות שונה מבעל plot)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. הגש לשרשרת:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. טיפול בתוצאה:
   if (accepted) {
       log_success();
       reset_forging_state();  // מוכן לבלוק הבא
   } else {
       log_failure();
       reset_forging_state();
   }
```

**יישום:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**החלטות עיצוב מפתח:**
- Coinbase משלם לחותם אפקטיבי (מכבד הקצאות)
- ההוכחה מכילה כתובת plot מקורית (לאימות)
- חתימה ממפתח החותם האפקטיבי (הוכחת בעלות)
- יצירת תבנית כוללת עסקאות mempool אוטומטית

---

## אימות בלוק

### זרימת אימות בלוק נכנס

כאשר בלוק מתקבל מהרשת או מוגש מקומית, הוא עובר אימות במספר שלבים:

### שלב 1: אימות כותרת (CheckBlockHeader)

**אימות ללא הקשר:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**אימות PoCX (כאשר ENABLE_POCX מוגדר):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // אימות חתימה בסיסי (ללא תמיכת הקצאות עדיין)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**אימות חתימה בסיסי:**
1. בדוק נוכחות שדות pubkey וחתימה
2. אמת גודל pubkey (33 בתים דחוס)
3. אמת גודל חתימה (65 בתים קומפקטי)
4. שחזר pubkey מחתימה: `pubkey.RecoverCompact(hash, signature)`
5. אמת ש-pubkey משוחזר תואם ל-pubkey מאוחסן

**יישום:** `src/validation.cpp:CheckBlockHeader()`
**לוגיקת חתימה:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### שלב 2: אימות בלוק (CheckBlock)

**מאמת:**
- נכונות שורש merkle
- תקפות עסקאות
- דרישות coinbase
- מגבלות גודל בלוק
- כללי קונצנזוס Bitcoin סטנדרטיים

**יישום:** `src/consensus/validation.cpp:CheckBlock()`

### שלב 3: אימות כותרת הקשרי (ContextualCheckBlockHeader)

**אימות ספציפי ל-PoCX:**

```cpp
#ifdef ENABLE_POCX
    // שלב 1: אמת חתימת יצירה
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // שלב 2: אמת base target
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // שלב 3: אמת proof of capacity
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

    // שלב 4: אמת תזמון deadline
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**שלבי אימות:**
1. **חתימת יצירה:** חייבת להתאים לערך מחושב מבלוק קודם
2. **Base Target:** חייב להתאים לחישוב התאמת קושי
3. **רמת סילום:** חייבת לעמוד במינימום רשת (`compression >= min_compression`)
4. **טענת איכות:** איכות מוגשת חייבת להתאים לאיכות מחושבת מההוכחה
5. **Proof of Capacity:** אימות הוכחה קריפטוגרפי (מותאם SIMD)
6. **תזמון Deadline:** deadline עם עיקום זמן (`poc_time`) חייב להיות ≤ זמן שעבר

**יישום:** `src/validation.cpp:ContextualCheckBlockHeader()`

### שלב 4: חיבור בלוק (ConnectBlock)

**אימות הקשרי מלא:**

```cpp
#ifdef ENABLE_POCX
    // אימות חתימה מורחב עם תמיכת הקצאות
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**אימות חתימה מורחב:**
1. בצע אימות חתימה בסיסי
2. חלץ account ID מ-pubkey משוחזר
3. קבל חותם אפקטיבי לכתובת plot: `GetEffectiveSigner(plot_address, height, view)`
4. אמת שחשבון pubkey תואם לחותם אפקטיבי

**לוגיקת הקצאה:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // החזר חותם מוקצה
    }

    return plotAddress;  // אין הקצאה - בעל plot חותם
}
```

**יישום:**
- חיבור: `src/validation.cpp:ConnectBlock()`
- אימות מורחב: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- לוגיקת הקצאה: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### שלב 5: הפעלת שרשרת

**זרימת ProcessNewBlock:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → אימות ואחסון לדיסק
    2. ActivateBestChain → עדכון קצה שרשרת אם זו השרשרת הטובה ביותר
    3. הודע לרשת על בלוק חדש
}
```

**יישום:** `src/validation.cpp:ProcessNewBlock()`

### סיכום אימות

**נתיב אימות מלא:**
```
קבלת בלוק
    ↓
CheckBlockHeader (חתימה בסיסית)
    ↓
CheckBlock (עסקאות, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, base target, הוכחת PoC, deadline)
    ↓
ConnectBlock (חתימה מורחבת עם הקצאות, מעברי מצב)
    ↓
ActivateBestChain (טיפול ב-reorg, הרחבת שרשרת)
    ↓
הפצת רשת
```

---

## מערכת הקצאות

### סקירה

הקצאות מאפשרות לבעלי plots להאציל זכויות כרייה לכתובות אחרות תוך שמירה על בעלות plot.

**מקרי שימוש:**
- כריית בריכה (plots מוקצים לכתובת בריכה)
- אחסון קר (מפתח כרייה נפרד מבעלות plot)
- כרייה רב-צדדית (תשתית משותפת)

### ארכיטקטורת הקצאות

**עיצוב OP_RETURN בלבד:**
- הקצאות מאוחסנות בפלטי OP_RETURN (לא UTXO)
- אין דרישות הוצאה (אין dust, אין עמלות להחזקה)
- נעקב ב-CCoinsViewCache במצב מורחב
- מופעל לאחר תקופת עיכוב (ברירת מחדל: 4 בלוקים)

**מצבי הקצאה:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // אין הקצאה קיימת
    ASSIGNING = 1,   // הקצאה ממתינה להפעלה (תקופת עיכוב)
    ASSIGNED = 2,    // הקצאה פעילה, כרייה מותרת
    REVOKING = 3,    // ביטול ממתין (תקופת עיכוב, עדיין פעיל)
    REVOKED = 4      // ביטול הושלם, הקצאה כבר לא פעילה
};
```

### יצירת הקצאות

**פורמט עסקה:**
```cpp
Transaction {
    inputs: [any]  // מוכיח בעלות על כתובת plot
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**כללי אימות:**
1. קלט חייב להיות חתום על ידי בעל plot (מוכיח בעלות)
2. OP_RETURN מכיל נתוני הקצאה תקפים
3. Plot חייב להיות UNASSIGNED או REVOKED
4. אין הקצאות ממתינות כפולות ב-mempool
5. עמלת עסקה מינימלית שולמה

**הפעלה:**
- הקצאה הופכת ל-ASSIGNING בגובה אישור
- הופכת ל-ASSIGNED לאחר תקופת עיכוב (4 בלוקים regtest, 30 בלוקים mainnet)
- עיכוב מונע הקצאות מחדש מהירות במהלך מרוצי בלוקים

**יישום:** `src/script/forging_assignment.h`, אימות ב-ConnectBlock

### ביטול הקצאות

**פורמט עסקה:**
```cpp
Transaction {
    inputs: [any]  // מוכיח בעלות על כתובת plot
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**אפקט:**
- מעבר מצב מיידי ל-REVOKED
- בעל plot יכול לכרות מיד
- ניתן ליצור הקצאה חדשה לאחר מכן

### אימות הקצאות במהלך כרייה

**קביעת חותם אפקטיבי:**
```cpp
// באימות submit_nonce
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// בכריית בלוק
coinbase_script = P2WPKH(effective_signer);  // הפרס הולך לכאן

// בחתימת בלוק
signature = effective_signer_key.SignCompact(hash);  // חייב לחתום עם חותם אפקטיבי
```

**אימות בלוק:**
```cpp
// ב-VerifyPoCXBlockCompactSignature (מורחב)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**תכונות מפתח:**
- הוכחה תמיד מכילה כתובת plot מקורית
- חתימה חייבת להיות מחותם אפקטיבי
- Coinbase משלם לחותם אפקטיבי
- אימות משתמש במצב הקצאה בגובה בלוק

---

## הפצת רשת

### הכרזת בלוק

**פרוטוקול P2P Bitcoin סטנדרטי:**
1. בלוק שנכרה מוגש דרך `ProcessNewBlock()`
2. בלוק מאומת ומתווסף לשרשרת
3. הודעת רשת: `GetMainSignals().BlockConnected()`
4. שכבת P2P משדרת בלוק לעמיתים

**יישום:** net_processing Bitcoin Core סטנדרטי

### שידור בלוק

**Compact Blocks (BIP 152):**
- משמש להפצת בלוקים יעילה
- רק מזהי עסקאות נשלחים תחילה
- עמיתים מבקשים עסקאות חסרות

**שידור בלוק מלא:**
- גיבוי כאשר compact blocks נכשלים
- נתוני בלוק מלאים מועברים

### ארגונים מחדש של שרשרת

**טיפול ב-Reorg:**
```cpp
// ב-thread עובד כורה
if (current_tip_hash != stored_tip_hash) {
    // זוהה ארגון מחדש של שרשרת
    reset_forging_state();
    log("Chain tip changed, resetting forging");
}
```

**ברמת Blockchain:**
- טיפול reorg Bitcoin Core סטנדרטי
- שרשרת טובה ביותר נקבעת לפי chainwork
- בלוקים מנותקים חוזרים ל-mempool

---

## פרטים טכניים

### מניעת קיפאון

**דפוס קיפאון ABBA (נמנע):**
```
Thread A: cs_main → cs_wallet
Thread B: cs_wallet → cs_main
```

**פתרון:**
1. **submit_nonce:** אפס שימוש ב-cs_main
   - `GetNewBlockContext()` מטפל בנעילה פנימית
   - כל האימות לפני הגשה לכורה

2. **כורה:** ארכיטקטורה מבוססת תור
   - Thread עובד יחיד (ללא צירופי threads)
   - הקשר טרי בכל גישה
   - ללא נעילות מקוננות

3. **בדיקות ארנק:** מבוצעות לפני פעולות יקרות
   - דחייה מוקדמת אם אין מפתח זמין
   - נפרד מגישה למצב blockchain

### אופטימיזציות ביצועים

**אימות Fail-Fast:**
```cpp
1. בדיקות פורמט (מיידיות)
2. אימות הקשר (קל)
3. אימות ארנק (מקומי)
4. אימות הוכחה (SIMD יקר)
```

**אחזור הקשר יחיד:**
- קריאת `GetNewBlockContext()` אחת להגשה
- שמירת תוצאות לבדיקות מרובות
- ללא רכישות cs_main חוזרות

**יעילות תור:**
- מבנה הגשה קל
- אין base_target/deadline בתור (מחושב מחדש טרי)
- טביעת רגל זיכרון מינימלית

### טיפול בהתיישנות

**עיצוב כורה "טיפש":**
- אין הרשמות לאירועי blockchain
- אימות עצל כשנדרש
- ביטולים שקטים של הגשות מיושנות

**יתרונות:**
- ארכיטקטורה פשוטה
- ללא סנכרון מורכב
- עמיד למקרי קצה

**מקרי קצה מטופלים:**
- שינויי גובה → ביטול
- שינויי חתימת יצירה → ביטול
- שינויי base target → חשב מחדש deadline
- Reorgs → איפוס מצב כרייה

### פרטים קריפטוגרפיים

**חתימת יצירה:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Hash חתימת בלוק:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**פורמט חתימה קומפקטית:**
- 65 בתים: [recovery_id][r][s]
- מאפשר שחזור מפתח ציבורי
- משמש ליעילות מקום

**Account ID:**
- HASH160 של 20 בתים של מפתח ציבורי דחוס
- תואם לפורמטים של כתובות Bitcoin (P2PKH, P2WPKH)

### שיפורים עתידיים

**מגבלות מתועדות:**
1. אין מטריקות ביצועים (קצבי הגשה, התפלגויות deadline)
2. אין קטגוריזציה מפורטת של שגיאות לכורים
3. שאילתות מוגבלות של מצב כורה (deadline נוכחי, עומק תור)

**שיפורים פוטנציאליים:**
- RPC למצב כורה
- מטריקות ליעילות כרייה
- לוגים משופרים לניפוי שגיאות
- תמיכת פרוטוקול בריכה

---

## הפניות לקוד

**יישומי ליבה:**
- ממשק RPC: `src/pocx/rpc/mining.cpp`
- תור כורה: `src/pocx/mining/scheduler.cpp`
- אימות קונצנזוס: `src/pocx/consensus/validation.cpp`
- אימות הוכחה: `src/pocx/consensus/pocx.cpp`
- עיקום זמן: `src/pocx/algorithms/time_bending.cpp`
- אימות בלוק: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- לוגיקת הקצאה: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- ניהול הקשר: `src/pocx/node/node.cpp:GetNewBlockContext()`

**מבני נתונים:**
- פורמט בלוק: `src/primitives/block.h`
- פרמטרי קונצנזוס: `src/consensus/params.h`
- מעקב הקצאות: `src/coins.h` (הרחבות CCoinsViewCache)

---

## נספח: מפרטי אלגוריתמים

### נוסחת עיקום זמן

**הגדרה מתמטית:**
```
deadline_seconds = quality / base_target  (גולמי)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

כאשר:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**יישום:**
- אריתמטיקת נקודה קבועה (פורמט Q42)
- חישוב שורש שלישי למספרים שלמים בלבד
- מותאם לאריתמטיקת 256-bit

### חישוב איכות

**תהליך:**
1. צור scoop מחתימת יצירה וגובה
2. קרא נתוני plot ל-scoop מחושב
3. Hash: `SHABAL256(generation_signature || scoop_data)`
4. בדוק רמות סילום ממינימום למקסימום
5. החזר את האיכות הטובה ביותר שנמצאה

**סילום:**
- רמה X0: קו בסיס POC2 (תיאורטי)
- רמה X1: קו בסיס XOR-transpose
- רמה Xn: 2^(n-1) × עבודת X1 מוטמעת
- סילום גבוה יותר = יותר עבודת ייצור plot

### התאמת Base Target

**התאמה בכל בלוק:**
1. חשב ממוצע נע של base targets אחרונים
2. חשב פרק זמן בפועל מול פרק זמן יעד לחלון גלילה
3. התאם base target באופן פרופורציונלי
4. הגבל למניעת תנודות קיצוניות

**נוסחה:**
```
avg_base_target = moving_average(base targets אחרונים)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*תיעוד זה משקף את יישום קונצנזוס PoCX המלא נכון לאוקטובר 2025.*

---

[← הקודם: פורמט Plot](2-plot-format.md) | [📘 תוכן העניינים](index.md) | [הבא: הקצאות כרייה →](4-forging-assignments.md)
