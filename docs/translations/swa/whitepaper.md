# Bitcoin-PoCX: Makubaliano ya Ufanisi wa Nishati kwa Bitcoin Core

**Toleo**: 2.0 Rasimu
**Tarehe**: Desemba 2025
**Shirika**: Proof of Capacity Consortium

---

## Muhtasari

Makubaliano ya Proof-of-Work (PoW) ya Bitcoin yanatoa usalama imara lakini yanatumia nishati kubwa kutokana na hesabu za hash zinazofanywa kwa wakati halisi. Tunawasilisha Bitcoin-PoCX, fork ya Bitcoin inayobadilisha PoW na Proof of Capacity (PoC), ambapo wachimbaji wanahesabu mapema na kuhifadhi seti kubwa za hash kwenye diski wakati wa uundaji wa plot na kisha kuchimba kwa kufanya utafutaji mwepesi badala ya kuhesabu kwa kuendelea. Kwa kuhamisha hesabu kutoka hatua ya uchimbaji hadi hatua ya uundaji wa plot inayofanywa mara moja, Bitcoin-PoCX inapunguza sana matumizi ya nishati huku ikiwezesha uchimbaji kwenye vifaa vya kawaida, kupunguza vikwazo vya kushiriki na kupunguza shinikizo la uwekaji mkuu uliopo katika PoW inayotawaliwa na ASIC, huku ikihifadhi mawazo ya usalama na tabia ya kiuchumi ya Bitcoin.

Utekelezaji wetu unaanzisha uvumbuzi kadhaa muhimu:
(1) Muundo wa plot ulioimarishwa unaondoa mashambulizi yote yanayojulikana ya ubadilishaji wa wakati-kumbukumbu katika mifumo iliyopo ya PoC, kuhakikisha kuwa nguvu ya uchimbaji inayofanya kazi inabaki kulingana sawia na uwezo wa kuhifadhi uliojitolea;
(2) Algoriti ya Time-Bending, inayobadilisha usambazaji wa tarehe za mwisho kutoka exponential hadi chi-squared, kupunguza tofauti ya muda wa block bila kubadilisha wastani;
(3) Utaratibu wa kugawia uundaji unaotegemea OP_RETURN unaowezesha uchimbaji wa pool bila uhifadhi wa fedha; na
(4) Ukadiriaji wa ukandamizaji unaobadilika, unaoongeza ugumu wa uundaji wa plot kulingana na ratiba za nusu ili kudumisha margin za usalama za muda mrefu kadri vifaa vinavyoboreshwa.

Bitcoin-PoCX inahifadhi usanifu wa Bitcoin Core kupitia marekebisho madogo yaliyowekwa alama za vipengele, ikitenga mantiki ya PoC kutoka kwa msimbo uliopo wa makubaliano. Mfumo unahifadhi sera ya fedha ya Bitcoin kwa kulenga muda wa block wa sekunde 120 na kurekebisha ruzuku ya block hadi BTC 10. Ruzuku iliyopunguzwa inalingana na ongezeko la mara tano la masafa ya block, ikihifadhi kiwango cha utoaji wa muda mrefu kulingana na ratiba asili ya Bitcoin na kudumisha ugavi wa juu zaidi wa ~milioni 21.

---

## 1. Utangulizi

### 1.1 Motisha

Makubaliano ya Proof-of-Work (PoW) ya Bitcoin yamethibitishwa kuwa salama kwa zaidi ya miongo, lakini kwa gharama kubwa: wachimbaji lazima watumie rasilimali za hesabu kwa kuendelea, na kusababisha matumizi makubwa ya nishati. Zaidi ya wasiwasi wa ufanisi, kuna motisha pana: kuchunguza taratibu mbadala za makubaliano zinazohifadhi usalama huku zikipunguza vikwazo vya kushiriki. PoC inaruhusu karibu mtu yeyote mwenye vifaa vya kuhifadhi vya kawaida kuchimba kwa ufanisi, kupunguza shinikizo la uwekaji mkuu linalopatikana katika uchimbaji wa PoW unaotawaliwa na ASIC.

Proof of Capacity (PoC) inafanikisha hili kwa kupata nguvu ya uchimbaji kutoka kwa ahadi ya kuhifadhi badala ya hesabu inayoendelea. Wachimbaji wanahesabu mapema seti kubwa za hash zilizohifadhiwa kwenye diski—plot—wakati wa hatua ya uundaji wa plot inayofanywa mara moja. Kuchimba kisha kunajumuisha utafutaji mwepesi, kupunguza sana matumizi ya nishati huku kukihifadhi mawazo ya usalama ya makubaliano yanayotegemea rasilimali.

### 1.2 Ujumuishaji na Bitcoin Core

Bitcoin-PoCX inajumuisha makubaliano ya PoC katika Bitcoin Core badala ya kuunda blockchain mpya. Njia hii inatumia usalama uliothibitishwa wa Bitcoin Core, stakili za mtandao zilizokomaa, na zana zinazotumika sana, huku marekebisho yakibaki madogo na yaliyowekwa alama za vipengele. Mantiki ya PoC imetenga kutoka kwa msimbo uliopo wa makubaliano, kuhakikisha kuwa kazi za msingi—uthibitishaji wa block, operesheni za wallet, muundo wa miamala—zinabaki bila kubadilika kwa kiasi kikubwa.

### 1.3 Malengo ya Muundo

**Usalama**: Kudumisha uimara sawa na Bitcoin; mashambulizi yanahitaji uwezo wa wingi wa kuhifadhi.

**Ufanisi**: Kupunguza mzigo wa hesabu unaoendelea hadi viwango vya I/O ya diski.

**Upatikanaji**: Kuwezesha uchimbaji kwa vifaa vya kawaida, kupunguza vikwazo vya kuingia.

**Ujumuishaji Mdogo**: Kuanzisha makubaliano ya PoC na alama ndogo za marekebisho.

---

## 2. Historia: Proof of Capacity

### 2.1 Historia

Proof of Capacity (PoC) ilianzishwa na Burstcoin mwaka 2014 kama mbadala wa Proof-of-Work (PoW) yenye ufanisi wa nishati. Burstcoin ilionyesha kuwa nguvu ya uchimbaji inaweza kupatikana kutoka kwa kuhifadhi kulikojitolea badala ya kuhesabu kwa wakati halisi kwa kuendelea: wachimbaji walihesabu mapema seti kubwa za data ("plot") mara moja na kisha kuchimba kwa kusoma sehemu ndogo, zilizowekwa za data hiyo.

Utekelezaji wa awali wa PoC ulithibitisha dhana kuwa inafanya kazi lakini pia ulifunua kuwa muundo wa plot na muundo wa kriptografia ni muhimu kwa usalama. Ubadilishaji kadhaa wa wakati-kumbukumbu uliruhusu washambuliaji kuchimba kwa ufanisi na kuhifadhi kidogo kuliko washiriki waaminifu. Hii ilisisitiza kuwa usalama wa PoC unategemea muundo wa plot—si tu kutumia kuhifadhi kama rasilimali.

Urithi wa Burstcoin ulianzisha PoC kama utaratibu wa makubaliano unaofanya kazi na kutoa msingi ambao PoCX inajengwa juu yake.

### 2.2 Dhana za Msingi

Uchimbaji wa PoC unategemea faili kubwa za plot zilizohesabiwa mapema na kuhifadhiwa kwenye diski. Plot hizi zina "hesabu zilizohifadhiwa": kuhesabu hash ghali kunafanywa mara moja wakati wa uundaji wa plot, na kuchimba kisha kunajumuisha kusoma diski mwepesi na uthibitishaji rahisi. Vipengele vya msingi vinajumuisha:

**Nonce:**
Kitengo cha msingi cha data ya plot. Kila nonce ina scoop 4096 (jumla ya KiB 256) zinazozalishwa kupitia Shabal256 kutoka anwani ya mchimbaji na fahirisi ya nonce.

