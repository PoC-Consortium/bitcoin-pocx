[← Iliyotangulia: Utangulizi](1-introduction.md) | [Yaliyomo](index.md) | [Inayofuata: Makubaliano na Uchimbaji →](3-consensus-and-mining.md)

---

# Sura ya 2: Maelezo ya Muundo wa Plot wa PoCX

Hati hii inaelezea muundo wa plot wa PoCX, toleo lililoboreshwa la muundo wa POC2 lenye usalama ulioboreshwa, uboreshaji wa SIMD, na proof-of-work inayopanuka.

## Muhtasari wa Muundo

Faili za plot za PoCX zina thamani za hash za Shabal256 zilizohesabiwa mapema zilizopangwa kwa operesheni za uchimbaji zenye ufanisi. Kufuatia desturi ya PoC tangu POC1, **metadata yote imejumuishwa katika jina la faili** - hakuna kichwa cha faili.

### Kiendelezi cha Faili
- **Kawaida**: `.pocx` (plot zilizokamilika)
- **Inaendelea**: `.tmp` (wakati wa kuandika plot, inabadilishwa jina kuwa `.pocx` inapokamilika)

## Muktadha wa Kihistoria na Mageuzi ya Udhaifu

### Muundo wa POC1 (Wa Zamani)
**Udhaifu Mkubwa Mbili (Biashara za Muda-Kumbukumbu):**

1. **Kasoro ya Usambazaji wa PoW**
   - Usambazaji usio sawa wa proof-of-work kati ya scoop
   - Nambari za scoop za chini zingeweza kuhesabiwa papo hapo
   - **Athari**: Mahitaji ya hifadhi yalipunguzwa kwa washambuliaji

2. **Shambulio la Ukandamizaji wa XOR** (Biashara ya 50% ya Muda-Kumbukumbu)
   - Ilitumia mali za kihisabati kufikia upunguzaji wa 50% wa hifadhi
   - **Athari**: Washambuliaji wangeweza kuchimba na nusu ya hifadhi inayohitajika

**Uboreshaji wa Mpangilio**: Mpangilio wa msingi wa scoop wa mfuatano kwa ufanisi wa HDD

### Muundo wa POC2 (Burstcoin)
- ✅ **Ilirekebisha kasoro ya usambazaji wa PoW**
- ❌ **Udhaifu wa XOR-transpose ulibaki bila kurekebishwa**
- **Mpangilio**: Ulidumisha uboreshaji wa scoop wa mfuatano

### Muundo wa PoCX (Wa Sasa)
- ✅ **Usambazaji wa PoW uliorekebishwa** (umetiwa kutoka POC2)
- ✅ **Udhaifu wa XOR-transpose umezibwa** (wa kipekee kwa PoCX)
- ✅ **Mpangilio ulioboreshwa wa SIMD/GPU** ulioimarishwa kwa uchakataji sambamba na ujumuishaji wa kumbukumbu
- ✅ **Proof-of-work inayopanuka** inazuia biashara za muda-kumbukumbu kadri nguvu ya kompyuta inavyoongezeka (PoW inafanywa tu wakati wa kuunda au kuboresha faili za plot)

## Usimbaji wa XOR-Transpose

### Tatizo: Biashara ya 50% ya Muda-Kumbukumbu

Katika muundo wa POC1/POC2, washambuliaji wangeweza kutumia uhusiano wa kihisabati kati ya scoop kuhifadhi nusu tu ya data na kuhesabu iliyobaki papo hapo wakati wa uchimbaji. "Shambulio la ukandamizaji wa XOR" hili liliharibu dhamana ya hifadhi.

### Suluhisho: Uimarishaji wa XOR-Transpose

PoCX inazalisha muundo wake wa uchimbaji (X1) kwa kutumia usimbaji wa XOR-transpose kwa jozi za warp za msingi (X0):

**Kuunda scoop S ya nonce N katika warp ya X1:**
1. Chukua scoop S ya nonce N kutoka warp ya kwanza ya X0 (nafasi ya moja kwa moja)
2. Chukua scoop N ya nonce S kutoka warp ya pili ya X0 (nafasi iliyobadilishwa)
3. XOR thamani mbili za byte 64 kupata scoop ya X1

Hatua ya transpose inabadilisha fahirisi za scoop na nonce. Kwa maneno ya matrix—ambapo safu zinawakilisha scoop na safu wima zinawakilisha nonce—inachanganya kipengele katika nafasi (S, N) katika warp ya kwanza na kipengele katika (N, S) katika ya pili.

### Kwa Nini Hii Inaondoa Shambulio

XOR-transpose inaunganisha kila scoop na safu nzima na safu wima nzima ya data ya msingi ya X0. Kurejesha scoop moja ya X1 kunahitaji ufikiaji wa data inayohusu fahirisi zote 4096 za scoop. Juhudi yoyote ya kuhesabu data inayokosekana ingehitaji kuzalisha tena nonce 4096 kamili badala ya nonce moja—kuondoa muundo wa gharama usio sawa uliotumiwa na shambulio la XOR.

