# Bitcoin-PoCX Tekninen dokumentaatio

**Versio**: 1.0
**Bitcoin Core -pohja**: v30.0
**Tila**: Testiverkkofase
**Päivitetty viimeksi**: 25.12.2025

---

## Tietoa tästä dokumentaatiosta

Tämä on Bitcoin-PoCX:n täydellinen tekninen dokumentaatio. Bitcoin-PoCX on Bitcoin Core -integraatio, joka lisää Proof of Capacity neXt generation (PoCX) -konsensustuen. Dokumentaatio on järjestetty selattavaksi oppaaksi, jonka luvut ovat yhteydessä toisiinsa ja kattavat järjestelmän kaikki osa-alueet.

**Kohderyhmät**:
- **Solmuoperaattorit**: Luvut 1, 5, 6, 8
- **Louhijat**: Luvut 2, 3, 7
- **Kehittäjät**: Kaikki luvut
- **Tutkijat**: Luvut 3, 4, 5




## Käännökset

| | | | | | |
|---|---|---|---|---|---|
| [🇸🇦 arabia](translations/ara/index.md) | [🇨🇳 kiina](translations/zho/index.md) | [🇳🇱 hollanti](translations/nld/index.md) | [🇫🇷 ranska](translations/fra/index.md) | [🇩🇪 saksa](translations/deu/index.md) | [🇬🇷 kreikka](translations/ell/index.md) |
| [🇮🇱 heprea](translations/heb/index.md) | [🇮🇳 hindi](translations/hin/index.md) | [🇮🇩 indonesia](translations/ind/index.md) | [🇮🇹 italia](translations/ita/index.md) | [🇯🇵 japani](translations/jpn/index.md) | [🇰🇷 korea](translations/kor/index.md) |
| [🇵🇹 portugali](translations/por/index.md) | [🇷🇺 venäjä](translations/rus/index.md) | [🇷🇸 serbia](translations/srp/index.md) | [🇪🇸 espanja](translations/spa/index.md) | [🇹🇷 turkki](translations/tur/index.md) | [🇺🇦 ukraina](translations/ukr/index.md) |
| [🇻🇳 vietnam](translations/vie/index.md) | | | | | |


---

## Sisällysluettelo

### Osa I: Perusteet

**[Luku 1: Johdanto ja yleiskatsaus](1-introduction.md)**
Projektin yleiskatsaus, arkkitehtuuri, suunnittelufilosofia, keskeiset ominaisuudet ja miten PoCX eroaa Proof of Work -konsensuksesta.

**[Luku 2: Plottitiedostomuoto](2-plot-format.md)**
PoCX-plottimuodon täydellinen määrittely, mukaan lukien SIMD-optimointi, proof-of-work-skaalaus ja muodon kehitys POC1/POC2:sta.

**[Luku 3: Konsensus ja louhinta](3-consensus-and-mining.md)**
PoCX-konsensusmekanismin täydellinen tekninen määrittely: lohkorakenne, generoinnin allekirjoitukset, perustavoitteen säätö, louhintaprosessi, validointiputki ja Time Bending -algoritmi.

---

### Osa II: Edistyneet ominaisuudet

**[Luku 4: Forging-delegointijärjestelmä](4-forging-assignments.md)**
OP_RETURN-pohjainen arkkitehtuuri forging-oikeuksien delegointiin: transaktiorakenne, tietokantasuunnittelu, tilakoneen toiminta, uudelleenjärjestelyn käsittely ja RPC-rajapinta.

**[Luku 5: Aikasynkronointi ja turvallisuus](5-timing-security.md)**
Kellodriftin toleranssi, puolustava forging-mekanismi, kellon manipuloinnin esto ja ajoitukseen liittyvät turvallisuusnäkökohdat.

**[Luku 6: Verkkoparametrit](6-network-parameters.md)**
Chainparams-konfiguraatio, genesis-lohko, konsensusparametrit, coinbase-säännöt, dynaaminen skaalaus ja talousmalli.

---

### Osa III: Käyttö ja integraatio

**[Luku 7: RPC-rajapintaviite](7-rpc-reference.md)**
Täydellinen RPC-komentoviite louhintaan, delegointeihin ja lohkoketjukyselyihin. Välttämätön louhijoiden ja poolien integraatioon.

**[Luku 8: Lompakko- ja käyttöliittymäopas](8-wallet-guide.md)**
Käyttöopas Bitcoin-PoCX Qt -lompakolle: forging-delegointidialogi, transaktiohistoria, louhinnan asetukset ja vianetsintä.

---

## Pikalinkit

### Solmuoperaattoreille
→ Aloita [Luvusta 1: Johdanto](1-introduction.md)
→ Tutustu sitten [Lukuun 6: Verkkoparametrit](6-network-parameters.md)
→ Määritä louhinta [Luvun 8: Lompakko-opas](8-wallet-guide.md) avulla

