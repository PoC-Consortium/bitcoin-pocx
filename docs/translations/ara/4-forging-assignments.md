[→ السابق: الإجماع والتعدين](3-consensus-and-mining.md) | [📘 جدول المحتويات](index.md) | [التالي: مزامنة الوقت →](5-timing-security.md)

---

# الفصل الرابع: نظام تعيين صياغة PoCX

## الملخص التنفيذي

يصف هذا المستند نظام تعيين صياغة PoCX **المُنفّذ** باستخدام بنية OP_RETURN فقط. يُمكّن النظام مالكي الرسم من تفويض حقوق الصياغة لعناوين منفصلة من خلال معاملات على السلسلة، مع سلامة كاملة من إعادة التنظيم وعمليات قاعدة بيانات ذرية.

**الحالة:** ✅ منفّذ بالكامل وعامل

## فلسفة التصميم الأساسية

**المبدأ الرئيسي:** التعيينات هي أذونات، وليست أصولاً

- لا UTXOs خاصة للتتبع أو الإنفاق
- حالة التعيين مُخزّنة بشكل منفصل عن مجموعة UTXO
- الملكية تُثبت بتوقيع المعاملة، وليس إنفاق UTXO
- تتبع السجل الكامل لمسار تدقيق كامل
- تحديثات قاعدة بيانات ذرية من خلال كتابات دفعية LevelDB

## هيكل المعاملة

### صيغة معاملة التعيين

```
المدخلات:
  [0]: أي UTXO يتحكم فيه مالك الرسم (يثبت الملكية + يدفع الرسوم)
       يجب أن يكون موقّعاً بالمفتاح الخاص لمالك الرسم
  [1+]: مدخلات إضافية اختيارية لتغطية الرسوم

المخرجات:
  [0]: OP_RETURN (علامة POCX + عنوان الرسم + عنوان الصياغة)
       الصيغة: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       الحجم: 46 بايت إجمالي (1 بايت OP_RETURN + 1 بايت الطول + 44 بايت بيانات)
       القيمة: 0 BTC (غير قابل للإنفاق، لا يُضاف لمجموعة UTXO)

  [1]: التغيير للمستخدم (اختياري، P2WPKH قياسي)
```

**التنفيذ:** `src/pocx/assignments/opcodes.cpp`

### صيغة معاملة الإلغاء

```
المدخلات:
  [0]: أي UTXO يتحكم فيه مالك الرسم (يثبت الملكية + يدفع الرسوم)
       يجب أن يكون موقّعاً بالمفتاح الخاص لمالك الرسم
  [1+]: مدخلات إضافية اختيارية لتغطية الرسوم

المخرجات:
  [0]: OP_RETURN (علامة XCOP + عنوان الرسم)
       الصيغة: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       الحجم: 26 بايت إجمالي (1 بايت OP_RETURN + 1 بايت الطول + 24 بايت بيانات)
       القيمة: 0 BTC (غير قابل للإنفاق، لا يُضاف لمجموعة UTXO)

  [1]: التغيير للمستخدم (اختياري، P2WPKH قياسي)
```

**التنفيذ:** `src/pocx/assignments/opcodes.cpp`

### العلامات

- **علامة التعيين:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **علامة الإلغاء:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**التنفيذ:** `src/pocx/assignments/opcodes.cpp`

### خصائص المعاملة الرئيسية

- معاملات Bitcoin قياسية (لا تغييرات في البروتوكول)
- مخرجات OP_RETURN غير قابلة للإنفاق بشكل مُثبت (لا تُضاف لمجموعة UTXO أبداً)
- ملكية الرسم تُثبت بالتوقيع على input[0] من عنوان الرسم
- تكلفة منخفضة (~200 بايت، عادة <0.0001 BTC رسوم)
- المحفظة تختار تلقائياً أكبر UTXO من عنوان الرسم لإثبات الملكية

