# Bitcoin-PoCX teknisk dokumentasjon

**Versjon**: 1.0
**Bitcoin Core-grunnlag**: v30.2
**Status**: Testnett-fase
**Sist oppdatert**: 2025-12-25

---

## Om denne dokumentasjonen

Dette er den fullstendige tekniske dokumentasjonen for Bitcoin-PoCX, en Bitcoin Core-integrasjon som legger til støtte for Proof of Capacity neXt generation (PoCX)-konsensus. Dokumentasjonen er organisert som en navigerbar veiledning med sammenkoblede kapitler som dekker alle aspekter av systemet.

**Målgrupper**:
- **Nodeoperatører**: Kapittel 1, 5, 6, 8
- **Minere**: Kapittel 2, 3, 7
- **Utviklere**: Alle kapitler
- **Forskere**: Kapittel 3, 4, 5




## Oversettelser

| | | | | | |
|---|---|---|---|---|---|
| [🇸🇦 Arabisk](../ara/index.md) | [🇧🇬 Bulgarsk](../bul/index.md) | [🇩🇰 Dansk](../dan/index.md) | [🇬🇧 Engelsk](../../index.md) | [🇪🇪 Estisk](../est/index.md) | [🇵🇭 Filippinsk](../fil/index.md) |
| [🇫🇮 Finsk](../fin/index.md) | [🇫🇷 Fransk](../fra/index.md) | [🇬🇷 Gresk](../ell/index.md) | [🇮🇱 Hebraisk](../heb/index.md) | [🇮🇳 Hindi](../hin/index.md) | [🇮🇩 Indonesisk](../ind/index.md) |
| [🇮🇹 Italiensk](../ita/index.md) | [🇯🇵 Japansk](../jpn/index.md) | [🇨🇳 Kinesisk](../zho/index.md) | [🇰🇷 Koreansk](../kor/index.md) | [🇱🇻 Latvisk](../lav/index.md) | [🇱🇹 Litauisk](../lit/index.md) |
| [🇳🇱 Nederlandsk](../nld/index.md) | [🇵🇱 Polsk](../pol/index.md) | [🇵🇹 Portugisisk](../por/index.md) | [🇷🇴 Rumensk](../ron/index.md) | [🇷🇺 Russisk](../rus/index.md) | [🇷🇸 Serbisk](../srp/index.md) |
| [🇪🇸 Spansk](../spa/index.md) | [🇰🇪 Swahili](../swa/index.md) | [🇸🇪 Svensk](../swe/index.md) | [🇨🇿 Tsjekkisk](../ces/index.md) | [🇹🇷 Tyrkisk](../tur/index.md) | [🇩🇪 Tysk](../deu/index.md) |
| [🇺🇦 Ukrainsk](../ukr/index.md) | [🇭🇺 Ungarsk](../hun/index.md) | [🇻🇳 Vietnamesisk](../vie/index.md) | | | |


---

## Innholdsfortegnelse

### Del I: Grunnleggende

**[Kapittel 1: Introduksjon og oversikt](1-introduction.md)**
Prosjektoversikt, arkitektur, designfilosofi, hovedfunksjoner og hvordan PoCX skiller seg fra Proof of Work.

**[Kapittel 2: Plotfilformat](2-plot-format.md)**
Fullstendig spesifikasjon av PoCX-plotformatet, inkludert SIMD-optimalisering, proof-of-work-skalering og formatutvikling fra POC1/POC2.

**[Kapittel 3: Konsensus og mining](3-consensus-and-mining.md)**
Fullstendig teknisk spesifikasjon av PoCX-konsensusmekanismen: blokkstruktur, generasjonssignaturer, base target-justering, miningprosess, valideringspipeline og Time Bending-algoritmen.

---

### Del II: Avanserte funksjoner

**[Kapittel 4: Forging assignment-system](4-forging-assignments.md)**
OP_RETURN-basert arkitektur for delegering av forging-rettigheter: transaksjonsstruktur, databasedesign, tilstandsmaskin, reorganiseringshåndtering og RPC-grensesnitt.

**[Kapittel 5: Tidssynkronisering og sikkerhet](5-timing-security.md)**
Klokkeavvik-toleranse, defensiv forging-mekanisme, anti-klokkemanipulasjon og tidsrelaterte sikkerhetshensyn.

**[Kapittel 6: Nettverksparametere](6-network-parameters.md)**
Chainparams-konfigurasjon, genesis-blokk, konsensusparametere, coinbase-regler, dynamisk skalering og økonomisk modell.

---

### Del III: Bruk og integrasjon

**[Kapittel 7: RPC-grensesnitt-referanse](7-rpc-reference.md)**
Fullstendig RPC-kommandoreferanse for mining, tildelinger og blockchain-spørringer. Essensielt for miner- og pool-integrasjon.

