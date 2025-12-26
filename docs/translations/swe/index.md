# Teknisk dokumentation för Bitcoin-PoCX

**Version**: 1.0
**Bitcoin Core-bas**: v30.0
**Status**: Testnetfas
**Senast uppdaterad**: 2025-12-25

---

## Om denna dokumentation

Detta är den fullständiga tekniska dokumentationen för Bitcoin-PoCX, en Bitcoin Core-integration som lägger till stöd för Proof of Capacity neXt generation (PoCX)-konsensus. Dokumentationen är organiserad som en navigerbar guide med sammanlänkade kapitel som täcker alla aspekter av systemet.

**Målgrupper**:
- **Nodoperatörer**: Kapitel 1, 5, 6, 8
- **Miners**: Kapitel 2, 3, 7
- **Utvecklare**: Alla kapitel
- **Forskare**: Kapitel 3, 4, 5




## Översättningar

| | | | | | |
|---|---|---|---|---|---|
| [🇸🇦 Arabiska](../ara/index.md) | [🇧🇬 Bulgariska](../bul/index.md) | [🇩🇰 Danska](../dan/index.md) | [🇬🇧 Engelska](../../index.md) | [🇪🇪 Estniska](../est/index.md) | [🇵🇭 Filippinska](../fil/index.md) |
| [🇫🇮 Finska](../fin/index.md) | [🇫🇷 Franska](../fra/index.md) | [🇬🇷 Grekiska](../ell/index.md) | [🇮🇱 Hebreiska](../heb/index.md) | [🇮🇳 Hindi](../hin/index.md) | [🇮🇩 Indonesiska](../ind/index.md) |
| [🇮🇹 Italienska](../ita/index.md) | [🇯🇵 Japanska](../jpn/index.md) | [🇨🇳 Kinesiska](../zho/index.md) | [🇰🇷 Koreanska](../kor/index.md) | [🇱🇻 Lettiska](../lav/index.md) | [🇱🇹 Litauiska](../lit/index.md) |
| [🇳🇱 Nederländska](../nld/index.md) | [🇳🇴 Norska](../nor/index.md) | [🇵🇱 Polska](../pol/index.md) | [🇵🇹 Portugisiska](../por/index.md) | [🇷🇴 Rumänska](../ron/index.md) | [🇷🇺 Ryska](../rus/index.md) |
| [🇷🇸 Serbiska](../srp/index.md) | [🇪🇸 Spanska](../spa/index.md) | [🇰🇪 Swahili](../swa/index.md) | [🇨🇿 Tjeckiska](../ces/index.md) | [🇹🇷 Turkiska](../tur/index.md) | [🇩🇪 Tyska](../deu/index.md) |
| [🇺🇦 Ukrainska](../ukr/index.md) | [🇭🇺 Ungerska](../hun/index.md) | [🇻🇳 Vietnamesiska](../vie/index.md) | | | |


---

## Innehållsförteckning

### Del I: Grunderna

**[Kapitel 1: Introduktion och översikt](1-introduction.md)**
Projektöversikt, arkitektur, designfilosofi, nyckelfunktioner och hur PoCX skiljer sig från Proof of Work.

**[Kapitel 2: Plotfilformat](2-plot-format.md)**
Fullständig specifikation av PoCX-plotformatet inklusive SIMD-optimering, proof-of-work-skalning och formatutveckling från POC1/POC2.

**[Kapitel 3: Konsensus och mining](3-consensus-and-mining.md)**
Fullständig teknisk specifikation av PoCX-konsensusmekanismen: blockstruktur, generationssignaturer, basmåljustering, miningprocess, valideringspipeline och Time Bending-algoritmen.

---

### Del II: Avancerade funktioner

**[Kapitel 4: Forging Assignment-systemet](4-forging-assignments.md)**
OP_RETURN-baserad arkitektur för delegering av forgningrättigheter: transaktionsstruktur, databasdesign, tillståndsmaskin, reorg-hantering och RPC-gränssnitt.

**[Kapitel 5: Tidssynkronisering och säkerhet](5-timing-security.md)**
Klockdriftstolerans, defensiv forgning, skydd mot klockmanipulation och tidsrelaterade säkerhetsöverväganden.

**[Kapitel 6: Nätverksparametrar](6-network-parameters.md)**
Chainparams-konfiguration, genesisblock, konsensusparametrar, coinbase-regler, dynamisk skalning och ekonomisk modell.

---

### Del III: Användning och integration