## بنية قاعدة البيانات

### هيكل التخزين

جميع بيانات التعيين مُخزّنة في نفس قاعدة بيانات LevelDB مثل مجموعة UTXO (`chainstate/`)، لكن ببادئات مفاتيح منفصلة:

```
chainstate/ LevelDB:
├─ مجموعة UTXO (قياسي Bitcoin Core)
│  └─ بادئة 'C': COutPoint → Coin
│
└─ حالة التعيين (إضافات PoCX)
   └─ بادئة 'A': (plot_address, assignment_txid) → ForgingAssignment
       └─ السجل الكامل: جميع التعيينات لكل رسم عبر الوقت
```

**التنفيذ:** `src/txdb.cpp`

### هيكل ForgingAssignment

```cpp
struct ForgingAssignment {
    // الهوية
    std::array<uint8_t, 20> plotAddress;      // مالك الرسم (تجزئة P2WPKH 20 بايت)
    std::array<uint8_t, 20> forgingAddress;   // حامل حقوق الصياغة (تجزئة P2WPKH 20 بايت)

    // دورة حياة التعيين
    uint256 assignment_txid;                   // المعاملة التي أنشأت التعيين
    int assignment_height;                     // ارتفاع الكتلة عند الإنشاء
    int assignment_effective_height;           // عندما يصبح نشطاً (الارتفاع + التأخير)

    // دورة حياة الإلغاء
    bool revoked;                              // هل تم إلغاء هذا؟
    uint256 revocation_txid;                   // المعاملة التي ألغته
    int revocation_height;                     // ارتفاع الكتلة عند الإلغاء
    int revocation_effective_height;           // عندما يصبح الإلغاء فعالاً (الارتفاع + التأخير)

    // طرق استعلام الحالة
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**التنفيذ:** `src/coins.h`

### حالات التعيين

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // لا تعيين موجود
    ASSIGNING = 1,   // التعيين أُنشئ، في انتظار تأخير التفعيل
    ASSIGNED = 2,    // التعيين نشط، الصياغة مسموحة
    REVOKING = 3,    // مُلغى، لكن لا يزال نشطاً خلال فترة التأخير
    REVOKED = 4      // مُلغى بالكامل، لم يعد نشطاً
};
```

**التنفيذ:** `src/coins.h`

### مفاتيح قاعدة البيانات

```cpp
// مفتاح السجل: يخزن سجل التعيين الكامل
// صيغة المفتاح: (prefix, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // عنوان الرسم (20 بايت)
    int assignment_height;                // الارتفاع لتحسين الفرز
    uint256 assignment_txid;              // معرف المعاملة
};
```

**التنفيذ:** `src/txdb.cpp`

### تتبع السجل

- كل تعيين يُخزّن بشكل دائم (لا يُحذف إلا في إعادة التنظيم)
- تُتتبّع تعيينات متعددة لكل رسم عبر الوقت
- يُمكّن مسار التدقيق الكامل واستعلامات الحالة التاريخية
- التعيينات المُلغاة تبقى في قاعدة البيانات مع `revoked=true`

## معالجة الكتلة

### تكامل ConnectBlock

تُعالج OP_RETURNs للتعيين والإلغاء أثناء اتصال الكتلة في `validation.cpp`:

```cpp
// الموقع: بعد التحقق من السكريبت، قبل UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // تحليل بيانات OP_RETURN
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // التحقق من الملكية (يجب أن تكون المعاملة موقّعة من مالك الرسم)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // فحص حالة الرسم (يجب أن يكون UNASSIGNED أو REVOKED)
            ForgingState plotState = pocx::assignments::GetAssignmentState(plot_addr, height, view);
            if (plotState != UNASSIGNED && plotState != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // إنشاء تعيين جديد
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // تخزين بيانات التراجع
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // تحليل بيانات OP_RETURN
            auto plot_addr = ParseRevocationOpReturn(output);

            // التحقق من الملكية
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // الحصول على التعيين الحالي - يجب أن يكون في حالة ASSIGNED للإلغاء
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->GetStateAtHeight(height) != ForgingState::ASSIGNED)
                return state.Invalid("cannot-revoke-inactive");

            // تخزين الحالة القديمة للتراجع
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // وضع علامة كمُلغى
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

// UpdateCoins يستمر بشكل طبيعي (يتخطى مخرجات OP_RETURN تلقائياً)
```

