[← Předchozí: Úvod](1-introduction.md) | [Obsah](index.md) | [Další: Konsenzus a těžba →](3-consensus-and-mining.md)

---

# Kapitola 2: Specifikace formátu PoCX plotů

Tento dokument popisuje formát PoCX plotů, vylepšenou verzi formátu POC2 se zlepšenou bezpečností, optimalizacemi SIMD a škálovatelným proof-of-work.

## Přehled formátu

PoCX plot soubory obsahují předpočítané hodnoty hashe Shabal256 organizované pro efektivní těžební operace. Podle tradice PoC od POC1 jsou **všechna metadata vložena do názvu souboru** — soubor nemá žádnou hlavičku.

### Přípona souboru
- **Standardní**: `.pocx` (dokončené ploty)
- **V průběhu**: `.tmp` (během plottování, po dokončení přejmenováno na `.pocx`)

## Historický kontext a vývoj zranitelností

### Formát POC1 (Legacy)
**Dvě hlavní zranitelnosti (časově-paměťové kompromisy):**

1. **Chyba distribuce PoW**
   - Nerovnoměrná distribuce proof-of-work mezi scoopy
   - Nízká čísla scoopů mohla být počítána za běhu
   - **Dopad**: Snížené požadavky na úložiště pro útočníky

2. **Útok XOR kompresí** (50% časově-paměťový kompromis)
   - Zneužil matematické vlastnosti k dosažení 50% redukce úložiště
   - **Dopad**: Útočníci mohli těžit s poloviční požadovanou kapacitou

**Optimalizace rozložení**: Základní sekvenční rozložení scoopů pro efektivitu HDD

### Formát POC2 (Burstcoin)
- ✅ **Opravena chyba distribuce PoW**
- ❌ **Zranitelnost XOR-transpose zůstala neopravena**
- **Rozložení**: Zachováno sekvenční optimalizované rozložení scoopů

### Formát PoCX (Aktuální)
- ✅ **Opravena distribuce PoW** (zděděno z POC2)
- ✅ **Opravena zranitelnost XOR-transpose** (unikátní pro PoCX)
- ✅ **Vylepšené rozložení SIMD/GPU** optimalizované pro paralelní zpracování a koalescenci paměti
- ✅ **Škálovatelný proof-of-work** zabraňuje časově-paměťovým kompromisům s růstem výpočetního výkonu (PoW se provádí pouze při vytváření nebo upgradu plotů)

## XOR-Transpose kódování

### Problém: 50% časově-paměťový kompromis

Ve formátech POC1/POC2 mohli útočníci zneužít matematický vztah mezi scoopy k uložení pouze poloviny dat a výpočtu zbytku za běhu během těžby. Tento "útok XOR kompresí" podkopával garanci úložiště.

### Řešení: XOR-Transpose zpevnění

PoCX odvozuje svůj těžební formát (X1) aplikací XOR-transpose kódování na páry základních warpů (X0):

**Pro konstrukci scoopu S nonce N ve warpu X1:**
1. Vezměte scoop S nonce N z prvního warpu X0 (přímá pozice)
2. Vezměte scoop N nonce S z druhého warpu X0 (transponovaná pozice)
3. XORujte dvě 64bajtové hodnoty pro získání scoopu X1

Krok transpozice zamění indexy scoopu a nonce. V maticových termínech — kde řádky reprezentují scoopy a sloupce reprezentují nonces — kombinuje prvek na pozici (S, N) v prvním warpu s prvkem na (N, S) ve druhém.

### Proč to eliminuje útok

XOR-transpose propojuje každý scoop s celým řádkem a celým sloupcem podkladových dat X0. Obnova jediného scoopu X1 vyžaduje přístup k datům pokrývajícím všech 4096 indexů scoopů. Jakýkoliv pokus o výpočet chybějících dat by vyžadoval regeneraci 4096 kompletních nonces místo jediného nonce — odstraňuje asymetrickou nákladovou strukturu zneužívanou útokem XOR.

V důsledku toho se ukládání kompletního warpu X1 stává jedinou výpočetně životaschopnou strategií pro těžaře.

