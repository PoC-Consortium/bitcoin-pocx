# Bitcoin-PoCX: Energiatehokas konsensus Bitcoin Corelle

**Versio**: 2.0 Luonnos
**Päivämäärä**: Joulukuu 2025
**Organisaatio**: Proof of Capacity Consortium

---

## Tiivistelmä

Bitcoinin Proof-of-Work (PoW) -konsensus tarjoaa vankan turvallisuuden, mutta kuluttaa huomattavasti energiaa jatkuvan reaaliaikaisen tiivistelaskennan vuoksi. Esittelemme Bitcoin-PoCX:n, Bitcoin-haarukan, joka korvaa PoW:n Proof of Capacity (PoC) -konsensuksella, jossa louhijat esigeneroidut ja tallentavat suuria joukkoja levylle tallennettuja tiivisteitä plottauksen aikana ja louhivat sen jälkeen suorittamalla kevyitä hakuja jatkuvan tiivistämisen sijaan. Siirtämällä laskenta louhintavaiheesta kertaluonteiseen plottausvaiheeseen Bitcoin-PoCX vähentää dramaattisesti energiankulutusta mahdollistaen samalla louhinnan tavallisella laitteistolla, madaltaen osallistumiskynnystä ja lieventäen ASIC-hallitun PoW:n keskittymispaineita, säilyttäen samalla Bitcoinin turvallisuusoletukset ja taloudellisen käyttäytymisen.

Toteutuksemme esittelee useita keskeisiä innovaatioita:
(1) Kovennettu plottimuoto, joka eliminoi kaikki tunnetut aika–muisti-vaihtokauppahyökkäykset olemassa olevissa PoC-järjestelmissä varmistaen, että tehokas louhintateho pysyy tiukasti suhteessa sitoutuneeseen tallennuskapasiteettiin;
(2) Time Bending -algoritmi, joka muuntaa deadline-jakaumat eksponentiaalisesta khii-neliö-jakaumaksi vähentäen lohkoajan varianssia muuttamatta keskiarvoa;
(3) OP_RETURN-pohjainen forging-delegointimekanismi, joka mahdollistaa ei-säilytysperusteisen poolilouhinnan; ja
(4) Dynaaminen pakkausskaalaus, joka kasvattaa plotin generoinnin vaikeutta puolittumisaikataulujen mukaisesti pitkäaikaisten turvamarginaalien ylläpitämiseksi laitteiston parantuessa.

Bitcoin-PoCX säilyttää Bitcoin Coren arkkitehtuurin minimaalisilla, feature-lipuitetuilla muutoksilla eristäen PoC-logiikan olemassa olevasta konsensuskoodista. Järjestelmä säilyttää Bitcoinin rahapolitiikan tähtäämällä 120 sekunnin lohkoväliin ja säätämällä lohkopalkkion 10 BTC:hen. Pienennetty palkkio kompensoi viisinkertaisen lohkotiheyden kasvun pitäen pitkän aikavälin liikkeellelaskuasteen linjassa Bitcoinin alkuperäisen aikataulun kanssa ja säilyttäen ~21 miljoonan maksimitarjonnan.

---

## 1. Johdanto

### 1.1 Motivaatio

Bitcoinin Proof-of-Work (PoW) -konsensus on osoittautunut turvalliseksi yli vuosikymmenen ajan, mutta merkittävällä kustannuksella: louhijoiden on jatkuvasti kulutettava laskentaresursseja, mikä johtaa korkeaan energiankulutukseen. Tehokkuushuolten lisäksi on laajempi motivaatio: vaihtoehtoisten konsensusmekanismien tutkiminen, jotka säilyttävät turvallisuuden samalla madaltaen osallistumiskynnystä. PoC mahdollistaa käytännössä kenen tahansa tavallista tallennuslaitteistoa omistavan louhinnan tehokkaasti, vähentäen ASIC-hallitussa PoW-louhinnassa nähtäviä keskittymispaineita.

Proof of Capacity (PoC) saavuttaa tämän johtamalla louhintatehon tallennussitoutumisesta jatkuvan laskennan sijaan. Louhijat esigeneroivat suuria joukkoja levylle tallennettuja tiivisteitä – plotteja – kertaluonteisen plottausvaiheen aikana. Louhinta koostuu sen jälkeen kevyistä hauista, vähentäen dramaattisesti energiankäyttöä säilyttäen samalla resurssipohjaisen konsensuksen turvallisuusoletukset.

### 1.2 Integraatio Bitcoin Coreen

Bitcoin-PoCX integroi PoC-konsensuksen Bitcoin Coreen uuden lohkoketjun luomisen sijaan. Tämä lähestymistapa hyödyntää Bitcoin Coren todistettua turvallisuutta, kypsää verkostopinoa ja laajasti omaksuttuja työkaluja pitäen muutokset minimaalisina ja feature-liputettuina. PoC-logiikka on eristetty olemassa olevasta konsensuskoodista varmistaen, että ydintoiminnallisuus – lohkon validointi, lompakko-operaatiot, transaktiomuodot – pysyy suurelta osin muuttumattomana.

### 1.3 Suunnittelutavoitteet

**Turvallisuus**: Säilytä Bitcoin-vastaava robustisuus; hyökkäykset vaativat enemmistön tallennuskapasiteetista.

**Tehokkuus**: Vähennä jatkuvaa laskentakuormaa levyn I/O -tasolle.

**Saavutettavuus**: Mahdollista louhinta tavallisella laitteistolla madaltaen osallistumiskynnystä.

**Minimaalinen integraatio**: Esittele PoC-konsensus minimaalisella muutosjalanjäljellä.

---

## 2. Tausta: Proof of Capacity

### 2.1 Historia

Proof of Capacity (PoC) esiteltiin Burstcoinin toimesta vuonna 2014 energiatehokkaana vaihtoehtona Proof-of-Workille (PoW). Burstcoin osoitti, että louhintateho voidaan johtaa sitoutuneesta tallennustilasta jatkuvan reaaliaikaisen tiivistämisen sijaan: louhijat esigeneroivat suuria datakokoelmia ("plotteja") kerran ja louhivat sen jälkeen lukemalla pieniä, kiinteitä osia niistä.

Varhaiset PoC-toteutukset todistivat konseptin toimivaksi, mutta paljastivat myös, että plottimuoto ja kryptografinen rakenne ovat kriittisiä turvallisuudelle. Useat aika–muisti-vaihtokaupat mahdollistivat hyökkääjien louhinnan tehokkaasti pienemmällä tallennustilalla kuin rehelliset osallistujat. Tämä korosti, että PoC-turvallisuus riippuu plottisuunnittelusta – ei pelkästään tallennuksen käytöstä resurssina.

Burstcoinin perintö vakiinnutti PoC:n käytännöllisenä konsensusmekanismina ja loi perustan jolle PoCX rakentuu.

### 2.2 Ydinkonseptit

PoC-louhinta perustuu suuriin, esigeneroituihin plottitiedostoihin, jotka on tallennettu levylle. Nämä plotit sisältävät "jäädytettyä laskentaa": kallis tiivistäminen suoritetaan kerran plottauksen aikana, ja louhinta koostuu sen jälkeen kevyistä levyn luvuista ja yksinkertaisesta varmentamisesta. Keskeiset elementit sisältävät:

**Nonce:**
Plottidatan perusyksikkö. Jokainen nonce sisältää 4096 scooopia (256 KiB yhteensä), jotka on generoitu Shabal256:lla louhijan osoitteesta ja nonce-indeksistä.