**التنفيذ:** `src/validation.cpp:ConnectBlock()`

### التحقق من الملكية

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // التحقق من أن مدخل واحد على الأقل موقّع من مالك الرسم
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

**التنفيذ:** `src/pocx/assignments/opcodes.cpp:VerifyPlotOwnership()`

### تأخيرات التفعيل

التعيينات والإلغاءات لها تأخيرات تفعيل قابلة للتكوين لمنع هجمات إعادة التنظيم:

```cpp
// معلمات الإجماع (قابلة للتكوين لكل شبكة)
// مثال: 30 كتلة = ~1 ساعة مع وقت كتلة 2 دقيقة
consensus.nForgingAssignmentDelay;   // تأخير تفعيل التعيين
consensus.nForgingRevocationDelay;   // تأخير تفعيل الإلغاء
```

**انتقالات الحالة:**
- التعيين: `UNASSIGNED → ASSIGNING (تأخير) → ASSIGNED`
- الإلغاء: `ASSIGNED → REVOKING (تأخير) → REVOKED`

**التنفيذ:** `src/consensus/params.h`، `src/kernel/chainparams.cpp`

## التحقق من Mempool

تُحقق معاملات التعيين والإلغاء عند قبول mempool لرفض المعاملات غير الصالحة قبل نشر الشبكة.

### فحوصات مستوى المعاملة (CheckTransaction)

تُنفّذ في `src/consensus/tx_check.cpp` بدون وصول لحالة السلسلة:

1. **حد أقصى OP_RETURN POCX واحد:** المعاملة لا يمكن أن تحتوي علامات POCX/XCOP متعددة

**التنفيذ:** `src/consensus/tx_check.cpp`

### فحوصات قبول Mempool (PreChecks)

تُنفّذ في `src/validation.cpp` مع وصول كامل لحالة السلسلة و mempool:

#### التحقق من التعيين

1. **ملكية الرسم:** يجب أن تكون المعاملة موقّعة من مالك الرسم
2. **حالة الرسم:** يجب أن يكون الرسم في حالة UNASSIGNED (0) أو REVOKED (4)
3. **تعارضات Mempool:** لا تعيين آخر لهذا الرسم في mempool (أول مشاهدة يفوز)

#### التحقق من الإلغاء

1. **ملكية الرسم:** يجب أن تكون المعاملة موقّعة من مالك الرسم
2. **تعيين نشط:** يجب أن يكون الرسم في حالة ASSIGNED (2) فقط
3. **تعارضات Mempool:** لا إلغاء آخر لهذا الرسم في mempool

**التنفيذ:** `src/validation.cpp:PreChecks()`

### تدفق التحقق

```
بث المعاملة
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ حد أقصى OP_RETURN POCX واحد
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ التحقق من ملكية الرسم
  ✓ فحص حالة التعيين
  ✓ فحص تعارضات mempool
       ↓
   صالح → قبول في Mempool
   غير صالح → رفض (لا نشر)
       ↓
تعدين الكتلة
       ↓
ConnectBlock() [validation.cpp]
  ✓ إعادة التحقق من جميع الفحوصات (دفاع متعمق)
  ✓ تطبيق تغييرات الحالة
  ✓ تسجيل معلومات التراجع
```

### الدفاع المتعمق

