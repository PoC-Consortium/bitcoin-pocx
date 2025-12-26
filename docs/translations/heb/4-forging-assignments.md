[← הקודם: קונצנזוס וכרייה](3-consensus-and-mining.md) | [📘 תוכן העניינים](index.md) | [הבא: סנכרון זמן →](5-timing-security.md)

---

# פרק 4: מערכת הקצאות כרייה של PoCX

## תקציר מנהלים

מסמך זה מתאר את מערכת הקצאות הכרייה **המיושמת** של PoCX באמצעות ארכיטקטורת OP_RETURN בלבד. המערכת מאפשרת לבעלי plots להאציל זכויות כרייה לכתובות נפרדות באמצעות עסקאות on-chain, עם בטיחות reorg מלאה ופעולות מסד נתונים אטומיות.

**סטטוס:** ✅ מיושם ופעיל במלואו

## פילוסופיית עיצוב ליבה

**עקרון מפתח:** הקצאות הן הרשאות, לא נכסים

- אין UTXOs מיוחדים לעקוב או להוציא
- מצב הקצאה מאוחסן בנפרד ממערך UTXO
- בעלות מוכחת על ידי חתימת עסקה, לא הוצאת UTXO
- מעקב היסטוריה מלא לנתיב ביקורת שלם
- עדכוני מסד נתונים אטומיים דרך כתיבות אצווה LevelDB

## מבנה עסקה

### פורמט עסקת הקצאה

```
קלטים:
  [0]: כל UTXO בשליטת בעל plot (מוכיח בעלות + משלם עמלות)
       חייב להיות חתום עם מפתח פרטי של בעל plot
  [1+]: קלטים נוספים אופציונליים לכיסוי עמלות

פלטים:
  [0]: OP_RETURN (סמן POCX + כתובת plot + כתובת כרייה)
       פורמט: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       גודל: 46 בתים סה"כ (1 בית OP_RETURN + 1 בית אורך + 44 בתים נתונים)
       ערך: 0 BTC (בלתי ניתן להוצאה, לא נוסף למערך UTXO)

  [1]: עודף חזרה למשתמש (אופציונלי, P2WPKH סטנדרטי)
```

**יישום:** `src/pocx/assignments/opcodes.cpp:25-52`

### פורמט עסקת ביטול

```
קלטים:
  [0]: כל UTXO בשליטת בעל plot (מוכיח בעלות + משלם עמלות)
       חייב להיות חתום עם מפתח פרטי של בעל plot
  [1+]: קלטים נוספים אופציונליים לכיסוי עמלות

פלטים:
  [0]: OP_RETURN (סמן XCOP + כתובת plot)
       פורמט: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       גודל: 26 בתים סה"כ (1 בית OP_RETURN + 1 בית אורך + 24 בתים נתונים)
       ערך: 0 BTC (בלתי ניתן להוצאה, לא נוסף למערך UTXO)

  [1]: עודף חזרה למשתמש (אופציונלי, P2WPKH סטנדרטי)
```

**יישום:** `src/pocx/assignments/opcodes.cpp:54-77`

### סמנים

- **סמן הקצאה:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **סמן ביטול:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**יישום:** `src/pocx/assignments/opcodes.cpp:15-19`

### מאפייני עסקה מפתח

- עסקאות Bitcoin סטנדרטיות (ללא שינויי פרוטוקול)
- פלטי OP_RETURN בלתי ניתנים להוצאה מוכחית (אף פעם לא נוספים למערך UTXO)
- בעלות plot מוכחת על ידי חתימה על input[0] מכתובת plot
- עלות נמוכה (~200 בתים, בדרך כלל <0.0001 BTC עמלה)
- הארנק בוחר אוטומטית את ה-UTXO הגדול ביותר מכתובת plot להוכחת בעלות

## ארכיטקטורת מסד נתונים

### מבנה אחסון

כל נתוני ההקצאה מאוחסנים באותו מסד נתונים LevelDB כמערך UTXO (`chainstate/`), אך עם קידומות מפתח נפרדות:

```
chainstate/ LevelDB:
├─ מערך UTXO (Bitcoin Core סטנדרטי)
│  └─ קידומת 'C': COutPoint → Coin
│
└─ מצב הקצאות (תוספות PoCX)
   └─ קידומת 'A': (plot_address, assignment_txid) → ForgingAssignment
       └─ היסטוריה מלאה: כל ההקצאות לכל plot לאורך זמן
```