## Struktura metadat v názvu souboru

Všechna metadata plotu jsou zakódována v názvu souboru pomocí tohoto přesného formátu:

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Komponenty názvu souboru

1. **ACCOUNT_PAYLOAD** (40 hex znaků)
   - Surový 20bajtový payload účtu jako velká hex písmena
   - Nezávislý na síti (bez network ID nebo checksum)
   - Příklad: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED** (64 hex znaků)
   - 32bajtová hodnota seed jako malá hex písmena
   - **Novinka v PoCX**: Náhodný 32bajtový seed v názvu souboru nahrazuje po sobě jdoucí číslování nonce — zabraňuje překrývání plotů
   - Příklad: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS** (desetinné číslo)
   - **NOVÁ jednotka velikosti v PoCX**: Nahrazuje velikost založenou na nonces z POC1/POC2
   - **Design odolný vůči XOR-transpose**: Každý warp = přesně 4096 nonces (velikost oddílu vyžadovaná pro transformaci odolnou vůči XOR-transpose)
   - **Velikost**: 1 warp = 1073741824 bajtů = 1 GiB (pohodlná jednotka)
   - Příklad: `1024` (1 TiB plot = 1024 warpů)

4. **SCALING** (desetinné číslo s předponou X)
   - Úroveň škálování jako `X{úroveň}`
   - Vyšší hodnoty = více požadovaného proof-of-work
   - Příklad: `X4` (2^4 = 16× obtížnost POC2)

### Příklady názvů souborů
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Rozložení souboru a datová struktura

### Hierarchická organizace
```
Plot soubor (BEZ HLAVIČKY)
├── Scoop 0
│   ├── Warp 0 (Všechny nonces pro tento scoop/warp)
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

### Konstanty a velikosti

| Konstanta       | Velikost                | Popis                                           |
| --------------- | ----------------------- | ----------------------------------------------- |
| **HASH\_SIZE**  | 32 B                   | Jeden výstup hashe Shabal256                    |
| **SCOOP\_SIZE** | 64 B (2 × HASH\_SIZE)  | Pár hashů čtený v kole těžby                    |
| **NUM\_SCOOPS** | 4096 (2¹²)             | Scoopů na nonce; jeden vybrán za kolo           |
| **NONCE\_SIZE** | 262144 B (256 KiB)     | Všechny scoopy nonce (nejmenší jednotka PoC1/PoC2) |
| **WARP\_SIZE**  | 1073741824 B (1 GiB)   | Nejmenší jednotka v PoCX                        |

### Rozložení plot souboru optimalizované pro SIMD

PoCX implementuje vzor přístupu k nonces s vědomím SIMD, který umožňuje vektorizované zpracování
více nonces současně. Staví na konceptech z [výzkumu optimalizace POC2×16](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) pro maximalizaci propustnosti paměti a efektivity SIMD.

---

#### Tradiční sekvenční rozložení

Sekvenční ukládání nonces:

```
[Nonce 0: Data scoopu] [Nonce 1: Data scoopu] [Nonce 2: Data scoopu] ...
```

Neefektivita SIMD: Každá dráha SIMD potřebuje stejné slovo napříč nonces:

```
Slovo 0 z Nonce 0 -> offset 0
Slovo 0 z Nonce 1 -> offset 512
Slovo 0 z Nonce 2 -> offset 1024
...
```

Scatter-gather přístup snižuje propustnost.

---

#### Rozložení PoCX optimalizované pro SIMD

PoCX ukládá **pozice slov napříč 16 nonces** souvisle:

```
Cache line (64 bajtů):

Word0_N0 Word0_N1 Word0_N2 ... Word0_N15
Word1_N0 Word1_N1 Word1_N2 ... Word1_N15
...
```

**ASCII diagram**

```
Tradiční rozložení:

Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

Rozložení PoCX:

