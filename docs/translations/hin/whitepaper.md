# Bitcoin-PoCX: Bitcoin Core के लिए ऊर्जा-कुशल सहमति

**संस्करण**: 2.0 ड्राफ्ट
**तिथि**: दिसंबर 2025
**संगठन**: Proof of Capacity Consortium

---

## सार

Bitcoin का Proof-of-Work (PoW) सहमति मजबूत सुरक्षा प्रदान करता है लेकिन निरंतर रीयल-टाइम hash गणना के कारण पर्याप्त ऊर्जा खपत करता है। हम Bitcoin-PoCX प्रस्तुत करते हैं, एक Bitcoin फोर्क जो PoW को Proof of Capacity (PoC) से प्रतिस्थापित करता है, जहाँ miners plotting के दौरान डिस्क-संग्रहित hashes के बड़े सेट पूर्व-गणना और संग्रहित करते हैं और बाद में चल रही hashing के बजाय हल्के lookups करके mine करते हैं। गणना को माइनिंग चरण से एक बार के plotting चरण में स्थानांतरित करके, Bitcoin-PoCX ऊर्जा खपत को काफी कम करता है जबकि commodity हार्डवेयर पर माइनिंग सक्षम करता है, भागीदारी की बाधा को कम करता है और ASIC-प्रभुत्व वाले PoW में निहित केंद्रीकरण दबावों को कम करता है, यह सब Bitcoin की सुरक्षा धारणाओं और आर्थिक व्यवहार को संरक्षित करते हुए।

हमारा कार्यान्वयन कई प्रमुख नवाचार प्रस्तुत करता है:
(1) एक कठोर plot प्रारूप जो मौजूदा PoC सिस्टमों में सभी ज्ञात time–memory-tradeoff हमलों को समाप्त करता है, यह सुनिश्चित करते हुए कि प्रभावी माइनिंग शक्ति प्रतिबद्ध स्टोरेज क्षमता के सख्त अनुपात में रहे;
(2) Time-Bending एल्गोरिथ्म, जो deadline वितरण को exponential से chi-squared में रूपांतरित करता है, माध्य को बदले बिना block-time variance को कम करता है;
(3) एक OP_RETURN-आधारित forging-assignment तंत्र जो non-custodial पूल माइनिंग सक्षम करता है; और
(4) Dynamic compression scaling, जो hardware में सुधार के साथ दीर्घकालिक सुरक्षा मार्जिन बनाए रखने के लिए halving अनुसूचियों के अनुरूप plot-generation कठिनाई बढ़ाता है।

Bitcoin-PoCX न्यूनतम, feature-flagged संशोधनों के माध्यम से Bitcoin Core की वास्तुकला बनाए रखता है, PoC तर्क को मौजूदा consensus कोड से अलग करता है। सिस्टम 120-सेकंड block interval को लक्षित करके और block subsidy को 10 BTC में समायोजित करके Bitcoin की मौद्रिक नीति को संरक्षित करता है। कम subsidy block आवृत्ति में पाँच गुना वृद्धि की भरपाई करता है, दीर्घकालिक जारी दर को Bitcoin की मूल अनुसूची के साथ संरेखित रखता है और ~21 मिलियन अधिकतम आपूर्ति बनाए रखता है।

---

## 1. परिचय

### 1.1 प्रेरणा

Bitcoin का Proof-of-Work (PoW) सहमति एक दशक से अधिक समय से सुरक्षित साबित हुआ है, लेकिन महत्वपूर्ण लागत पर: miners को लगातार कम्प्यूटेशनल संसाधन खर्च करने होते हैं, जिसके परिणामस्वरूप उच्च ऊर्जा खपत होती है। दक्षता चिंताओं से परे, एक व्यापक प्रेरणा है: वैकल्पिक सहमति तंत्रों का अन्वेषण जो भागीदारी की बाधा को कम करते हुए सुरक्षा बनाए रखते हैं। PoC व्यावहारिक रूप से किसी को भी commodity स्टोरेज हार्डवेयर के साथ प्रभावी ढंग से mine करने में सक्षम बनाता है, ASIC-प्रभुत्व वाली PoW माइनिंग में देखे गए केंद्रीकरण दबावों को कम करता है।

Proof of Capacity (PoC) चल रही गणना के बजाय स्टोरेज प्रतिबद्धता से माइनिंग शक्ति प्राप्त करके इसे प्राप्त करता है। Miners एक बार के plotting चरण के दौरान डिस्क-संग्रहित hashes के बड़े सेट—plots—पूर्व-गणना करते हैं। माइनिंग तब हल्के lookups से मिलकर बनती है, संसाधन-आधारित सहमति की सुरक्षा धारणाओं को संरक्षित करते हुए ऊर्जा उपयोग को काफी कम करती है।

### 1.2 Bitcoin Core के साथ एकीकरण

Bitcoin-PoCX नई blockchain बनाने के बजाय PoC सहमति को Bitcoin Core में एकीकृत करता है। यह दृष्टिकोण Bitcoin Core की सिद्ध सुरक्षा, परिपक्व नेटवर्किंग स्टैक, और व्यापक रूप से अपनाए गए टूलिंग का लाभ उठाता है, जबकि संशोधनों को न्यूनतम और feature-flagged रखता है। PoC तर्क मौजूदा consensus कोड से अलग है, यह सुनिश्चित करते हुए कि मुख्य कार्यक्षमता—block सत्यापन, वॉलेट संचालन, लेनदेन प्रारूप—काफी हद तक अपरिवर्तित रहे।

### 1.3 डिज़ाइन लक्ष्य

**सुरक्षा**: Bitcoin-समतुल्य मजबूती बनाए रखें; हमलों के लिए बहुमत स्टोरेज क्षमता की आवश्यकता होती है।

**दक्षता**: चल रहे कम्प्यूटेशनल लोड को डिस्क I/O स्तरों तक कम करें।

**सुलभता**: Commodity हार्डवेयर के साथ माइनिंग सक्षम करें, प्रवेश की बाधाओं को कम करें।

**न्यूनतम एकीकरण**: न्यूनतम संशोधन पदचिह्न के साथ PoC सहमति प्रस्तुत करें।

---

## 2. पृष्ठभूमि: Proof of Capacity

### 2.1 इतिहास

Proof of Capacity (PoC) को Burstcoin द्वारा 2014 में Proof-of-Work (PoW) के ऊर्जा-कुशल विकल्प के रूप में प्रस्तुत किया गया था। Burstcoin ने प्रदर्शित किया कि माइनिंग शक्ति निरंतर रीयल-टाइम hashing के बजाय प्रतिबद्ध स्टोरेज से प्राप्त की जा सकती है: miners ने एक बार बड़े datasets ("plots") की पूर्व-गणना की और फिर उनके छोटे, निश्चित भागों को पढ़कर mine किया।

प्रारंभिक PoC कार्यान्वयनों ने अवधारणा को व्यवहार्य साबित किया लेकिन यह भी प्रकट किया कि plot प्रारूप और क्रिप्टोग्राफिक संरचना सुरक्षा के लिए महत्वपूर्ण हैं। कई time–memory tradeoffs ने हमलावरों को ईमानदार प्रतिभागियों से कम स्टोरेज के साथ प्रभावी ढंग से mine करने की अनुमति दी। इसने उजागर किया कि PoC सुरक्षा plot डिज़ाइन पर निर्भर करती है—केवल स्टोरेज को संसाधन के रूप में उपयोग करने पर नहीं।

Burstcoin की विरासत ने PoC को एक व्यावहारिक सहमति तंत्र के रूप में स्थापित किया और वह नींव प्रदान की जिस पर PoCX निर्मित है।

### 2.2 मुख्य अवधारणाएँ

