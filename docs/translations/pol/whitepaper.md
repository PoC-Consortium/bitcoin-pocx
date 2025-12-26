# Bitcoin-PoCX: Energooszczędny konsensus dla Bitcoin Core

**Wersja**: 2.0 Wersja robocza
**Data**: Grudzień 2025
**Organizacja**: Proof of Capacity Consortium

---

## Streszczenie

Konsensus Proof-of-Work (PoW) Bitcoina zapewnia solidne bezpieczeństwo, ale zużywa znaczną ilość energii ze względu na ciągłe obliczenia haszów w czasie rzeczywistym. Prezentujemy Bitcoin-PoCX, fork Bitcoina, który zastępuje PoW mechanizmem Proof of Capacity (PoC), gdzie górnicy wstępnie obliczają i przechowują duże zbiory haszy na dysku podczas plottingu, a następnie wydobywają poprzez lekkie wyszukiwania zamiast ciągłego haszowania. Przenosząc obliczenia z fazy wydobycia do jednorazowej fazy plottingu, Bitcoin-PoCX drastycznie redukuje zużycie energii, jednocześnie umożliwiając wydobycie na sprzęcie konsumenckim, obniżając barierę uczestnictwa i łagodząc presje centralizacyjne nieodłączne od PoW zdominowanego przez ASIC, zachowując przy tym założenia bezpieczeństwa i zachowanie ekonomiczne Bitcoina.

Nasza implementacja wprowadza kilka kluczowych innowacji:
(1) Zahartowany format plot, który eliminuje wszystkie znane ataki kompromisu czas–pamięć w istniejących systemach PoC, zapewniając że efektywna moc wydobywcza pozostaje ściśle proporcjonalna do zadeklarowanej pojemności pamięci;
(2) Algorytm Time-Bending, który transformuje rozkłady deadline'ów z wykładniczego do chi-kwadrat, redukując wariancję czasu bloku bez zmiany średniej;
(3) Mechanizm przydziału kucia oparty na OP_RETURN umożliwiający wydobycie w puli bez powiernictwa; oraz
(4) Dynamiczne skalowanie kompresji, które zwiększa trudność generowania plotów w zgodności z harmonogramami halvingu, aby utrzymać długoterminowe marginesy bezpieczeństwa w miarę poprawy sprzętu.

Bitcoin-PoCX zachowuje architekturę Bitcoin Core poprzez minimalne, oznaczone flagami modyfikacje, izolując logikę PoC od istniejącego kodu konsensusu. System zachowuje politykę monetarną Bitcoina, celując w 120-sekundowy interwał bloków i dostosowując dotację blokową do 10 BTC. Zmniejszona dotacja kompensuje pięciokrotny wzrost częstotliwości bloków, utrzymując długoterminową stopę emisji zgodną z oryginalnym harmonogramem Bitcoina i zachowując maksymalną podaż ~21 milionów.

---

## 1. Wprowadzenie

### 1.1 Motywacja

Konsensus Proof-of-Work (PoW) Bitcoina okazał się bezpieczny przez ponad dekadę, ale przy znacznych kosztach: górnicy muszą nieustannie wydatkować zasoby obliczeniowe, co skutkuje wysokim zużyciem energii. Poza kwestiami efektywności istnieje szersza motywacja: eksploracja alternatywnych mechanizmów konsensusu, które utrzymują bezpieczeństwo przy jednoczesnym obniżeniu bariery uczestnictwa. PoC umożliwia praktycznie każdemu posiadaczowi konsumenckiego sprzętu pamięciowego efektywne wydobycie, redukując presje centralizacyjne obserwowane w wydobyciu PoW zdominowanym przez ASIC.

Proof of Capacity (PoC) osiąga to, wywodząc moc wydobywczą z zaangażowania pamięci zamiast ciągłych obliczeń. Górnicy wstępnie obliczają duże zbiory haszy przechowywanych na dysku — ploty — podczas jednorazowej fazy plottingu. Wydobycie polega następnie na lekkich wyszukiwaniach, drastycznie redukując zużycie energii przy zachowaniu założeń bezpieczeństwa konsensusu opartego na zasobach.

### 1.2 Integracja z Bitcoin Core

Bitcoin-PoCX integruje konsensus PoC w Bitcoin Core zamiast tworzyć nowy blockchain. To podejście wykorzystuje sprawdzone bezpieczeństwo Bitcoin Core, dojrzały stos sieciowy i powszechnie przyjęte narzędzia, zachowując minimalne i oznaczone flagami modyfikacje. Logika PoC jest izolowana od istniejącego kodu konsensusu, zapewniając że podstawowa funkcjonalność — walidacja bloków, operacje portfela, formaty transakcji — pozostaje w dużej mierze niezmieniona.

### 1.3 Cele projektowe

**Bezpieczeństwo**: Zachowanie solidności równoważnej Bitcoinowi; ataki wymagają większościowej pojemności pamięci.

**Efektywność**: Redukcja ciągłego obciążenia obliczeniowego do poziomu I/O dysku.

**Dostępność**: Umożliwienie wydobycia na sprzęcie konsumenckim, obniżenie barier wejścia.

**Minimalna integracja**: Wprowadzenie konsensusu PoC z minimalnym footprintem modyfikacji.

---

## 2. Tło: Proof of Capacity

### 2.1 Historia

Proof of Capacity (PoC) został wprowadzony przez Burstcoin w 2014 roku jako energooszczędna alternatywa dla Proof-of-Work (PoW). Burstcoin udowodnił, że moc wydobywcza może być wywodzona z zadeklarowanej pamięci zamiast ciągłego haszowania w czasie rzeczywistym: górnicy wstępnie obliczali duże zbiory danych ("ploty") raz, a następnie wydobywali poprzez odczytywanie małych, stałych porcji z nich.

Wczesne implementacje PoC udowodniły wykonalność koncepcji, ale również ujawniły, że format plotu i struktura kryptograficzna są krytyczne dla bezpieczeństwa. Kilka kompromisów czas–pamięć pozwalało atakującym wydobywać efektywnie z mniejszą ilością pamięci niż uczciwi uczestnicy. To uwidoczniło, że bezpieczeństwo PoC zależy od projektu plotu — nie tylko od używania pamięci jako zasobu.

Dziedzictwo Burstcoina ustanowiło PoC jako praktyczny mechanizm konsensusu i zapewniło fundament, na którym buduje PoCX.

### 2.2 Podstawowe koncepcje

Wydobycie PoC opiera się na dużych, wstępnie obliczonych plikach plot przechowywanych na dysku. Te ploty zawierają "zamrożone obliczenia": kosztowne haszowanie wykonywane jest raz podczas plottingu, a wydobycie polega na lekkich odczytach dysku i prostej weryfikacji. Podstawowe elementy obejmują:

**Nonce:**
Podstawowa jednostka danych plotu. Każdy nonce zawiera 4096 scoopów (łącznie 256 KiB) wygenerowanych przez Shabal256 z adresu górnika i indeksu nonce'a.