Kwa hivyo, kuhifadhi warp kamili ya X1 inakuwa mkakati pekee unaofaa kwa kompyuta kwa wachimbaji.

## Muundo wa Metadata ya Jina la Faili

Metadata yote ya plot imesimbwa katika jina la faili kwa kutumia muundo huu halisi:

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Vipengele vya Jina la Faili

1. **ACCOUNT_PAYLOAD** (herufi 40 za hex)
   - Payload ya byte 20 ya akaunti kama hex ya herufi kubwa
   - Haitegemei mtandao (hakuna kitambulisho cha mtandao au checksum)
   - Mfano: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED** (herufi 64 za hex)
   - Thamani ya mbegu ya byte 32 kama hex ya herufi ndogo
   - **Mpya katika PoCX**: Mbegu ya nasibu ya byte 32 katika jina la faili inabadilisha uhesabuaji wa nonce za mfuatano — kuzuia kuingiliana kwa plot
   - Mfano: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS** (nambari ya desimali)
   - **Kitengo kipya cha ukubwa katika PoCX**: Kinabadilisha ukubwa unaotegemea nonce kutoka POC1/POC2
   - **Usanifu sugu kwa XOR-transpose**: Kila warp = nonce 4096 haswa (ukubwa wa sehemu unaohitajika kwa ubadilishaji sugu kwa XOR-transpose)
   - **Ukubwa**: warp 1 = byte 1073741824 = 1 GiB (kitengo rahisi)
   - Mfano: `1024` (plot ya 1 TiB = warp 1024)

4. **SCALING** (desimali yenye kiambishi cha X)
   - Kiwango cha upanuzi kama `X{level}`
   - Thamani za juu zaidi = proof-of-work zaidi inayohitajika
   - Mfano: `X4` (2^4 = ugumu wa 16× wa POC2)

### Mifano ya Majina ya Faili
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Mpangilio wa Faili na Muundo wa Data

### Mpangilio wa Kihierarkia
```
Faili ya Plot (HAKUNA KICHWA)
├── Scoop 0
│   ├── Warp 0 (Nonce zote kwa scoop/warp hii)
│   ├── Warp 1
│   └── ...
├── Scoop 1
│   ├── Warp 0
│   ├── Warp 1
│   └── ...
└── Scoop 4095
    ├── Warp 0
    └── ...
```

### Viwango na Ukubwa

| Kiwango        | Ukubwa                    | Maelezo                                     |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                   | Matokeo moja ya hash ya Shabal256                    |
| **SCOOP\_SIZE** | 64 B (2 × HASH\_SIZE)  | Jozi ya hash inayosomwa katika raundi ya uchimbaji                |
| **NUM\_SCOOPS** | 4096 (2¹²)             | Scoop kwa nonce; moja inachaguliwa kwa raundi        |
| **NONCE\_SIZE** | 262144 B (256 KiB)     | Scoop zote za nonce (kitengo kidogo zaidi cha PoC1/PoC2) |
| **WARP\_SIZE**  | 1073741824 B (1 GiB)   | Kitengo kidogo zaidi katika PoCX                           |

### Mpangilio wa Faili ya Plot Ulioboreshwa kwa SIMD

PoCX inatekeleza muundo wa ufikiaji wa nonce unaozingatia SIMD unaowezesha uchakataji wa vector wa nonce nyingi kwa wakati mmoja. Inajengwa juu ya dhana kutoka [utafiti wa uboreshaji wa POC2×16](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) kuongeza ufanisi wa kumbukumbu na SIMD.

---

#### Mpangilio wa Jadi wa Mfuatano

Hifadhi ya mfuatano ya nonce:

```
[Nonce 0: Data ya Scoop] [Nonce 1: Data ya Scoop] [Nonce 2: Data ya Scoop] ...
```

Kutofanya kazi vizuri kwa SIMD: Kila njia ya SIMD inahitaji neno sawa kati ya nonce:

```
Neno 0 kutoka Nonce 0 -> offset 0
Neno 0 kutoka Nonce 1 -> offset 512
Neno 0 kutoka Nonce 2 -> offset 1024
...
```

Ufikiaji wa scatter-gather unapunguza ufanisi.

---

#### Mpangilio Ulioboreshwa kwa SIMD wa PoCX

PoCX inahifadhi **nafasi za maneno kati ya nonce 16** kwa mfuatano:

```
Mstari wa Cache (byte 64):

Word0_N0 Word0_N1 Word0_N2 ... Word0_N15
Word1_N0 Word1_N1 Word1_N2 ... Word1_N15
...
```

**Mchoro wa ASCII**

```
Mpangilio wa jadi:

Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

Mpangilio wa PoCX:

Word0: [N0][N1][N2][N3]...[N15]
Word1: [N0][N1][N2][N3]...[N15]
Word2: [N0][N1][N2][N3]...[N15]
```

