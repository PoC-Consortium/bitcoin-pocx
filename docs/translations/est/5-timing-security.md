[<- Eelmine: Sepistamisülesanded](4-forging-assignments.md) | [Sisukord](index.md) | [Järgmine: Võrguparameetrid ->](6-network-parameters.md)

---

# Peatükk 5: Ajasünkroniseerimine ja turvalisus

## Ülevaade

PoCX konsensus nõuab täpset ajasünkroniseerimist üle võrgu. See peatükk dokumenteerib ajaga seotud turvamehhanisme, kellanihe tolerantsi ja kaitsva sepistamise käitumist.

**Põhimehhanismid**:
- 15-sekundiline tuleviku tolerants ploki ajatemplidele
- 10-sekundiline kellanihe hoiatussüsteem
- Kaitsev sepistamine (kellamanipuleerimise vastane)
- Ajapainde algoritmi integratsioon

---

## Sisukord

1. [Ajasünkroniseerimise nõuded](#ajasünkroniseerimise-nõuded)
2. [Kellanihe tuvastamine ja hoiatused](#kellanihe-tuvastamine-ja-hoiatused)
3. [Kaitsev sepistamismehhanism](#kaitsev-sepistamismehhanism)
4. [Turvaohule analüüs](#turvaohtude-analüüs)
5. [Parimad praktikad sõlmeoperaatoritele](#parimad-praktikad-sõlmeoperaatoritele)

---

## Ajasünkroniseerimise nõuded

### Konstandid ja parameetrid

**Bitcoin-PoCX konfiguratsioon:**
```cpp
// src/chain.h:31
static constexpr int64_t MAX_FUTURE_BLOCK_TIME = 15;  // 15 sekundit

// src/node/timeoffsets.h:27
static constexpr std::chrono::seconds WARN_THRESHOLD{10};  // 10 sekundit
```

### Valideerimise kontrollid

**Ploki ajatempli valideerimine** (`src/validation.cpp:4547-4561`):
```cpp
// 1. Monotoonne kontroll: ajatempel >= eelmise ploki ajatempel
if (block.nTime < pindexPrev->nTime) {
    return state.Invalid("time-too-old");
}

// 2. Tuleviku kontroll: ajatempel <= praegu + 15 sekundit
if (block.Time() > NodeClock::now() + std::chrono::seconds{MAX_FUTURE_BLOCK_TIME}) {
    return state.Invalid("time-too-new");
}

// 3. Tähtaja kontroll: möödunud aeg >= tähtaeg
uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
if (result.deadline > elapsed_time) {
    return state.Invalid("bad-pocx-timing");
}
```

### Kellanihe mõjutabel

| Kella nihe | Saab sünkroniseerida? | Saab kaevandada? | Valideerimise staatus | Konkurentsimõju |
|------------|----------------------|------------------|----------------------|-----------------|
| -30s aeglane | EI - Tuleviku kontroll ebaõnnestub | Ei kohaldu | **SURNUD SÕLM** | Ei saa osaleda |
| -14s aeglane | JAH | JAH | Hiline sepistamine, läbib valideerimise | Kaotab võidujooksud |
| 0s täpne | JAH | JAH | Optimaalne | Optimaalne |
| +14s kiire | JAH | JAH | Varane sepistamine, läbib valideerimise | Võidab võidujooksud |
| +16s kiire | JAH | EI - Tuleviku kontroll ebaõnnestub | Ei saa plokke levitada | Saab sünkroniseerida, ei saa kaevandada |

**Põhiline taipamine**: 15-sekundiline aken on sümmeetriline osalemiseks (±14.9s), kuid kiired kellad annavad ebaõiglase konkurentsieelise tolerantsi piires.

### Ajapainde integratsioon

Ajapainde algoritm (detailselt kirjeldatud [Peatükk 3](3-consensus-and-mining.md#ajapainde-arvutamine)) teisendab töötlemata tähtajad kuupjuurega:

```
time_bended_deadline = scale × (deadline_seconds)^(1/3)
```

**Koostoime kellanihega**:
- Paremad lahendused sepistavad varem (kuupjuur võimendab kvaliteedi erinevusi)
- Kellanihe mõjutab sepistamisaega võrreldes võrguga
- Kaitsev sepistamine tagab kvaliteedipõhise konkurentsi hoolimata ajastuse varieeruvusest

---

## Kellanihe tuvastamine ja hoiatused

### Hoiatussüsteem

Bitcoin-PoCX jälgib ajanihett kohaliku sõlme ja võrgu partnerite vahel.

**Hoiatusteade** (kui nihe ületab 10 sekundit):
> "Teie arvuti kuupäev ja kellaaeg näivad olevat üle 10 sekundi võrgust erinevad, see võib põhjustada PoCX konsensuse ebaõnnestumist. Palun kontrollige oma süsteemikella."

**Implementatsioon**: `src/node/timeoffsets.cpp`

### Disaini põhjendus

**Miks 10 sekundit?**
- Pakub 5-sekundilist ohutuspuhvrit enne 15-sekundilist tolerantspiiri
- Rangem kui Bitcoin Core'i vaikimisi (10 minutit)
- Sobiv PoC ajastusnõuetele

**Ennetav lähenemine**:
- Varajane hoiatus enne kriitilist ebaõnnestumist
- Võimaldab operaatoritel probleeme ennetavalt lahendada
- Vähendab võrgu fragmenteerumist ajaga seotud ebaõnnestumistest

---

## Kaitsev sepistamismehhanism

### Mis see on

Kaitsev sepistamine on standardne kaevandaja käitumine Bitcoin-PoCX-is, mis elimineerib ajastuspõhised eelised ploki tootmisel. Kui teie kaevandaja saab konkureeriva ploki samal kõrgusel, kontrollib see automaatselt, kas teil on parem lahendus. Kui jah, sepistab kohe teie ploki, tagades kvaliteedipõhise konkurentsi kellamanipuleerimise põhise asemel.

### Probleem

PoCX konsensus lubab plokke ajatemplidega kuni 15 sekundit tulevikus. See tolerants on vajalik globaalseks võrgu sünkroniseerimiseks. Siiski loob see võimaluse kellamanipuleerimiseks:

**Ilma kaitsva sepistamiseta:**
- Kaevandaja A: Korrektne aeg, kvaliteet 800 (parem), ootab õiget tähtaega
- Kaevandaja B: Kiire kell (+14s), kvaliteet 1000 (halvem), sepistab 14 sekundit varem
- Tulemus: Kaevandaja B võidab võidujooksu hoolimata kehvemast mahtutõestuse tööst

**Probleem:** Kellamanipuleerimine annab eelise isegi halvema kvaliteediga, õõnestades mahtutõestuse põhimõtet.

### Lahendus: Kahekihiline kaitse

#### Kiht 1: Kellanihe hoiatus (ennetav)

Bitcoin-PoCX jälgib ajanihett teie sõlme ja võrgu partnerite vahel. Kui teie kell nihkub rohkem kui 10 sekundit võrgu konsensusest, saate hoiatuse, mis teavitab teid kellaprobleemide lahendamisest enne, kui need probleeme põhjustavad.

#### Kiht 2: Kaitsev sepistamine (reaktiivne)

Kui teine kaevandaja avaldab ploki samal kõrgusel, mida teie kaevandate:

1. **Tuvastamine**: Teie sõlm tuvastab sama-kõrguse konkurentsi
2. **Valideerimine**: Ekstrakteerib ja valideerib konkureeriva ploki kvaliteedi
3. **Võrdlus**: Kontrollib, kas teie kvaliteet on parem
4. **Vastus**: Kui parem, sepistab teie ploki kohe

**Tulemus:** Võrk saab mõlemad plokid ja valib parema kvaliteediga ploki standardse hargnemiselahenduse kaudu.

### Kuidas see töötab

#### Stsenaarium: Sama-kõrguse konkurents

```
Aeg 150s: Kaevandaja B (kell +10s) sepistab kvaliteediga 1000
          -> Ploki ajatempel näitab 160s (10s tulevikus)

Aeg 150s: Teie sõlm saab kaevandaja B ploki
          -> Tuvastab: sama kõrgus, kvaliteet 1000
          -> Teil on: kvaliteet 800 (parem!)
          -> Tegevus: Sepista kohe korrektse ajatempliga (150s)

Aeg 152s: Võrk valideerib mõlemad plokid
          -> Mõlemad kehtivad (15s tolerantsi piires)
          -> Kvaliteet 800 võidab (madalam = parem)
          -> Teie plokist saab ahela tipp
```

#### Stsenaarium: Tõeline ümberkorraldus

```
Teie kaevandamise kõrgus 100, konkurent avaldab ploki 99
-> Pole sama-kõrguse konkurents
-> Kaitsev sepistamine EI käivitu
-> Normaalne ümberkorralduse käsitlemine jätkub
```

### Eelised

**Null stiimul kellamanipuleerimiseks**
- Kiired kellad aitavad ainult siis, kui teil juba on parim kvaliteet
- Kellamanipuleerimine muutub majanduslikult mõttetuks

**Kvaliteedipõhine konkurents jõustatud**
- Sunnib kaevandajaid konkureerima tegeliku mahtutõestuse tööga
- Säilitab PoCX konsensuse terviklikkuse

**Võrgu turvalisus**
- Vastupidav ajastuspõhistele mängustrateegiatele
- Konsensuse muudatusi pole vaja - puhas kaevandaja käitumine

**Täielikult automaatne**
- Konfigureerimist pole vaja
- Käivitub ainult vajadusel
- Standardne käitumine kõigis Bitcoin-PoCX sõlmedes

### Kompromissid

**Minimaalne orvude määra suurenemine**
- Tahtlik - rünnakuplokid jäävad orvuks
- Esineb ainult tegelike kellamanipuleerimise katsete ajal
- Loomulik tulemus kvaliteedipõhisest hargnemiselahendusest

**Lühike võrgu konkurents**
- Võrk näeb lühidalt kahte konkureerivat plokki
- Laheneb sekunditega standardse valideerimise kaudu
- Sama käitumine kui samaaegne kaevandamine Bitcoin'is

### Tehnilised detailid

**Jõudluse mõju:** Tühine
- Käivitub ainult sama-kõrguse konkurentsi korral
- Kasutab mälus olevaid andmeid (pole ketta I/O-d)
- Valideerimine lõpeb millisekunditega

**Ressursside kasutus:** Minimaalne
- ~20 rida põhiloogikat
- Taaskasutab olemasolevat valideerimise infrastruktuuri
- Üks luku haaramine

**Ühilduvus:** Täielik
- Konsensusreeglite muudatusi pole
- Töötab kõigi Bitcoin Core funktsioonidega
- Valikuline jälgimine silumislogide kaudu

**Staatus**: Aktiivne kõigis Bitcoin-PoCX väljalasetes
**Esmakordselt kasutusele võetud**: 2025-10-10

---

## Turvaohtude analüüs

### Kiire kella rünnak (leevendatud kaitsva sepistamisega)

**Rünnakuvektor**:
Kaevandaja kellaga **+14s ees** saab:
1. Saada plokke normaalselt (näivad neile vanad)
2. Sepistada plokke kohe, kui tähtaeg saabub
3. Edastada plokke, mis näivad võrgule 14s "vara"
4. **Plokid aktsepteeritakse** (15s tolerantsi piires)
5. **Võidab võidujooksud** ausate kaevandajate vastu

**Mõju ilma kaitsva sepistamiseta**:
Eelis on piiratud 14.9 sekundile (mitte piisav olulise PoC töö vahelejätmiseks), kuid annab järjepideva eelise plokkide võidujooksudes.

**Leevendus (kaitsev sepistamine)**:
- Ausad kaevandajad tuvastavad sama-kõrguse konkurentsi
- Võrdlevad kvaliteediväärtusi
- Sepistavad kohe, kui kvaliteet on parem
- **Tulemus**: Kiire kell aitab ainult siis, kui teil juba on parim kvaliteet
- **Stiimul**: Null - kellamanipuleerimine muutub majanduslikult mõttetuks

### Aeglase kella ebaõnnestumine (kriitiline)

**Ebaõnnestumise režiim**:
Sõlm **>15s maas** on katastroofiline:
- Ei saa valideerida sissetulevaid plokke (tuleviku kontroll ebaõnnestub)
- Isoleerub võrgust
- Ei saa kaevandada ega sünkroniseerida

**Leevendus**:
- Tugev hoiatus 10s nihkel annab 5-sekundilise puhvri enne kriitilist ebaõnnestumist
- Operaatorid saavad kellaprobleeme ennetavalt lahendada
- Selged veateated juhendavad veaotsingut

---

## Parimad praktikad sõlmeoperaatoritele

### Ajasünkroniseerimise seadistamine

**Soovitatav konfiguratsioon**:
1. **Luba NTP**: Kasuta võrguajaprotokolli automaatseks sünkroniseerimiseks
   ```bash
   # Linux (systemd-timesyncd)
   sudo timedatectl set-ntp true

   # Kontrolli staatust
   timedatectl status
   ```

2. **Verifitseeri kella täpsust**: Kontrolli regulaarselt ajanihett
   ```bash
   # Kontrolli NTP sünkroniseerimise staatust
   ntpq -p

   # Või chrony-ga
   chronyc tracking
   ```

3. **Jälgi hoiatusi**: Vaata Bitcoin-PoCX kellanihe hoiatusi logides

### Kaevandajatele

**Tegevust pole vaja**:
- Funktsioon on alati aktiivne
- Töötab automaatselt
- Hoia lihtsalt oma süsteemikell täpne

**Parimad praktikad**:
- Kasuta NTP ajasünkroniseerimist
- Jälgi kellanihe hoiatusi
- Tegele hoiatustega kiiresti, kui need ilmuvad

**Oodatav käitumine**:
- Üksi kaevandamine: Kaitsev sepistamine käivitub harva (konkurentsi pole)
- Võrgu kaevandamine: Kaitseb kellamanipuleerimise katsete eest
- Läbipaistev töö: Enamik kaevandajaid ei märka seda kunagi

### Veaotsing

**Hoiatus: "10 sekundit sünkronisatsioonist väljas"**
- Tegevus: Kontrolli ja paranda süsteemikella sünkroniseerimist
- Mõju: 5-sekundiline puhver enne kriitilist ebaõnnestumist
- Tööriistad: NTP, chrony, systemd-timesyncd

**Viga: "time-too-new" sissetulevatel plokkidel**
- Põhjus: Teie kell on >15 sekundit aeglane
- Mõju: Ei saa valideerida plokke, sõlm isoleeritud
- Lahendus: Sünkroniseeri süsteemikell kohe

**Viga: Ei saa sepistatud plokke levitada**
- Põhjus: Teie kell on >15 sekundit kiire
- Mõju: Võrk lükkab plokid tagasi
- Lahendus: Sünkroniseeri süsteemikell kohe

---

## Disainiotsused ja põhjendused

### Miks 15-sekundiline tolerants?

**Põhjendus**:
- Bitcoin-PoCX muutuv tähtajaaeg on vähem ajakriitiline kui fikseeritud ajastusega konsensus
- 15s pakub piisavat kaitset, takistades samal ajal võrgu fragmenteerumist

**Kompromissid**:
- Rangem tolerants = rohkem võrgu fragmenteerumist väiksemast nihkest
- Lõdvem tolerants = rohkem võimalusi ajastusrünnakuteks
- 15s tasakaalustab turvalisust ja vastupidavust

### Miks 10-sekundiline hoiatus?

**Põhjendus**:
- Pakub 5-sekundilist ohutuspuhvrit
- Sobivam PoC jaoks kui Bitcoin'i 10-minutiline vaikimisi
- Võimaldab ennetavaid parandusi enne kriitilist ebaõnnestumist

### Miks kaitsev sepistamine?

**Käsitletud probleem**:
- 15-sekundiline tolerants võimaldab kiire kella eelist
- Kvaliteedipõhist konsensust võiks õõnestada ajastusmanipuleerimisega

**Lahenduse eelised**:
- Nullkululine kaitse (konsensuse muudatusi pole)
- Automaatne töö
- Elimineerib rünnakustiimuli
- Säilitab mahtutõestuse põhimõtted

### Miks pole võrgusisest ajasünkroniseerimist?

**Turvapõhjendus**:
- Kaasaegne Bitcoin Core eemaldas partneripõhise aja kohandamise
- Haavatav Sybil rünnakutele tajutava võrguaja vastu
- PoCX väldib teadlikult võrgusiseste ajaallikate usaldamist
- Süsteemikell on usaldusväärsem kui partnerite konsensus
- Operaatorid peaksid sünkroniseerima kasutades NTP-d või samaväärset välist ajaallikat
- Sõlmed jälgivad oma nihett ja väljutavad hoiatusi, kui kohalik kell erineb hiljutistest ploki ajatemplidest

---

## Implementatsiooni viited

**Põhifailid**:
- Aja valideerimine: `src/validation.cpp:4547-4561`
- Tuleviku tolerantsi konstant: `src/chain.h:31`
- Hoiatuse lävi: `src/node/timeoffsets.h:27`
- Ajanihe jälgimine: `src/node/timeoffsets.cpp`
- Kaitsev sepistamine: `src/pocx/mining/scheduler.cpp`

**Seotud dokumentatsioon**:
- Ajapainde algoritm: [Peatükk 3: Konsensus ja kaevandamine](3-consensus-and-mining.md#ajapainde-arvutamine)
- Ploki valideerimine: [Peatükk 3: Ploki valideerimine](3-consensus-and-mining.md#ploki-valideerimine)

---

**Genereeritud**: 2025-10-10
**Staatus**: Täielik implementatsioon
**Katvus**: Ajasünkroniseerimise nõuded, kellanihe käsitlemine, kaitsev sepistamine

---

[<- Eelmine: Sepistamisülesanded](4-forging-assignments.md) | [Sisukord](index.md) | [Järgmine: Võrguparameetrid ->](6-network-parameters.md)