**Scoop:**
64-bajtowy segment wewnątrz nonce'a. Dla każdego bloku sieć deterministycznie wybiera indeks scoopa (0–4095) na podstawie sygnatury generacji poprzedniego bloku. Tylko ten scoop na nonce musi być odczytany.

**Sygnatura generacji:**
256-bitowa wartość wywodzona z poprzedniego bloku. Zapewnia entropię do wyboru scoopa i uniemożliwia górnikom przewidywanie przyszłych indeksów scoopów.

**Warp:**
Strukturalna grupa 4096 nonce'ów (1 GiB). Warpy są odpowiednią jednostką dla formatów plot odpornych na kompresję.

### 2.3 Proces wydobycia i potok jakości

Wydobycie PoC składa się z jednorazowego kroku plottingu i lekkiej procedury przy każdym bloku:

**Jednorazowa konfiguracja:**
- Generowanie plotu: Obliczenie nonce'ów przez Shabal256 i zapis na dysk.

**Wydobycie przy każdym bloku:**
- Wybór scoopa: Określenie indeksu scoopa z sygnatury generacji.
- Skanowanie plotu: Odczyt tego scoopa ze wszystkich nonce'ów w plotach górnika.

**Potok jakości:**
- Surowa jakość: Zahaszowanie każdego scoopa z sygnaturą generacji używając Shabal256Lite w celu uzyskania 64-bitowej wartości jakości (niższa jest lepsza).
- Deadline: Konwersja jakości na deadline używając base target (parametr dostosowany do trudności zapewniający że sieć osiąga docelowy interwał bloków): `deadline = quality / base_target`
- Zgięty deadline: Zastosowanie transformacji Time-Bending w celu redukcji wariancji przy zachowaniu oczekiwanego czasu bloku.

**Kucie bloku:**
Górnik z najkrótszym (zgiętym) deadline'em kuje następny blok gdy ten czas upłynie.

W przeciwieństwie do PoW, niemal wszystkie obliczenia dzieją się podczas plottingu; aktywne wydobycie jest głównie ograniczone przez dysk i bardzo niskoenergetyczne.

### 2.4 Znane podatności w poprzednich systemach

**Błąd rozkładu POC1:**
Oryginalny format POC1 Burstcoina wykazywał strukturalną stronniczość: scoopy o niskich indeksach były znacznie tańsze do przeliczenia w locie niż scoopy o wysokich indeksach. To wprowadzało niejednolity kompromis czas–pamięć, pozwalając atakującym zmniejszyć wymaganą pamięć dla tych scoopów i łamiąc założenie, że wszystkie wstępnie obliczone dane były równie kosztowne.

**Atak kompresji XOR (POC2):**
W POC2 atakujący może wziąć dowolny zbiór 8192 nonce'ów i podzielić je na dwa bloki po 4096 nonce'ów (A i B). Zamiast przechowywać oba bloki, atakujący przechowuje tylko strukturę pochodną: `A ⊕ transpose(B)`, gdzie transpozycja zamienia indeksy scoopów i nonce'ów — scoop S nonce'a N w bloku B staje się scoopem N nonce'a S.

Podczas wydobycia, gdy potrzebny jest scoop S nonce'a N, atakujący rekonstruuje go przez:
1. Odczyt zapisanej wartości XOR na pozycji (S, N)
2. Obliczenie nonce'a N z bloku A w celu uzyskania scoopa S
3. Obliczenie nonce'a S z bloku B w celu uzyskania transponowanego scoopa N
4. XOR wszystkich trzech wartości w celu odzyskania oryginalnego 64-bajtowego scoopa

To redukuje pamięć o 50%, wymagając tylko dwóch obliczeń nonce'ów na wyszukiwanie — koszt znacznie poniżej progu potrzebnego do wymuszenia pełnego wstępnego obliczenia. Atak jest wykonalny ponieważ obliczenie wiersza (jeden nonce, 4096 scoopów) jest niedrogie, podczas gdy obliczenie kolumny (pojedynczy scoop przez 4096 nonce'ów) wymagałoby regeneracji wszystkich nonce'ów. Struktura transpozycji ujawnia tę nierównowagę.

To pokazało potrzebę formatu plotu, który zapobiega takim strukturalnym rekombinacjom i usuwa podstawowy kompromis czas–pamięć. Sekcja 3.3 opisuje jak PoCX adresuje i rozwiązuje tę słabość.

### 2.5 Przejście do PoCX

Ograniczenia wcześniejszych systemów PoC jasno pokazały, że bezpieczne, uczciwe i zdecentralizowane wydobycie pamięciowe zależy od starannie zaprojektowanych struktur plotu. Bitcoin-PoCX adresuje te problemy zahartowanym formatem plotu, ulepszonym rozkładem deadline'ów i mechanizmami dla zdecentralizowanego wydobycia w puli — opisanymi w następnej sekcji.

---

## 3. Format plotu PoCX

### 3.1 Konstrukcja bazowego nonce'a

Nonce to struktura danych 256 KiB wywodzona deterministycznie z trzech parametrów: 20-bajtowego payloadu adresu, 32-bajtowego seeda i 64-bitowego indeksu nonce'a.

Konstrukcja rozpoczyna się od połączenia tych wejść i zahaszowania ich Shabal256 w celu uzyskania początkowego hasza. Ten hash służy jako punkt startowy dla iteracyjnego procesu rozszerzania: Shabal256 jest aplikowany wielokrotnie, z każdym krokiem zależnym od wcześniej wygenerowanych danych, aż cały 256 KiB bufor zostanie wypełniony. Ten łańcuchowy proces reprezentuje pracę obliczeniową wykonywaną podczas plottingu.

Końcowy krok dyfuzji haszuje ukończony bufor i wykonuje XOR wyniku przez wszystkie bajty. To zapewnia, że cały bufor został obliczony i że górnicy nie mogą skrócić obliczenia. Następnie aplikowany jest shuffle PoC2, zamieniający dolne i górne połówki każdego scoopa, aby zagwarantować że wszystkie scoopy wymagają równoważnego wysiłku obliczeniowego.

Końcowy nonce składa się z 4096 scoopów po 64 bajty każdy i stanowi podstawową jednostkę używaną w wydobyciu.

### 3.2 Układ plotu wyrównany do SIMD

Aby zmaksymalizować przepustowość na nowoczesnym sprzęcie, PoCX organizuje dane nonce'ów na dysku w celu ułatwienia przetwarzania wektorowego. Zamiast przechowywać każdy nonce sekwencyjnie, PoCX wyrównuje odpowiadające 4-bajtowe słowa z wielu kolejnych nonce'ów ciągle. To pozwala pojedynczemu pobraniu pamięci dostarczyć dane dla wszystkich pasów SIMD, minimalizując chybienia cache i eliminując narzut scatter-gather.

```
Tradycyjny układ:
Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

Układ SIMD PoCX:
Słowo0: [N0][N1][N2]...[N15]
Słowo1: [N0][N1][N2]...[N15]
Słowo2: [N0][N1][N2]...[N15]
```

