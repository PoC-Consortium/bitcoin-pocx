[→ السابق: معلمات الشبكة](6-network-parameters.md) | [📘 جدول المحتويات](index.md) | [التالي: دليل المحفظة →](8-wallet-guide.md)

---

# الفصل السابع: مرجع واجهة RPC

مرجع كامل لأوامر RPC في Bitcoin-PoCX، بما في ذلك RPCs التعدين، وإدارة التعيينات، و RPCs سلسلة الكتل المُعدّلة.

---

## جدول المحتويات

1. [التكوين](#التكوين)
2. [RPCs تعدين PoCX](#rpcs-تعدين-pocx)
3. [RPCs التعيين](#rpcs-التعيين)
4. [RPCs سلسلة الكتل المُعدّلة](#rpcs-سلسلة-الكتل-المُعدّلة)
5. [RPCs المُعطّلة](#rpcs-المُعطّلة)
6. [أمثلة التكامل](#أمثلة-التكامل)

---

## التكوين

### وضع خادم التعدين

**العَلَم**: ``

**الغرض**: يُفعّل وصول RPC للمُعدّنين الخارجيين لاستدعاء RPCs الخاصة بالتعدين

**المتطلبات**:
- مطلوب لعمل `submit_nonce`
- مطلوب لظهور حوار تعيين الصياغة في محفظة Qt

**الاستخدام**:
```bash
# سطر الأوامر
./bitcoind

# bitcoin.conf
```

**اعتبارات الأمان**:
- لا مصادقة إضافية بخلاف بيانات اعتماد RPC القياسية
- RPCs التعدين محدودة المعدل بسعة الطابور
- مصادقة RPC القياسية لا تزال مطلوبة

**التنفيذ**: `src/pocx/rpc/mining.cpp`

---

## RPCs تعدين PoCX

### get_mining_info

**الفئة**: mining
**يتطلب خادم التعدين**: لا
**يتطلب محفظة**: لا

**الغرض**: يُرجع معلمات التعدين الحالية اللازمة للمُعدّنين الخارجيين لمسح ملفات الرسم وحساب المواعيد النهائية.

**المعلمات**: لا شيء

**القيم المُرجعة**:
```json
{
  "generation_signature": "abc123...",       // hex، 64 حرف
  "base_target": 36650387592,                // رقمي
  "height": 12345,                           // رقمي، ارتفاع الكتلة التالية
  "block_hash": "def456...",                 // hex، الكتلة السابقة
  "target_quality": 18446744073709551615,    // uint64_max (جميع الحلول مقبولة)
  "minimum_compression_level": 1,            // رقمي
  "target_compression_level": 2              // رقمي
}
```

**أوصاف الحقول**:
- `generation_signature`: إنتروبيا التعدين الحتمية لارتفاع الكتلة هذا
- `base_target`: الصعوبة الحالية (أعلى = أسهل)
- `height`: ارتفاع الكتلة الذي يجب أن يستهدفه المُعدّنون
- `block_hash`: تجزئة الكتلة السابقة (معلوماتي)
- `target_quality`: عتبة الجودة (حالياً uint64_max، لا تصفية)
- `minimum_compression_level`: الحد الأدنى للضغط المطلوب للتحقق
- `target_compression_level`: الضغط الموصى به للتعدين الأمثل

**رموز الخطأ**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: العقدة لا تزال تتزامن

**مثال**:
```bash
bitcoin-cli get_mining_info
```

**التنفيذ**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**الفئة**: mining
**يتطلب خادم التعدين**: نعم
**يتطلب محفظة**: نعم (للمفاتيح الخاصة)

**الغرض**: إرسال حل تعدين PoCX. يتحقق من الإثبات، يضعه في طابور للصياغة المثنية للوقت، ويُنشئ الكتلة تلقائياً في الوقت المجدول.

**Parameters**:
1. `block_hash` (string hex, required) - Previous block hash
2. `height` (numeric, required) - Block height
3. `generation_signature` (string hex, required) - Generation signature (64 characters)
4. `base_target` (numeric, required) - Base target for this block
5. `account_id` (string, required) - Account ID (20-byte hex or address)
6. `seed` (string, required) - Plot seed (64 hex characters = 32 bytes)
7. `nonce` (numeric, required) - Mining nonce
8. `compression` (numeric, required) - Compression level used (1-6)
9. `raw_quality` (numeric, required) - Raw quality from proof validation

**القيم المُرجعة** (النجاح):
```json
{
  "accepted": true,
  "quality": 120,           // الموعد النهائي المُعدّل للصعوبة بالثواني
  "poc_time": 45            // وقت الصياغة المثني بالثواني
}
```

**القيم المُرجعة** (الرفض):
```json
{
  "accepted": false,
  "error": "عدم تطابق توقيع التوليد"
}
```

**خطوات التحقق**:
1. **التحقق من الصيغة** (فشل سريع):
   - Account ID: بالضبط 40 حرف hex
   - Seed: بالضبط 64 حرف hex
2. **التحقق من السياق**:
   - الارتفاع يجب أن يطابق الرأس الحالي + 1
   - توقيع التوليد يجب أن يطابق الحالي
3. **التحقق من المحفظة**:
   - تحديد المُوقّع الفعال (التحقق من التعيينات النشطة)
   - التحقق من أن المحفظة تملك المفتاح الخاص للمُوقّع الفعال
4. **التحقق من الإثبات** (مكلف):
   - التحقق من إثبات PoCX مع حدود الضغط
   - حساب الجودة الخام
5. **إرسال للمجدول**:
   - وضع nonce في الطابور للصياغة المثنية للوقت
   - الكتلة ستُنشأ تلقائياً عند forge_time

**رموز الخطأ**:
- `RPC_INVALID_PARAMETER`: صيغة غير صالحة (account_id، seed) أو عدم تطابق الارتفاع
- `RPC_VERIFY_REJECTED`: عدم تطابق توقيع التوليد أو فشل التحقق من الإثبات
- `RPC_INVALID_ADDRESS_OR_KEY`: لا مفتاح خاص للمُوقّع الفعال
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: طابور الإرسال ممتلئ
- `RPC_INTERNAL_ERROR`: فشل تهيئة مجدول PoCX

**رموز خطأ التحقق من الإثبات**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**مثال**:
```bash
bitcoin-cli submit_nonce \
  "blockhash..." \
  12345 \
  "gensig..." \
  18325193796 \
  "1234567890abcdef1234567890abcdef12345678" \
  "seed..." \
  999888777 \
  1 \
  123456789
```

**ملاحظات**:
- الإرسال غير متزامن - RPC يعود فوراً، الكتلة تُصاغ لاحقاً
- ثني الوقت يؤخر الحلول الجيدة للسماح بمسح الرسم على مستوى الشبكة
- نظام التعيين: إذا كان الرسم مُعيّناً، يجب أن تملك المحفظة مفتاح عنوان الصياغة
- حدود الضغط تُعدّل ديناميكياً بناءً على ارتفاع الكتلة

**التنفيذ**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## RPCs التعيين

### get_assignment

**الفئة**: mining
**يتطلب خادم التعدين**: لا
**يتطلب محفظة**: لا

**الغرض**: استعلام حالة تعيين الصياغة لعنوان رسم. للقراءة فقط، لا تتطلب محفظة.

**المعلمات**:
1. `plot_address` (سلسلة، مطلوب) - عنوان الرسم (صيغة P2WPKH bech32)
2. `height` (رقمي، اختياري) - ارتفاع الكتلة للاستعلام (افتراضي: الرأس الحالي)

**القيم المُرجعة** (لا تعيين):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**القيم المُرجعة** (تعيين نشط):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030
}
```

**القيم المُرجعة** (قيد الإلغاء):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "REVOKING",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030,
  "revoked": true,
  "revocation_txid": "def456...",
  "revocation_height": 12300,
  "revocation_effective_height": 13020
}
```

**حالات التعيين**:
- `UNASSIGNED`: لا تعيين موجود
- `ASSIGNING`: معاملة التعيين مؤكدة، تأخير التفعيل قيد التقدم
- `ASSIGNED`: التعيين نشط، حقوق الصياغة مُفوّضة
- `REVOKING`: معاملة الإلغاء مؤكدة، لا يزال نشطاً حتى انقضاء التأخير
- `REVOKED`: الإلغاء مكتمل، حقوق الصياغة عادت لمالك الرسم

**رموز الخطأ**:
- `RPC_INVALID_ADDRESS_OR_KEY`: عنوان غير صالح أو ليس P2WPKH (bech32)

**مثال**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**التنفيذ**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**الفئة**: wallet
**يتطلب خادم التعدين**: لا
**يتطلب محفظة**: نعم (يجب أن تكون مُحمّلة ومفتوحة)

**الغرض**: إنشاء معاملة تعيين صياغة لتفويض حقوق الصياغة لعنوان آخر (مثلاً، مجمع تعدين).

**المعلمات**:
1. `plot_address` (سلسلة، مطلوب) - عنوان مالك الرسم (يجب ملك المفتاح الخاص، P2WPKH bech32)
2. `forging_address` (سلسلة، مطلوب) - العنوان لتعيين حقوق الصياغة له (P2WPKH bech32)
3. `fee_rate` (رقمي، اختياري) - معدل الرسوم بـ BTC/kvB (افتراضي: 10× minRelayFee)

**القيم المُرجعة**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**المتطلبات**:
- المحفظة مُحمّلة ومفتوحة
- المفتاح الخاص لـ plot_address في المحفظة
- كلا العنوانين يجب أن يكونا P2WPKH (صيغة bech32: pocx1q... mainnet، tpocx1q... testnet)
- عنوان الرسم يجب أن يملك UTXOs مؤكدة (يثبت الملكية)
- الرسم يجب ألا يملك تعيين نشط (استخدم إلغاء أولاً)

**هيكل المعاملة**:
- المدخل: UTXO من عنوان الرسم (يثبت الملكية)
- المخرج: OP_RETURN (46 بايت): علامة `POCX` + plot_address (20 بايت) + forging_address (20 بايت)
- المخرج: التغيير يُعاد للمحفظة

**التفعيل**:
- التعيين يصبح ASSIGNING عند التأكيد
- يصبح ACTIVE بعد `nForgingAssignmentDelay` كتلة
- التأخير يمنع إعادة التعيين السريعة أثناء تفرعات السلسلة

**رموز الخطأ**:
- `RPC_WALLET_NOT_FOUND`: لا محفظة متاحة
- `RPC_WALLET_UNLOCK_NEEDED`: المحفظة مشفرة ومقفلة
- `RPC_WALLET_ERROR`: فشل إنشاء المعاملة
- `RPC_INVALID_ADDRESS_OR_KEY`: صيغة عنوان غير صالحة

**مثال**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**التنفيذ**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**الفئة**: wallet
**يتطلب خادم التعدين**: لا
**يتطلب محفظة**: نعم (يجب أن تكون مُحمّلة ومفتوحة)

**الغرض**: إلغاء تعيين صياغة موجود، إعادة حقوق الصياغة لمالك الرسم.

**المعلمات**:
1. `plot_address` (سلسلة، مطلوب) - عنوان الرسم (يجب ملك المفتاح الخاص، P2WPKH bech32)
2. `fee_rate` (رقمي، اختياري) - معدل الرسوم بـ BTC/kvB (افتراضي: 10× minRelayFee)

**القيم المُرجعة**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**المتطلبات**:
- المحفظة مُحمّلة ومفتوحة
- المفتاح الخاص لـ plot_address في المحفظة
- عنوان الرسم يجب أن يكون P2WPKH (صيغة bech32)
- عنوان الرسم يجب أن يملك UTXOs مؤكدة

**هيكل المعاملة**:
- المدخل: UTXO من عنوان الرسم (يثبت الملكية)
- المخرج: OP_RETURN (26 بايت): علامة `XCOP` + plot_address (20 بايت)
- المخرج: التغيير يُعاد للمحفظة

**التأثير**:
- الحالة تنتقل إلى REVOKING فوراً
- عنوان الصياغة لا يزال يمكنه الصياغة خلال فترة التأخير
- يصبح REVOKED بعد `nForgingRevocationDelay` كتلة
- مالك الرسم يمكنه الصياغة بعد أن يصبح الإلغاء فعالاً
- يمكن إنشاء تعيين جديد بعد اكتمال الإلغاء

**رموز الخطأ**:
- `RPC_WALLET_NOT_FOUND`: لا محفظة متاحة
- `RPC_WALLET_UNLOCK_NEEDED`: المحفظة مشفرة ومقفلة
- `RPC_WALLET_ERROR`: فشل إنشاء المعاملة

**مثال**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**ملاحظات**:
- تماثل العملية: يمكن الإلغاء حتى لو لم يوجد تعيين نشط
- لا يمكن إلغاء الإلغاء بمجرد إرساله

**التنفيذ**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## RPCs سلسلة الكتل المُعدّلة

### getdifficulty

**تعديلات PoCX**:
- **الحساب**: `reference_base_target / current_base_target`
- **المرجع**: سعة شبكة 1 TiB (base_target = 36650387592)
- **التفسير**: سعة التخزين المُقدّرة للشبكة بـ TiB
  - مثال: `1.0` = ~1 TiB
  - مثال: `1024.0` = ~1 PiB
- **الفرق عن PoW**: يمثل السعة، ليس قوة التجزئة

**مثال**:
```bash
bitcoin-cli getdifficulty
# يُرجع: 2048.5 (الشبكة ~2 PiB)
```

**التنفيذ**: `src/rpc/blockchain.cpp`

---

### getblockheader

**الحقول المُضافة لـ PoCX**:
- `time_since_last_block` (رقمي) - الثواني منذ الكتلة السابقة (يحل محل mediantime)
- `poc_time` (رقمي) - وقت الصياغة المثني بالثواني
- `base_target` (رقمي) - الهدف الأساسي لصعوبة PoCX
- `generation_signature` (سلسلة hex) - توقيع التوليد
- `pocx_proof` (كائن):
  - `account_id` (سلسلة hex) - معرف حساب الرسم (20 بايت)
  - `seed` (سلسلة hex) - بذرة الرسم (32 بايت)
  - `nonce` (رقمي) - nonce التعدين
  - `compression` (رقمي) - مستوى المقياس المستخدم
  - `quality` (رقمي) - قيمة الجودة المُدّعاة
- `pubkey` (سلسلة hex) - المفتاح العام لموقّع الكتلة (33 بايت)
- `signer_address` (سلسلة) - عنوان موقّع الكتلة
- `signature` (سلسلة hex) - توقيع الكتلة (65 بايت)

**الحقول المُزالة لـ PoCX**:
- `mediantime` - مُزال (يحل محله time_since_last_block)

**مثال**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**التنفيذ**: `src/rpc/blockchain.cpp`

---

### getblock

**تعديلات PoCX**: نفس getblockheader، بالإضافة لبيانات المعاملات الكاملة

**مثال**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # تفصيلي مع تفاصيل المعاملات
```

**التنفيذ**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**الحقول المُضافة لـ PoCX**:
- `base_target` (رقمي) - الهدف الأساسي الحالي
- `generation_signature` (سلسلة hex) - توقيع التوليد الحالي

**الحقول المُعدّلة لـ PoCX**:
- `difficulty` - يستخدم حساب PoCX (قائم على السعة)

**الحقول المُزالة لـ PoCX**:
- `mediantime` - مُزال

**مثال**:
```bash
bitcoin-cli getblockchaininfo
```

**التنفيذ**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**الحقول المُضافة لـ PoCX**:
- `generation_signature` (سلسلة hex) - لتعدين المجمعات
- `base_target` (رقمي) - لتعدين المجمعات

**الحقول المُزالة لـ PoCX**:
- `target` - مُزال (خاص بـ PoW)
- `noncerange` - مُزال (خاص بـ PoW)
- `bits` - مُزال (خاص بـ PoW)

**ملاحظات**:
- لا يزال يتضمن بيانات المعاملات الكاملة لبناء الكتلة
- يُستخدم من خوادم المجمعات للتعدين المنسق

**مثال**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**التنفيذ**: `src/rpc/mining.cpp`

---

## RPCs المُعطّلة

RPCs التالية الخاصة بـ PoW **مُعطّلة** في وضع PoCX:

### getnetworkhashps
- **السبب**: معدل التجزئة غير قابل للتطبيق على إثبات السعة
- **البديل**: استخدم `getdifficulty` لتقدير سعة الشبكة

### getmininginfo
- **السبب**: يُرجع معلومات خاصة بـ PoW
- **البديل**: استخدم `get_mining_info` (خاص بـ PoCX)

### generate، generatetoaddress، generatetodescriptor، generateblock
- **السبب**: تعدين CPU غير قابل للتطبيق على PoCX (يتطلب رسومات مُولّدة مسبقاً)
- **البديل**: استخدم راسم خارجي + مُعدّن + `submit_nonce`

**التنفيذ**: `src/rpc/mining.cpp` (RPCs تُرجع خطأ عند تعريف ENABLE_POCX)

---

## أمثلة التكامل

### تكامل المُعدّن الخارجي

**حلقة التعدين الأساسية**:
```python
import requests
import time

RPC_URL = "http://user:pass@localhost:8332"

def rpc_call(method, params=[]):
    payload = {
        "jsonrpc": "2.0",
        "id": "miner",
        "method": method,
        "params": params
    }
    response = requests.post(RPC_URL, json=payload)
    return response.json()["result"]

# حلقة التعدين
while True:
    # 1. الحصول على معلمات التعدين
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    compression_bounds.nPoCXMinCompression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. مسح ملفات الرسم (تنفيذ خارجي)
    best_nonce = scan_plots(gen_sig, height)

    # 3. إرسال أفضل حل
    result = rpc_call("submit_nonce", [
        info["block_hash"],
        height,
        gen_sig,
        base_target,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"],
        best_nonce["compression"],
        best_nonce["raw_quality"]
    ])

    if result["accepted"]:
        print(f"الحل مقبول! الجودة: {result['quality']}ث، "
              f"وقت الصياغة: {result['poc_time']}ث")

    # 4. انتظار الكتلة التالية
    time.sleep(10)  # فترة الاستطلاع
```

---

### نمط تكامل المجمع

**سير عمل خادم المجمع**:
1. المُعدّنون يُنشئون تعيينات صياغة لعنوان المجمع
2. المجمع يُشغّل محفظة بمفاتيح عنوان الصياغة
3. المجمع يستدعي `get_mining_info` ويوزع للمُعدّنين
4. المُعدّنون يُرسلون الحلول عبر المجمع (ليس مباشرة للسلسلة)
5. المجمع يتحقق ويستدعي `submit_nonce` بمفاتيح المجمع
6. المجمع يوزع المكافآت وفق سياسة المجمع

**إدارة التعيينات**:
```bash
# المُعدّن يُنشئ تعيين (من محفظة المُعدّن)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# انتظار التفعيل (30 كتلة mainnet)

# المجمع يفحص حالة التعيين
bitcoin-cli get_assignment "pocx1qminer_plot..."

# المجمع يمكنه الآن إرسال nonces لهذا الرسم
# (محفظة المجمع يجب أن تملك المفتاح الخاص لـ pocx1qpool...)
```

---

### استعلامات مستكشف الكتل

**استعلام بيانات كتلة PoCX**:
```bash
# الحصول على آخر كتلة
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# الحصول على تفاصيل الكتلة مع إثبات PoCX
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# استخراج الحقول الخاصة بـ PoCX
echo $BLOCK | jq '{
  height: .height,
  time_since_last: .time_since_last_block,
  poc_time: .poc_time,
  base_target: .base_target,
  generation_signature: .generation_signature,
  pocx_proof: .pocx_proof,
  miner_address: .tx[0].vout[0].scriptPubKey.address
}'
```

**كشف معاملات التعيين**:
```bash
# مسح المعاملة لـ OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# التحقق من علامة التعيين (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## معالجة الأخطاء

### أنماط الأخطاء الشائعة

**عدم تطابق الارتفاع**:
```json
{
  "accepted": false,
  "error": "عدم تطابق الارتفاع: المُرسل 12345، الحالي 12346"
}
```
**الحل**: أعد جلب معلومات التعدين، السلسلة تقدمت

**عدم تطابق توقيع التوليد**:
```json
{
  "accepted": false,
  "error": "عدم تطابق توقيع التوليد"
}
```
**الحل**: أعد جلب معلومات التعدين، كتلة جديدة وصلت

**لا مفتاح خاص**:
```json
{
  "code": -5,
  "message": "لا مفتاح خاص متاح للمُوقّع الفعال"
}
```
**الحل**: استورد المفتاح لعنوان الرسم أو عنوان الصياغة

**تفعيل التعيين معلق**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**الحل**: انتظر انقضاء تأخير التفعيل

---

## مراجع الكود

**RPCs التعدين**: `src/pocx/rpc/mining.cpp`
**RPCs التعيين**: `src/pocx/rpc/assignments.cpp`، `src/pocx/rpc/assignments_wallet.cpp`
**RPCs سلسلة الكتل**: `src/rpc/blockchain.cpp`
**التحقق من الإثبات**: `src/pocx/consensus/proof.cpp`، `src/pocx/consensus/signature.cpp`
**حالة التعيين**: `src/pocx/assignments/assignment_state.cpp`
**إنشاء المعاملة**: `src/pocx/assignments/transactions.cpp`

---

## المراجع التبادلية

الفصول ذات الصلة:
- [الفصل الثالث: الإجماع والتعدين](3-consensus-and-mining.md) - تفاصيل عملية التعدين
- [الفصل الرابع: تعيينات الصياغة](4-forging-assignments.md) - بنية نظام التعيين
- [الفصل السادس: معلمات الشبكة](6-network-parameters.md) - قيم تأخير التعيين
- [الفصل الثامن: دليل المحفظة](8-wallet-guide.md) - واجهة المستخدم لإدارة التعيينات

---

[→ السابق: معلمات الشبكة](6-network-parameters.md) | [📘 جدول المحتويات](index.md) | [التالي: دليل المحفظة →](8-wallet-guide.md)