**Scoop:**
64-tavuinen segmentti noncen sisällä. Jokaiselle lohkolle verkko valitsee deterministisesti scoop-indeksin (0–4095) edellisen lohkon generoinnin allekirjoituksen perusteella. Vain tämä scoop per nonce on luettava.

**Generoinnin allekirjoitus:**
256-bittinen arvo, joka on johdettu edellisestä lohkosta. Se tarjoaa entropian scoop-valintaan ja estää louhijoita ennustamasta tulevia scoop-indeksejä.

**Warp:**
Rakenteellinen ryhmä 4096 noncea (1 GiB). Warpit ovat oleellinen yksikkö pakkausresistenteille plottimuodoille.

### 2.3 Louhintaprosessi ja laatuputki

PoC-louhinta koostuu kertaluonteisesta plottausvaiheesta ja kevyestä lohkokohtaisesta rutiinista:

**Kertaluonteinen asetus:**
- Plotin generointi: Laske noncet Shabal256:lla ja kirjoita ne levylle.

**Lohkokohtainen louhinta:**
- Scoop-valinta: Määritä scoop-indeksi generoinnin allekirjoituksesta.
- Plotin skannaus: Lue kyseinen scoop kaikista nonceista louhijan ploteissa.

**Laatuputki:**
- Raakalaatu: Tiivistä jokainen scoop generoinnin allekirjoituksen kanssa käyttäen Shabal256Liteä saadaksesi 64-bittisen laatuarvon (pienempi on parempi).
- Deadline: Muunna laatu deadlineksi perustavoitteen avulla (vaikeussäädetty parametri, joka varmistaa verkon saavuttavan tavoitellun lohkovälin): `deadline = quality / base_target`
- Taivutettu deadline: Sovella Time Bending -muunnos varianssin vähentämiseksi odotetun lohkoajan säilyttäen.

**Lohkon forging:**
Louhija, jolla on lyhin (taivutettu) deadline, forgaa seuraavan lohkon kun kyseinen aika on kulunut.

Toisin kuin PoW:ssä, käytännössä kaikki laskenta tapahtuu plottauksen aikana; aktiivinen louhinta on ensisijaisesti levysidonnaista ja hyvin matalatehoistta.

### 2.4 Tunnetut haavoittuvuudet aiemmissa järjestelmissä

**POC1-jakeluvirhe:**
Alkuperäinen Burstcoinin POC1-muoto kärsi rakenteellisesta vinoudesta: matalan indeksin scooppien uudelleenlaskenta lennossa oli merkittävästi halvempaa kuin korkean indeksin scooppien. Tämä toi epätasaisen aika–muisti-vaihtokaupan, mahdollistaen hyökkääjien vähentää vaaditun tallennuksen näille scoopeille ja rikkoen oletuksen, että kaikki esigeneroitu data oli yhtä kallista.

**XOR-pakkausshyökkäys (POC2):**
POC2:ssa hyökkääjä voi ottaa minkä tahansa joukon 8192 noncea ja jakaa ne kahteen 4096 noncen lohkoon (A ja B). Sen sijaan, että tallentaisi molemmat lohkot, hyökkääjä tallentaa vain johdetun rakenteen: `A ⊕ transpose(B)`, missä transponointi vaihtaa scoop- ja nonce-indeksit – lohkon B scoop S noncesta N muuttuu scoop N:ksi noncessa S.

Louhinnan aikana, kun scoopin S noncesta N tarvitaan, hyökkääjä palauttaa sen:
1. Lukemalla tallennetun XOR-arvon positiossa (S, N)
2. Laskemalla noncen N lohkosta A saadakseen scoopin S
3. Laskemalla noncen S lohkosta B saadakseen transponoidun scoopin N
4. XOR-operoimalla kaikki kolme arvoa palauttaakseen alkuperäisen 64-tavuisen scoopin

Tämä vähentää tallennusta 50 %, vaatien vain kaksi nonce-laskentaa per haku – kustannus paljon alle kynnyksen, jota tarvitaan täyden esigeneroinnin pakottamiseen. Hyökkäys on toteuttamiskelpoinen, koska rivin laskeminen (yksi nonce, 4096 scooopia) on edullista, kun taas sarakkeen laskeminen (yksittäinen scoop 4096 noncesta) vaatisi kaikkien noncien uudelleengenerointia. Transpose-rakenne paljastaa tämän epätasapainon.

Tämä osoitti tarpeen plottimuodolle, joka estää tällaiset rakenteelliset yhdistelmät ja poistaa taustalla olevan aika–muisti-vaihtokaupan. Osio 3.3 kuvaa miten PoCX käsittelee ja ratkaisee tämän heikkouden.

### 2.5 Siirtymä PoCX:ään

Aiempien PoC-järjestelmien rajoitukset tekivät selväksi, että turvallinen, reilu ja hajautettu tallennuslouhinta riippuu huolellisesti suunnitelluista plottirakenteista. Bitcoin-PoCX käsittelee nämä ongelmat kovennetulla plottimuodolla, parannetulla deadline-jakaumalla ja mekanismeilla hajautetulle poolilouhinnalle – kuvataan seuraavassa osiossa.

---

## 3. PoCX-plottimuoto

### 3.1 Perus-noncen rakentaminen

Nonce on 256 KiB:n datarakenne, joka on johdettu deterministisesti kolmesta parametrista: 20-tavuisesta osoite-payloadista, 32-tavuisesta seedistä ja 64-bittisestä nonce-indeksistä.

Rakentaminen alkaa yhdistämällä nämä syötteet ja tiivistämällä ne Shabal256:lla alkutiivisteen tuottamiseksi. Tämä tiiviste toimii lähtökohtana iteratiiviselle laajennusprosessille: Shabal256 sovelletaan toistuvasti, kunkin vaiheen riippuessa aiemmin generoidusta datasta, kunnes koko 256 KiB:n puskuri on täytetty. Tämä ketjutettu prosessi edustaa laskennallista työtä, joka suoritetaan plottauksen aikana.

Lopullinen diffuusiovaihe tiivistää valmistuneen puskurin ja XOR-operoi tuloksen kaikkien tavujen yli. Tämä varmistaa, että koko puskuri on laskettu ja että louhijat eivät voi oikaista laskennassa. PoC2-sekoitus sovelletaan sen jälkeen, vaihtaen jokaisen scoopin alemman ja ylemmän puoliskon varmistaakseen, että kaikkien scooppien palauttaminen vaatii samanarvoisen laskennallisen työn.

Lopullinen nonce koostuu 4096 scoopista, kukin 64 tavua, ja muodostaa louhinnassa käytetyn perusyksikön.

### 3.2 SIMD-tasattu plotin layout

Läpäisykyvyn maksimoimiseksi modernilla laitteistolla PoCX järjestää nonce-datan levylle vektorisoidun käsittelyn helpottamiseksi. Sen sijaan, että jokainen nonce tallennettaisiin peräkkäin, PoCX tasaa vastaavat 4-tavuiset sanat useiden peräkkäisten noncien kesken yhtenäisesti. Tämä mahdollistaa yhden muistihaun tarjoamaan datan kaikille SIMD-kaistoille minimoiden välimuistin ohitukset ja eliminoiden hajakeruu-yläpuolen.

```
Perinteinen layout:
Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX SIMD-layout:
Word0: [N0][N1][N2]...[N15]
Word1: [N0][N1][N2]...[N15]
Word2: [N0][N1][N2]...[N15]
```

Tämä layout hyödyttää sekä CPU- että GPU-louhijoita mahdollistaen korkean läpäisykyvyn, rinnakkaisen scoop-evaluoinnin säilyttäen yksinkertaisen skalaarisen käyttökuvion konsensusvarmentamiseen. Se varmistaa, että louhinta on rajoitettu tallennuksen kaistanleveyden eikä CPU-laskennan toimesta, ylläpitäen Proof of Capacityn matalatehoisuutta.