Ten układ przynosi korzyści zarówno górnikom CPU jak i GPU, umożliwiając wysokoprzepustową, zrównolegloną ewaluację scoopów przy zachowaniu prostego skalarnego wzorca dostępu dla weryfikacji konsensusu. Zapewnia to, że wydobycie jest ograniczone przez przepustowość pamięci a nie obliczenia CPU, zachowując niskoenergetyczny charakter Proof of Capacity.

### 3.3 Struktura warpa i kodowanie XOR-Transpose

Warp to podstawowa jednostka pamięci w PoCX, składająca się z 4096 nonce'ów (1 GiB). Format nieskompresowany, nazywany X0, zawiera bazowe nonce'y dokładnie jak wytworzone przez konstrukcję w Sekcji 3.1.

**Kodowanie XOR-Transpose (X1)**

Aby usunąć strukturalne kompromisy czas–pamięć obecne we wcześniejszych systemach PoC, PoCX wywodzi zahartowany format wydobywczy, X1, poprzez zastosowanie kodowania XOR-transpose do par warpów X0.

Aby skonstruować scoop S nonce'a N w warpie X1:

1. Weź scoop S nonce'a N z pierwszego warpa X0 (bezpośrednia pozycja)
2. Weź scoop N nonce'a S z drugiego warpa X0 (pozycja transponowana)
3. Wykonaj XOR dwóch 64-bajtowych wartości, aby uzyskać scoop X1

Krok transpozycji zamienia indeksy scoopów i nonce'ów. W terminach macierzowych — gdzie wiersze reprezentują scoopy a kolumny nonce'y — łączy element na pozycji (S, N) w pierwszym warpie z elementem na pozycji (N, S) w drugim.

**Dlaczego to eliminuje powierzchnię ataku kompresji**

XOR-transpose zazębia każdy scoop z całym wierszem i całą kolumną bazowych danych X0. Odzyskanie pojedynczego scoopa X1 wymaga więc dostępu do danych obejmujących wszystkie 4096 indeksów scoopów. Każda próba obliczenia brakujących danych wymagałaby regeneracji 4096 pełnych nonce'ów, zamiast pojedynczego nonce'a — usuwając asymetryczną strukturę kosztów wykorzystywaną przez atak XOR dla POC2 (Sekcja 2.4).

W rezultacie przechowywanie pełnego warpa X1 staje się jedyną obliczeniowo opłacalną strategią dla górników, zamykając kompromis czas–pamięć wykorzystywany w poprzednich projektach.

### 3.4 Układ dyskowy

Pliki plot PoCX składają się z wielu kolejnych warpów X1. Aby zmaksymalizować efektywność operacyjną podczas wydobycia, dane w każdym pliku są organizowane według scoopa: wszystkie dane scoopa 0 ze wszystkich warpów są przechowywane sekwencyjnie, następnie wszystkie dane scoopa 1, i tak dalej, do scoopa 4095.

To **uporządkowanie sekwencyjne scoopów** pozwala górnikom odczytać kompletne dane wymagane dla wybranego scoopa w pojedynczym sekwencyjnym dostępie dyskowym, minimalizując czasy wyszukiwania i maksymalizując przepustowość na konsumenckich urządzeniach pamięciowych.

W połączeniu z kodowaniem XOR-transpose z Sekcji 3.3, ten układ zapewnia że plik jest zarówno **strukturalnie zahartowany** jak i **operacyjnie efektywny**: sekwencyjne uporządkowanie scoopów wspiera optymalne I/O dysku, podczas gdy układy pamięci wyrównane do SIMD (patrz Sekcja 3.2) umożliwiają wysokoprzepustową, zrównolegloną ewaluację scoopów.

### 3.5 Skalowanie proof-of-work (Xn)

PoCX implementuje skalowalne wstępne obliczenia poprzez koncepcję poziomów skalowania, oznaczanych Xn, aby adaptować się do ewoluującej wydajności sprzętu. Bazowy format X1 reprezentuje pierwszą zahartowaną strukturę warpa XOR-transpose.

Każdy poziom skalowania Xn zwiększa proof-of-work osadzony w każdym warpie wykładniczo względem X1: praca wymagana na poziomie Xn to 2^(n-1) razy praca X1. Przejście z Xn do Xn+1 jest operacyjnie równoważne zastosowaniu XOR przez pary sąsiednich warpów, stopniowo osadzając więcej proof-of-work bez zmiany podstawowego rozmiaru plotu.

Istniejące pliki plot utworzone na niższych poziomach skalowania nadal mogą być używane do wydobycia, ale wnoszą proporcjonalnie mniej pracy do generowania bloków, odzwierciedlając ich niższy osadzony proof-of-work. Ten mechanizm zapewnia, że ploty PoCX pozostają bezpieczne, elastyczne i ekonomicznie zbalansowane w czasie.

### 3.6 Funkcjonalność seeda

Parametr seed umożliwia wiele nienakładających się plotów na adres bez ręcznej koordynacji.

**Problem (POC2)**: Górnicy musieli ręcznie śledzić zakresy nonce'ów między plikami plot, aby uniknąć nakładania się. Nakładające się nonce'y marnują pamięć bez zwiększania mocy wydobywczej.

**Rozwiązanie**: Każda para `(adres, seed)` definiuje niezależną przestrzeń kluczy. Ploty z różnymi seedami nigdy się nie nakładają, niezależnie od zakresów nonce'ów. Górnicy mogą tworzyć ploty swobodnie bez koordynacji.

---

## 4. Konsensus Proof of Capacity

PoCX rozszerza konsensus Nakamoto Bitcoina o mechanizm dowodu związanego z pamięcią. Zamiast wydatkować energię na powtarzane haszowanie, górnicy angażują duże ilości wstępnie obliczonych danych — plotów — na dysk. Podczas generowania bloku muszą zlokalizować małą, nieprzewidywalną porcję tych danych i przekształcić ją w dowód. Górnik, który dostarczy najlepszy dowód w oczekiwanym oknie czasowym, zdobywa prawo do wykucia następnego bloku.

Ten rozdział opisuje jak PoCX strukturyzuje metadane bloków, wywodzi nieprzewidywalność i transformuje statyczną pamięć w bezpieczny mechanizm konsensusu o niskiej wariancji.

### 4.1 Struktura bloku

PoCX zachowuje znajomy nagłówek bloku w stylu Bitcoina, ale wprowadza dodatkowe pola konsensusu wymagane dla wydobycia opartego na pojemności. Te pola zbiorowo wiążą blok z przechowanym plotem górnika, trudnością sieci i entropią kryptograficzną definiującą każde wyzwanie wydobywcze.

Na wysokim poziomie blok PoCX zawiera: wysokość bloku, zapisaną jawnie dla uproszczenia walidacji kontekstowej; sygnaturę generacji, źródło świeżej entropii łączące każdy blok z jego poprzednikiem; base target, reprezentujący trudność sieci w formie odwrotnej (wyższe wartości odpowiadają łatwiejszemu wydobyciu); dowód PoCX, identyfikujący plot górnika, poziom kompresji użyty podczas plottingu, wybrany nonce i wywodzoną z niego jakość; oraz klucz podpisujący i sygnaturę, dowodzące kontroli nad pojemnością użytą do wykucia bloku (lub przydzielonego klucza kucia).