**יישום:** `src/txdb.cpp:237-348`

### מבנה ForgingAssignment

```cpp
struct ForgingAssignment {
    // זהות
    std::array<uint8_t, 20> plotAddress;      // בעל plot (hash P2WPKH של 20 בתים)
    std::array<uint8_t, 20> forgingAddress;   // מחזיק זכויות כרייה (hash P2WPKH של 20 בתים)

    // מחזור חיי הקצאה
    uint256 assignment_txid;                   // עסקה שיצרה הקצאה
    int assignment_height;                     // גובה בלוק שנוצר
    int assignment_effective_height;           // מתי נהייה פעיל (גובה + עיכוב)

    // מחזור חיי ביטול
    bool revoked;                              // האם בוטל?
    uint256 revocation_txid;                   // עסקה שביטלה
    int revocation_height;                     // גובה בלוק שבוטל
    int revocation_effective_height;           // מתי ביטול אפקטיבי (גובה + עיכוב)

    // מתודות שאילתת מצב
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**יישום:** `src/coins.h:111-178`

### מצבי הקצאה

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // אין הקצאה קיימת
    ASSIGNING = 1,   // הקצאה נוצרה, ממתין לעיכוב הפעלה
    ASSIGNED = 2,    // הקצאה פעילה, כרייה מותרת
    REVOKING = 3,    // בוטל, אך עדיין פעיל במהלך תקופת עיכוב
    REVOKED = 4      // בוטל לחלוטין, כבר לא פעיל
};
```

**יישום:** `src/coins.h:98-104`

### מפתחות מסד נתונים

```cpp
// מפתח היסטוריה: מאחסן רשומת הקצאה מלאה
// פורמט מפתח: (קידומת, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // כתובת plot (20 בתים)
    int assignment_height;                // גובה לאופטימיזציית מיון
    uint256 assignment_txid;              // מזהה עסקה
};
```

**יישום:** `src/txdb.cpp:245-262`

### מעקב היסטוריה

- כל הקצאה מאוחסנת לצמיתות (לעולם לא נמחקת אלא אם reorg)
- הקצאות מרובות לכל plot נעקבות לאורך זמן
- מאפשר נתיב ביקורת מלא ושאילתות מצב היסטוריות
- הקצאות מבוטלות נשארות במסד נתונים עם `revoked=true`

## עיבוד בלוק

### אינטגרציית ConnectBlock

הקצאות וביטולי OP_RETURN מעובדים במהלך חיבור בלוק ב-`validation.cpp`:

```cpp
// מיקום: אחרי אימות סקריפט, לפני UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // פרסור נתוני OP_RETURN
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // אימות בעלות (tx חייב להיות חתום על ידי בעל plot)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // בדיקת מצב plot (חייב להיות UNASSIGNED או REVOKED)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // יצירת הקצאה חדשה
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // אחסון נתוני undo
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // פרסור נתוני OP_RETURN
            auto plot_addr = ParseRevocationOpReturn(output);

            // אימות בעלות
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // קבלת הקצאה נוכחית
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // אחסון מצב ישן ל-undo
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // סימון כמבוטל
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

// UpdateCoins ממשיך כרגיל (מדלג אוטומטית על פלטי OP_RETURN)
```

**יישום:** `src/validation.cpp:2775-2878`