### 3.3 Warp-rakenne ja XOR-Transpose-koodaus

Warp on PoCX:n perus tallennusyksikkö, koostuen 4096 noncesta (1 GiB). Pakkaamaton muoto, johon viitataan X0:na, sisältää perus-noncet täsmälleen osion 3.1 rakentamisen mukaisesti tuotettuina.

**XOR-Transpose-koodaus (X1)**

Aiempien PoC-järjestelmien rakenteellisten aika–muisti-vaihtokauppojen poistamiseksi PoCX johtaa kovennetun louhintamuodon, X1:n, soveltamalla XOR-transpose-koodausta X0-warp-pareihin.

X1-warpin scoopin S muodostamiseksi noncelle N:

1. Ota scoop S noncesta N ensimmäisestä X0-warpista (suora sijainti)
2. Ota scoop N noncesta S toisesta X0-warpista (transponoitu sijainti)
3. XOR-operoi kaksi 64-tavuista arvoa X1-scoopin saamiseksi

Transponointivaihe vaihtaa scoop- ja nonce-indeksit. Matriisitermein – missä rivit edustavat scooppeja ja sarakkeet nonceja – se yhdistää elementin positiossa (S, N) ensimmäisessä warpissa elementtiin (N, S) toisessa.

**Miksi tämä eliminoi pakkausshyökkäyspinnan**

XOR-transpose lukitsee jokaisen scoopin kokonaiseen riviin ja sarakkeeseen alla olevasta X0-datasta. Yhden X1-scoopin palauttaminen vaatii siksi pääsyä dataan, joka kattaa kaikki 4096 scoop-indeksiä. Mikä tahansa yritys laskea puuttuvaa dataa vaatisi tuhansien täysien noncien uudelleengenerointia yhden noncen sijaan – poistaen epäsymmetrisen kustannusrakenteen, jota POC2:n XOR-hyökkäys hyödynsi (Osio 2.4).

Täyden X1-warpin tallentamisesta tulee tämän seurauksena ainoa laskennallisesti toteuttamiskelpoinen strategia louhijoille, sulkien aiemmissa suunnitelmissa hyödynnetyn aika–muisti-vaihtokaupan.

### 3.4 Levy-layout

PoCX-plottitiedostot koostuvat monista peräkkäisistä X1-warpeista. Operatiivisen tehokkuuden maksimoimiseksi louhinnan aikana, data jokaisen tiedoston sisällä on järjestetty scoopin mukaan: kaikki scoop 0 -data jokaisesta warpista on tallennettu peräkkäin, jota seuraa kaikki scoop 1 -data, ja niin edelleen scoop 4095:een asti.

Tämä **scoop-peräkkäinen järjestys** mahdollistaa louhijoiden lukea valitun scoopin täydellisen datan yhdellä peräkkäisellä levyn käytöllä minimoiden hakuajat ja maksimoiden läpäisykyvyn tavallisilla tallennuslaitteilla.

Yhdistettynä osion 3.3 XOR-transpose-koodaukseen, tämä layout varmistaa, että tiedosto on sekä **rakenteellisesti kovennettu** että **operatiivisesti tehokas**: peräkkäinen scoop-järjestys tukee optimaalista levyn I/O:ta, kun taas SIMD-tasatut muisti-layoutit (katso Osio 3.2) mahdollistavat korkean läpäisykyvyn, rinnakkaisen scoop-evaluoinnin.

### 3.5 Proof-of-Work-skaalaus (Xn)

PoCX toteuttaa skaalautuvan esigeneroinnin skaalaustasokonseptin kautta, merkittynä Xn, mukautuakseen kehittyvään laitteistosuorituskykyyn. Perustason X1-muoto edustaa ensimmäistä XOR-transpose-kovennettua warp-rakennetta.

Jokainen skaalaustaso Xn kasvattaa jokaiseen warpiin upotettua proof-of-workia eksponentiaalisesti suhteessa X1:een: tason Xn vaatima työ on 2^(n-1) kertaa X1:n työ. Siirtymä Xn:stä Xn+1:een vastaa operatiivisesti XOR:n soveltamista vierekkäisten warp-parien yli, upottaen asteittain enemmän proof-of-workia muuttamatta alla olevaa plottikokoa.

Matalammilla skaalaustsoilla luodut olemassa olevat plottitiedostot voidaan yhä käyttää louhintaan, mutta ne tuottavat suhteellisesti vähemmän työtä lohkon generointiin, heijastaen niiden matalampaa upotettua proof-of-workia. Tämä mekanismi varmistaa, että PoCX-plotit pysyvät turvallisina, joustavina ja taloudellisesti tasapainotettuina ajan myötä.

### 3.6 Seed-toiminnallisuus

Seed-parametri mahdollistaa useita ei-päällekkäisiä plotteja per osoite ilman manuaalista koordinointia.

**Ongelma (POC2)**: Louhijoiden piti manuaalisesti seurata nonce-alueita plottitiedostojen kesken päällekkäisyyden välttämiseksi. Päällekkäiset noncet tuhlaavat tallennustilaa kasvattamatta louhintatehoa.

**Ratkaisu**: Jokainen `(osoite, seed)`-pari määrittelee itsenäisen avainavruuden. Eri seedeillä olevat plotit eivät koskaan mene päällekkäin nonce-alueista riippumatta. Louhijat voivat luoda plotteja vapaasti ilman koordinointia.

---

## 4. Proof of Capacity -konsensus

PoCX laajentaa Bitcoinin Nakamoto-konsensusta tallennussidonnaisella todistemekanismilla. Sen sijaan, että energiaa kulutettaisiin toistuvaan tiivistämiseen, louhijat sitoutuvat suuriin määriin esigeneroitua dataa – plotteja – levylle. Lohkon generoinnin aikana heidän on paikannettava pieni, ennustamaton osa tästä datasta ja muunnettava se todisteeksi. Louhija, joka tarjoaa parhaan todisteen odotetun aikaikkunan sisällä, ansaitsee oikeuden forgata seuraavan lohkon.

Tämä luku kuvaa miten PoCX jäsentää lohkon metadatan, johtaa ennustamattomuuden ja muuntaa staattisen tallennuksen turvalliseksi, matalan varianssin konsensusmekanismiksi.

### 4.1 Lohkorakenne

PoCX säilyttää tutun Bitcoin-tyylisen lohko-otsikon mutta esittelee lisäkonsensuskentät, joita kapasiteettipohjainen louhinta vaatii. Nämä kentät yhdessä sitovat lohkon louhijan tallennettuun plottiin, verkon vaikeuteen ja kryptografiseen entropiaan, joka määrittää kunkin louhintahaasteen.

Korkealla tasolla PoCX-lohko sisältää: lohkon korkeuden, kirjattuna eksplisiittisesti kontekstuaalisen validoinnin yksinkertaistamiseksi; generoinnin allekirjoituksen, tuoreen entropian lähteen, joka linkittää jokaisen lohkon edeltäjäänsä; perustavoitteen, joka edustaa verkon vaikeutta käänteisessä muodossa (korkeammat arvot vastaavat helpompaa louhintaa); PoCX-todisteen, joka identifioi louhijan plotin, plottauksen aikana käytetyn pakkaustason, valitun noncen ja siitä johdetun laadun; sekä allekirjoitusavaimen ja allekirjoituksen, jotka todistavat lohkon forgaamiseen käytetyn kapasiteetin hallinnan (tai delegoidun forging-avaimen).

