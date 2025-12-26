# Bitcoin-PoCX Technische Documentatie

**Versie**: 1.0
**Bitcoin Core Basis**: v30.0
**Status**: Testnetfase
**Laatst bijgewerkt**: 25-12-2025

---

## Over deze documentatie

Dit is de volledige technische documentatie voor Bitcoin-PoCX, een Bitcoin Core-integratie die Proof of Capacity neXt generation (PoCX) consensusondersteuning toevoegt. De documentatie is georganiseerd als een navigeerbare handleiding met onderling verbonden hoofdstukken die alle aspecten van het systeem behandelen.

**Doelgroepen**:
- **Node-operators**: Hoofdstukken 1, 5, 6, 8
- **Miners**: Hoofdstukken 2, 3, 7
- **Ontwikkelaars**: Alle hoofdstukken
- **Onderzoekers**: Hoofdstukken 3, 4, 5

## Vertalingen

| | | | | | |
|---|---|---|---|---|---|
| [🇸🇦 Arabisch](../ara/index.md) | [🇧🇬 Bulgaars](../bul/index.md) | [🇨🇳 Chinees](../zho/index.md) | [🇩🇰 Deens](../dan/index.md) | [🇩🇪 Duits](../deu/index.md) | [🇬🇧 Engels](../../index.md) |
| [🇪🇪 Estisch](../est/index.md) | [🇵🇭 Filipijns](../fil/index.md) | [🇫🇮 Fins](../fin/index.md) | [🇫🇷 Frans](../fra/index.md) | [🇬🇷 Grieks](../ell/index.md) | [🇮🇱 Hebreeuws](../heb/index.md) |
| [🇮🇳 Hindi](../hin/index.md) | [🇭🇺 Hongaars](../hun/index.md) | [🇮🇩 Indonesisch](../ind/index.md) | [🇮🇹 Italiaans](../ita/index.md) | [🇯🇵 Japans](../jpn/index.md) | [🇰🇷 Koreaans](../kor/index.md) |
| [🇱🇻 Lets](../lav/index.md) | [🇱🇹 Litouws](../lit/index.md) | [🇳🇴 Noors](../nor/index.md) | [🇺🇦 Oekraïens](../ukr/index.md) | [🇵🇱 Pools](../pol/index.md) | [🇵🇹 Portugees](../por/index.md) |
| [🇷🇴 Roemeens](../ron/index.md) | [🇷🇺 Russisch](../rus/index.md) | [🇷🇸 Servisch](../srp/index.md) | [🇪🇸 Spaans](../spa/index.md) | [🇰🇪 Swahili](../swa/index.md) | [🇨🇿 Tsjechisch](../ces/index.md) |
| [🇹🇷 Turks](../tur/index.md) | [🇻🇳 Vietnamees](../vie/index.md) | [🇸🇪 Zweeds](../swe/index.md) | | | |

---

## Inhoudsopgave

### Deel I: Grondbeginselen

**[Hoofdstuk 1: Inleiding en overzicht](1-introduction.md)**
Projectoverzicht, architectuur, ontwerpfilosofie, kernfuncties en hoe PoCX verschilt van Proof of Work.

**[Hoofdstuk 2: Plotbestandsformaat](2-plot-format.md)**
Volledige specificatie van het PoCX-plotformaat inclusief SIMD-optimalisatie, proof-of-work-schaling en formaat-evolutie vanaf POC1/POC2.

**[Hoofdstuk 3: Consensus en mining](3-consensus-and-mining.md)**
Volledige technische specificatie van het PoCX-consensusmechanisme: blokstructuur, generatiehandtekeningen, base target-aanpassing, miningproces, validatiepijplijn en Time Bending-algoritme.

---

### Deel II: Geavanceerde functies

**[Hoofdstuk 4: Forging-toewijzingssysteem](4-forging-assignments.md)**
OP_RETURN-architectuur voor het delegeren van forgingrechten: transactiestructuur, database-ontwerp, toestandsmachine, reorg-afhandeling en RPC-interface.

**[Hoofdstuk 5: Tijdsynchronisatie en beveiliging](5-timing-security.md)**
Klokverschuivingstolerantie, defensief forgen, anti-klokmanipulatie en timing-gerelateerde beveiligingsoverwegingen.

**[Hoofdstuk 6: Netwerkparameters](6-network-parameters.md)**
Chainparams-configuratie, genesisblok, consensusparameters, coinbase-regels, dynamische schaling en economisch model.

---

### Deel III: Gebruik en integratie

**[Hoofdstuk 7: RPC-interface-referentie](7-rpc-reference.md)**
Volledige RPC-opdrachtreferentie voor mining, toewijzingen en blockchain-queries. Essentieel voor miner- en pool-integratie.

