[Yaliyomo](index.md) | [Inayofuata: Muundo wa Plot →](2-plot-format.md)

---

# Sura ya 1: Utangulizi na Muhtasari

## Bitcoin-PoCX ni Nini?

Bitcoin-PoCX ni muungano wa Bitcoin Core unaoongeza msaada wa makubaliano ya **Proof of Capacity neXt generation (PoCX)**. Inadumisha muundo uliopo wa Bitcoin Core huku ikiwezesha njia mbadala ya uchimbaji yenye ufanisi wa nishati kama mbadala kamili wa Proof of Work.

**Tofauti Muhimu**: Hii ni **mtandao mpya** bila utangamano wa nyuma na Bitcoin PoW. Bloku za PoCX haziendani na nodi za PoW kwa makusudi.

---

## Utambulisho wa Mradi

- **Shirika**: Proof of Capacity Consortium
- **Jina la Mradi**: Bitcoin-PoCX
- **Jina Kamili**: Bitcoin Core na Muungano wa PoCX
- **Hali**: Awamu ya Testnet

---

## Proof of Capacity ni Nini?

Proof of Capacity (PoC) ni utaratibu wa makubaliano ambapo nguvu ya uchimbaji inalingana na **nafasi ya diski** badala ya nguvu ya kompyuta. Wachimbaji huzalisha mapema faili kubwa za plot zenye heshi za kriptografia, kisha hutumia plot hizi kupata suluhisho halali za bloku.

**Ufanisi wa Nishati**: Faili za plot huzalishwa mara moja na kutumika tena bila kikomo. Uchimbaji unatumia nguvu ndogo sana ya CPU—hasa I/O ya diski.

**Uboreshaji wa PoCX**:
- Ilirekebisha shambulio la ukandamizaji wa XOR-transpose (biashara ya 50% ya muda-kumbukumbu katika POC2)
- Mpangilio uliojipanga kwa nonce 16 kwa vifaa vya kisasa
- Proof-of-work inayopanuka katika uzalishaji wa plot (viwango vya upanuzi Xn)
- Muungano wa asili wa C++ moja kwa moja katika Bitcoin Core
- Algorithm ya Kupinda Muda kwa usambazaji bora wa muda wa bloku

---

## Muhtasari wa Muundo

### Muundo wa Hifadhi

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + muungano wa PoCX
│   └── src/pocx/        # Utekelezaji wa PoCX
├── pocx/                # Mfumo wa msingi wa PoCX (moduli ndogo, kusoma pekee)
└── docs/                # Nyaraka hizi
```

### Falsafa ya Muungano

**Uso Mdogo wa Muungano**: Mabadiliko yametengwa katika saraka ya `/src/pocx/` na ndoano safi kwenye tabaka za uthibitishaji, uchimbaji, na RPC za Bitcoin Core.

**Alama za Kipengele**: Marekebisho yote chini ya ulinzi wa preprocessor `#ifdef ENABLE_POCX`. Bitcoin Core inajenga kawaida inapozimwa.

**Utangamano wa Upstream**: Usawazishaji wa mara kwa mara na sasisho za Bitcoin Core unadumishwa kupitia nukta zilizotengwa za muungano.

**Utekelezaji wa Asili wa C++**: Algorithm za kriptografia za scalar (Shabal256, hesabu ya scoop, ukandamizaji) zimeunganishwa moja kwa moja katika Bitcoin Core kwa uthibitishaji wa makubaliano.

---

## Vipengele Muhimu

### 1. Ubadilishaji Kamili wa Makubaliano

- **Muundo wa Bloku**: Sehemu mahususi za PoCX zinabadilisha nonce na bits za ugumu wa PoW
  - Sahihi ya uzalishaji (entropi ya uamuzi wa uchimbaji)
  - Lengo la msingi (kinyume cha ugumu)
  - Uthibitisho wa PoCX (kitambulisho cha akaunti, mbegu, nonce)
  - Sahihi ya bloku (inathibitisha umiliki wa plot)

- **Uthibitishaji**: Bomba la uthibitishaji la hatua 5 kutoka ukaguzi wa kichwa hadi muunganisho wa bloku

- **Marekebisho ya Ugumu**: Marekebisho ya kila bloku kwa kutumia wastani unaosogea wa lengo la msingi la hivi karibuni