**Scoop:**
Sehemu ya baiti 64 ndani ya nonce. Kwa kila block, mtandao unachagua fahirisi ya scoop (0–4095) kwa njia ya kubainisha kulingana na saini ya uzalishaji ya block iliyotangulia. Scoop hii pekee kwa kila nonce lazima isomwe.

**Generation Signature:**
Thamani ya biti 256 inayotokana na block iliyotangulia. Inatoa entropy kwa uchaguzi wa scoop na kuzuia wachimbaji kutabiri fahirisi za scoop za baadaye.

**Warp:**
Kikundi cha muundo wa nonce 4096 (GiB 1). Warp ni kitengo husika kwa muundo wa plot unaostahimili ukandamizaji.

### 2.3 Mchakato wa Uchimbaji na Mkondo wa Ubora

Uchimbaji wa PoC unajumuisha hatua ya uundaji wa plot inayofanywa mara moja na utaratibu mwepesi kwa kila block:

**Usanidi wa Mara Moja:**
- Uundaji wa plot: Hesabu nonce kupitia Shabal256 na uziandike kwenye diski.

**Uchimbaji kwa Kila Block:**
- Uchaguzi wa scoop: Bainisha fahirisi ya scoop kutoka kwa saini ya uzalishaji.
- Uchunguzi wa plot: Soma scoop hiyo kutoka kwa nonce zote katika plot za mchimbaji.

**Mkondo wa Ubora:**
- Ubora mbichi: Hesabu hash ya kila scoop na saini ya uzalishaji kwa kutumia Shabal256Lite kupata thamani ya ubora ya biti 64 (ndogo ni bora).
- Tarehe ya mwisho: Badilisha ubora kuwa tarehe ya mwisho kwa kutumia lengo la msingi (kipengele kilichorekebishwa kwa ugumu kinachohakikisha mtandao unafikia muda wa block unaolengwa): `deadline = quality / base_target`
- Tarehe ya mwisho iliyobadilishwa: Tumia mabadiliko ya Time-Bending kupunguza tofauti huku ukihifadhi muda wa block unaotarajiwa.

**Uundaji wa Block:**
Mchimbaji mwenye tarehe ya mwisho (iliyobadilishwa) fupi zaidi anaunda block inayofuata mara tu muda huo umepita.

Tofauti na PoW, karibu hesabu zote zinafanyika wakati wa uundaji wa plot; uchimbaji unaoendelea kimsingi unategemea diski na unahitaji nishati ndogo sana.

### 2.4 Udhaifu Unaojulikana katika Mifumo ya Awali

**Kasoro ya Usambazaji wa POC1:**
Muundo wa asili wa Burstcoin POC1 ulionyesha upendeleo wa muundo: scoop za fahirisi ndogo zilikuwa nafuu sana kuhesabu upya wakati wa hitaji kuliko scoop za fahirisi kubwa. Hii ilianzisha ubadilishaji usio sawa wa wakati-kumbukumbu, kuruhusu washambuliaji kupunguza kuhifadhi kunakohitajika kwa scoop hizo na kuvunja wazo kwamba data zote zilizohesabiwa mapema zilikuwa ghali sawa.

**Shambulio la Ukandamizaji wa XOR (POC2):**
Katika POC2, mshambuliaji anaweza kuchukua seti yoyote ya nonce 8192 na kuzigawanya katika vitalu viwili vya nonce 4096 (A na B). Badala ya kuhifadhi vitalu vyote viwili, mshambuliaji anahifadhi muundo uliotokana pekee: `A ⊕ transpose(B)`, ambapo transpose inabadilisha fahirisi za scoop na nonce—scoop S ya nonce N katika kitalu B inakuwa scoop N ya nonce S.

Wakati wa uchimbaji, wakati scoop S ya nonce N inahitajika, mshambuliaji anairejesha kwa:
1. Kusoma thamani ya XOR iliyohifadhiwa katika nafasi (S, N)
2. Kuhesabu nonce N kutoka kitalu A kupata scoop S
3. Kuhesabu nonce S kutoka kitalu B kupata scoop ya transposed N
4. Ku-XOR thamani zote tatu kurejesha scoop ya awali ya baiti 64

Hii inapunguza kuhifadhi kwa 50%, huku ikihitaji hesabu mbili za nonce pekee kwa kila utafutaji—gharama chini sana ya kizingiti kinachohitajika kutekeleza kuhesabu mapema kikamilifu. Shambulio linafanya kazi kwa sababu kuhesabu safu (nonce moja, scoop 4096) ni nafuu, wakati kuhesabu safu wima (scoop moja kwa nonce 4096) kungehitaji kuzalisha upya nonce zote. Muundo wa transpose unafichua usawa huu.

Hii ilionyesha hitaji la muundo wa plot unaozuia ujumuishaji kama huo wa muundo na kuondoa ubadilishaji wa msingi wa wakati-kumbukumbu. Sehemu ya 3.3 inaelezea jinsi PoCX inavyoshughulikia na kutatua udhaifu huu.

### 2.5 Mpito kwa PoCX

Mapungufu ya mifumo ya awali ya PoC yalifanya wazi kuwa uchimbaji wa kuhifadhi salama, wa haki, na usio na uwekaji mkuu unategemea miundo ya plot iliyoundwa kwa uangalifu. Bitcoin-PoCX inashughulikia masuala haya kwa muundo wa plot ulioimarishwa, usambazaji bora wa tarehe za mwisho, na taratibu za uchimbaji wa pool usio na uwekaji mkuu—zimeelezewa katika sehemu inayofuata.

---

## 3. Muundo wa Plot wa PoCX

### 3.1 Ujenzi wa Nonce ya Msingi

Nonce ni muundo wa data wa KiB 256 unaotokana kwa njia ya kubainisha kutoka vigezo vitatu: mzigo wa anwani wa baiti 20, mbegu ya baiti 32, na fahirisi ya nonce ya biti 64.

Ujenzi unaanza kwa kuchanganya pembejeo hizi na kuzihesabu na Shabal256 kupata hash ya awali. Hash hii inatumika kama hatua ya kuanzia kwa mchakato wa upanuzi wa kurudia: Shabal256 inatumika mara kwa mara, na kila hatua ikitegemea data iliyozalishwa awali, hadi bafa yote ya KiB 256 ijae. Mchakato huu wa mnyororo unawakilisha kazi ya hesabu inayofanywa wakati wa uundaji wa plot.

Hatua ya mwisho ya usambazaji inahesabu hash ya bafa iliyokamilishwa na ku-XOR matokeo kwa baiti zote. Hii inahakikisha kuwa bafa yote imehesabiwa na kwamba wachimbaji hawawezi kufupisha hesabu. Kushusha kwa PoC2 kisha kunatumika, kubadilisha nusu za chini na juu za kila scoop kuhakikisha kuwa scoop zote zinahitaji juhudi sawa za hesabu.

Nonce ya mwisho inajumuisha scoop 4096 za baiti 64 kila moja na inafanya kitengo cha msingi kinachotumika katika uchimbaji.

### 3.2 Mpangilio wa Plot Uliowekwa kwa SIMD

Ili kuongeza upitishaji kwenye vifaa vya kisasa, PoCX inapanga data ya nonce kwenye diski ili kuwezesha usindikaji wa vector. Badala ya kuhifadhi kila nonce kwa mfuatano, PoCX inaweka maneno ya baiti 4 yanayolingana kwa nonce nyingi zinazofuatana kwa karibu. Hii inaruhusu kusoma kumbukumbu moja kutoa data kwa lane zote za SIMD, kupunguza kukosa cache na kuondoa gharama ya scatter-gather.

```
Mpangilio wa jadi:
Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

Mpangilio wa PoCX SIMD:
Word0: [N0][N1][N2]...[N15]
Word1: [N0][N1][N2]...[N15]
Word2: [N0][N1][N2]...[N15]
```

Mpangilio huu unanufaisha wachimbaji wa CPU na GPU, kuwezesha tathmini ya scoop ya upitishaji wa juu, iliyosambazwa huku ukihifadhi muundo rahisi wa upatikanaji wa scalar kwa uthibitishaji wa makubaliano. Inahakikisha kuwa uchimbaji unakuwa mdogo kwa kipimo data cha kuhifadhi badala ya hesabu za CPU, kudumisha tabia ya nishati ndogo ya Proof of Capacity.