**[Kapitel 7: RPC-gränssnittsreferens](7-rpc-reference.md)**
Fullständig RPC-kommandoreferens för mining, tilldelningar och blockchain-förfrågningar. Väsentlig för miner- och poolintegration.

**[Kapitel 8: Plånboks- och GUI-guide](8-wallet-guide.md)**
Användarguide för Bitcoin-PoCX Qt-plånboken: dialogruta för forging assignment, transaktionshistorik, miningkonfiguration och felsökning.

---

## Snabbnavigering

### För nodoperatörer
-> Börja med [Kapitel 1: Introduktion](1-introduction.md)
-> Granska sedan [Kapitel 6: Nätverksparametrar](6-network-parameters.md)
-> Konfigurera mining med [Kapitel 8: Plånboksguide](8-wallet-guide.md)

### För miners
-> Förstå [Kapitel 2: Plotformat](2-plot-format.md)
-> Lär dig processen i [Kapitel 3: Konsensus och mining](3-consensus-and-mining.md)
-> Integrera med [Kapitel 7: RPC-referens](7-rpc-reference.md)

### För pooloperatörer
-> Granska [Kapitel 4: Forging Assignments](4-forging-assignments.md)
-> Studera [Kapitel 7: RPC-referens](7-rpc-reference.md)
-> Implementera med assignment-RPC:er och submit_nonce

### För utvecklare
-> Läs alla kapitel i ordning
-> Korshänvisa implementationsfiler som nämns genomgående
-> Undersök katalogstrukturen `src/pocx/`
-> Bygg releaser med [GUIX](../bitcoin/contrib/guix/README.md)

---

## Dokumentationskonventioner

**Filreferenser**: Implementationsdetaljer refererar till källfiler som `sökväg/till/fil.cpp:rad`

**Kodintegration**: Alla ändringar är funktionsflaggade med `#ifdef ENABLE_POCX`

**Korsreferenser**: Kapitel länkar till relaterade avsnitt med relativa markdown-länkar

**Teknisk nivå**: Dokumentationen förutsätter bekantskap med Bitcoin Core och C++-utveckling

---

## Byggande

### Utvecklingsbygg

```bash
# Klona med submoduler
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Konfigurera med PoCX aktiverat
cmake -B build -DENABLE_POCX=ON

# Bygg
cmake --build build -j$(nproc)
```

**Byggvarianter**:
```bash
# Med Qt GUI
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Debug-bygg
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Beroenden**: Standard Bitcoin Core-byggberoenden. Se [Bitcoin Core-byggdokumentation](https://github.com/bitcoin/bitcoin/tree/master/doc#building) för plattformsspecifika krav.

### Releasebyggen

För reproducerbara releasebinärer, använd GUIX-byggsystemet: Se [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Ytterligare resurser

**Arkiv**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCX Core Framework**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Relaterade projekt**:
- Plotter: Baserad på [engraver](https://github.com/PoC-Consortium/engraver)
- Miner: Baserad på [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Hur man läser denna dokumentation

**Sekventiell läsning**: Kapitlen är utformade för att läsas i ordning och bygger på tidigare koncept.

**Referensläsning**: Använd innehållsförteckningen för att hoppa direkt till specifika ämnen. Varje kapitel är fristående med korsreferenser till relaterat material.

**Webbläsarnavigering**: Öppna `index.md` i en markdown-visare eller webbläsare. Alla interna länkar är relativa och fungerar offline.

**PDF-export**: Denna dokumentation kan sammanfogas till en enda PDF för offlineläsning.

---

## Projektstatus

**Funktionskomplett**: Alla konsensusregler, mining, tilldelningar och plånboksfunktioner är implementerade.

**Dokumentation komplett**: Alla 8 kapitel är kompletta och verifierade mot kodbasen.

**Testnet aktivt**: För närvarande i testnetfas för communitytestning.

---

## Bidra

Bidrag till dokumentationen välkomnas. Vänligen upprätthåll:
- Teknisk noggrannhet framför ordrikedom
- Korta, koncisa förklaringar
- Ingen kod eller pseudokod i dokumentationen (referera till källfiler istället)
- Endast som-implementerat (inga spekulativa funktioner)

---

## Licens

Bitcoin-PoCX ärver Bitcoin Cores MIT-licens. Se `COPYING` i arkivets rot.

Attribution för PoCX core framework dokumenteras i [Kapitel 2: Plotformat](2-plot-format.md).

---

**Börja läsa**: [Kapitel 1: Introduktion och översikt ->](1-introduction.md)