### אימות בעלות

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // בדוק שלפחות קלט אחד חתום על ידי בעל plot
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // חילוץ יעד
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // בדוק אם P2WPKH לכתובת plot
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core כבר אימת חתימה
                return true;
            }
        }
    }
    return false;
}
```

**יישום:** `src/pocx/assignments/opcodes.cpp:217-256`

### עיכובי הפעלה

להקצאות וביטולים יש עיכובי הפעלה הניתנים להגדרה למניעת התקפות reorg:

```cpp
// פרמטרי קונצנזוס (ניתנים להגדרה לכל רשת)
// דוגמה: 30 בלוקים = ~שעה עם זמן בלוק של 2 דקות
consensus.nForgingAssignmentDelay;   // עיכוב הפעלת הקצאה
consensus.nForgingRevocationDelay;   // עיכוב הפעלת ביטול
```

**מעברי מצב:**
- הקצאה: `UNASSIGNED → ASSIGNING (עיכוב) → ASSIGNED`
- ביטול: `ASSIGNED → REVOKING (עיכוב) → REVOKED`

**יישום:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## אימות Mempool

עסקאות הקצאה וביטול מאומתות בקבלת mempool לדחיית עסקאות לא תקפות לפני הפצת רשת.

### בדיקות ברמת עסקה (CheckTransaction)

מבוצעות ב-`src/consensus/tx_check.cpp` ללא גישה למצב שרשרת:

1. **מקסימום OP_RETURN POCX אחד:** עסקה לא יכולה להכיל סמני POCX/XCOP מרובים

**יישום:** `src/consensus/tx_check.cpp:63-77`

### בדיקות קבלת Mempool (PreChecks)

מבוצעות ב-`src/validation.cpp` עם גישה מלאה למצב שרשרת ו-mempool:

#### אימות הקצאה

1. **בעלות Plot:** עסקה חייבת להיות חתומה על ידי בעל plot
2. **מצב Plot:** Plot חייב להיות UNASSIGNED (0) או REVOKED (4)
3. **התנגשויות Mempool:** אין הקצאה אחרת ל-plot זה ב-mempool (ראשון שנראה מנצח)

#### אימות ביטול

1. **בעלות Plot:** עסקה חייבת להיות חתומה על ידי בעל plot
2. **הקצאה פעילה:** Plot חייב להיות במצב ASSIGNED (2) בלבד
3. **התנגשויות Mempool:** אין ביטול אחר ל-plot זה ב-mempool

**יישום:** `src/validation.cpp:898-993`

### זרימת אימות

```
שידור עסקה
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ מקסימום OP_RETURN POCX אחד
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ אימות בעלות plot
  ✓ בדיקת מצב הקצאה
  ✓ בדיקת התנגשויות mempool
       ↓
   תקף → קבלה ל-Mempool
   לא תקף → דחייה (לא להפיץ)
       ↓
כריית בלוק
       ↓
ConnectBlock() [validation.cpp]
  ✓ אימות מחדש של כל הבדיקות (הגנה בעומק)
  ✓ החלת שינויי מצב
  ✓ רישום מידע undo
```

### הגנה בעומק

כל בדיקות אימות mempool מבוצעות מחדש במהלך `ConnectBlock()` להגנה מפני:
- התקפות עקיפת mempool
- בלוקים לא תקפים מכורים זדוניים
- מקרי קצה במהלך תרחישי reorg

אימות בלוק נשאר סמכותי לקונצנזוס.

## עדכוני מסד נתונים אטומיים

### ארכיטקטורה תלת-שכבתית

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (מטמון זיכרון)        │  ← שינויי הקצאה נעקבים בזיכרון
│   - Coins: cacheCoins                   │
│   - Assignments: pendingAssignments     │
│   - מעקב dirty: dirtyPlots              │
│   - מחיקות: deletedAssignments          │
│   - מעקב זיכרון: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (שכבת מסד נתונים)        │  ← כתיבה אטומית יחידה
│   - BatchWrite(): UTXOs + Assignments   │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (אחסון דיסק)                  │  ← ערבויות ACID
│   - עסקה אטומית                         │
└─────────────────────────────────────────┘
```

### תהליך Flush