### 3.3 Muundo wa Warp na Usimbaji wa XOR-Transpose

Warp ni kitengo cha msingi cha kuhifadhi katika PoCX, kinachojumuisha nonce 4096 (GiB 1). Muundo usiobanwa, unaojulikana kama X0, una nonce za msingi kama zinavyozalishwa na ujenzi katika Sehemu ya 3.1.

**Usimbaji wa XOR-Transpose (X1)**

Ili kuondoa ubadilishaji wa muundo wa wakati-kumbukumbu uliopo katika mifumo ya awali ya PoC, PoCX inapata muundo wa uchimbaji ulioimarishwa, X1, kwa kutumia usimbaji wa XOR-transpose kwa jozi za warp za X0.

Ili kujenga scoop S ya nonce N katika warp ya X1:

1. Chukua scoop S ya nonce N kutoka warp ya kwanza ya X0 (nafasi ya moja kwa moja)
2. Chukua scoop N ya nonce S kutoka warp ya pili ya X0 (nafasi ya transposed)
3. XOR thamani mbili za baiti 64 kupata scoop ya X1

Hatua ya transpose inabadilisha fahirisi za scoop na nonce. Kwa maneno ya matrix—ambapo safu zinawakilisha scoop na safu wima zinawakilisha nonce—inachanganya kipengele katika nafasi (S, N) katika warp ya kwanza na kipengele katika (N, S) katika ya pili.

**Kwa Nini Hii Inaondoa Uso wa Shambulio la Ukandamizaji**

XOR-transpose inaunganisha kila scoop na safu nzima na safu wima nzima ya data ya msingi ya X0. Kurejesha scoop moja ya X1 kwa hivyo kunahitaji upatikanaji wa data inayoenea fahirisi zote 4096 za scoop. Jaribio lolote la kuhesabu data inayokosekana lingehitaji kuzalisha upya nonce 4096 kamili, badala ya nonce moja—kuondoa muundo wa gharama usio sawa unaotumika na shambulio la XOR kwa POC2 (Sehemu ya 2.4).

Kwa sababu hiyo, kuhifadhi warp kamili ya X1 inakuwa mkakati pekee unaowezekana kwa hesabu kwa wachimbaji, kufunga ubadilishaji wa wakati-kumbukumbu unaotumika katika miundo ya awali.

### 3.4 Mpangilio wa Diski

Faili za plot za PoCX zinajumuisha warp nyingi za X1 zinazofuatana. Ili kuongeza ufanisi wa uendeshaji wakati wa uchimbaji, data ndani ya kila faili imepangwa kwa scoop: data yote ya scoop 0 kutoka kila warp imehifadhiwa kwa mfuatano, ikifuatiwa na data yote ya scoop 1, na kadhalika, hadi scoop 4095.

**Mpangilio wa mfuatano wa scoop** huu unaruhusu wachimbaji kusoma data kamili inayohitajika kwa scoop iliyochaguliwa katika upatikanaji mmoja wa diski wa mfuatano, kupunguza muda wa kutafuta na kuongeza upitishaji kwenye vifaa vya kuhifadhi vya kawaida.

Pamoja na usimbaji wa XOR-transpose wa Sehemu ya 3.3, mpangilio huu unahakikisha kuwa faili ni **imeimarishwa kimuundo** na **ina ufanisi wa uendeshaji**: mpangilio wa mfuatano wa scoop unasaidia I/O bora ya diski, wakati mpangilio wa kumbukumbu uliowekwa kwa SIMD (angalia Sehemu ya 3.2) unaruhusu tathmini ya scoop ya upitishaji wa juu, iliyosambazwa.

### 3.5 Ukadiriaji wa Proof-of-Work (Xn)

PoCX inatekeleza kuhesabu mapema kunakokadiriwa kupitia dhana ya viwango vya ukadiriaji, vinavyoonyeshwa Xn, kuzoea utendaji wa vifaa unavyobadilika. Muundo wa msingi wa X1 unawakilisha muundo wa kwanza wa warp ulioimarishwa wa XOR-transpose.

Kila kiwango cha ukadiriaji Xn kinaongeza proof-of-work iliyoingizwa katika kila warp kwa kielelezo ikilinganishwa na X1: kazi inayohitajika katika kiwango Xn ni mara 2^(n-1) ya X1. Kuhamia kutoka Xn hadi Xn+1 kwa uendeshaji ni sawa na kutumia XOR kwa jozi za warp zinazopakana, kuingiza hatua kwa hatua proof-of-work zaidi bila kubadilisha ukubwa wa msingi wa plot.

Faili za plot zilizopo zilizoundwa katika viwango vya chini vya ukadiriaji bado zinaweza kutumika kwa uchimbaji, lakini zinachangia kazi ndogo kwa uwiano kuelekea uzalishaji wa block, kuonyesha proof-of-work yao ndogo iliyoingizwa. Utaratibu huu unahakikisha kuwa plot za PoCX zinabaki salama, zenye kubadilika, na zenye usawa wa kiuchumi kwa muda.

### 3.6 Kazi ya Mbegu

Kigezo cha mbegu kinawezesha plot nyingi zisizoingiliana kwa kila anwani bila uratibu wa mikono.

**Tatizo (POC2)**: Wachimbaji walilazimika kufuatilia mipaka ya nonce kwa mikono kwa faili za plot ili kuepuka kuingiliana. Nonce zinazoingiliana zinapoteza kuhifadhi bila kuongeza nguvu ya uchimbaji.

**Suluhisho**: Kila jozi ya `(address, seed)` inafafanua nafasi ya funguo huru. Plot zenye mbegu tofauti haziwezi kuingiliana kamwe, bila kujali mipaka ya nonce. Wachimbaji wanaweza kuunda plot kwa uhuru bila uratibu.

---

## 4. Makubaliano ya Proof of Capacity

PoCX inapanua makubaliano ya Nakamoto ya Bitcoin na utaratibu wa uthibitisho unaotegemea kuhifadhi. Badala ya kutumia nishati kwa kuhesabu hash kwa kurudia, wachimbaji wanajitolea data nyingi zilizohesabiwa mapema—plot—kwenye diski. Wakati wa uzalishaji wa block, lazima wapate sehemu ndogo, isiyotabirika ya data hii na kuibadilisha kuwa uthibitisho. Mchimbaji anayetoa uthibitisho bora ndani ya dirisha la muda linalotarajiwa anapata haki ya kuunda block inayofuata.

Sura hii inaelezea jinsi PoCX inavyopanga metadata ya block, kupata kutotabirika, na kubadilisha kuhifadhi tuli kuwa utaratibu wa makubaliano salama, wenye tofauti ndogo.

### 4.1 Muundo wa Block

PoCX inahifadhi kichwa cha block cha mtindo wa Bitcoin lakini inaanzisha sehemu za ziada za makubaliano zinazohitajika kwa uchimbaji unaotegemea uwezo. Sehemu hizi kwa pamoja zinaunganisha block na plot iliyohifadhiwa ya mchimbaji, ugumu wa mtandao, na entropy ya kriptografia inayofafanua kila changamoto ya uchimbaji.

Kwa ujumla, block ya PoCX ina: urefu wa block, uliorekodiwa wazi ili kurahisisha uthibitishaji wa muktadha; saini ya uzalishaji, chanzo cha entropy mpya kinachounganisha kila block na iliyoitangulia; lengo la msingi, linalowakilisha ugumu wa mtandao kwa muundo wa kinyume (thamani za juu zinalingana na uchimbaji rahisi); uthibitisho wa PoCX, unaobainisha plot ya mchimbaji, kiwango cha ukandamizaji kilichotumika wakati wa uundaji wa plot, nonce iliyochaguliwa, na ubora unaotokana nayo; na funguo ya kusaini na saini, inayothibitisha udhibiti wa uwezo uliotumika kuunda block (au funguo ya uundaji iliyogawiwa).