Dowód osadza wszystkie informacje istotne dla konsensusu potrzebne walidatorom do przeliczenia wyzwania, weryfikacji wybranego scoopa i potwierdzenia wynikowej jakości. Rozszerzając zamiast przeprojektowywać strukturę bloku, PoCX pozostaje koncepcyjnie wyrównany z Bitcoinem, jednocześnie umożliwiając fundamentalnie odmienne źródło pracy wydobywczej.

### 4.2 Łańcuch sygnatur generacji

Sygnatura generacji zapewnia nieprzewidywalność wymaganą dla bezpiecznego wydobycia Proof of Capacity. Każdy blok wywodzi swoją sygnaturę generacji z sygnatury i podpisującego poprzedniego bloku, zapewniając że górnicy nie mogą przewidywać przyszłych wyzwań ani wstępnie obliczać korzystnych regionów plotu:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

To produkuje sekwencję kryptograficznie silnych, zależnych od górnika wartości entropii. Ponieważ klucz publiczny górnika jest nieznany aż poprzedni blok zostanie opublikowany, żaden uczestnik nie może przewidzieć przyszłych wyborów scoopów. To zapobiega selektywnemu wstępnemu obliczaniu lub strategicznemu plottingowi i zapewnia że każdy blok wprowadza prawdziwie świeżą pracę wydobywczą.

### 4.3 Proces kucia

Wydobycie w PoCX polega na transformowaniu przechowanych danych w dowód kierowany całkowicie przez sygnaturę generacji. Chociaż proces jest deterministyczny, nieprzewidywalność sygnatury zapewnia że górnicy nie mogą się przygotować z wyprzedzeniem i muszą wielokrotnie uzyskiwać dostęp do swoich przechowanych plotów.

**Wywodzenie wyzwania (wybór scoopa):** Górnik haszuje aktualną sygnaturę generacji z wysokością bloku, aby uzyskać indeks scoopa w zakresie 0–4095. Ten indeks określa, który 64-bajtowy segment każdego przechowywanego nonce'a uczestniczy w dowodzie. Ponieważ sygnatura generacji zależy od podpisującego poprzedni blok, wybór scoopa staje się znany dopiero w momencie publikacji bloku.

**Ewaluacja dowodu (obliczenie jakości):** Dla każdego nonce'a w plotie, górnik pobiera wybrany scoop i haszuje go razem z sygnaturą generacji, aby uzyskać jakość — 64-bitową wartość, której wielkość określa konkurencyjność górnika. Niższa jakość odpowiada lepszemu dowodowi.

**Formowanie deadline'u (Time Bending):** Surowy deadline jest proporcjonalny do jakości i odwrotnie proporcjonalny do base target. W starszych projektach PoC te deadline'y podlegały silnie skośnemu rozkładowi wykładniczemu, produkując długie opóźnienia ogona, które nie zapewniały dodatkowego bezpieczeństwa. PoCX transformuje surowy deadline używając Time Bending (Sekcja 4.4), redukując wariancję i zapewniając przewidywalne interwały bloków. Gdy zgięty deadline upłynie, górnik kuje blok poprzez osadzenie dowodu i podpisanie go efektywnym kluczem kucia.

### 4.4 Time Bending

Proof of Capacity produkuje wykładniczo rozłożone deadline'y. Po krótkim okresie — typowo kilkadziesiąt sekund — każdy górnik już zidentyfikował swój najlepszy dowód, a jakikolwiek dodatkowy czas oczekiwania wnosi tylko opóźnienie, nie bezpieczeństwo.

Time Bending przekształca rozkład poprzez zastosowanie transformacji pierwiastka sześciennego:

`deadline_bended = skala × (quality / base_target)^(1/3)`

Współczynnik skali zachowuje oczekiwany czas bloku (120 sekund) przy jednoczesnej dramatycznej redukcji wariancji. Krótkie deadline'y są rozszerzane, poprawiając propagację bloków i bezpieczeństwo sieci. Długie deadline'y są kompresowane, zapobiegając wartościom odstającym od opóźniania łańcucha.

![Rozkłady czasów bloków](blocktime_distributions.svg)

Time Bending zachowuje zawartość informacyjną podstawowego dowodu. Nie modyfikuje konkurencyjności między górnikami; tylko realokuje czas oczekiwania, aby produkować gładsze, bardziej przewidywalne interwały bloków. Implementacja używa arytmetyki stałoprzecinkowej (format Q42) i liczb całkowitych 256-bitowych, aby zapewnić deterministyczne wyniki na wszystkich platformach.

### 4.5 Dostosowanie trudności

PoCX reguluje produkcję bloków używając base target, odwrotnej miary trudności. Oczekiwany czas bloku jest proporcjonalny do stosunku `quality / base_target`, więc zwiększenie base target przyspiesza tworzenie bloków, podczas gdy zmniejszenie go spowalnia łańcuch.

Trudność dostosowuje się przy każdym bloku używając zmierzonego czasu między ostatnimi blokami w porównaniu z docelowym interwałem. To częste dostosowanie jest konieczne ponieważ pojemność pamięci może być szybko dodawana lub usuwana — w przeciwieństwie do mocy haszującej Bitcoina, która zmienia się wolniej.

Dostosowanie podlega dwóm ograniczającym warunkom: **Stopniowość** — zmiany na blok są ograniczone (maksymalnie ±20%), aby uniknąć oscylacji lub manipulacji; **Hartowanie** — base target nie może przekroczyć swojej wartości genesis, uniemożliwiając sieci obniżenie trudności poniżej oryginalnych założeń bezpieczeństwa.

### 4.6 Ważność bloku

Blok w PoCX jest ważny gdy przedstawia weryfikowalny dowód wywiedziony z pamięci, spójny ze stanem konsensusu. Walidatorzy niezależnie przeliczają wybór scoopa, wywodzą oczekiwaną jakość z zgłoszonego nonce'a i metadanych plotu, aplikują transformację Time Bending i potwierdzają że górnik był uprawniony do wykucia bloku w zadeklarowanym czasie.

W szczególności ważny blok wymaga: deadline upłynął od bloku rodzica; zgłoszona jakość pasuje do obliczonej jakości dla dowodu; poziom skalowania spełnia minimum sieciowe; sygnatura generacji pasuje do oczekiwanej wartości; base target pasuje do oczekiwanej wartości; sygnatura bloku pochodzi od efektywnego podpisującego; a coinbase płaci na adres efektywnego podpisującego.

---

## 5. Przydziały kucia

### 5.1 Motywacja

Przydziały kucia pozwalają właścicielom plotów delegować uprawnienia kucia bloków bez rezygnacji z własności swoich plotów. Ten mechanizm umożliwia wydobycie w puli i konfiguracje zimnego przechowywania przy zachowaniu gwarancji bezpieczeństwa PoCX.

