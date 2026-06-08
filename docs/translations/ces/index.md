# Technická dokumentace Bitcoin-PoCX

**Verze**: 1.0
**Základ Bitcoin Core**: v30.2
**Stav**: Mainnet aktivní (od 3. května 2026)
**Poslední aktualizace**: 2025-12-25

---

## O této dokumentaci

Toto je kompletní technická dokumentace pro Bitcoin-PoCX, integraci do Bitcoin Core přidávající podporu konsenzu Proof of Capacity neXt generation (PoCX). Dokumentace je organizována jako prohlížitelný průvodce s propojenými kapitolami pokrývajícími všechny aspekty systému.

**Cílové skupiny**:
- **Provozovatelé uzlů**: Kapitoly 1, 5, 6, 8
- **Těžaři**: Kapitoly 2, 3, 7
- **Vývojáři**: Všechny kapitoly
- **Výzkumníci**: Kapitoly 3, 4, 5




## Překlady

| | | | | | |
|---|---|---|---|---|---|
| [🇬🇧 Angličtina](../../index.md) | [🇸🇦 Arabština](../ara/index.md) | [🇧🇬 Bulharština](../bul/index.md) | [🇨🇳 Čínština](../zho/index.md) | [🇩🇰 Dánština](../dan/index.md) | [🇪🇪 Estonština](../est/index.md) |
| [🇵🇭 Filipínština](../fil/index.md) | [🇫🇮 Finština](../fin/index.md) | [🇫🇷 Francouzština](../fra/index.md) | [🇮🇱 Hebrejština](../heb/index.md) | [🇮🇳 Hindština](../hin/index.md) | [🇮🇩 Indonéština](../ind/index.md) |
| [🇮🇹 Italština](../ita/index.md) | [🇯🇵 Japonština](../jpn/index.md) | [🇰🇷 Korejština](../kor/index.md) | [🇱🇹 Litevština](../lit/index.md) | [🇱🇻 Lotyština](../lav/index.md) | [🇭🇺 Maďarština](../hun/index.md) |
| [🇩🇪 Němčina](../deu/index.md) | [🇳🇱 Nizozemština](../nld/index.md) | [🇳🇴 Norština](../nor/index.md) | [🇵🇱 Polština](../pol/index.md) | [🇵🇹 Portugalština](../por/index.md) | [🇬🇷 Řečtina](../ell/index.md) |
| [🇷🇴 Rumunština](../ron/index.md) | [🇷🇺 Ruština](../rus/index.md) | [🇷🇸 Srbština](../srp/index.md) | [🇰🇪 Svahilština](../swa/index.md) | [🇪🇸 Španělština](../spa/index.md) | [🇸🇪 Švédština](../swe/index.md) |
| [🇹🇷 Turečtina](../tur/index.md) | [🇺🇦 Ukrajinština](../ukr/index.md) | [🇻🇳 Vietnamština](../vie/index.md) | | | |


---

## Obsah

### Část I: Základy

**[Kapitola 1: Úvod a přehled](1-introduction.md)**
Přehled projektu, architektura, filozofie návrhu, klíčové funkce a rozdíly mezi PoCX a Proof of Work.

**[Kapitola 2: Formát plot souborů](2-plot-format.md)**
Kompletní specifikace formátu PoCX plotů včetně optimalizace SIMD, škálování proof-of-work a vývoje z formátů POC1/POC2.

**[Kapitola 3: Konsenzus a těžba](3-consensus-and-mining.md)**
Kompletní technická specifikace konsensuálního mechanismu PoCX: struktura bloků, generační podpisy, úprava base target, proces těžby, validační pipeline a algoritmus Time Bending.

---

### Část II: Pokročilé funkce

**[Kapitola 4: Systém forging přiřazení](4-forging-assignments.md)**
Architektura pouze s OP_RETURN pro delegování práv na vytváření bloků: struktura transakcí, návrh databáze, stavový automat, zpracování reorganizací a RPC rozhraní.

**[Kapitola 5: Časová synchronizace a bezpečnost](5-timing-security.md)**
Tolerance odchylky hodin, obranný forging mechanismus, ochrana proti manipulaci s hodinami a bezpečnostní aspekty související s časováním.

**[Kapitola 6: Síťové parametry](6-network-parameters.md)**
Konfigurace chainparams, genesis blok, konsensuální parametry, pravidla coinbase, dynamické škálování a ekonomický model.

---

### Část III: Použití a integrace

**[Kapitola 7: Reference RPC rozhraní](7-rpc-reference.md)**
Kompletní reference RPC příkazů pro těžbu, přiřazení a dotazy na blockchain. Nezbytné pro integraci těžařů a poolů.

