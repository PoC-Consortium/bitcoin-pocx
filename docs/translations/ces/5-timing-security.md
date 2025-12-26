[← Předchozí: Forging přiřazení](4-forging-assignments.md) | [Obsah](index.md) | [Další: Síťové parametry →](6-network-parameters.md)

---

# Kapitola 5: Časová synchronizace a bezpečnost

## Přehled

Konsenzus PoCX vyžaduje přesnou časovou synchronizaci napříč sítí. Tato kapitola dokumentuje bezpečnostní mechanismy související s časem, toleranci driftu hodin a obranné chování při forgingu.

**Klíčové mechanismy**:
- 15sekundová tolerance budoucnosti pro časové značky bloků
- Systém varování při 10sekundovém driftu hodin
- Obranný forging (ochrana proti manipulaci s hodinami)
- Integrace algoritmu Time Bending

---

## Obsah

1. [Požadavky na časovou synchronizaci](#požadavky-na-časovou-synchronizaci)
2. [Detekce driftu hodin a varování](#detekce-driftu-hodin-a-varování)
3. [Mechanismus obranného forgingu](#mechanismus-obranného-forgingu)
4. [Analýza bezpečnostních hrozeb](#analýza-bezpečnostních-hrozeb)
5. [Osvědčené postupy pro provozovatele uzlů](#osvědčené-postupy-pro-provozovatele-uzlů)

---

## Požadavky na časovou synchronizaci

### Konstanty a parametry

**Konfigurace Bitcoin-PoCX:**
```cpp
// src/chain.h:31
static constexpr int64_t MAX_FUTURE_BLOCK_TIME = 15;  // 15 sekund

// src/node/timeoffsets.h:27
static constexpr std::chrono::seconds WARN_THRESHOLD{10};  // 10 sekund
```

### Validační kontroly

**Validace časové značky bloku** (`src/validation.cpp:4547-4561`):
```cpp
// 1. Monotónní kontrola: časová značka >= časová značka předchozího bloku
if (block.nTime < pindexPrev->nTime) {
    return state.Invalid("time-too-old");
}

// 2. Kontrola budoucnosti: časová značka <= nyní + 15 sekund
if (block.Time() > NodeClock::now() + std::chrono::seconds{MAX_FUTURE_BLOCK_TIME}) {
    return state.Invalid("time-too-new");
}

// 3. Kontrola deadline: uplynulý čas >= deadline
uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
if (result.deadline > elapsed_time) {
    return state.Invalid("bad-pocx-timing");
}
```

### Tabulka dopadu driftu hodin

| Offset hodin | Může synchronizovat? | Může těžit? | Stav validace | Konkurenční efekt |
|--------------|---------------------|-------------|---------------|-------------------|
| -30s pomalé | NE - Kontrola budoucnosti selže | N/A | **MRTVÝ UZEL** | Nemůže participovat |
| -14s pomalé | Ano | Ano | Pozdní forging, projde validací | Prohrává závody |
| 0s perfektní | Ano | Ano | Optimální | Optimální |
| +14s rychlé | Ano | Ano | Brzký forging, projde validací | Vyhrává závody |
| +16s rychlé | Ano | NE - Kontrola budoucnosti selže | Nemůže šířit bloky | Může synchronizovat, nemůže těžit |

**Klíčový poznatek**: 15sekundové okno je symetrické pro participaci (±14,9s), ale rychlé hodiny poskytují neférovou konkurenční výhodu v rámci tolerance.

### Integrace Time Bending

Algoritmus Time Bending (podrobně v [Kapitole 3](3-consensus-and-mining.md#výpočet-time-bending)) transformuje surové deadliny pomocí třetí odmocniny:

```
time_bended_deadline = scale × (deadline_seconds)^(1/3)
```

**Interakce s driftem hodin**:
- Lepší řešení se vytvářejí dříve (třetí odmocnina zesiluje rozdíly v kvalitě)
- Drift hodin ovlivňuje čas forgingu relativně k síti
- Obranný forging zajišťuje soutěž založenou na kvalitě navzdory varianci časování

---

## Detekce driftu hodin a varování

### Systém varování

Bitcoin-PoCX monitoruje časový offset mezi lokálním uzlem a síťovými peery.

**Varovná zpráva** (když drift překročí 10 sekund):
> "Datum a čas vašeho počítače se zdá být více než 10 sekund mimo synchronizaci se sítí, což může vést k selhání konsenzu PoCX. Prosím zkontrolujte systémové hodiny."

**Implementace**: `src/node/timeoffsets.cpp`

### Zdůvodnění návrhu

**Proč 10 sekund?**
- Poskytuje 5sekundový bezpečnostní buffer před limitem 15sekundové tolerance
- Přísnější než výchozí Bitcoin Core (10 minut)
- Vhodné pro požadavky časování PoC

**Preventivní přístup**:
- Včasné varování před kritickým selháním
- Umožňuje operátorům proaktivně opravit problémy
- Snižuje fragmentaci sítě z časově souvisejících selhání

---

## Mechanismus obranného forgingu

### Co to je

Obranný forging je standardní chování těžaře v Bitcoin-PoCX, které eliminuje výhody založené na časování při produkci bloků. Když váš miner přijme konkurenční blok ve stejné výšce, automaticky zkontroluje, zda máte lepší řešení. Pokud ano, okamžitě vytvoří váš blok, čímž zajistí soutěž založenou na kvalitě místo soutěže založené na manipulaci s hodinami.

### Problém

Konsenzus PoCX umožňuje bloky s časovými značkami až 15 sekund v budoucnosti. Tato tolerance je nezbytná pro globální síťovou synchronizaci. Vytváří však příležitost pro manipulaci s hodinami:

**Bez obranného forgingu:**
- Těžař A: Správný čas, kvalita 800 (lepší), čeká na správný deadline
- Těžař B: Rychlé hodiny (+14s), kvalita 1000 (horší), vytváří o 14 sekund dříve
- Výsledek: Těžař B vyhrává závod navzdory horší práci proof-of-capacity

**Problém:** Manipulace s hodinami poskytuje výhodu i při horší kvalitě, což podkopává princip proof-of-capacity.

### Řešení: Dvouvrstvá obrana

#### Vrstva 1: Varování při driftu hodin (preventivní)

Bitcoin-PoCX monitoruje časový offset mezi vaším uzlem a síťovými peery. Pokud se vaše hodiny odchýlí o více než 10 sekund od síťového konsenzu, dostanete varování upozorňující vás na opravu problémů s hodinami, než způsobí potíže.

#### Vrstva 2: Obranný forging (reaktivní)

Když jiný těžař publikuje blok ve stejné výšce, kterou těžíte:

1. **Detekce**: Váš uzel identifikuje soutěž ve stejné výšce
2. **Validace**: Extrahuje a validuje kvalitu konkurenčního bloku
3. **Porovnání**: Zkontroluje, zda je vaše kvalita lepší
4. **Odpověď**: Pokud je lepší, okamžitě vytvoří váš blok

**Výsledek:** Síť přijme oba bloky a vybere ten s lepší kvalitou prostřednictvím standardního řešení forků.

### Jak to funguje

#### Scénář: Soutěž ve stejné výšce

```
Čas 150s: Těžař B (hodiny +10s) vytváří s kvalitou 1000
          → Časová značka bloku ukazuje 160s (10s v budoucnosti)

Čas 150s: Váš uzel přijímá blok těžaře B
          → Detekuje: stejná výška, kvalita 1000
          → Vy máte: kvalitu 800 (lepší!)
          → Akce: Okamžitě vytvořit se správnou časovou značkou (150s)

Čas 152s: Síť validuje oba bloky
          → Oba platné (v rámci 15s tolerance)
          → Kvalita 800 vyhrává (nižší = lepší)
          → Váš blok se stává špičkou řetězce
```

#### Scénář: Skutečný reorg

```
Vaše těžební výška 100, konkurent publikuje blok 99
→ Není soutěž ve stejné výšce
→ Obranný forging se NESPOUŠTÍ
→ Pokračuje normální zpracování reorgu
```

### Výhody

**Nulová motivace pro manipulaci s hodinami**
- Rychlé hodiny pomáhají pouze tehdy, pokud již máte nejlepší kvalitu
- Manipulace s hodinami se stává ekonomicky nesmyslnou

**Vynucena soutěž založená na kvalitě**
- Nutí těžaře soutěžit na skutečné práci proof-of-capacity
- Zachovává integritu konsenzu PoCX

**Bezpečnost sítě**
- Odolná vůči strategiím herního časování
- Nevyžaduje žádné změny konsenzu - čistě chování těžaře

**Plně automatické**
- Nevyžaduje žádnou konfiguraci
- Spouští se pouze když je to nutné
- Standardní chování ve všech uzlech Bitcoin-PoCX

### Kompromisy

**Minimální zvýšení míry osiřelých bloků**
- Záměrné - útočné bloky jsou osiřelé
- Vyskytuje se pouze během skutečných pokusů o manipulaci s hodinami
- Přirozený výsledek řešení forků založeného na kvalitě

**Krátká síťová soutěž**
- Síť krátce vidí dva soutěžící bloky
- Vyřeší se během sekund prostřednictvím standardní validace
- Stejné chování jako simultánní těžba v Bitcoinu

### Technické podrobnosti

**Dopad na výkon:** Zanedbatelný
- Spouští se pouze při soutěži ve stejné výšce
- Používá data v paměti (žádné diskové I/O)
- Validace se dokončí v milisekundách

**Využití zdrojů:** Minimální
- ~20 řádků základní logiky
- Znovu používá existující validační infrastrukturu
- Jedno získání zámku

**Kompatibilita:** Plná
- Žádné změny konsensuálních pravidel
- Funguje se všemi funkcemi Bitcoin Core
- Volitelný monitoring přes debug logy

**Stav**: Aktivní ve všech vydáních Bitcoin-PoCX
**Poprvé představeno**: 2025-10-10

---

## Analýza bezpečnostních hrozeb

### Útok rychlými hodinami (zmírněn obranným forgingem)

**Vektor útoku**:
Těžař s hodinami **+14s dopředu** může:
1. Přijímat bloky normálně (zdají se mu staré)
2. Vytvářet bloky okamžitě, když uplyne deadline
3. Vysílat bloky, které se zdají být 14s "brzy" pro síť
4. **Bloky jsou přijaty** (v rámci 15s tolerance)
5. **Vyhrává závody** proti poctivým těžařům

**Dopad bez obranného forgingu**:
Výhoda je omezena na 14,9 sekundy (nestačí k přeskočení významné práce PoC), ale poskytuje konzistentní výhodu v závodech o bloky.

**Zmírnění (obranný forging)**:
- Poctiví těžaři detekují soutěž ve stejné výšce
- Porovnávají hodnoty kvality
- Okamžitě vytvářejí, pokud je kvalita lepší
- **Výsledek**: Rychlé hodiny pomáhají pouze tehdy, pokud již máte nejlepší kvalitu
- **Motivace**: Nulová - manipulace s hodinami se stává ekonomicky nesmyslnou

### Selhání pomalých hodin (kritické)

**Režim selhání**:
Uzel **>15s pozadu** je katastrofální:
- Nemůže validovat příchozí bloky (kontrola budoucnosti selže)
- Stává se izolovaným od sítě
- Nemůže těžit ani synchronizovat

**Zmírnění**:
- Silné varování při 10s driftu dává 5sekundový buffer před kritickým selháním
- Operátoři mohou proaktivně opravit problémy s hodinami
- Jasné chybové zprávy vedou k řešení problémů

---

## Osvědčené postupy pro provozovatele uzlů

### Nastavení časové synchronizace

**Doporučená konfigurace**:
1. **Povolte NTP**: Použijte Network Time Protocol pro automatickou synchronizaci
   ```bash
   # Linux (systemd-timesyncd)
   sudo timedatectl set-ntp true

   # Kontrola stavu
   timedatectl status
   ```

2. **Ověřte přesnost hodin**: Pravidelně kontrolujte časový offset
   ```bash
   # Kontrola stavu synchronizace NTP
   ntpq -p

   # Nebo s chrony
   chronyc tracking
   ```

3. **Monitorujte varování**: Sledujte varování o driftu hodin v logech Bitcoin-PoCX

### Pro těžaře

**Nevyžaduje žádnou akci**:
- Funkce je vždy aktivní
- Funguje automaticky
- Jen udržujte systémové hodiny přesné

**Osvědčené postupy**:
- Používejte NTP časovou synchronizaci
- Monitorujte varování o driftu hodin
- Řešte varování okamžitě, pokud se objeví

**Očekávané chování**:
- Sólová těžba: Obranný forging se spouští zřídka (žádná soutěž)
- Síťová těžba: Chrání proti pokusům o manipulaci s hodinami
- Transparentní provoz: Většina těžařů si ho nikdy nevšimne

### Řešení problémů

**Varování: "10 sekund mimo synchronizaci"**
- Akce: Zkontrolujte a opravte synchronizaci systémových hodin
- Dopad: 5sekundový buffer před kritickým selháním
- Nástroje: NTP, chrony, systemd-timesyncd

**Chyba: "time-too-new" u příchozích bloků**
- Příčina: Vaše hodiny jsou >15 sekund pomalé
- Dopad: Nemůže validovat bloky, uzel izolován
- Oprava: Okamžitě synchronizujte systémové hodiny

**Chyba: Nelze šířit vytvořené bloky**
- Příčina: Vaše hodiny jsou >15 sekund rychlé
- Dopad: Bloky odmítnuty sítí
- Oprava: Okamžitě synchronizujte systémové hodiny

---

## Designová rozhodnutí a zdůvodnění

### Proč 15sekundová tolerance?

**Zdůvodnění**:
- Variabilní časování deadline Bitcoin-PoCX je méně kritické na čas než konsenzus s pevným časováním
- 15s poskytuje adekvátní ochranu při prevenci fragmentace sítě

**Kompromisy**:
- Těsnější tolerance = více fragmentace sítě z menšího driftu
- Volnější tolerance = více příležitostí pro útoky časováním
- 15s vyvažuje bezpečnost a robustnost

### Proč 10sekundové varování?

**Zdůvodnění**:
- Poskytuje 5sekundový bezpečnostní buffer
- Vhodnější pro PoC než výchozí 10 minut Bitcoinu
- Umožňuje proaktivní opravy před kritickým selháním

### Proč obranný forging?

**Řešený problém**:
- 15sekundová tolerance umožňuje výhodu rychlých hodin
- Konsenzus založený na kvalitě by mohl být podkopán manipulací s časováním

**Výhody řešení**:
- Obrana s nulovými náklady (žádné změny konsenzu)
- Automatický provoz
- Eliminuje motivaci k útoku
- Zachovává principy proof-of-capacity

### Proč žádná vnitrosíťová časová synchronizace?

**Bezpečnostní zdůvodnění**:
- Moderní Bitcoin Core odstranil úpravu času založenou na peerech
- Zranitelná vůči Sybil útokům na vnímaný síťový čas
- PoCX záměrně se vyhýbá spoléhání na vnitrosíťové zdroje času
- Systémové hodiny jsou důvěryhodnější než peerový konsenzus
- Operátoři by měli synchronizovat pomocí NTP nebo ekvivalentního externího zdroje času
- Uzly monitorují svůj vlastní drift a vydávají varování, pokud se lokální hodiny odchylují od nedávných časových značek bloků

---

## Reference implementace

**Základní soubory**:
- Validace času: `src/validation.cpp:4547-4561`
- Konstanta tolerance budoucnosti: `src/chain.h:31`
- Práh varování: `src/node/timeoffsets.h:27`
- Monitorování časového offsetu: `src/node/timeoffsets.cpp`
- Obranný forging: `src/pocx/mining/scheduler.cpp`

**Související dokumentace**:
- Algoritmus Time Bending: [Kapitola 3: Konsenzus a těžba](3-consensus-and-mining.md#výpočet-time-bending)
- Validace bloků: [Kapitola 3: Validace bloků](3-consensus-and-mining.md#validace-bloků)

---

**Vygenerováno**: 2025-10-10
**Stav**: Kompletní implementace
**Pokrytí**: Požadavky na časovou synchronizaci, zpracování driftu hodin, obranný forging

---

[← Předchozí: Forging přiřazení](4-forging-assignments.md) | [Obsah](index.md) | [Další: Síťové parametry →](6-network-parameters.md)
