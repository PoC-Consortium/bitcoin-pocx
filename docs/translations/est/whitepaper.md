# Bitcoin-PoCX: Energiatõhus konsensus Bitcoin Core'ile

**Versioon**: 2.0 mustand
**Kuupäev**: Detsember 2025
**Organisatsioon**: Proof of Capacity Consortium

---

## Kokkuvõte

Bitcoin'i tööst tuletatud tõestuse (Proof-of-Work, PoW) konsensus pakub tugevat turvalisust, kuid tarbib märkimisväärset energiat pideva reaalajas räsimise tõttu. Esitame Bitcoin-PoCX-i, Bitcoin'i hargnema, mis asendab PoW mahtutõestusega (Proof of Capacity, PoC), kus kaevandajad eelarvutavad ja hoiustavad suuri kettale salvestatud räsikomplekte graafikukoostamise ajal ning kaevandavad seejärel kergete otsingute, mitte pideva räsimise kaudu. Nihutades arvutuse kaevandamisfaasist ühekordsesse graafikukoostamise faasi, vähendab Bitcoin-PoCX drastiliselt energiatarbimist, võimaldades samal ajal kaevandamist tavapärasel riistvaral, alandades osalemisbarjääri ja leevendades ASIC-domineeritud PoW-le omaseid tsentraliseerumissurvet, säilitades samal ajal Bitcoin'i turvaeeldused ja majandusliku käitumise.

Meie implementatsioon tutvustab mitmeid põhilisi uuendusi:
(1) Karastatud graafikuvorming, mis elimineerib kõik teadaolevad aja-mälu kompromissrünnakud olemasolevates PoC süsteemides, tagades, et efektiivne kaevandusvõimsus jääb rangelt proportsionaalseks pühendatud hoiustusmahtuvusega;
(2) Ajapainde algoritm, mis teisendab tähtaegade jaotused eksponentsiaalsest hii-ruut jaotuseks, vähendades plokkide aja varieeruvust keskmist muutmata;
(3) OP_RETURN-põhine sepistamisülesannete mehhanism, mis võimaldab mitte-hoiustavat basseinikaevandamist; ja
(4) Dünaamiline kompressiooni skaleerimine, mis suurendab graafikugenereerimise raskust vastavalt poolnemise graafikutele, et säilitada pikaajalisi ohutuspiire riistvara paranedes.

Bitcoin-PoCX säilitab Bitcoin Core'i arhitektuuri minimaalsete, funktsiooni lipuga modifikatsioonide kaudu, isoleerides PoC loogika olemasolevast konsensuse koodist. Süsteem säilitab Bitcoin'i rahapoliitika, sihtides 120-sekundilist plokiintervalli ja kohandades ploki subsiidiumi 10 BTC-le. Vähendatud subsiidium kompenseerib viiekordset plokkide sageduse kasvu, hoides pikaajalise emissiooni määra joondatuna Bitcoin'i algse graafikuga ja säilitades ~21 miljoni maksimaalse pakkumise.

---

## 1. Sissejuhatus

### 1.1 Motivatsioon

Bitcoin'i tööst tuletatud tõestuse (PoW) konsensus on osutunud turvaliseks rohkem kui kümnendi jooksul, kuid märkimisväärse kuluga: kaevandajad peavad pidevalt kulutama arvutusressursse, mille tulemuseks on kõrge energiatarbimine. Lisaks tõhususprobleemidele on laiem motivatsioon: uurida alternatiivseid konsensusmehhanisme, mis säilitavad turvalisuse, alandades samal ajal osalemisbarjääri. PoC võimaldab praktiliselt igaühel tavapärase hoiustusriistvaraga tõhusalt kaevandada, vähendades ASIC-domineeritud PoW kaevandamises nähtavaid tsentraliseerumissurvet.

Mahtutõestus (PoC) saavutab selle, tuletades kaevandusvõimsuse hoiustuskohustusest, mitte pidevast arvutusest. Kaevandajad eelarvutavad suuri kettale salvestatud räsikomplekte - graafikuid - ühekordse graafikukoostamise faasi ajal. Kaevandamine seisneb seejärel kergetes otsingutes, vähendades drastiliselt energiakasutust, säilitades samal ajal ressursipõhise konsensuse turvaeeldused.

### 1.2 Integratsioon Bitcoin Core'iga

Bitcoin-PoCX integreerib PoC konsensuse Bitcoin Core'i, mitte ei loo uut plokiahelat. See lähenemine kasutab Bitcoin Core'i tõestatud turvalisust, küpset võrgustiivi ja laialdaselt kasutatavat tööriistakomplekti, hoides samal ajal modifikatsioone minimaalsena ja funktsiooni lipuga. PoC loogika on isoleeritud olemasolevast konsensuse koodist, tagades, et põhifunktsioonid - ploki valideerimine, rahakoti operatsioonid, tehinguvormingud - jäävad suures osas muutumatuks.

### 1.3 Disainieesmärgid

**Turvalisus**: Säilitada Bitcoin'iga samaväärne vastupidavus; rünnakud nõuavad enamuse hoiustusmahtu.

**Tõhusus**: Vähendada pidevat arvutuskoormust ketta I/O tasemele.

**Ligipääsetavus**: Võimaldada kaevandamist tavapärasel riistvaral, alandades sisenemisbarjääre.

**Minimaalne integratsioon**: Tutvustada PoC konsensust minimaalse modifikatsiooni jalajäljega.

---

## 2. Taust: Mahtutõestus

### 2.1 Ajalugu

Mahtutõestuse (PoC) tutvustas Burstcoin 2014. aastal energiatõhusa alternatiivina tööst tuletatud tõestusele (PoW). Burstcoin demonstreeris, et kaevandusvõimsust saab tuletada pühendatud hoiustusest, mitte pidevast reaalajas räsimisest: kaevandajad eelarvutasid suuri andmekomplekte ("graafikud") üks kord ja seejärel kaevandasid, lugedes neist väikseid, fikseeritud osi.

Varased PoC implementatsioonid tõestasid kontseptsiooni elujõulisust, kuid paljastasid ka, et graafikuvorming ja krüptograafiline struktuur on turvalisuse jaoks kriitilised. Mitmed aja-mälu kompromissid võimaldasid ründajatel kaevandada tõhusalt väiksema hoiustusega kui ausad osalejad. See tõi esile, et PoC turvalisus sõltub graafikudisainist - mitte lihtsalt hoiustuse kasutamisest ressursina.

Burstcoin'i pärand rajas PoC kui praktilise konsensusmehhanismi ja pakkus aluse, millele PoCX ehitab.

### 2.2 Põhimõisted

PoC kaevandamine põhineb suurtel, eelarvutatud graafikufailidel, mis on kettal hoiustatud. Need graafikud sisaldavad "külmutatud arvutust": kulukas räsimine tehakse üks kord graafikukoostamise ajal ja kaevandamine seisneb seejärel kergetes ketta lugemistes ja lihtsas verifitseerimises. Põhielemendid hõlmavad:

**Nonce:**
Graafikuandmete põhiühik. Iga nonce sisaldab 4096 scoop'i (kokku 256 KiB), mis on genereeritud Shabal256 kaudu kaevandaja aadressist ja nonce indeksist.

