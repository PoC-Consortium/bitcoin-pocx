# Bitcoin-PoCX: Energeticky úsporný konsenzus pro Bitcoin Core

**Verze**: 2.0 Draft
**Datum**: Prosinec 2025
**Organizace**: Proof of Capacity Consortium

---

## Abstrakt

Konsenzus Proof-of-Work (PoW) Bitcoinu poskytuje robustní bezpečnost, ale spotřebovává značné množství energie kvůli nepřetržitému výpočtu hashů v reálném čase. Představujeme Bitcoin-PoCX, fork Bitcoinu, který nahrazuje PoW systémem Proof of Capacity (PoC), kde těžaři předpočítávají a ukládají velké sady hashů uložených na disku během plottování a následně těží prováděním lehkých vyhledávání místo průběžného hashování. Přesunutím výpočtu z fáze těžby do jednorázové fáze plottování Bitcoin-PoCX drasticky snižuje spotřebu energie a zároveň umožňuje těžbu na běžném hardwaru, čímž snižuje bariéru pro účast a zmírňuje centralizační tlaky inherentní v PoW dominovaném ASIC, to vše při zachování bezpečnostních předpokladů a ekonomického chování Bitcoinu.

Naše implementace zavádí několik klíčových inovací:
(1) Zpevněný formát plotů, který eliminuje všechny známé útoky časově-paměťovými kompromisy v existujících PoC systémech, čímž zajišťuje, že efektivní těžební výkon zůstává striktně úměrný vázané úložné kapacitě;
(2) Algoritmus Time-Bending, který transformuje distribuce deadlinů z exponenciální na chí-kvadrát, čímž snižuje varianci času bloků bez změny průměru;
(3) Mechanismus forging přiřazení založený na OP_RETURN umožňující non-custodial poolovou těžbu; a
(4) Dynamické škálování komprese, které zvyšuje obtížnost generování plotů v souladu s harmonogramy halvingů pro udržení dlouhodobých bezpečnostních marží s tím, jak se hardware zlepšuje.

Bitcoin-PoCX zachovává architekturu Bitcoin Core prostřednictvím minimálních, feature-flagovaných modifikací, izolujících logiku PoC od existujícího konsensuálního kódu. Systém zachovává měnovou politiku Bitcoinu cílením na 120sekundový interval bloků a úpravou subsidy bloků na 10 BTC. Snížená subsidy kompenzuje pětinásobné zvýšení frekvence bloků, udržujíc dlouhodobou míru emise v souladu s původním harmonogramem Bitcoinu a udržujíc maximální nabídku ~21 milionů.

---

## 1. Úvod

### 1.1 Motivace

Konsenzus Proof-of-Work (PoW) Bitcoinu se osvědčil jako bezpečný po více než deset let, ale za významných nákladů: těžaři musí nepřetržitě vynakládat výpočetní zdroje, což vede k vysoké spotřebě energie. Nad rámec obav o efektivitu existuje širší motivace: prozkoumávání alternativních konsensuálních mechanismů, které udržují bezpečnost při snižování bariéry pro účast. PoC umožňuje prakticky komukoli s běžným úložným hardwarem efektivně těžit, čímž snižuje centralizační tlaky pozorované u těžby PoW dominované ASIC.

Proof of Capacity (PoC) toho dosahuje odvozením těžebního výkonu z vázaného úložiště místo průběžného výpočtu. Těžaři předpočítávají velké sady hashů uložených na disku — ploty — během jednorázové fáze plottování. Těžba pak spočívá v lehkých vyhledáváních, čímž drasticky snižuje spotřebu energie při zachování bezpečnostních předpokladů konsenzu založeného na zdrojích.

### 1.2 Integrace s Bitcoin Core

Bitcoin-PoCX integruje konsenzus PoC do Bitcoin Core místo vytváření nového blockchainu. Tento přístup využívá osvědčenou bezpečnost Bitcoin Core, vyspělý síťový stack a široce přijímané nástroje, přičemž udržuje modifikace minimální a feature-flagované. Logika PoC je izolována od existujícího konsensuálního kódu, čímž zajišťuje, že základní funkcionalita — validace bloků, operace peněženky, formáty transakcí — zůstává z velké části nezměněna.

### 1.3 Designové cíle

**Bezpečnost**: Zachovat robustnost ekvivalentní Bitcoinu; útoky vyžadují většinovou úložnou kapacitu.

**Efektivita**: Snížit průběžné výpočetní zatížení na úroveň diskových I/O.

**Přístupnost**: Umožnit těžbu s běžným hardwarem, snížit bariéry vstupu.

**Minimální integrace**: Zavést konsenzus PoC s minimálním modifikačním otiskem.

---

## 2. Pozadí: Proof of Capacity

### 2.1 Historie

Proof of Capacity (PoC) byl představen Burstcoinem v roce 2014 jako energeticky úsporná alternativa k Proof-of-Work (PoW). Burstcoin demonstroval, že těžební výkon může být odvozen z vázaného úložiště místo nepřetržitého hashování v reálném čase: těžaři předpočítali velké datasety ("ploty") jednou a poté těžili čtením jejich malých, fixních částí.

Rané implementace PoC dokázaly životaschopnost konceptu, ale také odhalily, že formát plotů a kryptografická struktura jsou kritické pro bezpečnost. Několik časově-paměťových kompromisů umožnilo útočníkům těžit efektivně s menším úložištěm než poctiví účastníci. To zdůraznilo, že bezpečnost PoC závisí na návrhu plotů — nejen na používání úložiště jako zdroje.

Dědictví Burstcoinu etablovalo PoC jako praktický konsensuální mechanismus a poskytlo základ, na kterém PoCX staví.

### 2.2 Základní koncepty

Těžba PoC je založena na velkých, předpočítaných plot souborech uložených na disku. Tyto ploty obsahují "zmrazený výpočet": nákladné hashování se provádí jednou během plottování a těžba pak spočívá v lehkých čteních z disku a jednoduché verifikaci. Základní prvky zahrnují:

**Nonce:**
Základní jednotka dat plotu. Každá nonce obsahuje 4096 scoopů (celkem 256 KiB) generovaných pomocí Shabal256 z adresy těžaře a indexu nonce.

**Scoop:**
64bajtový segment uvnitř nonce. Pro každý blok síť deterministicky vybírá index scoopu (0–4095) na základě generačního podpisu předchozího bloku. Pouze tento scoop na nonce musí být přečten.