Todiste upottaa kaiken konsenssin kannalta oleellisen tiedon, jota validoijat tarvitsevat haasteen uudelleenlaskemiseen, valitun scoopin varmentamiseen ja tuloksena saadun laadun vahvistamiseen. Laajentamalla lohkorakennetta sen uudelleensuunnittelun sijaan PoCX pysyy konseptuaalisesti linjassa Bitcoinin kanssa mahdollistaen samalla perustavanlaatuisesti erilaisen louhintatyön lähteen.

### 4.2 Generoinnin allekirjoitusketju

Generoinnin allekirjoitus tarjoaa ennustamattomuuden, jota turvallinen Proof of Capacity -louhinta vaatii. Jokainen lohko johtaa generoinnin allekirjoituksensa edellisen lohkon allekirjoituksesta ja allekirjoittajasta varmistaen, että louhijat eivät voi ennakoida tulevia haasteita tai esigeneroida edullisia plottialueita:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

Tämä tuottaa sarjan kryptografisesti vahvoja, louhijariippuvaisia entropia-arvoja. Koska louhijan julkinen avain on tuntematon kunnes edellinen lohko julkaistaan, kukaan osallistuja ei voi ennustaa tulevia scoop-valintoja. Tämä estää valikoivan esigeneroinnin tai strategisen plottauksen ja varmistaa, että jokainen lohko tuo aidosti tuoretta louhintatyötä.

### 4.3 Forging-prosessi

PoCX-louhinta koostuu tallennetun datan muuntamisesta todisteeksi, jota ohjaa kokonaan generoinnin allekirjoitus. Vaikka prosessi on deterministinen, allekirjoituksen ennustamattomuus varmistaa, että louhijat eivät voi valmistautua etukäteen ja heidän on toistuvasti käytettävä tallennettuja plottejaan.

**Haasteen johtaminen (Scoop-valinta):** Louhija tiivistää nykyisen generoinnin allekirjoituksen lohkon korkeuden kanssa saadakseen scoop-indeksin välillä 0–4095. Tämä indeksi määrittää mikä 64-tavuinen segmentti jokaisesta tallennetusta noncesta osallistuu todisteeseen. Koska generoinnin allekirjoitus riippuu edellisen lohkon allekirjoittajasta, scoop-valinta tunnetaan vasta lohkon julkaisuhetkellä.

**Todisteen evaluointi (Laadun laskenta):** Jokaiselle plotin noncelle louhija hakee valitun scoopin ja tiivistää sen yhdessä generoinnin allekirjoituksen kanssa laadun saamiseksi – 64-bittinen arvo, jonka suuruus määrittää louhijan kilpailukyvyn. Matalampi laatu vastaa parempaa todistetta.

**Deadlinen muodostus (Time Bending):** Raaka deadline on suhteessa laatuun ja kääntäen verrannollinen perustavoitteeseen. Aiemmissa PoC-suunnitelmissa nämä deadlinet noudattivat voimakkaasti vinoutunutta eksponentiaalijakaumaa tuottaen pitkiä häntäviiveitä, jotka eivät tarjonneet lisäturvallisuutta. PoCX muuntaa raa'an deadlinen Time Bendingin avulla (Osio 4.4) varianssin vähentämiseksi ja ennustettavien lohkovälien varmistamiseksi. Kun taivutettu deadline täyttyy, louhija forgaa lohkon upottamalla todisteen ja allekirjoittamalla sen tehokkaalla forging-avaimella.

### 4.4 Time Bending

Proof of Capacity tuottaa eksponentiaalisesti jakautuneita deadlineja. Lyhyen ajanjakson jälkeen – tyypillisesti muutama kymmenen sekuntia – jokainen louhija on jo tunnistanut parhaan todisteensa, ja mikä tahansa lisäodotusaika tuottaa vain viivettä, ei turvallisuutta.

Time Bending muokkaa jakauman soveltamalla kuutiojuurimuunnosta:

`deadline_bended = scale × (quality / base_target)^(1/3)`

Skaalauskerroin säilyttää odotetun lohkoajan (120 sekuntia) samalla vähentäen varianssia dramaattisesti. Lyhyet deadlinet pidennetään parantaen lohkon propagaatiota ja verkon turvallisuutta. Pitkät deadlinet pakataan estäen poikkeamien viivästyttämästä ketjua.

![Lohkoaikajakaumat](blocktime_distributions.svg)

Time Bending säilyttää taustalla olevan todisteen informaatiosisällön. Se ei muuta kilpailukykyä louhijoiden kesken; se ainoastaan uudelleenallokoi odotusajan tasaisempien, ennustettavampien lohkovälien tuottamiseksi. Toteutus käyttää kiintopistearitmetiikkaa (Q42-muoto) ja 256-bittisiä kokonaislukuja determinististen tulosten varmistamiseksi kaikilla alustoilla.

### 4.5 Vaikeuden säätö

PoCX säätelee lohkon tuotantoa perustavoitteella, käänteisellä vaikeusmitalla. Odotettu lohkoaika on suhteessa suhteeseen `quality / base_target`, joten perustavoitteen kasvattaminen nopeuttaa lohkon luontia kun taas sen pienentäminen hidastaa ketjua.

Vaikeus säätyy joka lohkossa käyttäen mitattua aikaa viimeaikaisten lohkojen välillä verrattuna tavoiteväliin. Tämä tiheä säätö on välttämätön, koska tallennuskapasiteettia voidaan lisätä tai poistaa nopeasti – toisin kuin Bitcoinin hash-tehoa, joka muuttuu hitaammin.

Säätö noudattaa kahta ohjaavaa rajoitetta: **Asteittaisuus** – lohkokohtaiset muutokset on rajattu (±20 % maksimi) värähtelyjen tai manipuloinnin välttämiseksi; **Kovetus** – perustavoite ei voi ylittää genesis-arvoaan estäen verkko koskaan laskemasta vaikeutta alle alkuperäisten turvallisuusoletusten.

### 4.6 Lohkon kelvollisuus

PoCX:n lohko on kelvollinen kun se esittää konsensustilan kanssa yhdenmukaisen, varmennettavan tallennusjohdetun todisteen. Validoijat laskevat itsenäisesti uudelleen scoop-valinnan, johtavat odotetun laadun lähetetystä noncesta ja plotin metadatasta, soveltavat Time Bending -muunnoksen ja vahvistavat, että louhija oli oikeutettu forgaamaan lohkon ilmoitettuna aikana.

Erityisesti kelvollinen lohko vaatii: deadline on täyttynyt edellisen lohkon jälkeen; lähetetty laatu vastaa todisteen laskettua laatua; skaalaustaso täyttää verkon minimin; generoinnin allekirjoitus vastaa odotettua arvoa; perustavoite vastaa odotettua arvoa; lohkon allekirjoitus on tehokkaalta allekirjoittajalta; ja coinbase maksaa tehokkaan allekirjoittajan osoitteelle.

---

## 5. Forging-delegoinnit

### 5.1 Motivaatio

Forging-delegoinnit mahdollistavat plotin omistajien delegoida lohkon forging-valtuuden luovuttamatta koskaan plottiensa omistajuutta. Tämä mekanismi mahdollistaa poolilouhinnan ja kylmäsäilytysasetelmat säilyttäen PoCX:n turvallisuustakuut.

Poolilouhinnassa plotin omistajat voivat valtuuttaa poolin forgaamaan lohkoja heidän puolestaan. Pooli kokoaa lohkot ja jakaa palkkiot, mutta se ei koskaan saa haltuunsa plotteja itseään. Delegointi on peruutettavissa milloin tahansa, ja plotin omistajat voivat vapaasti poistua poolista tai muuttaa konfiguraatioita ilman uudelleenplottausta.