### 2. Algorithm ya Kupinda Muda

**Tatizo**: Muda wa bloku wa PoC wa jadi unafuata usambazaji wa exponential, na kusababisha bloku ndefu wakati hakuna mchimbaji anayepata suluhisho zuri.

**Suluhisho**: Ubadilishaji wa usambazaji kutoka exponential hadi chi-squared kwa kutumia mzizi wa tatu: `Y = scale × (X^(1/3))`.

**Athari**: Suluhisho nzuri sana zinaunda baadaye (mtandao una muda wa kuchanganua diski zote, inapunguza bloku za haraka), suluhisho duni zimeboreshwa. Muda wa wastani wa bloku unadumishwa sekunde 120, bloku ndefu zimepunguzwa.

**Maelezo**: [Sura ya 3: Makubaliano na Uchimbaji](3-consensus-and-mining.md)

### 3. Mfumo wa Ugawaji wa Haki za Kuunda

**Uwezo**: Wamiliki wa plot wanaweza kukabidhi haki za kuunda kwa anwani nyingine huku wakidumisha umiliki wa plot.

**Matumizi**:
- Uchimbaji wa dimbwi (plot zinagawa kwa anwani ya dimbwi)
- Hifadhi baridi (ufunguo wa uchimbaji tofauti na umiliki wa plot)
- Uchimbaji wa vyama vingi (miundombinu iliyoshirikiwa)

**Muundo**: Usanifu wa OP_RETURN pekee—hakuna UTXO maalum, ugawaji unafuatiliwa tofauti katika hifadhidata ya chainstate.

**Maelezo**: [Sura ya 4: Ugawaji wa Kuunda](4-forging-assignments.md)

### 4. Kuunda kwa Kujilinda

**Tatizo**: Saa za haraka zinaweza kutoa faida za muda ndani ya uvumilivu wa sekunde 15 za baadaye.

**Suluhisho**: Unapopokea bloku inayoshindana kwa urefu sawa, angalia ubora wa ndani moja kwa moja. Ikiwa ni bora, unda mara moja.

**Athari**: Inaondoa motisha ya kudanganya saa—saa za haraka zinasaidia tu ikiwa tayari una suluhisho bora zaidi.

**Maelezo**: [Sura ya 5: Usalama wa Muda](5-timing-security.md)

### 5. Upanuzi Wenye Nguvu wa Ukandamizaji

**Usawazishaji wa Kiuchumi**: Mahitaji ya kiwango cha upanuzi yanaongezeka kwa ratiba ya exponential (Miaka 4, 12, 28, 60, 124 = nusu 1, 3, 7, 15, 31).

**Athari**: Kadri zawadi za bloku zinavyopungua, ugumu wa uzalishaji wa plot unaongezeka. Inadumisha ukingo wa usalama kati ya gharama za kuunda plot na kutafuta.

**Inazuia**: Mfumuko wa uwezo kutoka kwa vifaa vya haraka zaidi kwa wakati.

**Maelezo**: [Sura ya 6: Vigezo vya Mtandao](6-network-parameters.md)

---

## Falsafa ya Usanifu

### Usalama wa Msimbo

- Mazoea ya programu ya kujilinda kote
- Ushughulikiaji wa kina wa makosa katika njia za uthibitishaji
- Hakuna kufuli zilizowekwa ndani kwa ndani (kuzuia deadlock)
- Operesheni za atomiki za hifadhidata (UTXO + ugawaji pamoja)

### Muundo wa Moduli

- Utenganisho safi kati ya miundombinu ya Bitcoin Core na makubaliano ya PoCX
- Mfumo wa msingi wa PoCX unatoa primitivi za kriptografia
- Bitcoin Core inatoa mfumo wa uthibitishaji, hifadhidata, mtandao

### Uboreshaji wa Utendaji

- Mpangilio wa uthibitishaji wa kushindwa haraka (ukaguzi wa bei nafuu kwanza)
- Kuleta moja kwa moja kwa kila uwasilishaji (hakuna kupata cs_main mara kwa mara)
- Operesheni za atomiki za hifadhidata kwa usawa

### Usalama wa Reorg

- Data kamili ya kutengua kwa mabadiliko ya hali ya ugawaji
- Kuweka upya hali ya kuunda kwa mabadiliko ya ncha ya mtandao
- Kugundua uchakavu katika pointi zote za uthibitishaji

