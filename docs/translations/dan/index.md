# Bitcoin-PoCX Teknisk Dokumentation

**Version**: 1.0
**Bitcoin Core-base**: v30.0
**Status**: Testnet-fase
**Senest opdateret**: 2025-12-25

---

## Om denne dokumentation

Dette er den komplette tekniske dokumentation for Bitcoin-PoCX, en Bitcoin Core-integration der tilfojer understottelse af Proof of Capacity neXt generation (PoCX) konsensus. Dokumentationen er organiseret som en gennemsoelig guide med sammenkoblede kapitler, der daekker alle aspekter af systemet.

**Malgrupper**:
- **Node-operatorer**: Kapitel 1, 5, 6, 8
- **Minere**: Kapitel 2, 3, 7
- **Udviklere**: Alle kapitler
- **Forskere**: Kapitel 3, 4, 5




## Oversaettelser

| | | | | | |
|---|---|---|---|---|---|
| [Arabic](translations/ara/index.md) | [Kinesisk](translations/zho/index.md) | [Hollandsk](translations/nld/index.md) | [Fransk](translations/fra/index.md) | [Tysk](translations/deu/index.md) | [Graesk](translations/ell/index.md) |
| [Hebraisk](translations/heb/index.md) | [Hindi](translations/hin/index.md) | [Indonesisk](translations/ind/index.md) | [Italiensk](translations/ita/index.md) | [Japansk](translations/jpn/index.md) | [Koreansk](translations/kor/index.md) |
| [Portugisisk](translations/por/index.md) | [Russisk](translations/rus/index.md) | [Serbisk](translations/srp/index.md) | [Spansk](translations/spa/index.md) | [Tyrkisk](translations/tur/index.md) | [Ukrainsk](translations/ukr/index.md) |
| [Vietnamesisk](translations/vie/index.md) | | | | | |


---

## Indholdsfortegnelse

### Del I: Grundlaeggende

**[Kapitel 1: Introduktion og overblik](1-introduction.md)**
Projektoversigt, arkitektur, designfilosofi, noglefunktioner og hvordan PoCX adskiller sig fra Proof of Work.

**[Kapitel 2: Plotfilformat](2-plot-format.md)**
Komplet specifikation af PoCX-plotformatet inklusive SIMD-optimering, proof-of-work-skalering og formatudvikling fra POC1/POC2.

**[Kapitel 3: Konsensus og mining](3-consensus-and-mining.md)**
Komplet teknisk specifikation af PoCX-konsensusmekanismen: blokstruktur, generationssignaturer, base target-justering, miningproces, valideringspipeline og Time Bending-algoritmen.

---

### Del II: Avancerede funktioner

**[Kapitel 4: Forging Assignment-system](4-forging-assignments.md)**
OP_RETURN-baseret arkitektur til delegering af forging-rettigheder: transaktionsstruktur, databasedesign, tilstandsmaskine, reorg-handtering og RPC-graenseflade.

**[Kapitel 5: Tidssynkronisering og sikkerhed](5-timing-security.md)**
Urdriftstolerance, defensiv forging-mekanisme, anti-urmanipulation og timing-relaterede sikkerhedsovervejelser.

**[Kapitel 6: Netvaerksparametre](6-network-parameters.md)**
Chainparams-konfiguration, genesis-blok, konsensusparametre, coinbase-regler, dynamisk skalering og okonomisk model.

---

### Del III: Brug og integration

**[Kapitel 7: RPC-graensefladereference](7-rpc-reference.md)**
Komplet RPC-kommandoreference til mining, assignments og blockchain-foresprgsler. Essentiel for miner- og pool-integration.

**[Kapitel 8: Wallet- og GUI-guide](8-wallet-guide.md)**
Brugervejledning til Bitcoin-PoCX Qt-wallet: forging assignment-dialog, transaktionshistorik, mining-opsaetning og fejlfinding.

---

## Hurtig navigation