Delegoinnit tukevat myös puhdasta erottelua kylmien ja kuumien avainten välillä. Plottia hallitseva yksityinen avain voi pysyä offline-tilassa, kun taas erillinen forging-avain – tallennettu online-koneelle – tuottaa lohkoja. Forging-avaimen vaarantuminen vaarantaa siksi vain forging-valtuuden, ei omistajuutta. Plotti pysyy turvassa ja delegointi voidaan peruuttaa, sulkien turvallisuusaukon välittömästi.

Forging-delegoinnit tarjoavat siten operatiivista joustavuutta säilyttäen periaatteen, että tallennetun kapasiteetin hallintaa ei koskaan siirretä välittäjille.

### 5.2 Delegointiprotokolla

Delegoinnit ilmoitetaan OP_RETURN-transaktioiden kautta UTXO-joukon tarpeettoman kasvun välttämiseksi. Delegointitransaktio määrittää plotin osoitteen ja forging-osoitteen, joka on valtuutettu tuottamaan lohkoja kyseisen plotin kapasiteetilla. Peruutustransaktio sisältää vain plotin osoitteen. Molemmissa tapauksissa plotin omistaja todistaa hallinnan allekirjoittamalla transaktion kulutussyötteen.

Jokainen delegointi etenee selkeästi määriteltyjen tilojen sarjan läpi (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Delegointitransaktion vahvistuksen jälkeen järjestelmä siirtyy lyhyeen aktivointivaiheeseen. Tämä viive – 30 lohkoa, noin tunti – varmistaa vakauden lohkokisojen aikana ja estää forging-identiteettien nopean vaihtamisen. Aktivointijakson täytyttyä delegointi aktivoituu ja pysyy sellaisena kunnes plotin omistaja antaa peruutuksen.

Peruutukset siirtyvät pidempään viivejaksoon 720 lohkoa, noin vuorokausi. Tänä aikana edellinen forging-osoite pysyy aktiivisena. Tämä pidempi viive tarjoaa operatiivista vakautta pooleille estäen strategisen "delegointihyppelyn" ja antaen infrastruktuurin tarjoajille riittävän varmuuden tehokkaaseen toimintaan. Peruutusviiveen täytyttyä peruutus valmistuu, ja plotin omistaja voi vapaasti nimetä uuden forging-avaimen.

Delegointitila ylläpidetään konsensustason rakenteessa rinnakkain UTXO-joukon kanssa ja tukee kumoamisdataa ketjun uudelleenjärjestelyjen turvalliseen käsittelyyn.

### 5.3 Validointisäännöt

Jokaiselle lohkolle validoijat määrittävät tehokkaan allekirjoittajan – osoitteen, jonka on allekirjoitettava lohko ja vastaanotettava coinbase-palkkio. Tämä allekirjoittaja riippuu yksinomaan delegointitilasta lohkon korkeudessa.

Jos delegointia ei ole tai delegointi ei ole vielä täyttänyt aktivointivaihettaan, plotin omistaja pysyy tehokkaana allekirjoittajana. Kun delegointi aktivoituu, delegoidun forging-osoitteen on allekirjoitettava. Peruutuksen aikana forging-osoite jatkaa allekirjoittamista kunnes peruutusviive täyttyy. Vasta sen jälkeen valtuus palautuu plotin omistajalle.

Validoijat pakottavat, että lohkon allekirjoitus on tehokkaan allekirjoittajan tuottama, että coinbase maksaa samalle osoitteelle ja että kaikki siirtymät noudattavat määrättyjä aktivointi- ja peruutusviiveitä. Vain plotin omistaja voi luoda tai peruuttaa delegointeja; forging-avaimet eivät voi muokata tai laajentaa omia käyttöoikeuksiaan.

Forging-delegoinnit esittelevät siten joustavan delegoinnin ilman luottamusta. Alla olevan kapasiteetin omistajuus pysyy aina kryptografisesti ankkuroituna plotin omistajaan, kun taas forging-valtuus voidaan delegoida, kierrättää tai peruuttaa operatiivisten tarpeiden mukaan.

---

## 6. Dynaaminen skaalaus

Laitteiston kehittyessä plottien laskentakustannus pienenee suhteessa esigeneroidun työn lukemiseen levyltä. Ilman vastatoimia hyökkääjät voisivat lopulta generoida todisteita lennossa nopeammin kuin louhijat lukevat tallennettua työtä, heikentäen Proof of Capacityn turvallisuusmallia.

Aiotun turvamarginaalin säilyttämiseksi PoCX toteuttaa skaalausaikataulun: plottien vaadittu vähimmäisskaalaustaso kasvaa ajan myötä. Jokainen skaalaustaso Xn, kuten osio 3.5 kuvaa, upottaa eksponentiaalisesti enemmän proof-of-workia plottirakenteeseen varmistaen, että louhijat jatkavat merkittävien tallennusresurssien sitoutumista vaikka laskenta halpene.

Aikataulu linjautuu verkon taloudellisten kannustimien, erityisesti lohkopalkkioiden puolittumisten, kanssa. Lohkokohtaisen palkkion pienentyessä vähimmäistaso kasvaa asteittain säilyttäen tasapainon plottaustyön ja louhintapotentiaalin välillä:

| Ajanjakso | Vuodet | Puolittumisia | Minimi | Plottityön kerroin |
|--------|-------|----------|-------------|---------------------|
| Epokki 0 | 0-4 | 0 | X1 | 2× perustaso |
| Epokki 1 | 4-12 | 1-2 | X2 | 4× perustaso |
| Epokki 2 | 12-28 | 3-6 | X3 | 8× perustaso |
| Epokki 3 | 28-60 | 7-14 | X4 | 16× perustaso |
| Epokki 4 | 60-124 | 15-30 | X5 | 32× perustaso |
| Epokki 5 | 124+ | 31+ | X6 | 64× perustaso |

Louhijat voivat valinnaisesti valmistella plotteja ylittäen nykyisen minimin yhdellä tasolla, mahdollistaen etukäteissuunnittelun ja välttäen välittömät päivitykset verkon siirtyessä seuraavaan epokkiin. Tämä valinnainen askel ei anna lisäetua lohkon todennäköisyyden suhteen – se ainoastaan mahdollistaa sujuvamman operatiivisen siirtymän.

Lohkot, jotka sisältävät todisteita alle korkeudelle vaaditun vähimmäisskaalaustason, katsotaan kelvottomiksi. Validoijat tarkistavat todisteen ilmoitetun skaalaustason nykyistä verkkovaatimusta vasten konsensusvalidoinnin aikana varmistaen, että kaikki osallistuvat louhijat täyttävät kehittyvät turvallisuusodotukset.

---

## 7. Louhinta-arkkitehtuuri

PoCX erottaa konsensuksen kannalta kriittiset operaatiot resurssivaltaisista louhintatehtävistä mahdollistaen sekä turvallisuuden että tehokkuuden. Solmu ylläpitää lohkoketjua, validoi lohkot, hallitsee mempoolia ja tarjoaa RPC-rajapinnan. Ulkoiset louhijat käsittelevät plotin tallennuksen, scoopin lukemisen, laadun laskennan ja deadlinen hallinnan. Tämä erottelu pitää konsensuslogiikan yksinkertaisena ja auditoitavana samalla kun louhijat voivat optimoida levyn läpäisykykyä.

### 7.1 Louhinnan RPC-rajapinta

Louhijat vuorovaikuttavat solmun kanssa minimaalisen RPC-kutsujoukon kautta. get_mining_info-RPC tarjoaa nykyisen lohkon korkeuden, generoinnin allekirjoituksen, perustavoitteen, tavoitedeadlinen ja plotin skaalaustason hyväksyttävän alueen. Näiden tietojen avulla louhijat laskevat kandidaatti-noncet. submit_nonce-RPC mahdollistaa louhijoiden lähettää ehdotetun ratkaisun sisältäen plotin tunnisteen, nonce-indeksin, skaalaustason ja louhijatilin. Solmu evaluoi lähetyksen ja vastaa lasketulla deadlinella jos todiste on kelvollinen.

### 7.2 Forging-ajastin

Solmu ylläpitää forging-ajastinta, joka seuraa saapuvia lähetyksiä ja säilyttää vain parhaan ratkaisun kullekin lohkokorkeudelle. Lähetetyt noncet jonotetaan sisäänrakennetuilla suojauksilla lähetystulvaa tai palvelunestohyökkäyksiä vastaan. Ajastin odottaa kunnes laskettu deadline täyttyy tai parempi ratkaisu saapuu, jolloin se kokoaa lohkon, allekirjoittaa sen tehokkaalla forging-avaimella ja julkaisee sen verkkoon.

### 7.3 Puolustava forging

Ajoitushyökkäysten tai kellon manipuloinnin kannustimien estämiseksi PoCX toteuttaa puolustavan forgingin. Jos samalla korkeudella saapuu kilpaileva lohko, ajastin vertaa paikallista ratkaisua uuteen lohkoon. Jos paikallinen laatu on parempi, solmu forgaa välittömästi alkuperäisen deadlinen odottamisen sijaan. Tämä varmistaa, että louhijat eivät voi saada etua pelkästään säätämällä paikallisia kelloja; paras ratkaisu voittaa aina, säilyttäen reiluuden ja verkon turvallisuuden.

---

## 8. Turvallisuusanalyysi

### 8.1 Uhkamalli

PoCX mallintaa vastustajat, joilla on merkittäviä mutta rajallisia kykyjä. Hyökkääjät voivat yrittää ylikuormittaa verkkoa kelvottomilla transaktioilla, virheellisillä lohkoilla tai väärennetyillä todisteilla stressitestaten validointipolkuja. He voivat vapaasti manipuloida paikallisia kellojaan ja saattavat yrittää hyödyntää reunatapauksia konsensuskäyttäytymisessä kuten aikaleiman käsittelyssä, vaikeuden säädön dynamiikassa tai uudelleenjärjestelysäännöissä. Vastustajien odotetaan myös tutkivan mahdollisuuksia historian uudelleenkirjoittamiseen kohdennettujen ketjuhaarautumien kautta.

Malli olettaa, ettei yksikään osapuoli hallitse enemmistöä verkon kokonaistallennuskapasiteetista. Kuten minkä tahansa resurssipohjaisen konsensusmekanismin kanssa, 51 % kapasiteetin hyökkääjä voi yksipuolisesti uudelleenjärjestää ketjun; tämä perustavanlaatuinen rajoitus ei ole PoCX-spesifinen. PoCX olettaa myös, että hyökkääjät eivät voi laskea plottidataa nopeammin kuin rehelliset louhijat voivat lukea sitä levyltä. Skaalausaikataulu (Osio 6) varmistaa, että turvallisuuden vaatima laskennallinen ero kasvaa ajan myötä laitteiston parantuessa.

Seuraavat osiot tarkastelevat kutakin merkittävää hyökkäysluokkaa yksityiskohtaisesti ja kuvaavat PoCX:ään rakennetut vastatoimet.

### 8.2 Kapasiteettihyökkäykset

Kuten PoW:ssä, hyökkääjä enemmistökapasiteetilla voi uudelleenkirjoittaa historian (51 % hyökkäys). Tämän saavuttaminen vaatii fyysisen tallennusjalanjäljen hankkimisen, joka on suurempi kuin rehellinen verkko – kallis ja logistisesti vaativa urakka. Kun laitteisto on hankittu, käyttökustannukset ovat matalat, mutta alkuinvestointi luo vahvan taloudellisen kannustimen rehelliseen käyttäytymiseen: ketjun heikentäminen vahingoittaisi hyökkääjän oman omaisuuspohjan arvoa.

PoC välttää myös PoS:ään liittyvän nothing-at-stake-ongelman. Vaikka louhijat voivat skannata plotteja useita kilpailevia haarukkeita vastaan, jokainen skannaus kuluttaa todellista aikaa – tyypillisesti kymmeniä sekunteja per ketju. 120 sekunnin lohkovälillä tämä rajoittaa luonnostaan monihaarukkelouhintaa, ja useiden haarukkejen samanaikainen louhiminen heikentää suorituskykyä kaikissa. Haarukkelouhinta ei siksi ole ilmaista; se on perustavanlaatuisesti rajoitettu I/O-läpäisykyvyn toimesta.

Vaikka tuleva laitteisto mahdollistaisi lähes välittömän plotin skannauksen (esim. nopeat SSD:t), hyökkääjä kohtaisi silti merkittävän fyysisen resurssivaateen verkon kapasiteetin enemmistön hallitsemiseksi, tehden 51 %-tyylisestä hyökkäyksestä kalliin ja logistisesti haastavan.

Kapasiteettihyökkäyksiä on myös paljon vaikeampi vuokrata kuin hash-tehohyökkäyksiä. GPU-laskentaa voi hankkia vaatimalla ja ohjata mihin tahansa PoW-ketjuun välittömästi. Sitä vastoin PoC vaatii fyysistä laitteistoa, aikaavievää plottausta ja jatkuvia I/O-operaatioita. Nämä rajoitukset tekevät lyhytaikaisista, opportunistisista hyökkäyksistä paljon epätoteuttamiskelpoisempia.

### 8.3 Ajoitushyökkäykset

Ajoituksella on kriittisempi rooli Proof of Capacityssä kuin Proof of Workissä. PoW:ssä aikaleimat vaikuttavat ensisijaisesti vaikeuden säätöön; PoC:ssä ne määrittävät onko louhijan deadline täyttynyt ja siten onko lohko oikeutettu forgaamiseen. Deadlinet mitataan suhteessa edellisen lohkon aikaleimaan, mutta solmun paikallista kelloa käytetään arvioimaan onko saapuva lohko liian kaukana tulevaisuudessa. Tästä syystä PoCX pakottaa tiukan aikaleiman toleranssin: lohkot eivät saa poiketa enempää kuin 15 sekuntia solmun paikallisesta kellosta (verrattuna Bitcoinin 2 tunnin ikkunaan). Tämä raja toimii molempiin suuntiin – liian kaukana tulevaisuudessa olevat lohkot hylätään, ja hitailla kelloilla olevat solmut saattavat virheellisesti hylätä kelvollisia saapuvia lohkoja.

Solmujen tulisi siksi synkronoida kellonsa NTP:llä tai vastaavalla aikalähteellä. PoCX välttää tarkoituksella luottamasta verkon sisäisiin aikalähteisiin estääkseen hyökkääjiä manipuloimasta havaittua verkkoaikaa. Solmut seuraavat omaa driftiään ja lähettävät varoituksia jos paikallinen kello alkaa erkaantua viimeaikaisista lohkojen aikaleimoista.

Kellon kiihdyttäminen – nopean paikallisen kellon käyttö forgaamiseen hieman aikaisemmin – tarjoaa vain marginaalisen hyödyn. Sallitun toleranssin puitteissa puolustava forging (Osio 7.3) varmistaa, että louhija paremmalla ratkaisulla julkaisee välittömästi nähdessään huonomman aikaisen lohkon. Nopea kello auttaa louhijaa vain julkaisemaan jo voittavan ratkaisun muutama sekunti aikaisemmin; se ei voi muuntaa huonompaa todistetta voittavaksi.

Yritykset manipuloida vaikeutta aikaleimoin on rajattu ±20 % lohkokohtaisella säätörajoituksella ja 24 lohkon liukuvalla ikkunalla, estäen louhijoita vaikuttamasta merkittävästi vaikeuteen lyhytaikaisten ajoituspelien kautta.

### 8.4 Aika–muisti-vaihtokauppahyökkäykset

Aika–muisti-vaihtokaupat yrittävät vähentää tallennusvaatimuksia laskemalla osia plotista vaatimalla. Aiemmat Proof of Capacity -järjestelmät olivat haavoittuvia tällaisille hyökkäyksille, erityisesti POC1:n scoop-epätasapainovirheelle ja POC2:n XOR-transpose-pakkausshyökkäykselle (Osio 2.4). Molemmat hyödynsivät epäsymmetrioita siinä kuinka kallista tiettyjen plottidatan osien uudelleengenerointi oli, mahdollistaen vastustajien leikata tallennusta maksaen vain pienen laskennallisen rangaistuksen. Myös vaihtoehtoiset plottimuodot PoC2:lle kärsivät samanlaisista TMTO-heikkouksista; merkittävä esimerkki on Chia, jonka plottimuotoa voidaan mielivaltaisesti pienentää yli 4-kertaisesti.

PoCX poistaa nämä hyökkäyspinnat kokonaan nonce-rakenteellaan ja warp-muodollaan. Jokaisen noncen sisällä lopullinen diffuusiovaihe tiivistää täysin lasketun puskurin ja XOR-operoi tuloksen kaikkien tavujen yli varmistaen, että jokainen puskurin osa riippuu jokaisesta muusta osasta eikä sitä voida oikaista. Sen jälkeen PoC2-sekoitus vaihtaa jokaisen scoopin alemman ja ylemmän puoliskon tasaten minkä tahansa scoopin palauttamisen laskennallisen kustannuksen.

PoCX eliminoi edelleen POC2:n XOR-transpose-pakkausshyökkäyksen johtamalla kovennetun X1-muotonsa, missä jokainen scoop on XOR suorasta ja transponoidusta positiosta pariksi asetettujen warpien yli; tämä lukitsee jokaisen scoopin kokonaiseen riviin ja sarakkeeseen alla olevasta X0-datasta, tehden rekonstruktiosta tuhansien täysien noncien vaativan ja siten poistaen epäsymmetrisen aika–muisti-vaihtokaupan kokonaan.

Tuloksena täyden plotin tallentaminen on ainoa laskennallisesti toteuttamiskelpoinen strategia louhijoille. Mikään tunnettu oikotie – olipa se osittainen plottaus, valikoiva uudelleengenerointi, rakenteellinen pakkaus tai hybridit laskenta-tallennus-lähestymistavat – ei tarjoa merkittävää etua. PoCX varmistaa, että louhinta pysyy tiukasti tallennussidonnaisena ja että kapasiteetti heijastaa todellista, fyysistä sitoutumista.

### 8.5 Delegointihyökkäykset

PoCX käyttää deterministista tilakonetta hallitsemaan kaikkia plotti-forger-delegointeja. Jokainen delegointi etenee selkeästi määriteltyjen tilojen läpi – UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED – pakotetuin aktivointi- ja peruutusviivein. Tämä varmistaa, ettei louhija voi välittömästi muuttaa delegointeja järjestelmän huijaamiseksi tai vaihtaa nopeasti forging-valtuutta.

Koska kaikki siirtymät vaativat kryptografisia todisteita – erityisesti plotin omistajan allekirjoituksia, jotka ovat varmennettavissa syöte-UTXO:ta vasten – verkko voi luottaa kunkin delegoinnin oikeutukseen. Yritykset ohittaa tilakoneen tai väärentää delegointeja hylätään automaattisesti konsensusvalidoinnin aikana. Toistohyökkäykset estetään myös vakio Bitcoin-tyylisillä transaktion toistosuojauksilla varmistaen, että jokainen delegointitoiminto on yksilöllisesti sidottu kelvolliseen, kuluttamattomaan syötteeseen.

Tilakonehallinnan, pakotettujen viiveiden ja kryptografisen todisteen yhdistelmä tekee delegointipohjaisesta huijaamisesta käytännössä mahdotonta: louhijat eivät voi kaapata delegointeja, suorittaa nopeaa uudelleendelegointia lohkokisojen aikana tai kiertää peruutusaikatauluja.

### 8.6 Allekirjoitusturvallisuus

PoCX:n lohkoallekirjoitukset toimivat kriittisenä linkkinä todisteen ja tehokkaan forging-avaimen välillä varmistaen, että vain valtuutetut louhijat voivat tuottaa kelvollisia lohkoja.

Muunneltavuushyökkäysten estämiseksi allekirjoitukset jätetään pois lohkon tiivisteen laskennasta. Tämä eliminoi muunneltavien allekirjoitusten riskit, jotka voisivat heikentää validointia tai mahdollistaa lohkon korvaamishyökkäykset.

Palvelunestovektorien lieventämiseksi allekirjoitus- ja julkisen avaimen koot ovat kiinteitä – 65 tavua kompakteille allekirjoituksille ja 33 tavua pakatuille julkisille avaimille – estäen hyökkääjiä paisuttamasta lohkoja resurssien loppumisen aiheuttamiseksi tai verkkopropagaation hidastamiseksi.

---

## 9. Toteutus

PoCX on toteutettu modulaarisena laajennuksena Bitcoin Coreen, kaikki relevantti koodi sisällytettynä omaan erilliseen alihakemistoonsa ja aktivoituna feature-lipulla. Tämä suunnittelu säilyttää alkuperäisen koodin eheyden mahdollistaen PoCX:n puhtaan käyttöönoton tai poistamisen käytöstä, mikä yksinkertaistaa testausta, auditointia ja upstream-muutosten seuraamista.

Integraatio koskettaa vain välttämättömiä kohtia Proof of Capacityn tukemiseksi. Lohko-otsikko on laajennettu PoCX-spesifeillä kentillä, ja konsensusvalidointi on mukautettu käsittelemään tallennuspohjaiset todisteet perinteisten Bitcoin-tarkistusten rinnalla. Forging-järjestelmä, joka vastaa deadlinejen hallinnasta, ajastuksesta ja louhijien lähetyksistä, sisältyy kokonaan PoCX-moduuleihin, kun taas RPC-laajennukset tarjoavat louhinta- ja delegointitoiminnallisuuden ulkoisille asiakkaille. Käyttäjille lompakkorajapintaa on parannettu delegointien hallintaan OP_RETURN-transaktioiden kautta mahdollistaen saumattoman vuorovaikutuksen uusien konsensusominaisuuksien kanssa.

Kaikki konsensuksen kannalta kriittiset operaatiot on toteutettu deterministisellä C++:lla ilman ulkoisia riippuvuuksia varmistaen alustarajat ylittävän yhdenmukaisuuden. Shabal256:ta käytetään tiivistämiseen, kun taas Time Bending ja laadun laskenta nojaavat kiintopistearitmetiikkaan ja 256-bittisiin operaatioihin. Kryptografiset operaatiot kuten allekirjoituksen varmennus hyödyntävät Bitcoin Coren olemassa olevaa secp256k1-kirjastoa.

Eristämällä PoCX-toiminnallisuus tällä tavalla toteutus pysyy auditoitavana, ylläpidettävänä ja täysin yhteensopivana jatkuvan Bitcoin Core -kehityksen kanssa osoittaen, että perustavanlaatuisesti uusi tallennussidonnainen konsensusmekanismi voi rinnakkaiselo kypsän proof-of-work-koodipohjan kanssa häiritsemättä sen eheyttä tai käytettävyyttä.

---

## 10. Verkkoparametrit

PoCX rakentuu Bitcoinin verkkoinfrastruktuurin päälle ja käyttää uudelleen sen ketjuparametrikehystä. Kapasiteettipohjaisen louhinnan, lohkovälien, delegointien käsittelyn ja plotin skaalauksen tukemiseksi useita parametreja on laajennettu tai ohitettu. Tämä sisältää lohkoajan tavoitteen, alkuperäisen palkkion, puolittumisaikataulun, delegoinnin aktivointi- ja peruutusviiveet sekä verkkotunnisteet kuten magiikkatavut, portit ja Bech32-etuliitteet. Testnet- ja regtest-ympäristöt säätävät näitä parametreja edelleen nopean iteroinnin ja matalan kapasiteetin testauksen mahdollistamiseksi.

Alla olevat taulukot tiivistävät tuloksena olevat mainnet-, testnet- ja regtest-asetukset korostaen miten PoCX mukauttaa Bitcoinin ydinparametrit tallennussidonnaiseen konsensusmalliin.

### 10.1 Mainnet

| Parametri | Arvo |
|-----------|-------|
| Magiikkatavut | `0xa7 0x3c 0x91 0x5e` |
| Oletusportti | 8888 |
| Bech32 HRP | `pocx` |
| Lohkoajan tavoite | 120 sekuntia |
| Alkuperäinen palkkio | 10 BTC |
| Puolittumisväli | 1050000 lohkoa (~4 vuotta) |
| Kokonaistarjonta | ~21 miljoonaa BTC |
| Delegoinnin aktivointi | 30 lohkoa |
| Delegoinnin peruutus | 720 lohkoa |
| Liukuva ikkuna | 24 lohkoa |

### 10.2 Testnet

| Parametri | Arvo |
|-----------|-------|
| Magiikkatavut | `0x6d 0xf2 0x48 0xb3` |
| Oletusportti | 18888 |
| Bech32 HRP | `tpocx` |
| Lohkoajan tavoite | 120 sekuntia |
| Muut parametrit | Samat kuin mainnet |

### 10.3 Regtest

| Parametri | Arvo |
|-----------|-------|
| Magiikkatavut | `0xfa 0xbf 0xb5 0xda` |
| Oletusportti | 18444 |
| Bech32 HRP | `rpocx` |
| Lohkoajan tavoite | 1 sekunti |
| Puolittumisväli | 500 lohkoa |
| Delegoinnin aktivointi | 4 lohkoa |
| Delegoinnin peruutus | 8 lohkoa |
| Matalan kapasiteetin tila | Käytössä (~4 MB plotit) |

---

## 11. Aiheeseen liittyvät työt

Vuosien varrella useat lohkoketju- ja konsensusprojektit ovat tutkineet tallennuspohjaisia tai hybriditoimintaisia louhintamalleja. PoCX rakentuu tälle perinnölle tuoden parannuksia turvallisuuteen, tehokkuuteen ja yhteensopivuuteen.

**Burstcoin / Signum.** Burstcoin esitteli ensimmäisen käytännöllisen Proof-of-Capacity (PoC) -järjestelmän vuonna 2014 määrittäen ydinkonseptit kuten plotit, noncet, scoopit ja deadline-pohjaisen louhinnan. Sen seuraajat, erityisesti Signum (entinen Burstcoin), laajensivat ekosysteemiä ja kehittyivät lopulta nimellä Proof-of-Commitment (PoC+) tunnetuksi, yhdistäen tallennussitoutumisen valinnaiseen staking-toimintoon tehollisen kapasiteetin vaikuttamiseksi. PoCX perii tallennuspohjaisen louhinnan perustan näistä projekteista, mutta eroaa merkittävästi kovennetun plottimuodon (XOR-transpose-koodaus), dynaamisen plottityön skaalauksen, deadline-tasoituksen ("Time Bending") ja joustavan delegointijärjestelmän kautta – kaikki ankkuroituna Bitcoin Core -koodipohjaan erillisen verkkohaarukan ylläpidon sijaan.

**Chia.** Chia toteuttaa Proof of Space and Time -konsensuksen yhdistäen levypohjaiset tallennustodisteet aikakomponenttiin, jota pakotetaan Verifiable Delay Functions (VDF) -funktioilla. Sen suunnittelu käsittelee tiettyjä todisteen uudelleenkäytön ja tuoreen haasteen generoinnin huolia, eroten klassisesta PoC:stä. PoCX ei omaksu tätä aika-ankkuroitua todistemallia; sen sijaan se ylläpitää tallennussidonnaista konsensusta ennustettavin välein, optimoituna pitkäaikaiseen yhteensopivuuteen UTXO-talouden ja Bitcoin-johdettujen työkalujen kanssa.

**Spacemesh.** Spacemesh ehdottaa Proof-of-Space-Time (PoST) -järjestelmää käyttäen DAG-pohjaista (mesh) verkkotopologiaa. Tässä mallissa osallistujien on säännöllisesti todistettava, että varattu tallennustila pysyy ehjänä ajan myötä, yhden esigeneroidun datakokoelman sijaan. PoCX sitä vastoin varmentaa tallennussitoutumisen vain lohkon aikana – kovennetuilla plottimuodoilla ja tiukalla todisteen validoinnilla – välttäen jatkuvien tallennustodisteiden yläpuolen säilyttäen tehokkuuden ja hajautuksen.

---

## 12. Johtopäätökset

Bitcoin-PoCX osoittaa, että energiatehokas konsensus voidaan integroida Bitcoin Coreen säilyttäen turvallisuusominaisuudet ja talousmalli. Keskeiset panokset sisältävät XOR-transpose-koodauksen (pakottaa hyökkääjät laskemaan 4096 noncea per haku, eliminoiden pakkausshyökkäyksen), Time Bending -algoritmin (jakauman muunnos vähentää lohkoajan varianssia), forging-delegointijärjestelmän (OP_RETURN-pohjainen delegointi mahdollistaa ei-säilytysperusteisen poolilouhinnan), dynaamisen skaalauksen (linjassa puolittumisten kanssa turvamarginaalien ylläpitämiseksi) ja minimaalisen integraation (feature-liputettu koodi eristettynä omaan hakemistoonsa).

Järjestelmä on tällä hetkellä testiverkkofasissa. Louhintateho johdetaan tallennuskapasiteetista hash-nopeuden sijaan vähentäen energiankulutusta suuruusluokkia säilyttäen samalla Bitcoinin todistetun talousmallin.

---

## Viitteet

Bitcoin Core. *Bitcoin Core Repository.* https://github.com/bitcoin/bitcoin

Burstcoin. *Proof of Capacity Technical Documentation.* 2014.

NIST. *SHA-3 Competition: Shabal.* 2008.

Cohen, B., Pietrzak, K. *The Chia Network Blockchain.* 2019.

Spacemesh. *Spacemesh Protocol Documentation.* 2021.

PoC Consortium. *PoCX Framework.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Bitcoin-PoCX Integration.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Lisenssi**: MIT
**Organisaatio**: Proof of Capacity Consortium
**Tila**: Testiverkkofase