---

#### Faida za Ufikiaji wa Kumbukumbu

- Mstari mmoja wa cache unatoa data kwa njia zote za SIMD.
- Inaondoa operesheni za scatter-gather.
- Inapunguza makosa ya cache.
- Ufikiaji wa kumbukumbu wa mfuatano kamili kwa hesabu ya vector.
- GPU pia zinafaidika na upangaji wa nonce-16, kuongeza ufanisi wa cache.

---

#### Upanuzi wa SIMD

| SIMD       | Upana wa Vector* | Nonce | Mzunguko wa Uchakataji kwa Mstari wa Cache |
|------------|---------------|--------|---------------------------------|
| SSE2/AVX   | 128-bit       | 4      | mzunguko 4                        |
| AVX2       | 256-bit       | 8      | mzunguko 2                        |
| AVX512     | 512-bit       | 16     | mzunguko 1                         |

\* Kwa operesheni za integer

---



## Upanuzi wa Proof-of-Work

### Viwango vya Upanuzi
- **X0**: Nonce za msingi bila usimbaji wa XOR-transpose (wa kinadharia, hautumiki kwa uchimbaji)
- **X1**: Msingi wa XOR-transpose—muundo wa kwanza ulioimarishwa (kazi 1×)
- **X2**: Kazi 2× ya X1 (XOR kati ya warp 2)
- **X3**: Kazi 4× ya X1 (XOR kati ya warp 4)
- **…**
- **Xn**: Kazi 2^(n-1) × ya X1 iliyojumuishwa

### Faida
- **Ugumu wa PoW unaorekebishika**: Inaongeza mahitaji ya kompyuta kuendana na vifaa vya haraka zaidi
- **Maisha marefu ya muundo**: Inawezesha upanuzi rahisi wa ugumu wa uchimbaji kwa wakati

### Uboreshaji wa Plot / Utangamano wa Nyuma

Mtandao unapoongeza kiwango cha PoW (Proof of Work) kwa 1, plot zilizopo zinahitaji uboreshaji kudumisha ukubwa sawa wa plot unaofanya kazi. Kimsingi, sasa unahitaji PoW mara mbili katika faili zako za plot kufikia mchango sawa kwa akaunti yako.

Habari njema ni kwamba PoW uliyoifanya tayari wakati wa kuunda faili zako za plot haijapotea—unahitaji tu kuongeza PoW zaidi kwa faili zilizopo. Hakuna haja ya kuandika plot upya.

Vinginevyo, unaweza kuendelea kutumia plot zako za sasa bila kuboresha, lakini kumbuka kuwa sasa zitachangia 50% tu ya ukubwa wao uliofanya kazi hapo awali kwa akaunti yako. Programu yako ya uchimbaji inaweza kupanua faili ya plot papo hapo.

## Ulinganisho na Muundo wa Zamani

| Kipengele | POC1 | POC2 | PoCX |
|---------|------|------|------|
| Usambazaji wa PoW | ❌ Wenye kasoro | ✅ Umerekebishwa | ✅ Umerekebishwa |
| Ustahimilivu wa XOR-Transpose | ❌ Dhaifu | ❌ Dhaifu | ✅ Umerekebishwa |
| Uboreshaji wa SIMD | ❌ Hakuna | ❌ Hakuna | ✅ Wa Juu |
| Uboreshaji wa GPU | ❌ Hakuna | ❌ Hakuna | ✅ Umeimba |
| Proof-of-Work inayopanuka | ❌ Hakuna | ❌ Hakuna | ✅ Ndiyo |
| Msaada wa Mbegu | ❌ Hakuna | ❌ Hakuna | ✅ Ndiyo |

Muundo wa PoCX unawakilisha hali ya juu ya sasa katika muundo wa plot wa Proof of Capacity, ukishughulikia udhaifu wote unaojulikana huku ukitoa uboreshaji mkubwa wa utendaji kwa vifaa vya kisasa.

## Marejeleo na Usomaji Zaidi

- **Historia ya POC1/POC2**: [Muhtasari wa Uchimbaji wa Burstcoin](https://www.burstcoin.community/burstcoin-mining/) - Mwongozo wa kina wa muundo wa jadi wa Proof of Capacity
- **Utafiti wa POC2×16**: [Tangazo la CIP: POC2×16 - Muundo mpya ulioboreshwa wa plot](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Utafiti wa asili wa uboreshaji wa SIMD uliochochea PoCX
- **Algorithm ya Hash ya Shabal**: [Mradi wa Saphir: Shabal, Uwasilishaji kwa Mashindano ya Algorithm ya Hash ya Kriptografia ya NIST](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Maelezo ya kiufundi ya algorithm ya Shabal256 inayotumika katika uchimbaji wa PoC

---

[← Iliyotangulia: Utangulizi](1-introduction.md) | [Yaliyomo](index.md) | [Inayofuata: Makubaliano na Uchimbaji →](3-consensus-and-mining.md)