**Scoop:**
64-baidine segment nonce'i sees. Igal plokil valib võrk deterministiliselt scoop indeksi (0-4095) eelmise ploki genereerimisallkirja põhjal. Ainult seda scoop'i nonce'i kohta tuleb lugeda.

**Genereerimisallkiri:**
256-bitine väärtus, mis on tuletatud eelmisest plokist. See pakub entroopiat scoop'i valimiseks ja takistab kaevandajatel tulevaste scoop indeksite ennustamist.

**Warp:**
Struktuurne grupp 4096 nonce'ist (1 GiB). Warp'id on asjakohane ühik kompressioonikindlate graafikuvormingute jaoks.

### 2.3 Kaevandamisprotsess ja kvaliteedi töövoog

PoC kaevandamine koosneb ühekordsest graafikukoostamise sammust ja kergest iga-ploki rutiinist:

**Ühekordne seadistamine:**
- Graafikugenereerimine: Arvuta nonce'd Shabal256 kaudu ja kirjuta need kettale.

**Iga-ploki kaevandamine:**
- Scoop'i valik: Määra scoop indeks genereerimisallkirjast.
- Graafikute skaneerimine: Loe seda scoop'i kõigist kaevandaja graafikute nonce'idest.

**Kvaliteedi töövoog:**
- Töötlemata kvaliteet: Räsi iga scoop genereerimisallkirjaga kasutades Shabal256Lite, et saada 64-bitine kvaliteediväärtus (madalam on parem).
- Tähtaeg: Teisenda kvaliteet tähtajaks kasutades baassihtmärki (raskusega kohandatud parameeter, mis tagab, et võrk jõuab sihtitud plokiintervallini): `deadline = quality / base_target`
- Painutatud tähtaeg: Rakenda ajapainde teisendus varieeruvuse vähendamiseks, säilitades eeldatava plokkide aja.

**Ploki sepistamine:**
Kaevandaja lühima (painutatud) tähtajaga sepistab järgmise ploki, kui see aeg on möödunud.

Erinevalt PoW-st toimub peaaegu kogu arvutus graafikukoostamise ajal; aktiivne kaevandamine on peamiselt kettaga piiratud ja väga madala energiatarbimisega.

### 2.4 Teadaolevad haavatavused varasemates süsteemides

**POC1 jaotuse viga:**
Algne Burstcoin POC1 vorming näitas struktuurset kallutatust: madala indeksiga scoop'e oli oluliselt odavam lennult ümber arvutada kui kõrge indeksiga scoop'e. See tutvustas ebaühtlast aja-mälu kompromissi, võimaldades ründajatel vähendada nõutavat hoiustust nende scoop'ide jaoks ja rikkudes eeldust, et kõik eelarvutatud andmed on võrdselt kulukad.

**XOR kompressiooni rünnak (POC2):**
POC2-s saab ründaja võtta mis tahes 8192 nonce'i komplekti ja jagada need kahte 4096 nonce'i plokki (A ja B). Mõlema ploki hoiustamise asemel hoiustab ründaja ainult tuletatud struktuuri: `A ⊕ transpose(B)`, kus transponeerimine vahetab scoop ja nonce indeksid - scoop S nonce'ist N plokis B saab scoop'iks N nonce'ist S.

Kaevandamise ajal, kui on vaja scoop S nonce'ist N, taastab ründaja selle:
1. Lugedes hoiustatud XOR väärtust positsioonil (S, N)
2. Arvutades nonce N plokist A, et saada scoop S
3. Arvutades nonce S plokist B, et saada transponeeritud scoop N
4. XOR-ides kõik kolm väärtust, et taastada algne 64-baidine scoop

See vähendab hoiustust 50%, nõudes samal ajal ainult kahte nonce arvutust otsingu kohta - kulu, mis on palju madalam kui täieliku eelarvutuse jõustamiseks vajalik lävi. Rünnak on elujõuline, sest rea arvutamine (üks nonce, 4096 scoop'i) on odav, samas kui veeru arvutamine (üks scoop 4096 nonce'i vahel) nõuaks kõigi nonce'ide regenereerimist. Transponeeri struktuur paljastab selle tasakaalutuse.

See demonstreeris vajadust graafikuvormingu järele, mis takistab sellist struktureeritud rekombineerimist ja eemaldab aluseks oleva aja-mälu kompromissi. Jaotis 3.3 kirjeldab, kuidas PoCX seda nõrkust käsitleb ja lahendab.

### 2.5 Üleminek PoCX-ile

Varasemate PoC süsteemide piirangud tegid selgeks, et turvaline, õiglane ja detsentraliseeritud hoiustuskaevandamine sõltub hoolikalt projekteeritud graafikustruktuuridest. Bitcoin-PoCX käsitleb neid probleeme karastatud graafikuvorminguga, parandatud tähtaegade jaotusega ja detsentraliseeritud basseinikaevandamise mehhanismidega - kirjeldatud järgmises jaotises.

---

## 3. PoCX graafikuvorming

### 3.1 Baas-nonce'i konstrueerimine

Nonce on 256 KiB andmestruktuur, mis on deterministiliselt tuletatud kolmest parameetrist: 20-baidisest aadressi koormusest, 32-baidisest seemnest ja 64-bitisest nonce indeksist.

Konstrueerimine algab nende sisendite kombineerimise ja Shabal256-ga räsimisega, et toota algne räsi. See räsi toimib iteratiivse laiendusprotsessi lähtepunktina: Shabal256 rakendatakse korduvalt, kusjuures iga samm sõltub varem genereeritud andmetest, kuni kogu 256 KiB puhver on täidetud. See aheldatud protsess esindab graafikukoostamise ajal tehtud arvutustööd.

Lõplik difusioonietapp räsib lõpetatud puhvri ja XOR-ib tulemuse üle kõigi baitide. See tagab, et kogu puhver on arvutatud ja et kaevandajad ei saa arvutust lühendada. Seejärel rakendatakse PoC2 segamist, vahetades iga scoop'i alumise ja ülemise poole, et garanteerida, et kõik scoop'id nõuavad võrdväärset arvutuslikku pingutust.

Lõplik nonce koosneb 4096 scoop'ist, igaüks 64 baiti, ja moodustab kaevandamises kasutatava põhiühiku.

### 3.2 SIMD-joondatud graafikupaigutus

Läbilaskevõime maksimeerimiseks kaasaegsel riistvaral korraldab PoCX nonce andmed kettal vektoriseeritud töötluse hõlbustamiseks. Iga nonce'i järjestikuse hoiustamise asemel joondab PoCX vastavad 4-baidised sõnad mitme järjestikuse nonce'i vahel kõrvuti. See võimaldab ühel mälu hankimisel pakkuda andmeid kõigile SIMD radadele, minimeerides vahemälu möödalaskmisi ja elimineerides hajutatud kogumise üldkulu.

```
Traditsiooniline paigutus:
Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX SIMD paigutus:
Sõna0: [N0][N1][N2]...[N15]
Sõna1: [N0][N1][N2]...[N15]
Sõna2: [N0][N1][N2]...[N15]
```

See paigutus toob kasu nii CPU kui GPU kaevandajatele, võimaldades suure läbilaskevõimega paralleliseeritud scoop'i hindamist, säilitades samal ajal lihtsa skalaarse juurdepääsumustri konsensuse verifitseerimiseks. See tagab, et kaevandamine on piiratud hoiustuse ribalaiusega, mitte CPU arvutusega, säilitades mahtutõestuse madala energiatarbimise olemuse.

