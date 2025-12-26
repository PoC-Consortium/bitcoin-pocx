[Obsah](index.md) | [Další: Formát plotů →](2-plot-format.md)

---

# Kapitola 1: Úvod a přehled

## Co je Bitcoin-PoCX?

Bitcoin-PoCX je integrace do Bitcoin Core, která přidává podporu konsenzu **Proof of Capacity neXt generation (PoCX)**. Zachovává stávající architekturu Bitcoin Core a zároveň umožňuje energeticky úspornou alternativu těžby Proof of Capacity jako úplnou náhradu za Proof of Work.

**Klíčový rozdíl**: Jedná se o **nový řetězec** bez zpětné kompatibility s Bitcoin PoW. PoCX bloky jsou záměrně nekompatibilní s PoW uzly.

---

## Identita projektu

- **Organizace**: Proof of Capacity Consortium
- **Název projektu**: Bitcoin-PoCX
- **Plný název**: Bitcoin Core s integrací PoCX
- **Stav**: Fáze testovací sítě

---

## Co je Proof of Capacity?

Proof of Capacity (PoC) je konsensuální mechanismus, kde je těžební výkon úměrný **diskovému prostoru** místo výpočetního výkonu. Těžaři předem generují velké plot soubory obsahující kryptografické hashe a poté tyto ploty používají k nalezení platných řešení bloků.

**Energetická účinnost**: Plot soubory se generují jednou a používají se neomezeně dlouho. Těžba spotřebovává minimální výkon CPU — především diskové I/O operace.

**Vylepšení PoCX**:
- Opravený útok XOR-transpose komprese (50% časově-paměťový kompromis v POC2)
- Rozložení zarovnané na 16 nonces pro moderní hardware
- Škálovatelný proof-of-work při generování plotů (úrovně škálování Xn)
- Nativní C++ integrace přímo do Bitcoin Core
- Algoritmus Time Bending pro vylepšenou distribuci času bloků

---

## Přehled architektury

### Struktura repozitáře

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + integrace PoCX
│   └── src/pocx/        # Implementace PoCX
├── pocx/                # PoCX core framework (submodul, pouze pro čtení)
└── docs/                # Tato dokumentace
```

### Filozofie integrace

**Minimální integrační plocha**: Změny izolované v adresáři `/src/pocx/` s čistými háky do validační, těžební a RPC vrstvy Bitcoin Core.

**Feature flagy**: Všechny modifikace pod preprocesovými direktivami `#ifdef ENABLE_POCX`. Bitcoin Core se sestavuje normálně, když jsou zakázány.

**Kompatibilita s upstreamem**: Pravidelná synchronizace s aktualizacemi Bitcoin Core udržovaná prostřednictvím izolovaných integračních bodů.

**Nativní C++ implementace**: Skalární kryptografické algoritmy (Shabal256, výpočet scoop, komprese) integrované přímo do Bitcoin Core pro validaci konsenzu.

---

## Klíčové funkce

### 1. Kompletní náhrada konsenzu

- **Struktura bloků**: PoCX-specifická pole nahrazují PoW nonce a difficulty bits
  - Generační podpis (deterministická entropie těžby)
  - Base target (inverzní hodnota obtížnosti)
  - PoCX důkaz (account ID, seed, nonce)
  - Podpis bloku (prokazuje vlastnictví plotu)

- **Validace**: 5-stupňová validační pipeline od kontroly hlavičky po připojení bloku

- **Úprava obtížnosti**: Úprava při každém bloku pomocí klouzavého průměru nedávných base targets

### 2. Algoritmus Time Bending

**Problém**: Tradiční časy bloků PoC následují exponenciální distribuci, což vede k dlouhým blokům, když žádný těžař nenajde dobré řešení.

**Řešení**: Transformace distribuce z exponenciální na chí-kvadrát pomocí třetí odmocniny: `Y = měřítko × (X^(1/3))`.

**Efekt**: Velmi dobrá řešení jsou vytvářena později (síť má čas prohledat všechny disky, redukuje rychlé bloky), špatná řešení jsou vylepšena. Průměrný čas bloku udržován na 120 sekundách, dlouhé bloky redukovány.

**Podrobnosti**: [Kapitola 3: Konsenzus a těžba](3-consensus-and-mining.md)

### 3. Systém forging přiřazení

**Schopnost**: Vlastníci plotů mohou delegovat práva na vytváření bloků na jiné adresy při zachování vlastnictví plotů.

**Případy použití**:
- Poolová těžba (ploty přiřazeny k adrese poolu)
- Studené úložiště (těžební klíč oddělený od vlastnictví plotu)
- Vícestranná těžba (sdílená infrastruktura)