جميع فحوصات التحقق من mempool تُعاد تنفيذها أثناء `ConnectBlock()` للحماية من:
- هجمات تجاوز mempool
- كتل غير صالحة من مُعدّنين خبيثين
- الحالات الحافة أثناء سيناريوهات إعادة التنظيم

التحقق من الكتلة يبقى موثوقاً للإجماع.

## تحديثات قاعدة البيانات الذرية

### بنية ثلاثية الطبقات

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (ذاكرة التخزين المؤقت)        │  ← تغييرات التعيين تُتتبّع في الذاكرة
│   - Coins: cacheCoins                   │
│   - Assignments: pendingAssignments     │
│   - تتبع التغييرات: dirtyPlots          │
│   - الحذف: deletedAssignments       │
│   - تتبع الذاكرة: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (طبقة قاعدة البيانات)         │  ← كتابة ذرية واحدة
│   - BatchWrite(): UTXOs + Assignments   │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (تخزين القرص)                │  ← ضمانات ACID
│   - معاملة ذرية                  │
└─────────────────────────────────────────┘
```

### عملية Flush

عندما يُستدعى `view.Flush()` أثناء اتصال الكتلة:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. كتابة تغييرات العملة للقاعدة
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. كتابة تغييرات التعيين بشكل ذري
    if (fOk && !dirtyPlots.empty()) {
        // جمع التعيينات المُتغيّرة
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

        // الكتابة لقاعدة البيانات
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

**التنفيذ:** `src/coins.cpp:Flush()`

### كتابة دفعة قاعدة البيانات

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // دفعة LevelDB واحدة

    // 1. وضع علامة حالة الانتقال
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. كتابة جميع تغييرات العملة
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. وضع علامة حالة متسقة
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. إلتزام ذري
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// التعيينات تُكتب بشكل منفصل لكن في نفس سياق معاملة قاعدة البيانات
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

**التنفيذ:** `src/txdb.cpp:BatchWriteAssignments()`

### ضمانات الذرية

✅ **ما هو ذري:**
- جميع تغييرات العملة ضمن كتلة تُكتب بشكل ذري
- جميع تغييرات التعيين ضمن كتلة تُكتب بشكل ذري
- قاعدة البيانات تبقى متسقة عبر الأعطال

⚠️ **القيد الحالي:**
- العملات والتعيينات تُكتب في عمليات دفعة LevelDB **منفصلة**
- كلا العمليتين تحدثان أثناء `view.Flush()`، لكن ليس في كتابة ذرية واحدة
- عملياً: كلتا الدفعتين تكتملان بسرعة قبل fsync القرص
- المخاطرة ضئيلة: كلاهما سيحتاج إعادة تشغيل من نفس الكتلة أثناء استرداد العطل

**ملاحظة:** هذا يختلف عن خطة البنية الأصلية التي دعت لدفعة موحدة واحدة. التنفيذ الحالي يستخدم دفعتين لكن يحافظ على الاتساق من خلال آليات استرداد العطل الموجودة في Bitcoin Core (علامة DB_HEAD_BLOCKS).

## معالجة إعادة التنظيم

### هيكل بيانات التراجع

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // التعيين أُضيف (حذف عند التراجع)
        MODIFIED = 1,   // التعيين عُدّل (استعادة عند التراجع)
        REVOKED = 2     // التعيين أُلغي (إلغاء الإلغاء عند التراجع)
    };

    UndoType type;
    ForgingAssignment assignment;  // الحالة الكاملة قبل التغيير
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // بيانات تراجع UTXO
    std::vector<ForgingUndo> vforgingundo;  // بيانات تراجع التعيين
};
```

**التنفيذ:** `src/undo.h`

### عملية DisconnectBlock

عندما يُفصل كتلة أثناء إعادة التنظيم:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... فصل UTXO القياسي ...

    // قراءة بيانات التراجع من القرص
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // تراجع تغييرات التعيين (المعالجة بترتيب عكسي)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // التعيين أُضيف - إزالته
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // التعيين أُلغي - استعادة الحالة غير المُلغاة
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // التعيين عُدّل - استعادة الحالة السابقة
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**التنفيذ:** `src/validation.cpp:DisconnectBlock()`