PoC माइनिंग डिस्क पर संग्रहित बड़ी, पूर्व-गणित plot फ़ाइलों पर आधारित है। इन plots में "जमी हुई गणना" होती है: महंगी hashing plotting के दौरान एक बार की जाती है, और माइनिंग तब हल्के डिस्क reads और सरल सत्यापन से मिलकर बनती है। मुख्य तत्वों में शामिल हैं:

**Nonce:**
Plot डेटा की मूल इकाई। प्रत्येक nonce में miner के पते और nonce index से Shabal256 के माध्यम से जनरेट किए गए 4096 scoops (कुल 256 KiB) होते हैं।

**Scoop:**
Nonce के अंदर एक 64-बाइट खंड। प्रत्येक block के लिए, नेटवर्क पिछले block के generation signature के आधार पर निर्धारिक रूप से एक scoop index (0–4095) चुनता है। प्रति nonce केवल यह scoop पढ़ा जाना चाहिए।

**Generation Signature:**
पूर्व block से व्युत्पन्न 256-bit मान। यह scoop चयन के लिए entropy प्रदान करता है और miners को भविष्य के scoop indices की भविष्यवाणी करने से रोकता है।

**Warp:**
4096 nonces (1 GiB) का एक संरचनात्मक समूह। Warps compression-resistant plot प्रारूपों के लिए प्रासंगिक इकाई हैं।

### 2.3 माइनिंग प्रक्रिया और गुणवत्ता पाइपलाइन

PoC माइनिंग में एक बार का plotting चरण और एक हल्की प्रति-block दिनचर्या होती है:

**एक बार का सेटअप:**
- Plot जनरेशन: Shabal256 के माध्यम से nonces की गणना करें और उन्हें डिस्क पर लिखें।

**प्रति-Block माइनिंग:**
- Scoop चयन: Generation signature से scoop index निर्धारित करें।
- Plot स्कैनिंग: Miner के plots में सभी nonces से वह scoop पढ़ें।

**गुणवत्ता पाइपलाइन:**
- Raw गुणवत्ता: 64-bit गुणवत्ता मान (कम बेहतर है) प्राप्त करने के लिए Shabal256Lite का उपयोग करके प्रत्येक scoop को generation signature के साथ hash करें।
- Deadline: Base target (एक difficulty-adjusted पैरामीटर जो यह सुनिश्चित करता है कि नेटवर्क अपने लक्षित block interval तक पहुँचे) का उपयोग करके गुणवत्ता को deadline में बदलें: `deadline = quality / base_target`
- Bended deadline: अपेक्षित block समय को संरक्षित करते हुए variance को कम करने के लिए Time-Bending transformation लागू करें।

**Block Forging:**
सबसे छोटी (bended) deadline वाला miner उस समय के बीतने के बाद अगला block forge करता है।

PoW के विपरीत, लगभग सभी गणना plotting के दौरान होती है; सक्रिय माइनिंग मुख्य रूप से disk-bound और बहुत कम-शक्ति वाली है।

### 2.4 पूर्व प्रणालियों में ज्ञात कमजोरियाँ

**POC1 वितरण दोष:**
मूल Burstcoin POC1 प्रारूप में एक संरचनात्मक पूर्वाग्रह था: निम्न-index scoops उच्च-index scoops की तुलना में तुरंत पुनः-गणना करने में काफी सस्ते थे। इसने एक गैर-समान time–memory tradeoff प्रस्तुत किया, जिससे हमलावरों को उन scoops के लिए आवश्यक स्टोरेज कम करने की अनुमति मिली और यह धारणा टूट गई कि सभी पूर्व-गणित डेटा समान रूप से महंगा था।

**XOR Compression हमला (POC2):**
POC2 में, एक हमलावर 8192 nonces का कोई भी सेट ले सकता है और उन्हें 4096 nonces (A और B) के दो blocks में विभाजित कर सकता है। दोनों blocks को संग्रहित करने के बजाय, हमलावर केवल एक व्युत्पन्न संरचना संग्रहित करता है: `A ⊕ transpose(B)`, जहाँ transpose scoop और nonce indices को स्वैप करता है—block B में nonce N का scoop S, nonce S का scoop N बन जाता है।

माइनिंग के दौरान, जब nonce N का scoop S आवश्यक होता है, हमलावर इसे इस प्रकार पुनर्निर्मित करता है:
1. स्थिति (S, N) पर संग्रहित XOR मान पढ़ें
2. Scoop S प्राप्त करने के लिए block A से nonce N की गणना करें
3. Transposed scoop N प्राप्त करने के लिए block B से nonce S की गणना करें
4. मूल 64-बाइट scoop को पुनर्प्राप्त करने के लिए तीनों मानों को XOR करें

यह स्टोरेज को 50% कम करता है, जबकि प्रति lookup केवल दो nonce गणनाओं की आवश्यकता होती है—पूर्ण precomputation को लागू करने के लिए आवश्यक threshold से बहुत नीचे की लागत। हमला व्यवहार्य है क्योंकि एक row (एक nonce, 4096 scoops) की गणना करना सस्ता है, जबकि एक column (4096 nonces में एक single scoop) की गणना के लिए सभी nonces को पुनर्जनन करना आवश्यक होगा। Transpose संरचना इस असंतुलन को उजागर करती है।

इसने ऐसे plot प्रारूप की आवश्यकता प्रदर्शित की जो ऐसे संरचित पुनर्संयोजन को रोकता है और अंतर्निहित time–memory tradeoff को हटाता है। खंड 3.3 वर्णन करता है कि PoCX इस कमजोरी को कैसे संबोधित और हल करता है।

### 2.5 PoCX में संक्रमण

पहले के PoC सिस्टमों की सीमाओं ने स्पष्ट किया कि सुरक्षित, निष्पक्ष, और विकेंद्रीकृत स्टोरेज माइनिंग सावधानीपूर्वक इंजीनियर की गई plot संरचनाओं पर निर्भर करती है। Bitcoin-PoCX इन मुद्दों को एक कठोर plot प्रारूप, बेहतर deadline वितरण, और विकेंद्रीकृत पूल माइनिंग के तंत्रों के साथ संबोधित करता है—अगले खंड में वर्णित।

---

## 3. PoCX Plot प्रारूप

### 3.1 आधार Nonce निर्माण

Nonce एक 256 KiB डेटा संरचना है जो तीन पैरामीटरों से निर्धारिक रूप से व्युत्पन्न होती है: एक 20-बाइट address payload, एक 32-बाइट seed, और एक 64-bit nonce index।

निर्माण इन इनपुटों को संयोजित करके और प्रारंभिक hash उत्पन्न करने के लिए Shabal256 के साथ उन्हें hash करके शुरू होता है। यह hash एक पुनरावृत्त विस्तार प्रक्रिया के लिए प्रारंभिक बिंदु के रूप में कार्य करता है: Shabal256 बार-बार लागू किया जाता है, प्रत्येक चरण पहले जनरेट किए गए डेटा पर निर्भर करता है, जब तक कि पूरा 256 KiB buffer नहीं भर जाता। यह श्रृंखलाबद्ध प्रक्रिया plotting के दौरान किए गए कम्प्यूटेशनल कार्य का प्रतिनिधित्व करती है।

एक अंतिम diffusion चरण पूर्ण buffer को hash करता है और परिणाम को सभी bytes में XOR करता है। यह सुनिश्चित करता है कि पूर्ण buffer की गणना की गई है और miners गणना को shortcut नहीं कर सकते। फिर PoC2 shuffle लागू किया जाता है, प्रत्येक scoop के निचले और ऊपरी हिस्सों को स्वैप करके यह गारंटी देता है कि सभी scoops को समान कम्प्यूटेशनल प्रयास की आवश्यकता होती है।

अंतिम nonce में प्रत्येक 64 bytes के 4096 scoops होते हैं और माइनिंग में उपयोग की जाने वाली मौलिक इकाई बनाते हैं।