**Architektura**: Design pouze s OP_RETURN — žádné speciální UTXO, přiřazení sledována samostatně v databázi chainstate.

**Podrobnosti**: [Kapitola 4: Forging přiřazení](4-forging-assignments.md)

### 4. Obranný forging

**Problém**: Rychlé hodiny by mohly poskytnout časovou výhodu v rámci 15sekundové tolerance budoucnosti.

**Řešení**: Při přijetí konkurenčního bloku ve stejné výšce automaticky zkontroluje lokální kvalitu. Pokud je lepší, okamžitě vytvoří blok.

**Efekt**: Eliminuje motivaci k manipulaci s hodinami — rychlé hodiny pomáhají pouze tehdy, pokud již máte nejlepší řešení.

**Podrobnosti**: [Kapitola 5: Časová bezpečnost](5-timing-security.md)

### 5. Dynamické škálování komprese

**Ekonomické sladění**: Požadavky na úroveň škálování se zvyšují podle exponenciálního harmonogramu (roky 4, 12, 28, 60, 124 = halvings 1, 3, 7, 15, 31).

**Efekt**: Jak se odměny za bloky snižují, obtížnost generování plotů se zvyšuje. Udržuje bezpečnostní marži mezi náklady na vytvoření plotu a vyhledávání.

**Zabraňuje**: Inflaci kapacity z rychlejšího hardwaru v průběhu času.

**Podrobnosti**: [Kapitola 6: Síťové parametry](6-network-parameters.md)

---

## Filozofie návrhu

### Bezpečnost kódu

- Obranné programovací praktiky v celém systému
- Komplexní zpracování chyb ve validačních cestách
- Žádné vnořené zámky (prevence deadlocků)
- Atomické databázové operace (UTXO + přiřazení společně)

### Modulární architektura

- Čisté oddělení mezi infrastrukturou Bitcoin Core a konsenzem PoCX
- PoCX core framework poskytuje kryptografické primitivy
- Bitcoin Core poskytuje validační framework, databázi, síťování

### Optimalizace výkonu

- Uspořádání validace s rychlým selháním (nejlevnější kontroly první)
- Jedno získání kontextu na odeslání (žádné opakované získávání cs_main)
- Atomické databázové operace pro konzistenci

### Bezpečnost reorganizací

- Kompletní undo data pro změny stavu přiřazení
- Reset stavu forgingu při změnách špičky řetězce
- Detekce zastarání ve všech bodech validace

---

## Jak se PoCX liší od Proof of Work

| Aspekt | Bitcoin (PoW) | Bitcoin-PoCX |
|--------|---------------|--------------|
| **Těžební zdroj** | Výpočetní výkon (hash rate) | Diskový prostor (kapacita) |
| **Spotřeba energie** | Vysoká (nepřetržité hashování) | Nízká (pouze diskové I/O) |
| **Proces těžby** | Najít nonce s hashem < target | Najít nonce s deadline < uplynulý čas |
| **Obtížnost** | Pole `bits`, upravováno každých 2016 bloků | Pole `base_target`, upravováno každý blok |
| **Čas bloku** | ~10 minut (exponenciální distribuce) | 120 sekund (time-bended, snížená variance) |
| **Subsidy** | 50 BTC → 25 → 12,5 → ... | 10 BTC → 5 → 2,5 → ... |
| **Hardware** | ASIC (specializovaný) | HDD (běžný hardware) |
| **Identita těžby** | Anonymní | Vlastník plotu nebo delegát |

---

## Systémové požadavky

### Provoz uzlu

**Stejné jako Bitcoin Core**:
- **CPU**: Moderní x86_64 procesor
- **Paměť**: 4-8 GB RAM
- **Úložiště**: Nový řetězec, aktuálně prázdný (může růst ~4× rychleji než Bitcoin kvůli 2minutovým blokům a databázi přiřazení)
- **Síť**: Stabilní internetové připojení
- **Hodiny**: Doporučena NTP synchronizace pro optimální provoz

**Poznámka**: Plot soubory NEJSOU vyžadovány pro provoz uzlu.

### Požadavky na těžbu

**Další požadavky pro těžbu**:
- **Plot soubory**: Předem vygenerované pomocí `pocx_plotter` (referenční implementace)
- **Těžební software**: `pocx_miner` (referenční implementace) se připojuje přes RPC
- **Peněženka**: `bitcoind` nebo `bitcoin-qt` s privátními klíči pro těžební adresu. Poolová těžba nevyžaduje lokální peněženku.

---

## Začínáme

### 1. Sestavte Bitcoin-PoCX