Uthibitisho unaingiza taarifa zote muhimu za makubaliano zinazohitajika na wathibitishaji kuhesabu upya changamoto, kuthibitisha scoop iliyochaguliwa, na kuthibitisha ubora unaotokana. Kwa kupanua badala ya kubuni upya muundo wa block, PoCX inabaki kulingana kidhana na Bitcoin huku ikiwezesha chanzo tofauti kabisa cha kazi ya uchimbaji.

### 4.2 Mnyororo wa Generation Signature

Saini ya uzalishaji inatoa kutotabirika kunakohitajika kwa uchimbaji salama wa Proof of Capacity. Kila block inapata saini yake ya uzalishaji kutoka kwa saini na msainiaji wa block iliyotangulia, kuhakikisha kuwa wachimbaji hawawezi kutabiri changamoto za baadaye au kuhesabu mapema maeneo ya plot yenye faida:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

Hii inazalisha mfuatano wa thamani za entropy zenye nguvu za kriptografia, zinazotegemea mchimbaji. Kwa sababu funguo ya umma ya mchimbaji haijulikani hadi block iliyotangulia ichapishwe, hakuna mshiriki anayeweza kutabiri uchaguzi wa scoop za baadaye. Hii inazuia kuhesabu mapema kwa kuchagua au kupanga plot kwa kimkakati na inahakikisha kuwa kila block inaanzisha kazi ya uchimbaji mpya kweli.

### 4.3 Mchakato wa Uundaji

Uchimbaji katika PoCX unajumuisha kubadilisha data iliyohifadhiwa kuwa uthibitisho unaodhibitiwa kabisa na saini ya uzalishaji. Ingawa mchakato unabainishwa, kutotabirika kwa saini kunahakikisha kuwa wachimbaji hawawezi kujiandaa mapema na lazima wapate tena na tena plot zao zilizohifadhiwa.

**Upatikanaji wa Changamoto (Uchaguzi wa Scoop):** Mchimbaji anahesabu hash ya saini ya sasa ya uzalishaji na urefu wa block kupata fahirisi ya scoop katika mipaka ya 0–4095. Fahirisi hii inabainisha ni sehemu ipi ya baiti 64 ya kila nonce iliyohifadhiwa inayoshiriki katika uthibitisho. Kwa sababu saini ya uzalishaji inategemea msainiaji wa block iliyotangulia, uchaguzi wa scoop unajulikana tu wakati wa kuchapishwa kwa block.

**Tathmini ya Uthibitisho (Hesabu ya Ubora):** Kwa kila nonce katika plot, mchimbaji anapata scoop iliyochaguliwa na kuihesabu pamoja na saini ya uzalishaji kupata ubora—thamani ya biti 64 ambayo ukubwa wake unabainisha ushindani wa mchimbaji. Ubora mdogo unalingana na uthibitisho bora.

**Uundaji wa Tarehe ya Mwisho (Time Bending):** Tarehe ya mwisho mbichi inalingana na ubora na kulingana kinyume na lengo la msingi. Katika miundo ya zamani ya PoC, tarehe hizi za mwisho zilifuata usambazaji wa exponential uliopindika sana, ukizalisha ucheleweshaji mrefu wa mkia ambao haukutoa usalama wa ziada. PoCX inabadilisha tarehe ya mwisho mbichi kwa kutumia Time Bending (Sehemu ya 4.4), kupunguza tofauti na kuhakikisha muda wa block unaotabirika. Mara tu tarehe ya mwisho iliyobadilishwa inapopita, mchimbaji anaunda block kwa kuingiza uthibitisho na kuisaini na funguo ya uundaji inayofanya kazi.

### 4.4 Time Bending

Proof of Capacity inazalisha tarehe za mwisho zilizosambazwa kwa exponential. Baada ya kipindi kifupi—kawaida sekunde chache za kumi—kila mchimbaji tayari amebainisha uthibitisho wao bora, na muda wowote wa ziada wa kusubiri unachangia tu latency, si usalama.

Time Bending inaumba upya usambazaji kwa kutumia mabadiliko ya mzizi wa mchemraba:

`deadline_bended = scale × (quality / base_target)^(1/3)`

Kipengele cha ukadiriaji kinahifadhi muda wa block unaotarajiwa (sekunde 120) huku kikipunguza sana tofauti. Tarehe fupi za mwisho zinapanuliwa, kuboresha usambazaji wa block na usalama wa mtandao. Tarehe ndefu za mwisho zinakandamizwa, kuzuia vipengele vya nje kuchelewisha mnyororo.

![Usambazaji wa Muda wa Block](blocktime_distributions.svg)

Time Bending inahifadhi maudhui ya taarifa ya uthibitisho wa msingi. Haibadilishi ushindani kati ya wachimbaji; inagawanya upya tu muda wa kusubiri kuzalisha muda wa block laini, unaotabirika zaidi. Utekelezaji unatumia aritmetiki ya nukta-imara (muundo wa Q42) na nambari kamili za biti 256 kuhakikisha matokeo ya kubainisha kwenye majukwaa yote.

### 4.5 Urekebishaji wa Ugumu

PoCX inadhibiti uzalishaji wa block kwa kutumia lengo la msingi, kipimo cha ugumu cha kinyume. Muda wa block unaotarajiwa unalingana na uwiano `quality / base_target`, kwa hivyo kuongeza lengo la msingi kunaharakisha uundaji wa block wakati kupunguza kunasimamisha mnyororo.

Ugumu unarekebisha kila block kwa kutumia muda uliohesabiwa kati ya block za karibuni ikilinganishwa na muda wa lengo. Urekebishaji huu wa mara kwa mara ni muhimu kwa sababu uwezo wa kuhifadhi unaweza kuongezwa au kuondolewa haraka—tofauti na nguvu ya hash ya Bitcoin, inayobadilika polepole zaidi.

Urekebishaji unafuata vikwazo viwili vya kuongoza: **Taratibu**—mabadiliko kwa kila block yamepunguzwa (±20% upeo) ili kuepuka oscillation au udanganyifu; **Uimarishaji**—lengo la msingi haliwezi kuzidi thamani yake ya genesis, kuzuia mtandao kupunguza kamwe ugumu chini ya mawazo ya awali ya usalama.

### 4.6 Uhalali wa Block

Block katika PoCX ni halali inapotoa uthibitisho unaotokana na kuhifadhi unaothibitishika kulingana na hali ya makubaliano. Wathibitishaji wanahesabu upya kwa uhuru uchaguzi wa scoop, wanapata ubora unaotarajiwa kutoka kwa nonce iliyowasilishwa na metadata ya plot, wanatumia mabadiliko ya Time Bending, na wanathibitisha kuwa mchimbaji alikuwa na haki ya kuunda block wakati uliotangazwa.

Kwa usahihi, block halali inahitaji: tarehe ya mwisho imepita tangu block ya mzazi; ubora uliowasilishwa unalingana na ubora uliohesabiwa kwa uthibitisho; kiwango cha ukadiriaji kinakidhi kiwango cha chini cha mtandao; saini ya uzalishaji inalingana na thamani inayotarajiwa; lengo la msingi linalingana na thamani inayotarajiwa; saini ya block inatoka kwa msainiaji anayefanya kazi; na coinbase inalipa kwa anwani ya msainiaji anayefanya kazi.

---

## 5. Ugawaji wa Uundaji

### 5.1 Motisha

Ugawaji wa uundaji unaruhusu wamiliki wa plot kuwakalisha mamlaka ya kuunda block bila kuachia kamwe umiliki wa plot zao. Utaratibu huu unawezesha uchimbaji wa pool na usanidi wa kuhifadhi baridi huku ukihifadhi dhamana za usalama za PoCX.

Katika uchimbaji wa pool, wamiliki wa plot wanaweza kuidhinisha pool kuunda block kwa niaba yao. Pool inapanga block na kusambaza zawadi, lakini kamwe haipati uhifadhi wa plot zenyewe. Uwakilishaji unaweza kubatilishwa wakati wowote, na wamiliki wa plot wanabaki huru kuondoka kwenye pool au kubadilisha usanidi bila kuunda upya plot.