### 3.2 SIMD-संरेखित Plot लेआउट

आधुनिक हार्डवेयर पर throughput को अधिकतम करने के लिए, PoCX vectorized प्रसंस्करण को सुविधाजनक बनाने के लिए nonce डेटा को डिस्क पर व्यवस्थित करता है। प्रत्येक nonce को क्रमिक रूप से संग्रहित करने के बजाय, PoCX कई consecutive nonces में संबंधित 4-बाइट words को contiguously संरेखित करता है। यह एक single memory fetch को सभी SIMD lanes के लिए डेटा प्रदान करने की अनुमति देता है, cache misses को न्यूनतम करता है और scatter-gather overhead को समाप्त करता है।

```
पारंपरिक लेआउट:
Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX SIMD लेआउट:
Word0: [N0][N1][N2]...[N15]
Word1: [N0][N1][N2]...[N15]
Word2: [N0][N1][N2]...[N15]
```

यह लेआउट CPU और GPU दोनों miners को लाभ पहुँचाता है, उच्च-throughput, parallelized scoop evaluation सक्षम करता है जबकि consensus सत्यापन के लिए एक सरल scalar access pattern बनाए रखता है। यह सुनिश्चित करता है कि माइनिंग CPU गणना के बजाय स्टोरेज bandwidth द्वारा सीमित है, Proof of Capacity की कम-शक्ति प्रकृति को बनाए रखता है।

### 3.3 Warp संरचना और XOR-Transpose Encoding

Warp PoCX में मौलिक स्टोरेज इकाई है, जिसमें 4096 nonces (1 GiB) होते हैं। असंपीड़ित प्रारूप, जिसे X0 कहा जाता है, में खंड 3.1 में निर्माण द्वारा उत्पादित आधार nonces बिल्कुल वैसे ही होते हैं।

**XOR-Transpose Encoding (X1)**

पहले के PoC सिस्टमों में मौजूद संरचनात्मक time–memory tradeoffs को हटाने के लिए, PoCX X0 warps के जोड़ों पर XOR-transpose encoding लागू करके एक कठोर माइनिंग प्रारूप, X1, व्युत्पन्न करता है।

X1 warp में nonce N का scoop S बनाने के लिए:

1. पहले X0 warp से nonce N का scoop S लें (प्रत्यक्ष स्थिति)
2. दूसरे X0 warp से nonce S का scoop N लें (transposed स्थिति)
3. X1 scoop प्राप्त करने के लिए दो 64-बाइट मानों को XOR करें

Transpose चरण scoop और nonce indices को स्वैप करता है। Matrix शब्दों में—जहाँ rows scoops का प्रतिनिधित्व करते हैं और columns nonces का—यह पहले warp में स्थिति (S, N) पर तत्व को दूसरे में (N, S) पर तत्व के साथ संयोजित करता है।

**यह Compression Attack Surface को क्यों समाप्त करता है**

XOR-transpose प्रत्येक scoop को अंतर्निहित X0 डेटा की एक पूरी row और एक पूरी column के साथ interlocks करता है। इसलिए एक single X1 scoop को पुनर्प्राप्त करने के लिए सभी 4096 scoop indices में फैले डेटा तक पहुँच की आवश्यकता होती है। गायब डेटा की गणना करने का कोई भी प्रयास एक single nonce के बजाय 4096 पूर्ण nonces को पुनर्जनन करने की आवश्यकता होगी—POC2 (खंड 2.4) के लिए XOR हमले द्वारा शोषित असममित लागत संरचना को हटाता है।

परिणामस्वरूप, पूर्ण X1 warp को संग्रहित करना miners के लिए एकमात्र कम्प्यूटेशनल रूप से व्यवहार्य रणनीति बन जाती है, पूर्व डिज़ाइनों में शोषित time–memory tradeoff को बंद करता है।

### 3.4 डिस्क लेआउट

PoCX plot फ़ाइलें कई consecutive X1 warps से मिलकर बनती हैं। माइनिंग के दौरान संचालन दक्षता को अधिकतम करने के लिए, प्रत्येक फ़ाइल के भीतर डेटा scoop द्वारा व्यवस्थित किया जाता है: प्रत्येक warp से सभी scoop 0 डेटा क्रमिक रूप से संग्रहित होता है, उसके बाद सभी scoop 1 डेटा, और इसी तरह, scoop 4095 तक।

यह **scoop-sequential ordering** miners को एक single sequential डिस्क access में चयनित scoop के लिए आवश्यक पूर्ण डेटा पढ़ने की अनुमति देती है, seek times को न्यूनतम करती है और commodity स्टोरेज devices पर throughput को अधिकतम करती है।

खंड 3.3 के XOR-transpose encoding के साथ संयुक्त, यह लेआउट सुनिश्चित करता है कि फ़ाइल दोनों **संरचनात्मक रूप से कठोर** और **संचालन रूप से कुशल** है: sequential scoop ordering इष्टतम डिस्क I/O का समर्थन करती है, जबकि SIMD-संरेखित memory layouts (खंड 3.2 देखें) उच्च-throughput, parallelized scoop evaluation की अनुमति देते हैं।

### 3.5 Proof-of-Work Scaling (Xn)

PoCX विकसित हार्डवेयर प्रदर्शन के अनुकूल होने के लिए scaling levels की अवधारणा के माध्यम से, जिसे Xn दर्शाया जाता है, scalable precomputation लागू करता है। Baseline X1 प्रारूप पहली XOR-transpose hardened warp संरचना का प्रतिनिधित्व करता है।

प्रत्येक scaling level Xn, X1 के सापेक्ष प्रत्येक warp में एम्बेडेड proof-of-work को exponentially बढ़ाता है: level Xn पर आवश्यक कार्य X1 का 2^(n-1) गुना है। Xn से Xn+1 में संक्रमण संचालन रूप से आसन्न warps के जोड़ों में XOR लागू करने के बराबर है, अंतर्निहित plot आकार को बदले बिना अधिक proof-of-work को incrementally एम्बेड करता है।

निम्न scaling levels पर बनाई गई मौजूदा plot फ़ाइलें अभी भी माइनिंग के लिए उपयोग की जा सकती हैं, लेकिन वे block generation में आनुपातिक रूप से कम कार्य योगदान करती हैं, उनके निम्न एम्बेडेड proof-of-work को प्रतिबिंबित करते हुए। यह तंत्र सुनिश्चित करता है कि PoCX plots समय के साथ सुरक्षित, लचीले, और आर्थिक रूप से संतुलित रहें।

### 3.6 Seed कार्यक्षमता

Seed पैरामीटर मैन्युअल समन्वय के बिना प्रति address एकाधिक गैर-overlapping plots सक्षम करता है।

**समस्या (POC2)**: Miners को overlap से बचने के लिए plot फ़ाइलों में nonce ranges को मैन्युअल रूप से ट्रैक करना पड़ता था। Overlapping nonces माइनिंग शक्ति बढ़ाए बिना स्टोरेज बर्बाद करते हैं।

**समाधान**: प्रत्येक `(address, seed)` जोड़ी एक स्वतंत्र keyspace परिभाषित करती है। विभिन्न seeds वाले plots nonce ranges की परवाह किए बिना कभी overlap नहीं होते। Miners समन्वय के बिना स्वतंत्र रूप से plots बना सकते हैं।

---

## 4. Proof of Capacity सहमति

PoCX एक storage-bound proof तंत्र के साथ Bitcoin के Nakamoto सहमति का विस्तार करता है। बार-बार hashing पर ऊर्जा खर्च करने के बजाय, miners पूर्व-गणित डेटा की बड़ी मात्रा—plots—को डिस्क पर commit करते हैं। Block generation के दौरान, उन्हें इस डेटा का एक छोटा, अप्रत्याशित भाग खोजना होगा और इसे proof में रूपांतरित करना होगा। जो miner अपेक्षित समय विंडो के भीतर सर्वोत्तम proof प्रदान करता है, उसे अगला block forge करने का अधिकार मिलता है।