כאשר `view.Flush()` נקרא במהלך חיבור בלוק:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. כתוב שינויי coins לבסיס
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. כתוב שינויי הקצאה אטומית
    if (fOk && !dirtyPlots.empty()) {
        // אסוף הקצאות dirty
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // ריק - לא בשימוש

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // כתוב למסד נתונים
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // נקה מעקב
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // שחרר זיכרון
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**יישום:** `src/coins.cpp:278-315`

### כתיבת אצווה למסד נתונים

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // אצוות LevelDB יחידה

    // 1. סמן מצב מעבר
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. כתוב את כל שינויי coins
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. סמן מצב עקבי
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. COMMIT אטומי
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// הקצאות נכתבות בנפרד אך באותו הקשר עסקת מסד נתונים
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // פרמטר לא בשימוש (נשמר לתאימות API)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // אצווה חדשה, אותו מסד נתונים

    // כתוב היסטוריית הקצאות
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // מחק הקצאות שנמחקו מהיסטוריה
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // COMMIT אטומי
    return m_db->WriteBatch(batch);
}
```

**יישום:** `src/txdb.cpp:332-348`

### ערבויות אטומיות

✅ **מה אטומי:**
- כל שינויי coins בתוך בלוק נכתבים אטומית
- כל שינויי הקצאה בתוך בלוק נכתבים אטומית
- מסד נתונים נשאר עקבי בקריסות

⚠️ **מגבלה נוכחית:**
- Coins והקצאות נכתבים בפעולות אצווה LevelDB **נפרדות**
- שתי הפעולות קורות במהלך `view.Flush()`, אך לא בכתיבה אטומית יחידה
- בפועל: שתי האצוות מסתיימות ברצף מהיר לפני fsync לדיסק
- הסיכון מינימלי: שניהם יצטרכו להיות מושמעים מחדש מאותו בלוק במהלך שחזור קריסה

**הערה:** זה שונה מתוכנית הארכיטקטורה המקורית שקראה לאצווה מאוחדת יחידה. היישום הנוכחי משתמש בשתי אצוות אך שומר על עקביות דרך מנגנוני שחזור הקריסה הקיימים של Bitcoin Core (סמן DB_HEAD_BLOCKS).

## טיפול ב-Reorg

### מבנה נתוני Undo

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // הקצאה נוספה (מחק ב-undo)
        MODIFIED = 1,   // הקצאה שונתה (שחזר ב-undo)
        REVOKED = 2     // הקצאה בוטלה (בטל ביטול ב-undo)
    };

    UndoType type;
    ForgingAssignment assignment;  // מצב מלא לפני שינוי
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // נתוני undo UTXO
    std::vector<ForgingUndo> vforgingundo;  // נתוני undo הקצאה
};
```

**יישום:** `src/undo.h:63-105`

### תהליך DisconnectBlock

כאשר בלוק מנותק במהלך reorg:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... ניתוק UTXO סטנדרטי ...

    // קרא נתוני undo מדיסק
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // בטל שינויי הקצאה (עבד בסדר הפוך)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // הקצאה נוספה - הסר אותה
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // הקצאה בוטלה - שחזר מצב לא-מבוטל
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // הקצאה שונתה - שחזר מצב קודם
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**יישום:** `src/validation.cpp:2381-2415`

### ניהול מטמון במהלך Reorg

```cpp
class CCoinsViewCache {
private:
    // מטמוני הקצאה
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // עקוב plots משונים
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // עקוב מחיקות
    mutable size_t cachedAssignmentsUsage{0};  // מעקב זיכרון

public:
    void AddForgingAssignment(const ForgingAssignment& assignment) {
        pendingAssignments[assignment.plotAddress].push_back(assignment);
        dirtyPlots.insert(assignment.plotAddress);
        cachedAssignmentsUsage += sizeof(ForgingAssignment);
    }

    void RemoveForgingAssignment(const std::array<uint8_t, 20>& plotAddress,
                                 const uint256& assignment_txid) {
        auto key = std::make_pair(plotAddress, assignment_txid);
        deletedAssignments.insert(key);
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
        if (true) {
            cachedAssignmentsUsage += sizeof(ForgingAssignment);
        }
    }
};
```

**יישום:** `src/coins.cpp:494-565`

## ממשק RPC

### פקודות צומת (ללא ארנק נדרש)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

מחזיר סטטוס הקצאה נוכחי לכתובת plot:
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

**יישום:** `src/pocx/rpc/assignments.cpp:31-126`

### פקודות ארנק (ארנק נדרש)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

יוצר עסקת הקצאה:
- בוחר אוטומטית UTXO הגדול ביותר מכתובת plot להוכחת בעלות
- בונה עסקה עם OP_RETURN + פלט עודף
- חותם עם מפתח בעל plot
- משדר לרשת

**יישום:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

יוצר עסקת ביטול:
- בוחר אוטומטית UTXO הגדול ביותר מכתובת plot להוכחת בעלות
- בונה עסקה עם OP_RETURN + פלט עודף
- חותם עם מפתח בעל plot
- משדר לרשת

**יישום:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### יצירת עסקת ארנק

תהליך יצירת עסקת ארנק:

```cpp
1. פרסור ואימות כתובות (חייבות להיות P2WPKH bech32)
2. מצא UTXO הגדול ביותר מכתובת plot (מוכיח בעלות)
3. צור עסקה זמנית עם פלט placeholder
4. חתום עסקה (קבל גודל מדויק עם נתוני witness)
5. החלף פלט placeholder ב-OP_RETURN
6. התאם עמלות פרופורציונלית על בסיס שינוי גודל
7. חתום מחדש עסקה סופית
8. שדר לרשת
```

**תובנה מפתח:** הארנק חייב להוציא מכתובת plot להוכחת בעלות, אז הוא מאלץ אוטומטית בחירת coins מאותה כתובת.

**יישום:** `src/pocx/assignments/transactions.cpp:38-263`

## מבנה קבצים

### קובצי יישום ליבה

```
src/
├── coins.h                        # מבנה ForgingAssignment, מתודות CCoinsViewCache [710 שורות]
├── coins.cpp                      # ניהול מטמון, כתיבות אצווה [603 שורות]
│
├── txdb.h                         # מתודות הקצאה CCoinsViewDB [90 שורות]
├── txdb.cpp                       # קריאה/כתיבה למסד נתונים [349 שורות]
│
├── undo.h                         # מבנה ForgingUndo ל-reorgs
│
├── validation.cpp                 # אינטגרציית ConnectBlock/DisconnectBlock
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # פורמט OP_RETURN, פרסור, אימות
    │   ├── opcodes.cpp            # [259 שורות] הגדרות סמנים, פעולות OP_RETURN, בדיקת בעלות
    │   ├── assignment_state.h     # עוזרי GetEffectiveSigner, GetAssignmentState
    │   ├── assignment_state.cpp   # פונקציות שאילתת מצב הקצאה
    │   ├── transactions.h         # API יצירת עסקת ארנק
    │   └── transactions.cpp       # פונקציות ארנק create_assignment, revoke_assignment
    │
    ├── rpc/
    │   ├── assignments.h          # פקודות RPC צומת (ללא ארנק)
    │   ├── assignments.cpp        # RPCs get_assignment, list_assignments
    │   ├── assignments_wallet.h   # פקודות RPC ארנק
    │   └── assignments_wallet.cpp # RPCs create_assignment, revoke_assignment
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## מאפייני ביצועים

### פעולות מסד נתונים

- **קבל הקצאה נוכחית:** O(n) - סריקת כל ההקצאות לכתובת plot למציאת האחרונה
- **קבל היסטוריית הקצאות:** O(n) - איטרציה על כל ההקצאות ל-plot
- **צור הקצאה:** O(1) - הוספה יחידה
- **בטל הקצאה:** O(1) - עדכון יחיד
- **Reorg (להקצאה):** O(1) - החלת נתוני undo ישירה

כאשר n = מספר הקצאות ל-plot (בדרך כלל קטן, < 10)

### שימוש בזיכרון

- **להקצאה:** ~160 בתים (מבנה ForgingAssignment)
- **תקורת מטמון:** תקורת hash map למעקב dirty
- **בלוק טיפוסי:** <10 הקצאות = <2 KB זיכרון

### שימוש בדיסק

- **להקצאה:** ~200 בתים בדיסק (עם תקורת LevelDB)
- **10000 הקצאות:** ~2 MB שטח דיסק
- **זניח בהשוואה למערך UTXO:** <0.001% מ-chainstate טיפוסי

## מגבלות נוכחיות ועבודה עתידית

### מגבלת אטומיות

**נוכחי:** Coins והקצאות נכתבים באצוות LevelDB נפרדות במהלך `view.Flush()`

**השפעה:** סיכון תיאורטי לחוסר עקביות אם קריסה מתרחשת בין אצוות

**הפחתה:**
- שתי האצוות מסתיימות במהירות לפני fsync
- שחזור קריסה של Bitcoin Core משתמש בסמן DB_HEAD_BLOCKS
- בפועל: לא נצפה בבדיקות

**שיפור עתידי:** איחוד לפעולת אצווה LevelDB יחידה

### גיזום היסטוריית הקצאות

**נוכחי:** כל ההקצאות מאוחסנות לזמן בלתי מוגבל

**השפעה:** ~200 בתים להקצאה לנצח

**עתיד:** גיזום אופציונלי של הקצאות מבוטלות לחלוטין ישנות יותר מ-N בלוקים

**הערה:** לא סביר שיידרש - אפילו מיליון הקצאות = 200 MB

## סטטוס בדיקות

### בדיקות מיושמות

✅ פרסור ואימות OP_RETURN
✅ אימות בעלות
✅ יצירת הקצאה ConnectBlock
✅ ביטול ConnectBlock
✅ טיפול reorg DisconnectBlock
✅ פעולות קריאה/כתיבה למסד נתונים
✅ מעברי מצב (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
✅ פקודות RPC (get_assignment, create_assignment, revoke_assignment)
✅ יצירת עסקת ארנק

### אזורי כיסוי בדיקות

- בדיקות יחידה: `src/test/pocx_*_tests.cpp`
- בדיקות פונקציונליות: `test/functional/feature_pocx_*.py`
- בדיקות אינטגרציה: בדיקה ידנית עם regtest

## כללי קונצנזוס

### כללי יצירת הקצאה

1. **בעלות:** עסקה חייבת להיות חתומה על ידי בעל plot
2. **מצב:** Plot חייב להיות במצב UNASSIGNED או REVOKED
3. **פורמט:** OP_RETURN תקף עם סמן POCX + 2x כתובות של 20 בתים
4. **ייחודיות:** הקצאה פעילה אחת ל-plot בכל זמן

### כללי ביטול

1. **בעלות:** עסקה חייבת להיות חתומה על ידי בעל plot
2. **קיום:** הקצאה חייבת להתקיים ולא להיות כבר מבוטלת
3. **פורמט:** OP_RETURN תקף עם סמן XCOP + כתובת של 20 בתים

### כללי הפעלה

- **הפעלת הקצאה:** `assignment_height + nForgingAssignmentDelay`
- **הפעלת ביטול:** `revocation_height + nForgingRevocationDelay`
- **עיכובים:** ניתנים להגדרה לכל רשת (למשל, 30 בלוקים = ~שעה עם זמן בלוק של 2 דקות)

### אימות בלוק

- הקצאה/ביטול לא תקפים → בלוק נדחה (כשל קונצנזוס)
- פלטי OP_RETURN מוחרגים אוטומטית ממערך UTXO (התנהגות Bitcoin סטנדרטית)
- עיבוד הקצאות מתרחש לפני עדכוני UTXO ב-ConnectBlock

## סיכום

מערכת הקצאות הכרייה של PoCX כפי שיושמה מספקת:

✅ **פשטות:** עסקאות Bitcoin סטנדרטיות, ללא UTXOs מיוחדים
✅ **חסכון:** אין דרישת dust, רק עמלות עסקה
✅ **בטיחות Reorg:** נתוני undo מקיפים משחזרים מצב נכון
✅ **עדכונים אטומיים:** עקביות מסד נתונים דרך אצוות LevelDB
✅ **היסטוריה מלאה:** נתיב ביקורת שלם של כל ההקצאות לאורך זמן
✅ **ארכיטקטורה נקייה:** שינויי Bitcoin Core מינימליים, קוד PoCX מבודד
✅ **מוכן לייצור:** מיושם במלואו, נבדק, ופעיל

### איכות יישום

- **ארגון קוד:** מצוין - הפרדה ברורה בין Bitcoin Core ל-PoCX
- **טיפול בשגיאות:** אימות קונצנזוס מקיף
- **תיעוד:** הערות קוד ומבנה מתועדים היטב
- **בדיקות:** פונקציונליות ליבה נבדקה, אינטגרציה אומתה

### החלטות עיצוב מפתח שאומתו

1. ✅ גישת OP_RETURN בלבד (מול מבוסס UTXO)
2. ✅ אחסון מסד נתונים נפרד (מול extraData של Coin)
3. ✅ מעקב היסטוריה מלא (מול נוכחי בלבד)
4. ✅ בעלות על ידי חתימה (מול הוצאת UTXO)
5. ✅ עיכובי הפעלה (מונע התקפות reorg)

המערכת משיגה בהצלחה את כל יעדי הארכיטקטורה עם יישום נקי וניתן לתחזוקה.

---

[← הקודם: קונצנזוס וכרייה](3-consensus-and-mining.md) | [📘 תוכן העניינים](index.md) | [הבא: סנכרון זמן →](5-timing-security.md)
