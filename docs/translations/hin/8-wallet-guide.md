[← पिछला: RPC संदर्भ](7-rpc-reference.md) | [📘 विषय-सूची](index.md)

---

# अध्याय 8: वॉलेट और GUI उपयोगकर्ता गाइड

Bitcoin-PoCX Qt वॉलेट और forging assignment प्रबंधन के लिए पूर्ण गाइड।

---

## विषय-सूची

1. [अवलोकन](#अवलोकन)
2. [मुद्रा इकाइयाँ](#मुद्रा-इकाइयाँ)
3. [Forging Assignment संवाद](#forging-assignment-संवाद)
4. [लेनदेन इतिहास](#लेनदेन-इतिहास)
5. [पता आवश्यकताएँ](#पता-आवश्यकताएँ)
6. [माइनिंग एकीकरण](#माइनिंग-एकीकरण)
7. [समस्या निवारण](#समस्या-निवारण)
8. [सुरक्षा सर्वोत्तम प्रथाएँ](#सुरक्षा-सर्वोत्तम-प्रथाएँ)

---

## अवलोकन

### Bitcoin-PoCX वॉलेट सुविधाएँ

Bitcoin-PoCX Qt वॉलेट (`bitcoin-qt`) प्रदान करता है:
- मानक Bitcoin Core वॉलेट कार्यक्षमता (भेजना, प्राप्त करना, लेनदेन प्रबंधन)
- **Forging Assignment प्रबंधक**: Plot assignments बनाने/रद्द करने के लिए GUI
- **माइनिंग सर्वर मोड**: `` फ्लैग माइनिंग-संबंधित सुविधाएँ सक्षम करता है
- **लेनदेन इतिहास**: Assignment और revocation लेनदेन प्रदर्शन

### वॉलेट शुरू करना

**केवल नोड** (माइनिंग के बिना):
```bash
./build/bin/bitcoin-qt
```

**माइनिंग के साथ** (assignment संवाद सक्षम करता है):
```bash
./build/bin/bitcoin-qt -server
```

**कमांड लाइन विकल्प**:
```bash
./build/bin/bitcoind
```

### माइनिंग आवश्यकताएँ

**माइनिंग संचालन के लिए**:
- `` फ्लैग आवश्यक
- P2WPKH पतों और निजी कुंजियों वाला वॉलेट
- Plot जनरेशन के लिए बाहरी plotter (`pocx_plotter`)
- माइनिंग के लिए बाहरी miner (`pocx_miner`)

**पूल माइनिंग के लिए**:
- पूल पते पर forging assignment बनाएँ
- पूल सर्वर पर वॉलेट आवश्यक नहीं (पूल कुंजियाँ प्रबंधित करता है)

---

## मुद्रा इकाइयाँ

### इकाई प्रदर्शन

Bitcoin-PoCX **BTCX** मुद्रा इकाई का उपयोग करता है (BTC नहीं):

| इकाई | सातोशी | प्रदर्शन |
|------|--------|----------|
| **BTCX** | 100000000 | 1.00000000 BTCX |
| **mBTCX** | 100000 | 1000.00 mBTCX |
| **µBTCX** | 100 | 1000000.00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**GUI सेटिंग्स**: Preferences → Display → Unit

---

## Forging Assignment संवाद

### संवाद तक पहुँच

**मेनू**: `Wallet → Forging Assignments`
**टूलबार**: माइनिंग आइकन (केवल `` फ्लैग के साथ दिखाई देता है)
**विंडो आकार**: 600×450 पिक्सेल

### संवाद मोड

#### मोड 1: Assignment बनाएँ

**उद्देश्य**: Plot स्वामित्व बनाए रखते हुए पूल या अन्य पते को forging अधिकार सौंपें।

**उपयोग के मामले**:
- पूल माइनिंग (पूल पते को सौंपें)
- कोल्ड स्टोरेज (माइनिंग कुंजी plot स्वामित्व से अलग)
- साझा बुनियादी ढाँचा (हॉट वॉलेट को सौंपें)

**आवश्यकताएँ**:
- Plot पता (P2WPKH bech32, निजी कुंजी का स्वामी होना चाहिए)
- Forging पता (P2WPKH bech32, plot पते से भिन्न)
- वॉलेट अनलॉक (यदि एन्क्रिप्टेड है)
- Plot पते में पुष्टि किए गए UTXOs

**चरण**:
1. "Create Assignment" मोड चुनें
2. ड्रॉपडाउन से plot पता चुनें या मैन्युअल रूप से दर्ज करें
3. Forging पता दर्ज करें (पूल या प्रतिनिधि)
4. "Send Assignment" पर क्लिक करें (इनपुट वैध होने पर बटन सक्षम)
5. लेनदेन तुरंत प्रसारित होता है
6. `nForgingAssignmentDelay` ब्लॉकों के बाद Assignment सक्रिय:
   - Mainnet/Testnet: 30 ब्लॉक (~1 घंटा)
   - Regtest: 4 ब्लॉक (~4 सेकंड)

**लेनदेन शुल्क**: डिफ़ॉल्ट 10× `minRelayFee` (अनुकूलन योग्य)

**लेनदेन संरचना**:
- इनपुट: Plot पते से UTXO (स्वामित्व का प्रमाण)
- OP_RETURN आउटपुट: `POCX` मार्कर + plot_address + forging_address (46 बाइट्स)
- चेंज आउटपुट: वॉलेट में वापस

#### मोड 2: Assignment रद्द करें

**उद्देश्य**: Forging assignment रद्द करें और अधिकार plot स्वामी को लौटाएँ।

**आवश्यकताएँ**:
- Plot पता (निजी कुंजी का स्वामी होना चाहिए)
- वॉलेट अनलॉक (यदि एन्क्रिप्टेड है)
- Plot पते में पुष्टि किए गए UTXOs

**चरण**:
1. "Revoke Assignment" मोड चुनें
2. Plot पता चुनें
3. "Send Revocation" पर क्लिक करें
4. लेनदेन तुरंत प्रसारित होता है
5. `nForgingRevocationDelay` ब्लॉकों के बाद Revocation प्रभावी:
   - Mainnet/Testnet: 720 ब्लॉक (~24 घंटे)
   - Regtest: 8 ब्लॉक (~8 सेकंड)

**प्रभाव**:
- विलंब अवधि के दौरान Forging पता अभी भी forge कर सकता है
- Revocation पूर्ण होने के बाद Plot स्वामी अधिकार पुनः प्राप्त करता है
- बाद में नया assignment बना सकते हैं

**लेनदेन संरचना**:
- इनपुट: Plot पते से UTXO (स्वामित्व का प्रमाण)
- OP_RETURN आउटपुट: `XCOP` मार्कर + plot_address (26 बाइट्स)
- चेंज आउटपुट: वॉलेट में वापस

#### मोड 3: Assignment स्थिति जाँचें

**उद्देश्य**: किसी भी plot पते के लिए वर्तमान assignment स्थिति पूछें।

**आवश्यकताएँ**: कोई नहीं (केवल पढ़ने के लिए, वॉलेट की आवश्यकता नहीं)

**चरण**:
1. "Check Assignment Status" मोड चुनें
2. Plot पता दर्ज करें
3. "Check Status" पर क्लिक करें
4. स्टेटस बॉक्स विवरण के साथ वर्तमान स्थिति प्रदर्शित करता है

**स्थिति संकेतक** (रंग-कोडित):

**ग्रे - UNASSIGNED**
```
UNASSIGNED - कोई assignment मौजूद नहीं
```

**नारंगी - ASSIGNING**
```
ASSIGNING - Assignment सक्रियण लंबित
Forging Address: pocx1qforger...
Created at height: 12000
Activates at height: 12030 (5 ब्लॉक शेष)
```

**हरा - ASSIGNED**
```
ASSIGNED - सक्रिय assignment
Forging Address: pocx1qforger...
Created at height: 12000
Activated at height: 12030
```

**लाल-नारंगी - REVOKING**
```
REVOKING - Revocation लंबित
Forging Address: pocx1qforger... (अभी भी सक्रिय)
Assignment created at height: 12000
Revoked at height: 12300
Revocation effective at height: 13020 (50 ब्लॉक शेष)
```

**लाल - REVOKED**
```
REVOKED - Assignment रद्द
Previously assigned to: pocx1qforger...
Assignment created at height: 12000
Revoked at height: 12300
Revocation effective at height: 13020
```

---

## लेनदेन इतिहास

### Assignment लेनदेन प्रदर्शन

**प्रकार**: "Assignment"
**आइकन**: माइनिंग आइकन (माइन किए गए ब्लॉकों जैसा)

**पता कॉलम**: Plot पता (जिस पते के forging अधिकार सौंपे जा रहे हैं)
**राशि कॉलम**: लेनदेन शुल्क (ऋणात्मक, आउटगोइंग लेनदेन)
**स्थिति कॉलम**: पुष्टि संख्या (0-6+)

**विवरण** (क्लिक करने पर):
- लेनदेन ID
- Plot पता
- Forging पता (OP_RETURN से पार्स किया गया)
- बनाया गया ऊँचाई पर
- सक्रियण ऊँचाई
- लेनदेन शुल्क
- टाइमस्टैम्प

### Revocation लेनदेन प्रदर्शन

**प्रकार**: "Revocation"
**आइकन**: माइनिंग आइकन

**पता कॉलम**: Plot पता
**राशि कॉलम**: लेनदेन शुल्क (ऋणात्मक)
**स्थिति कॉलम**: पुष्टि संख्या

**विवरण** (क्लिक करने पर):
- लेनदेन ID
- Plot पता
- रद्द किया गया ऊँचाई पर
- Revocation प्रभावी ऊँचाई
- लेनदेन शुल्क
- टाइमस्टैम्प

### लेनदेन फ़िल्टरिंग

**उपलब्ध फ़िल्टर**:
- "All" (डिफ़ॉल्ट, assignments/revocations शामिल)
- तिथि सीमा
- राशि सीमा
- पते द्वारा खोज
- लेनदेन ID द्वारा खोज
- लेबल द्वारा खोज (यदि पता लेबल किया गया है)

**नोट**: Assignment/Revocation लेनदेन वर्तमान में "All" फ़िल्टर के तहत दिखाई देते हैं। समर्पित प्रकार फ़िल्टर अभी तक लागू नहीं किया गया है।

### लेनदेन क्रमबद्धता

**क्रम क्रम** (प्रकार द्वारा):
- Generated (प्रकार 0)
- Received (प्रकार 1-3)
- Assignment (प्रकार 4)
- Revocation (प्रकार 5)
- Sent (प्रकार 6+)

---

## पता आवश्यकताएँ

### केवल P2WPKH (SegWit v0)

**Forging संचालन के लिए आवश्यक**:
- Bech32 एन्कोडेड पते ("pocx1q" mainnet, "tpocx1q" testnet, "rpocx1q" regtest से शुरू)
- P2WPKH (Pay-to-Witness-Public-Key-Hash) प्रारूप
- 20-बाइट key hash

**समर्थित नहीं**:
- P2PKH (लीगेसी, "1" से शुरू)
- P2SH (रैप्ड SegWit, "3" से शुरू)
- P2TR (Taproot, "bc1p" से शुरू)

**तर्क**: PoCX ब्लॉक हस्ताक्षरों के लिए प्रूफ सत्यापन हेतु विशिष्ट witness v0 प्रारूप आवश्यक है।

### पता ड्रॉपडाउन फ़िल्टरिंग

**Plot पता कॉम्बोबॉक्स**:
- स्वचालित रूप से वॉलेट के प्राप्त करने वाले पतों से भरा जाता है
- गैर-P2WPKH पतों को फ़िल्टर करता है
- प्रारूप दिखाता है: "लेबल (पता)" यदि लेबल किया गया है, अन्यथा केवल पता
- पहला आइटम: "-- Enter custom address --" मैन्युअल प्रविष्टि के लिए

**मैन्युअल प्रविष्टि**:
- प्रविष्ट करने पर प्रारूप सत्यापित करता है
- वैध bech32 P2WPKH होना चाहिए
- अमान्य प्रारूप होने पर बटन अक्षम

### सत्यापन त्रुटि संदेश

**संवाद त्रुटियाँ**:
- "Plot address must be segwit v0 (bech32)"
- Invalid forging address silently disables the Send button
- "Invalid address format"
- "No coins available at the plot address. Cannot prove ownership."
- "Cannot create transactions with watch-only wallet"
- "Wallet not available"
- "Wallet locked" (RPC से)

---

## माइनिंग एकीकरण

### सेटअप आवश्यकताएँ

**नोड कॉन्फ़िगरेशन**:
```bash
# bitcoin.conf
server=1
```

**वॉलेट आवश्यकताएँ**:
- Plot स्वामित्व के लिए P2WPKH पते
- माइनिंग के लिए निजी कुंजियाँ (या assignments का उपयोग करने पर forging पता)
- लेनदेन निर्माण के लिए पुष्टि किए गए UTXOs

**बाहरी उपकरण**:
- `pocx_plotter`: Plot फ़ाइलें जनरेट करें
- `pocx_miner`: Plots स्कैन करें और nonces सबमिट करें

### कार्यप्रवाह

#### सोलो माइनिंग

1. **Plot फ़ाइलें जनरेट करें**:
   ```bash
   pocx_plotter --account <plot_address_hash160> --seed <32_bytes> --nonces <count>
   ```

2. **माइनिंग सर्वर के साथ नोड शुरू करें**:
   ```bash
   bitcoin-qt -server
   ```

3. **Miner कॉन्फ़िगर करें**:
   - नोड RPC endpoint पर इंगित करें
   - Plot फ़ाइल निर्देशिकाएँ निर्दिष्ट करें
   - खाता ID कॉन्फ़िगर करें (plot पते से)

4. **माइनिंग शुरू करें**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /path/to/plots
   ```

5. **निगरानी करें**:
   - Miner प्रत्येक ब्लॉक पर `get_mining_info` कॉल करता है
   - सर्वोत्तम deadline के लिए plots स्कैन करता है
   - समाधान मिलने पर `submit_nonce` कॉल करता है
   - नोड स्वचालित रूप से सत्यापित और forge करता है

#### पूल माइनिंग

1. **Plot फ़ाइलें जनरेट करें** (सोलो माइनिंग जैसा)

2. **Forging Assignment बनाएँ**:
   - Forging Assignment संवाद खोलें
   - Plot पता चुनें
   - पूल का forging पता दर्ज करें
   - "Send Assignment" पर क्लिक करें
   - सक्रियण विलंब की प्रतीक्षा करें (testnet पर 30 ब्लॉक)

3. **Miner कॉन्फ़िगर करें**:
   - **पूल** endpoint पर इंगित करें (स्थानीय नोड नहीं)
   - पूल चेन पर `submit_nonce` संभालता है

4. **पूल संचालन**:
   - पूल वॉलेट में forging पते की निजी कुंजियाँ हैं
   - पूल miners से सबमिशन सत्यापित करता है
   - पूल blockchain पर `submit_nonce` कॉल करता है
   - पूल नीति के अनुसार पुरस्कार वितरित करता है

### Coinbase पुरस्कार

**Assignment के बिना**:
- Coinbase सीधे plot स्वामी पते को भुगतान करता है
- Plot पते में शेष जाँचें

**Assignment के साथ**:
- Coinbase forging पते को भुगतान करता है
- पूल पुरस्कार प्राप्त करता है
- Miner पूल से हिस्सा प्राप्त करता है

**पुरस्कार अनुसूची**:
- प्रारंभिक: 10 BTCX प्रति ब्लॉक
- आधा करना: हर 1050000 ब्लॉक (~4 वर्ष)
- अनुसूची: 10 → 5 → 2.5 → 1.25 → ...

---

## समस्या निवारण

### सामान्य समस्याएँ

#### "Wallet does not have private key for plot address"

**कारण**: वॉलेट पते का स्वामी नहीं है
**समाधान**:
- `importprivkey` RPC के माध्यम से निजी कुंजी आयात करें
- या वॉलेट के स्वामित्व वाला अन्य plot पता उपयोग करें

#### "Cannot create assignment: plot is in ... state"

**Cause**: Plot is not in UNASSIGNED or REVOKED state
**Solution**:
1. Revoke existing assignment
2. Wait for revocation delay (720 blocks mainnet/testnet, 8 blocks regtest)
3. Create new assignment

#### "Address format not supported"

**कारण**: पता P2WPKH bech32 नहीं है
**समाधान**:
- "pocx1q" (mainnet) या "tpocx1q" (testnet) से शुरू होने वाले पते उपयोग करें
- यदि आवश्यक हो तो नया पता जनरेट करें: `getnewaddress "" "bech32"`

#### "Transaction fee too low"

**कारण**: नेटवर्क mempool भीड़भाड़ या relay के लिए शुल्क बहुत कम
**समाधान**:
- शुल्क दर पैरामीटर बढ़ाएँ
- Mempool खाली होने की प्रतीक्षा करें

#### "Assignment not yet active"

**कारण**: सक्रियण विलंब अभी तक समाप्त नहीं हुआ
**समाधान**:
- स्थिति जाँचें: सक्रियण तक शेष ब्लॉक
- विलंब अवधि पूर्ण होने की प्रतीक्षा करें

#### "No coins available at the plot address"

**कारण**: Plot पते में कोई पुष्टि किए गए UTXOs नहीं हैं
**समाधान**:
1. Plot पते पर धन भेजें
2. 1 पुष्टि की प्रतीक्षा करें
3. Assignment निर्माण पुनः प्रयास करें

#### "Cannot create transactions with watch-only wallet"

**कारण**: वॉलेट ने निजी कुंजी के बिना पता आयात किया
**समाधान**: पूर्ण निजी कुंजी आयात करें, केवल पता नहीं

### डीबग चरण

1. **वॉलेट स्थिति जाँचें**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **पता स्वामित्व सत्यापित करें**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # जाँचें: "iswatchonly": false, "ismine": true
   ```

3. **Assignment स्थिति जाँचें**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **हाल के लेनदेन देखें**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **नोड सिंक जाँचें**:
   ```bash
   bitcoin-cli getblockchaininfo
   # सत्यापित करें: blocks == headers (पूर्ण रूप से सिंक)
   ```

---

## सुरक्षा सर्वोत्तम प्रथाएँ

### Plot पता सुरक्षा

**कुंजी प्रबंधन**:
- Plot पते की निजी कुंजियाँ सुरक्षित रूप से संग्रहित करें
- Assignment लेनदेन हस्ताक्षर के माध्यम से स्वामित्व प्रमाणित करते हैं
- केवल plot स्वामी assignments बना/रद्द कर सकता है

**बैकअप**:
- नियमित रूप से वॉलेट बैकअप करें (`dumpwallet` या `backupwallet`)
- wallet.dat को सुरक्षित स्थान पर संग्रहित करें
- HD वॉलेट का उपयोग करने पर रिकवरी वाक्यांश रिकॉर्ड करें

### Forging पता प्रत्यायोजन

**सुरक्षा मॉडल**:
- Forging पता ब्लॉक पुरस्कार प्राप्त करता है
- Forging पता ब्लॉक पर हस्ताक्षर कर सकता है (माइनिंग)
- Forging पता assignment को संशोधित या रद्द **नहीं कर सकता**
- Plot स्वामी पूर्ण नियंत्रण बनाए रखता है

**उपयोग के मामले**:
- **हॉट वॉलेट प्रत्यायोजन**: Plot कुंजी कोल्ड स्टोरेज में, forging कुंजी माइनिंग के लिए हॉट वॉलेट में
- **पूल माइनिंग**: पूल को सौंपें, plot स्वामित्व बनाए रखें
- **साझा बुनियादी ढाँचा**: एकाधिक miners, एक forging पता

### नेटवर्क समय सिंक्रनाइज़ेशन

**महत्व**:
- PoCX सहमति के लिए सटीक समय आवश्यक है
- >10s घड़ी विचलन चेतावनी ट्रिगर करता है
- >15s घड़ी विचलन माइनिंग रोकता है

**समाधान**:
- सिस्टम घड़ी को NTP के साथ सिंक्रनाइज़ रखें
- निगरानी करें: समय ऑफ़सेट चेतावनियों के लिए `bitcoin-cli getnetworkinfo`
- विश्वसनीय NTP सर्वर उपयोग करें

### Assignment विलंब

**सक्रियण विलंब** (testnet पर 30 ब्लॉक):
- चेन फोर्क के दौरान तेज़ पुनः-assignment रोकता है
- नेटवर्क को सहमति तक पहुँचने देता है
- बायपास नहीं किया जा सकता

**Revocation विलंब** (testnet पर 720 ब्लॉक):
- माइनिंग पूलों के लिए स्थिरता प्रदान करता है
- Assignment "griefing" हमलों को रोकता है
- विलंब के दौरान Forging पता सक्रिय रहता है

### वॉलेट एन्क्रिप्शन

**एन्क्रिप्शन सक्षम करें**:
```bash
bitcoin-cli encryptwallet "your_passphrase"
```

**लेनदेन के लिए अनलॉक करें**:
```bash
bitcoin-cli walletpassphrase "your_passphrase" 300
```

**सर्वोत्तम प्रथाएँ**:
- मज़बूत पासफ़्रेज़ उपयोग करें (20+ अक्षर)
- पासफ़्रेज़ को सादे पाठ में संग्रहित न करें
- Assignments बनाने के बाद वॉलेट लॉक करें

---

## कोड संदर्भ

**Forging Assignment संवाद**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**लेनदेन प्रदर्शन**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**लेनदेन पार्सिंग**: `src/qt/transactionrecord.cpp`
**वॉलेट एकीकरण**: `src/pocx/assignments/transactions.cpp`
**Assignment RPCs**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI मुख्य**: `src/qt/bitcoingui.cpp`

---

## क्रॉस-संदर्भ

संबंधित अध्याय:
- [अध्याय 3: सहमति और माइनिंग](3-consensus-and-mining.md) - माइनिंग प्रक्रिया
- [अध्याय 4: Forging Assignments](4-forging-assignments.md) - Assignment आर्किटेक्चर
- [अध्याय 6: नेटवर्क पैरामीटर](6-network-parameters.md) - Assignment विलंब मान
- [अध्याय 7: RPC संदर्भ](7-rpc-reference.md) - RPC कमांड विवरण

---

[← पिछला: RPC संदर्भ](7-rpc-reference.md) | [📘 विषय-सूची](index.md)