**[Hoofdstuk 8: Wallet- en GUI-handleiding](8-wallet-guide.md)**
Gebruikershandleiding voor Bitcoin-PoCX Qt-wallet: forging-toewijzingsdialoog, transactiegeschiedenis, mining-setup en probleemoplossing.

---

## Snelle navigatie

### Voor node-operators
Ga naar [Hoofdstuk 1: Inleiding](1-introduction.md)
Bekijk vervolgens [Hoofdstuk 6: Netwerkparameters](6-network-parameters.md)
Configureer mining met [Hoofdstuk 8: Wallet-handleiding](8-wallet-guide.md)

### Voor miners
Begrijp [Hoofdstuk 2: Plotformaat](2-plot-format.md)
Leer het proces in [Hoofdstuk 3: Consensus en mining](3-consensus-and-mining.md)
Integreer met [Hoofdstuk 7: RPC-referentie](7-rpc-reference.md)

### Voor pool-operators
Bekijk [Hoofdstuk 4: Forging-toewijzingen](4-forging-assignments.md)
Bestudeer [Hoofdstuk 7: RPC-referentie](7-rpc-reference.md)
Implementeer met toewijzings-RPC's en submit_nonce

### Voor ontwikkelaars
Lees alle hoofdstukken op volgorde
Raadpleeg implementatiebestanden die overal vermeld worden
Bekijk de `src/pocx/`-mappenstructuur
Bouw releases met [GUIX](../bitcoin/contrib/guix/README.md)

---

## Documentatieconventies

**Bestandsreferenties**: Implementatiedetails verwijzen naar bronbestanden als `pad/naar/bestand.cpp:regel`

**Code-integratie**: Alle wijzigingen zijn voorzien van functievlaggen met `#ifdef ENABLE_POCX`

**Kruisverwijzingen**: Hoofdstukken verwijzen naar gerelateerde secties met relatieve markdown-links

**Technisch niveau**: Documentatie veronderstelt bekendheid met Bitcoin Core en C++-ontwikkeling

---

## Bouwen

### Ontwikkelingsbuild

```bash
# Kloon met submodules
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Configureer met PoCX ingeschakeld
cmake -B build -DENABLE_POCX=ON

# Bouw
cmake --build build -j$(nproc)
```

**Buildvarianten**:
```bash
# Met Qt GUI
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Debugbuild
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Afhankelijkheden**: Standaard Bitcoin Core build-afhankelijkheden. Zie de [Bitcoin Core build-documentatie](https://github.com/bitcoin/bitcoin/tree/master/doc#building) voor platformspecifieke vereisten.

### Releasebuild

Voor reproduceerbare release-binaries, gebruik het GUIX-buildsysteem: Zie [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Aanvullende bronnen

**Repository**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCX Core Framework**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Gerelateerde projecten**:
- Plotter: Gebaseerd op [engraver](https://github.com/PoC-Consortium/engraver)
- Miner: Gebaseerd op [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Hoe deze documentatie te lezen

**Sequentieel lezen**: Hoofdstukken zijn ontworpen om op volgorde te worden gelezen, voortbouwend op eerdere concepten.

**Naslagwerk**: Gebruik de inhoudsopgave om direct naar specifieke onderwerpen te navigeren. Elk hoofdstuk is op zichzelf staand met kruisverwijzingen naar gerelateerd materiaal.

**Browsernavigatie**: Open `index.md` in een markdown-viewer of browser. Alle interne links zijn relatief en werken offline.

**PDF-export**: Deze documentatie kan worden samengevoegd tot een enkele PDF voor offline lezen.

---

## Projectstatus

**Volledig functioneel**: Alle consensusregels, mining, toewijzingen en wallet-functies zijn geimplementeerd.

**Documentatie compleet**: Alle 8 hoofdstukken zijn voltooid en geverifieerd tegen de codebase.

**Testnet actief**: Momenteel in testnetfase voor communitytesten.

---

## Bijdragen

Bijdragen aan de documentatie zijn welkom. Houd rekening met:
- Technische nauwkeurigheid boven breedvoerigheid
- Beknopte, to-the-point uitleg
- Geen code of pseudocode in documentatie (verwijs in plaats daarvan naar bronbestanden)
- Alleen zoals geimplementeerd (geen speculatieve functies)

---

## Licentie

Bitcoin-PoCX erft de MIT-licentie van Bitcoin Core. Zie `COPYING` in de repository-root.

PoCX core framework-attributie is gedocumenteerd in [Hoofdstuk 2: Plotformaat](2-plot-format.md).

---

**Begin met lezen**: [Hoofdstuk 1: Inleiding en overzicht](1-introduction.md)