### 3.3 Warp struktuur ja XOR-transponeeri kodeering

Warp on PoCX-i põhiline hoiustusühik, koosnedes 4096 nonce'ist (1 GiB). Kompresseerimata vorming, mida nimetatakse X0-ks, sisaldab baas-nonce'e täpselt nii, nagu jaotises 3.1 kirjeldatud konstrueerimine need toodab.

**XOR-transponeeri kodeering (X1)**

Varasemates PoC süsteemides esinenud struktuursete aja-mälu kompromisside eemaldamiseks tuletab PoCX karastatud kaevandusvormingu X1, rakendades XOR-transponeeri kodeeringut X0 warp'ide paaridele.

Scoop S konstrueerimiseks nonce N jaoks X1 warp'is:

1. Võta scoop S nonce'ist N esimesest X0 warp'ist (otsene positsioon)
2. Võta scoop N nonce'ist S teisest X0 warp'ist (transponeeritud positsioon)
3. XOR-i kaks 64-baidist väärtust X1 scoop'i saamiseks

Transponeeri samm vahetab scoop ja nonce indeksid. Maatriksi mõttes - kus read esindavad scoop'e ja veerud nonce'e - kombineerib see elemendi positsioonilt (S, N) esimeses warp'is elemendiga positsioonilt (N, S) teises.

**Miks see elimineerib kompressioonirünnaku pinna**

XOR-transponeeri lukustab iga scoop'i terve rea ja terve veeruga aluseks olevatest X0 andmetest. Ühe X1 scoop'i taastamine nõuab seega juurdepääsu andmetele, mis hõlmavad kõiki 4096 scoop indeksit. Igasugune katse puuduvaid andmeid arvutada nõuaks 4096 täieliku nonce'i regenereerimist, mitte ühe nonce'i - eemaldades asümmeetrilise kulustruktuuri, mida POC2 XOR rünnak kasutas (jaotis 2.4).

Selle tulemusena muutub täieliku X1 warp'i hoiustamine ainsaks arvutuslikult elujõuliseks strateegiaks kaevandajatele, sulgedes varasemates disainides kasutatud aja-mälu kompromissi.

### 3.4 Kettapaigutus

PoCX graafikufailid koosnevad paljudest järjestikustest X1 warp'idest. Operatiivse tõhususe maksimeerimiseks kaevandamise ajal on andmed igas failis korraldatud scoop'i järgi: kõik scoop 0 andmed igast warp'ist hoitakse järjestikku, millele järgnevad kõik scoop 1 andmed jne kuni scoop 4095-ni.

See **scoop-järjestikune korrastus** võimaldab kaevandajatel lugeda valitud scoop'i jaoks nõutavad täielikud andmed ühe järjestikuse kettalugemisega, minimeerides otsimisaegu ja maksimeerides läbilaskevõimet tavapärastel hoiustusseadmetel.

Kombineerituna jaotise 3.3 XOR-transponeeri kodeeringuga tagab see paigutus, et fail on nii **struktuurselt karastatud** kui ka **operatiivselt tõhus**: scoop-järjestikune korrastus toetab optimaalset ketta I/O-d, samas kui SIMD-joondatud mälupaigutused (vt jaotis 3.2) võimaldavad suure läbilaskevõimega paralleliseeritud scoop'i hindamist.

### 3.5 Tööst tuletatud tõestuse skaleerimine (Xn)

PoCX implementeerib skaleeritavat eelarvutust skaleerimistasemete kontseptsiooni kaudu, tähistatuna Xn, et kohaneda areneva riistvara jõudlusega. Baastase X1 vorming esindab esimest XOR-transponeeri karastatud warp struktuuri.

Iga skaleerimistase Xn suurendab igas warp'is manustatud tööst tuletatud tõestust eksponentsiaalselt võrreldes X1-ga: tasemel Xn nõutav töö on 2^(n-1) korda X1 oma. Üleminek Xn-lt Xn+1-le on operatiivselt samaväärne XOR-i rakendamisega külgnevate warp'ide paaride vahel, manustades inkrementaalselt rohkem tööst tuletatud tõestust ilma aluseks olevat graafiku suurust muutmata.

Madalamal skaleerimistasemel loodud olemasolevaid graafikufaile saab endiselt kaevandamiseks kasutada, kuid need annavad proportsionaalselt vähem tööd ploki genereerimise poole, kajastades nende madalamat manustatud tööst tuletatud tõestust. See mehhanism tagab, et PoCX graafikud jäävad aja jooksul turvaliseks, paindlikuks ja majanduslikult tasakaalustatuks.

### 3.6 Seemne funktsioon

Seemne parameeter võimaldab mitut mittekattuvat graafikut aadressi kohta ilma käsitsi koordineerimiseta.

**Probleem (POC2)**: Kaevandajad pidid käsitsi jälgima nonce vahemikke graafikufailide vahel kattumise vältimiseks. Kattuvad nonce'd raiskavad hoiustust ilma kaevandusvõimsust suurendamata.

**Lahendus**: Iga `(aadress, seeme)` paar defineerib sõltumatu võtmeruumi. Erinevate seemnetega graafikud ei kattu kunagi, olenemata nonce vahemikest. Kaevandajad saavad graafikuid vabalt luua ilma koordineerimiseta.

---

## 4. Mahtutõestuse konsensus

PoCX laiendab Bitcoin'i Nakamoto konsensust hoiustusega seotud tõestusmehhanismiga. Energia kulutamise asemel korduvale räsimisele pühendavad kaevandajad suured kogused eelarvutatud andmeid - graafikuid - kettale. Ploki genereerimise ajal peavad nad leidma väikese, ettearvamatatu osa neist andmetest ja teisendama selle tõestuseks. Kaevandaja, kes esitab parima tõestuse oodatava ajaakna jooksul, teenib õiguse sepistada järgmine plokk.

See peatükk kirjeldab, kuidas PoCX struktureerib ploki metaandmeid, tuletab ettearvamatust ja teisendab staatilise hoiustuse turvaliseks, madala varieeruvusega konsensusmehhanismiks.

### 4.1 Ploki struktuur

PoCX säilitab tuttava Bitcoin-stiilis ploki päise, kuid tutvustab täiendavaid konsensuse välju, mis on vajalikud mahtupõhiseks kaevandamiseks. Need väljad seovad kollektiivselt ploki kaevandaja hoiustatud graafikuga, võrgu raskusega ja krüptograafilise entroopiaga, mis defineerib iga kaevandamisväljakutse.

Kõrgel tasemel sisaldab PoCX plokk: ploki kõrgust, mis on selgesõnaliselt salvestatud kontekstivaba valideerimise lihtsustamiseks; genereerimisallkirja, värske entroopia allikat, mis seob iga ploki eelkäijaga; baassihtmärki, mis esindab võrgu raskust pöördvormis (kõrgemad väärtused vastavad kergemale kaevandamisele); PoCX tõestust, mis identifitseerib kaevandaja graafiku, graafikukoostamisel kasutatud kompressiooni taseme, valitud nonce'i ja sellest tuletatud kvaliteedi; ning allkirjastamisvõtit ja allkirja, mis tõestavad kontrolli ploki sepistamiseks kasutatud mahtuvuse üle (või määratud sepistamisvõtme üle).

