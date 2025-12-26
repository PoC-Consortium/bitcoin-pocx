[← Poprzedni: Wprowadzenie](1-introduction.md) | [Spis treści](index.md) | [Dalej: Konsensus i wydobycie →](3-consensus-and-mining.md)

---

# Rozdział 2: Specyfikacja formatu plot PoCX

Ten dokument opisuje format plot PoCX, ulepszoną wersję formatu POC2 z poprawionym bezpieczeństwem, optymalizacjami SIMD i skalowalnym proof-of-work.

## Przegląd formatu

Pliki plot PoCX zawierają wstępnie obliczone wartości haszów Shabal256 zorganizowane dla efektywnych operacji wydobywczych. Zgodnie z tradycją PoC od POC1, **wszystkie metadane są osadzone w nazwie pliku** — nie ma nagłówka pliku.

### Rozszerzenie pliku
- **Standardowe**: `.pocx` (ukończone ploty)
- **W trakcie**: `.tmp` (podczas plottingu, zmieniane na `.pocx` po ukończeniu)

## Kontekst historyczny i ewolucja podatności

### Format POC1 (starszy)
**Dwie główne podatności (kompromisy czas–pamięć):**

1. **Błąd rozkładu PoW**
   - Niejednolity rozkład proof-of-work pomiędzy scoopami
   - Niskie numery scoopów mogły być obliczane w locie
   - **Wpływ**: Zmniejszone wymagania pamięciowe dla atakujących

2. **Atak kompresji XOR** (50% kompromis czas–pamięć)
   - Wykorzystywał właściwości matematyczne do osiągnięcia 50% redukcji pamięci
   - **Wpływ**: Atakujący mogli wydobywać z połową wymaganej pamięci

**Optymalizacja układu**: Podstawowy sekwencyjny układ scoopów dla wydajności HDD

### Format POC2 (Burstcoin)
- ✅ **Naprawiony błąd rozkładu PoW**
- ❌ **Podatność XOR-transpose pozostała niezałatana**
- **Układ**: Zachowana optymalizacja sekwencyjnych scoopów

### Format PoCX (aktualny)
- ✅ **Naprawiony rozkład PoW** (odziedziczone z POC2)
- ✅ **Załatana podatność XOR-transpose** (unikalna dla PoCX)
- ✅ **Ulepszony układ SIMD/GPU** zoptymalizowany dla przetwarzania równoległego i koalescencji pamięci
- ✅ **Skalowalny proof-of-work** zapobiega kompromisom czas–pamięć wraz ze wzrostem mocy obliczeniowej (PoW jest wykonywany tylko podczas tworzenia lub uaktualniania plików plot)

## Kodowanie XOR-Transpose

### Problem: 50% kompromis czas–pamięć

W formatach POC1/POC2 atakujący mogli wykorzystać matematyczną zależność między scoopami, aby przechowywać tylko połowę danych i obliczać resztę w locie podczas wydobycia. Ten "atak kompresji XOR" podważał gwarancję pamięci.

### Rozwiązanie: Hartowanie XOR-Transpose

PoCX wywodzi swój format wydobywczy (X1) poprzez zastosowanie kodowania XOR-transpose do par bazowych warpów (X0):

**Aby skonstruować scoop S nonce'a N w warpie X1:**
1. Weź scoop S nonce'a N z pierwszego warpa X0 (bezpośrednia pozycja)
2. Weź scoop N nonce'a S z drugiego warpa X0 (pozycja transponowana)
3. Wykonaj XOR dwóch 64-bajtowych wartości, aby uzyskać scoop X1

Krok transpozycji zamienia indeksy scoopów i nonce'ów. W terminach macierzowych — gdzie wiersze reprezentują scoopy, a kolumny nonce'y — łączy element na pozycji (S, N) w pierwszym warpie z elementem na pozycji (N, S) w drugim.

### Dlaczego to eliminuje atak

XOR-transpose zazębia każdy scoop z całym wierszem i całą kolumną bazowych danych X0. Odzyskanie pojedynczego scoopa X1 wymaga więc dostępu do danych obejmujących wszystkie 4096 indeksów scoopów. Każda próba obliczenia brakujących danych wymagałaby regeneracji 4096 pełnych nonce'ów zamiast pojedynczego nonce'a — usuwając asymetryczną strukturę kosztów wykorzystywaną przez atak XOR.

W rezultacie przechowywanie pełnego warpa X1 staje się jedyną obliczeniowo opłacalną strategią dla górników.

## Struktura metadanych nazwy pliku

Wszystkie metadane plotu są zakodowane w nazwie pliku przy użyciu tego dokładnego formatu:

```
{ACCOUNT_PAYLOAD}_{SEED}_{WARPS}_{SCALING}.pocx
```

### Składniki nazwy pliku

1. **ACCOUNT_PAYLOAD** (40 znaków hex)
   - Surowy 20-bajtowy payload konta jako wielkie litery hex
   - Niezależny od sieci (bez ID sieci ani sumy kontrolnej)
   - Przykład: `DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD`

2. **SEED** (64 znaki hex)
   - 32-bajtowa wartość seed jako małe litery hex
   - **Nowość w PoCX**: Losowy 32-bajtowy seed w nazwie pliku zastępuje kolejne numerowanie nonce'ów — zapobiegając nakładaniu się plotów
   - Przykład: `c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea`

3. **WARPS** (liczba dziesiętna)
   - **NOWA jednostka rozmiaru w PoCX**: Zastępuje rozmiar oparty na nonce'ach z POC1/POC2
   - **Projekt odporny na XOR-transpose**: Każdy warp = dokładnie 4096 nonce'ów (rozmiar partycji wymagany dla transformacji odpornej na XOR-transpose)
   - **Rozmiar**: 1 warp = 1073741824 bajtów = 1 GiB (wygodna jednostka)
   - Przykład: `1024` (1 TiB plot = 1024 warpy)

4. **SCALING** (dziesiętna z prefiksem X)
   - Poziom skalowania jako `X{poziom}`
   - Wyższe wartości = więcej wymaganego proof-of-work
   - Przykład: `X4` (2^4 = 16× trudność POC2)

### Przykładowe nazwy plików
```
DEADBEEFCAFEBABE1337C0DEBADC0FFEE15DEAD_c0ffeebeefcafebabedeadbeef1337c0de42424242feedfacecafed00dabad1dea_1024_X4.pocx
FEEDFACEDEADC0DE123456789ABCDEF012345678_b00b1e5feedc0debabeface5dea1deadc0de1337c0ffeebabeface5bad1dea5_2048_X1.pocx
```


## Układ pliku i struktura danych

### Organizacja hierarchiczna
```
Plik plot (BEZ NAGŁÓWKA)
├── Scoop 0
│   ├── Warp 0 (wszystkie nonce'y dla tego scoopa/warpa)
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

### Stałe i rozmiary

| Stała          | Rozmiar                   | Opis                                            |
| -------------- | ------------------------- | ----------------------------------------------- |
| **HASH\_SIZE** | 32 B                      | Pojedyncze wyjście hasza Shabal256              |
| **SCOOP\_SIZE**| 64 B (2 × HASH\_SIZE)     | Para haszy czytana w rundzie wydobycia          |
| **NUM\_SCOOPS**| 4096 (2¹²)                | Scoopy na nonce; jeden wybierany na rundę       |
| **NONCE\_SIZE**| 262144 B (256 KiB)        | Wszystkie scoopy nonce'a (najmniejsza jednostka PoC1/PoC2) |
| **WARP\_SIZE** | 1073741824 B (1 GiB)      | Najmniejsza jednostka w PoCX                    |

### Układ pliku plot zoptymalizowany pod SIMD

PoCX implementuje wzorzec dostępu do nonce'ów świadomy SIMD, który umożliwia wektoryzowane przetwarzanie wielu nonce'ów jednocześnie. Bazuje na koncepcjach z [badań optymalizacji POC2×16](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/), aby zmaksymalizować przepustowość pamięci i wydajność SIMD.

---

#### Tradycyjny układ sekwencyjny

Sekwencyjne przechowywanie nonce'ów:

```
[Nonce 0: Dane scoopa] [Nonce 1: Dane scoopa] [Nonce 2: Dane scoopa] ...
```

Nieefektywność SIMD: Każdy pas SIMD potrzebuje tego samego słowa z różnych nonce'ów:

```
Słowo 0 z Nonce 0 -> offset 0
Słowo 0 z Nonce 1 -> offset 512
Słowo 0 z Nonce 2 -> offset 1024
...
```

Dostęp scatter-gather zmniejsza przepustowość.

---

#### Układ PoCX zoptymalizowany pod SIMD

PoCX przechowuje **pozycje słów z 16 nonce'ów** ciągle:

```
Linia cache (64 bajty):

Słowo0_N0 Słowo0_N1 Słowo0_N2 ... Słowo0_N15
Słowo1_N0 Słowo1_N1 Słowo1_N2 ... Słowo1_N15
...
```

**Diagram ASCII**

```
Tradycyjny układ:

Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

Układ PoCX:

Słowo0: [N0][N1][N2][N3]...[N15]
Słowo1: [N0][N1][N2][N3]...[N15]
Słowo2: [N0][N1][N2][N3]...[N15]
```

---

#### Korzyści dostępu do pamięci

- Jedna linia cache zasila wszystkie pasy SIMD.
- Eliminuje operacje scatter-gather.
- Redukuje chybienia cache.
- W pełni sekwencyjny dostęp do pamięci dla wektoryzowanych obliczeń.
- GPU również zyskują na wyrównaniu do 16 nonce'ów, maksymalizując wydajność cache.

---

#### Skalowanie SIMD

| SIMD       | Szerokość wektora* | Nonce'y | Cykle przetwarzania na linię cache |
|------------|--------------------|---------|------------------------------------|
| SSE2/AVX   | 128-bit            | 4       | 4 cykle                            |
| AVX2       | 256-bit            | 8       | 2 cykle                            |
| AVX512     | 512-bit            | 16      | 1 cykl                             |

\* Dla operacji na liczbach całkowitych

---



## Skalowanie proof-of-work

### Poziomy skalowania
- **X0**: Bazowe nonce'y bez kodowania XOR-transpose (teoretyczne, nieużywane do wydobycia)
- **X1**: Bazowy XOR-transpose — pierwszy zahartowany format (1× praca)
- **X2**: 2× praca X1 (XOR z 2 warpów)
- **X3**: 4× praca X1 (XOR z 4 warpów)
- **...**
- **Xn**: 2^(n-1) × praca X1 osadzona

### Korzyści
- **Regulowana trudność PoW**: Zwiększa wymagania obliczeniowe, aby nadążyć za szybszym sprzętem
- **Długowieczność formatu**: Umożliwia elastyczne skalowanie trudności wydobycia w czasie

### Uaktualnianie plotu / kompatybilność wsteczna

Gdy sieć zwiększa skalę PoW (Proof of Work) o 1, istniejące ploty wymagają uaktualnienia, aby zachować ten sam efektywny rozmiar plotu. Zasadniczo potrzebujesz teraz dwa razy więcej PoW w plikach plot, aby osiągnąć ten sam wkład do swojego konta.

Dobra wiadomość jest taka, że PoW, który już wykonałeś podczas tworzenia plików plot, nie jest utracony — musisz po prostu dodać dodatkowy PoW do istniejących plików. Nie ma potrzeby replotowania.

Alternatywnie możesz kontynuować używanie swoich obecnych plotów bez uaktualniania, ale pamiętaj, że teraz będą one wnosić tylko 50% poprzedniego efektywnego rozmiaru do twojego konta. Twoje oprogramowanie wydobywcze może skalować plik plot w locie.

## Porównanie z formatami starszymi

| Cecha | POC1 | POC2 | PoCX |
|-------|------|------|------|
| Rozkład PoW | ❌ Wadliwy | ✅ Naprawiony | ✅ Naprawiony |
| Odporność XOR-Transpose | ❌ Podatny | ❌ Podatny | ✅ Naprawiony |
| Optymalizacja SIMD | ❌ Brak | ❌ Brak | ✅ Zaawansowana |
| Optymalizacja GPU | ❌ Brak | ❌ Brak | ✅ Zoptymalizowana |
| Skalowalny proof-of-work | ❌ Brak | ❌ Brak | ✅ Tak |
| Wsparcie seed | ❌ Brak | ❌ Brak | ✅ Tak |

Format PoCX reprezentuje aktualny stan sztuki w formatach plot Proof of Capacity, adresując wszystkie znane podatności, jednocześnie zapewniając znaczące ulepszenia wydajności dla nowoczesnego sprzętu.

## Odniesienia i dalsza lektura

- **Tło POC1/POC2**: [Przegląd wydobycia Burstcoin](https://www.burstcoin.community/burstcoin-mining/) - Kompleksowy przewodnik po tradycyjnych formatach wydobycia Proof of Capacity
- **Badania POC2×16**: [Ogłoszenie CIP: POC2×16 - Nowy zoptymalizowany format plot](https://www.reddit.com/r/burstcoin/comments/a1qyoq/cip_announcement_poc2x16_a_new_optimized_plot/) - Oryginalne badania optymalizacji SIMD, które zainspirowały PoCX
- **Algorytm haszowania Shabal**: [Projekt Saphir: Shabal, zgłoszenie do konkursu algorytmów haszujących NIST](https://www.cs.rit.edu/~ark/20090927/Round2Candidates/Shabal.pdf) - Specyfikacja techniczna algorytmu Shabal256 używanego w wydobyciu PoC

---

[← Poprzedni: Wprowadzenie](1-introduction.md) | [Spis treści](index.md) | [Dalej: Konsensus i wydobycie →](3-consensus-and-mining.md)