**Generační podpis:**
256bitová hodnota odvozená z předchozího bloku. Poskytuje entropii pro výběr scoopu a zabraňuje těžařům předpovídat budoucí indexy scoopů.

**Warp:**
Strukturní skupina 4096 nonces (1 GiB). Warpy jsou relevantní jednotkou pro formáty plotů odolné vůči kompresi.

### 2.3 Proces těžby a pipeline kvality

Těžba PoC se skládá z jednorázového kroku plottování a lehké rutiny per-blok:

**Jednorázové nastavení:**
- Generování plotu: Výpočet nonces pomocí Shabal256 a jejich zápis na disk.

**Těžba per-blok:**
- Výběr scoopu: Určení indexu scoopu z generačního podpisu.
- Skenování plotu: Čtení tohoto scoopu ze všech nonces v plotech těžaře.

**Pipeline kvality:**
- Surová kvalita: Hash každého scoopu s generačním podpisem pomocí Shabal256Lite pro získání 64bitové hodnoty kvality (nižší je lepší).
- Deadline: Převod kvality na deadline pomocí base target (parametr upravený na obtížnost zajišťující, že síť dosáhne cílového intervalu bloků): `deadline = quality / base_target`
- Bended deadline: Aplikace transformace Time-Bending pro snížení variance při zachování očekávaného času bloku.

**Forging bloku:**
Těžař s nejkratším (bended) deadline vytvoří další blok, jakmile tento čas uplyne.

Na rozdíl od PoW téměř veškerý výpočet probíhá během plottování; aktivní těžba je primárně vázána na disk a má velmi nízkou spotřebu.

### 2.4 Známé zranitelnosti v předchozích systémech

**Chyba distribuce POC1:**
Původní formát Burstcoin POC1 vykazoval strukturální zaujatost: scoopy s nízkými indexy bylo výrazně levnější přepočítávat za běhu než scoopy s vysokými indexy. To zavádělo nerovnoměrný časově-paměťový kompromis, umožňující útočníkům snížit požadované úložiště pro tyto scoopy a narušovat předpoklad, že všechna předpočítaná data byla stejně nákladná.

**Útok XOR kompresí (POC2):**
V POC2 může útočník vzít libovolnou sadu 8192 nonces a rozdělit je do dvou bloků po 4096 nonces (A a B). Místo ukládání obou bloků útočník ukládá pouze odvozenou strukturu: `A ⊕ transpose(B)`, kde transpozice zamění indexy scoopů a nonces — scoop S nonce N v bloku B se stává scoopem N nonce S.

Během těžby, když je potřeba scoop S nonce N, útočník ho rekonstruuje:
1. Přečtením uložené XOR hodnoty na pozici (S, N)
2. Výpočtem nonce N z bloku A pro získání scoopu S
3. Výpočtem nonce S z bloku B pro získání transponovaného scoopu N
4. XORováním všech tří hodnot pro obnovu původního 64bajtového scoopu

Toto snižuje úložiště o 50%, přičemž vyžaduje pouze dva výpočty nonces na vyhledávání — náklady daleko pod prahem potřebným pro vynucení úplného předpočítání. Útok je životaschopný, protože výpočet řádku (jedna nonce, 4096 scoopů) je levný, zatímco výpočet sloupce (jeden scoop napříč 4096 nonces) by vyžadoval regeneraci všech nonces. Transpoziční struktura odhaluje tuto nerovnováhu.

Toto demonstrovalo potřebu formátu plotů, který zabraňuje takové strukturované rekombinaci a odstraňuje základní časově-paměťový kompromis. Sekce 3.3 popisuje, jak PoCX řeší a vyřešuje tuto slabinu.

### 2.5 Přechod k PoCX

Omezení dřívějších systémů PoC jasně ukázala, že bezpečná, spravedlivá a decentralizovaná úložná těžba závisí na pečlivě navržených strukturách plotů. Bitcoin-PoCX řeší tyto problémy se zpevněným formátem plotů, vylepšenou distribucí deadlinů a mechanismy pro decentralizovanou poolovou těžbu — popsanými v další sekci.

---

## 3. Formát plotů PoCX

### 3.1 Základní konstrukce nonce

Nonce je 256 KiB datová struktura odvozená deterministicky ze tří parametrů: 20bajtového payloadu adresy, 32bajtového seedu a 64bitového indexu nonce.

Konstrukce začíná kombinací těchto vstupů a jejich hashováním pomocí Shabal256 pro vytvoření počátečního hashe. Tento hash slouží jako výchozí bod pro iterativní expanzní proces: Shabal256 je aplikován opakovaně, přičemž každý krok závisí na dříve vygenerovaných datech, dokud není vyplněn celý 256 KiB buffer. Tento řetězený proces reprezentuje výpočetní práci prováděnou během plottování.

Finální difúzní krok hashuje dokončený buffer a XORuje výsledek napříč všemi bajty. Toto zajišťuje, že celý buffer byl vypočítán a těžaři nemohou zkrátit výpočet. Poté je aplikován POC2 shuffle, který zamění dolní a horní poloviny každého scoopu, aby garantoval, že všechny scoopy vyžadují ekvivalentní výpočetní úsilí.

Výsledná nonce se skládá z 4096 scoopů po 64 bajtech každý a tvoří základní jednotku používanou při těžbě.

### 3.2 Rozložení plotů zarovnané na SIMD

Pro maximalizaci propustnosti na moderním hardwaru PoCX organizuje data nonces na disku pro usnadnění vektorizovaného zpracování. Místo sekvenčního ukládání každé nonce PoCX zarovnává odpovídající 4bajtová slova napříč více po sobě jdoucími nonces souvisle. To umožňuje jednomu paměťovému načtení poskytnout data pro všechny SIMD dráhy, minimalizujíc cache misses a eliminujíc scatter-gather overhead.

```
Tradiční rozložení:
Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

Rozložení PoCX SIMD:
Word0: [N0][N1][N2]...[N15]
Word1: [N0][N1][N2]...[N15]
Word2: [N0][N1][N2]...[N15]
```

Toto rozložení prospívá jak CPU, tak GPU těžařům, umožňujíc vysokopropustné, paralelizované vyhodnocování scoopů při zachování jednoduchého skalárního přístupového vzoru pro validaci konsenzu. Zajišťuje, že těžba je omezena šířkou pásma úložiště spíše než výpočtem CPU, udržujíc nízkospotřební povahu Proof of Capacity.

