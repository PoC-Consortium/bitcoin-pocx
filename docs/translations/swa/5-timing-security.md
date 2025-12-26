[← Iliyotangulia: Ugawaji wa Kuunda](4-forging-assignments.md) | [Yaliyomo](index.md) | [Inayofuata: Vigezo vya Mtandao →](6-network-parameters.md)

---

# Sura ya 5: Usawazishaji wa Muda na Usalama

## Muhtasari

Makubaliano ya PoCX yanahitaji usawazishaji sahihi wa muda kote kwenye mtandao. Sura hii inaandika taratibu za usalama zinazohusiana na muda, uvumilivu wa mkengeuko wa saa, na tabia ya kuunda kwa kujilinda.

**Taratibu Muhimu**:
- Uvumilivu wa sekunde 15 za baadaye kwa muda wa bloku
- Mfumo wa onyo wa mkengeuko wa saa wa sekunde 10
- Kuunda kwa kujilinda (kuzuia udanganyifu wa saa)
- Muungano wa algorithm ya Kupinda Muda

---

## Yaliyomo

1. [Mahitaji ya Usawazishaji wa Muda](#mahitaji-ya-usawazishaji-wa-muda)
2. [Kugundua Mkengeuko wa Saa na Maonyo](#kugundua-mkengeuko-wa-saa-na-maonyo)
3. [Utaratibu wa Kuunda kwa Kujilinda](#utaratibu-wa-kuunda-kwa-kujilinda)
4. [Uchambuzi wa Vitisho vya Usalama](#uchambuzi-wa-vitisho-vya-usalama)
5. [Mazoea Bora kwa Waendeshaji wa Nodi](#mazoea-bora-kwa-waendeshaji-wa-nodi)

---

## Mahitaji ya Usawazishaji wa Muda

### Viwango na Vigezo

**Usanidi wa Bitcoin-PoCX:**
```cpp
// src/chain.h:31
static constexpr int64_t MAX_FUTURE_BLOCK_TIME = 15;  // sekunde 15

// src/node/timeoffsets.h:27
static constexpr std::chrono::seconds WARN_THRESHOLD{10};  // sekunde 10
```

### Ukaguzi wa Uthibitishaji

**Uthibitishaji wa Muda wa Bloku** (`src/validation.cpp:4547-4561`):
```cpp
// 1. Ukaguzi wa monotonic: muda >= muda wa bloku iliyotangulia
if (block.nTime < pindexPrev->nTime) {
    return state.Invalid("time-too-old");
}

// 2. Ukaguzi wa baadaye: muda <= sasa + sekunde 15
if (block.Time() > NodeClock::now() + std::chrono::seconds{MAX_FUTURE_BLOCK_TIME}) {
    return state.Invalid("time-too-new");
}

// 3. Ukaguzi wa tarehe ya mwisho: muda uliopita >= tarehe ya mwisho
uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
if (result.deadline > elapsed_time) {
    return state.Invalid("bad-pocx-timing");
}
```

### Jedwali la Athari za Mkengeuko wa Saa

| Mkengeuko wa Saa | Inaweza Kusawazisha? | Inaweza Kuchimba? | Hali ya Uthibitishaji | Athari ya Ushindani |
|--------------|-----------|-----------|-------------------|-------------------|
| -30s polepole | HAPANA - Ukaguzi wa baadaye unashindwa | N/A | **NODI ILIYOKUFA** | Haiwezi kushiriki |
| -14s polepole | Ndiyo | Ndiyo | Kuunda kuchelewa, linapita uthibitishaji | Inapoteza mashindano |
| 0s kamili | Ndiyo | Ndiyo | Bora | Bora |
| +14s haraka | Ndiyo | Ndiyo | Kuunda mapema, linapita uthibitishaji | Inashinda mashindano |
| +16s haraka | Ndiyo | HAPANA - Ukaguzi wa baadaye unashindwa | Haiwezi kusambaza bloku | Inaweza kusawazisha, haiwezi kuchimba |

**Ufahamu Muhimu**: Dirisha la sekunde 15 ni sawa kwa ushiriki (±14.9s), lakini saa za haraka zinatoa faida isiyofaa ya ushindani ndani ya uvumilivu.

### Muungano wa Kupinda Muda

Algorithm ya Kupinda Muda (iliyoelezwa kwa undani katika [Sura ya 3](3-consensus-and-mining.md#hesabu-ya-kupinda-muda)) inabadilisha tarehe za mwisho zisizo na mabadiliko kwa kutumia mzizi wa tatu:

```
time_bended_deadline = scale × (deadline_seconds)^(1/3)
```

**Mwingiliano na Mkengeuko wa Saa**:
- Suluhisho bora zinaunda mapema zaidi (mzizi wa tatu unakuza tofauti za ubora)
- Mkengeuko wa saa unaathiri muda wa kuunda kulinganishwa na mtandao
- Kuunda kwa kujilinda kunahakikisha ushindani wa msingi wa ubora licha ya tofauti za muda

---

## Kugundua Mkengeuko wa Saa na Maonyo

### Mfumo wa Onyo

Bitcoin-PoCX inafuatilia mkengeuko wa muda kati ya nodi ya ndani na wenzake wa mtandao.

**Ujumbe wa Onyo** (mkengeuko unapozidi sekunde 10):
> "Tarehe na muda wa kompyuta yako zinaonekana kuwa zaidi ya sekunde 10 nje ya usawazishaji na mtandao, hii inaweza kusababisha kushindwa kwa makubaliano ya PoCX. Tafadhali angalia saa ya mfumo wako."

**Utekelezaji**: `src/node/timeoffsets.cpp`

### Sababu ya Usanifu

**Kwa nini sekunde 10?**
- Inatoa akiba ya usalama ya sekunde 5 kabla ya kikomo cha uvumilivu wa sekunde 15
- Kali zaidi kuliko default ya Bitcoin Core (dakika 10)
- Inafaa kwa mahitaji ya muda ya PoC

**Mbinu ya Kuzuia**:
- Onyo la mapema kabla ya kushindwa muhimu
- Inaruhusu waendeshaji kurekebisha matatizo kwa bidii
- Inapunguza kugawanyika kwa mtandao kutokana na kushindwa kunakohusiana na muda

---

## Utaratibu wa Kuunda kwa Kujilinda

### Ni Nini

Kuunda kwa kujilinda ni tabia ya kawaida ya mchimbaji katika Bitcoin-PoCX inayoondoa faida za msingi wa muda katika uzalishaji wa bloku. Mchimbaji wako anapopokea bloku inayoshindana kwa urefu sawa, inaangalia moja kwa moja ikiwa una suluhisho bora zaidi. Ikiwa ndio, inaunda bloku yako mara moja, kuhakikisha ushindani wa msingi wa ubora badala ya ushindani wa msingi wa kudanganya saa.

### Tatizo

Makubaliano ya PoCX yanaruhusu bloku zenye muda hadi sekunde 15 katika siku zijazo. Uvumilivu huu ni muhimu kwa usawazishaji wa mtandao wa kimataifa. Hata hivyo, unaunda fursa ya kudanganya saa:

**Bila Kuunda kwa Kujilinda:**
- Mchimbaji A: Muda sahihi, ubora 800 (bora zaidi), anasubiri tarehe ya mwisho sahihi
- Mchimbaji B: Saa haraka (+14s), ubora 1000 (mbaya zaidi), anaunda sekunde 14 mapema
- Matokeo: Mchimbaji B anashinda shindano licha ya kazi duni ya proof-of-capacity

**Tatizo:** Kudanganya saa kunatoa faida hata na ubora mbaya zaidi, kudhoofisha kanuni ya proof-of-capacity.

### Suluhisho: Ulinzi wa Tabaka Mbili

#### Tabaka la 1: Onyo la Mkengeuko wa Saa (Kuzuia)

Bitcoin-PoCX inafuatilia mkengeuko wa muda kati ya nodi yako na wenzake wa mtandao. Saa yako ikipotoka zaidi ya sekunde 10 kutoka makubaliano ya mtandao, unapokea onyo linalokutahadharisha kurekebisha matatizo ya saa kabla hayajasababisha matatizo.

#### Tabaka la 2: Kuunda kwa Kujilinda (Majibu)

Mchimbaji mwingine anapochapisha bloku kwa urefu sawa unaochimba:

1. **Kugundua**: Nodi yako inagundua ushindani wa urefu sawa
2. **Uthibitishaji**: Inatoa na kuthibitisha ubora wa bloku inayoshindana
3. **Ulinganisho**: Inaangalia ikiwa ubora wako ni bora zaidi
4. **Majibu**: Ikiwa ni bora zaidi, inaunda bloku yako mara moja

**Matokeo:** Mtandao unapokea bloku zote mbili na kuchagua ile yenye ubora bora kupitia utatuzi wa kawaida wa fork.

### Jinsi Inavyofanya Kazi

#### Hali: Ushindani wa Urefu Sawa

```
Muda 150s: Mchimbaji B (saa +10s) anaunda na ubora 1000
           → Muda wa bloku unaonyesha 160s (10s katika siku zijazo)

Muda 150s: Nodi yako inapokea bloku ya Mchimbaji B
           → Inagundua: urefu sawa, ubora 1000
           → Una: ubora 800 (bora zaidi!)
           → Hatua: Unda mara moja na muda sahihi (150s)

Muda 152s: Mtandao unathibitisha bloku zote mbili
           → Zote halali (ndani ya uvumilivu wa 15s)
           → Ubora 800 unashinda (chini = bora zaidi)
           → Bloku yako inakuwa ncha ya mtandao
```

#### Hali: Reorg ya Kweli

```
Urefu wako wa uchimbaji 100, mshindani anachapisha bloku 99
→ Sio ushindani wa urefu sawa
→ Kuunda kwa kujilinda HAISABABISHWI
→ Kushughulikia reorg kwa kawaida kunaendelea
```

### Faida

**Motisha ya Sifuri kwa Kudanganya Saa**
- Saa za haraka zinasaidia tu ikiwa tayari una ubora bora zaidi
- Kudanganya saa kunakuwa kitu kisichofanya kazi kiuchumi

**Ushindani wa Msingi wa Ubora Unalazimishwa**
- Inalazimisha wachimbaji kushindana kwa kazi halisi ya proof-of-capacity
- Inahifadhi uadilifu wa makubaliano ya PoCX

**Usalama wa Mtandao**
- Ina ustahimilivu dhidi ya mikakati ya mchezo wa msingi wa muda
- Hakuna mabadiliko ya makubaliano yanayohitajika - tabia safi ya mchimbaji

**Moja kwa Moja Kikamilifu**
- Hakuna usanidi unaohitajika
- Inasababishwa wakati inapohitajika tu
- Tabia ya kawaida katika nodi zote za Bitcoin-PoCX

### Biashara

**Kuongezeka Kidogo kwa Kiwango cha Yatima**
- Makusudi - bloku za shambulio zinakuwa yatima
- Kunafanyika tu wakati wa majaribio halisi ya kudanganya saa
- Matokeo ya asili ya utatuzi wa fork wa msingi wa ubora

**Ushindani Mfupi wa Mtandao**
- Mtandao unaona kwa muda mfupi bloku mbili zinazoshindana
- Unahuliwa kwa sekunde kupitia uthibitishaji wa kawaida
- Tabia sawa na uchimbaji wa wakati mmoja katika Bitcoin

### Maelezo ya Kiufundi

**Athari ya Utendaji:** Ndogo sana
- Inasababishwa tu kwa ushindani wa urefu sawa
- Inatumia data ya kumbukumbu (hakuna I/O ya diski)
- Uthibitishaji unakamilika kwa millisekunde

**Matumizi ya Rasilimali:** Ndogo
- ~mistari 20 ya mantiki ya msingi
- Inatumia tena miundombinu iliyopo ya uthibitishaji
- Kupata kufuli moja

**Utangamano:** Kamili
- Hakuna mabadiliko ya sheria za makubaliano
- Inafanya kazi na vipengele vyote vya Bitcoin Core
- Ufuatiliaji wa hiari kupitia kumbukumbu za utatuzi

**Hali**: Inafanya kazi katika matoleo yote ya Bitcoin-PoCX
**Ilianzishwa Kwanza**: 2025-10-10

---

## Uchambuzi wa Vitisho vya Usalama

### Shambulio la Saa Haraka (Limepunguzwa na Kuunda kwa Kujilinda)

**Njia ya Shambulio**:
Mchimbaji mwenye saa **+14s mbele** anaweza:
1. Kupokea bloku kawaida (zinaonekana za zamani kwake)
2. Kuunda bloku mara moja tarehe ya mwisho inapopita
3. Kutangaza bloku zinazoonekana "mapema" sekunde 14 kwa mtandao
4. **Bloku zinakubaliwa** (ndani ya uvumilivu wa sekunde 15)
5. **Anashinda mashindano** dhidi ya wachimbaji waaminifu

**Athari Bila Kuunda kwa Kujilinda**:
Faida ni mdogo kwa sekunde 14.9 (si ya kutosha kuruka kazi kubwa ya PoC), lakini inatoa ukingo thabiti katika mashindano ya bloku.

**Upunguzaji (Kuunda kwa Kujilinda)**:
- Wachimbaji waaminifu wanagundua ushindani wa urefu sawa
- Wanalinganisha thamani za ubora
- Wanaunda mara moja ikiwa ubora ni bora zaidi
- **Matokeo**: Saa haraka inasaidia tu ikiwa tayari una ubora bora zaidi
- **Motisha**: Sifuri - kudanganya saa kunakuwa kitu kisichofanya kazi kiuchumi

### Kushindwa kwa Saa Polepole (Muhimu)

**Hali ya Kushindwa**:
Nodi **>15s nyuma** ni maafa:
- Haiwezi kuthibitisha bloku zinazoingia (ukaguzi wa baadaye unashindwa)
- Inakuwa imetengwa na mtandao
- Haiwezi kuchimba au kusawazisha

**Upunguzaji**:
- Onyo kali kwa mkengeuko wa 10s linatoa akiba ya sekunde 5 kabla ya kushindwa muhimu
- Waendeshaji wanaweza kurekebisha matatizo ya saa kwa bidii
- Ujumbe wazi wa makosa unaongoza utatuzi wa matatizo

---

## Mazoea Bora kwa Waendeshaji wa Nodi

### Usanidi wa Usawazishaji wa Muda

**Usanidi Unaopendekezwa**:
1. **Wezesha NTP**: Tumia Itifaki ya Muda ya Mtandao kwa usawazishaji wa moja kwa moja
   ```bash
   # Linux (systemd-timesyncd)
   sudo timedatectl set-ntp true

   # Angalia hali
   timedatectl status
   ```

2. **Thibitisha Usahihi wa Saa**: Angalia mara kwa mara mkengeuko wa muda
   ```bash
   # Angalia hali ya usawazishaji wa NTP
   ntpq -p

   # Au na chrony
   chronyc tracking
   ```

3. **Fuatilia Maonyo**: Angalia maonyo ya mkengeuko wa saa ya Bitcoin-PoCX katika kumbukumbu

### Kwa Wachimbaji

**Hakuna Hatua Inayohitajika**:
- Kipengele kinafanya kazi daima
- Kinafanya kazi moja kwa moja
- Dumisha tu saa yako ya mfumo kuwa sahihi

**Mazoea Bora**:
- Tumia usawazishaji wa muda wa NTP
- Fuatilia maonyo ya mkengeuko wa saa
- Shughulikia maonyo mara moja yakionekana

**Tabia Inayotarajiwa**:
- Uchimbaji wa peke yako: Kuunda kwa kujilinda mara chache kunasababishwa (hakuna ushindani)
- Uchimbaji wa mtandao: Inalinda dhidi ya majaribio ya kudanganya saa
- Operesheni ya uwazi: Wachimbaji wengi hawataiona kamwe

### Utatuzi wa Matatizo

**Onyo: "10 seconds out of sync"**
- Hatua: Angalia na rekebisha usawazishaji wa saa ya mfumo
- Athari: Akiba ya sekunde 5 kabla ya kushindwa muhimu
- Zana: NTP, chrony, systemd-timesyncd

**Kosa: "time-too-new" kwenye bloku zinazoingia**
- Sababu: Saa yako ni >15 sekunde polepole
- Athari: Haiwezi kuthibitisha bloku, nodi imetengwa
- Kurekebisha: Sawazisha saa ya mfumo mara moja

**Kosa: Haiwezi kusambaza bloku zilizoundwa**
- Sababu: Saa yako ni >15 sekunde haraka
- Athari: Bloku zinakataliwa na mtandao
- Kurekebisha: Sawazisha saa ya mfumo mara moja

---

## Maamuzi ya Usanifu na Sababu

### Kwa Nini Uvumilivu wa Sekunde 15?

**Sababu**:
- Muda wa tarehe ya mwisho unaobadilika wa Bitcoin-PoCX ni muhimu kidogo kwa muda kuliko makubaliano ya muda uliowekwa
- Sekunde 15 inatoa ulinzi wa kutosha huku ikizuia kugawanyika kwa mtandao

**Biashara**:
- Uvumilivu mkali zaidi = kugawanyika zaidi kwa mtandao kutoka mkengeuko mdogo
- Uvumilivu mpana zaidi = fursa zaidi za mashambulizi ya muda
- Sekunde 15 zinasawazisha usalama na uthabiti

### Kwa Nini Onyo la Sekunde 10?

**Sababu**:
- Inatoa akiba ya usalama ya sekunde 5
- Inafaa zaidi kwa PoC kuliko default ya Bitcoin ya dakika 10
- Inaruhusu marekebisho ya bidii kabla ya kushindwa muhimu

### Kwa Nini Kuunda kwa Kujilinda?

**Tatizo Lililoshugulikwa**:
- Uvumilivu wa sekunde 15 unawezesha faida ya saa haraka
- Makubaliano ya msingi wa ubora yangeweza kudhoofishwa na udanganyifu wa muda

**Faida za Suluhisho**:
- Ulinzi wa gharama ya sifuri (hakuna mabadiliko ya makubaliano)
- Operesheni ya moja kwa moja
- Inaondoa motisha ya shambulio
- Inahifadhi kanuni za proof-of-capacity

### Kwa Nini Hakuna Usawazishaji wa Muda wa Ndani ya Mtandao?

**Sababu ya Usalama**:
- Bitcoin Core ya kisasa iliondoa marekebisho ya muda ya msingi wa wenzake
- Ina udhaifu kwa mashambulizi ya Sybil kwenye muda unaoonekana wa mtandao
- PoCX inazuia kwa makusudi kutegemea vyanzo vya muda vya ndani ya mtandao
- Saa ya mfumo inaweza kuaminika zaidi kuliko makubaliano ya wenzake
- Waendeshaji wanapaswa kusawazisha kwa kutumia NTP au chanzo sawa cha muda wa nje
- Nodi zinafuatilia mkengeuko wao wenyewe na kutoa maonyo ikiwa saa ya ndani inatofautiana na muda wa bloku za hivi karibuni

---

## Marejeleo ya Utekelezaji

**Faili za Msingi**:
- Uthibitishaji wa muda: `src/validation.cpp:4547-4561`
- Kiwango cha uvumilivu wa baadaye: `src/chain.h:31`
- Kizingiti cha onyo: `src/node/timeoffsets.h:27`
- Ufuatiliaji wa mkengeuko wa muda: `src/node/timeoffsets.cpp`
- Kuunda kwa kujilinda: `src/pocx/mining/scheduler.cpp`

**Nyaraka Zinazohusiana**:
- Algorithm ya Kupinda Muda: [Sura ya 3: Makubaliano na Uchimbaji](3-consensus-and-mining.md#hesabu-ya-kupinda-muda)
- Uthibitishaji wa bloku: [Sura ya 3: Uthibitishaji wa Bloku](3-consensus-and-mining.md#uthibitishaji-wa-bloku)

---

**Imeundwa**: 2025-10-10
**Hali**: Utekelezaji Kamili
**Uangalifu**: Mahitaji ya usawazishaji wa muda, kushughulikia mkengeuko wa saa, kuunda kwa kujilinda

---

[← Iliyotangulia: Ugawaji wa Kuunda](4-forging-assignments.md) | [Yaliyomo](index.md) | [Inayofuata: Vigezo vya Mtandao →](6-network-parameters.md)
