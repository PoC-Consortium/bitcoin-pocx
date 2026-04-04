[→ السابق: صيغة الرسم](2-plot-format.md) | [📘 جدول المحتويات](index.md) | [التالي: تعيينات الصياغة →](4-forging-assignments.md)

---

# الفصل الثالث: إجماع وعملية تعدين Bitcoin-PoCX

المواصفات التقنية الكاملة لآلية إجماع PoCX (الجيل التالي من إثبات السعة) وعملية التعدين المدمجة في Bitcoin Core.

---

## جدول المحتويات

1. [نظرة عامة](#نظرة-عامة)
2. [بنية الإجماع](#بنية-الإجماع)
3. [عملية التعدين](#عملية-التعدين)
4. [التحقق من الكتلة](#التحقق-من-الكتلة)
5. [نظام التعيين](#نظام-التعيين)
6. [نشر الشبكة](#نشر-الشبكة)
7. [التفاصيل التقنية](#التفاصيل-التقنية)

---

## نظرة عامة

يُنفذ Bitcoin-PoCX آلية إجماع إثبات السعة الخالصة كبديل كامل لإثبات العمل في Bitcoin. هذه سلسلة جديدة بدون متطلبات توافق عكسي.

**الخصائص الرئيسية:**
- **كفاءة الطاقة:** التعدين يستخدم ملفات رسم مُولّدة مسبقاً بدلاً من التجزئة الحسابية
- **مواعيد نهائية مثنية الوقت:** تحويل التوزيع (أسي→مربع كاي) يقلل الكتل الطويلة، يحسّن متوسط أوقات الكتل
- **دعم التعيين:** يمكن لمالكي الرسم تفويض حقوق الصياغة لعناوين أخرى
- **تكامل C++ أصلي:** خوارزميات التشفير منفذة بـ C++ للتحقق من الإجماع

**تدفق التعدين:**
```
مُعدّن خارجي → get_mining_info → حساب Nonce → submit_nonce →
طابور الصياغة → انتظار الموعد النهائي → صياغة الكتلة → نشر الشبكة →
التحقق من الكتلة → توسيع السلسلة
```

---

## بنية الإجماع

### هيكل الكتلة

كتل PoCX توسّع هيكل كتلة Bitcoin بحقول إجماع إضافية:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // بذرة الرسم (32 بايت)
    std::array<uint8_t, 20> account_id;       // عنوان الرسم (hash160 20 بايت)
    uint32_t compression;                     // مستوى المقياس (1-6)
    uint64_t nonce;                           // nonce التعدين (64-bit)
    uint64_t quality;                         // الجودة المُدّعاة (مخرج تجزئة PoC)
};

class CBlockHeader {
    // حقول Bitcoin القياسية
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // حقول إجماع PoCX (تحل محل nBits و nNonce)
    int nHeight;                              // ارتفاع الكتلة (تحقق بدون سياق)
    uint256 generationSignature;              // توقيع التوليد (إنتروبيا التعدين)
    uint64_t nBaseTarget;                     // معلمة الصعوبة (صعوبة عكسية)
    PoCXProof pocxProof;                      // إثبات التعدين

    // حقول توقيع الكتلة
    std::array<uint8_t, 33> vchPubKey;        // مفتاح عام مضغوط (33 بايت)
    std::array<uint8_t, 65> vchSignature;     // توقيع مضغوط (65 بايت)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // المعاملات
};
```

**ملاحظة:** التوقيع (`vchSignature`) مستبعد من حساب تجزئة الكتلة لمنع القابلية للتغيير.

**التنفيذ:** `src/primitives/block.h`

### توقيع التوليد

توقيع التوليد يخلق إنتروبيا التعدين ويمنع هجمات الحساب المسبق.

**الحساب:**
```
generationSignature = dSHA256(prev_generationSignature || prev_account_id_20bytes)
```

**كتلة التكوين:** تستخدم توقيع توليد أولي مُشفّر

**التنفيذ:** `src/pocx/mining/block_context.cpp:GetNewBlockContext()`

### الهدف الأساسي (الصعوبة)

الهدف الأساسي هو معكوس الصعوبة - قيم أعلى تعني تعدين أسهل.

**خوارزمية التعديل:**
- هدف وقت الكتلة: 120 ثانية (الشبكة الرئيسية)، 1 ثانية (regtest)
- فترة التعديل: كل كتلة
- يستخدم المتوسط المتحرك للأهداف الأساسية الأخيرة
- محدود لمنع تقلبات الصعوبة الشديدة

**التنفيذ:** `src/consensus/params.h`، منطق تعديل الصعوبة في إنشاء الكتلة

### مستويات المقياس

يدعم PoCX إثبات العمل القابل للتطوير في ملفات الرسم من خلال مستويات المقياس (Xn).

**الحدود الديناميكية:**
```cpp
struct CompressionBounds {
    uint32_t nPoCXMinCompression;     // الحد الأدنى المقبول
    uint32_t nPoCXTargetCompression;  // المستوى الموصى به
};
```

**جدول زيادة المقياس:**
- فترات أسية: السنوات 4، 12، 28، 60، 124 (التنصيفات 1، 3، 7، 15، 31)
- الحد الأدنى لمستوى المقياس يزداد بـ 1
- المستوى المستهدف للمقياس يزداد بـ 1
- يحافظ على هامش الأمان بين تكاليف إنشاء الرسم والبحث
- أقصى مستوى مقياس: 255

**التنفيذ:** `src/pocx/consensus/params.h:GetPoCXCompressionBounds()`

---

## عملية التعدين

### 1. استرجاع معلومات التعدين

**أمر RPC:** `get_mining_info`

**العملية:**
1. استدعاء `GetNewBlockContext(chainman)` لجلب حالة سلسلة الكتل الحالية
2. حساب حدود الضغط الديناميكية للارتفاع الحالي
3. إرجاع معلمات التعدين

**الاستجابة:**
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

**التنفيذ:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**ملاحظات:**
- لا أقفال محتجزة أثناء توليد الاستجابة
- استحواذ السياق يتعامل مع `cs_main` داخلياً
- `block_hash` مضمّن للمرجع لكن لا يُستخدم في التحقق

### 2. التعدين الخارجي

**مسؤوليات المُعدّن الخارجي:**
1. قراءة ملفات الرسم من القرص
2. حساب scoop بناءً على توقيع التوليد والارتفاع
3. إيجاد nonce بأفضل موعد نهائي
4. الإرسال للعقدة عبر `submit_nonce`

**صيغة ملف الرسم:**
- مبنية على صيغة POC2 (Burstcoin)
- معززة بإصلاحات أمنية وتحسينات قابلية التوسع
- راجع الإسناد في `CLAUDE.md`

**تنفيذ المُعدّن:** خارجي (مثلاً، مبني على Scavenger)

### 3. إرسال والتحقق من Nonce

**أمر RPC:** `submit_nonce`

**المعلمات:**
```
height, generation_signature, account_id, seed, nonce, quality (اختياري)
```

**تدفق التحقق (ترتيب محسّن):**

#### الخطوة 1: التحقق السريع من الصيغة
```cpp
// Account ID: 40 حرف hex = 20 بايت
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 حرف hex = 32 بايت
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### الخطوة 2: استحواذ السياق
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// يُرجع: height, generation_signature, base_target, block_hash
```

**القفل:** `cs_main` يُعالج داخلياً، لا أقفال محتجزة في خيط RPC

#### الخطوة 3: التحقق من السياق
```cpp
// فحص الارتفاع
if (height != context.height) reject;

// فحص توقيع التوليد
if (submitted_gen_sig != context.generation_signature) reject;
```

#### الخطوة 4: التحقق من المحفظة
```cpp
// تحديد المُوقّع الفعال (مع مراعاة التعيينات)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// التحقق مما إذا كانت العقدة تملك المفتاح الخاص للمُوقّع الفعال
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**دعم التعيين:** قد يُعيّن مالك الرسم حقوق الصياغة لعنوان آخر. يجب أن تملك المحفظة مفتاح المُوقّع الفعال، ليس بالضرورة مالك الرسم.

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
    account_payload,     // 20 بايت
    block_height,
    nonce,
    seed,                // 32 bytes
    compression,
    &result             // Output: quality
);
```

**الخوارزمية:**
1. فك تشفير توقيع التوليد من hex
2. حساب أفضل جودة في نطاق الضغط باستخدام خوارزميات محسّنة لـ SIMD
3. التحقق من أن الجودة تستوفي متطلبات الصعوبة
4. إرجاع قيمة الجودة الخام

**التنفيذ:** `src/pocx/consensus/proof.cpp:pocx_validate_block()`

#### الخطوة 6: حساب ثني الوقت
```cpp
// الموعد النهائي الخام المُعدّل للصعوبة (بالثواني)
uint64_t deadline_seconds = quality / base_target;

// وقت الصياغة المثني (بالثواني)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**صيغة ثني الوقت:**
```
Y = scale * (X^(1/3))
حيث:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**الغرض:** يحوّل التوزيع الأسي إلى مربع كاي. الحلول الجيدة جداً تُصاغ لاحقاً (للشبكة وقت لمسح الأقراص)، الحلول الضعيفة تتحسن. يقلل الكتل الطويلة، يحافظ على متوسط 120 ثانية.

**التنفيذ:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Step 8: Forger Submission: إرسال للصائغ
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

**تصميم قائم على الطابور:**
- الإرسال ينجح دائماً (يُضاف للطابور)
- RPC يعود فوراً
- خيط العامل يعالج بشكل غير متزامن

**التنفيذ:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. معالجة طابور الصائغ

**البنية:**
- خيط عامل واحد مستمر
- طابور إرسال FIFO
- حالة صياغة بدون قفل (خيط العامل فقط)
- لا أقفال متداخلة (منع الجمود)

**الحلقة الرئيسية لخيط العامل:**
```cpp
while (!shutdown) {
    // 1. التحقق من الإرسالات المُطابورة
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. انتظار الموعد النهائي أو إرسال جديد
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**منطق ProcessSubmission:**
```cpp
1. الحصول على سياق جديد: GetNewBlockContext(*chainman)

2. فحوصات القِدم (تجاهل صامت):
   - عدم تطابق الارتفاع → تجاهل
   - عدم تطابق توقيع التوليد → تجاهل
   - تغير تجزئة كتلة الرأس (إعادة تنظيم) → إعادة تعيين حالة الصياغة

3. مقارنة الجودة:
   - إذا كانت الجودة >= الأفضل الحالي → تجاهل

4. حساب الموعد النهائي المثني للوقت:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. تحديث حالة الصياغة:
   - إلغاء الصياغة الموجودة (إذا وُجد أفضل)
   - تخزين: account_id, seed, nonce, quality, deadline
   - حساب: forge_time = block_time + deadline_seconds
   - تخزين تجزئة الرأس لكشف إعادة التنظيم
```

**التنفيذ:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. انتظار الموعد النهائي وصياغة الكتلة

**WaitForDeadlineOrNewSubmission:**

**شروط الانتظار:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**عند الوصول للموعد النهائي - التحقق من السياق الجديد:**
```cpp
1. الحصول على السياق الحالي: GetNewBlockContext(*chainman)

2. التحقق من الارتفاع:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. التحقق من توقيع التوليد:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. حالة حافة الهدف الأساسي:
   if (forging_base_target != current_base_target) {
       // إعادة حساب الموعد النهائي مع الهدف الأساسي الجديد
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // انتظار مرة أخرى
   }

5. كل شيء صالح → ForgeBlock()
```

**عملية ForgeBlock:**

```cpp
1. تحديد المُوقّع الفعال (دعم التعيين):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. إنشاء سكريبت coinbase:
   coinbase_script = P2WPKH(effective_signer);  // يدفع للمُوقّع الفعال

3. إنشاء قالب الكتلة:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. إضافة إثبات PoCX:
   block.pocxProof.account_id = plot_address;    // عنوان الرسم الأصلي
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;
   block.pocxProof.compression = compression;

5. إعادة حساب جذر ميركل:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. توقيع الكتلة:
   // استخدام مفتاح المُوقّع الفعال (قد يختلف عن مالك الرسم)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. الإرسال للسلسلة:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. معالجة النتيجة:
   if (accepted) {
       log_success();
       reset_forging_state();  // جاهز للكتلة التالية
   } else {
       log_failure();
       reset_forging_state();
   }
```

**التنفيذ:** `src/pocx/mining/block_builder.cpp:BuildBlock()`

**قرارات التصميم الرئيسية:**
- Coinbase يدفع للمُوقّع الفعال (يحترم التعيينات)
- الإثبات يحتوي عنوان الرسم الأصلي (للتحقق)
- التوقيع من مفتاح المُوقّع الفعال (إثبات الملكية)
- إنشاء القالب يتضمن معاملات mempool تلقائياً

---

## التحقق من الكتلة

### تدفق التحقق من الكتل الواردة

عند استلام كتلة من الشبكة أو إرسالها محلياً، تخضع للتحقق في مراحل متعددة:

### المرحلة 1: التحقق من الرأس (CheckBlockHeader)

**التحقق بدون سياق:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**تحقق PoCX (عند تعريف ENABLE_POCX):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // التحقق الأساسي من التوقيع (لا دعم تعيين بعد)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**التحقق الأساسي من التوقيع:**
1. التحقق من وجود حقول pubkey والتوقيع
2. التحقق من حجم pubkey (33 بايت مضغوط)
3. التحقق من حجم التوقيع (65 بايت مضغوط)
4. استرداد pubkey من التوقيع: `pubkey.RecoverCompact(hash, signature)`
5. التحقق من تطابق pubkey المسترد مع pubkey المُخزّن

**التنفيذ:** `src/validation.cpp:CheckBlockHeader()`
**منطق التوقيع:** `src/pocx/consensus/signature.cpp:VerifyPoCXBlockCompactSignature()`

### المرحلة 2: التحقق من الكتلة (CheckBlock)

**يتحقق من:**
- صحة جذر ميركل
- صلاحية المعاملات
- متطلبات Coinbase
- حدود حجم الكتلة
- قواعد إجماع Bitcoin القياسية

**التنفيذ:** `src/consensus/validation.cpp:CheckBlock()`

### المرحلة 3: التحقق السياقي من الرأس (ContextualCheckBlockHeader)

**التحقق الخاص بـ PoCX:**

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

**التنفيذ:** `src/validation.cpp:ContextualCheckBlockHeader()`

### المرحلة 4: اتصال الكتلة (ConnectBlock)

**التحقق السياقي الكامل:**

```cpp
#ifdef ENABLE_POCX
    // التحقق الموسع من التوقيع مع دعم التعيين
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**التحقق الموسع من التوقيع:**
1. تنفيذ التحقق الأساسي من التوقيع
2. استخراج account ID من pubkey المسترد
3. الحصول على المُوقّع الفعال لعنوان الرسم: `GetEffectiveSigner(plot_address, height, view)`
4. التحقق من تطابق حساب pubkey مع المُوقّع الفعال

**منطق التعيين:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // إرجاع المُوقّع المُعيّن
    }

    return plotAddress;  // لا تعيين - مالك الرسم يُوقّع
}
```

**التنفيذ:**
- الاتصال: `src/validation.cpp:ConnectBlock()`
- التحقق الموسع: `src/pocx/consensus/signature.cpp:VerifyPoCXBlockCompactSignature()`
- منطق التعيين: `src/pocx/assignments/assignment_state.cpp:GetEffectiveSigner()`

### المرحلة 5: تفعيل السلسلة

**تدفق ProcessNewBlock:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → التحقق والتخزين على القرص
    2. ActivateBestChain → تحديث رأس السلسلة إذا كانت هذه أفضل سلسلة
    3. إخطار الشبكة بالكتلة الجديدة
}
```

**التنفيذ:** `src/validation.cpp:ProcessNewBlock()`

### ملخص التحقق

**مسار التحقق الكامل:**
```
استلام الكتلة
    ↓
CheckBlockHeader (التوقيع الأساسي)
    ↓
CheckBlock (المعاملات، ميركل)
    ↓
ContextualCheckBlockHeader (توقيع التوليد، الهدف الأساسي، إثبات PoC، الموعد النهائي)
    ↓
ConnectBlock (التوقيع الموسع مع التعيينات، انتقالات الحالة)
    ↓
ActivateBestChain (معالجة إعادة التنظيم، توسيع السلسلة)
    ↓
نشر الشبكة
```

---

## نظام التعيين

### نظرة عامة

تسمح التعيينات لمالكي الرسم بتفويض حقوق الصياغة لعناوين أخرى مع الحفاظ على ملكية الرسم.

**حالات الاستخدام:**
- تعدين المجمعات (الرسومات تُعيّن لعنوان المجمع)
- التخزين البارد (مفتاح التعدين منفصل عن ملكية الرسم)
- التعدين متعدد الأطراف (بنية تحتية مشتركة)

### بنية التعيين

**تصميم OP_RETURN فقط:**
- التعيينات مُخزّنة في مخرجات OP_RETURN (لا UTXO)
- لا متطلبات إنفاق (لا غبار، لا رسوم للاحتفاظ)
- مُتتبّعة في حالة CCoinsViewCache الموسعة
- مُفعّلة بعد فترة تأخير (افتراضي: 4 كتل)

**حالات التعيين:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // لا تعيين موجود
    ASSIGNING = 1,   // التعيين في انتظار التفعيل (فترة التأخير)
    ASSIGNED = 2,    // التعيين نشط، الصياغة مسموحة
    REVOKING = 3,    // الإلغاء في الانتظار (فترة التأخير، لا يزال نشطاً)
    REVOKED = 4      // الإلغاء مكتمل، التعيين لم يعد نشطاً
};
```

### إنشاء التعيينات

**صيغة المعاملة:**
```cpp
Transaction {
    inputs: [any]  // يثبت ملكية عنوان الرسم
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**قواعد التحقق:**
1. يجب أن يكون المدخل موقّعاً من مالك الرسم (يثبت الملكية)
2. OP_RETURN يحتوي بيانات تعيين صالحة
3. يجب أن يكون الرسم UNASSIGNED أو REVOKED
4. لا تعيينات معلقة مكررة في mempool
5. رسوم معاملة دنيا مدفوعة

**التفعيل:**
- يصبح التعيين ASSIGNING عند ارتفاع التأكيد
- يصبح ASSIGNED بعد فترة التأخير (4 كتل regtest، 30 كتلة mainnet)
- التأخير يمنع إعادة التعيين السريعة أثناء سباقات الكتل

**التنفيذ:** `src/pocx/assignments/opcodes.h`، التحقق في ConnectBlock

### إلغاء التعيينات

**صيغة المعاملة:**
```cpp
Transaction {
    inputs: [any]  // يثبت ملكية عنوان الرسم
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**التأثير:**
- انتقال فوري للحالة إلى REVOKED
- مالك الرسم يمكنه الصياغة فوراً
- يمكن إنشاء تعيين جديد بعد ذلك

### التحقق من التعيين أثناء التعدين

**تحديد المُوقّع الفعال:**
```cpp
// في التحقق من submit_nonce
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// في صياغة الكتلة
coinbase_script = P2WPKH(effective_signer);  // المكافأة تذهب هنا

// في توقيع الكتلة
signature = effective_signer_key.SignCompact(hash);  // يجب التوقيع بالمُوقّع الفعال
```

**التحقق من الكتلة:**
```cpp
// في VerifyPoCXBlockCompactSignature (موسع)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**الخصائص الرئيسية:**
- الإثبات يحتوي دائماً عنوان الرسم الأصلي
- يجب أن يكون التوقيع من المُوقّع الفعال
- Coinbase يدفع للمُوقّع الفعال
- التحقق يستخدم حالة التعيين عند ارتفاع الكتلة

---

## نشر الشبكة

### إعلان الكتلة

**بروتوكول P2P القياسي لـ Bitcoin:**
1. الكتلة المُصاغة تُرسل عبر `ProcessNewBlock()`
2. الكتلة تُحقق وتُضاف للسلسلة
3. إخطار الشبكة: `GetMainSignals().BlockConnected()`
4. طبقة P2P تبث الكتلة للأقران

**التنفيذ:** معالجة الشبكة القياسية لـ Bitcoin Core

### ترحيل الكتلة

**الكتل المضغوطة (BIP 152):**
- تُستخدم لنشر الكتل الفعال
- معرفات المعاملات فقط تُرسل مبدئياً
- الأقران يطلبون المعاملات المفقودة

**ترحيل الكتلة الكامل:**
- احتياطي عندما تفشل الكتل المضغوطة
- بيانات الكتلة الكاملة تُنقل

### إعادة تنظيم السلسلة

**معالجة إعادة التنظيم:**
```cpp
// في خيط عامل الصائغ
if (current_tip_hash != stored_tip_hash) {
    // كُشفت إعادة تنظيم السلسلة
    reset_forging_state();
    log("Chain tip changed, resetting forging");
}
```

**مستوى سلسلة الكتل:**
- معالجة إعادة التنظيم القياسية لـ Bitcoin Core
- أفضل سلسلة تُحدد بـ chainwork
- الكتل المنفصلة تُعاد لـ mempool

---

## التفاصيل التقنية

### منع الجمود

**نمط جمود ABBA (ممنوع):**
```
الخيط A: cs_main → cs_wallet
الخيط B: cs_wallet → cs_main
```

**الحل:**
1. **submit_nonce:** صفر استخدام لـ cs_main
   - `GetNewBlockContext()` يتعامل مع القفل داخلياً
   - كل التحقق قبل إرسال الصائغ

2. **الصائغ:** بنية قائمة على الطابور
   - خيط عامل واحد (لا انضمام خيوط)
   - سياق جديد عند كل وصول
   - لا أقفال متداخلة

3. **فحوصات المحفظة:** تُنفذ قبل العمليات المكلفة
   - رفض مبكر إذا لم يتوفر مفتاح
   - منفصلة عن وصول حالة سلسلة الكتل

### تحسينات الأداء

**التحقق بالفشل السريع:**
```cpp
1. فحوصات الصيغة (فورية)
2. التحقق من السياق (خفيف)
3. التحقق من المحفظة (محلي)
4. التحقق من الإثبات (SIMD مكلف)
```

**جلب سياق واحد:**
- استدعاء `GetNewBlockContext()` واحد لكل إرسال
- تخزين النتائج مؤقتاً لفحوصات متعددة
- لا استحواذات متكررة على cs_main

**كفاءة الطابور:**
- هيكل إرسال خفيف
- لا base_target/deadline في الطابور (يُعاد حسابها حديثاً)
- بصمة ذاكرة دنيا

### معالجة القِدم

**تصميم صائغ "بسيط":**
- لا اشتراكات في أحداث سلسلة الكتل
- تحقق كسول عند الحاجة
- تجاهل صامت للإرسالات القديمة

**الفوائد:**
- بنية بسيطة
- لا مزامنة معقدة
- متين ضد الحالات الحافة

**الحالات الحافة المُعالجة:**
- تغييرات الارتفاع → تجاهل
- تغييرات توقيع التوليد → تجاهل
- تغييرات الهدف الأساسي → إعادة حساب الموعد النهائي
- إعادة التنظيم → إعادة تعيين حالة الصياغة

### التفاصيل التشفيرية

**توقيع التوليد:**
```cpp
dSHA256(prev_generation_signature || prev_account_id_20bytes)
```

**تجزئة توقيع الكتلة:**
```cpp
// Uses HashWriter (double-SHA256) with Bitcoin serialization (length-prefixed strings)
HashWriter hasher{};
hasher << POCX_BLOCK_MAGIC << block_hash.ToString();
hash = hasher.GetHash();  // double-SHA256
```

**صيغة التوقيع المضغوط:**
- 65 بايت: [recovery_id][r][s]
- يسمح باسترداد المفتاح العام
- يُستخدم لكفاءة المساحة

**معرف الحساب:**
- HASH160 20 بايت للمفتاح العام المضغوط
- يطابق صيغ عناوين Bitcoin (P2PKH، P2WPKH)

### التحسينات المستقبلية

**القيود الموثقة:**
1. لا مقاييس أداء (معدلات الإرسال، توزيعات المواعيد النهائية)
2. لا تصنيف مفصل للأخطاء للمُعدّنين
3. استعلام محدود لحالة الصائغ (الموعد النهائي الحالي، عمق الطابور)

**التحسينات المحتملة:**
- RPC لحالة الصائغ
- مقاييس كفاءة التعدين
- تسجيل معزز للتصحيح
- دعم بروتوكول المجمع

---

## مراجع الكود

**التنفيذات الأساسية:**
- واجهة RPC: `src/pocx/rpc/mining.cpp`
- طابور الصائغ: `src/pocx/mining/scheduler.cpp`
- التحقق من الإجماع: `src/pocx/consensus/proof.cpp`
- التحقق من الإثبات: `src/pocx/consensus/signature.cpp`
- ثني الوقت: `src/pocx/algorithms/time_bending.cpp`
- التحقق من الكتلة: `src/validation.cpp` (CheckBlockHeader، ConnectBlock)
- منطق التعيين: `src/pocx/assignments/assignment_state.cpp:GetEffectiveSigner()`
- إدارة السياق: `src/pocx/mining/block_context.cpp:GetNewBlockContext()`

**هياكل البيانات:**
- صيغة الكتلة: `src/primitives/block.h`
- معلمات الإجماع: `src/consensus/params.h`
- تتبع التعيين: `src/coins.h` (ملحقات CCoinsViewCache)

---

## الملحق: مواصفات الخوارزميات

### صيغة ثني الوقت

**التعريف الرياضي:**
```
deadline_seconds = quality / base_target  (خام)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

حيث:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**التنفيذ:**
- حساب نقطة ثابتة (صيغة Q42)
- حساب الجذر التكعيبي بأعداد صحيحة فقط
- محسّن لحساب 256-bit

### حساب الجودة

**العملية:**
1. توليد scoop من توقيع التوليد والارتفاع
2. قراءة بيانات الرسم لـ scoop المحسوب
3. التجزئة: `Shabal256Lite(scoop_data, generation_signature)`
4. اختبار مستويات المقياس من الحد الأدنى للأقصى
5. إرجاع أفضل جودة موجودة

**المقياس:**
- المستوى X0: خط أساس POC2 (نظري)
- المستوى X1: خط أساس XOR-transpose
- المستوى Xn: 2^(n-1) × عمل X1 مضمّن
- مقياس أعلى = عمل توليد رسم أكثر

### تعديل الهدف الأساسي

**تعديل كل كتلة:**
1. حساب المتوسط المتحرك للأهداف الأساسية الأخيرة
2. حساب الفترة الفعلية مقابل الفترة المستهدفة لنافذة متدحرجة
3. تعديل الهدف الأساسي بالتناسب
4. التحديد لمنع التقلبات الشديدة

**الصيغة:**
```
avg_base_target = moving_average(الأهداف الأساسية الأخيرة)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, ±20% of prev_base_target)
```

---

*يعكس هذا التوثيق التنفيذ الكامل لإجماع PoCX اعتباراً من أكتوبر 2025.*

---

[→ السابق: صيغة الرسم](2-plot-format.md) | [📘 جدول المحتويات](index.md) | [التالي: تعيينات الصياغة →](4-forging-assignments.md)