---

## Jinsi PoCX Inavyotofautiana na Proof of Work

| Kipengele | Bitcoin (PoW) | Bitcoin-PoCX |
|--------|---------------|--------------|
| **Rasilimali ya Uchimbaji** | Nguvu ya kompyuta (kiwango cha hash) | Nafasi ya diski (uwezo) |
| **Matumizi ya Nishati** | Juu (hashing ya mara kwa mara) | Chini (I/O ya diski pekee) |
| **Mchakato wa Uchimbaji** | Pata nonce yenye hash < lengo | Pata nonce yenye tarehe ya mwisho < muda uliopita |
| **Ugumu** | Sehemu ya `bits`, inarekebishwa kila bloku 2016 | Sehemu ya `base_target`, inarekebishwa kila bloku |
| **Muda wa Bloku** | ~dakika 10 (usambazaji wa exponential) | Sekunde 120 (imepindwa muda, tofauti iliyopunguzwa) |
| **Ruzuku** | 50 BTC → 25 → 12.5 → ... | 10 BTC → 5 → 2.5 → ... |
| **Vifaa** | ASIC (maalum) | HDD (vifaa vya kawaida) |
| **Utambulisho wa Uchimbaji** | Isiyojulikana | Mmiliki wa plot au mwakilishi |

---

## Mahitaji ya Mfumo

### Uendeshaji wa Nodi

**Sawa na Bitcoin Core**:
- **CPU**: Processor ya kisasa ya x86_64
- **Kumbukumbu**: 4-8 GB RAM
- **Hifadhi**: Mtandao mpya, kwa sasa tupu (inaweza kukua ~4× haraka kuliko Bitcoin kutokana na bloku za dakika 2 na hifadhidata ya ugawaji)
- **Mtandao**: Muunganisho wa mtandao imara
- **Saa**: Usawazishaji wa NTP unapendekezwa kwa uendeshaji bora

**Kumbuka**: Faili za plot HAZIHITAJIKI kwa uendeshaji wa nodi.

### Mahitaji ya Uchimbaji

**Mahitaji ya ziada kwa uchimbaji**:
- **Faili za Plot**: Zilizozalishwa mapema kwa kutumia `pocx_plotter` (utekelezaji wa marejeleo)
- **Programu ya Miner**: `pocx_miner` (utekelezaji wa marejeleo) inaunganisha kupitia RPC
- **Pochi**: `bitcoind` au `bitcoin-qt` na funguo za kibinafsi za anwani ya uchimbaji. Uchimbaji wa dimbwi hauhitaji pochi ya ndani.

---

## Kuanza

### 1. Jenga Bitcoin-PoCX

```bash
# Nakili na moduli ndogo
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Jenga na PoCX imewezeshwa
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Maelezo**: Tazama `CLAUDE.md` katika mzizi wa hifadhi

### 2. Endesha Nodi

**Nodi pekee**:
```bash
./build/bin/bitcoind
# au
./build/bin/bitcoin-qt
```

**Kwa uchimbaji** (inawezesha ufikiaji wa RPC kwa wachimbaji wa nje):
```bash
./build/bin/bitcoind -miningserver
# au
./build/bin/bitcoin-qt -server -miningserver
```

**Maelezo**: [Sura ya 6: Vigezo vya Mtandao](6-network-parameters.md)

### 3. Zalisha Faili za Plot

Tumia `pocx_plotter` (utekelezaji wa marejeleo) kuzalisha faili za plot za muundo wa PoCX.

**Maelezo**: [Sura ya 2: Muundo wa Plot](2-plot-format.md)

### 4. Sanidi Uchimbaji

Tumia `pocx_miner` (utekelezaji wa marejeleo) kuunganisha na kiolesura cha RPC cha nodi yako.

**Maelezo**: [Sura ya 7: Marejeleo ya RPC](7-rpc-reference.md) na [Sura ya 8: Mwongozo wa Pochi](8-wallet-guide.md)

---

## Utambuzi

### Muundo wa Plot

Imejengwa juu ya muundo wa POC2 (Burstcoin) na uboreshaji:
- Ilirekebisha kasoro ya usalama (shambulio la ukandamizaji wa XOR-transpose)
- Proof-of-work inayopanuka
- Mpangilio ulioimarishwa kwa SIMD
- Utendaji wa mbegu

### Miradi ya Chanzo

- **pocx_miner**: Utekelezaji wa marejeleo uliojengwa juu ya [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Utekelezaji wa marejeleo uliojengwa juu ya [engraver](https://github.com/PoC-Consortium/engraver)

**Utambuzi Kamili**: [Sura ya 2: Muundo wa Plot](2-plot-format.md)

---

## Muhtasari wa Maelezo ya Kiufundi

- **Muda wa Bloku**: Sekunde 120 (mainnet), sekunde 1 (regtest)
- **Ruzuku ya Bloku**: 10 BTC awali, nusu kila bloku 1050000 (~miaka 4)
- **Usambazaji wa Jumla**: ~milioni 21 BTC (sawa na Bitcoin)
- **Uvumilivu wa Baadaye**: Sekunde 15 (bloku hadi sekunde 15 mbele zinakubaliwa)
- **Onyo la Saa**: Sekunde 10 (inaonya waendeshaji kuhusu mkengeuko wa muda)
- **Ucheleweshaji wa Ugawaji**: Bloku 30 (~saa 1)
- **Ucheleweshaji wa Kubatilisha**: Bloku 720 (~saa 24)
- **Muundo wa Anwani**: P2WPKH (bech32, pocx1q...) pekee kwa operesheni za uchimbaji wa PoCX na ugawaji wa kuunda

---

## Mpangilio wa Msimbo

**Marekebisho ya Bitcoin Core**: Mabadiliko madogo kwa faili za msingi, yenye alama ya kipengele na `#ifdef ENABLE_POCX`