### 3.3 Struktura warpu a XOR-transpose kódování

Warp je základní úložnou jednotkou v PoCX, skládající se z 4096 nonces (1 GiB). Nekomprimovaný formát, označovaný jako X0, obsahuje základní nonces přesně tak, jak jsou produkovány konstrukcí v sekci 3.1.

**XOR-Transpose kódování (X1)**

Pro odstranění strukturálních časově-paměťových kompromisů přítomných v dřívějších systémech PoC, PoCX odvozuje zpevněný těžební formát, X1, aplikací XOR-transpose kódování na páry warpů X0.

Pro konstrukci scoopu S nonce N ve warpu X1:

1. Vezměte scoop S nonce N z prvního warpu X0 (přímá pozice)
2. Vezměte scoop N nonce S z druhého warpu X0 (transponovaná pozice)
3. XORujte dvě 64bajtové hodnoty pro získání scoopu X1

Krok transpozice zamění indexy scoopů a nonces. V maticových termínech — kde řádky reprezentují scoopy a sloupce reprezentují nonces — kombinuje prvek na pozici (S, N) v prvním warpu s prvkem na (N, S) ve druhém.

**Proč to eliminuje plochu kompresního útoku**

XOR-transpose propojuje každý scoop s celým řádkem a celým sloupcem základních dat X0. Obnova jediného scoopu X1 proto vyžaduje přístup k datům pokrývajícím všech 4096 indexů scoopů. Jakýkoliv pokus o výpočet chybějících dat by vyžadoval regeneraci 4096 kompletních nonces, místo jediné nonce — odstraňujíc asymetrickou nákladovou strukturu zneužívanou útokem XOR pro POC2 (sekce 2.4).

V důsledku toho se ukládání kompletního warpu X1 stává jedinou výpočetně životaschopnou strategií pro těžaře, uzavírajíc časově-paměťový kompromis zneužívaný v předchozích návrzích.

### 3.4 Diskové rozložení

Plot soubory PoCX sestávají z mnoha po sobě jdoucích warpů X1. Pro maximalizaci provozní efektivity během těžby jsou data v každém souboru organizována podle scoopů: všechna data scoopu 0 z každého warpu jsou uložena sekvenčně, následována všemi daty scoopu 1 a tak dále až po scoop 4095.

Toto **sekvenční uspořádání scoopů** umožňuje těžařům přečíst kompletní data požadovaná pro vybraný scoop v jediném sekvenčním diskovém přístupu, minimalizujíc časy vystavení hlavy a maximalizujíc propustnost na běžných úložných zařízeních.

V kombinaci s XOR-transpose kódováním ze sekce 3.3 toto rozložení zajišťuje, že soubor je jak **strukturálně zpevněný**, tak **provozně efektivní**: sekvenční uspořádání scoopů podporuje optimální diskové I/O, zatímco paměťová rozložení zarovnaná na SIMD (viz sekce 3.2) umožňují vysokopropustné, paralelizované vyhodnocování scoopů.

### 3.5 Škálování proof-of-work (Xn)

PoCX implementuje škálovatelné předpočítání prostřednictvím konceptu úrovní škálování, označovaných Xn, pro přizpůsobení se vyvíjejícímu výkonu hardwaru. Baseline formát X1 reprezentuje první strukturu warpu zpevněnou XOR-transpose.

Každá úroveň škálování Xn exponenciálně zvyšuje proof-of-work vložený do každého warpu relativně k X1: práce vyžadovaná na úrovni Xn je 2^(n-1)krát práce X1. Přechod z Xn na Xn+1 je provozně ekvivalentní aplikaci XOR napříč páry sousedních warpů, postupně vkládajíc více proof-of-work bez změny základní velikosti plotu.

Existující plot soubory vytvořené na nižších úrovních škálování mohou být stále používány pro těžbu, ale přispívají proporcionálně méně práce k generování bloků, odrážejíc jejich nižší vložený proof-of-work. Tento mechanismus zajišťuje, že ploty PoCX zůstávají bezpečné, flexibilní a ekonomicky vyvážené v čase.

### 3.6 Funkcionalita seedu

Parametr seed umožňuje více nepřekrývajících se plotů na adresu bez manuální koordinace.

**Problém (POC2)**: Těžaři museli manuálně sledovat rozsahy nonces napříč plot soubory, aby se vyhnuli překrývání. Překrývající se nonces plýtvají úložištěm bez zvýšení těžebního výkonu.

**Řešení**: Každý pár `(adresa, seed)` definuje nezávislý prostor klíčů. Ploty s různými seedy se nikdy nepřekrývají, bez ohledu na rozsahy nonces. Těžaři mohou vytvářet ploty svobodně bez koordinace.

---

## 4. Konsenzus Proof of Capacity

PoCX rozšiřuje Nakamoto konsenzus Bitcoinu o mechanismus důkazu vázaného na úložiště. Místo vynakládání energie na opakované hashování, těžaři vážou velké množství předpočítaných dat — plotů — na disk. Během generování bloků musí lokalizovat malou, nepředvídatelnou část těchto dat a transformovat ji na důkaz. Těžař, který poskytne nejlepší důkaz v očekávaném časovém okně, získává právo vytvořit další blok.

Tato kapitola popisuje, jak PoCX strukturuje metadata bloků, odvozuje nepředvídatelnost a transformuje statické úložiště na bezpečný, nízkovariační konsensuální mechanismus.

### 4.1 Struktura bloku

PoCX zachovává známou hlavičku bloku ve stylu Bitcoinu, ale zavádí další konsensuální pole vyžadovaná pro těžbu založenou na kapacitě. Tato pole kolektivně vážou blok k uloženému plotu těžaře, obtížnosti sítě a kryptografické entropii, která definuje každou těžební výzvu.

Na vysoké úrovni blok PoCX obsahuje: výšku bloku, zaznamenou explicitně pro zjednodušení kontextové validace; generační podpis, zdroj čerstvé entropie propojující každý blok s jeho předchůdcem; base target, reprezentující obtížnost sítě v inverzní formě (vyšší hodnoty odpovídají jednodušší těžbě); PoCX důkaz, identifikující plot těžaře, úroveň komprese použitou během plottování, vybranou nonce a z ní odvozenou kvalitu; a podpisový klíč a podpis, prokazující kontrolu nad kapacitou použitou k vytvoření bloku (nebo přiřazeného forging klíče).

