[← הקודם: פרמטרי רשת](6-network-parameters.md) | [📘 תוכן העניינים](index.md) | [הבא: מדריך ארנק →](8-wallet-guide.md)

---

# פרק 7: עיון בממשק RPC

מדריך מלא לפקודות RPC של Bitcoin-PoCX, כולל קריאות RPC לכרייה, ניהול הקצאות, וקריאות RPC blockchain ששונו.

---

## תוכן העניינים

1. [תצורה](#תצורה)
2. [קריאות RPC כריית PoCX](#קריאות-rpc-כריית-pocx)
3. [קריאות RPC הקצאה](#קריאות-rpc-הקצאה)
4. [קריאות RPC Blockchain ששונו](#קריאות-rpc-blockchain-ששונו)
5. [קריאות RPC מושבתות](#קריאות-rpc-מושבתות)
6. [דוגמאות אינטגרציה](#דוגמאות-אינטגרציה)

---

## תצורה

### מצב שרת כרייה

**דגל**: `-miningserver`

**מטרה**: מאפשר גישת RPC לכורים חיצוניים לקרוא לקריאות RPC ספציפיות לכרייה

**דרישות**:
- נדרש ל-`submit_nonce` לפעול
- נדרש לנראות של דיאלוג הקצאת כרייה בארנק Qt

**שימוש**:
```bash
# שורת פקודה
./bitcoind -miningserver

# bitcoin.conf
miningserver=1
```

**שיקולי אבטחה**:
- אין אימות נוסף מעבר לאישורי RPC סטנדרטיים
- קריאות RPC כרייה מוגבלות בקצב על ידי קיבולת תור
- אימות RPC סטנדרטי עדיין נדרש

**יישום**: `src/pocx/rpc/mining.cpp`

---

## קריאות RPC כריית PoCX

### get_mining_info

**קטגוריה**: mining
**דורש שרת כרייה**: לא
**דורש ארנק**: לא

**מטרה**: מחזיר פרמטרי כרייה נוכחיים הנדרשים לכורים חיצוניים לסרוק קובצי plot ולחשב deadlines.

**פרמטרים**: אין

**ערכי החזרה**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 תווים
  "base_target": 36650387593,                // מספרי
  "height": 12345,                           // מספרי, גובה בלוק הבא
  "block_hash": "def456...",                 // hex, בלוק קודם
  "target_quality": 18446744073709551615,    // uint64_max (כל הפתרונות מתקבלים)
  "minimum_compression_level": 1,            // מספרי
  "target_compression_level": 2              // מספרי
}
```

**תיאורי שדות**:
- `generation_signature`: אנטרופיית כרייה דטרמיניסטית לגובה בלוק זה
- `base_target`: קושי נוכחי (גבוה יותר = קל יותר)
- `height`: גובה בלוק שכורים צריכים למקד
- `block_hash`: hash בלוק קודם (מידע)
- `target_quality`: סף איכות (כרגע uint64_max, ללא סינון)
- `minimum_compression_level`: דחיסה מינימלית נדרשת לאימות
- `target_compression_level`: דחיסה מומלצת לכרייה אופטימלית

**קודי שגיאה**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: הצומת עדיין מסנכרן

**דוגמה**:
```bash
bitcoin-cli get_mining_info
```

**יישום**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**קטגוריה**: mining
**דורש שרת כרייה**: כן
**דורש ארנק**: כן (למפתחות פרטיים)

**מטרה**: הגש פתרון כריית PoCX. מאמת הוכחה, מכניס לתור לכרייה עם עיקום זמן, ויוצר בלוק אוטומטית בזמן המתוזמן.

**פרמטרים**:
1. `height` (מספרי, נדרש) - גובה בלוק
2. `generation_signature` (מחרוזת hex, נדרש) - חתימת יצירה (64 תווים)
3. `account_id` (מחרוזת, נדרש) - מזהה חשבון plot (40 תווי hex = 20 בתים)
4. `seed` (מחרוזת, נדרש) - seed של plot (64 תווי hex = 32 בתים)
5. `nonce` (מספרי, נדרש) - nonce כרייה
6. `compression` (מספרי, נדרש) - רמת סילום/דחיסה שנעשה בה שימוש (1-255)
7. `quality` (מספרי, אופציונלי) - ערך איכות (מחושב מחדש אם נשמט)

**ערכי החזרה** (הצלחה):
```json
{
  "accepted": true,
  "quality": 120,           // deadline מותאם קושי בשניות
  "poc_time": 45            // זמן כרייה עם עיקום זמן בשניות
}
```

**ערכי החזרה** (נדחה):
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```

**שלבי אימות**:
1. **אימות פורמט** (fail-fast):
   - Account ID: בדיוק 40 תווי hex
   - Seed: בדיוק 64 תווי hex
2. **אימות הקשר**:
   - גובה חייב להתאים ל-tip נוכחי + 1
   - חתימת יצירה חייבת להתאים לנוכחית
3. **אימות ארנק**:
   - קבע חותם אפקטיבי (בדוק הקצאות פעילות)
   - אמת שלארנק יש מפתח פרטי לחותם אפקטיבי
4. **אימות הוכחה** (יקר):
   - אמת הוכחת PoCX עם גבולות דחיסה
   - חשב איכות גולמית
5. **הגשה למתזמן**:
   - הכנס nonce לתור לכרייה עם עיקום זמן
   - בלוק ייווצר אוטומטית ב-forge_time

**קודי שגיאה**:
- `RPC_INVALID_PARAMETER`: פורמט לא תקף (account_id, seed) או חוסר התאמה בגובה
- `RPC_VERIFY_REJECTED`: חוסר התאמה בחתימת יצירה או אימות הוכחה נכשל
- `RPC_INVALID_ADDRESS_OR_KEY`: אין מפתח פרטי לחותם אפקטיבי
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: תור הגשה מלא
- `RPC_INTERNAL_ERROR`: נכשלה אתחול מתזמן PoCX

**קודי שגיאת אימות הוכחה**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**דוגמה**:
```bash
bitcoin-cli submit_nonce 12345 \
  "abc123..." \
  "1234567890abcdef1234567890abcdef12345678" \
  "plot_seed_64_hex_characters..." \
  999888777 \
  1
```

**הערות**:
- הגשה היא אסינכרונית - RPC חוזר מיד, בלוק נכרה מאוחר יותר
- עיקום זמן מעכב פתרונות טובים כדי לאפשר סריקת plots ברחבי הרשת
- מערכת הקצאות: אם plot מוקצה, הארנק חייב להחזיק מפתח כתובת כרייה
- גבולות דחיסה מותאמים דינמית על בסיס גובה בלוק

**יישום**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## קריאות RPC הקצאה

### get_assignment

**קטגוריה**: mining
**דורש שרת כרייה**: לא
**דורש ארנק**: לא

**מטרה**: שאילתת סטטוס הקצאת כרייה לכתובת plot. קריאה בלבד, אין צורך בארנק.

**פרמטרים**:
1. `plot_address` (מחרוזת, נדרש) - כתובת plot (פורמט bech32 P2WPKH)
2. `height` (מספרי, אופציונלי) - גובה בלוק לשאילתה (ברירת מחדל: tip נוכחי)

**ערכי החזרה** (ללא הקצאה):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**ערכי החזרה** (הקצאה פעילה):
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

**ערכי החזרה** (בתהליך ביטול):
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

**מצבי הקצאה**:
- `UNASSIGNED`: אין הקצאה קיימת
- `ASSIGNING`: עסקת הקצאה אושרה, עיכוב הפעלה בתהליך
- `ASSIGNED`: הקצאה פעילה, זכויות כרייה הואצלו
- `REVOKING`: עסקת ביטול אושרה, עדיין פעיל עד שעיכוב מסתיים
- `REVOKED`: ביטול הושלם, זכויות כרייה חזרו לבעל plot

**קודי שגיאה**:
- `RPC_INVALID_ADDRESS_OR_KEY`: כתובת לא תקפה או לא P2WPKH (bech32)

**דוגמה**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**יישום**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**קטגוריה**: wallet
**דורש שרת כרייה**: לא
**דורש ארנק**: כן (חייב להיות טעון ופתוח)

**מטרה**: יצירת עסקת הקצאת כרייה להאצלת זכויות כרייה לכתובת אחרת (למשל, בריכת כרייה).

**פרמטרים**:
1. `plot_address` (מחרוזת, נדרש) - כתובת בעל plot (חייב להחזיק מפתח פרטי, P2WPKH bech32)
2. `forging_address` (מחרוזת, נדרש) - כתובת להקצאת זכויות כרייה אליה (P2WPKH bech32)
3. `fee_rate` (מספרי, אופציונלי) - קצב עמלה ב-BTC/kvB (ברירת מחדל: 10× minRelayFee)

**ערכי החזרה**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**דרישות**:
- ארנק טעון ופתוח
- מפתח פרטי ל-plot_address בארנק
- שתי הכתובות חייבות להיות P2WPKH (פורמט bech32: pocx1q... mainnet, tpocx1q... testnet)
- לכתובת plot חייבים להיות UTXOs מאושרים (מוכיח בעלות)
- ל-plot אסור שתהיה הקצאה פעילה (השתמש בביטול קודם)

**מבנה עסקה**:
- קלט: UTXO מכתובת plot (מוכיח בעלות)
- פלט: OP_RETURN (46 בתים): סמן `POCX` + plot_address (20 בתים) + forging_address (20 בתים)
- פלט: עודף חוזר לארנק

**הפעלה**:
- הקצאה הופכת ל-ASSIGNING באישור
- הופכת ל-ACTIVE לאחר `nForgingAssignmentDelay` בלוקים
- עיכוב מונע הקצאה מחדש מהירה במהלך פיצולי שרשרת

**קודי שגיאה**:
- `RPC_WALLET_NOT_FOUND`: אין ארנק זמין
- `RPC_WALLET_UNLOCK_NEEDED`: ארנק מוצפן ונעול
- `RPC_WALLET_ERROR`: יצירת עסקה נכשלה
- `RPC_INVALID_ADDRESS_OR_KEY`: פורמט כתובת לא תקף

**דוגמה**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**יישום**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**קטגוריה**: wallet
**דורש שרת כרייה**: לא
**דורש ארנק**: כן (חייב להיות טעון ופתוח)

**מטרה**: ביטול הקצאת כרייה קיימת, החזרת זכויות כרייה לבעל plot.

**פרמטרים**:
1. `plot_address` (מחרוזת, נדרש) - כתובת plot (חייב להחזיק מפתח פרטי, P2WPKH bech32)
2. `fee_rate` (מספרי, אופציונלי) - קצב עמלה ב-BTC/kvB (ברירת מחדל: 10× minRelayFee)

**ערכי החזרה**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**דרישות**:
- ארנק טעון ופתוח
- מפתח פרטי ל-plot_address בארנק
- כתובת plot חייבת להיות P2WPKH (פורמט bech32)
- לכתובת plot חייבים להיות UTXOs מאושרים

**מבנה עסקה**:
- קלט: UTXO מכתובת plot (מוכיח בעלות)
- פלט: OP_RETURN (26 בתים): סמן `XCOP` + plot_address (20 בתים)
- פלט: עודף חוזר לארנק

**אפקט**:
- מצב עובר ל-REVOKING מיד
- כתובת כרייה יכולה עדיין לכרות במהלך תקופת עיכוב
- הופך ל-REVOKED לאחר `nForgingRevocationDelay` בלוקים
- בעל plot יכול לכרות לאחר שביטול אפקטיבי
- יכול ליצור הקצאה חדשה לאחר השלמת ביטול

**קודי שגיאה**:
- `RPC_WALLET_NOT_FOUND`: אין ארנק זמין
- `RPC_WALLET_UNLOCK_NEEDED`: ארנק מוצפן ונעול
- `RPC_WALLET_ERROR`: יצירת עסקה נכשלה

**דוגמה**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**הערות**:
- Idempotent: ניתן לבטל גם אם אין הקצאה פעילה
- לא ניתן לבטל ביטול לאחר הגשה

**יישום**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## קריאות RPC Blockchain ששונו

### getdifficulty

**שינויי PoCX**:
- **חישוב**: `reference_base_target / current_base_target`
- **הפניה**: קיבולת רשת 1 TiB (base_target = 36650387593)
- **פרשנות**: קיבולת אחסון רשת משוערת ב-TiB
  - דוגמה: `1.0` = ~1 TiB
  - דוגמה: `1024.0` = ~1 PiB
- **הבדל מ-PoW**: מייצג קיבולת, לא כוח hash

**דוגמה**:
```bash
bitcoin-cli getdifficulty
# מחזיר: 2048.5 (רשת ~2 PiB)
```

**יישום**: `src/rpc/blockchain.cpp`

---

### getblockheader

**שדות PoCX שנוספו**:
- `time_since_last_block` (מספרי) - שניות מאז בלוק קודם (מחליף mediantime)
- `poc_time` (מספרי) - זמן כרייה עם עיקום זמן בשניות
- `base_target` (מספרי) - base target קושי PoCX
- `generation_signature` (מחרוזת hex) - חתימת יצירה
- `pocx_proof` (אובייקט):
  - `account_id` (מחרוזת hex) - מזהה חשבון plot (20 בתים)
  - `seed` (מחרוזת hex) - seed של plot (32 בתים)
  - `nonce` (מספרי) - nonce כרייה
  - `compression` (מספרי) - רמת סילום שנעשה בה שימוש
  - `quality` (מספרי) - ערך איכות מוצהר
- `pubkey` (מחרוזת hex) - מפתח ציבורי של חותם בלוק (33 בתים)
- `signer_address` (מחרוזת) - כתובת חותם בלוק
- `signature` (מחרוזת hex) - חתימת בלוק (65 בתים)

**שדות PoCX שהוסרו**:
- `mediantime` - הוסר (הוחלף על ידי time_since_last_block)

**דוגמה**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**יישום**: `src/rpc/blockchain.cpp`

---

### getblock

**שינויי PoCX**: זהים ל-getblockheader, בתוספת נתוני עסקה מלאים

**דוגמה**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbose עם פרטי tx
```

**יישום**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**שדות PoCX שנוספו**:
- `base_target` (מספרי) - base target נוכחי
- `generation_signature` (מחרוזת hex) - חתימת יצירה נוכחית

**שדות PoCX ששונו**:
- `difficulty` - משתמש בחישוב PoCX (מבוסס קיבולת)

**שדות PoCX שהוסרו**:
- `mediantime` - הוסר

**דוגמה**:
```bash
bitcoin-cli getblockchaininfo
```

**יישום**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**שדות PoCX שנוספו**:
- `generation_signature` (מחרוזת hex) - לכריית בריכה
- `base_target` (מספרי) - לכריית בריכה

**שדות PoCX שהוסרו**:
- `target` - הוסר (ספציפי ל-PoW)
- `noncerange` - הוסר (ספציפי ל-PoW)
- `bits` - הוסר (ספציפי ל-PoW)

**הערות**:
- עדיין כולל נתוני עסקה מלאים לבניית בלוק
- משמש שרתי בריכה לכרייה מתואמת

**דוגמה**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**יישום**: `src/rpc/mining.cpp`

---

## קריאות RPC מושבתות

קריאות RPC הבאות ספציפיות ל-PoW **מושבתות** במצב PoCX:

### getnetworkhashps
- **סיבה**: קצב hash לא רלוונטי ל-Proof of Capacity
- **חלופה**: השתמש ב-`getdifficulty` לאומדן קיבולת רשת

### getmininginfo
- **סיבה**: מחזיר מידע ספציפי ל-PoW
- **חלופה**: השתמש ב-`get_mining_info` (ספציפי ל-PoCX)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **סיבה**: כריית CPU לא רלוונטית ל-PoCX (דורש plots מיוצרים מראש)
- **חלופה**: השתמש ב-plotter חיצוני + miner + `submit_nonce`

**יישום**: `src/rpc/mining.cpp` (קריאות RPC מחזירות שגיאה כאשר ENABLE_POCX מוגדר)

---

## דוגמאות אינטגרציה

### אינטגרציית כורה חיצוני

**לולאת כרייה בסיסית**:
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

# לולאת כרייה
while True:
    # 1. קבל פרמטרי כרייה
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    min_compression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. סרוק קובצי plot (יישום חיצוני)
    best_nonce = scan_plots(gen_sig, height)

    # 3. הגש את הפתרון הטוב ביותר
    result = rpc_call("submit_nonce", [
        height,
        gen_sig,
        best_nonce["account_id"],
        best_nonce["seed"],
        best_nonce["nonce"]
    ])

    if result["accepted"]:
        print(f"פתרון התקבל! איכות: {result['quality']}s, "
              f"זמן כרייה: {result['poc_time']}s")

    # 4. המתן לבלוק הבא
    time.sleep(10)  # מרווח תשאול
```

---

### דפוס אינטגרציית בריכה

**זרימת עבודת שרת בריכה**:
1. כורים יוצרים הקצאות כרייה לכתובת הבריכה
2. הבריכה מפעילה ארנק עם מפתחות כתובת כרייה
3. הבריכה קוראת ל-`get_mining_info` ומפיצה לכורים
4. כורים מגישים פתרונות דרך הבריכה (לא ישירות לשרשרת)
5. הבריכה מאמתת וקוראת ל-`submit_nonce` עם מפתחות הבריכה
6. הבריכה מפיצה תגמולים לפי מדיניות בריכה

**ניהול הקצאות**:
```bash
# כורה יוצר הקצאה (מארנק הכורה)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# המתן להפעלה (30 בלוקים mainnet)

# בריכה בודקת סטטוס הקצאה
bitcoin-cli get_assignment "pocx1qminer_plot..."

# הבריכה יכולה כעת להגיש nonces עבור plot זה
# (ארנק בריכה חייב להחזיק מפתח פרטי של pocx1qpool...)
```

---

### שאילתות סייר בלוקים

**שאילתת נתוני בלוק PoCX**:
```bash
# קבל בלוק אחרון
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# קבל פרטי בלוק עם הוכחת PoCX
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# חלץ שדות ספציפיים ל-PoCX
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

**זיהוי עסקאות הקצאה**:
```bash
# סרוק עסקה ל-OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# בדוק סמן הקצאה (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## טיפול בשגיאות

### דפוסי שגיאה נפוצים

**חוסר התאמה בגובה**:
```json
{
  "accepted": false,
  "error": "Height mismatch: submitted 12345, current 12346"
}
```
**פתרון**: אחזר מחדש מידע כרייה, השרשרת התקדמה

**חוסר התאמה בחתימת יצירה**:
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```
**פתרון**: אחזר מחדש מידע כרייה, בלוק חדש הגיע

**אין מפתח פרטי**:
```json
{
  "code": -5,
  "message": "No private key available for effective signer"
}
```
**פתרון**: ייבא מפתח לכתובת plot או כתובת כרייה

**הפעלת הקצאה ממתינה**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**פתרון**: המתן לסיום עיכוב הפעלה

---

## הפניות לקוד

**קריאות RPC כרייה**: `src/pocx/rpc/mining.cpp`
**קריאות RPC הקצאה**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**קריאות RPC Blockchain**: `src/rpc/blockchain.cpp`
**אימות הוכחה**: `src/pocx/consensus/validation.cpp`, `src/pocx/consensus/pocx.cpp`
**מצב הקצאה**: `src/pocx/assignments/assignment_state.cpp`
**יצירת עסקה**: `src/pocx/assignments/transactions.cpp`

---

## הפניות צולבות

פרקים קשורים:
- [פרק 3: קונצנזוס וכרייה](3-consensus-and-mining.md) - פרטי תהליך כרייה
- [פרק 4: הקצאות כרייה](4-forging-assignments.md) - ארכיטקטורת מערכת הקצאות
- [פרק 6: פרמטרי רשת](6-network-parameters.md) - ערכי עיכוב הקצאה
- [פרק 8: מדריך ארנק](8-wallet-guide.md) - ממשק גרפי לניהול הקצאות

---

[← הקודם: פרמטרי רשת](6-network-parameters.md) | [📘 תוכן העניינים](index.md) | [הבא: מדריך ארנק →](8-wallet-guide.md)