### For node-operatorer
-> Start med [Kapitel 1: Introduktion](1-introduction.md)
-> Gennemga derefter [Kapitel 6: Netvaerksparametre](6-network-parameters.md)
-> Konfigurer mining med [Kapitel 8: Wallet-guide](8-wallet-guide.md)

### For minere
-> Forsta [Kapitel 2: Plotformat](2-plot-format.md)
-> Laer processen i [Kapitel 3: Konsensus og mining](3-consensus-and-mining.md)
-> Integrer ved hjaelp af [Kapitel 7: RPC-reference](7-rpc-reference.md)

### For pool-operatorer
-> Gennemga [Kapitel 4: Forging Assignments](4-forging-assignments.md)
-> Studer [Kapitel 7: RPC-reference](7-rpc-reference.md)
-> Implementer ved hjaelp af assignment-RPC'er og submit_nonce

### For udviklere
-> Laes alle kapitler sekventielt
-> Krydshenvis implementeringsfiler noteret hele vejen igennem
-> Undersg `src/pocx/`-mappestrukturen
-> Byg releases med [GUIX](../bitcoin/contrib/guix/README.md)

---

## Dokumentationskonventioner

**Filreferencer**: Implementeringsdetaljer refererer til kildefiler som `sti/til/fil.cpp:linje`

**Kodeintegration**: Alle aendringer er feature-flagget med `#ifdef ENABLE_POCX`

**Krydsreferencer**: Kapitler linker til relaterede sektioner ved hjaelp af relative markdown-links

**Teknisk niveau**: Dokumentationen forudsaetter kendskab til Bitcoin Core og C++-udvikling

---

## Bygning

### Udviklingsbygning

```bash
# Klon med submoduler
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Konfigurer med PoCX aktiveret
cmake -B build -DENABLE_POCX=ON

# Byg
cmake --build build -j$(nproc)
```

**Byggevarianter**:
```bash
# Med Qt GUI
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Debug-bygning
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Afhaengigheder**: Standard Bitcoin Core-byggeafhaengigheder. Se [Bitcoin Core-byggedokumentation](https://github.com/bitcoin/bitcoin/tree/master/doc#building) for platformsspecifikke krav.

### Release-bygninger

For reproducerbare release-binarfiler, brug GUIX-byggesystemet: Se [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Yderligere ressourcer

**Repository**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCX Core Framework**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Relaterede projekter**:
- Plotter: Baseret pa [engraver](https://github.com/PoC-Consortium/engraver)
- Miner: Baseret pa [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Sadan laeser du denne dokumentation

**Sekventiel laesning**: Kapitlerne er designet til at blive laest i raekkefolge, hvor hvert kapitel bygger pa tidligere begreber.

**Referencelaesning**: Brug indholdsfortegnelsen til at springe direkte til specifikke emner. Hvert kapitel er selvstaendigt med krydsreferencer til relateret materiale.

**Browsernavigation**: Abn `index.md` i en markdown-fremviser eller browser. Alle interne links er relative og fungerer offline.

**PDF-eksport**: Denne dokumentation kan sammenkaedes til en enkelt PDF til offline-laesning.

---

## Projektstatus

**Fuldt implementeret**: Alle konsensusregler, mining, assignments og wallet-funktioner implementeret.

**Dokumentation faerdig**: Alle 8 kapitler faerdige og verificeret mod kodebasen.

**Testnet aktivt**: I oejeblikket i testnet-fase til faellesskabstest.

---

## Bidrag

Bidrag til dokumentationen modtages gerne. Overhold venligst folgende:
- Teknisk njagtighed frem for ordrigdom
- Korte, praecise forklaringer
- Ingen kode eller pseudokode i dokumentationen (referer til kildefiler i stedet)
- Kun som-implementeret (ingen spekulative funktioner)

---

## Licens

Bitcoin-PoCX arver Bitcoin Cores MIT-licens. Se `COPYING` i repository-roden.

PoCX core framework-tilskrivning dokumenteret i [Kapitel 2: Plotformat](2-plot-format.md).

---

**Begynd at laese**: [Kapitel 1: Introduktion og overblik ->](1-introduction.md)