Důkaz vkládá všechny informace relevantní pro konsenzus potřebné validátory pro přepočítání výzvy, verifikaci zvoleného scoopu a potvrzení výsledné kvality. Rozšířením spíše než přepracováním struktury bloku zůstává PoCX konceptuálně sladěn s Bitcoinem při umožnění fundamentálně odlišného zdroje těžební práce.

### 4.2 Řetězec generačních podpisů

Generační podpis poskytuje nepředvídatelnost vyžadovanou pro bezpečnou těžbu Proof of Capacity. Každý blok odvozuje svůj generační podpis z podpisu a podpisujícího předchozího bloku, čímž zajišťuje, že těžaři nemohou předvídat budoucí výzvy nebo předpočítávat výhodné oblasti plotů:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

Toto produkuje sekvenci kryptograficky silných, na těžaři závislých hodnot entropie. Protože veřejný klíč těžaře je neznámý, dokud není publikován předchozí blok, žádný účastník nemůže předpovídat budoucí výběry scoopů. Toto zabraňuje selektivnímu předpočítání nebo strategickému plottování a zajišťuje, že každý blok zavádí skutečně čerstvou těžební práci.

### 4.3 Proces forgingu

Těžba v PoCX spočívá v transformaci uložených dat na důkaz řízený výhradně generačním podpisem. Ačkoliv je proces deterministický, nepředvídatelnost podpisu zajišťuje, že těžaři se nemohou připravit předem a musí opakovaně přistupovat ke svým uloženým plotům.

**Odvození výzvy (výběr scoopu):** Těžař hashuje aktuální generační podpis s výškou bloku pro získání indexu scoopu v rozsahu 0–4095. Tento index určuje, který 64bajtový segment každé uložené nonce participuje na důkazu. Protože generační podpis závisí na podpisujícím předchozího bloku, výběr scoopu se stává známým pouze v okamžiku publikace bloku.

**Vyhodnocení důkazu (výpočet kvality):** Pro každou nonce v plotu těžař načte vybraný scoop a hashuje ho společně s generačním podpisem pro získání kvality — 64bitové hodnoty, jejíž velikost určuje konkurenceschopnost těžaře. Nižší kvalita odpovídá lepšímu důkazu.

**Formování deadline (Time Bending):** Surový deadline je úměrný kvalitě a nepřímo úměrný base target. V legacy návrzích PoC tyto deadliny sledovaly vysoce zkreslené exponenciální distribuce, produkující dlouhé ocasní zpoždění, které neposkytovalo žádnou dodatečnou bezpečnost. PoCX transformuje surový deadline pomocí Time Bending (sekce 4.4), snižujíc varianci a zajišťujíc předvídatelné intervaly bloků. Jakmile bended deadline uplyne, těžař vytvoří blok vložením důkazu a jeho podepsáním efektivním forging klíčem.

### 4.4 Time Bending

Proof of Capacity produkuje exponenciálně distribuované deadliny. Po krátké době — typicky několika desítkách sekund — každý těžař již identifikoval svůj nejlepší důkaz a jakýkoliv dodatečný čekací čas přispívá pouze latencí, ne bezpečností.

Time Bending přetváří distribuci aplikací transformace třetí odmocniny:

`deadline_bended = scale × (quality / base_target)^(1/3)`

Faktor měřítka zachovává očekávaný čas bloku (120 sekund) při dramatickém snížení variance. Krátké deadliny jsou rozšířeny, zlepšujíc propagaci bloků a bezpečnost sítě. Dlouhé deadliny jsou komprimovány, zabraňujíc outlierům ve zpožďování řetězce.

![Distribuce času bloků](blocktime_distributions.svg)

Time Bending zachovává informační obsah základního důkazu. Nemodifikuje konkurenceschopnost mezi těžaři; pouze přealokuje čekací čas pro produkci hladších, předvídatelnějších intervalů bloků. Implementace používá aritmetiku s pevnou řádovou čárkou (formát Q42) a 256bitová celá čísla pro zajištění deterministických výsledků napříč všemi platformami.

### 4.5 Úprava obtížnosti

PoCX reguluje produkci bloků pomocí base target, inverzní míry obtížnosti. Očekávaný čas bloku je úměrný poměru `quality / base_target`, takže zvýšení base target urychluje vytváření bloků, zatímco jeho snížení řetězec zpomaluje.

Obtížnost se upravuje každý blok pomocí měřeného času mezi nedávnými bloky v porovnání s cílovým intervalem. Tato častá úprava je nezbytná, protože úložná kapacita může být přidána nebo odebrána rychle — na rozdíl od hashpower Bitcoinu, který se mění pomaleji.

Úprava sleduje dvě vodící omezení: **Gradualita** — změny per-blok jsou omezeny (max ±20%) pro zabránění oscilacím nebo manipulaci; **Zpevnění** — base target nemůže překročit svou genesis hodnotu, zabraňujíc síti kdy snížit obtížnost pod původní bezpečnostní předpoklady.

### 4.6 Platnost bloku

Blok v PoCX je platný, když prezentuje verifikovatelný důkaz odvozený z úložiště konzistentní s konsensuálním stavem. Validátoři nezávisle přepočítávají výběr scoopu, odvozují očekávanou kvalitu z odeslané nonce a metadat plotu, aplikují transformaci Time Bending a potvrzují, že těžař byl oprávněn vytvořit blok v deklarovaném čase.

Konkrétně platný blok vyžaduje: deadline uplynul od rodičovského bloku; odeslaná kvalita odpovídá vypočítané kvalitě pro důkaz; úroveň škálování splňuje síťové minimum; generační podpis odpovídá očekávané hodnotě; base target odpovídá očekávané hodnotě; podpis bloku pochází od efektivního podpisujícího; a coinbase platí na adresu efektivního podpisujícího.

---

## 5. Forging přiřazení

### 5.1 Motivace

Forging přiřazení umožňují vlastníkům plotů delegovat autoritu vytváření bloků bez vzdání se vlastnictví jejich plotů. Tento mechanismus umožňuje poolovou těžbu a nastavení studeného úložiště při zachování bezpečnostních garancí PoCX.

U poolové těžby mohou vlastníci plotů autorizovat pool k vytváření bloků jejich jménem. Pool sestavuje bloky a distribuuje odměny, ale nikdy nezíská custody nad samotnými ploty. Delegace je kdykoli reverzibilní a vlastníci plotů zůstávají svobodní opustit pool nebo změnit konfigurace bez přeplottování.