W wydobyciu w puli właściciele plotów mogą autoryzować pulę do kucia bloków w ich imieniu. Pula składa bloki i dystrybuuje nagrody, ale nigdy nie uzyskuje powiernictwa nad samymi plotami. Delegacja jest odwracalna w dowolnym momencie, a właściciele plotów pozostają wolni do opuszczenia puli lub zmiany konfiguracji bez replottingu.

Przydziały wspierają również czyste rozdzielenie między zimnymi a gorącymi kluczami. Klucz prywatny kontrolujący plot może pozostać offline, podczas gdy oddzielny klucz kucia — przechowywany na maszynie online — produkuje bloki. Kompromitacja klucza kucia kompromituje więc tylko uprawnienia kucia, nie własność. Plot pozostaje bezpieczny, a przydział może być cofnięty, zamykając lukę bezpieczeństwa natychmiast.

Przydziały kucia zapewniają więc elastyczność operacyjną przy zachowaniu zasady, że kontrola nad przechowaną pojemnością nigdy nie może być przekazana pośrednikom.

### 5.2 Protokół przydziału

Przydziały są deklarowane poprzez transakcje OP_RETURN, aby uniknąć niepotrzebnego wzrostu zbioru UTXO. Transakcja przydziału określa adres plotu i adres kucia autoryzowany do produkowania bloków używając pojemności tego plotu. Transakcja cofnięcia zawiera tylko adres plotu. W obu przypadkach właściciel plotu dowodzi kontroli poprzez podpisanie wejścia wydającego transakcji.