Ugawaji pia unasaidia utengano safi kati ya funguo baridi na moto. Funguo ya kibinafsi inayodhibiti plot inaweza kubaki nje ya mtandao, wakati funguo tofauti ya uundaji—iliyohifadhiwa kwenye mashine ya mtandaoni—inazalisha block. Kuvunjwa kwa funguo ya uundaji kwa hivyo kunavunja tu mamlaka ya uundaji, si umiliki. Plot inabaki salama na ugawaji unaweza kubatilishwa, kufunga pengo la usalama mara moja.

Ugawaji wa uundaji kwa hivyo unatoa kubadilika kwa uendeshaji huku ukihifadhi kanuni kwamba udhibiti wa uwezo wa kuhifadhi hauwezi kamwe kuhamishwa kwa waamuzi.

### 5.2 Itifaki ya Ugawaji

Ugawaji unatangazwa kupitia miamala ya OP_RETURN kuepuka ukuaji usio wa lazima wa seti ya UTXO. Miamala ya ugawaji inabainisha anwani ya plot na anwani ya uundaji iliyoidhinishwa kuzalisha block kwa kutumia uwezo wa plot hiyo. Miamala ya kubatilisha ina anwani ya plot pekee. Katika visa vyote viwili, mmiliki wa plot anathibitisha udhibiti kwa kusaini pembejeo ya kutumia ya miamala.

