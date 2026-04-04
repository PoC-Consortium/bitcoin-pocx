[← पिछला: नेटवर्क पैरामीटर](6-network-parameters.md) | [📘 विषय-सूची](index.md) | [अगला: वॉलेट गाइड →](8-wallet-guide.md)

---

# अध्याय 7: RPC इंटरफ़ेस संदर्भ

माइनिंग RPCs, असाइनमेंट प्रबंधन, और संशोधित ब्लॉकचेन RPCs सहित Bitcoin-PoCX RPC कमांड का संपूर्ण संदर्भ।

---

## विषय-सूची

1. [कॉन्फ़िगरेशन](#कॉन्फ़िगरेशन)
2. [PoCX माइनिंग RPCs](#pocx-माइनिंग-rpcs)
3. [असाइनमेंट RPCs](#असाइनमेंट-rpcs)
4. [संशोधित ब्लॉकचेन RPCs](#संशोधित-ब्लॉकचेन-rpcs)
5. [अक्षम RPCs](#अक्षम-rpcs)
6. [एकीकरण उदाहरण](#एकीकरण-उदाहरण)

---

## कॉन्फ़िगरेशन

### माइनिंग सर्वर मोड

**फ़्लैग**: ``

**उद्देश्य**: बाहरी माइनर्स के लिए माइनिंग-विशिष्ट RPCs कॉल करने के लिए RPC एक्सेस सक्षम करता है

**आवश्यकताएं**:
- `submit_nonce` काम करने के लिए आवश्यक
- Qt वॉलेट में फोर्जिंग असाइनमेंट डायलॉग की दृश्यता के लिए आवश्यक

**उपयोग**:
```bash
# कमांड लाइन
./bitcoind

# bitcoin.conf
```

**सुरक्षा विचार**:
- मानक RPC क्रेडेंशियल्स से परे कोई अतिरिक्त प्रमाणीकरण नहीं
- माइनिंग RPCs कतार क्षमता द्वारा दर-सीमित
- मानक RPC प्रमाणीकरण अभी भी आवश्यक

**कार्यान्वयन**: `src/pocx/rpc/mining.cpp`

---

## PoCX माइनिंग RPCs

### get_mining_info

**श्रेणी**: माइनिंग
**माइनिंग सर्वर आवश्यक**: नहीं
**वॉलेट आवश्यक**: नहीं

**उद्देश्य**: बाहरी माइनर्स के लिए plot फ़ाइलें स्कैन करने और deadlines गणना करने के लिए आवश्यक वर्तमान माइनिंग पैरामीटर लौटाता है।

**पैरामीटर**: कोई नहीं

**रिटर्न मान**:
```json
{
  "generation_signature": "abc123...",       // हेक्स, 64 अक्षर
  "base_target": 36650387592,                // संख्यात्मक
  "height": 12345,                           // संख्यात्मक, अगले ब्लॉक की ऊंचाई
  "block_hash": "def456...",                 // हेक्स, पिछला ब्लॉक
  "target_quality": 18446744073709551615,    // uint64_max (सभी समाधान स्वीकृत)
  "minimum_compression_level": 1,            // संख्यात्मक
  "target_compression_level": 2              // संख्यात्मक
}
```

**फ़ील्ड विवरण**:
- `generation_signature`: इस ब्लॉक ऊंचाई के लिए नियतात्मक माइनिंग एन्ट्रॉपी
- `base_target`: वर्तमान कठिनाई (उच्च = आसान)
- `height`: माइनर्स को लक्षित करने वाली ब्लॉक ऊंचाई
- `block_hash`: पिछले ब्लॉक का हैश (सूचनात्मक)
- `target_quality`: गुणवत्ता सीमा (वर्तमान में uint64_max, कोई फ़िल्टरिंग नहीं)
- `minimum_compression_level`: सत्यापन के लिए आवश्यक न्यूनतम compression
- `target_compression_level`: इष्टतम माइनिंग के लिए अनुशंसित compression

**त्रुटि कोड**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: नोड अभी भी सिंक हो रहा है

**उदाहरण**:
```bash
bitcoin-cli get_mining_info
```

**कार्यान्वयन**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**श्रेणी**: माइनिंग
**माइनिंग सर्वर आवश्यक**: हाँ
**वॉलेट आवश्यक**: हाँ (निजी कुंजियों के लिए)

**उद्देश्य**: PoCX माइनिंग समाधान सबमिट करें। प्रमाण सत्यापित करता है, time-bended फोर्जिंग के लिए कतारबद्ध करता है, और निर्धारित समय पर स्वचालित रूप से ब्लॉक बनाता है।

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

**रिटर्न मान** (सफलता):
```json
{
  "accepted": true,
  "quality": 120,           // सेकंड में कठिनाई-समायोजित deadline
  "poc_time": 45            // सेकंड में time-bended फोर्ज समय
}
```

**रिटर्न मान** (अस्वीकृत):
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```

**सत्यापन चरण**:
1. **प्रारूप सत्यापन** (फास्ट-फेल):
   - Account ID: ठीक 40 हेक्स अक्षर
   - Seed: ठीक 64 हेक्स अक्षर
2. **संदर्भ सत्यापन**:
   - ऊंचाई वर्तमान tip + 1 से मेल खानी चाहिए
   - Generation signature वर्तमान से मेल खानी चाहिए
3. **वॉलेट सत्यापन**:
   - प्रभावी हस्ताक्षरकर्ता निर्धारित करें (सक्रिय असाइनमेंट के लिए जांचें)
   - सत्यापित करें कि वॉलेट के पास प्रभावी हस्ताक्षरकर्ता के लिए निजी कुंजी है
4. **प्रमाण सत्यापन** (महंगा):
   - Compression सीमाओं के साथ PoCX प्रमाण सत्यापित करें
   - रॉ गुणवत्ता गणना करें
5. **शेड्यूलर सबमिशन**:
   - Time-bended फोर्जिंग के लिए nonce कतारबद्ध करें
   - ब्लॉक स्वचालित रूप से forge_time पर बनाया जाएगा

**त्रुटि कोड**:
- `RPC_INVALID_PARAMETER`: अमान्य प्रारूप (account_id, seed) या ऊंचाई बेमेल
- `RPC_VERIFY_REJECTED`: Generation signature बेमेल या प्रमाण सत्यापन विफल
- `RPC_INVALID_ADDRESS_OR_KEY`: प्रभावी हस्ताक्षरकर्ता के लिए कोई निजी कुंजी नहीं
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: सबमिशन कतार भरी हुई
- `RPC_INTERNAL_ERROR`: PoCX शेड्यूलर प्रारंभ करने में विफल

**प्रमाण सत्यापन त्रुटि कोड**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**उदाहरण**:
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

**नोट्स**:
- सबमिशन असिंक्रोनस है - RPC तुरंत लौटता है, ब्लॉक बाद में फोर्ज होता है
- Time Bending नेटवर्क-व्यापी plot स्कैनिंग की अनुमति देने के लिए अच्छे समाधानों में विलंब करता है
- असाइनमेंट सिस्टम: यदि plot असाइन है, तो वॉलेट के पास फोर्जिंग पते की कुंजी होनी चाहिए
- Compression सीमाएं ब्लॉक ऊंचाई के आधार पर गतिशील रूप से समायोजित

**कार्यान्वयन**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## असाइनमेंट RPCs

### get_assignment

**श्रेणी**: माइनिंग
**माइनिंग सर्वर आवश्यक**: नहीं
**वॉलेट आवश्यक**: नहीं

**उद्देश्य**: Plot पते के लिए फोर्जिंग असाइनमेंट स्थिति क्वेरी करें। केवल-पढ़ने, कोई वॉलेट आवश्यक नहीं।

**पैरामीटर**:
1. `plot_address` (स्ट्रिंग, आवश्यक) - Plot पता (bech32 P2WPKH प्रारूप)
2. `height` (संख्यात्मक, वैकल्पिक) - क्वेरी करने के लिए ब्लॉक ऊंचाई (डिफ़ॉल्ट: वर्तमान tip)

**रिटर्न मान** (कोई असाइनमेंट नहीं):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**रिटर्न मान** (सक्रिय असाइनमेंट):
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

**रिटर्न मान** (निरस्त हो रहा):
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

**असाइनमेंट स्थितियां**:
- `UNASSIGNED`: कोई असाइनमेंट मौजूद नहीं
- `ASSIGNING`: असाइनमेंट tx पुष्टि, सक्रियण विलंब प्रगति में
- `ASSIGNED`: असाइनमेंट सक्रिय, फोर्जिंग अधिकार प्रत्यायोजित
- `REVOKING`: निरस्तीकरण tx पुष्टि, विलंब समाप्त होने तक अभी भी सक्रिय
- `REVOKED`: निरस्तीकरण पूर्ण, फोर्जिंग अधिकार plot मालिक को लौटे

**त्रुटि कोड**:
- `RPC_INVALID_ADDRESS_OR_KEY`: अमान्य पता या P2WPKH (bech32) नहीं

**उदाहरण**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**कार्यान्वयन**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**श्रेणी**: वॉलेट
**माइनिंग सर्वर आवश्यक**: नहीं
**वॉलेट आवश्यक**: हाँ (लोडेड और अनलॉक होना चाहिए)

**उद्देश्य**: फोर्जिंग अधिकार दूसरे पते (जैसे, माइनिंग पूल) को प्रत्यायोजित करने के लिए फोर्जिंग असाइनमेंट लेनदेन बनाएं।

**पैरामीटर**:
1. `plot_address` (स्ट्रिंग, आवश्यक) - Plot मालिक पता (निजी कुंजी होनी चाहिए, P2WPKH bech32)
2. `forging_address` (स्ट्रिंग, आवश्यक) - फोर्जिंग अधिकार असाइन करने के लिए पता (P2WPKH bech32)
3. `fee_rate` (संख्यात्मक, वैकल्पिक) - BTC/kvB में शुल्क दर (डिफ़ॉल्ट: 10× minRelayFee)

**रिटर्न मान**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**आवश्यकताएं**:
- वॉलेट लोडेड और अनलॉक
- वॉलेट में plot_address के लिए निजी कुंजी
- दोनों पते P2WPKH (bech32 प्रारूप: pocx1q... mainnet, tpocx1q... testnet) होने चाहिए
- Plot पते में पुष्टि UTXOs होने चाहिए (स्वामित्व सिद्ध करता है)
- Plot में सक्रिय असाइनमेंट नहीं होना चाहिए (पहले निरस्त करें)

**लेनदेन संरचना**:
- Input: Plot पते से UTXO (स्वामित्व सिद्ध करता है)
- Output: OP_RETURN (46 बाइट्स): `POCX` मार्कर + plot_address (20 बाइट्स) + forging_address (20 बाइट्स)
- Output: वॉलेट में Change लौटाया गया

**सक्रियण**:
- पुष्टि पर असाइनमेंट ASSIGNING बन जाता है
- `nForgingAssignmentDelay` ब्लॉक के बाद ACTIVE बन जाता है
- विलंब चेन forks के दौरान तेज़ पुनर्असाइनमेंट रोकता है

**त्रुटि कोड**:
- `RPC_WALLET_NOT_FOUND`: कोई वॉलेट उपलब्ध नहीं
- `RPC_WALLET_UNLOCK_NEEDED`: वॉलेट एन्क्रिप्टेड और लॉक
- `RPC_WALLET_ERROR`: लेनदेन निर्माण विफल
- `RPC_INVALID_ADDRESS_OR_KEY`: अमान्य पता प्रारूप

**उदाहरण**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**कार्यान्वयन**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**श्रेणी**: वॉलेट
**माइनिंग सर्वर आवश्यक**: नहीं
**वॉलेट आवश्यक**: हाँ (लोडेड और अनलॉक होना चाहिए)

**उद्देश्य**: मौजूदा फोर्जिंग असाइनमेंट निरस्त करें, plot मालिक को फोर्जिंग अधिकार लौटाएं।

**पैरामीटर**:
1. `plot_address` (स्ट्रिंग, आवश्यक) - Plot पता (निजी कुंजी होनी चाहिए, P2WPKH bech32)
2. `fee_rate` (संख्यात्मक, वैकल्पिक) - BTC/kvB में शुल्क दर (डिफ़ॉल्ट: 10× minRelayFee)

**रिटर्न मान**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**आवश्यकताएं**:
- वॉलेट लोडेड और अनलॉक
- वॉलेट में plot_address के लिए निजी कुंजी
- Plot पता P2WPKH (bech32 प्रारूप) होना चाहिए
- Plot पते में पुष्टि UTXOs होने चाहिए

**लेनदेन संरचना**:
- Input: Plot पते से UTXO (स्वामित्व सिद्ध करता है)
- Output: OP_RETURN (26 बाइट्स): `XCOP` मार्कर + plot_address (20 बाइट्स)
- Output: वॉलेट में Change लौटाया गया

**प्रभाव**:
- स्थिति तुरंत REVOKING में संक्रमित
- फोर्जिंग पता विलंब अवधि के दौरान अभी भी फोर्ज कर सकता है
- `nForgingRevocationDelay` ब्लॉक के बाद REVOKED बन जाता है
- निरस्तीकरण प्रभावी होने के बाद Plot मालिक फोर्ज कर सकता है
- निरस्तीकरण पूर्ण होने के बाद नया असाइनमेंट बना सकता है

**त्रुटि कोड**:
- `RPC_WALLET_NOT_FOUND`: कोई वॉलेट उपलब्ध नहीं
- `RPC_WALLET_UNLOCK_NEEDED`: वॉलेट एन्क्रिप्टेड और लॉक
- `RPC_WALLET_ERROR`: लेनदेन निर्माण विफल

**उदाहरण**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**नोट्स**:
- Idempotent: कोई सक्रिय असाइनमेंट न होने पर भी निरस्त कर सकते हैं
- एक बार सबमिट करने के बाद निरस्तीकरण रद्द नहीं कर सकते

**कार्यान्वयन**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## संशोधित ब्लॉकचेन RPCs

### getdifficulty

**PoCX संशोधन**:
- **गणना**: `reference_base_target / current_base_target`
- **संदर्भ**: 1 TiB नेटवर्क क्षमता (base_target = 36650387592)
- **व्याख्या**: TiB में अनुमानित नेटवर्क स्टोरेज क्षमता
  - उदाहरण: `1.0` = ~1 TiB
  - उदाहरण: `1024.0` = ~1 PiB
- **PoW से अंतर**: हैश पावर नहीं, क्षमता का प्रतिनिधित्व करता है

**उदाहरण**:
```bash
bitcoin-cli getdifficulty
# लौटाता है: 2048.5 (नेटवर्क ~2 PiB)
```

**कार्यान्वयन**: `src/rpc/blockchain.cpp`

---

### getblockheader

**PoCX जोड़े गए फ़ील्ड**:
- `time_since_last_block` (संख्यात्मक) - पिछले ब्लॉक से सेकंड (mediantime की जगह लेता है)
- `poc_time` (संख्यात्मक) - सेकंड में Time-bended फोर्ज समय
- `base_target` (संख्यात्मक) - PoCX कठिनाई base target
- `generation_signature` (स्ट्रिंग हेक्स) - Generation signature
- `pocx_proof` (ऑब्जेक्ट):
  - `account_id` (string) - Plot account as bech32 address
  - `seed` (स्ट्रिंग हेक्स) - Plot seed (32 बाइट्स)
  - `nonce` (संख्यात्मक) - माइनिंग nonce
  - `compression` (संख्यात्मक) - उपयोग किया गया स्केलिंग स्तर
  - `quality` (संख्यात्मक) - दावा की गई गुणवत्ता मान
- `pubkey` (स्ट्रिंग हेक्स) - ब्लॉक हस्ताक्षरकर्ता की सार्वजनिक कुंजी (33 बाइट्स)
- `signer_address` (स्ट्रिंग) - ब्लॉक हस्ताक्षरकर्ता का पता
- `signature` (स्ट्रिंग हेक्स) - ब्लॉक हस्ताक्षर (65 बाइट्स)

**PoCX हटाए गए फ़ील्ड**:
- `mediantime` - हटाया गया (time_since_last_block द्वारा प्रतिस्थापित)

**उदाहरण**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**कार्यान्वयन**: `src/rpc/blockchain.cpp`

---

### getblock

**PoCX संशोधन**: getblockheader के समान, साथ ही पूर्ण लेनदेन डेटा

**उदाहरण**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # tx विवरण के साथ verbose
```

**कार्यान्वयन**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**PoCX जोड़े गए फ़ील्ड**:
- `base_target` (संख्यात्मक) - वर्तमान base target
- `generation_signature` (स्ट्रिंग हेक्स) - वर्तमान generation signature

**PoCX संशोधित फ़ील्ड**:
- `difficulty` - PoCX गणना उपयोग करता है (क्षमता-आधारित)

**PoCX हटाए गए फ़ील्ड**:
- `mediantime` - हटाया गया

**उदाहरण**:
```bash
bitcoin-cli getblockchaininfo
```

**कार्यान्वयन**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**PoCX जोड़े गए फ़ील्ड**:
- `generation_signature` (स्ट्रिंग हेक्स) - पूल माइनिंग के लिए
- `base_target` (संख्यात्मक) - पूल माइनिंग के लिए

**PoCX हटाए गए फ़ील्ड**:
- `target` - Removed (replaced by `base_target`)
- `noncerange` - हटाया गया (PoW-विशिष्ट)
- `bits` - हटाया गया (PoW-विशिष्ट)

**नोट्स**:
- ब्लॉक निर्माण के लिए अभी भी पूर्ण लेनदेन डेटा शामिल
- समन्वित माइनिंग के लिए पूल सर्वर द्वारा उपयोग

**उदाहरण**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**कार्यान्वयन**: `src/rpc/mining.cpp`

---

## अक्षम RPCs

निम्नलिखित PoW-विशिष्ट RPCs PoCX मोड में **अक्षम** हैं:

### getnetworkhashps
- **कारण**: हैश रेट Proof of Capacity पर लागू नहीं
- **विकल्प**: नेटवर्क क्षमता अनुमान के लिए `getdifficulty` उपयोग करें

### getmininginfo
- **कारण**: PoW-विशिष्ट जानकारी लौटाता है
- **विकल्प**: `get_mining_info` (PoCX-विशिष्ट) उपयोग करें

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Status**: Available as hidden commands (functional in regtest for testing)
- **Note**: In regtest PoCX mode, these commands scan for valid PoCX proofs on-the-fly
- **Production**: Use external plotter + miner + `submit_nonce`

**Implementation**: `src/rpc/mining.cpp`

---

## एकीकरण उदाहरण

### बाहरी माइनर एकीकरण

**बुनियादी माइनिंग लूप**:
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

# माइनिंग लूप
while True:
    # 1. माइनिंग पैरामीटर प्राप्त करें
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    compression_bounds.nPoCXMinCompression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Plot फ़ाइलें स्कैन करें (बाहरी कार्यान्वयन)
    best_nonce = scan_plots(gen_sig, height)

    # 3. सर्वोत्तम समाधान सबमिट करें
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
        print(f"समाधान स्वीकृत! गुणवत्ता: {result['quality']}s, "
              f"फोर्ज समय: {result['poc_time']}s")

    # 4. अगले ब्लॉक की प्रतीक्षा करें
    time.sleep(10)  # पोल अंतराल
```

---

### पूल एकीकरण पैटर्न

**पूल सर्वर वर्कफ़्लो**:
1. माइनर्स पूल पते को फोर्जिंग असाइनमेंट बनाते हैं
2. पूल फोर्जिंग पते की कुंजियों के साथ वॉलेट चलाता है
3. पूल `get_mining_info` कॉल करता है और माइनर्स को वितरित करता है
4. माइनर्स पूल के माध्यम से समाधान सबमिट करते हैं (सीधे चेन को नहीं)
5. पूल सत्यापित करता है और पूल की कुंजियों के साथ `submit_nonce` कॉल करता है
6. पूल पूल नीति के अनुसार पुरस्कार वितरित करता है

**असाइनमेंट प्रबंधन**:
```bash
# माइनर असाइनमेंट बनाता है (माइनर के वॉलेट से)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# सक्रियण की प्रतीक्षा करें (mainnet पर 30 ब्लॉक)

# पूल असाइनमेंट स्थिति जांचता है
bitcoin-cli get_assignment "pocx1qminer_plot..."

# पूल अब इस plot के लिए nonces सबमिट कर सकता है
# (पूल वॉलेट में pocx1qpool... निजी कुंजी होनी चाहिए)
```

---

### ब्लॉक एक्सप्लोरर क्वेरी

**PoCX ब्लॉक डेटा क्वेरी करना**:
```bash
# नवीनतम ब्लॉक प्राप्त करें
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# PoCX प्रमाण के साथ ब्लॉक विवरण प्राप्त करें
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# PoCX-विशिष्ट फ़ील्ड निकालें
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

**असाइनमेंट लेनदेन का पता लगाना**:
```bash
# OP_RETURN के लिए लेनदेन स्कैन करें
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# असाइनमेंट मार्कर के लिए जांचें (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## त्रुटि हैंडलिंग

### सामान्य त्रुटि पैटर्न

**ऊंचाई बेमेल**:
```json
{
  "accepted": false,
  "error": "Height mismatch: submitted 12345, current 12346"
}
```
**समाधान**: माइनिंग जानकारी फिर से प्राप्त करें, चेन आगे बढ़ गई

**Generation Signature बेमेल**:
```json
{
  "accepted": false,
  "error": "Generation signature mismatch"
}
```
**समाधान**: माइनिंग जानकारी फिर से प्राप्त करें, नया ब्लॉक आया

**कोई निजी कुंजी नहीं**:
```json
{
  "code": -5,
  "message": "No private key available for effective signer"
}
```
**समाधान**: Plot या फोर्जिंग पते के लिए कुंजी आयात करें

**असाइनमेंट सक्रियण लंबित**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**समाधान**: सक्रियण विलंब समाप्त होने की प्रतीक्षा करें

---

## कोड संदर्भ

**माइनिंग RPCs**: `src/pocx/rpc/mining.cpp`
**असाइनमेंट RPCs**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**ब्लॉकचेन RPCs**: `src/rpc/blockchain.cpp`
**प्रमाण सत्यापन**: `src/pocx/consensus/proof.cpp`, `src/pocx/consensus/signature.cpp`
**असाइनमेंट स्थिति**: `src/pocx/assignments/assignment_state.cpp`
**लेनदेन निर्माण**: `src/pocx/assignments/transactions.cpp`

---

## क्रॉस-रेफरेंस

संबंधित अध्याय:
- [अध्याय 3: सहमति और माइनिंग](3-consensus-and-mining.md) - माइनिंग प्रक्रिया विवरण
- [अध्याय 4: फोर्जिंग असाइनमेंट](4-forging-assignments.md) - असाइनमेंट सिस्टम आर्किटेक्चर
- [अध्याय 6: नेटवर्क पैरामीटर](6-network-parameters.md) - असाइनमेंट विलंब मान
- [अध्याय 8: वॉलेट गाइड](8-wallet-guide.md) - असाइनमेंट प्रबंधन के लिए GUI

---

[← पिछला: नेटवर्क पैरामीटर](6-network-parameters.md) | [📘 विषय-सूची](index.md) | [अगला: वॉलेट गाइड →](8-wallet-guide.md)