Każdy przydział przechodzi przez sekwencję dobrze zdefiniowanych stanów (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Po potwierdzeniu transakcji przydziału system wchodzi w krótką fazę aktywacji. To opóźnienie — 30 bloków, w przybliżeniu jedna godzina — zapewnia stabilność podczas wyścigów bloków i zapobiega adversarialnym szybkim zmianom tożsamości kucia. Gdy ten okres aktywacji upłynie, przydział staje się aktywny i pozostaje tak do momentu gdy właściciel plotu wyda cofnięcie.

Cofnięcia przechodzą w dłuższy okres opóźnienia 720 bloków, w przybliżeniu jeden dzień. Podczas tego czasu poprzedni adres kucia pozostaje aktywny. To dłuższe opóźnienie zapewnia stabilność operacyjną dla pul, zapobiegając strategicznemu "przeskakiwaniu przydziałów" i dając dostawcom infrastruktury wystarczającą pewność do efektywnego działania. Po upływie opóźnienia cofnięcia, cofnięcie się kończy, a właściciel plotu może swobodnie wyznaczyć nowy klucz kucia.

Stan przydziału jest utrzymywany w strukturze warstwy konsensusu równoległej do zbioru UTXO i wspiera dane cofania dla bezpiecznej obsługi reorganizacji łańcucha.

### 5.3 Reguły walidacji

Dla każdego bloku walidatorzy określają efektywnego podpisującego — adres który musi podpisać blok i otrzymać nagrodę coinbase. Ten podpisujący zależy wyłącznie od stanu przydziału przy wysokości bloku.

Jeśli nie istnieje przydział lub przydział nie zakończył jeszcze fazy aktywacji, właściciel plotu pozostaje efektywnym podpisującym. Gdy przydział staje się aktywny, przydzielony adres kucia musi podpisywać. Podczas cofnięcia adres kucia kontynuuje podpisywanie do upływu opóźnienia cofnięcia. Dopiero wtedy uprawnienia wracają do właściciela plotu.

Walidatorzy wymuszają że sygnatura bloku jest wyprodukowana przez efektywnego podpisującego, że coinbase płaci na ten sam adres, i że wszystkie przejścia podlegają przepisanym opóźnieniom aktywacji i cofnięcia. Tylko właściciel plotu może tworzyć lub cofać przydziały; klucze kucia nie mogą modyfikować ani rozszerzać własnych uprawnień.

Przydziały kucia wprowadzają więc elastyczną delegację bez wprowadzania zaufania. Własność podstawowej pojemności zawsze pozostaje kryptograficznie zakotwiczona u właściciela plotu, podczas gdy uprawnienia kucia mogą być delegowane, rotowane lub cofane w miarę ewolucji potrzeb operacyjnych.

---

## 6. Dynamiczne skalowanie

W miarę ewolucji sprzętu koszt obliczania plotów maleje względem odczytu wstępnie obliczonej pracy z dysku. Bez środków zaradczych atakujący mogliby ostatecznie generować dowody w locie szybciej niż górnicy czytający przechowywaną pracę, podważając model bezpieczeństwa Proof of Capacity.

Aby zachować zamierzony margines bezpieczeństwa, PoCX implementuje harmonogram skalowania: minimalny wymagany poziom skalowania dla plotów rośnie w czasie. Każdy poziom skalowania Xn, jak opisano w Sekcji 3.5, osadza wykładniczo więcej proof-of-work w strukturze plotu, zapewniając że górnicy kontynuują angażowanie znacznych zasobów pamięciowych nawet gdy obliczenia stają się tańsze.

Harmonogram wyrównuje się z zachętami ekonomicznymi sieci, szczególnie halvingami nagród za blok. W miarę zmniejszania nagrody za blok, minimalny poziom stopniowo rośnie, zachowując równowagę między wysiłkiem plottingu a potencjałem wydobywczym:

| Okres | Lata | Halvingi | Min skalowanie | Mnożnik pracy plotu |
|-------|------|----------|----------------|---------------------|
| Epoka 0 | 0-4 | 0 | X1 | 2× bazowy |
| Epoka 1 | 4-12 | 1-2 | X2 | 4× bazowy |
| Epoka 2 | 12-28 | 3-6 | X3 | 8× bazowy |
| Epoka 3 | 28-60 | 7-14 | X4 | 16× bazowy |
| Epoka 4 | 60-124 | 15-30 | X5 | 32× bazowy |
| Epoka 5 | 124+ | 31+ | X6 | 64× bazowy |

Górnicy mogą opcjonalnie przygotować ploty przekraczające aktualne minimum o jeden poziom, pozwalając im planować z wyprzedzeniem i unikać natychmiastowych aktualizacji gdy sieć przechodzi do następnej epoki. Ten opcjonalny krok nie daje dodatkowej przewagi pod względem prawdopodobieństwa bloku — jedynie pozwala na płynniejsze przejście operacyjne.

Bloki zawierające dowody poniżej minimalnego poziomu skalowania dla ich wysokości są uważane za nieprawidłowe. Walidatorzy sprawdzają zadeklarowany poziom skalowania w dowodzie względem aktualnego wymagania sieci podczas walidacji konsensusu, zapewniając że wszyscy uczestniczący górnicy spełniają ewoluujące oczekiwania bezpieczeństwa.

---

## 7. Architektura wydobycia

PoCX rozdziela operacje krytyczne dla konsensusu od zasobochłonnych zadań wydobycia, umożliwiając zarówno bezpieczeństwo jak i efektywność. Węzeł utrzymuje blockchain, waliduje bloki, zarządza mempoolem i udostępnia interfejs RPC. Zewnętrzni górnicy obsługują przechowywanie plotów, odczytywanie scoopów, obliczanie jakości i zarządzanie deadline'ami. To rozdzielenie utrzymuje logikę konsensusu prostą i audytowalną, pozwalając górnikom optymalizować przepustowość dysku.

### 7.1 Interfejs RPC wydobycia

Górnicy interagują z węzłem przez minimalny zestaw wywołań RPC. RPC get_mining_info dostarcza aktualną wysokość bloku, sygnaturę generacji, base target, docelowy deadline i akceptowalny zakres poziomów skalowania plotu. Używając tych informacji, górnicy obliczają kandydujące nonce'y. RPC submit_nonce pozwala górnikom zgłosić proponowane rozwiązanie, zawierające identyfikator plotu, indeks nonce'a, poziom skalowania i konto górnika. Węzeł ewaluuje zgłoszenie i odpowiada obliczonym deadline'em jeśli dowód jest prawidłowy.

### 7.2 Harmonogram kucia

Węzeł utrzymuje harmonogram kucia, który śledzi przychodzące zgłoszenia i zachowuje tylko najlepsze rozwiązanie dla każdej wysokości bloku. Zgłoszone nonce'y są kolejkowane z wbudowanymi zabezpieczeniami przed zalewaniem zgłoszeniami lub atakami denial-of-service. Harmonogram czeka aż obliczony deadline upłynie lub pojawi się lepsze rozwiązanie, po czym składa blok, podpisuje go używając efektywnego klucza kucia i publikuje do sieci.

### 7.3 Kucie obronne

Aby zapobiec atakom czasowym lub zachętom do manipulacji zegarem, PoCX implementuje kucie obronne. Jeśli konkurencyjny blok pojawi się dla tej samej wysokości, harmonogram porównuje lokalne rozwiązanie z nowym blokiem. Jeśli lokalna jakość jest lepsza, węzeł kuje natychmiast zamiast czekać na oryginalny deadline. To zapewnia że górnicy nie mogą zyskać przewagi jedynie przez dostosowanie lokalnych zegarów; najlepsze rozwiązanie zawsze wygrywa, zachowując uczciwość i bezpieczeństwo sieci.

---

## 8. Analiza bezpieczeństwa

### 8.1 Model zagrożeń

PoCX modeluje przeciwników ze znacznymi ale ograniczonymi możliwościami. Atakujący mogą próbować przeciążyć sieć nieprawidłowymi transakcjami, zniekształconymi blokami lub sfabrykowanymi dowodami, aby testować ścieżki walidacji. Mogą swobodnie manipulować swoimi lokalnymi zegarami i mogą próbować wykorzystywać przypadki brzegowe w zachowaniu konsensusu, takie jak obsługa znaczników czasu, dynamika dostosowania trudności czy reguły reorganizacji. Oczekuje się również że przeciwnicy będą szukać możliwości przepisywania historii poprzez ukierunkowane forki łańcucha.

Model zakłada że żadna pojedyncza strona nie kontroluje większości całkowitej pojemności pamięci sieci. Jak w przypadku każdego mechanizmu konsensusu opartego na zasobach, atakujący z 51% pojemnością może jednostronnie reorganizować łańcuch; to fundamentalne ograniczenie nie jest specyficzne dla PoCX. PoCX zakłada również że atakujący nie mogą obliczać danych plotu szybciej niż uczciwi górnicy mogą je czytać z dysku. Harmonogram skalowania (Sekcja 6) zapewnia że luka obliczeniowa wymagana dla bezpieczeństwa rośnie w czasie w miarę poprawy sprzętu.

Poniższe sekcje badają każdą główną klasę ataków szczegółowo i opisują środki zaradcze wbudowane w PoCX.

### 8.2 Ataki pojemnościowe

Podobnie jak PoW, atakujący z większościową pojemnością może przepisywać historię (atak 51%). Osiągnięcie tego wymaga pozyskania fizycznego footprintu pamięci większego niż uczciwa sieć — kosztowne i logistycznie wymagające przedsięwzięcie. Gdy sprzęt jest pozyskany, koszty operacyjne są niskie, ale początkowa inwestycja tworzy silną zachętę ekonomiczną do uczciwego zachowania: podważenie łańcucha uszkodziłoby wartość własnej bazy aktywów atakującego.

PoC unika również problemu nothing-at-stake związanego z PoS. Chociaż górnicy mogą skanować ploty względem wielu konkurujących forków, każdy skan zużywa realny czas — typowo rzędu dziesiątek sekund na łańcuch. Przy 120-sekundowym interwale bloków, to z natury ogranicza wydobycie wieloforkowe, a próba wydobywania wielu forków jednocześnie degraduje wydajność na wszystkich. Wydobycie forków nie jest więc bezkosztowe; jest fundamentalnie ograniczone przez przepustowość I/O.

Nawet jeśli przyszły sprzęt pozwalałby na niemal natychmiastowe skanowanie plotów (np. wysokowydajne SSD), atakujący nadal stanąłby przed znacznym wymogiem fizycznych zasobów do kontrolowania większości pojemności sieci, czyniąc atak w stylu 51% kosztownym i logistycznie wymagającym.

Na koniec, ataki pojemnościowe są znacznie trudniejsze do wynajęcia niż ataki mocą haszującą. Moc obliczeniową GPU można pozyskać na żądanie i natychmiast przekierować na dowolny łańcuch PoW. W przeciwieństwie do tego, PoC wymaga fizycznego sprzętu, czasochłonnego plottingu i ciągłych operacji I/O. Te ograniczenia czynią krótkoterminowe, oportunistyczne ataki znacznie mniej wykonalnymi.

### 8.3 Ataki czasowe

Czas odgrywa bardziej krytyczną rolę w Proof of Capacity niż w Proof of Work. W PoW znaczniki czasu wpływają głównie na dostosowanie trudności; w PoC określają czy deadline górnika upłynął i tym samym czy blok jest kwalifikowany do kucia. Deadline'y są mierzone względem znacznika czasu bloku rodzica, ale lokalny zegar węzła jest używany do oceny czy przychodzący blok leży zbyt daleko w przyszłości. Z tego powodu PoCX wymusza ścisłą tolerancję znaczników czasu: bloki nie mogą odbiegać więcej niż 15 sekund od lokalnego zegara węzła (w porównaniu z 2-godzinnym oknem Bitcoina). Ten limit działa w obu kierunkach — bloki zbyt daleko w przyszłości są odrzucane, a węzły z wolnymi zegarami mogą nieprawidłowo odrzucać ważne przychodzące bloki.

Węzły powinny więc synchronizować swoje zegary używając NTP lub równoważnego źródła czasu. PoCX celowo unika polegania na wewnętrznych źródłach czasu sieci, aby uniemożliwić atakującym manipulowanie postrzeganym czasem sieci. Węzły monitorują własny dryf i emitują ostrzeżenia jeśli lokalny zegar zaczyna odbiegać od ostatnich znaczników czasu bloków.

Przyspieszanie zegara — uruchamianie szybkiego lokalnego zegara do nieco wcześniejszego kucia — zapewnia tylko marginalną korzyść. W granicach dozwolonej tolerancji, kucie obronne (Sekcja 7.3) zapewnia że górnik z lepszym rozwiązaniem natychmiast opublikuje przy zobaczeniu gorszego wczesnego bloku. Szybki zegar pomaga górnikom publikować już wygrywające rozwiązanie kilka sekund wcześniej; nie może przekształcić gorszego dowodu w wygrywający.

Próby manipulowania trudnością przez znaczniki czasu są ograniczone przez ±20% limit dostosowania na blok i 24-blokowe okno kroczące, uniemożliwiając górnikom znaczące wpływanie na trudność przez krótkoterminowe gry czasowe.

### 8.4 Ataki kompromisu czas–pamięć

Kompromisy czas–pamięć próbują zmniejszyć wymagania pamięciowe poprzez przeliczanie części plotu na żądanie. Poprzednie systemy Proof of Capacity były podatne na takie ataki, najbardziej zauważalnie błąd nierównowagi scoopów POC1 i atak kompresji XOR-transpose POC2 (Sekcja 2.4). Oba wykorzystywały asymetrie w kosztowności regeneracji pewnych porcji danych plotu, pozwalając przeciwnikom ciąć pamięć płacąc tylko niewielką karę obliczeniową. Również alternatywne formaty plot do PoC2 cierpią na podobne słabości TMTO; prominentnym przykładem jest Chia, której format plotu może być arbitralnie zredukowany o czynnik większy niż 4.

PoCX usuwa te powierzchnie ataku całkowicie poprzez swoją konstrukcję nonce'a i format warpa. W każdym nonce'u końcowy krok dyfuzji haszuje w pełni obliczony bufor i wykonuje XOR wyniku przez wszystkie bajty, zapewniając że każda część bufora zależy od każdej innej części i nie może być skrócona. Następnie shuffle PoC2 zamienia dolne i górne połówki każdego scoopa, wyrównując koszt obliczeniowy odzyskania dowolnego scoopa.

PoCX dalej eliminuje atak kompresji XOR–transpose POC2 poprzez wywodzenie zahartowanego formatu X1, gdzie każdy scoop to XOR bezpośredniej i transponowanej pozycji przez sparowane warpy; to zazębia każdy scoop z całym wierszem i całą kolumną bazowych danych X0, czyniąc rekonstrukcję wymagającą tysięcy pełnych nonce'ów i tym samym usuwając asymetryczny kompromis czas–pamięć całkowicie.

W rezultacie przechowywanie pełnego plotu jest jedyną obliczeniowo opłacalną strategią dla górników. Żaden znany skrót — czy to częściowe plottowanie, selektywna regeneracja, strukturalna kompresja czy hybrydowe podejścia obliczeniowo-pamięciowe — nie zapewnia znaczącej przewagi. PoCX zapewnia że wydobycie pozostaje ściśle związane z pamięcią i że pojemność odzwierciedla realne, fizyczne zaangażowanie.

### 8.5 Ataki przydziałowe

PoCX używa deterministycznej maszyny stanów do zarządzania wszystkimi przydziałami plot-do-kowalki. Każdy przydział przechodzi przez dobrze zdefiniowane stany — UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED — z wymuszonymi opóźnieniami aktywacji i cofnięcia. To zapewnia że górnik nie może natychmiastowo zmieniać przydziałów, aby oszukiwać system lub szybko zmieniać uprawnienia kucia.

Ponieważ wszystkie przejścia wymagają dowodów kryptograficznych — konkretnie, sygnatur właściciela plotu weryfikowalnych względem wejściowego UTXO — sieć może ufać legalności każdego przydziału. Próby ominięcia maszyny stanów lub sfałszowania przydziałów są automatycznie odrzucane podczas walidacji konsensusu. Ataki typu replay są również zapobiegane przez standardowe zabezpieczenia Bitcoina przed replay transakcji, zapewniając że każda akcja przydziału jest unikalnie powiązana z prawidłowym, niewydanym wejściem.

Kombinacja zarządzania maszyną stanów, wymuszonych opóźnień i dowodu kryptograficznego czyni oszustwa oparte na przydziałach praktycznie niemożliwymi: górnicy nie mogą przejmować przydziałów, wykonywać szybkich zmian przydziałów podczas wyścigów bloków ani omijać harmonogramów cofnięcia.

### 8.6 Bezpieczeństwo sygnatur

Sygnatury bloków w PoCX służą jako krytyczne ogniwo między dowodem a efektywnym kluczem kucia, zapewniając że tylko autoryzowani górnicy mogą produkować ważne bloki.

Aby zapobiec atakom plastyczności, sygnatury są wyłączone z obliczenia hasza bloku. To eliminuje ryzyka plastycznych sygnatur, które mogłyby podważać walidację lub umożliwiać ataki zastępowania bloków.

Aby łagodzić wektory denial-of-service, rozmiary sygnatur i kluczy publicznych są stałe — 65 bajtów dla kompaktowych sygnatur i 33 bajty dla skompresowanych kluczy publicznych — uniemożliwiając atakującym nadymanie bloków w celu wywołania wyczerpania zasobów lub spowolnienia propagacji sieciowej.

---

## 9. Implementacja

PoCX jest zaimplementowany jako modułowe rozszerzenie Bitcoin Core, z całym odpowiednim kodem zawartym w dedykowanym podkatalogu i aktywowanym poprzez flagę funkcji. Ten projekt zachowuje integralność oryginalnego kodu, pozwalając włączać lub wyłączać PoCX czysto, co upraszcza testowanie, audytowanie i pozostawanie w synchronizacji ze zmianami upstream.

Integracja dotyka tylko niezbędnych punktów koniecznych do wsparcia Proof of Capacity. Nagłówek bloku został rozszerzony o pola specyficzne dla PoCX, a walidacja konsensusu została zaadaptowana do przetwarzania dowodów opartych na pamięci obok tradycyjnych sprawdzeń Bitcoina. System kucia, odpowiedzialny za zarządzanie deadline'ami, planowanie i zgłoszenia górników, jest w pełni zawarty w modułach PoCX, podczas gdy rozszerzenia RPC udostępniają funkcjonalność wydobycia i przydziałów zewnętrznym klientom. Dla użytkowników interfejs portfela został wzbogacony o zarządzanie przydziałami poprzez transakcje OP_RETURN, umożliwiając bezproblemową interakcję z nowymi funkcjami konsensusu.

Wszystkie operacje krytyczne dla konsensusu są zaimplementowane w deterministycznym C++ bez zewnętrznych zależności, zapewniając spójność międzyplatformową. Shabal256 jest używany do haszowania, podczas gdy Time Bending i obliczanie jakości opierają się na arytmetyce stałoprzecinkowej i operacjach 256-bitowych. Operacje kryptograficzne takie jak weryfikacja sygnatur wykorzystują istniejącą bibliotekę secp256k1 Bitcoin Core.

Izolując funkcjonalność PoCX w ten sposób, implementacja pozostaje audytowalna, łatwa w utrzymaniu i w pełni kompatybilna z ciągłym rozwojem Bitcoin Core, demonstrując że fundamentalnie nowy mechanizm konsensusu związany z pamięcią może współistnieć z dojrzałą bazą kodu proof-of-work bez zakłócania jej integralności czy użyteczności.

---

## 10. Parametry sieci

PoCX buduje na infrastrukturze sieciowej Bitcoina i wykorzystuje jego framework parametrów łańcucha. Aby wspierać wydobycie oparte na pojemności, obsługę przydziałów i skalowanie plotów, kilka parametrów zostało rozszerzonych lub nadpisanych. Obejmuje to docelowy czas bloku, początkową dotację, harmonogram halvingu, opóźnienia aktywacji i cofnięcia przydziałów, a także identyfikatory sieci takie jak bajty magiczne, porty i prefiksy Bech32. Środowiska testnet i regtest dalej dostosowują te parametry, aby umożliwić szybką iterację i testowanie niskiej pojemności.

Poniższe tabele podsumowują wynikowe ustawienia mainnet, testnet i regtest, podkreślając jak PoCX adaptuje podstawowe parametry Bitcoina do modelu konsensusu związanego z pamięcią.

### 10.1 Mainnet

| Parametr | Wartość |
|----------|---------|
| Bajty magiczne | `0xa7 0x3c 0x91 0x5e` |
| Domyślny port | 8888 |
| Bech32 HRP | `pocx` |
| Docelowy czas bloku | 120 sekund |
| Początkowa dotacja | 10 BTC |
| Interwał halvingu | 1050000 bloków (~4 lata) |
| Całkowita podaż | ~21 milionów BTC |
| Aktywacja przydziału | 30 bloków |
| Cofnięcie przydziału | 720 bloków |
| Okno kroczące | 24 bloki |

### 10.2 Testnet

| Parametr | Wartość |
|----------|---------|
| Bajty magiczne | `0x6d 0xf2 0x48 0xb3` |
| Domyślny port | 18888 |
| Bech32 HRP | `tpocx` |
| Docelowy czas bloku | 120 sekund |
| Inne parametry | Takie same jak mainnet |

### 10.3 Regtest

| Parametr | Wartość |
|----------|---------|
| Bajty magiczne | `0xfa 0xbf 0xb5 0xda` |
| Domyślny port | 18444 |
| Bech32 HRP | `rpocx` |
| Docelowy czas bloku | 1 sekunda |
| Interwał halvingu | 500 bloków |
| Aktywacja przydziału | 4 bloki |
| Cofnięcie przydziału | 8 bloków |
| Tryb niskiej pojemności | Włączony (~4 MB ploty) |

---

## 11. Powiązane prace

Przez lata kilka projektów blockchain i konsensusu eksplorowało modele wydobycia oparte na pamięci lub hybrydowe. PoCX buduje na tym dziedzictwie, wprowadzając ulepszenia w bezpieczeństwie, efektywności i kompatybilności.

**Burstcoin / Signum.** Burstcoin wprowadził pierwszy praktyczny system Proof-of-Capacity (PoC) w 2014 roku, definiując podstawowe koncepcje takie jak ploty, nonce'y, scoopy i wydobycie oparte na deadline'ach. Jego następcy, szczególnie Signum (dawniej Burstcoin), rozszerzyli ekosystem i ostatecznie ewoluowali w to, co jest znane jako Proof-of-Commitment (PoC+), łącząc zaangażowanie pamięci z opcjonalnym stakingiem, aby wpływać na efektywną pojemność. PoCX dziedziczy fundament wydobycia opartego na pamięci z tych projektów, ale znacząco odbiega poprzez zahartowany format plotu (kodowanie XOR-transpose), dynamiczne skalowanie pracy plotu, wygładzanie deadline'ów ("Time Bending") i elastyczny system przydziałów — wszystko to zakotwiczone w bazie kodu Bitcoin Core zamiast utrzymywania samodzielnego forka sieci.

**Chia.** Chia implementuje Proof of Space and Time, łącząc dowody pamięci oparte na dysku z komponentem czasowym wymuszanym przez Verifiable Delay Functions (VDF). Jej projekt adresuje pewne obawy dotyczące ponownego użycia dowodów i generowania świeżych wyzwań, odrębne od klasycznego PoC. PoCX nie adoptuje tego modelu dowodu zakotwiczonego w czasie; zamiast tego utrzymuje konsensus związany z pamięcią z przewidywalnymi interwałami, zoptymalizowany dla długoterminowej kompatybilności z ekonomią UTXO i narzędziami wywodzącymi się z Bitcoina.

**Spacemesh.** Spacemesh proponuje schemat Proof-of-Space-Time (PoST) używając topologii sieci opartej na DAG (mesh). W tym modelu uczestnicy muszą okresowo udowadniać że przydzielona pamięć pozostaje nienaruszona w czasie, zamiast polegać na pojedynczym wstępnie obliczonym zbiorze danych. PoCX, w przeciwieństwie, weryfikuje zaangażowanie pamięci tylko w czasie bloku — z zahartowanymi formatami plotu i rygorystyczną walidacją dowodów — unikając narzutu ciągłych dowodów pamięci przy zachowaniu efektywności i decentralizacji.

---

## 12. Wnioski

Bitcoin-PoCX demonstruje że energooszczędny konsensus może być zintegrowany z Bitcoin Core przy zachowaniu właściwości bezpieczeństwa i modelu ekonomicznego. Kluczowe wkłady obejmują kodowanie XOR-transpose (zmusza atakujących do obliczania 4096 nonce'ów na wyszukiwanie, eliminując atak kompresji), algorytm Time Bending (transformacja rozkładu redukuje wariancję czasu bloku), system przydziałów kucia (delegacja oparta na OP_RETURN umożliwia wydobycie w puli bez powiernictwa), dynamiczne skalowanie (wyrównane z halvingami dla zachowania marginesów bezpieczeństwa) oraz minimalną integrację (kod oznaczony flagą izolowany w dedykowanym katalogu).

System jest obecnie w fazie testnet. Moc wydobywcza wywodzi się z pojemności pamięci zamiast mocy haszującej, redukując zużycie energii o rzędy wielkości przy zachowaniu sprawdzonego modelu ekonomicznego Bitcoina.

---

## Odniesienia

Bitcoin Core. *Repozytorium Bitcoin Core.* https://github.com/bitcoin/bitcoin

Burstcoin. *Dokumentacja techniczna Proof of Capacity.* 2014.

NIST. *Konkurs SHA-3: Shabal.* 2008.

Cohen, B., Pietrzak, K. *Blockchain sieci Chia.* 2019.

Spacemesh. *Dokumentacja protokołu Spacemesh.* 2021.

PoC Consortium. *Framework PoCX.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Integracja Bitcoin-PoCX.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Licencja**: MIT
**Organizacja**: Proof of Capacity Consortium
**Status**: Faza testowa (Testnet)