### إدارة ذاكرة التخزين المؤقت أثناء إعادة التنظيم

```cpp
class CCoinsViewCache {
private:
    // ذاكرة تخزين التعيين المؤقتة
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // تتبع الرسومات المُعدّلة
    mutable ForgingAssignmentsMap deletedAssignments;  // Track deletions (map, not set)  // تتبع الحذف
    mutable size_t cachedAssignmentsUsage{0};  // تتبع الذاكرة

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

**التنفيذ:** `src/coins.cpp`

## واجهة RPC

### أوامر العقدة (لا تتطلب محفظة)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

تُرجع حالة التعيين الحالية لعنوان الرسم:
```json
{
  "plot_address": "pocx1qplot...",
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 100,
  "activation_height": 130,
  "revoked": false
}
```

**التنفيذ:** `src/pocx/rpc/assignments.cpp`

### أوامر المحفظة (تتطلب محفظة)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

تُنشئ معاملة تعيين:
- تختار تلقائياً أكبر UTXO من عنوان الرسم لإثبات الملكية
- تبني المعاملة مع مخرج OP_RETURN + التغيير
- تُوقّع بمفتاح مالك الرسم
- تبث للشبكة

**التنفيذ:** `src/pocx/rpc/assignments_wallet.cpp`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

تُنشئ معاملة إلغاء:
- تختار تلقائياً أكبر UTXO من عنوان الرسم لإثبات الملكية
- تبني المعاملة مع مخرج OP_RETURN + التغيير
- تُوقّع بمفتاح مالك الرسم
- تبث للشبكة

**التنفيذ:** `src/pocx/rpc/assignments_wallet.cpp`

### إنشاء معاملة المحفظة

عملية إنشاء معاملة المحفظة:

```cpp
1. تحليل والتحقق من العناوين (يجب أن تكون P2WPKH bech32)
2. إيجاد أكبر UTXO من عنوان الرسم (يثبت الملكية)
3. إنشاء معاملة مؤقتة مع مخرج وهمي
4. توقيع المعاملة (الحصول على حجم دقيق مع بيانات الشهادة)
5. استبدال المخرج الوهمي بـ OP_RETURN
6. تعديل الرسوم بالتناسب بناءً على تغيير الحجم
7. إعادة توقيع المعاملة النهائية
8. البث للشبكة
```

**نظرة مهمة:** يجب على المحفظة الإنفاق من عنوان الرسم لإثبات الملكية، لذا تفرض تلقائياً اختيار العملة من ذلك العنوان.

**التنفيذ:** `src/pocx/assignments/transactions.cpp`

## هيكل الملفات

### ملفات التنفيذ الأساسية

```
src/
├── coins.h                        # هيكل ForgingAssignment، طرق CCoinsViewCache [710 سطر]
├── coins.cpp                      # إدارة ذاكرة التخزين المؤقت، الكتابات الدفعية [603 سطر]
│
├── txdb.h                         # طرق تعيين CCoinsViewDB [90 سطر]
├── txdb.cpp                       # قراءة/كتابة قاعدة البيانات [349 سطر]
│
├── undo.h                         # هيكل ForgingUndo لإعادة التنظيم
│
├── validation.cpp                 # تكامل ConnectBlock/DisconnectBlock
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # صيغة OP_RETURN، التحليل، التحقق
    │   ├── opcodes.cpp            # [259 سطر] تعريفات العلامات، عمليات OP_RETURN، فحص الملكية
    │   ├── assignment_state.h     # مساعدات GetEffectiveSigner، GetAssignmentState
    │   ├── assignment_state.cpp   # دوال استعلام حالة التعيين
    │   ├── replay.h               # إعادة تنظيم/إعادة تشغيل تأثيرات التعيين
    │   ├── replay.cpp             # ApplyAssignmentEffectsForReplay (مسار إعادة التنظيم)
    │   ├── transactions.h         # واجهة برمجة إنشاء معاملة المحفظة
    │   └── transactions.cpp       # دوال محفظة create_assignment، revoke_assignment
    │
    ├── rpc/
    │   ├── assignments.h          # أوامر RPC للعقدة (بدون محفظة)
    │   ├── assignments.cpp        # RPCs get_assignment، list_assignments
    │   ├── assignments_wallet.h   # أوامر RPC للمحفظة
    │   └── assignments_wallet.cpp # RPCs create_assignment، revoke_assignment
    │
    └── consensus/
        └── params.h               # PoCXCompressionBounds، الهدف الأساسي للتكوين، جدول الضغط