**Utekelezaji Mpya wa PoCX**: Umetengwa katika saraka ya `src/pocx/`

---

## Mazingatio ya Usalama

### Usalama wa Muda

- Uvumilivu wa sekunde 15 za baadaye unazuia kugawanyika kwa mtandao
- Kizingiti cha onyo cha sekunde 10 kinaarifu waendeshaji kuhusu mkengeuko wa saa
- Kuunda kwa kujilinda kunaondoa motisha ya kudanganya saa
- Kupinda Muda kunapunguza athari ya tofauti za muda

**Maelezo**: [Sura ya 5: Usalama wa Muda](5-timing-security.md)

### Usalama wa Ugawaji

- Usanifu wa OP_RETURN pekee (hakuna udanganyifu wa UTXO)
- Sahihi ya muamala inathibitisha umiliki wa plot
- Ucheleweshaji wa uanzishaji unazuia udanganyifu wa haraka wa hali
- Data ya kutengua salama kwa reorg kwa mabadiliko yote ya hali

**Maelezo**: [Sura ya 4: Ugawaji wa Kuunda](4-forging-assignments.md)

### Usalama wa Makubaliano

- Sahihi imetengwa na hash ya bloku (inazuia malleability)
- Ukubwa wa sahihi uliozuiwa (unazuia DoS)
- Uthibitishaji wa mipaka ya ukandamizaji (unazuia uthibitisho dhaifu)
- Marekebisho ya ugumu kwa kila bloku (inajibu mabadiliko ya uwezo)

**Maelezo**: [Sura ya 3: Makubaliano na Uchimbaji](3-consensus-and-mining.md)

---

## Hali ya Mtandao

**Mainnet**: Bado haijazinduliwa
**Testnet**: Inapatikana kwa majaribio
**Regtest**: Inafanya kazi kikamilifu kwa maendeleo

**Vigezo vya Bloku ya Mwanzo**: [Sura ya 6: Vigezo vya Mtandao](6-network-parameters.md)

---

## Hatua Zinazofuata

**Kwa Kuelewa PoCX**: Endelea na [Sura ya 2: Muundo wa Plot](2-plot-format.md) kujifunza kuhusu muundo wa faili za plot na mageuzi ya muundo.

**Kwa Usanidi wa Uchimbaji**: Ruka hadi [Sura ya 7: Marejeleo ya RPC](7-rpc-reference.md) kwa maelezo ya muungano.

**Kwa Kuendesha Nodi**: Kagua [Sura ya 6: Vigezo vya Mtandao](6-network-parameters.md) kwa chaguzi za usanidi.

---

[Yaliyomo](index.md) | [Inayofuata: Muundo wa Plot →](2-plot-format.md)