Kila ugawaji unaendelea kupitia mfuatano wa hali zilizofafanuliwa vizuri (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Baada ya miamala ya ugawaji kuthibitishwa, mfumo unaingia katika awamu fupi ya uanzishaji. Ucheleweshaji huu—block 30, takriban saa moja—unahakikisha utulivu wakati wa mashindano ya block na kuzuia kubadilisha haraka kwa utambulisho wa uundaji kwa adui. Mara tu kipindi hiki cha uanzishaji kinapomalizika, ugawaji unakuwa hai na unabaki hivyo hadi mmiliki wa plot anapotoa ubatilishaji.

Ubatilishaji unahamia katika kipindi kirefu cha ucheleweshaji wa block 720, takriban siku moja. Wakati huu, anwani ya awali ya uundaji inabaki hai. Ucheleweshaji huu mrefu zaidi unatoa utulivu wa uendeshaji kwa pool, kuzuia "kuruka ugawaji" wa kimkakati na kuwapa watoa huduma za miundombinu uhakika wa kutosha kufanya kazi kwa ufanisi. Baada ya ucheleweshaji wa ubatilishaji kumalizika, ubatilishaji unakamilika, na mmiliki wa plot yuko huru kuteua funguo mpya ya uundaji.

Hali ya ugawaji inahifadhiwa katika muundo wa tabaka la makubaliano sambamba na seti ya UTXO na inasaidia data ya kutengua kwa kushughulikia salama upangaji upya wa mnyororo.

### 5.3 Sheria za Uthibitishaji

Kwa kila block, wathibitishaji wanabainisha msainiaji anayefanya kazi—anwani ambayo lazima isaini block na kupokea zawadi ya coinbase. Msainiaji huyu anategemea pekee hali ya ugawaji katika urefu wa block.

Ikiwa hakuna ugawaji au ugawaji haujamalizisha bado awamu yake ya uanzishaji, mmiliki wa plot anabaki msainiaji anayefanya kazi. Mara tu ugawaji unapokuwa hai, anwani ya uundaji iliyogawiwa lazima isaini. Wakati wa ubatilishaji, anwani ya uundaji inaendelea kusaini hadi ucheleweshaji wa ubatilishaji umalizike. Tu ndipo mamlaka yanarudishwa kwa mmiliki wa plot.

Wathibitishaji wanatekeleza kuwa saini ya block inazalishwa na msainiaji anayefanya kazi, kuwa coinbase inalipa kwa anwani hiyo hiyo, na kuwa mabadiliko yote yanafuata ucheleweshaji wa uanzishaji na ubatilishaji uliowekwa. Mmiliki wa plot pekee anaweza kuunda au kubatilisha ugawaji; funguo za uundaji haziwezi kurekebisha au kupanua ruhusa zao wenyewe.

Ugawaji wa uundaji kwa hivyo unaanzisha uwakilishaji unaobadilika bila kuanzisha uaminifu. Umiliki wa uwezo wa msingi daima unabaki kuunganishwa kwa kriptografia na mmiliki wa plot, wakati mamlaka ya uundaji yanaweza kuwakilishwa, kubadilishwa, au kubatilishwa kadri mahitaji ya uendeshaji yanavyobadilika.

---

## 6. Ukadiriaji Unaobadilika

Kadri vifaa vinavyobadilika, gharama ya kuhesabu plot inapungua ikilinganishwa na kusoma kazi iliyohesabiwa mapema kutoka kwa diski. Bila hatua za kukabiliana, washambuliaji hatimaye wangeweza kuzalisha uthibitisho wakati wa hitaji haraka kuliko wachimbaji wanaosoma kazi iliyohifadhiwa, kudhoofisha mfano wa usalama wa Proof of Capacity.

Ili kuhifadhi margin ya usalama iliyokusudiwa, PoCX inatekeleza ratiba ya ukadiriaji: kiwango cha chini cha ukadiriaji kinachohitajika kwa plot kinaongezeka kwa muda. Kila kiwango cha ukadiriaji Xn, kama ilivyoelezewa katika Sehemu ya 3.5, kinaingiza proof-of-work zaidi kwa kielelezo ndani ya muundo wa plot, kuhakikisha kuwa wachimbaji wanaendelea kujitolea rasilimali kubwa za kuhifadhi hata kadri hesabu inavyokuwa nafuu.

Ratiba inalingana na motisha za kiuchumi za mtandao, hasa nusu za zawadi za block. Kadri zawadi kwa block inavyopungua, kiwango cha chini kinaongezeka polepole, kuhifadhi usawa kati ya juhudi za uundaji wa plot na uwezekano wa uchimbaji:

| Kipindi | Miaka | Nusu | Ukadiriaji wa Chini | Kizidishio cha Kazi ya Plot |
|---------|-------|------|---------------------|----------------------------|
| Epoch 0 | 0-4 | 0 | X1 | 2× msingi |
| Epoch 1 | 4-12 | 1-2 | X2 | 4× msingi |
| Epoch 2 | 12-28 | 3-6 | X3 | 8× msingi |
| Epoch 3 | 28-60 | 7-14 | X4 | 16× msingi |
| Epoch 4 | 60-124 | 15-30 | X5 | 32× msingi |
| Epoch 5 | 124+ | 31+ | X6 | 64× msingi |

Wachimbaji wanaweza kwa hiari kuandaa plot zinazozidi kiwango cha sasa cha chini kwa kiwango kimoja, kuwaruhusu kupanga mapema na kuepuka maboresho ya mara moja wakati mtandao unapohamia epoch inayofuata. Hatua hii ya hiari haitoi faida ya ziada kulingana na uwezekano wa block—inaruhusu tu mpito laini wa uendeshaji.

Block zenye uthibitisho chini ya kiwango cha chini cha ukadiriaji kwa urefu wao zinachukuliwa kuwa batili. Wathibitishaji wanaangalia kiwango cha ukadiriaji kilichotangazwa katika uthibitisho dhidi ya mahitaji ya sasa ya mtandao wakati wa uthibitishaji wa makubaliano, kuhakikisha kuwa wachimbaji wote wanaoshiriki wanakidhi matarajio ya usalama yanayobadilika.

---

## 7. Usanifu wa Uchimbaji

PoCX inatenganisha operesheni muhimu za makubaliano kutoka kwa kazi zenye rasilimali nyingi za uchimbaji, kuwezesha usalama na ufanisi. Node inahifadhi blockchain, inathibitisha block, inasimamia mempool, na inafunua kiolesura cha RPC. Wachimbaji wa nje wanashughulikia kuhifadhi plot, kusoma scoop, kuhesabu ubora, na kusimamia tarehe za mwisho. Utengano huu unahifadhi mantiki ya makubaliano kuwa rahisi na inayokaguliwa huku ukuruhusu wachimbaji kuboresha kwa upitishaji wa diski.

### 7.1 Kiolesura cha RPC cha Uchimbaji

Wachimbaji wanaingiliana na node kupitia seti ndogo ya wito wa RPC. RPC ya get_mining_info inatoa urefu wa sasa wa block, saini ya uzalishaji, lengo la msingi, tarehe ya mwisho ya lengo, na mipaka inayokubalika ya viwango vya ukadiriaji wa plot. Kwa kutumia taarifa hii, wachimbaji wanahesabu nonce wagombea. RPC ya submit_nonce inaruhusu wachimbaji kuwasilisha suluhisho lililopendekezwa, ikiwa ni pamoja na kitambulisho cha plot, fahirisi ya nonce, kiwango cha ukadiriaji, na akaunti ya mchimbaji. Node inatathmini uwasilishaji na kujibu na tarehe ya mwisho iliyohesabiwa ikiwa uthibitisho ni halali.

### 7.2 Kipanga Ratiba cha Uundaji

Node inahifadhi kipanga ratiba cha uundaji, kinachofuatilia uwasilishaji unaoingia na kuhifadhi suluhisho bora pekee kwa kila urefu wa block. Nonce zilizowasilishwa zinapangwa kwa ulinzi uliojengwa ndani dhidi ya mafuriko ya uwasilishaji au mashambulizi ya kukataa huduma. Kipanga ratiba kinasubiri hadi tarehe ya mwisho iliyohesabiwa ipite au suluhisho bora zaidi lifike, wakati huo kinapanga block, kuisaini kwa kutumia funguo ya uundaji inayofanya kazi, na kuichapisha kwenye mtandao.

### 7.3 Uundaji wa Kujilinda

Ili kuzuia mashambulizi ya wakati au motisha za kudanganya saa, PoCX inatekeleza uundaji wa kujilinda. Ikiwa block inayoshindana inafika kwa urefu huo huo, kipanga ratiba kinalinganisha suluhisho la ndani na block mpya. Ikiwa ubora wa ndani ni bora, node inaunda mara moja badala ya kusubiri tarehe ya mwisho ya asili. Hii inahakikisha kuwa wachimbaji hawawezi kupata faida tu kwa kurekebisha saa za ndani; suluhisho bora daima linashinda, kuhifadhi haki na usalama wa mtandao.

---

## 8. Uchambuzi wa Usalama

### 8.1 Mfano wa Vitisho

PoCX inaunda mfano wa adui wenye uwezo mkubwa lakini wenye mipaka. Washambuliaji wanaweza kujaribu kusumbua mtandao na miamala batili, block zenye muundo mbaya, au uthibitisho ulioundwa kujaribu njia za uthibitishaji. Wanaweza kudanganya saa zao za ndani kwa uhuru na wanaweza kujaribu kutumia visa vya makali katika tabia ya makubaliano kama vile kushughulikia timestamp, mienendo ya urekebishaji wa ugumu, au sheria za upangaji upya. Adui pia wanatarajiwa kuchunguza fursa za kuandika upya historia kupitia fork za mnyororo zinazolengwa.

Mfano unachukulia kuwa hakuna chama kimoja kinachoudhibiti wingi wa uwezo wa jumla wa kuhifadhi wa mtandao. Kama ilivyo na utaratibu wowote wa makubaliano unaotegemea rasilimali, mshambuliaji wa uwezo wa 51% anaweza kupanga upya mnyororo peke yake; mapungufu haya ya msingi si mahususi kwa PoCX. PoCX pia inachukulia kuwa washambuliaji hawawezi kuhesabu data ya plot haraka kuliko wachimbaji waaminifu wanavyoweza kuisoma kutoka kwa diski. Ratiba ya ukadiriaji (Sehemu ya 6) inahakikisha kuwa pengo la hesabu linalohitajika kwa usalama linaongezeka kwa muda kadri vifaa vinavyoboreshwa.

Sehemu zinazofuata zinachunguza kila darasa kuu la shambulio kwa undani na zinaelezea hatua za kukabiliana zilizojengwa katika PoCX.

### 8.2 Mashambulizi ya Uwezo

Kama PoW, mshambuliaji mwenye uwezo wa wingi anaweza kuandika upya historia (shambulio la 51%). Kufanikisha hili kunahitaji kupata alama ya kimwili ya kuhifadhi kubwa kuliko mtandao mwaminifu—jambo la gharama kubwa na linalouhitaji mpangilio mkubwa. Mara tu vifaa vinapopatikana, gharama za uendeshaji ni ndogo, lakini uwekezaji wa awali unaunda motisha kali ya kiuchumi ya kuishi kwa uaminifu: kudhoofisha mnyororo kungeharibu thamani ya msingi wa mali wa mshambuliaji mwenyewe.

PoC pia inaepuka suala la nothing-at-stake linalohusishwa na PoS. Ingawa wachimbaji wanaweza kuchunguza plot dhidi ya fork nyingi zinazoshindana, kila uchunguzi unatumia muda halisi—kawaida sekunde za kumi kwa kila mnyororo. Na muda wa block wa sekunde 120, hii kwa asili inapunguza uchimbaji wa fork nyingi, na kujaribu kuchimba fork nyingi kwa wakati mmoja kunadhoofisha utendaji kwa zote. Kuchimba fork kwa hivyo si bila gharama; kunakuwa na mipaka ya I/O.

Hata kama vifaa vya baadaye vinaruhusu uchunguzi wa plot karibu papo hapo (k.m., SSD za kasi kubwa), mshambuliaji bado angekabiliwa na mahitaji makubwa ya rasilimali za kimwili kudhibiti wingi wa uwezo wa mtandao, na kufanya shambulio la mtindo wa 51% kuwa la gharama kubwa na changamoto kwa mpangilio.

Hatimaye, mashambulizi ya uwezo ni magumu zaidi kukodisha kuliko mashambulizi ya nguvu ya hash. Hesabu za GPU zinaweza kupatikana kwa mahitaji na kuelekeza kwa mnyororo wowote wa PoW mara moja. Kinyume chake, PoC inahitaji vifaa vya kimwili, uundaji wa plot unaochukua muda, na operesheni zinazoendelea za I/O. Vikwazo hivi vinafanya mashambulizi ya muda mfupi, ya fursa kuwa na uwezekano mdogo zaidi.

### 8.3 Mashambulizi ya Wakati

Wakati una jukumu muhimu zaidi katika Proof of Capacity kuliko katika Proof of Work. Katika PoW, timestamp zinaathiri hasa urekebishaji wa ugumu; katika PoC, zinabainisha kama tarehe ya mwisho ya mchimbaji imepita na hivyo kama block ina haki ya kuundwa. Tarehe za mwisho zinahesabiwa kulingana na timestamp ya block ya mzazi, lakini saa ya ndani ya node inatumika kuhukumu kama block inayoingia iko mbali sana katika wakati ujao. Kwa sababu hii PoCX inatekeleza uvumilivu mdogo wa timestamp: block haziwezi kupotoka zaidi ya sekunde 15 kutoka kwa saa ya ndani ya node (ikilinganishwa na dirisha la masaa 2 la Bitcoin). Kikomo hiki kinafanya kazi kwa pande zote mbili—block zilizo mbali sana katika wakati ujao zinakataliwa, na node zenye saa polepole zinaweza kukataa kwa makosa block halali zinazoingia.

Kwa hivyo node zinapaswa kusawazisha saa zao kwa kutumia NTP au chanzo sawa cha wakati. PoCX kwa makusudi inaepuka kutegemea vyanzo vya wakati vya ndani ya mtandao ili kuzuia washambuliaji kudanganya wakati unaofahamika wa mtandao. Node zinafuatilia mwelekeo wao wenyewe na kutoa onyo ikiwa saa ya ndani inaanza kupotoka kutoka kwa timestamp za block za karibuni.

Kuharakisha saa—kuendesha saa ya ndani ya haraka kuunda mapema kidogo—kunatoa faida ndogo tu. Ndani ya uvumilivu unaoruhusiwa, uundaji wa kujilinda (Sehemu ya 7.3) unahakikisha kuwa mchimbaji mwenye suluhisho bora atachapisha mara moja akiona block duni ya mapema. Saa ya haraka inasaidia tu mchimbaji kuchapisha suluhisho linaloshinda tayari sekunde chache mapema; haiwezi kubadilisha uthibitisho duni kuwa wa kushinda.

Jaribio la kudanganya ugumu kupitia timestamp linakuwa na mipaka kwa kofia ya urekebishaji wa ±20% kwa kila block na dirisha la kusogea la block 24, kuzuia wachimbaji kuathiri kwa maana ugumu kupitia michezo ya wakati ya muda mfupi.

### 8.4 Mashambulizi ya Ubadilishaji wa Wakati-Kumbukumbu

Ubadilishaji wa wakati-kumbukumbu unajaribu kupunguza mahitaji ya kuhifadhi kwa kuhesabu upya sehemu za plot wakati wa hitaji. Mifumo ya awali ya Proof of Capacity ilikuwa na udhaifu kwa mashambulizi kama hayo, hasa kasoro ya usawa wa scoop wa POC1 na shambulio la ukandamizaji wa XOR-transpose wa POC2 (Sehemu ya 2.4). Yote mawili yalitumia usawa usio sawa katika jinsi ilivyokuwa ghali kuzalisha upya sehemu fulani za data ya plot, kuruhusu adui kupunguza kuhifadhi huku wakilipa adhabu ndogo ya hesabu. Pia, muundo mbadala wa plot kwa PoC2 una udhaifu sawa wa TMTO; mfano unaojulikana ni Chia, ambayo muundo wake wa plot unaweza kupunguzwa kwa hiari kwa kipengele zaidi ya 4.

PoCX inaondoa uso huu wa shambulio kabisa kupitia ujenzi wake wa nonce na muundo wa warp. Ndani ya kila nonce, hatua ya mwisho ya usambazaji inahesabu hash ya bafa iliyohesabiwa kikamilifu na ku-XOR matokeo kwa baiti zote, kuhakikisha kuwa kila sehemu ya bafa inategemea kila sehemu nyingine na haiwezi kufupishwa. Baadaye, kushusha kwa PoC2 kunabadilisha nusu za chini na juu za kila scoop, kusawazisha gharama ya hesabu ya kurejesha scoop yoyote.

PoCX zaidi inaondoa shambulio la ukandamizaji wa XOR–transpose wa POC2 kwa kupata muundo wake ulioimarishwa wa X1, ambapo kila scoop ni XOR ya nafasi ya moja kwa moja na nafasi ya transposed kwa warp zilizounganishwa; hii inaunganisha kila scoop na safu nzima na safu wima nzima ya data ya msingi ya X0, kufanya ujenzi upya uhitaji nonce elfu kadhaa kamili na hivyo kuondoa kabisa ubadilishaji usio sawa wa wakati-kumbukumbu.

Kwa sababu hiyo, kuhifadhi plot kamili ni mkakati pekee unaowezekana kwa hesabu kwa wachimbaji. Hakuna njia fupi inayojulikana—iwe ni uundaji wa plot wa sehemu, uzalishaji upya wa kuchagua, ukandamizaji wa muundo, au njia za mseto za hesabu-kuhifadhi—inayotoa faida ya maana. PoCX inahakikisha kuwa uchimbaji unabaki kutegemea kabisa kuhifadhi na kuwa uwezo unaonyesha ahadi halisi, ya kimwili.

### 8.5 Mashambulizi ya Ugawaji

PoCX inatumia mashine ya hali ya kubainisha kusimamia ugawaji wote wa plot-kwa-mwundaji. Kila ugawaji unaendelea kupitia hali zilizofafanuliwa vizuri—UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED—na ucheleweshaji wa uanzishaji na ubatilishaji uliotekelezwa. Hii inahakikisha kuwa mchimbaji hawezi kubadilisha mara moja ugawaji kudanganya mfumo au kubadilisha haraka mamlaka ya uundaji.

Kwa sababu mabadiliko yote yanahitaji uthibitisho wa kriptografia—hasa, saini za mmiliki wa plot zinazothibitishika dhidi ya pembejeo ya UTXO—mtandao unaweza kuamini uhalali wa kila ugawaji. Jaribio la kupita mashine ya hali au kutengeneza ugawaji zinakataliwa moja kwa moja wakati wa uthibitishaji wa makubaliano. Mashambulizi ya kurudia pia yanazuiwa na ulinzi wa kawaida wa kurudia miamala wa mtindo wa Bitcoin, kuhakikisha kuwa kila hatua ya ugawaji imeunganishwa kipekee na pembejeo halali, isiyotumika.

Mchanganyiko wa usimamizi wa mashine ya hali, ucheleweshaji uliotekelezwa, na uthibitisho wa kriptografia unafanya udanganyifu unaotegemea ugawaji kuwa hauwezekani kivitendo: wachimbaji hawawezi kuteka ugawaji, kufanya ugawaji upya wa haraka wakati wa mashindano ya block, au kupita ratiba za ubatilishaji.

### 8.6 Usalama wa Saini

Saini za block katika PoCX zinatumika kama kiungo muhimu kati ya uthibitisho na funguo ya uundaji inayofanya kazi, kuhakikisha kuwa wachimbaji walioidhinishwa pekee wanaweza kuzalisha block halali.

Ili kuzuia mashambulizi ya kubadilika, saini haziingizwi katika hesabu ya hash ya block. Hii inaondoa hatari za saini zinazoweza kubadilika ambazo zingeweza kudhoofisha uthibitishaji au kuruhusu mashambulizi ya kubadilisha block.

Ili kupunguza njia za kukataa huduma, ukubwa wa saini na funguo ya umma umewekwa—baiti 65 kwa saini zilizoshupazwa na baiti 33 kwa funguo za umma zilizokandamizwa—kuzuia washambuliaji kupunguza block kusababisha uchovu wa rasilimali au kupunguza usambazaji wa mtandao.

---

## 9. Utekelezaji

PoCX imetekelezwa kama ugani wa moduli kwa Bitcoin Core, na msimbo wote husika umehifadhiwa ndani ya saraka yake maalum na kuanzishwa kupitia bendera ya kipengele. Muundo huu unahifadhi uadilifu wa msimbo wa asili, kuruhusu PoCX kuwezeshwa au kuzimwa kwa usafi, ambayo inarahisisha upimaji, ukaguzi, na kubaki kulingana na mabadiliko ya juu.

Ujumuishaji unagusa tu maeneo muhimu yanayohitajika kusaidia Proof of Capacity. Kichwa cha block kimepanuliwa kujumuisha sehemu mahususi za PoCX, na uthibitishaji wa makubaliano umerekebishwa kusindika uthibitisho unaotegemea kuhifadhi pamoja na ukaguzi wa kawaida wa Bitcoin. Mfumo wa uundaji, unaohusika na kusimamia tarehe za mwisho, kupanga ratiba, na uwasilishaji wa wachimbaji, umehifadhiwa kikamilifu ndani ya moduli za PoCX, wakati ugani wa RPC unafunua kazi za uchimbaji na ugawaji kwa wateja wa nje. Kwa watumiaji, kiolesura cha wallet kimeboreshwa kusimamia ugawaji kupitia miamala ya OP_RETURN, kuwezesha mwingiliano laini na vipengele vipya vya makubaliano.

Operesheni zote muhimu za makubaliano zimetekelezwa katika C++ ya kubainisha bila utegemezi wa nje, kuhakikisha uthabiti wa jukwaa. Shabal256 inatumika kwa kuhesabu hash, wakati Time Bending na hesabu ya ubora zinategemea aritmetiki ya nukta-imara na operesheni za biti 256. Operesheni za kriptografia kama uthibitishaji wa saini zinatumia maktaba iliyopo ya secp256k1 ya Bitcoin Core.

Kwa kutenga kazi ya PoCX kwa njia hii, utekelezaji unabaki unaokaguliwa, unaohifadhiwa, na wenye utangamano kamili na maendeleo yanayoendelea ya Bitcoin Core, kuonyesha kuwa utaratibu mpya kabisa wa makubaliano unaotegemea kuhifadhi unaweza kuishi pamoja na codebase ya proof-of-work iliyokomaa bila kusumbua uadilifu au utumiaji wake.

---

## 10. Vigezo vya Mtandao

PoCX inajengwa juu ya miundombinu ya mtandao ya Bitcoin na kutumia tena mfumo wake wa vigezo vya mnyororo. Kusaidia uchimbaji unaotegemea uwezo, muda wa block, usimamizi wa ugawaji, na ukadiriaji wa plot, vigezo kadhaa vimepanuliwa au kubadilishwa. Hii inajumuisha lengo la muda wa block, ruzuku ya awali, ratiba ya nusu, ucheleweshaji wa uanzishaji na ubatilishaji wa ugawaji, pamoja na vitambulisho vya mtandao kama baiti za uchawi, milango, na viambishi vya Bech32. Mazingira ya Testnet na regtest zaidi yanarekebisha vigezo hivi kuwezesha marudio ya haraka na upimaji wa uwezo mdogo.

Jedwali zilizo hapa chini zinaonyesha muhtasari wa mipangilio ya mainnet, testnet, na regtest inayotokana, zikionyesha jinsi PoCX inavyozoea vigezo vya msingi vya Bitcoin kwa mfano wa makubaliano unaotegemea kuhifadhi.

### 10.1 Mainnet

| Kigezo | Thamani |
|--------|---------|
| Baiti za uchawi | `0xa7 0x3c 0x91 0x5e` |
| Mlango wa kawaida | 8888 |
| Bech32 HRP | `pocx` |
| Lengo la muda wa block | sekunde 120 |
| Ruzuku ya awali | BTC 10 |
| Muda wa nusu | block 1050000 (~miaka 4) |
| Ugavi wa jumla | ~milioni 21 BTC |
| Uanzishaji wa ugawaji | block 30 |
| Ubatilishaji wa ugawaji | block 720 |
| Dirisha la kusogea | block 24 |

### 10.2 Testnet

| Kigezo | Thamani |
|--------|---------|
| Baiti za uchawi | `0x6d 0xf2 0x48 0xb3` |
| Mlango wa kawaida | 18888 |
| Bech32 HRP | `tpocx` |
| Lengo la muda wa block | sekunde 120 |
| Vigezo vingine | Sawa na mainnet |

### 10.3 Regtest

| Kigezo | Thamani |
|--------|---------|
| Baiti za uchawi | `0xfa 0xbf 0xb5 0xda` |
| Mlango wa kawaida | 18444 |
| Bech32 HRP | `rpocx` |
| Lengo la muda wa block | sekunde 1 |
| Muda wa nusu | block 500 |
| Uanzishaji wa ugawaji | block 4 |
| Ubatilishaji wa ugawaji | block 8 |
| Hali ya uwezo mdogo | Imewezeshwa (~MB 4 plot) |

---

## 11. Kazi Zinazohusiana

Kwa miaka mingi, miradi kadhaa ya blockchain na makubaliano imechunguza mifumo ya uchimbaji inayotegemea kuhifadhi au ya mseto. PoCX inajengwa juu ya urithi huu huku ikianzisha maboresho katika usalama, ufanisi, na utangamano.

**Burstcoin / Signum.** Burstcoin ilianzisha mfumo wa kwanza wa Proof-of-Capacity (PoC) wa vitendo mwaka 2014, ikifafanua dhana za msingi kama plot, nonce, scoop, na uchimbaji unaotegemea tarehe ya mwisho. Warithi wake, hasa Signum (hapo awali Burstcoin), walipanua mfumo wa ikolojia na hatimaye waliibadilika kuwa kinachojulikana kama Proof-of-Commitment (PoC+), kuchanganya ahadi ya kuhifadhi na staking ya hiari kuathiri uwezo wa ufanisi. PoCX inarithi msingi wa uchimbaji unaotegemea kuhifadhi kutoka kwa miradi hii, lakini inapotoka sana kupitia muundo wa plot ulioimarishwa (usimbaji wa XOR-transpose), ukadiriaji wa kazi ya plot unaobadilika, usawazishaji wa tarehe ya mwisho ("Time Bending"), na mfumo wa ugawaji unaobadilika—yote huku ukiangika katika codebase ya Bitcoin Core badala ya kudumisha fork ya mtandao inayojitegemea.

**Chia.** Chia inatekeleza Proof of Space and Time, kuchanganya uthibitisho wa kuhifadhi unaotegemea diski na sehemu ya wakati inayotekelezwa kupitia Verifiable Delay Functions (VDF). Muundo wake unashughulikia wasiwasi fulani kuhusu matumizi tena ya uthibitisho na uzalishaji wa changamoto mpya, tofauti na PoC ya kawaida. PoCX haipitishi mfano huo wa uthibitisho uliounganishwa na wakati; badala yake, inahifadhi makubaliano yanayotegemea kuhifadhi na muda unaotabirika, ulioimarishwa kwa utangamano wa muda mrefu na uchumi wa UTXO na zana zinazotokana na Bitcoin.

**Spacemesh.** Spacemesh inapendekeza mpango wa Proof-of-Space-Time (PoST) ukitumia topology ya mtandao wa DAG (mesh). Katika mfano huu, washiriki lazima wathibitishe mara kwa mara kuwa kuhifadhi kulikowekwa kunabaki bila kubadilika kwa muda, badala ya kutegemea seti moja ya data iliyohesabiwa mapema. PoCX, kinyume chake, inathibitisha ahadi ya kuhifadhi wakati wa block pekee—kwa muundo wa plot ulioimarishwa na uthibitishaji mkali wa uthibitisho—kuepuka gharama ya ziada ya uthibitisho wa kuhifadhi unaoendelea huku ukihifadhi ufanisi na kutokuwa na uwekaji mkuu.

---

## 12. Hitimisho

Bitcoin-PoCX inaonyesha kuwa makubaliano ya ufanisi wa nishati yanaweza kujumuishwa katika Bitcoin Core huku yakihifadhi sifa za usalama na mfano wa kiuchumi. Michango muhimu inajumuisha usimbaji wa XOR-transpose (unaolazimisha washambuliaji kuhesabu nonce 4096 kwa kila utafutaji, kuondoa shambulio la ukandamizaji), algoriti ya Time Bending (mabadiliko ya usambazaji yanapunguza tofauti ya muda wa block), mfumo wa ugawaji wa uundaji (uwakilishaji unaotegemea OP_RETURN unawezesha uchimbaji wa pool bila uhifadhi wa fedha), ukadiriaji unaobadilika (ulioratibiwa na nusu kudumisha margin za usalama), na ujumuishaji mdogo (msimbo uliowekwa alama za vipengele umetenga katika saraka maalum).

Mfumo kwa sasa uko katika awamu ya testnet. Nguvu ya uchimbaji inatokana na uwezo wa kuhifadhi badala ya kiwango cha hash, kupunguza matumizi ya nishati kwa maelfu huku ukihifadhi mfano wa kiuchumi uliothibitishwa wa Bitcoin.

---

## Marejeleo

Bitcoin Core. *Bitcoin Core Repository.* https://github.com/bitcoin/bitcoin

Burstcoin. *Proof of Capacity Technical Documentation.* 2014.

NIST. *SHA-3 Competition: Shabal.* 2008.

Cohen, B., Pietrzak, K. *The Chia Network Blockchain.* 2019.

Spacemesh. *Spacemesh Protocol Documentation.* 2021.

PoC Consortium. *PoCX Framework.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Bitcoin-PoCX Integration.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Leseni**: MIT
**Shirika**: Proof of Capacity Consortium
**Hali**: Awamu ya Testnet