### Louhijoille
→ Ymmärrä [Luku 2: Plottimuoto](2-plot-format.md)
→ Opi prosessi [Luvusta 3: Konsensus ja louhinta](3-consensus-and-mining.md)
→ Integroi [Luvun 7: RPC-viite](7-rpc-reference.md) avulla

### Poolioperaattoreille
→ Tutustu [Lukuun 4: Forging-delegoinnit](4-forging-assignments.md)
→ Perehdy [Lukuun 7: RPC-viite](7-rpc-reference.md)
→ Toteuta delegointi-RPC:iden ja submit_nonce-komennon avulla

### Kehittäjille
→ Lue kaikki luvut järjestyksessä
→ Tutki viittaukset toteutustiedostoihin dokumentaation läpi
→ Tutustu `src/pocx/`-hakemistorakenteeseen
→ Luo julkaisut [GUIX:n](../bitcoin/contrib/guix/README.md) avulla

---

## Dokumentaatiokäytännöt

**Tiedostoviittaukset**: Toteutusyksityiskohdat viittaavat lähdetiedostoihin muodossa `polku/tiedostoon.cpp:rivi`

**Koodin integraatio**: Kaikki muutokset on merkitty feature-liputuksella `#ifdef ENABLE_POCX`

**Ristiviittaukset**: Luvut linkittyvät toisiinsa suhteellisilla markdown-linkeillä

**Tekninen taso**: Dokumentaatio olettaa tuntemusta Bitcoin Coreen ja C++-kehitykseen

---

## Rakentaminen

### Kehitysbuildi

```bash
# Kloonaa alimoduuleineen
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Konfiguroi PoCX käyttöön
cmake -B build -DENABLE_POCX=ON

# Rakenna
cmake --build build -j$(nproc)
```

**Buildivariantit**:
```bash
# Qt-käyttöliittymällä
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Debug-buildi
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Riippuvuudet**: Samat kuin Bitcoin Coren standardibuildivaatimukset. Katso [Bitcoin Core -rakennusdokumentaatio](https://github.com/bitcoin/bitcoin/tree/master/doc#building) alustakohtaisiin vaatimuksiin.

### Julkaisubuildit

Toistettaviin julkaisutiedostoihin käytä GUIX-rakennusjärjestelmää: Katso [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Lisäresurssit

**Repositorio**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**PoCX Core -kehys**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Liittyvät projektit**:
- Plotteri: Perustuu [engraver](https://github.com/PoC-Consortium/engraver)-projektiin
- Louhija: Perustuu [scavenger](https://github.com/PoC-Consortium/scavenger)-projektiin

---

## Kuinka lukea tätä dokumentaatiota

**Peräkkäinen lukeminen**: Luvut on suunniteltu luettavaksi järjestyksessä, sillä ne rakentuvat aiempien käsitteiden päälle.

**Viitelukeminen**: Käytä sisällysluetteloa siirtyäksesi suoraan haluamiisi aiheisiin. Jokainen luku on itsenäinen ja sisältää ristiviittauksia liittyvään materiaaliin.

**Selainnavigaatio**: Avaa `index.md` markdown-katselimessa tai selaimessa. Kaikki sisäiset linkit ovat suhteellisia ja toimivat offline-tilassa.

**PDF-vienti**: Tämä dokumentaatio voidaan yhdistää yhdeksi PDF-tiedostoksi offline-lukemista varten.

---

## Projektin tila

**Ominaisuudet valmiit**: Kaikki konsensussäännöt, louhinta, delegoinnit ja lompakko-ominaisuudet toteutettu.

**Dokumentaatio valmis**: Kaikki 8 lukua valmiina ja tarkistettu koodipohjaa vasten.

**Testiverkko aktiivinen**: Tällä hetkellä testiverkkofasissa yhteisön testausta varten.

---

## Osallistuminen

Dokumentaatioon osallistuminen on tervetullutta. Säilytä:
- Tekninen tarkkuus monisanaisuuden sijaan
- Lyhyet, ytimekkäät selitykset
- Ei koodia tai pseudokoodia dokumentaatiossa (viittaa sen sijaan lähdetiedostoihin)
- Vain toteutetut ominaisuudet (ei spekulatiivisia ominaisuuksia)

---

## Lisenssi

Bitcoin-PoCX perii Bitcoin Coren MIT-lisenssin. Katso `COPYING` repositorion juurihakemistossa.

PoCX-ydinkehyksen attribuutio dokumentoitu [Luvussa 2: Plottimuoto](2-plot-format.md).

---

**Aloita lukeminen**: [Luku 1: Johdanto ja yleiskatsaus →](1-introduction.md)