Word0: [N0][N1][N2][N3]...[N15]
Word1: [N0][N1][N2][N3]...[N15]
Word2: [N0][N1][N2][N3]...[N15]
```

---

#### Výhody přístupu k paměti

- Jedna cache line dodává všechny dráhy SIMD.
- Eliminuje scatter-gather operace.
- Snižuje cache misses.
- Plně sekvenční přístup k paměti pro vektorizovaný výpočet.
- GPU také těží ze zarovnání na 16 nonces, maximalizuje efektivitu cache.

---

#### Škálování SIMD

| SIMD       | Šířka vektoru* | Nonces | Cykly zpracování na cache line |
|------------|----------------|--------|---------------------------------|
| SSE2/AVX   | 128bitů        | 4      | 4 cykly                         |
| AVX2       | 256bitů        | 8      | 2 cykly                         |
| AVX512     | 512bitů        | 16     | 1 cyklus                        |

\* Pro celočíselné operace

---



## Škálování proof-of-work

### Úrovně škálování
- **X0**: Základní nonces bez XOR-transpose kódování (teoretické, nepoužívá se pro těžbu)
- **X1**: XOR-transpose baseline — první zpevněný formát (1× práce)
- **X2**: 2× práce X1 (XOR napříč 2 warpy)
- **X3**: 4× práce X1 (XOR napříč 4 warpy)
- **…**
- **Xn**: 2^(n-1) × práce X1 vloženo

### Výhody
- **Nastavitelná obtížnost PoW**: Zvyšuje výpočetní požadavky, aby držela krok s rychlejším hardwarem
- **Dlouhověkost formátu**: Umožňuje flexibilní škálování obtížnosti těžby v čase

### Upgrade plotu / zpětná kompatibilita

Když síť zvýší měřítko PoW (Proof of Work) o 1, existující ploty vyžadují upgrade pro udržení stejné efektivní velikosti plotu. V podstatě nyní potřebujete dvojnásobek PoW ve vašich plot souborech pro dosažení stejného příspěvku k vašemu účtu.

Dobrá zpráva je, že PoW, které jste již dokončili při vytváření plot souborů, není ztraceno — jednoduše potřebujete přidat další PoW k existujícím souborům. Není třeba přeplotovat.

Alternativně můžete pokračovat v používání vašich aktuálních plotů bez upgradu, ale uvědomte si, že nyní přispějí pouze 50% jejich předchozí efektivní velikosti k vašemu účtu. Váš těžební software může plotfile škálovat za běhu.

## Srovnání s legacy formáty

| Funkce | POC1 | POC2 | PoCX |
|--------|------|------|------|
| Distribuce PoW | ❌ Chybná | ✅ Opravena | ✅ Opravena |
| Odolnost vůči XOR-Transpose | ❌ Zranitelný | ❌ Zranitelný | ✅ Opraveno |
| Optimalizace SIMD | ❌ Žádná | ❌ Žádná | ✅ Pokročilá |
| Optimalizace GPU | ❌ Žádná | ❌ Žádná | ✅ Optimalizováno |
| Škálovatelný proof-of-work | ❌ Žádný | ❌ Žádný | ✅ Ano |
| Podpora seed | ❌ Žádná | ❌ Žádná | ✅ Ano |

Formát PoCX reprezentuje současný stav techniky ve formátech plotů Proof of Capacity, řeší všechny známé zranitelnosti a poskytuje významná vylepšení výkonu pro moderní hardware.

## Reference a další čtení

- **Pozadí POC1/POC2**: [Přehled těžby Burstcoin](https://www.burstcoin.community/burstcoin-mining/) - Komplexní průvodce tradičními formáty těžby Proof of Capacity
- **Výzkum POC2×16**: [CIP oznámení: POC2×16 - Nový optimalizovaný formát plotů](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Původní výzkum optimalizace SIMD, který inspiroval PoCX
- **Hashovací algoritmus Shabal**: [Projekt Saphir: Shabal, příspěvek do soutěže NIST o kryptografický hashovací algoritmus](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Technická specifikace algoritmu Shabal256 používaného při těžbě PoC

---

[← Předchozí: Úvod](1-introduction.md) | [Obsah](index.md) | [Další: Konsenzus a těžba →](3-consensus-and-mining.md)