Přiřazení také podporují čisté oddělení mezi studenými a horkými klíči. Privátní klíč kontrolující plot může zůstat offline, zatímco oddělený forging klíč — uložený na online stroji — produkuje bloky. Kompromitace forging klíče proto kompromituje pouze forging autoritu, ne vlastnictví. Plot zůstává bezpečný a přiřazení může být revokováno, čímž se okamžitě uzavře bezpečnostní mezera.

Forging přiřazení tak poskytují provozní flexibilitu při udržování principu, že kontrola nad uloženou kapacitou nesmí být nikdy převedena na zprostředkovatele.

### 5.2 Protokol přiřazení

Přiřazení jsou deklarována prostřednictvím transakcí OP_RETURN, aby se zabránilo zbytečnému růstu UTXO setu. Transakce přiřazení specifikuje adresu plotu a forging adresu, která je autorizována produkovat bloky pomocí kapacity tohoto plotu. Transakce revokace obsahuje pouze adresu plotu. V obou případech vlastník plotu prokazuje kontrolu podepsáním utrácejícího vstupu transakce.

Každé přiřazení postupuje sekvencí dobře definovaných stavů (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Po potvrzení transakce přiřazení systém vstoupí do krátké aktivační fáze. Toto zpoždění — 30 bloků, zhruba jedna hodina — zajišťuje stabilitu během závodů o bloky a zabraňuje nepřátelskému rychlému přepínání forging identit. Jakmile toto aktivační období vyprší, přiřazení se stává aktivním a zůstává tak, dokud vlastník plotu nevydá revokaci.

Revokace přecházejí do delšího období zpoždění 720 bloků, přibližně jeden den. Během této doby zůstává předchozí forging adresa aktivní. Toto delší zpoždění poskytuje provozní stabilitu pro pooly, zabraňujíc strategickému "skákání přiřazení" a dávajíc poskytovatelům infrastruktury dostatečnou jistotu pro efektivní provoz. Po uplynutí zpoždění revokace se revokace dokončí a vlastník plotu může svobodně určit nový forging klíč.

Stav přiřazení je udržován ve struktuře konsensuální vrstvy paralelní k UTXO setu a podporuje undo data pro bezpečné zpracování reorganizací řetězce.

### 5.3 Pravidla validace

Pro každý blok validátoři určují efektivního podpisujícího — adresu, která musí podepsat blok a přijmout odměnu coinbase. Tento podpisující závisí výhradně na stavu přiřazení při výšce bloku.

Pokud přiřazení neexistuje nebo přiřazení ještě nedokončilo svou aktivační fázi, vlastník plotu zůstává efektivním podpisujícím. Jakmile se přiřazení stane aktivním, přiřazená forging adresa musí podepisovat. Během revokace forging adresa nadále podepisuje, dokud nevyprší zpoždění revokace. Teprve poté se autorita vrací vlastníkovi plotu.

Validátoři vynucují, že podpis bloku je produkován efektivním podpisujícím, že coinbase platí na stejnou adresu a že všechny přechody sledují předepsaná aktivační a revokační zpoždění. Pouze vlastník plotu může vytvářet nebo revokovat přiřazení; forging klíče nemohou modifikovat nebo rozšiřovat svá vlastní oprávnění.

Forging přiřazení proto zavádějí flexibilní delegaci bez zavedení důvěry. Vlastnictví základní kapacity zůstává vždy kryptograficky ukotveno u vlastníka plotu, zatímco forging autorita může být delegována, rotována nebo revokována podle vývoje provozních potřeb.

---

## 6. Dynamické škálování

S vývojem hardwaru klesají náklady na výpočet plotů relativně ke čtení předpočítané práce z disku. Bez protiopatření by útočníci nakonec mohli generovat důkazy za běhu rychleji, než těžaři čtou uloženou práci, čímž by podkopali bezpečnostní model Proof of Capacity.

Pro zachování zamýšlené bezpečnostní marže PoCX implementuje harmonogram škálování: minimální požadovaná úroveň škálování pro ploty se v čase zvyšuje. Každá úroveň škálování Xn, jak je popsáno v sekci 3.5, vkládá exponenciálně více proof-of-work do struktury plotu, zajišťujíc, že těžaři nadále vážou podstatné úložné zdroje i když se výpočet stává levnějším.

Harmonogram je sladěn s ekonomickými pobídkami sítě, zejména halvingy odměn za bloky. Jak odměna za blok klesá, minimální úroveň se postupně zvyšuje, zachovávajíc rovnováhu mezi úsilím plottování a těžebním potenciálem:

| Období | Roky | Halvingy | Min škálování | Multiplikátor práce plotu |
|--------|------|----------|---------------|---------------------------|
| Epocha 0 | 0-4 | 0 | X1 | 2× baseline |
| Epocha 1 | 4-12 | 1-2 | X2 | 4× baseline |
| Epocha 2 | 12-28 | 3-6 | X3 | 8× baseline |
| Epocha 3 | 28-60 | 7-14 | X4 | 16× baseline |
| Epocha 4 | 60-124 | 15-30 | X5 | 32× baseline |
| Epocha 5 | 124+ | 31+ | X6 | 64× baseline |

Těžaři mohou volitelně připravit ploty překračující aktuální minimum o jednu úroveň, což jim umožňuje plánovat dopředu a vyhnout se okamžitým upgradům, když síť přejde na další epochu. Tento volitelný krok neposkytuje žádnou další výhodu z hlediska pravděpodobnosti bloku — pouze umožňuje hladší provozní přechod.

Bloky obsahující důkazy pod minimální úrovní škálování pro jejich výšku jsou považovány za neplatné. Validátoři kontrolují deklarovanou úroveň škálování v důkazu oproti aktuálnímu síťovému požadavku během validace konsenzu, zajišťujíc, že všichni participující těžaři splňují vyvíjející se bezpečnostní očekávání.

---

## 7. Architektura těžby

PoCX odděluje operace kritické pro konsenzus od zdrojově náročných úloh těžby, umožňujíc jak bezpečnost, tak efektivitu. Uzel udržuje blockchain, validuje bloky, spravuje mempool a exponuje RPC rozhraní. Externí těžaři zpracovávají úložiště plotů, čtení scoopů, výpočet kvality a správu deadlinů. Toto oddělení udržuje logiku konsenzu jednoduchou a auditovatelnou, zatímco umožňuje těžařům optimalizovat pro diskovou propustnost.

### 7.1 Těžební RPC rozhraní

Těžaři interagují s uzlem prostřednictvím minimální sady RPC volání. RPC get_mining_info poskytuje aktuální výšku bloku, generační podpis, base target, cílový deadline a přijatelný rozsah úrovní škálování plotů. S použitím těchto informací těžaři počítají kandidátní nonces. RPC submit_nonce umožňuje těžařům odeslat navrhované řešení, včetně identifikátoru plotu, indexu nonce, úrovně škálování a účtu těžaře. Uzel vyhodnotí odesílání a odpoví s vypočítaným deadline, pokud je důkaz platný.

### 7.2 Plánovač forgingu

Uzel udržuje plánovač forgingu, který sleduje příchozí odesílání a uchovává pouze nejlepší řešení pro každou výšku bloku. Odeslané nonces jsou zařazeny do fronty s vestavěnými ochrannými mechanismy proti zahlcení odesíláním nebo útokům typu denial-of-service. Plánovač čeká, dokud vypočítaný deadline nevyprší nebo nepřijde lepší řešení, načež sestaví blok, podepíše ho efektivním forging klíčem a publikuje ho do sítě.

### 7.3 Obranný forging

Pro prevenci útoků na časování nebo motivací k manipulaci s hodinami PoCX implementuje obranný forging. Pokud přijde konkurenční blok pro stejnou výšku, plánovač porovná lokální řešení s novým blokem. Pokud je lokální kvalita lepší, uzel okamžitě vytvoří blok místo čekání na původní deadline. Toto zajišťuje, že těžaři nemohou získat výhodu pouze úpravou lokálních hodin; nejlepší řešení vždy převáží, zachovávajíc spravedlnost a bezpečnost sítě.

---

## 8. Bezpečnostní analýza

### 8.1 Model hrozeb

PoCX modeluje protivníky s podstatnými, ale omezenými schopnostmi. Útočníci mohou pokoušet zahltit síť neplatnými transakcemi, malformovanými bloky nebo fabrikovanými důkazy pro stresové testování validačních cest. Mohou svobodně manipulovat se svými lokálními hodinami a mohou se pokoušet zneužít hraniční případy v chování konsenzu jako je zpracování časových značek, dynamika úpravy obtížnosti nebo pravidla reorganizací. Očekává se také, že protivníci budou zkoumat příležitosti k přepsání historie prostřednictvím cílených forků řetězce.

Model předpokládá, že žádná jediná strana nekontroluje většinu celkové síťové úložné kapacity. Jako u jakéhokoliv konsensuálního mechanismu založeného na zdrojích, útočník s 51% kapacitou může jednostranně reorganizovat řetězec; toto fundamentální omezení není specifické pro PoCX. PoCX také předpokládá, že útočníci nemohou počítat data plotů rychleji, než je poctiví těžaři mohou číst z disku. Harmonogram škálování (sekce 6) zajišťuje, že výpočetní mezera vyžadovaná pro bezpečnost roste v čase s tím, jak se hardware zlepšuje.

Následující sekce zkoumají každou hlavní třídu útoku podrobně a popisují protiopatření zabudovaná do PoCX.

### 8.2 Útoky na kapacitu

Stejně jako PoW, útočník s většinovou kapacitou může přepsat historii (51% útok). Dosažení toho vyžaduje získání fyzické úložné stopy větší než poctivá síť — nákladný a logisticky náročný podnik. Jakmile je hardware získán, provozní náklady jsou nízké, ale počáteční investice vytváří silnou ekonomickou motivaci chovat se poctivě: podkopání řetězce by poškodilo hodnotu vlastní základny aktiv útočníka.

PoC také vyhýbá problému nothing-at-stake spojenému s PoS. Ačkoliv těžaři mohou skenovat ploty proti více soutěžícím forkům, každé skenování spotřebovává reálný čas — typicky řádově desítky sekund na řetězec. Při 120sekundovém intervalu bloků toto inherentně omezuje těžbu více forků a pokus o těžbu mnoha forků současně degraduje výkon na všech z nich. Těžba forků proto není beznákladová; je fundamentálně omezena propustností I/O.

I kdyby budoucí hardware umožnil téměř okamžité skenování plotů (např. vysokorychlostní SSD), útočník by stále čelil podstatnému požadavku na fyzické zdroje pro kontrolu většiny síťové kapacity, činíc útok typu 51% nákladným a logisticky náročným.

Konečně, útoky na kapacitu jsou mnohem těžší pronajmout než útoky na hashpower. GPU compute lze získat na vyžádání a okamžitě přesměrovat na jakýkoliv PoW řetězec. Naproti tomu PoC vyžaduje fyzický hardware, časově náročné plottování a průběžné I/O operace. Tato omezení činí krátkodobé, oportunistické útoky mnohem méně proveditelné.

### 8.3 Útoky na časování

Časování hraje kritičtější roli v Proof of Capacity než v Proof of Work. V PoW časové značky primárně ovlivňují úpravu obtížnosti; v PoC určují, zda deadline těžaře uplynul a tedy zda je blok způsobilý k forgingu. Deadliny jsou měřeny relativně k časové značce rodičovského bloku, ale lokální hodiny uzlu jsou použity k posouzení, zda příchozí blok leží příliš daleko v budoucnosti. Z tohoto důvodu PoCX vynucuje těsnou toleranci časových značek: bloky se nesmí odchýlit o více než 15 sekund od lokálních hodin uzlu (v porovnání s 2hodinovým oknem Bitcoinu). Tento limit funguje oběma směry — bloky příliš daleko v budoucnosti jsou odmítnuty a uzly s pomalými hodinami mohou nesprávně odmítnout platné příchozí bloky.

Uzly by proto měly synchronizovat své hodiny pomocí NTP nebo ekvivalentního zdroje času. PoCX záměrně se vyhýbá spoléhání na vnitrosíťové zdroje času, aby zabránil útočníkům v manipulaci vnímaného síťového času. Uzly monitorují svůj vlastní drift a vydávají varování, pokud se lokální hodiny začnou odchylovat od nedávných časových značek bloků.

Zrychlení hodin — provoz rychlých lokálních hodin pro dřívější forging — poskytuje pouze marginální výhodu. V rámci povolené tolerance obranný forging (sekce 7.3) zajišťuje, že těžař s lepším řešením okamžitě publikuje po viděním horšího předčasného bloku. Rychlé hodiny pomáhají těžaři pouze publikovat již vítězné řešení o několik sekund dříve; nemohou převést horší důkaz na vítězný.

Pokusy o manipulaci obtížnosti prostřednictvím časových značek jsou omezeny ±20% limitem úpravy per-blok a 24blokovým klouzavým oknem, zabraňujíc těžařům smysluplně ovlivňovat obtížnost prostřednictvím krátkodobých časovacích her.

### 8.4 Útoky časově-paměťovými kompromisy

Časově-paměťové kompromisy se pokoušejí snížit požadavky na úložiště přepočítáváním částí plotu na vyžádání. Předchozí systémy Proof of Capacity byly zranitelné vůči takovým útokům, nejpozoruhodněji chyba nerovnováhy scoopů POC1 a útok XOR-transpose kompresí POC2 (sekce 2.4). Oba zneužívali asymetrie v tom, jak nákladné bylo regenerovat určité části dat plotů, umožňujíc protivníkům snížit úložiště při platbě pouze malé výpočetní pokuty. Také alternativní formáty plotů k PoC2 trpí podobnými slabinami TMTO; prominentním příkladem je Chia, jejíž formát plotů může být libovolně redukován faktorem větším než 4.

PoCX odstraňuje tyto útočné plochy zcela prostřednictvím své konstrukce nonces a formátu warpů. V každé nonce finální difúzní krok hashuje plně vypočítaný buffer a XORuje výsledek napříč všemi bajty, zajišťujíc, že každá část bufferu závisí na každé jiné části a nemůže být zkrácena. Poté POC2 shuffle zamění dolní a horní poloviny každého scoopu, vyrovnávajíc výpočetní náklady na obnovu jakéhokoliv scoopu.

PoCX dále eliminuje útok XOR–transpose kompresí POC2 odvozením svého zpevněného formátu X1, kde každý scoop je XOR přímé a transponované pozice napříč spárovanými warpy; toto propojuje každý scoop s celým řádkem a celým sloupcem základních dat X0, činíc rekonstrukci vyžadující tisíce kompletních nonces a tím odstraňujíc asymetrický časově-paměťový kompromis zcela.

V důsledku toho je ukládání kompletního plotu jedinou výpočetně životaschopnou strategií pro těžaře. Žádná známá zkratka — ať už částečné plottování, selektivní regenerace, strukturovaná komprese nebo hybridní přístupy compute-storage — neposkytuje smysluplnou výhodu. PoCX zajišťuje, že těžba zůstává striktně vázána na úložiště a že kapacita odráží reálný, fyzický závazek.

### 8.5 Útoky na přiřazení

PoCX používá deterministický stavový automat k řízení všech přiřazení plot-to-forger. Každé přiřazení postupuje přes dobře definované stavy — UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED — s vynucenými aktivačními a revokačními zpožděními. Toto zajišťuje, že těžař nemůže okamžitě změnit přiřazení k podvádění systému nebo rychle přepínat forging autoritu.

Protože všechny přechody vyžadují kryptografické důkazy — konkrétně podpisy vlastníkem plotu verifikovatelné proti vstupnímu UTXO — síť může důvěřovat legitimitě každého přiřazení. Pokusy o obejití stavového automatu nebo padělání přiřazení jsou automaticky odmítnuty během validace konsenzu. Replay útokům je rovněž zabráněno standardními ochranami proti replay transakcí ve stylu Bitcoinu, zajišťujíc, že každá akce přiřazení je unikátně vázána na platný, neutracený vstup.

Kombinace řízení stavovým automatem, vynucených zpoždění a kryptografického důkazu činí podvádění založené na přiřazení prakticky nemožným: těžaři nemohou unést přiřazení, provádět rychlé přeřazení během závodů o bloky nebo obejít harmonogramy revokací.

### 8.6 Bezpečnost podpisů

Podpisy bloků v PoCX slouží jako kritické propojení mezi důkazem a efektivním forging klíčem, zajišťujíc, že pouze autorizovaní těžaři mohou produkovat platné bloky.

Pro prevenci útoků maleabilitou jsou podpisy vyloučeny z výpočtu hashe bloku. Toto eliminuje rizika maleabilních podpisů, které by mohly podkopat validaci nebo umožnit útoky nahrazením bloků.

Pro zmírnění vektorů denial-of-service jsou velikosti podpisů a veřejných klíčů fixní — 65 bajtů pro kompaktní podpisy a 33 bajtů pro komprimované veřejné klíče — zabraňujíc útočníkům nafoukovat bloky pro vyvolání vyčerpání zdrojů nebo zpomalení síťové propagace.

---

## 9. Implementace

PoCX je implementován jako modulární rozšíření Bitcoin Core, s veškerým relevantním kódem obsaženým ve svém vlastním dedikovaném podadresáři a aktivovaným prostřednictvím feature flagu. Tento design zachovává integritu původního kódu, umožňujíc PoCX být povolen nebo zakázán čistě, což zjednodušuje testování, audit a udržování synchronizace s upstream změnami.

Integrace se dotýká pouze základních bodů nezbytných pro podporu Proof of Capacity. Hlavička bloku byla rozšířena o pole specifická pro PoCX a validace konsenzu byla přizpůsobena pro zpracování důkazů založených na úložišti vedle tradičních kontrol Bitcoinu. Forging systém, zodpovědný za správu deadlinů, plánování a odesílání těžařů, je plně obsažen v modulech PoCX, zatímco RPC rozšíření exponují těžební a přiřazovací funkcionalitu externím klientům. Pro uživatele bylo rozhraní peněženky vylepšeno pro správu přiřazení prostřednictvím transakcí OP_RETURN, umožňujíc bezproblémovou interakci s novými konsensuálními funkcemi.

Všechny operace kritické pro konsenzus jsou implementovány v deterministickém C++ bez externích závislostí, zajišťujíc konzistenci napříč platformami. Pro hashování se používá Shabal256, zatímco Time Bending a výpočet kvality spoléhají na aritmetiku s pevnou řádovou čárkou a 256bitové operace. Kryptografické operace jako verifikace podpisů využívají existující knihovnu secp256k1 Bitcoin Core.

Izolováním funkcionalit PoCX tímto způsobem implementace zůstává auditovatelná, udržovatelná a plně kompatibilní s probíhajícím vývojem Bitcoin Core, demonstrujíc, že fundamentálně nový konsensuální mechanismus vázaný na úložiště může koexistovat s vyspělou proof-of-work kódovou základnou bez narušení její integrity nebo použitelnosti.

---

## 10. Síťové parametry

PoCX staví na síťové infrastruktuře Bitcoinu a znovu používá jeho framework parametrů řetězce. Pro podporu těžby založené na kapacitě, zpracování přiřazení a škálování plotů bylo několik parametrů rozšířeno nebo přepsáno. To zahrnuje cílový čas bloku, počáteční subsidy, harmonogram halvingů, aktivační a revokační zpoždění přiřazení, stejně jako síťové identifikátory jako magic bajty, porty a Bech32 prefixy. Prostředí testnet a regtest dále upravují tyto parametry pro umožnění rychlé iterace a testování s nízkou kapacitou.

Tabulky níže shrnují výsledná nastavení pro mainnet, testnet a regtest, zdůrazňujíc jak PoCX adaptuje základní parametry Bitcoinu na konsensuální model vázaný na úložiště.

### 10.1 Mainnet

| Parametr | Hodnota |
|----------|---------|
| Magic bajty | `0xa7 0x3c 0x91 0x5e` |
| Výchozí port | 8888 |
| Bech32 HRP | `pocx` |
| Cílový čas bloku | 120 sekund |
| Počáteční subsidy | 10 BTC |
| Interval halvingu | 1050000 bloků (~4 roky) |
| Celková nabídka | ~21 milionů BTC |
| Aktivace přiřazení | 30 bloků |
| Revokace přiřazení | 720 bloků |
| Klouzavé okno | 24 bloků |

### 10.2 Testnet

| Parametr | Hodnota |
|----------|---------|
| Magic bajty | `0x6d 0xf2 0x48 0xb3` |
| Výchozí port | 18888 |
| Bech32 HRP | `tpocx` |
| Cílový čas bloku | 120 sekund |
| Ostatní parametry | Stejné jako mainnet |

### 10.3 Regtest

| Parametr | Hodnota |
|----------|---------|
| Magic bajty | `0xfa 0xbf 0xb5 0xda` |
| Výchozí port | 18444 |
| Bech32 HRP | `rpocx` |
| Cílový čas bloku | 1 sekunda |
| Interval halvingu | 500 bloků |
| Aktivace přiřazení | 4 bloky |
| Revokace přiřazení | 8 bloků |
| Režim nízké kapacity | Povolen (~4 MB ploty) |

---

## 11. Související práce

V průběhu let několik blockchain a konsensuálních projektů zkoumalo modely těžby založené na úložišti nebo hybridní modely. PoCX staví na tomto dědictví a zároveň zavádí vylepšení v bezpečnosti, efektivitě a kompatibilitě.

**Burstcoin / Signum.** Burstcoin představil první praktický systém Proof-of-Capacity (PoC) v roce 2014, definující základní koncepty jako ploty, nonces, scoopy a těžbu založenou na deadline. Jeho nástupci, zejména Signum (dříve Burstcoin), rozšířili ekosystém a nakonec se vyvinuli v to, co je známo jako Proof-of-Commitment (PoC+), kombinující vázání úložiště s volitelným stakingem pro ovlivnění efektivní kapacity. PoCX dědí základ těžby založené na úložišti z těchto projektů, ale významně se liší prostřednictvím zpevněného formátu plotů (XOR-transpose kódování), dynamického škálování práce plotů, vyhlazování deadlinů ("Time Bending") a flexibilního systému přiřazení — to vše při ukotvení v kódové základně Bitcoin Core místo udržování samostatného síťového forku.

**Chia.** Chia implementuje Proof of Space and Time, kombinující důkazy založené na úložišti s časovou komponentou vynucenou prostřednictvím Verifiable Delay Functions (VDF). Její design řeší určité obavy ohledně znovupoužití důkazů a generování čerstvých výzev, odlišné od klasického PoC. PoCX nepřijímá tento model důkazů ukotvených v čase; místo toho udržuje konsenzus vázaný na úložiště s předvídatelnými intervaly, optimalizovaný pro dlouhodobou kompatibilitu s ekonomikou UTXO a nástroji odvozenými od Bitcoinu.

**Spacemesh.** Spacemesh navrhuje schéma Proof-of-Space-Time (PoST) používající síťovou topologii založenou na DAG (mesh). V tomto modelu musí účastníci periodicky prokazovat, že alokované úložiště zůstává nedotčeno v čase, místo spoléhání na jediný předpočítaný dataset. PoCX naproti tomu verifikuje vázání úložiště pouze v čase bloku — se zpevněnými formáty plotů a rigorózní validací důkazů — vyhýbajíc se overheadu nepřetržitých důkazů úložiště při zachování efektivity a decentralizace.

---

## 12. Závěr

Bitcoin-PoCX demonstruje, že energeticky úsporný konsenzus může být integrován do Bitcoin Core při zachování bezpečnostních vlastností a ekonomického modelu. Klíčové příspěvky zahrnují XOR-transpose kódování (nutí útočníky počítat 4096 nonces na vyhledávání, eliminujíc útok kompresí), algoritmus Time Bending (transformace distribuce snižuje varianci času bloků), systém forging přiřazení (delegace založená na OP_RETURN umožňuje non-custodial poolovou těžbu), dynamické škálování (sladěné s halvingy pro udržení bezpečnostních marží) a minimální integraci (feature-flagovaný kód izolovaný v dedikovaném adresáři).

Systém je v současné době ve fázi testovací sítě. Těžební výkon je odvozen z úložné kapacity místo hash rate, snižujíc spotřebu energie o řády při udržování osvědčeného ekonomického modelu Bitcoinu.

---

## Reference

Bitcoin Core. *Repozitář Bitcoin Core.* https://github.com/bitcoin/bitcoin

Burstcoin. *Technická dokumentace Proof of Capacity.* 2014.

NIST. *Soutěž SHA-3: Shabal.* 2008.

Cohen, B., Pietrzak, K. *Blockchain Chia Network.* 2019.

Spacemesh. *Dokumentace protokolu Spacemesh.* 2021.

PoC Consortium. *Framework PoCX.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Integrace Bitcoin-PoCX.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Licence**: MIT
**Organizace**: Proof of Capacity Consortium
**Stav**: Fáze testovací sítě