Tõestus manustab kogu konsensuse jaoks vajaliku informatsiooni, mida valideerijad vajavad väljakutse ümberarvutamiseks, valitud scoop'i verifitseerimiseks ja tuleneva kvaliteedi kinnitamiseks. Laiendades, mitte ümber disainides ploki struktuuri, jääb PoCX kontseptuaalselt Bitcoin'iga joondatuks, võimaldades samal ajal põhimõtteliselt erinevat kaevandamistöö allikat.

### 4.2 Genereerimisallkirja ahel

Genereerimisallkiri pakub turvaliseks mahtutõestuse kaevandamiseks vajalikku ettearvamatust. Iga plokk tuletab oma genereerimisallkirja eelmise ploki allkirjast ja allkirjastajast, tagades, et kaevandajad ei saa ennustada tulevasi väljakutseid ega eelarvutada soodsaid graafikupiirkondi:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

See toodab krüptograafiliselt tugevate, kaevandajast sõltuvate entroopia väärtuste jada. Kuna kaevandaja avalik võti on teadmata kuni eelmise ploki avaldamiseni, ei saa ükski osaleja ennustada tulevasi scoop'i valikuid. See takistab selektiivset eelarvutust või strateegilist graafikukoostamist ja tagab, et iga plokk tutvustab genuiinselt värsket kaevandamistööd.

### 4.3 Sepistamisprotsess

Kaevandamine PoCX-is seisneb hoiustatud andmete teisendamises tõestuseks, mida juhib täielikult genereerimisallkiri. Kuigi protsess on deterministlik, tagab allkirja ettearvamatatus, et kaevandajad ei saa ette valmistada ja peavad korduvalt oma hoiustatud graafikutele juurde pääsema.

