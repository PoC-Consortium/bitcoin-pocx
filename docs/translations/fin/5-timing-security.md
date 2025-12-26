[← Edellinen: Forging-delegoinnit](4-forging-assignments.md) | [Sisällysluettelo](index.md) | [Seuraava: Verkkoparametrit →](6-network-parameters.md)

---

# Luku 5: Aikasynkronointi ja turvallisuus

## Yleiskatsaus

PoCX-konsensus vaatii tarkkaa aikasynkronointia koko verkon kesken. Tämä luku dokumentoi aikaan liittyvät turvallisuusmekanismit, kellodriftin toleranssin ja puolustavan forging-käyttäytymisen.

**Keskeiset mekanismit**:
- 15 sekunnin tulevaisuustoleranssi lohkojen aikaleimoille
- 10 sekunnin kellodriftin varoitusjärjestelmä
- Puolustava forging (kellon manipuloinnin esto)
- Time Bending -algoritmin integraatio

---

## Sisällysluettelo

1. [Aikasynkronointivaatimukset](#aikasynkronointivaatimukset)
2. [Kellodriftin tunnistus ja varoitukset](#kellodriftin-tunnistus-ja-varoitukset)
3. [Puolustava forging-mekanismi](#puolustava-forging-mekanismi)
4. [Turvallisuusuhka-analyysi](#turvallisuusuhka-analyysi)
5. [Parhaat käytännöt solmuoperaattoreille](#parhaat-käytännöt-solmuoperaattoreille)

---

## Aikasynkronointivaatimukset

### Vakiot ja parametrit

**Bitcoin-PoCX-konfiguraatio:**
```cpp
// src/chain.h:31
static constexpr int64_t MAX_FUTURE_BLOCK_TIME = 15;  // 15 sekuntia

// src/node/timeoffsets.h:27
static constexpr std::chrono::seconds WARN_THRESHOLD{10};  // 10 sekuntia
```

### Validointitarkistukset

**Lohkon aikaleiman validointi** (`src/validation.cpp:4547-4561`):
```cpp
// 1. Monotonisuustarkistus: aikaleima >= edellisen lohkon aikaleima
if (block.nTime < pindexPrev->nTime) {
    return state.Invalid("time-too-old");
}

// 2. Tulevaisuustarkistus: aikaleima <= nyt + 15 sekuntia
if (block.Time() > NodeClock::now() + std::chrono::seconds{MAX_FUTURE_BLOCK_TIME}) {
    return state.Invalid("time-too-new");
}

// 3. Deadlinen tarkistus: kulunut aika >= deadline
uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
if (result.deadline > elapsed_time) {
    return state.Invalid("bad-pocx-timing");
}
```

### Kellodriftin vaikutustaulukko

| Kellon siirtymä | Voiko synkronoida? | Voiko louhia? | Validointitila | Kilpailuvaikutus |
|--------------|-----------|-----------|-------------------|-------------------|
| -30s jäljessä | EI - Tulevaisuustarkistus epäonnistuu | Ei sovellettavissa | **KUOLLUT SOLMU** | Ei voi osallistua |
| -14s jäljessä | Kyllä | Kyllä | Myöhäinen forging, läpäisee validoinnin | Häviää kilpailut |
| 0s täsmällinen | Kyllä | Kyllä | Optimaalinen | Optimaalinen |
| +14s edellä | Kyllä | Kyllä | Aikainen forging, läpäisee validoinnin | Voittaa kilpailut |
| +16s edellä | Kyllä | EI - Tulevaisuustarkistus epäonnistuu | Ei voi propagoida lohkoja | Voi synkronoida, ei louhia |

**Keskeinen oivallus**: 15 sekunnin ikkuna on symmetrinen osallistumiselle (±14,9s), mutta nopeat kellot tarjoavat epäreilun kilpailuedun toleranssin puitteissa.

### Time Bending -integraatio

Time Bending -algoritmi (kuvailtu yksityiskohtaisesti [Luvussa 3](3-consensus-and-mining.md#aikataivutuksen-laskenta)) muuntaa raa'at deadlinet kuutiojuurella:

```
time_bended_deadline = scale × (deadline_seconds)^(1/3)
```

**Vuorovaikutus kellodriftin kanssa**:
- Paremmat ratkaisut forgataan nopeammin (kuutiojuuri vahvistaa laatueroja)
- Kellodrifti vaikuttaa forging-aikaan suhteessa verkkoon
- Puolustava forging varmistaa laatupohjaisen kilpailun ajoitusvaihtelusta huolimatta

---

## Kellodriftin tunnistus ja varoitukset

### Varoitusjärjestelmä

Bitcoin-PoCX seuraa aikaeroa paikallisen solmun ja verkon vertaisten välillä.

**Varoitusviesti** (kun drifti ylittää 10 sekuntia):
> "Tietokoneesi päivämäärä ja aika näyttävät olevan yli 10 sekuntia poikki synkronista verkon kanssa, tämä voi johtaa PoCX-konsensusvirheeseen. Tarkista järjestelmäsi kello."

**Toteutus**: `src/node/timeoffsets.cpp`

### Suunnittelun perustelu

**Miksi 10 sekuntia?**
- Tarjoaa 5 sekunnin turvamarginaalin ennen 15 sekunnin toleranssirajaa
- Tiukempi kuin Bitcoin Coren oletus (10 minuuttia)
- Sopiva PoC-ajoitusvaatimuksiin

**Ennaltaehkäisevä lähestymistapa**:
- Varhainen varoitus ennen kriittistä virhettä
- Mahdollistaa operaattoreiden korjata ongelmat ennakoivasti
- Vähentää verkon fragmentoitumista aikaan liittyvistä virheistä

---

## Puolustava forging-mekanismi

### Mikä se on

Puolustava forging on vakio louhijakäyttäytyminen Bitcoin-PoCX:ssä, joka poistaa ajoituspohjaiset edut lohkon tuotannossa. Kun louhijasi vastaanottaa kilpailevan lohkon samalla korkeudella, se tarkistaa automaattisesti onko sinulla parempi ratkaisu. Jos on, se forgaa lohkosi välittömästi, varmistaen laatupohjaisen kilpailun kellon manipuloinnin sijaan.

### Ongelma

PoCX-konsensus sallii lohkot, joiden aikaleimat ovat enintään 15 sekuntia tulevaisuudessa. Tämä toleranssi on välttämätön globaalille verkkosynkronoinnille. Se kuitenkin luo mahdollisuuden kellon manipuloinnille:

**Ilman puolustavaa forgingia:**
- Louhija A: Oikea aika, laatu 800 (parempi), odottaa oikean deadlinen
- Louhija B: Nopea kello (+14s), laatu 1000 (huonompi), forgaa 14 sekuntia aikaisin
- Tulos: Louhija B voittaa kilpailun huonommasta kapasiteetin todistuksesta huolimatta

**Ongelma:** Kellon manipulointi tarjoaa etua jopa huonommalla laadulla, heikentäen proof-of-capacity-periaatetta.

### Ratkaisu: Kaksitasoinen puolustus

#### Taso 1: Kellodriftin varoitus (ennaltaehkäisevä)

Bitcoin-PoCX seuraa aikaeroa solmusi ja verkon vertaisten välillä. Jos kellosi ajautuu yli 10 sekuntia verkon konsensuksesta, saat varoituksen, joka kehottaa korjaamaan kello-ongelmat ennen kuin ne aiheuttavat ongelmia.

#### Taso 2: Puolustava forging (reaktiivinen)

Kun toinen louhija julkaisee lohkon samalla korkeudella kuin olet louhimassa:

1. **Tunnistus**: Solmusi tunnistaa saman korkeuden kilpailun
2. **Validointi**: Poimii ja validoi kilpailevan lohkon laadun
3. **Vertailu**: Tarkistaa onko sinun laatusi parempi
4. **Vastaus**: Jos parempi, forgaa lohkosi välittömästi

**Tulos:** Verkko vastaanottaa molemmat lohkot ja valitsee paremman laadun perusteella vakio haarukan ratkaisun kautta.

### Kuinka se toimii

#### Skenaario: Saman korkeuden kilpailu

```
Aika 150s: Louhija B (kello +10s) forgaa laadulla 1000
           → Lohkon aikaleima näyttää 160s (10s tulevaisuudessa)

Aika 150s: Solmusi vastaanottaa louhija B:n lohkon
           → Tunnistaa: sama korkeus, laatu 1000
           → Sinulla on: laatu 800 (parempi!)
           → Toiminto: Forgaa välittömästi oikealla aikaleimalla (150s)

Aika 152s: Verkko validoi molemmat lohkot
           → Molemmat kelvollisia (15s toleranssin sisällä)
           → Laatu 800 voittaa (pienempi = parempi)
           → Sinun lohkosi tulee ketjun kärjeksi
```

#### Skenaario: Aito uudelleenjärjestely

```
Louhintakorkeusi 100, kilpailija julkaisee lohkon 99
→ Ei saman korkeuden kilpailua
→ Puolustava forging EI käynnisty
→ Normaali reorg-käsittely etenee
```

### Hyödyt

**Nolla kannustinta kellon manipuloinnille**
- Nopeat kellot auttavat vain jos sinulla on jo paras laatu
- Kellon manipulointi tulee taloudellisesti turhaksi

**Laatupohjainen kilpailu pakotettu**
- Pakottaa louhijat kilpailemaan todellisella kapasiteetin todistustyöllä
- Säilyttää PoCX-konsensuksen eheyden

**Verkkoturvallisuus**
- Vastustuskykyinen ajoituspohjaisille pelistrategioille
- Ei konsensusmuutoksia vaadittu – puhdasta louhijakäyttäytymistä

**Täysin automaattinen**
- Ei konfigurointia tarvita
- Käynnistyy vain tarvittaessa
- Vakiokäyttäytyminen kaikissa Bitcoin-PoCX-solmuissa

### Kompromissit

**Minimaalinen orpoudutusasteen kasvu**
- Tarkoituksellinen – hyökkäyslohkot orpoutuvat
- Tapahtuu vain todellisten kellon manipulointiyritysten aikana
- Luonnollinen tulos laadun perustuvasta haarukan ratkaisusta

**Lyhyt verkkokilpailu**
- Verkko näkee lyhyesti kaksi kilpailevaa lohkoa
- Ratkeaa sekunneissa vakiovalidoinnin kautta
- Sama käyttäytyminen kuin samanaikainen louhinta Bitcoinissa

### Tekniset yksityiskohdat

**Suorituskykyvaikutus:** Merkityksetön
- Käynnistyy vain saman korkeuden kilpailussa
- Käyttää muistissa olevaa dataa (ei levyn I/O:ta)
- Validointi valmistuu millisekunneissa

**Resurssinkäyttö:** Minimaalinen
- ~20 riviä ydinlogiikkaa
- Uudelleenkäyttää olemassa olevaa validointi-infrastruktuuria
- Yksi lukon hankinta

**Yhteensopivuus:** Täysi
- Ei konsensussääntömuutoksia
- Toimii kaikkien Bitcoin Core -ominaisuuksien kanssa
- Valinnainen seuranta debug-lokien kautta

**Tila**: Aktiivinen kaikissa Bitcoin-PoCX-julkaisuissa
**Ensimmäinen käyttöönotto**: 10.10.2025

---

## Turvallisuusuhka-analyysi

### Nopean kellon hyökkäys (lievennetty puolustavalla forgingilla)

**Hyökkäysvektori**:
Louhija kellolla **+14s edellä** voi:
1. Vastaanottaa lohkoja normaalisti (näyttävät vanhoilta hänelle)
2. Forgata lohkoja välittömästi kun deadline täyttyy
3. Lähettää lohkoja jotka näyttävät 14s "aikaisilta" verkolle
4. **Lohkot hyväksytään** (15s toleranssin sisällä)
5. **Voittaa kilpailut** rehellisiä louhijoita vastaan

**Vaikutus ilman puolustavaa forgingia**:
Etu rajoittuu 14,9 sekuntiin (ei riittävästi ohittamaan merkittävää PoC-työtä), mutta tarjoaa johdonmukaisen etulyöntiaseman lohkokisoissa.

**Lievennys (puolustava forging)**:
- Rehelliset louhijat tunnistavat saman korkeuden kilpailun
- Vertaavat laatuarvoja
- Forgataan välittömästi jos laatu on parempi
- **Tulos**: Nopea kello auttaa vain jos sinulla on jo paras laatu
- **Kannustin**: Nolla – kellon manipulointi tulee taloudellisesti turhaksi

### Hitaan kellon virhe (kriittinen)

**Virhetila**:
Solmu **>15s jäljessä** on katastrofaalinen:
- Ei voi validoida saapuvia lohkoja (tulevaisuustarkistus epäonnistuu)
- Eristäytyy verkosta
- Ei voi louhia tai synkronoida

**Lievennys**:
- Vahva varoitus 10s driftillä antaa 5 sekunnin puskurin ennen kriittistä virhettä
- Operaattorit voivat korjata kello-ongelmat ennakoivasti
- Selkeät virheilmoitukset ohjaavat vianetsintää

---

## Parhaat käytännöt solmuoperaattoreille

### Aikasynkronoinnin asetukset

**Suositeltu konfiguraatio**:
1. **Ota NTP käyttöön**: Käytä Network Time Protocolia automaattiseen synkronointiin
   ```bash
   # Linux (systemd-timesyncd)
   sudo timedatectl set-ntp true

   # Tarkista tila
   timedatectl status
   ```

2. **Varmenna kellon tarkkuus**: Tarkista säännöllisesti aikaero
   ```bash
   # Tarkista NTP-synkronoinnin tila
   ntpq -p

   # Tai chronyn kanssa
   chronyc tracking
   ```

3. **Seuraa varoituksia**: Tarkkaile Bitcoin-PoCX:n kellodriftivaroituksia lokeissa

### Louhijoille

**Toimenpiteitä ei tarvita**:
- Ominaisuus on aina aktiivinen
- Toimii automaattisesti
- Pidä vain järjestelmäkellosi tarkkana

**Parhaat käytännöt**:
- Käytä NTP-aikasynkronointia
- Seuraa kellodriftivaroituksia
- Reagoi varoituksiin nopeasti jos niitä ilmenee

**Odotettu käyttäytyminen**:
- Yksinlouhinta: Puolustava forging käynnistyy harvoin (ei kilpailua)
- Verkkolouhinta: Suojaa kellon manipulointiyrityksiltä
- Läpinäkyvä toiminta: Useimmat louhijat eivät koskaan huomaa sitä

### Vianetsintä

**Varoitus: "10 sekuntia poikki synkronista"**
- Toiminto: Tarkista ja korjaa järjestelmän kellon synkronointi
- Vaikutus: 5 sekunnin puskuri ennen kriittistä virhettä
- Työkalut: NTP, chrony, systemd-timesyncd

**Virhe: "time-too-new" saapuvilla lohkoilla**
- Syy: Kellosi on >15 sekuntia jäljessä
- Vaikutus: Ei voi validoida lohkoja, solmu eristäytyy
- Korjaus: Synkronoi järjestelmäkello välittömästi

**Virhe: Ei voi propagoida forgattuja lohkoja**
- Syy: Kellosi on >15 sekuntia edellä
- Vaikutus: Verkko hylkää lohkot
- Korjaus: Synkronoi järjestelmäkello välittömästi

---

## Suunnittelupäätökset ja perustelut

### Miksi 15 sekunnin toleranssi?

**Perustelu**:
- Bitcoin-PoCX:n muuttuva deadline-ajoitus on vähemmän aikakriittinen kuin kiinteän ajoituksen konsensus
- 15s tarjoaa riittävän suojan samalla estäen verkon fragmentoitumisen

**Kompromissit**:
- Tiukempi toleranssi = enemmän verkon fragmentoitumista pienestä driftistä
- Löysempi toleranssi = enemmän mahdollisuuksia ajoitushyökkäyksille
- 15s tasapainottaa turvallisuutta ja robustisuutta

### Miksi 10 sekunnin varoitus?

**Perustelu**:
- Tarjoaa 5 sekunnin turvamarginaalin
- Sopivampi PoC:lle kuin Bitcoinin 10 minuutin oletus
- Mahdollistaa ennakoivat korjaukset ennen kriittistä virhettä

### Miksi puolustava forging?

**Ratkaistu ongelma**:
- 15 sekunnin toleranssi mahdollistaa nopean kellon edun
- Laatupohjainen konsensus voitaisiin heikentää ajoituksen manipuloinnilla

**Ratkaisun hyödyt**:
- Nollakustannuspuolustus (ei konsensusmuutoksia)
- Automaattinen toiminta
- Poistaa hyökkäyskannustimen
- Säilyttää proof-of-capacity-periaatteet

### Miksi ei verkon sisäistä aikasynkronointia?

**Turvallisuusperustelu**:
- Moderni Bitcoin Core poisti vertaispohjaisen ajan säädön
- Haavoittuva Sybil-hyökkäyksille havaitun verkkoajan suhteen
- PoCX välttää tarkoituksella luottamasta verkon sisäisiin aikalähteisiin
- Järjestelmäkello on luotettavampi kuin vertaisten konsensus
- Operaattoreiden tulisi synkronoida NTP:llä tai vastaavalla ulkoisella aikalähteellä
- Solmut seuraavat omaa driftiään ja lähettävät varoituksia jos paikallinen kello erkaantuu viimeaikaisista lohkojen aikaleimoista

---

## Toteutusviittaukset

**Ydintiedostot**:
- Aikavalidointi: `src/validation.cpp:4547-4561`
- Tulevaisuustoleranssivakio: `src/chain.h:31`
- Varoituskynnys: `src/node/timeoffsets.h:27`
- Aikaeron seuranta: `src/node/timeoffsets.cpp`
- Puolustava forging: `src/pocx/mining/scheduler.cpp`

**Liittyvä dokumentaatio**:
- Time Bending -algoritmi: [Luku 3: Konsensus ja louhinta](3-consensus-and-mining.md#aikataivutuksen-laskenta)
- Lohkon validointi: [Luku 3: Lohkon validointi](3-consensus-and-mining.md#lohkon-validointi)

---

**Luotu**: 10.10.2025
**Tila**: Täydellinen toteutus
**Kattavuus**: Aikasynkronointivaatimukset, kellodriftin käsittely, puolustava forging

---

[← Edellinen: Forging-delegoinnit](4-forging-assignments.md) | [Sisällysluettelo](index.md) | [Seuraava: Verkkoparametrit →](6-network-parameters.md)