यह अध्याय वर्णन करता है कि PoCX block metadata को कैसे संरचित करता है, अप्रत्याशितता कैसे व्युत्पन्न करता है, और स्थिर स्टोरेज को एक सुरक्षित, कम-variance सहमति तंत्र में कैसे रूपांतरित करता है।

### 4.1 Block संरचना

PoCX परिचित Bitcoin-शैली block header को बनाए रखता है लेकिन capacity-based माइनिंग के लिए आवश्यक अतिरिक्त consensus fields प्रस्तुत करता है। ये fields सामूहिक रूप से block को miner के संग्रहित plot, नेटवर्क की difficulty, और प्रत्येक माइनिंग चुनौती को परिभाषित करने वाली cryptographic entropy से बाँधते हैं।

उच्च स्तर पर, एक PoCX block में शामिल है: block height, contextual सत्यापन को सरल बनाने के लिए स्पष्ट रूप से रिकॉर्ड; generation signature, प्रत्येक block को उसके पूर्ववर्ती से जोड़ने वाली ताज़ा entropy का स्रोत; base target, inverse रूप में नेटवर्क difficulty का प्रतिनिधित्व करता है (उच्च मान आसान माइनिंग के अनुरूप हैं); PoCX proof, miner के plot, plotting के दौरान उपयोग किए गए compression level, चयनित nonce, और इससे व्युत्पन्न गुणवत्ता की पहचान करता है; और एक signing key और signature, block forge करने के लिए उपयोग की गई क्षमता (या assigned forging key) पर नियंत्रण साबित करते हैं।

Proof में validators द्वारा चुनौती की पुनः-गणना, चुने हुए scoop को सत्यापित करने, और परिणामी गुणवत्ता की पुष्टि करने के लिए आवश्यक सभी consensus-relevant जानकारी एम्बेडेड है। Block संरचना को redesign करने के बजाय extend करके, PoCX माइनिंग कार्य के मौलिक रूप से भिन्न स्रोत को सक्षम करते हुए Bitcoin के साथ conceptually संरेखित रहता है।

### 4.2 Generation Signature Chain

Generation signature सुरक्षित Proof of Capacity माइनिंग के लिए आवश्यक अप्रत्याशितता प्रदान करता है। प्रत्येक block अपना generation signature पिछले block के signature और signer से व्युत्पन्न करता है, यह सुनिश्चित करते हुए कि miners भविष्य की चुनौतियों का अनुमान नहीं लगा सकते या लाभदायक plot क्षेत्रों की पूर्व-गणना नहीं कर सकते:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

यह cryptographically मजबूत, miner-dependent entropy मानों का एक अनुक्रम उत्पन्न करता है। क्योंकि miner की public key पिछला block प्रकाशित होने तक अज्ञात है, कोई भी प्रतिभागी भविष्य के scoop selections की भविष्यवाणी नहीं कर सकता। यह चुनिंदा precomputation या रणनीतिक plotting को रोकता है और सुनिश्चित करता है कि प्रत्येक block वास्तव में ताज़ा माइनिंग कार्य प्रस्तुत करता है।

### 4.3 Forging प्रक्रिया

PoCX में माइनिंग पूरी तरह से generation signature द्वारा संचालित proof में संग्रहित डेटा को रूपांतरित करने से मिलकर बनती है। हालाँकि प्रक्रिया निर्धारिक है, signature की अप्रत्याशितता सुनिश्चित करती है कि miners पहले से तैयारी नहीं कर सकते और उन्हें बार-बार अपने संग्रहित plots तक पहुँचना होगा।

**Challenge Derivation (Scoop Selection):** Miner वर्तमान generation signature को block height के साथ hash करता है ताकि 0–4095 की सीमा में एक scoop index प्राप्त हो। यह index निर्धारित करता है कि प्रत्येक संग्रहित nonce का कौन सा 64-बाइट खंड proof में भाग लेता है। क्योंकि generation signature पिछले block के signer पर निर्भर करता है, scoop selection केवल block प्रकाशन के क्षण में ज्ञात होता है।

**Proof Evaluation (Quality Calculation):** Plot में प्रत्येक nonce के लिए, miner चयनित scoop को पुनर्प्राप्त करता है और गुणवत्ता प्राप्त करने के लिए इसे generation signature के साथ hash करता है—एक 64-bit मान जिसकी magnitude miner की प्रतिस्पर्धात्मकता निर्धारित करती है। निम्न गुणवत्ता बेहतर proof के अनुरूप है।

**Deadline Formation (Time Bending):** Raw deadline गुणवत्ता के आनुपातिक और base target के व्युत्क्रमानुपाती है। Legacy PoC डिज़ाइनों में, ये deadlines अत्यधिक skewed exponential वितरण का पालन करती थीं, जो बिना अतिरिक्त सुरक्षा प्रदान किए लंबी tail delays उत्पन्न करती थीं। PoCX Time Bending (खंड 4.4) का उपयोग करके raw deadline को रूपांतरित करता है, variance को कम करता है और पूर्वानुमेय block intervals सुनिश्चित करता है। एक बार bended deadline बीतने के बाद, miner proof एम्बेड करके और इसे effective forging key से sign करके एक block forge करता है।

### 4.4 Time Bending

Proof of Capacity exponentially वितरित deadlines उत्पन्न करता है। एक छोटी अवधि के बाद—आमतौर पर कुछ दर्जन सेकंड—प्रत्येक miner ने पहले से ही अपना सर्वोत्तम proof पहचान लिया है, और कोई भी अतिरिक्त प्रतीक्षा समय केवल latency योगदान देता है, सुरक्षा नहीं।

Time Bending cube root transformation लागू करके वितरण को reshape करता है:

`deadline_bended = scale × (quality / base_target)^(1/3)`

Scale factor अपेक्षित block समय (120 सेकंड) को संरक्षित करता है जबकि variance को नाटकीय रूप से कम करता है। छोटी deadlines का विस्तार किया जाता है, block propagation और नेटवर्क सुरक्षा में सुधार करता है। लंबी deadlines को संपीड़ित किया जाता है, outliers को chain में देरी करने से रोकता है।

![Block Time Distributions](blocktime_distributions.svg)

Time Bending अंतर्निहित proof की informational content को बनाए रखता है। यह miners के बीच प्रतिस्पर्धात्मकता को संशोधित नहीं करता; यह केवल smoother, अधिक पूर्वानुमेय block intervals उत्पन्न करने के लिए प्रतीक्षा समय को पुनर्आवंटित करता है। कार्यान्वयन सभी platforms में निर्धारिक परिणाम सुनिश्चित करने के लिए fixed-point arithmetic (Q42 format) और 256-bit integers का उपयोग करता है।

### 4.5 Difficulty Adjustment

PoCX base target, एक inverse difficulty माप, का उपयोग करके block उत्पादन को नियंत्रित करता है। अपेक्षित block समय `quality / base_target` के अनुपात के आनुपातिक है, इसलिए base target बढ़ाना block निर्माण को तेज करता है जबकि इसे घटाना chain को धीमा करता है।

Difficulty प्रत्येक block पर हाल के blocks के बीच मापे गए समय की तुलना target interval से करके adjust होती है। यह बार-बार adjustment आवश्यक है क्योंकि स्टोरेज क्षमता को जल्दी जोड़ा या हटाया जा सकता है—Bitcoin के hashpower के विपरीत, जो अधिक धीरे-धीरे बदलता है।

Adjustment दो मार्गदर्शक बाधाओं का पालन करता है: **Graduality**—प्रति-block परिवर्तन bounded हैं (अधिकतम ±20%) oscillations या manipulation से बचने के लिए; **Hardening**—base target अपने genesis मान से अधिक नहीं हो सकता, नेटवर्क को मूल सुरक्षा धारणाओं से नीचे difficulty कम करने से रोकता है।