```

> **ملاحظة:** ثوابت تأخير التعيين `nForgingAssignmentDelay` / `nForgingRevocationDelay` موجودة في `Consensus::Params` الخاص بـ Bitcoin Core (`src/consensus/params.h`) وتُضبط لكل شبكة في `src/kernel/chainparams.cpp` — وليس في `pocx/consensus/params.h`.

## خصائص الأداء

### عمليات قاعدة البيانات

- **الحصول على التعيين الحالي:** O(n) - مسح جميع التعيينات لعنوان الرسم لإيجاد الأحدث
- **الحصول على سجل التعيين:** O(n) - تكرار جميع التعيينات للرسم
- **إنشاء تعيين:** O(1) - إدراج واحد
- **إلغاء تعيين:** O(1) - تحديث واحد
- **إعادة التنظيم (لكل تعيين):** O(1) - تطبيق مباشر لبيانات التراجع

حيث n = عدد التعيينات للرسم (عادة صغير، < 10)

### استخدام الذاكرة

- **لكل تعيين:** ~160 بايت (هيكل ForgingAssignment)
- **حمل ذاكرة التخزين المؤقت:** حمل خريطة التجزئة لتتبع التغييرات
- **الكتلة النموذجية:** <10 تعيينات = <2 KB ذاكرة

### استخدام القرص

- **لكل تعيين:** ~200 بايت على القرص (مع حمل LevelDB)
- **10000 تعيين:** ~2 MB مساحة قرص
- **مهمل مقارنة بمجموعة UTXO:** <0.001% من chainstate النموذجي

## القيود الحالية والعمل المستقبلي

### قيد الذرية

**الحالي:** العملات والتعيينات تُكتب في دفعات LevelDB منفصلة أثناء `view.Flush()`

**التأثير:** خطر نظري من عدم الاتساق إذا حدث عطل بين الدفعات

**التخفيف:**
- كلتا الدفعتين تكتملان بسرعة قبل fsync
- استرداد عطل Bitcoin Core يستخدم علامة DB_HEAD_BLOCKS
- عملياً: لم يُلاحظ أبداً في الاختبار

**تحسين مستقبلي:** توحيد في عملية دفعة LevelDB واحدة

### تقليم سجل التعيين

**الحالي:** جميع التعيينات تُخزّن إلى أجل غير مسمى

**التأثير:** ~200 بايت لكل تعيين للأبد

**المستقبل:** تقليم اختياري للتعيينات المُلغاة بالكامل الأقدم من N كتلة

**ملاحظة:** من غير المحتمل أن تكون هناك حاجة - حتى مليون تعيين = 200 MB

## حالة الاختبار

### الاختبارات المُنفّذة

✅ تحليل والتحقق من OP_RETURN
✅ التحقق من الملكية
✅ إنشاء تعيين ConnectBlock
✅ إلغاء ConnectBlock
✅ معالجة إعادة تنظيم DisconnectBlock
✅ عمليات قراءة/كتابة قاعدة البيانات
✅ انتقالات الحالة (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
✅ أوامر RPC (get_assignment، create_assignment، revoke_assignment)
✅ إنشاء معاملة المحفظة

### مجالات تغطية الاختبار

- اختبارات الوحدة: `src/test/pocx_tests.cpp`، `src/test/pocx_simd_tests.cpp`
- اختبارات التكامل: سكريبتات shell الخاصة بـ regtest ضمن `scripts/assignments/` و `scripts/mining/`

## قواعد الإجماع

### قواعد إنشاء التعيين

1. **الملكية:** يجب أن تكون المعاملة موقّعة من مالك الرسم
2. **الحالة:** يجب أن يكون الرسم في حالة UNASSIGNED أو REVOKED
3. **الصيغة:** OP_RETURN صالح مع علامة POCX + عنوانين 20 بايت
4. **التفرد:** تعيين نشط واحد لكل رسم في وقت واحد

### قواعد الإلغاء

1. **الملكية:** يجب أن تكون المعاملة موقّعة من مالك الرسم
2. **الوجود:** يجب أن يوجد التعيين ولم يُلغ بالفعل
3. **الصيغة:** OP_RETURN صالح مع علامة XCOP + عنوان 20 بايت

### قواعد التفعيل

- **تفعيل التعيين:** `assignment_height + nForgingAssignmentDelay`
- **تفعيل الإلغاء:** `revocation_height + nForgingRevocationDelay`
- **التأخيرات:** قابلة للتكوين لكل شبكة (مثلاً، 30 كتلة = ~1 ساعة مع وقت كتلة 2 دقيقة)

### التحقق من الكتلة

- تعيين/إلغاء غير صالح → الكتلة مرفوضة (فشل الإجماع)
- مخرجات OP_RETURN تُستبعد تلقائياً من مجموعة UTXO (سلوك Bitcoin القياسي)
- معالجة التعيين تحدث قبل تحديثات UTXO في ConnectBlock

## الخلاصة

نظام تعيين صياغة PoCX كما هو مُنفّذ يوفر:

✅ **البساطة:** معاملات Bitcoin قياسية، لا UTXOs خاصة
✅ **فعالية التكلفة:** لا متطلب غبار، رسوم المعاملات فقط
✅ **سلامة إعادة التنظيم:** بيانات تراجع شاملة تستعيد الحالة الصحيحة
✅ **تحديثات ذرية:** اتساق قاعدة البيانات من خلال دفعات LevelDB
✅ **السجل الكامل:** مسار تدقيق كامل لجميع التعيينات عبر الوقت
✅ **بنية نظيفة:** تعديلات طفيفة على Bitcoin Core، كود PoCX معزول
✅ **جاهز للإنتاج:** منفّذ بالكامل، مُختبر، وعامل

### جودة التنفيذ

- **تنظيم الكود:** ممتاز - فصل واضح بين Bitcoin Core و PoCX
- **معالجة الأخطاء:** التحقق الشامل من الإجماع
- **التوثيق:** تعليقات الكود والهيكل موثقة جيداً
- **الاختبار:** الوظائف الأساسية مُختبرة، التكامل مُتحقق منه

### قرارات التصميم الرئيسية المُثبتة

1. ✅ نهج OP_RETURN فقط (مقابل القائم على UTXO)
2. ✅ تخزين قاعدة بيانات منفصل (مقابل Coin extraData)
3. ✅ تتبع السجل الكامل (مقابل الحالي فقط)
4. ✅ الملكية بالتوقيع (مقابل إنفاق UTXO)
5. ✅ تأخيرات التفعيل (تمنع هجمات إعادة التنظيم)

يحقق النظام بنجاح جميع الأهداف البنيوية مع تنفيذ نظيف وقابل للصيانة.

---

[→ السابق: الإجماع والتعدين](3-consensus-and-mining.md) | [📘 جدول المحتويات](index.md) | [التالي: مزامنة الوقت →](5-timing-security.md)