**[Kapittel 8: Lommebok- og GUI-veiledning](8-wallet-guide.md)**
Brukerveiledning for Bitcoin-PoCX Qt-lommeboken: forging assignment-dialog, transaksjonshistorikk, mining-oppsett og feilsøking.

---

## Hurtignavigasjon

### For nodeoperatører
→ Start med [Kapittel 1: Introduksjon](1-introduction.md)
→ Deretter gjennomgå [Kapittel 6: Nettverksparametere](6-network-parameters.md)
→ Konfigurer mining med [Kapittel 8: Lommebokveiledning](8-wallet-guide.md)

### For minere
→ Forstå [Kapittel 2: Plotformat](2-plot-format.md)
→ Lær prosessen i [Kapittel 3: Konsensus og mining](3-consensus-and-mining.md)
→ Integrer ved hjelp av [Kapittel 7: RPC-referanse](7-rpc-reference.md)

### For pool-operatører
→ Gjennomgå [Kapittel 4: Forging assignments](4-forging-assignments.md)
→ Studer [Kapittel 7: RPC-referanse](7-rpc-reference.md)
→ Implementer ved hjelp av assignment-RPC-er og submit_nonce

### For utviklere
→ Les alle kapitler i rekkefølge
→ Kryssreferér implementasjonsfiler som er notert gjennom hele dokumentasjonen
→ Undersøk `src/pocx/`-mappestrukturen
→ Bygg utgivelser med [GUIX](../bitcoin/contrib/guix/README.md)

---

## Dokumentasjonskonvensjoner

**Filreferanser**: Implementasjonsdetaljer refererer til kildefiler som `sti/til/fil.cpp:linje`

**Kodeintegrasjon**: Alle endringer er feature-flagget med `#ifdef ENABLE_POCX`

**Kryssreferanser**: Kapitler lenker til relaterte seksjoner ved hjelp av relative markdown-lenker

**Teknisk nivå**: Dokumentasjonen forutsetter kjennskap til Bitcoin Core og C++-utvikling

---

## Bygging

### Utviklingsbygg

```bash
# Klon med submoduler
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Configure
cmake -B build

# Bygg
cmake --build build -j$(nproc)
```

**Byggevarianter**:
```bash
# Med Qt GUI
cmake -B build -DBUILD_GUI=ON

# Debug-bygg
cmake -B build -DCMAKE_BUILD_TYPE=Debug
```

**Avhengigheter**: Standard Bitcoin Core-byggavhengigheter. Se [Bitcoin Core byggedokumentasjon](https://github.com/bitcoin/bitcoin/tree/master/doc#building) for plattformspesifikke krav.

### Utgivelsesbygg

For reproduserbare utgivelsesbinærfiler, bruk GUIX-byggesystemet: Se [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Tilleggsressurser

**Repository**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCX Core Framework**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Relaterte prosjekter**:
- Plotter: Basert på [engraver](https://github.com/PoC-Consortium/engraver)
- Miner: Basert på [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Hvordan lese denne dokumentasjonen

**Sekvensiell lesing**: Kapitlene er designet for å leses i rekkefølge, og bygger på tidligere konsepter.

**Referanselesing**: Bruk innholdsfortegnelsen for å hoppe direkte til spesifikke emner. Hvert kapittel er selvstendig med kryssreferanser til relatert materiale.

**Nettlesernavigasjon**: Åpne `index.md` i en markdown-visning eller nettleser. Alle interne lenker er relative og fungerer offline.

**PDF-eksport**: Denne dokumentasjonen kan sammenslås til én enkelt PDF for offline-lesing.

---

## Prosjektstatus

**Fullstendig funksjonalitet**: Alle konsensusregler, mining, tildelinger og lommebokfunksjoner er implementert.

**Dokumentasjon fullført**: Alle 8 kapitler er fullstendige og verifisert mot kodebasen.

**Testnett aktivt**: For øyeblikket i testnett-fase for fellesskapstesting.

---

## Bidra

Bidrag til dokumentasjonen mottas med takk. Vennligst oppretthold:
- Teknisk nøyaktighet fremfor ordrikdom
- Korte, konsise forklaringer
- Ingen kode eller pseudokode i dokumentasjonen (referer til kildefiler i stedet)
- Kun implementert funksjonalitet (ingen spekulative funksjoner)

---

## Lisens

Bitcoin-PoCX arver Bitcoin Cores MIT-lisens. Se `bitcoin/COPYING` i repository-roten.

PoCX core framework-attribusjon er dokumentert i [Kapittel 2: Plotformat](2-plot-format.md).

---

**Begynn å lese**: [Kapittel 1: Introduksjon og oversikt →](1-introduction.md)