### 4.6 Block वैधता

PoCX में एक block तब वैध होता है जब यह consensus स्थिति के अनुरूप एक सत्यापन योग्य storage-derived proof प्रस्तुत करता है। Validators स्वतंत्र रूप से scoop selection की पुनः-गणना करते हैं, सबमिट किए गए nonce और plot metadata से अपेक्षित गुणवत्ता व्युत्पन्न करते हैं, Time Bending transformation लागू करते हैं, और पुष्टि करते हैं कि miner घोषित समय पर block forge करने के योग्य था।

विशेष रूप से, एक वैध block के लिए आवश्यक है: parent block के बाद से deadline बीत चुकी है; सबमिट की गई गुणवत्ता proof के लिए गणना की गई गुणवत्ता से मेल खाती है; scaling level नेटवर्क न्यूनतम को पूरा करता है; generation signature अपेक्षित मान से मेल खाता है; base target अपेक्षित मान से मेल खाता है; block signature effective signer से आता है; और coinbase effective signer के पते पर भुगतान करता है।

---

## 5. Forging Assignments

### 5.1 प्रेरणा

Forging assignments plot स्वामियों को अपने plots के स्वामित्व को कभी त्यागे बिना block-forging अधिकार सौंपने की अनुमति देते हैं। यह तंत्र PoCX की सुरक्षा गारंटियों को संरक्षित करते हुए पूल माइनिंग और cold-storage सेटअपों को सक्षम करता है।

पूल माइनिंग में, plot स्वामी एक पूल को उनकी ओर से blocks forge करने के लिए अधिकृत कर सकते हैं। पूल blocks को assemble करता है और पुरस्कार वितरित करता है, लेकिन इसे plots पर कभी custody नहीं मिलती। Delegation किसी भी समय reversible है, और plot स्वामी replotting के बिना पूल छोड़ने या configurations बदलने के लिए स्वतंत्र रहते हैं।

Assignments cold और hot keys के बीच स्वच्छ पृथक्करण का भी समर्थन करते हैं। Plot को नियंत्रित करने वाली private key offline रह सकती है, जबकि एक अलग forging key—एक online machine पर संग्रहित—blocks उत्पन्न करती है। इसलिए forging key का compromise केवल forging अधिकार को compromise करता है, स्वामित्व को नहीं। Plot सुरक्षित रहता है और assignment को रद्द किया जा सकता है, सुरक्षा gap को तुरंत बंद करता है।

इस प्रकार Forging assignments इस सिद्धांत को बनाए रखते हुए संचालन लचीलापन प्रदान करते हैं कि संग्रहित क्षमता पर नियंत्रण कभी मध्यस्थों को स्थानांतरित नहीं होना चाहिए।

### 5.2 Assignment Protocol

Assignments को UTXO सेट की अनावश्यक वृद्धि से बचने के लिए OP_RETURN लेनदेन के माध्यम से घोषित किया जाता है। एक assignment लेनदेन plot address और उस forging address को निर्दिष्ट करता है जो उस plot की क्षमता का उपयोग करके blocks उत्पन्न करने के लिए अधिकृत है। एक revocation लेनदेन में केवल plot address होता है। दोनों मामलों में, plot स्वामी लेनदेन के spending input पर हस्ताक्षर करके नियंत्रण साबित करता है।

प्रत्येक assignment अच्छी तरह से परिभाषित states (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED) के अनुक्रम से गुज़रता है। Assignment लेनदेन की पुष्टि के बाद, सिस्टम एक छोटे activation चरण में प्रवेश करता है। यह विलंब—30 blocks, लगभग एक घंटा—block races के दौरान स्थिरता सुनिश्चित करता है और forging identities की adversarial तेज़ switching को रोकता है। एक बार यह activation अवधि समाप्त होने के बाद, assignment सक्रिय हो जाता है और तब तक रहता है जब तक plot स्वामी revocation जारी नहीं करता।

Revocations 720 blocks, लगभग एक दिन, की लंबी विलंब अवधि में संक्रमण करते हैं। इस समय के दौरान, पिछला forging address सक्रिय रहता है। यह लंबा विलंब पूलों के लिए संचालन स्थिरता प्रदान करता है, रणनीतिक "assignment hopping" को रोकता है और infrastructure प्रदाताओं को कुशलतापूर्वक संचालन करने के लिए पर्याप्त निश्चितता देता है। Revocation विलंब समाप्त होने के बाद, revocation पूर्ण हो जाता है, और plot स्वामी एक नई forging key नामित करने के लिए स्वतंत्र है।

Assignment state को UTXO सेट के समानांतर एक consensus-layer संरचना में बनाए रखा जाता है और chain reorganizations के सुरक्षित handling के लिए undo data का समर्थन करता है।

### 5.3 सत्यापन नियम

प्रत्येक block के लिए, validators effective signer निर्धारित करते हैं—वह पता जिसे block पर हस्ताक्षर करना होगा और coinbase पुरस्कार प्राप्त करना होगा। यह signer पूरी तरह से block की height पर assignment state पर निर्भर करता है।

यदि कोई assignment मौजूद नहीं है या assignment ने अभी तक अपना activation चरण पूरा नहीं किया है, तो plot स्वामी effective signer रहता है। एक बार assignment सक्रिय हो जाने पर, assigned forging address को हस्ताक्षर करना होगा। Revocation के दौरान, forging address तब तक हस्ताक्षर करता रहता है जब तक revocation विलंब समाप्त नहीं हो जाता। केवल तभी अधिकार plot स्वामी को वापस मिलता है।

Validators यह लागू करते हैं कि block signature effective signer द्वारा उत्पादित है, कि coinbase उसी पते पर भुगतान करता है, और कि सभी transitions निर्धारित activation और revocation विलंबों का पालन करते हैं। केवल plot स्वामी assignments बना या रद्द कर सकता है; forging keys अपनी अनुमतियों को संशोधित या extend नहीं कर सकतीं।

इसलिए Forging assignments विश्वास प्रस्तुत किए बिना लचीला delegation प्रस्तुत करते हैं। अंतर्निहित क्षमता का स्वामित्व हमेशा plot स्वामी से cryptographically anchored रहता है, जबकि forging अधिकार को संचालन आवश्यकताओं के विकास के अनुसार delegate, rotate, या revoke किया जा सकता है।

---

## 6. Dynamic Scaling

जैसे-जैसे hardware विकसित होता है, plots की गणना करने की लागत डिस्क से precomputed कार्य पढ़ने के सापेक्ष घटती है। प्रतिउपायों के बिना, हमलावर अंततः honest miners के संग्रहित कार्य पढ़ने से तेज़ी से proofs on-the-fly उत्पन्न कर सकते हैं, Proof of Capacity के सुरक्षा मॉडल को कमज़ोर करते हुए।

इच्छित सुरक्षा मार्जिन को संरक्षित करने के लिए, PoCX एक scaling अनुसूची लागू करता है: plots के लिए न्यूनतम आवश्यक scaling level समय के साथ बढ़ता है। प्रत्येक scaling level Xn, जैसा कि खंड 3.5 में वर्णित है, plot संरचना के भीतर exponentially अधिक proof-of-work एम्बेड करता है, यह सुनिश्चित करते हुए कि miners पर्याप्त स्टोरेज संसाधन commit करते रहें भले ही गणना सस्ती हो जाए।

अनुसूची नेटवर्क के आर्थिक प्रोत्साहनों, विशेष रूप से block reward halvings, के साथ संरेखित होती है। जैसे-जैसे प्रति block पुरस्कार घटता है, न्यूनतम level धीरे-धीरे बढ़ता है, plotting प्रयास और माइनिंग potential के बीच संतुलन को संरक्षित करता है:

| अवधि | वर्ष | Halvings | न्यूनतम Scaling | Plot कार्य गुणक |
|------|------|----------|-----------------|------------------|
| Epoch 0 | 0-4 | 0 | X1 | 2× baseline |
| Epoch 1 | 4-12 | 1-2 | X2 | 4× baseline |
| Epoch 2 | 12-28 | 3-6 | X3 | 8× baseline |
| Epoch 3 | 28-60 | 7-14 | X4 | 16× baseline |
| Epoch 4 | 60-124 | 15-30 | X5 | 32× baseline |
| Epoch 5 | 124+ | 31+ | X6 | 64× baseline |

Miners वैकल्पिक रूप से वर्तमान न्यूनतम से एक level अधिक plots तैयार कर सकते हैं, जिससे उन्हें आगे की योजना बनाने और नेटवर्क के अगले epoch में transition होने पर तत्काल upgrades से बचने की अनुमति मिलती है। यह वैकल्पिक चरण block संभावना के मामले में अतिरिक्त लाभ प्रदान नहीं करता—यह केवल एक smoother संचालन transition की अनुमति देता है।

उनकी height के लिए न्यूनतम scaling level से नीचे proofs वाले blocks अमान्य माने जाते हैं। Validators consensus सत्यापन के दौरान proof में घोषित scaling level को वर्तमान नेटवर्क आवश्यकता के विरुद्ध जाँचते हैं, यह सुनिश्चित करते हुए कि सभी भाग लेने वाले miners विकसित सुरक्षा अपेक्षाओं को पूरा करते हैं।

---

## 7. माइनिंग वास्तुकला

PoCX माइनिंग के संसाधन-गहन कार्यों से consensus-critical संचालन को अलग करता है, सुरक्षा और दक्षता दोनों सक्षम करता है। नोड blockchain बनाए रखता है, blocks को validate करता है, mempool प्रबंधित करता है, और एक RPC interface expose करता है। External miners plot स्टोरेज, scoop reading, quality calculation, और deadline प्रबंधन संभालते हैं। यह पृथक्करण consensus logic को सरल और auditable रखता है जबकि miners को डिस्क throughput के लिए optimize करने की अनुमति देता है।

### 7.1 माइनिंग RPC Interface

Miners नोड के साथ RPC calls के एक न्यूनतम सेट के माध्यम से interact करते हैं। get_mining_info RPC वर्तमान block height, generation signature, base target, target deadline, और plot scaling levels की स्वीकार्य सीमा प्रदान करता है। इस जानकारी का उपयोग करके, miners candidate nonces की गणना करते हैं। submit_nonce RPC miners को एक प्रस्तावित समाधान सबमिट करने की अनुमति देता है, जिसमें plot identifier, nonce index, scaling level, और miner account शामिल है। नोड submission का मूल्यांकन करता है और proof वैध होने पर गणना की गई deadline के साथ प्रतिक्रिया देता है।

### 7.2 Forging Scheduler

नोड एक forging scheduler बनाए रखता है, जो incoming submissions को track करता है और प्रत्येक block height के लिए केवल सर्वोत्तम समाधान रखता है। सबमिट किए गए nonces submission flooding या denial-of-service हमलों के विरुद्ध built-in सुरक्षाओं के साथ queue किए जाते हैं। Scheduler तब तक प्रतीक्षा करता है जब तक गणना की गई deadline समाप्त नहीं हो जाती या एक बेहतर समाधान नहीं आ जाता, जिस बिंदु पर यह एक block assemble करता है, इसे effective forging key का उपयोग करके sign करता है, और इसे नेटवर्क पर publish करता है।

### 7.3 Defensive Forging

Timing हमलों या clock manipulation के लिए प्रोत्साहनों को रोकने के लिए, PoCX defensive forging लागू करता है। यदि समान height के लिए एक competing block आता है, तो scheduler स्थानीय समाधान की तुलना नए block से करता है। यदि स्थानीय गुणवत्ता बेहतर है, तो नोड मूल deadline की प्रतीक्षा करने के बजाय तुरंत forge करता है। यह सुनिश्चित करता है कि miners केवल स्थानीय clocks को समायोजित करके लाभ प्राप्त नहीं कर सकते; सर्वोत्तम समाधान हमेशा प्रबल होता है, निष्पक्षता और नेटवर्क सुरक्षा को संरक्षित करता है।

---

## 8. सुरक्षा विश्लेषण

### 8.1 Threat Model

PoCX पर्याप्त लेकिन bounded क्षमताओं वाले adversaries को मॉडल करता है। हमलावर सत्यापन paths को stress-test करने के लिए अमान्य transactions, malformed blocks, या fabricated proofs के साथ नेटवर्क को overload करने का प्रयास कर सकते हैं। वे अपनी स्थानीय clocks को स्वतंत्र रूप से manipulate कर सकते हैं और timestamp handling, difficulty adjustment dynamics, या reorganization rules जैसे consensus व्यवहार में edge cases का exploit करने का प्रयास कर सकते हैं। Adversaries से targeted chain forks के माध्यम से history को rewrite करने के अवसरों की भी जाँच की अपेक्षा है।

मॉडल मानता है कि कोई भी single party कुल नेटवर्क स्टोरेज क्षमता के बहुमत को नियंत्रित नहीं करती। किसी भी resource-based consensus तंत्र की तरह, एक 51% क्षमता हमलावर एकतरफा रूप से chain को reorganize कर सकता है; यह मौलिक सीमा PoCX के लिए विशिष्ट नहीं है। PoCX यह भी मानता है कि हमलावर honest miners के डिस्क से पढ़ने की तुलना में plot डेटा की गणना तेज़ी से नहीं कर सकते। Scaling अनुसूची (खंड 6) सुनिश्चित करती है कि सुरक्षा के लिए आवश्यक computational gap समय के साथ hardware में सुधार होने पर बढ़ता है।

अगले खंड प्रत्येक प्रमुख हमला वर्ग की विस्तार से जाँच करते हैं और PoCX में निर्मित प्रतिउपायों का वर्णन करते हैं।

### 8.2 Capacity Attacks

PoW की तरह, बहुमत क्षमता वाला हमलावर history को rewrite कर सकता है (51% हमला)। इसे प्राप्त करने के लिए honest नेटवर्क से बड़ा physical स्टोरेज footprint प्राप्त करना आवश्यक है—एक महंगा और logistically मांग वाला उपक्रम। Hardware प्राप्त होने के बाद, operating costs कम हैं, लेकिन प्रारंभिक निवेश ईमानदारी से व्यवहार करने के लिए एक मजबूत आर्थिक प्रोत्साहन बनाता है: chain को कमज़ोर करना हमलावर के अपने asset base के मूल्य को नुकसान पहुँचाएगा।

PoC PoS से जुड़े nothing-at-stake मुद्दे से भी बचता है। हालाँकि miners कई competing forks के विरुद्ध plots स्कैन कर सकते हैं, प्रत्येक scan वास्तविक समय खपत करता है—आमतौर पर प्रति chain दसों सेकंड के क्रम में। 120-सेकंड block interval के साथ, यह स्वाभाविक रूप से multi-fork माइनिंग को सीमित करता है, और कई forks को एक साथ mine करने का प्रयास सभी पर प्रदर्शन को degrade करता है। इसलिए Fork माइनिंग costless नहीं है; यह मौलिक रूप से I/O throughput द्वारा बाधित है।

भले ही भविष्य के hardware ने near-instantaneous plot scanning (जैसे, high-speed SSDs) की अनुमति दी, हमलावर को अभी भी नेटवर्क क्षमता के बहुमत को नियंत्रित करने के लिए पर्याप्त physical संसाधन आवश्यकता का सामना करना होगा, जो 51%-style हमले को महंगा और logistically चुनौतीपूर्ण बनाता है।