**Väljakutse tuletus (scoop'i valik):** Kaevandaja räsib praeguse genereerimisallkirja ploki kõrgusega, et saada scoop indeks vahemikus 0-4095. See indeks määrab, milline 64-baidine segment igast hoiustatud nonce'ist osaleb tõestuses. Kuna genereerimisallkiri sõltub eelmise ploki allkirjastajast, saab scoop'i valik teatavaks alles ploki avaldamise hetkel.

**Tõestuse hindamine (kvaliteedi arvutamine):** Iga graafiku nonce'i jaoks hangib kaevandaja valitud scoop'i ja räsib selle koos genereerimisallkirjaga, et saada kvaliteet - 64-bitine väärtus, mille suurus määrab kaevandaja konkurentsivõime. Madalam kvaliteet vastab paremale tõestusele.

**Tähtaja moodustamine (ajapainde):** Töötlemata tähtaeg on proportsionaalne kvaliteediga ja pöördvõrdeline baassihtmärgiga. Pärand PoC disainides järgisid need tähtajad kõrgelt kaldu eksponentsiaalset jaotust, tootes pikki saba viivitusi, mis ei pakkunud täiendavat turvalisust. PoCX teisendab töötlemata tähtaja kasutades ajapainet (jaotis 4.4), vähendades varieeruvust ja tagades etteaimatavad plokiintervallid. Kui painutatud tähtaeg möödub, sepistab kaevandaja ploki, manustades tõestuse ja allkirjastades selle efektiivse sepistamisvõtmega.

### 4.4 Ajapainde

Mahtutõestus toodab eksponentsiaalselt jaotunud tähtaegu. Pärast lühikest perioodi - tavaliselt mõnikümmend sekundit - on iga kaevandaja juba identifitseerinud oma parima tõestuse ja igasugune täiendav ooteaeg annab ainult latentsust, mitte turvalisust.

Ajapainde kujundab jaotuse ümber, rakendades kuupjuure teisendust:

`deadline_bended = scale × (quality / base_target)^(1/3)`

Skaala tegur säilitab oodatava plokkide aja (120 sekundit), vähendades samal ajal dramaatiliselt varieeruvust. Lühikesi tähtaegu pikendatakse, parandades ploki levikut ja võrgu turvalisust. Pikki tähtaegu kompresseeritakse, takistades äärmusi ahelat viivitamast.

![Plokkide aja jaotused](blocktime_distributions.svg)

Ajapainde säilitab aluseks oleva tõestuse informatsioonilise sisu. See ei muuda kaevandajate vahelist konkurentsivõimet; see ainult jaotab ooteaja ümber, et toota sujuvamaid, etteaimatavamaid plokiintervalle. Implementatsioon kasutab püsipunktaritmeetikat (Q42 vorming) ja 256-bitiseid täisarve, et tagada deterministlikud tulemused kõigil platvormidel.

### 4.5 Raskuse kohandamine

PoCX reguleerib plokitootmist kasutades baassihtmärki, pöördraskuse mõõtu. Oodatav plokkide aeg on proportsionaalne suhtega `quality / base_target`, seega baassihtmärgi suurendamine kiirendab ploki loomist, samas kui selle vähendamine aeglustab ahelat.

Raskus kohandub igal plokil, kasutades hiljutiste plokkide vahel mõõdetud aega võrreldes sihtintervalliga. See sage kohandamine on vajalik, sest hoiustusmahtu saab kiiresti lisada või eemaldada - erinevalt Bitcoin'i räsivõimsusest, mis muutub aeglasemalt.

Kohandamine järgib kahte juhtivat piirangut: **Järkjärgulisus** - iga-ploki muudatused on piiratud (maksimaalselt ±20%), et vältida võnkumisi või manipuleerimist; **Karastamine** - baassihtmärk ei saa ületada oma genesise väärtust, takistades võrgul kunagi alandada raskust alla algsete turvaeelduste.

### 4.6 Ploki kehtivus

Plokk PoCX-is on kehtiv, kui see esitab verifitseeritava hoiustusest tuletatud tõestuse, mis on kooskõlas konsensuse olekuga. Valideerijad arvutavad sõltumatult ümber scoop'i valiku, tuletavad oodatava kvaliteedi esitatud nonce'ist ja graafiku metaandmetest, rakendavad ajapainde teisendust ja kinnitavad, et kaevandajal oli õigus sepistada plokk deklareeritud ajal.

Konkreetselt nõuab kehtiv plokk: tähtaeg on möödunud alates emaploklist; esitatud kvaliteet vastab tõestuse jaoks arvutatud kvaliteedile; skaleerimistase vastab võrgu miinimumile; genereerimisallkiri vastab oodatavale väärtusele; baassihtmärk vastab oodatavale väärtusele; ploki allkiri tuleb efektiivselt allkirjastajalt; ja coinbase maksab efektiivse allkirjastaja aadressile.

---

## 5. Sepistamisülesanded

### 5.1 Motivatsioon

Sepistamisülesanded võimaldavad graafikuomanikel delegeerida ploki sepistamise volitusi ilma kunagi loobumata oma graafikute omandist. See mehhanism võimaldab basseinikaevandamist ja külma hoiustuse seadistusi, säilitades samal ajal PoCX turvatagatised.

Basseinikaevandamises saavad graafikuomanikud volitada basseini sepistama plokke nende nimel. Bassein koondab plokke ja jagab tasusid, kuid see ei saa kunagi graafikute hooldusõigust. Delegeerimine on igal ajal tühistatav ja graafikuomanikud võivad vabalt basseinidest lahkuda või konfiguratsioone muuta ilma uuesti graafikuid koostamata.

Ülesanded toetavad ka puhast eraldust külmade ja kuumade võtmete vahel. Graafikut kontrolliv privaatvõti võib jääda võrguühenduseta, samas kui eraldi sepistamisvõti - hoiustatud võrguühendusega masinas - toodab plokke. Sepistamisvõtme kompromiteerimine ohustab seega ainult sepistamisvolitust, mitte omandit. Graafik jääb turvaliseks ja ülesande saab tühistada, sulgedes turvaaugu kohe.

Sepistamisülesanded pakuvad seega operatiivset paindlikkust, säilitades samal ajal põhimõtte, et kontrolli hoiustatud mahtuvuse üle ei tohi kunagi üle kanda vahendajatele.

### 5.2 Ülesande protokoll

Ülesandeid deklareeritakse läbi OP_RETURN tehingute, et vältida UTXO kogumi tarbetut kasvu. Ülesande tehing määrab graafiku aadressi ja sepistamise aadressi, mis on volitatud tootma plokke selle graafiku mahtuvust kasutades. Tühistamise tehing sisaldab ainult graafiku aadressi. Mõlemal juhul tõestab graafikuomanik kontrolli, allkirjastades tehingu kulutava sisendi.

Iga ülesanne progresseerub läbi hästi defineeritud olekute jada (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Pärast ülesande tehingu kinnitamist siseneb süsteem lühikesse aktiveerimisfaasi. See viivitus - 30 plokki, ligikaudu üks tund - tagab stabiilsuse plokkide võidujooksude ajal ja takistab adversaarseid kiireid sepistamisidentiteetide vahetusi. Kui see aktiveerimisperiood möödub, muutub ülesanne aktiivseks ja jääb selliseks, kuni graafikuomanik annab välja tühistamise.

Tühistamised lähevad üle pikemasse viivitusperioodi 720 plokist, ligikaudu üks päev. Selle aja jooksul jääb eelmine sepistamise aadress aktiivseks. See pikem viivitus pakub operatiivset stabiilsust basseinidele, takistades strateegilist "ülesannete hüppamist" ja andes infrastruktuuriteenuse pakkujatele piisavalt kindlust tõhusaks toimimiseks. Pärast tühistamise viivituse möödumist lõpeb tühistamine ja graafikuomanik on vaba määrama uut sepistamisvõtit.

Ülesande olekut säilitatakse konsensuskihi struktuuris paralleelselt UTXO kogumiga ja see toetab tagasivõtmise andmeid ahela ümberkorralduste ohutuks käsitlemiseks.

### 5.3 Valideerimisreeglid

Iga ploki jaoks määravad valideerijad efektiivse allkirjastaja - aadressi, mis peab allkirjastama ploki ja saama coinbase tasu. See allkirjastaja sõltub ainult ülesande olekust ploki kõrgusel.

Kui ülesannet pole või ülesanne pole veel lõpetanud oma aktiveerimisfaasi, jääb graafikuomanik efektiivseks allkirjastajaks. Kui ülesanne muutub aktiivseks, peab määratud sepistamise aadress allkirjastama. Tühistamise ajal jätkab sepistamise aadress allkirjastamist, kuni tühistamise viivitus möödub. Alles seejärel naaseb volitus graafikuomanikule.

Valideerijad jõustavad, et ploki allkiri on toodetud efektiivse allkirjastaja poolt, et coinbase maksab samale aadressile ja et kõik üleminekud järgivad ettenähtud aktiveerimise ja tühistamise viivitusi. Ainult graafikuomanik saab luua või tühistada ülesandeid; sepistamisvõtmed ei saa muuta ega pikendada oma õigusi.

Sepistamisülesanded tutvustavad seega paindlikku delegeerimist ilma usaldust tutvustamata. Aluseks oleva mahtuvuse omand jääb alati krüptograafiliselt ankurdatuks graafikuomanikule, samas kui sepistamisvolitust saab delegeerida, roteerida või tühistada vastavalt operatiivsetele vajadustele.

---

## 6. Dünaamiline skaleerimine

Riistvara arenedes väheneb graafikute arvutamise kulu võrreldes eelarvutatud töö kettalt lugemisega. Ilma vastumeetmeteta võiksid ründajad lõpuks genereerida tõestusi lennult kiiremini kui kaevandajad hoiustatud tööd lugemas, õõnestades mahtutõestuse turvamudelit.

Kavandatud ohutuspiiri säilitamiseks implementeerib PoCX skaleerimisgraafiku: graafikute minimaalne nõutav skaleerimistase suureneb aja jooksul. Iga skaleerimistase Xn, nagu kirjeldatud jaotises 3.5, manustab eksponentsiaalselt rohkem tööst tuletatud tõestust graafikustruktuuri, tagades, et kaevandajad jätkavad märkimisväärsete hoiustusressursside pühendamist isegi arvutuse odavnedes.

Graafik joondub võrgu majanduslike stiimulitega, eriti ploki tasu poolnemistega. Kui tasu ploki kohta väheneb, minimaalne tase järk-järgult suureneb, säilitades tasakaalu graafikukoostamise pingutuse ja kaevandamise potentsiaali vahel:

| Periood | Aastad | Poolnemised | Min skaleerimine | Graafiku töö kordaja |
|---------|--------|-------------|------------------|----------------------|
| Epohh 0 | 0-4 | 0 | X1 | 2× baastase |
| Epohh 1 | 4-12 | 1-2 | X2 | 4× baastase |
| Epohh 2 | 12-28 | 3-6 | X3 | 8× baastase |
| Epohh 3 | 28-60 | 7-14 | X4 | 16× baastase |
| Epohh 4 | 60-124 | 15-30 | X5 | 32× baastase |
| Epohh 5 | 124+ | 31+ | X6 | 64× baastase |

Kaevandajad võivad valikuliselt valmistada graafikuid, mis ületavad praegust miinimumi ühe taseme võrra, võimaldades neil planeerida ette ja vältida koheseid uuendusi, kui võrk läheb üle järgmisesse epohhi. See valikuline samm ei anna täiendavat eelist ploki tõenäosuse osas - see lihtsalt võimaldab sujuvamat operatiivset üleminekut.

Plokke, mis sisaldavad tõestusi alla minimaalse skaleerimistaseme oma kõrguse jaoks, peetakse kehtetuteks. Valideerijad kontrollivad tõestuses deklareeritud skaleerimistase praeguse võrgu nõude vastu konsensuse valideerimise ajal, tagades, et kõik osalevad kaevandajad vastavad arenevatele turvaootustele.

---

## 7. Kaevandamise arhitektuur

PoCX eraldab konsensuse jaoks kriitilised operatsioonid kaevandamise ressursimahukatest ülesannetest, võimaldades nii turvalisust kui tõhusust. Sõlm säilitab plokiahelat, valideerib plokke, haldab mempool'i ja pakub RPC liidest. Välised kaevandajad tegelevad graafikute hoiustamise, scoop'ide lugemise, kvaliteedi arvutamise ja tähtaegade haldamisega. See eraldatus hoiab konsensuse loogika lihtsa ja auditeeritavana, võimaldades samal ajal kaevandajatel optimeerida ketta läbilaskevõime jaoks.

### 7.1 Kaevandamise RPC liides

Kaevandajad suhtlevad sõlmega minimaalse RPC kutsete komplekti kaudu. get_mining_info RPC pakub praegust ploki kõrgust, genereerimisallkirja, baassihtmärki, sihttähtaega ja aktsepteeritavat graafikute skaleerimistasemete vahemikku. Seda informatsiooni kasutades arvutavad kaevandajad kandidaat-nonce'e. submit_nonce RPC võimaldab kaevandajatel esitada pakutud lahendust, sealhulgas graafiku identifikaatorit, nonce indeksit, skaleerimistase ja kaevandaja kontot. Sõlm hindab esitust ja vastab arvutatud tähtajaga, kui tõestus on kehtiv.

### 7.2 Sepistamise planeerija

Sõlm säilitab sepistamise planeerijat, mis jälgib sissetulevaid esitusi ja säilitab ainult parima lahenduse iga ploki kõrguse jaoks. Esitatud nonce'id seatakse järjekorda sisseehitatud kaitsemeetmetega esitamiste üleujutamise või teenuse tõkestamise rünnakute vastu. Planeerija ootab, kuni arvutatud tähtaeg möödub või parem lahendus saabub, mille järel ta koondab ploki, allkirjastab selle efektiivse sepistamisvõtmega ja avaldab selle võrku.

### 7.3 Kaitsev sepistamine

Ajastusrünnakute või kellamanipuleerimise stiimulite vältimiseks implementeerib PoCX kaitsva sepistamise. Kui sama kõrguse jaoks saabub konkureeriv plokk, võrdleb planeerija kohalikku lahendust uue plokiga. Kui kohalik kvaliteet on parem, sepistab sõlm kohe, mitte ei oota algset tähtaega. See tagab, et kaevandajad ei saa eelist lihtsalt kohalikke kellasid kohandades; parim lahendus võidab alati, säilitades õigluse ja võrgu turvalisuse.

---

## 8. Turvaanalüüs

### 8.1 Ohumudel

PoCX modelleerib vastaseid märkimisväärsete, kuid piiratud võimetega. Ründajad võivad üritada koormata võrku kehtetute tehingute, valesti moodustatud plokkide või võltsitud tõestustega, et testida valideerimisteid. Nad saavad vabalt manipuleerida oma kohalikke kellasid ja võivad üritada kasutada ära äärjuhte konsensuse käitumises nagu ajatempli käsitlemine, raskuse kohandamise dünaamika või ümberkorraldusreeglid. Vastastelt oodatakse ka ajaloo ümberkirjutamise võimaluste otsimist läbi sihitud ahela hargnede.

Mudel eeldab, et ükski üksik osapool ei kontrolli enamust kogu võrgu hoiustusmahust. Nagu iga ressursipõhise konsensusmehhanismi puhul, saab 51% mahtuvuse ründaja ühepoolselt ahelat ümber korraldada; see fundamentaalne piirang pole PoCX-ile omane. PoCX eeldab samuti, et ründajad ei saa arvutada graafikuandmeid kiiremini kui ausad kaevandajad saavad neid kettalt lugeda. Skaleerimisgraafik (jaotis 6) tagab, et turvalisuseks vajalik arvutuslik vahe kasvab aja jooksul riistvara paranedes.

Järgnevad jaotised uurivad iga peamist rünnakuklassi detailselt ja kirjeldavad PoCX-i sisseehitatud vastumeetmeid.

### 8.2 Mahtuvuse rünnakud

Nagu PoW, saab enamuse mahtuvusega ründaja ajalugu ümber kirjutada (51% rünnak). Selle saavutamine nõuab füüsilise hoiustusmahu omandamist, mis on suurem kui aus võrk - kulukas ja logistiliselt nõudlik ettevõtmine. Kui riistvara on omandatud, on tegevuskulud madalad, kuid algne investeering loob tugeva majandusliku stiimuli ausalt käitumiseks: ahela õõnestamine kahjustaks ründaja enda vara baasi väärtust.

PoC väldib ka PoS-iga seotud "nothing-at-stake" probleemi. Kuigi kaevandajad saavad skaneerida graafikuid mitme konkureeriva hargnemi vastu, tarbib iga skaneering reaalset aega - tavaliselt kümneid sekundeid ahela kohta. 120-sekundilise plokiintervalliga piirab see olemuslikult mitme hargnemi kaevandamist ja paljude hargnede samaaegne kaevandamise katse halvendab jõudlust kõigil neil. Hargnemi kaevandamine pole seega kulutu; see on fundamentaalselt piiratud I/O läbilaskevõimega.

Isegi kui tulevane riistvara võimaldaks peaaegu kohest graafikute skaneerimist (nt kiirete SSD-dega), seisaks ründaja endiselt silmitsi märkimisväärse füüsilise ressursinõudega, et kontrollida enamust võrgu mahtuvusest, muutes 51%-stiilis rünnaku kulukaks ja logistiliselt keeruliseks.

Lõpuks on mahtuvuse rünnakuid palju raskem rentida kui räsivõimsuse rünnakuid. GPU arvutust saab nõudmisel omandada ja kohe mis tahes PoW ahelale suunata. Seevastu nõuab PoC füüsilist riistvara, ajamahuka graafikukoostamist ja pidevaid I/O operatsioone. Need piirangud muudavad lühiajalised, oportunistlikud rünnakud palju vähem teostatavaks.

### 8.3 Ajastusrünnakud

Ajastus mängib mahtutõestuses kriitilisemat rolli kui tööst tuletatud tõestuses. PoW-s mõjutavad ajatemplid peamiselt raskuse kohandamist; PoC-s määravad need, kas kaevandaja tähtaeg on möödunud ja seega kas plokk on sepistamiseks kõlblik. Tähtaegu mõõdetakse suhtes emaoploki ajatempliga, kuid sõlme kohalikku kella kasutatakse hindamaks, kas sissetulev plokk on liiga kaugel tulevikus. Sel põhjusel jõustab PoCX ranget ajatempli tolerantsi: plokid ei tohi erineda rohkem kui 15 sekundit sõlme kohalikust kellast (võrreldes Bitcoin'i 2-tunnise aknaga). See piir töötab mõlemas suunas - liiga kaugel tulevikus olevad plokid lükatakse tagasi ja aeglaste kelladega sõlmed võivad valesti kehtivaid sissetulevaid plokke tagasi lükata.

Sõlmed peaksid seega sünkroniseerima oma kellasid NTP või samaväärse ajaallika abil. PoCX väldib teadlikult võrgusisestele ajaallika te toetumist, et takistada ründajaid tajutavat võrguaega manipuleerimast. Sõlmed jälgivad oma nihett ja väljutavad hoiatusi, kui kohalik kell hakkab hiljutistest ploki ajatemplitest erinema.

Kella kiirendamine - kiire kohaliku kella käitamine veidi varem sepistamiseks - annab ainult marginaalset kasu. Lubatud tolerantsi piires tagab kaitsev sepistamine (jaotis 7.3), et parema lahendusega kaevandaja avaldab kohe, nähes kehvemat varast plokki. Kiire kell aitab kaevandajal ainult avaldada juba-võitvat lahendust mõne sekundi võrra varem; see ei saa teisendada kehvemat tõestust võitvaks.

Katseid raskust ajatemplite kaudu manipuleerida piirab ±20% iga-ploki kohandamise piir ja 24-ploki libisev aken, takistades kaevandajaid raskust lühiajaliste ajastusmängude kaudu oluliselt mõjutamast.

### 8.4 Aja-mälu kompromissrünnakud

Aja-mälu kompromissid üritavad vähendada hoiustusnõudeid, arvutades osa graafikust nõudmisel ümber. Varasemad mahtutõestuse süsteemid olid sellistele rünnakutele haavatavad, eriti POC1 scoop-tasakaalustamatus viga ja POC2 XOR-transponeeri kompressiooni rünnak (jaotis 2.4). Mõlemad kasutasid ära asümmeetriaid selles, kui kulukas oli graafikuandmete teatud osi regenereerida, võimaldades vastastel hoiustust vähendada, makstes samal ajal ainult väikest arvutuslikku trahvi. Samuti kannatavad alternatiivsed graafikuvormingud PoC2-le sarnaste TMTO nõrkuste all; silmapaistev näide on Chia, mille graafikuvormingut saab suvafiliselt vähendada teguriga suurem kui 4.

PoCX eemaldab need rünnakupinnad täielikult oma nonce konstrueerimise ja warp vormingu kaudu. Iga nonce sees räsib lõplik difusioonietapp täielikult arvutatud puhvri ja XOR-ib tulemuse üle kõigi baitide, tagades, et iga puhvri osa sõltub igast teisest osast ja seda ei saa lühendada. Seejärel vahetab PoC2 segamine iga scoop'i alumise ja ülemise poole, ühtlustades mis tahes scoop'i taastamise arvutuslikku kulu.

PoCX elimineerib veelgi POC2 XOR-transponeeri kompressiooni rünnaku, tuletades oma karastatud X1 vormingu, kus iga scoop on XOR otsesest ja transponeeritud positsioonist paardunud warp'ide vahel; see lukustab iga scoop'i terve rea ja terve veeruga aluseks olevatest X0 andmetest, muutes rekonstrueerimise vajaduseks tuhandeid täielikke nonce'e ja eemaldades seeläbi täielikult asümmeetrilise aja-mälu kompromissi.

Selle tulemusena on täieliku graafiku hoiustamine ainus arvutuslikult elujõuline strateegia kaevandajatele. Ükski teadaolev otsetee - olgu see osaline graafikukoostamine, selektiivne regenereerimine, struktureeritud kompressioon või hübriidsed arvutus-hoiustus lähenemised - ei anna tähenduslikku eelist. PoCX tagab, et kaevandamine jääb rangelt hoiustusega seotuks ja et mahtuvus kajastab reaalset, füüsilist kohustust.

### 8.5 Ülesannete rünnakud

PoCX kasutab deterministlikku olekumasinat kõigi graafik-sepistaja ülesannete reguleerimiseks. Iga ülesanne progresseerub läbi hästi defineeritud olekute - UNASSIGNED -> ASSIGNING -> ASSIGNED -> REVOKING -> REVOKED - jõustatud aktiveerimise ja tühistamise viivitustega. See tagab, et kaevandaja ei saa kohe ülesandeid muuta, et süsteemi petta, ega kiiresti sepistamisvolitust vahetada.

Kuna kõik üleminekud nõuavad krüptograafilisi tõestusi - konkreetselt graafikuomaniku allkirju, mis on verifitseeritav sisendi UTXO vastu - saab võrk usaldada iga ülesande legitiimsust. Katseid olekumasinast mööda hiilida või ülesandeid võltsida lükatakse konsensuse valideerimise ajal automaatselt tagasi. Taasesitusrünnakuid takistavad samuti standardsed Bitcoin-stiilis tehingu taasesituse kaitsemeetmed, tagades, et iga ülesande tegevus on unikaalselt seotud kehtiva, kulutamata sisendiga.

Olekumasina reguleerimise, jõustatud viivituste ja krüptograafilise tõestuse kombinatsioon muudab ülesandepõhise petmise praktiliselt võimatuks: kaevandajad ei saa ülesandeid kaaperdada, teha kiiret ümberseadistamist plokkide võidujooksude ajal ega tühistamise graafikutest mööda minna.

### 8.6 Allkirja turvalisus

Ploki allkirjad PoCX-is toimivad kriitilise lingina tõestuse ja efektiivse sepistamisvõtme vahel, tagades, et ainult volitatud kaevandajad saavad toota kehtivaid plokke.

Muudetavusrünnakute takistamiseks on allkirjad välja arvatud ploki räsi arvutamisest. See elimineerib muudetavate allkirjade riskid, mis võiksid valideerimist õõnestada või võimaldada ploki asendamise rünnakuid.

Teenuse tõkestamise vektorite leevendamiseks on allkirjade ja avalike võtmete suurused fikseeritud - 65 baiti kompaktsete allkirjade ja 33 baiti kompresseeritud avalike võtmete jaoks - takistades ründajaid plokke paisutamast ressursside ammendamiseks või võrgu leviku aeglustamiseks.

---

## 9. Implementatsioon

PoCX on implementeeritud modulaarse laiendusena Bitcoin Core'ile, kogu asjakohane kood sisaldub oma pühendatud alamkataloogis ja aktiveeritakse funktsiooni lipu kaudu. See disain säilitab algse koodi terviklikkuse, võimaldades PoCX-i puhtalt lubada või keelata, mis lihtsustab testimist, auditeerimist ja ülesvoolu muudatustega sammu pidamist.

Integratsioon puudutab ainult olulisi punkte, mis on vajalikud mahtutõestuse toetamiseks. Ploki päist on laiendatud, et sisaldada PoCX-spetsiifilisi välju, ja konsensuse valideerimist on kohandatud hoiustuspõhiste tõestuste töötlemiseks koos traditsiooniliste Bitcoin kontrollide töötlusega. Sepistamissüsteem, mis vastutab tähtaegade, planeerimise ja kaevandaja esituste haldamise eest, sisaldub täielikult PoCX moodulites, samas kui RPC laiendused pakuvad kaevandamise ja ülesannete funktsionaalsust välistele klientidele. Kasutajatele on rahakoti liidest täiustatud ülesannete haldamiseks läbi OP_RETURN tehingute, võimaldades sujuvat suhtlust uute konsensuse funktsioonidega.

Kõik konsensuse jaoks kriitilised operatsioonid on implementeeritud deterministlikus C++-s ilma väliste sõltuvusteta, tagades platvormidevahelist järjepidevust. Shabal256 kasutatakse räsimiseks, samas kui ajapainde ja kvaliteedi arvutamine tuginevad püsipunktaritmeetikale ja 256-bitistele operatsioonidele. Krüptograafilised operatsioonid nagu allkirja verifitseerimine kasutavad Bitcoin Core'i olemasolevat secp256k1 teeki.

PoCX funktsionaalsuse sellisel viisil isoleerides jääb implementatsioon auditeeritavaks, hooldatavaks ja täielikult ühilduvaks käimasoleva Bitcoin Core'i arendusega, demonstreerides, et fundamentaalselt uus hoiustusega seotud konsensusmehhanism saab eksisteerida koos küpse tööst tuletatud tõestuse koodibaasiga, häirimata selle terviklikkust või kasutatavust.

---

## 10. Võrguparameetrid

PoCX ehitab Bitcoin'i võrgu infrastruktuurile ja taaskasutab selle ahela parameetrite raamistikku. Mahtupõhise kaevandamise, plokkide intervallide, ülesannete käsitlemise ja graafikute skaleerimise toetamiseks on mitmeid parameetreid laiendatud või tühistatud. See hõlmab plokkide aja sihtmärki, algset subsiidiumi, poolnemise graafikut, ülesande aktiveerimise ja tühistamise viivitusi ning võrgu identifikaatoreid nagu maagilised baidid, pordid ja Bech32 prefiksid. Testivõrgu ja regtest'i keskkonnad kohandavad neid parameetreid veelgi, et võimaldada kiiret iteratsiooni ja madala mahtuvusega testimist.

Allolevad tabelid võtavad kokku tuleneva mainnet'i, testivõrgu ja regtest'i seaded, tõstes esile, kuidas PoCX kohandab Bitcoin'i põhiparameetreid hoiustusega seotud konsensusmudelile.

### 10.1 Mainnet

| Parameeter | Väärtus |
|------------|---------|
| Maagilised baidid | `0xa7 0x3c 0x91 0x5e` |
| Vaikeport | 8888 |
| Bech32 HRP | `pocx` |
| Plokkide aja sihtmärk | 120 sekundit |
| Algne subsiidium | 10 BTC |
| Poolnemise intervall | 1050000 plokki (~4 aastat) |
| Kogumaht | ~21 miljonit BTC |
| Ülesande aktiveerimine | 30 plokki |
| Ülesande tühistamine | 720 plokki |
| Libisev aken | 24 plokki |

### 10.2 Testnet

| Parameeter | Väärtus |
|------------|---------|
| Maagilised baidid | `0x6d 0xf2 0x48 0xb3` |
| Vaikeport | 18888 |
| Bech32 HRP | `tpocx` |
| Plokkide aja sihtmärk | 120 sekundit |
| Muud parameetrid | Samad mis mainnet'il |

### 10.3 Regtest

| Parameeter | Väärtus |
|------------|---------|
| Maagilised baidid | `0xfa 0xbf 0xb5 0xda` |
| Vaikeport | 18444 |
| Bech32 HRP | `rpocx` |
| Plokkide aja sihtmärk | 1 sekund |
| Poolnemise intervall | 500 plokki |
| Ülesande aktiveerimine | 4 plokki |
| Ülesande tühistamine | 8 plokki |
| Madala mahtuvuse režiim | Lubatud (~4 MB graafikud) |

---

## 11. Seotud tööd

Aastate jooksul on mitmed plokiahela ja konsensuse projektid uurinud hoiustuspõhiseid või hübriidseid kaevandamismudeleid. PoCX ehitab sellele pärandile, tutvustades samal ajal täiustusi turvalisuses, tõhususes ja ühilduvuses.

**Burstcoin / Signum.** Burstcoin tutvustas esimest praktilist mahtutõestuse (PoC) süsteemi 2014. aastal, defineerides põhimõisted nagu graafikud, nonce'd, scoop'id ja tähtajapõhine kaevandamine. Selle järglased, eriti Signum (endine Burstcoin), laiendasid ökosüsteemi ja arenesid lõpuks selleks, mida tuntakse kui kohustuse tõestus (Proof-of-Commitment, PoC+), kombineerides hoiustuskohustust valikulise panustamisega efektiivse mahtuvuse mõjutamiseks. PoCX pärib hoiustuspõhise kaevandamise aluse nendest projektidest, kuid erineb oluliselt läbi karastatud graafikuvormingu (XOR-transponeeri kodeering), dünaamilise graafiku-töö skaleerimise, tähtaegade silumise ("ajapainde") ja paindliku ülesannete süsteemi - kõik selle, ankurdudes samal ajal Bitcoin Core'i koodibaasi, mitte säilitades iseseisvat võrguhargnema.

**Chia.** Chia implementeerib ruumi ja aja tõestust, kombineerides kettapõhiseid hoiustuse tõestusi ajaga, mida jõustatakse verifitseeritavate viivitusfunktsioonide (VDF-ide) kaudu. Selle disain käsitleb teatud probleeme tõestuse taaskasutamise ja värske väljakutse genereerimise kohta, erinevalt klassikalisest PoC-st. PoCX ei võta kasutusele seda ajaankurdatud tõestusmudelit; selle asemel säilitab see hoiustusega seotud konsensust etteaimatavate intervallidega, optimeerituna pikaajaliseks ühilduvuseks UTXO majandusega ja Bitcoin-tuletatud tööriistakomplektiga.

**Spacemesh.** Spacemesh pakub ruumi-aja tõestuse (PoST) skeemi, kasutades DAG-põhist (võrgu) võrgutopoloogiat. Selles mudelis peavad osalejad perioodiliselt tõestama, et eraldatud hoiustus jääb aja jooksul puutumatuks, mitte ei tugine ühele eelarvutatud andmekomplektile. PoCX seevastu verifitseerib hoiustuskohustust ainult ploki ajal - karastatud graafikuvormingute ja range tõestuse valideerimisega - vältides pidevate hoiustuse tõestuste üldkulu, säilitades samal ajal tõhususe ja detsentraliseerituse.

---

## 12. Kokkuvõte

Bitcoin-PoCX demonstreerib, et energiatõhus konsensus saab olla integreeritud Bitcoin Core'i, säilitades samal ajal turvalisuse omadused ja majandusliku mudeli. Põhilised panused hõlmavad XOR-transponeeri kodeeringut (sunnib ründajaid arvutama 4096 nonce'i otsingu kohta, elimineerides kompressiooni rünnaku), ajapainde algoritmi (jaotuse teisendus vähendab plokkide aja varieeruvust), sepistamisülesannete süsteemi (OP_RETURN-põhine delegeerimine võimaldab mitte-hoiustavat basseinikaevandamist), dünaamilist skaleerimist (joondatud poolnemistega ohutuspiiride säilitamiseks) ja minimaalset integratsiooni (funktsiooni lipuga kood isoleeritud pühendatud kataloogis).

Süsteem on praegu testivõrgu faasis. Kaevandusvõimsus tuleneb hoiustusmahust, mitte räsimäärast, vähendades energiatarbimist suurusjärkude võrra, säilitades samal ajal Bitcoin'i tõestatud majandusliku mudeli.

---

## Viited

Bitcoin Core. *Bitcoin Core hoidla.* https://github.com/bitcoin/bitcoin

Burstcoin. *Mahtutõestuse tehniline dokumentatsioon.* 2014.

NIST. *SHA-3 konkurss: Shabal.* 2008.

Cohen, B., Pietrzak, K. *Chia võrgu plokiahel.* 2019.

Spacemesh. *Spacemesh protokolli dokumentatsioon.* 2021.

PoC Consortium. *PoCX raamistik.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Bitcoin-PoCX integratsioon.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Litsents**: MIT
**Organisatsioon**: Proof of Capacity Consortium
**Staatus**: Testivõrgu faas