**[Kapitola 8: Průvodce peněženkou a GUI](8-wallet-guide.md)**
Uživatelská příručka pro Qt peněženku Bitcoin-PoCX: dialog forging přiřazení, historie transakcí, nastavení těžby a řešení problémů.

---

## Rychlá navigace

### Pro provozovatele uzlů
→ Začněte s [Kapitola 1: Úvod](1-introduction.md)
→ Poté si projděte [Kapitola 6: Síťové parametry](6-network-parameters.md)
→ Nastavte těžbu pomocí [Kapitola 8: Průvodce peněženkou](8-wallet-guide.md)

### Pro těžaře
→ Pochopte [Kapitola 2: Formát plotů](2-plot-format.md)
→ Naučte se proces v [Kapitola 3: Konsenzus a těžba](3-consensus-and-mining.md)
→ Integrujte pomocí [Kapitola 7: Reference RPC](7-rpc-reference.md)

### Pro provozovatele poolů
→ Prostudujte [Kapitola 4: Forging přiřazení](4-forging-assignments.md)
→ Studujte [Kapitola 7: Reference RPC](7-rpc-reference.md)
→ Implementujte pomocí RPC pro přiřazení a submit_nonce

### Pro vývojáře
→ Přečtěte si všechny kapitoly postupně
→ Křížově odkazujte implementační soubory uvedené v textu
→ Prozkoumejte strukturu adresáře `src/pocx/`
→ Sestavujte release pomocí [GUIX](../bitcoin/contrib/guix/README.md)

---

## Konvence dokumentace

**Odkazy na soubory**: Implementační detaily odkazují na zdrojové soubory jako `cesta/k/souboru.cpp:řádek`

**Integrace kódu**: Všechny změny jsou označeny feature flagy pomocí `#ifdef ENABLE_POCX`

**Křížové odkazy**: Kapitoly odkazují na související sekce pomocí relativních markdown odkazů

**Technická úroveň**: Dokumentace předpokládá znalost Bitcoin Core a vývoje v C++

---

## Sestavení

### Vývojové sestavení

```bash
# Klonování se submoduly
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Configure
cmake -B build

# Sestavení
cmake --build build -j$(nproc)
```

**Varianty sestavení**:
```bash
# S Qt GUI
cmake -B build -DBUILD_GUI=ON

# Debug sestavení
cmake -B build -DCMAKE_BUILD_TYPE=Debug
```

**Závislosti**: Standardní závislosti sestavení Bitcoin Core. Viz [dokumentace sestavení Bitcoin Core](https://github.com/bitcoin/bitcoin/tree/master/doc#building) pro požadavky specifické pro platformu.

### Release sestavení

Pro reprodukovatelné release binárky použijte sestavovací systém GUIX: Viz [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Další zdroje

**Repozitář**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCX Core Framework**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Související projekty**:
- Plotter: Založen na [engraver](https://github.com/PoC-Consortium/engraver)
- Miner: Založen na [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Jak číst tuto dokumentaci

**Sekvenční čtení**: Kapitoly jsou navrženy ke čtení v pořadí a navazují na předchozí koncepty.

**Referenční čtení**: Použijte obsah k přímému přechodu na konkrétní témata. Každá kapitola je samostatná s křížovými odkazy na související materiál.

**Navigace v prohlížeči**: Otevřete `index.md` v markdown prohlížeči nebo webovém prohlížeči. Všechny interní odkazy jsou relativní a fungují offline.

**Export do PDF**: Tuto dokumentaci lze zřetězit do jediného PDF pro offline čtení.

---

## Stav projektu

**Funkce dokončeny**: Všechna konsensuální pravidla, těžba, přiřazení a funkce peněženky jsou implementovány.

**Dokumentace dokončena**: Všech 8 kapitol je dokončeno a ověřeno proti kódové základně.

**🚀 Mainnet aktivní**: Mainnet je aktivní od 3. května 2026.

---

## Přispívání

Příspěvky do dokumentace jsou vítány. Prosím udržujte:
- Technickou přesnost před rozsáhlostí
- Stručná a výstižná vysvětlení
- Žádný kód ani pseudokód v dokumentaci (místo toho odkazujte na zdrojové soubory)
- Pouze implementované funkce (žádné spekulativní vlastnosti)

---

## Licence

Bitcoin-PoCX dědí licenci MIT od Bitcoin Core. Viz `bitcoin/COPYING` v kořenovém adresáři repozitáře.

Atribuce PoCX core frameworku dokumentována v [Kapitola 2: Formát plotů](2-plot-format.md).

---

**Začít číst**: [Kapitola 1: Úvod a přehled →](1-introduction.md)