अंत में, capacity attacks को hashpower attacks की तुलना में किराए पर लेना कहीं अधिक कठिन है। GPU compute को demand पर प्राप्त किया जा सकता है और किसी भी PoW chain पर तुरंत redirect किया जा सकता है। इसके विपरीत, PoC के लिए physical hardware, time-intensive plotting, और ongoing I/O operations की आवश्यकता होती है। ये बाधाएँ short-term, opportunistic हमलों को कहीं कम feasible बनाती हैं।

### 8.3 Timing Attacks

Proof of Capacity में Proof of Work की तुलना में timing अधिक महत्वपूर्ण भूमिका निभाती है। PoW में, timestamps मुख्य रूप से difficulty adjustment को प्रभावित करते हैं; PoC में, वे निर्धारित करते हैं कि miner की deadline बीत चुकी है या नहीं और इस प्रकार block forging के योग्य है या नहीं। Deadlines को parent block के timestamp के सापेक्ष मापा जाता है, लेकिन नोड की स्थानीय clock का उपयोग यह judge करने के लिए किया जाता है कि incoming block भविष्य में बहुत दूर है या नहीं। इस कारण PoCX एक tight timestamp tolerance लागू करता है: blocks नोड की स्थानीय clock से 15 सेकंड से अधिक विचलित नहीं हो सकते (Bitcoin की 2-घंटे की विंडो की तुलना में)। यह सीमा दोनों दिशाओं में काम करती है—भविष्य में बहुत दूर के blocks reject किए जाते हैं, और धीमी clocks वाले nodes वैध incoming blocks को गलत तरीके से reject कर सकते हैं।

इसलिए Nodes को NTP या समकक्ष time source का उपयोग करके अपनी clocks को synchronize करना चाहिए। PoCX जानबूझकर network-internal time sources पर निर्भर होने से बचता है ताकि हमलावरों को perceived network time को manipulate करने से रोका जा सके। Nodes अपने drift की निगरानी करते हैं और यदि स्थानीय clock हाल के block timestamps से diverge होने लगती है तो warnings emit करते हैं।

Clock acceleration—थोड़ा पहले forge करने के लिए fast स्थानीय clock चलाना—केवल marginal लाभ प्रदान करता है। Allowed tolerance के भीतर, defensive forging (खंड 7.3) सुनिश्चित करता है कि बेहतर समाधान वाला miner एक inferior early block देखने पर तुरंत publish करेगा। Fast clock केवल एक miner को already-winning समाधान कुछ सेकंड पहले publish करने में मदद करती है; यह एक inferior proof को winning में नहीं बदल सकती।

Timestamps के माध्यम से difficulty को manipulate करने के प्रयास ±20% प्रति-block adjustment cap और 24-block rolling window द्वारा bounded हैं, miners को short-term timing games के माध्यम से difficulty को meaningfully प्रभावित करने से रोकता है।

### 8.4 Time–Memory Tradeoff Attacks

Time–memory tradeoffs demand पर plot के parts को recomputing करके स्टोरेज आवश्यकताओं को कम करने का प्रयास करते हैं। पूर्व Proof of Capacity सिस्टम ऐसे हमलों के प्रति vulnerable थे, विशेष रूप से POC1 scoop-imbalance flaw और POC2 XOR-transpose compression हमला (खंड 2.4)। दोनों ने plot डेटा के certain portions को regenerate करना कितना महंगा था इसमें asymmetries का exploit किया, adversaries को केवल small computational penalty देते हुए स्टोरेज कम करने की अनुमति दी। साथ ही, PoC2 के वैकल्पिक plot प्रारूप भी similar TMTO कमजोरियों से पीड़ित हैं; एक प्रमुख उदाहरण Chia है, जिसका plot प्रारूप 4 से अधिक के factor से arbitrarily कम किया जा सकता है।

PoCX अपने nonce निर्माण और warp प्रारूप के माध्यम से इन attack surfaces को पूरी तरह से हटाता है। प्रत्येक nonce के भीतर, final diffusion चरण पूर्ण रूप से computed buffer को hash करता है और परिणाम को सभी bytes में XOR करता है, यह सुनिश्चित करते हुए कि buffer का हर हिस्सा हर दूसरे हिस्से पर निर्भर करता है और shortcut नहीं किया जा सकता। इसके बाद, PoC2 shuffle प्रत्येक scoop के निचले और ऊपरी हिस्सों को swap करता है, किसी भी scoop को recover करने की computational cost को equalize करता है।

PoCX अपने hardened X1 प्रारूप को derive करके POC2 XOR–transpose compression हमले को और समाप्त करता है, जहाँ प्रत्येक scoop paired warps में एक direct और एक transposed position का XOR है; यह हर scoop को underlying X0 डेटा की एक पूरी row और एक पूरी column के साथ interlocks करता है, reconstruction के लिए हज़ारों पूर्ण nonces की आवश्यकता बनाता है और इस प्रकार asymmetric time–memory tradeoff को पूरी तरह से हटाता है।

परिणामस्वरूप, पूर्ण plot को संग्रहित करना miners के लिए एकमात्र computationally viable रणनीति है। कोई known shortcut—चाहे partial plotting, selective regeneration, structured compression, या hybrid compute-storage approaches—meaningful advantage प्रदान नहीं करता। PoCX सुनिश्चित करता है कि माइनिंग strictly storage-bound रहे और क्षमता real, physical commitment को reflect करे।

### 8.5 Assignment Attacks

PoCX सभी plot-to-forger assignments को govern करने के लिए एक deterministic state machine का उपयोग करता है। प्रत्येक assignment अच्छी तरह से परिभाषित states—UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED—से enforced activation और revocation विलंबों के साथ गुज़रता है। यह सुनिश्चित करता है कि miner system को cheat करने या तेज़ी से forging authority switch करने के लिए तुरंत assignments नहीं बदल सकता।

क्योंकि सभी transitions के लिए cryptographic proofs की आवश्यकता होती है—विशेष रूप से, plot स्वामी द्वारा signatures जो input UTXO के विरुद्ध verifiable हैं—नेटवर्क प्रत्येक assignment की legitimacy पर trust कर सकता है। State machine को bypass करने या assignments को forge करने के प्रयास consensus सत्यापन के दौरान automatically reject किए जाते हैं। Replay attacks को भी standard Bitcoin-style transaction replay protections द्वारा रोका जाता है, यह सुनिश्चित करते हुए कि हर assignment action एक valid, unspent input से uniquely tied है।

State-machine governance, enforced विलंब, और cryptographic proof का संयोजन assignment-based cheating को practically असंभव बनाता है: miners assignments को hijack नहीं कर सकते, block races के दौरान rapid reassignment नहीं कर सकते, या revocation schedules को circumvent नहीं कर सकते।

### 8.6 Signature Security

PoCX में Block signatures एक proof और effective forging key के बीच एक critical link के रूप में कार्य करते हैं, यह सुनिश्चित करते हुए कि केवल authorized miners valid blocks उत्पन्न कर सकते हैं।

Malleability attacks को रोकने के लिए, signatures को block hash computation से exclude किया जाता है। यह malleable signatures के जोखिमों को समाप्त करता है जो validation को undermine कर सकते हैं या block replacement attacks की अनुमति दे सकते हैं।

Denial-of-service vectors को mitigate करने के लिए, signature और public key sizes fixed हैं—compact signatures के लिए 65 bytes और compressed public keys के लिए 33 bytes—हमलावरों को resource exhaustion trigger करने या network propagation धीमा करने के लिए blocks को inflate करने से रोकता है।

---

## 9. कार्यान्वयन

PoCX को Bitcoin Core के modular extension के रूप में implement किया गया है, सभी relevant code इसकी अपनी dedicated subdirectory में contained है और feature flag के माध्यम से activated है। यह design मूल code की integrity को preserve करता है, PoCX को cleanly enable या disable करने की अनुमति देता है, जो testing, auditing, और upstream changes के साथ sync में रहने को सरल बनाता है।