```bash
# Klonování se submoduly
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Sestavení s povoleným PoCX
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Podrobnosti**: Viz `CLAUDE.md` v kořenovém adresáři repozitáře

### 2. Spusťte uzel

**Pouze uzel**:
```bash
./build/bin/bitcoind
# nebo
./build/bin/bitcoin-qt
```

**Pro těžbu** (povoluje RPC přístup pro externí těžaře):
```bash
./build/bin/bitcoind -miningserver
# nebo
./build/bin/bitcoin-qt -server -miningserver
```

**Podrobnosti**: [Kapitola 6: Síťové parametry](6-network-parameters.md)

### 3. Generujte plot soubory

Použijte `pocx_plotter` (referenční implementace) k vygenerování plot souborů ve formátu PoCX.

**Podrobnosti**: [Kapitola 2: Formát plotů](2-plot-format.md)

### 4. Nastavte těžbu

Použijte `pocx_miner` (referenční implementace) k připojení k RPC rozhraní vašeho uzlu.

**Podrobnosti**: [Kapitola 7: Reference RPC](7-rpc-reference.md) a [Kapitola 8: Průvodce peněženkou](8-wallet-guide.md)

---

## Atribuce

### Formát plotů

Založeno na formátu POC2 (Burstcoin) s vylepšeními:
- Opravena bezpečnostní chyba (útok XOR-transpose komprese)
- Škálovatelný proof-of-work
- Rozložení optimalizované pro SIMD
- Funkce seed

### Zdrojové projekty

- **pocx_miner**: Referenční implementace založená na [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Referenční implementace založená na [engraver](https://github.com/PoC-Consortium/engraver)

**Úplná atribuce**: [Kapitola 2: Formát plotů](2-plot-format.md)

---

## Souhrn technických specifikací

- **Čas bloku**: 120 sekund (mainnet), 1 sekunda (regtest)
- **Subsidy bloku**: 10 BTC počáteční, halving každých 1050000 bloků (~4 roky)
- **Celková nabídka**: ~21 milionů BTC (stejně jako Bitcoin)
- **Tolerance budoucnosti**: 15 sekund (bloky až 15s dopředu akceptovány)
- **Upozornění na hodiny**: 10 sekund (upozorňuje operátory na časový drift)
- **Zpoždění přiřazení**: 30 bloků (~1 hodina)
- **Zpoždění revokace**: 720 bloků (~24 hodin)
- **Formát adresy**: Pouze P2WPKH (bech32, pocx1q...) pro PoCX těžební operace a forging přiřazení

---

## Organizace kódu

**Modifikace Bitcoin Core**: Minimální změny v základních souborech, označené feature flagy pomocí `#ifdef ENABLE_POCX`

**Nová implementace PoCX**: Izolována v adresáři `src/pocx/`

---

## Bezpečnostní aspekty

### Časová bezpečnost

- 15sekundová tolerance budoucnosti zabraňuje fragmentaci sítě
- 10sekundový práh upozornění varuje operátory před driftem hodin
- Obranný forging eliminuje motivaci k manipulaci s hodinami
- Time Bending snižuje dopad variance časování

**Podrobnosti**: [Kapitola 5: Časová bezpečnost](5-timing-security.md)

### Bezpečnost přiřazení

- Design pouze s OP_RETURN (žádná manipulace s UTXO)
- Podpis transakce prokazuje vlastnictví plotu
- Zpoždění aktivace zabraňují rychlé manipulaci se stavem
- Reorg-safe undo data pro všechny změny stavu

**Podrobnosti**: [Kapitola 4: Forging přiřazení](4-forging-assignments.md)

### Bezpečnost konsenzu

- Podpis vyloučen z hashe bloku (zabraňuje maleabilitě)
- Omezené velikosti podpisu (zabraňuje DoS)
- Validace hranic komprese (zabraňuje slabým důkazům)
- Úprava obtížnosti při každém bloku (reaguje na změny kapacity)

**Podrobnosti**: [Kapitola 3: Konsenzus a těžba](3-consensus-and-mining.md)

---

## Stav sítě

**Mainnet**: Dosud nespuštěn
**Testnet**: K dispozici pro testování
**Regtest**: Plně funkční pro vývoj

**Parametry genesis bloku**: [Kapitola 6: Síťové parametry](6-network-parameters.md)

---

## Další kroky

**Pro pochopení PoCX**: Pokračujte na [Kapitola 2: Formát plotů](2-plot-format.md) a naučte se o struktuře plot souborů a vývoji formátu.

**Pro nastavení těžby**: Přejděte na [Kapitola 7: Reference RPC](7-rpc-reference.md) pro podrobnosti integrace.

**Pro provoz uzlu**: Projděte si [Kapitola 6: Síťové parametry](6-network-parameters.md) pro možnosti konfigurace.

---

[Obsah](index.md) | [Další: Formát plotů →](2-plot-format.md)