Integration केवल Proof of Capacity का समर्थन करने के लिए आवश्यक essential points को छूता है। Block header को PoCX-specific fields शामिल करने के लिए extend किया गया है, और consensus validation को traditional Bitcoin checks के साथ storage-based proofs को process करने के लिए adapted किया गया है। Forging system, deadlines, scheduling, और miner submissions के प्रबंधन के लिए जिम्मेदार, पूरी तरह से PoCX modules के भीतर contained है, जबकि RPC extensions external clients को mining और assignment functionality expose करते हैं। Users के लिए, wallet interface को OP_RETURN transactions के माध्यम से assignments प्रबंधित करने के लिए enhanced किया गया है, नई consensus features के साथ seamless interaction सक्षम करता है।

सभी consensus-critical operations deterministic C++ में external dependencies के बिना implement किए गए हैं, cross-platform consistency सुनिश्चित करते हुए। Shabal256 का उपयोग hashing के लिए किया जाता है, जबकि Time Bending और quality calculation fixed-point arithmetic और 256-bit operations पर rely करते हैं। Cryptographic operations जैसे signature verification Bitcoin Core की existing secp256k1 library का leverage करते हैं।

इस तरह PoCX functionality को isolate करके, implementation auditable, maintainable, और ongoing Bitcoin Core development के साथ पूर्ण रूप से compatible रहता है, यह demonstrating करते हुए कि एक fundamentally नया storage-bound consensus mechanism एक mature proof-of-work codebase के साथ उसकी integrity या usability को disrupt किए बिना coexist कर सकता है।

---

## 10. नेटवर्क पैरामीटर

PoCX Bitcoin के network infrastructure पर build करता है और इसके chain parameter framework को reuse करता है। Capacity-based माइनिंग, block intervals, assignment handling, और plot scaling का समर्थन करने के लिए, कई parameters को extend या override किया गया है। इसमें block time target, initial subsidy, halving schedule, assignment activation और revocation विलंब, साथ ही network identifiers जैसे magic bytes, ports, और Bech32 prefixes शामिल हैं। Testnet और regtest environments rapid iteration और low-capacity testing सक्षम करने के लिए इन parameters को और adjust करते हैं।

नीचे दी गई tables resulting mainnet, testnet, और regtest settings को summarize करती हैं, highlighting करते हुए कि PoCX Bitcoin के core parameters को storage-bound consensus model में कैसे adapt करता है।

### 10.1 Mainnet

| पैरामीटर | मान |
|----------|-----|
| Magic bytes | `0xa7 0x3c 0x91 0x5e` |
| Default port | 8888 |
| Bech32 HRP | `pocx` |
| Block time target | 120 सेकंड |
| Initial subsidy | 10 BTC |
| Halving interval | 1050000 blocks (~4 वर्ष) |
| Total supply | ~21 मिलियन BTC |
| Assignment activation | 30 blocks |
| Assignment revocation | 720 blocks |
| Rolling window | 24 blocks |

### 10.2 Testnet

| पैरामीटर | मान |
|----------|-----|
| Magic bytes | `0x6d 0xf2 0x48 0xb3` |
| Default port | 18888 |
| Bech32 HRP | `tpocx` |
| Block time target | 120 सेकंड |
| अन्य पैरामीटर | Mainnet जैसे |

### 10.3 Regtest

| पैरामीटर | मान |
|----------|-----|
| Magic bytes | `0xfa 0xbf 0xb5 0xda` |
| Default port | 18444 |
| Bech32 HRP | `rpocx` |
| Block time target | 1 सेकंड |
| Halving interval | 500 blocks |
| Assignment activation | 4 blocks |
| Assignment revocation | 8 blocks |
| Low-capacity mode | Enabled (~4 MB plots) |

---

## 11. संबंधित कार्य

वर्षों में, कई blockchain और consensus परियोजनाओं ने storage-based या hybrid माइनिंग models का अन्वेषण किया है। PoCX सुरक्षा, दक्षता, और compatibility में enhancements प्रस्तुत करते हुए इस वंशावली पर build करता है।

**Burstcoin / Signum.** Burstcoin ने 2014 में पहला practical Proof-of-Capacity (PoC) सिस्टम प्रस्तुत किया, plots, nonces, scoops, और deadline-based माइनिंग जैसी core concepts को परिभाषित करते हुए। इसके successors, विशेष रूप से Signum (पूर्व में Burstcoin), ने ecosystem को extend किया और अंततः जिसे Proof-of-Commitment (PoC+) के रूप में जाना जाता है उसमें evolve हुए, storage commitment को effective capacity को प्रभावित करने के लिए optional staking के साथ combine करते हुए। PoCX इन परियोजनाओं से storage-based माइनिंग foundation को inherit करता है, लेकिन hardened plot format (XOR-transpose encoding), dynamic plot-work scaling, deadline smoothing ("Time Bending"), और flexible assignment system के माध्यम से significantly diverge करता है—यह सब standalone network fork बनाए रखने के बजाय Bitcoin Core codebase में anchor करते हुए।

**Chia.** Chia Proof of Space and Time implement करता है, disk-based storage proofs को Verifiable Delay Functions (VDFs) के माध्यम से enforced time component के साथ combine करता है। इसका design proof reuse और fresh challenge generation के बारे में certain concerns को address करता है, classic PoC से distinct। PoCX उस time-anchored proof model को adopt नहीं करता; इसके बजाय, यह UTXO economics और Bitcoin-derived tooling के साथ long-term compatibility के लिए optimized, predictable intervals के साथ storage-bound consensus बनाए रखता है।

**Spacemesh.** Spacemesh DAG-based (mesh) network topology का उपयोग करके Proof-of-Space-Time (PoST) scheme propose करता है। इस model में, participants को single precomputed dataset पर rely करने के बजाय periodically prove करना होगा कि allocated storage समय के साथ intact रहता है। PoCX, इसके विपरीत, storage commitment को केवल block time पर verify करता है—hardened plot formats और rigorous proof validation के साथ—efficiency और decentralization को preserve करते हुए continuous storage proofs के overhead से बचता है।

---

## 12. निष्कर्ष

Bitcoin-PoCX demonstrate करता है कि energy-efficient consensus को security properties और economic model को preserve करते हुए Bitcoin Core में integrate किया जा सकता है। प्रमुख योगदानों में XOR-transpose encoding (हमलावरों को प्रति lookup 4096 nonces compute करने के लिए force करता है, compression attack को eliminate करता है), Time Bending algorithm (distribution transformation block time variance को reduce करता है), forging assignment system (OP_RETURN-based delegation non-custodial pool माइनिंग enable करता है), dynamic scaling (security margins maintain करने के लिए halvings के साथ aligned), और minimal integration (dedicated directory में isolated feature-flagged code) शामिल हैं।

सिस्टम वर्तमान में testnet phase में है। माइनिंग power hash rate के बजाय storage capacity से derive होती है, Bitcoin के proven economic model को maintain करते हुए orders of magnitude से energy consumption को reduce करती है।

---

## संदर्भ

Bitcoin Core. *Bitcoin Core Repository.* https://github.com/bitcoin/bitcoin

Burstcoin. *Proof of Capacity Technical Documentation.* 2014.

NIST. *SHA-3 Competition: Shabal.* 2008.

Cohen, B., Pietrzak, K. *The Chia Network Blockchain.* 2019.

Spacemesh. *Spacemesh Protocol Documentation.* 2021.

PoC Consortium. *PoCX Framework.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Bitcoin-PoCX Integration.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**लाइसेंस**: MIT
**संगठन**: Proof of Capacity Consortium
**स्थिति**: Testnet Phase
