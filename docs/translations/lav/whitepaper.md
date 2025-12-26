# Bitcoin-PoCX: Energoefektīvs konsensuss Bitcoin Core platformai

**Versija**: 2.0 melnraksts
**Datums**: 2025. gada decembris
**Organizācija**: Proof of Capacity Consortium

---

## Kopsavilkums

Bitcoin darba apliecinājuma (Proof-of-Work, PoW) konsensuss nodrošina stabilu drošību, taču patērē ievērojamu enerģijas daudzumu nepārtrauktu reāllaika heša aprēķinu dēļ. Mēs prezentējam Bitcoin-PoCX — Bitcoin atvasinājumu, kas aizstāj PoW ar ietilpības apliecinājumu (Proof of Capacity, PoC), kur raktuvnieki iepriekš aprēķina un saglabā lielas diskā glabātas hešu kopas plotēšanas laikā un pēc tam veic rakšanu, izpildot vieglus meklējumus, nevis nepārtrauktus hešēšanas aprēķinus. Pārvietojot aprēķinus no rakšanas posma uz vienreizēju plotēšanas posmu, Bitcoin-PoCX būtiski samazina enerģijas patēriņu, vienlaikus ļaujot veikt rakšanu ar standarta aparatūru, pazeminot dalības barjeru un mazinot centralizācijas spiedienu, kas raksturīgs ASIC dominētai PoW ekosistēmai, saglabājot Bitcoin drošības pieņēmumus un ekonomisko uzvedību.

Mūsu implementācija ievieš vairākas būtiskas inovācijas:
(1) Nostiprinātu plota formātu, kas novērš visus zināmos laika-atmiņas kompromisa uzbrukumus esošajās PoC sistēmās, nodrošinot, ka efektīvā rakšanas jauda paliek stingri proporcionāla piešķirtajai krātuves ietilpībai;
(2) Time-Bending algoritmu, kas transformē termiņu sadalījumus no eksponenciālā uz chi-kvadrāta sadalījumu, samazinot bloku laika dispersiju, nemainot vidējo vērtību;
(3) OP_RETURN balstītu kalšanas piešķiršanas mehānismu, kas nodrošina nekustodālu pūla rakšanu; un
(4) Dinamisku kompresijas mērogošanu, kas palielina plota ģenerēšanas sarežģītību saskaņā ar dalīšanas grafikiem, lai uzturētu ilgtermiņa drošības rezerves, aparatūrai attīstoties.

Bitcoin-PoCX saglabā Bitcoin Core arhitektūru ar minimālām, funkciju karodziņiem kontrolētām modifikācijām, izolējot PoC loģiku no esošā konsensusa koda. Sistēma saglabā Bitcoin monetāro politiku, mērķējot uz 120 sekunžu bloku intervālu un pielāgojot bloka subsīdiju līdz 10 BTC. Samazinātā subsīdija kompensē piecu reižu palielināto bloku biežumu, saglabājot ilgtermiņa emisijas likmi saskaņā ar Bitcoin sākotnējo grafiku un uzturot ~21 miljona maksimālo piedāvājumu.

---

## 1. Ievads

### 1.1 Motivācija

Bitcoin darba apliecinājuma (PoW) konsensuss ir pierādījis savu drošību vairāk nekā desmit gadu garumā, taču ar būtiskām izmaksām: raktuvniekiem nepārtraukti jāpatērē skaitļošanas resursi, kas rada augstu enerģijas patēriņu. Papildus efektivitātes jautājumiem pastāv plašāka motivācija: alternatīvu konsensusa mehānismu izpēte, kas saglabā drošību, vienlaikus pazeminot dalības barjeru. PoC ļauj praktiski jebkuram ar standarta krātuves aparatūru efektīvi veikt rakšanu, samazinot centralizācijas spiedienu, kas vērojams ASIC dominētā PoW rakšanā.

Ietilpības apliecinājums (PoC) to panāk, iegūstot rakšanas jaudu no krātuves piešķīruma, nevis no nepārtrauktas skaitļošanas. Raktuvnieki iepriekš aprēķina lielas diskā glabātu hešu kopas — plotus — vienreizējā plotēšanas posmā. Pēc tam rakšana sastāv no viegliem meklējumiem, krasi samazinot enerģijas patēriņu, vienlaikus saglabājot uz resursiem balstīta konsensusa drošības pieņēmumus.

### 1.2 Integrācija ar Bitcoin Core

Bitcoin-PoCX integrē PoC konsensusu Bitcoin Core platformā, nevis veido jaunu blokķēdi. Šī pieeja izmanto Bitcoin Core pārbaudīto drošību, nobriedušo tīkla steku un plaši pieņemtos rīkus, vienlaikus saglabājot modifikācijas minimālas un kontrolētas ar funkciju karodziņiem. PoC loģika ir izolēta no esošā konsensusa koda, nodrošinot, ka pamata funkcionalitāte — bloku validācija, maka operācijas, darījumu formāti — paliek lielākoties nemainīta.

### 1.3 Projektēšanas mērķi

**Drošība**: Saglabāt Bitcoin līmeņa stabilitāti; uzbrukumiem nepieciešama vairākuma krātuves ietilpība.

**Efektivitāte**: Samazināt nepārtraukto skaitļošanas slodzi līdz diska I/O līmenim.

**Pieejamība**: Nodrošināt rakšanu ar standarta aparatūru, pazeminot ienākšanas barjeras.

**Minimāla integrācija**: Ieviest PoC konsensusu ar minimālu modifikāciju pēdu.

---

## 2. Priekšvēsture: Ietilpības apliecinājums

### 2.1 Vēsture

Ietilpības apliecinājumu (PoC) 2014. gadā ieviesa Burstcoin kā energoefektīvu alternatīvu darba apliecinājumam (PoW). Burstcoin demonstrēja, ka rakšanas jaudu var iegūt no piešķirtas krātuves, nevis no nepārtrauktas reāllaika hešēšanas: raktuvnieki vienreiz iepriekš aprēķināja lielas datu kopas ("plotus") un pēc tam veica rakšanu, nolasot nelielas, fiksētas to daļas.

Agrīnās PoC implementācijas pierādīja koncepta dzīvotspēju, taču atklāja arī to, ka plota formāts un kriptogrāfiskā struktūra ir kritiski drošībai. Vairāki laika-atmiņas kompromisi ļāva uzbrucējiem efektīvi veikt rakšanu ar mazāku krātuvi nekā godīgiem dalībniekiem. Tas uzsvēra, ka PoC drošība balstās uz plota projektējumu — ne tikai uz krātuves izmantošanu kā resursu.

Burstcoin mantojums nostiprināja PoC kā praktisku konsensusa mehānismu un nodrošināja pamatu, uz kura balstās PoCX.

### 2.2 Pamatkoncepcijas

PoC rakšana balstās uz lieliem, iepriekš aprēķinātiem plota failiem, kas glabājas diskā. Šie ploti satur "iesaldētu skaitļošanu": dārga hešēšana tiek veikta vienreiz plotēšanas laikā, un rakšana pēc tam sastāv no viegliem diska nolasījumiem un vienkāršas verifikācijas. Pamatkomponenti ietver:

**Nonce:**
Plota datu pamatvienība. Katrs nonce satur 4096 scoopus (kopā 256 KiB), kas ģenerēti ar Shabal256 no raktuvnieka adreses un nonce indeksa.

**Scoop:**
64 baitu segments nonce iekšienē. Katram blokam tīkls deterministiski izvēlas scoop indeksu (0–4095) balstoties uz iepriekšējā bloka ģenerēšanas parakstu. Jānolasa tikai šis scoop no katra nonce.

**Ģenerēšanas paraksts:**
256 bitu vērtība, kas iegūta no iepriekšējā bloka. Tā nodrošina entropiju scoop izvēlei un neļauj raktuvniekiem paredzēt nākotnes scoop indeksus.

**Warp:**
Strukturāla 4096 nonce grupa (1 GiB). Warpi ir būtiska vienība kompresijas izturīgiem plota formātiem.

### 2.3 Rakšanas process un kvalitātes konveijers

PoC rakšana sastāv no vienreizēja plotēšanas soļa un vieglas katram blokam paredzētas rutīnas:

**Vienreizēja uzstādīšana:**
- Plota ģenerēšana: Aprēķināt nonce vērtības ar Shabal256 un ierakstīt tās diskā.

**Katram blokam paredzēta rakšana:**
- Scoop izvēle: Noteikt scoop indeksu no ģenerēšanas paraksta.
- Plota skenēšana: Nolasīt šo scoop no visiem nonce raktuvnieka plotos.

**Kvalitātes konveijers:**
- Neapstrādāta kvalitāte: Hešēt katru scoop ar ģenerēšanas parakstu, izmantojot Shabal256Lite, lai iegūtu 64 bitu kvalitātes vērtību (zemāka ir labāka).
- Termiņš: Konvertēt kvalitāti termiņā, izmantojot bāzes mērķi (sarežģītībai pielāgotu parametru, kas nodrošina, ka tīkls sasniedz mērķa bloku intervālu): `deadline = quality / base_target`
- Liekts termiņš: Pielietot Time-Bending transformāciju, lai samazinātu dispersiju, saglabājot paredzamo bloka laiku.

**Bloka kalšana:**
Raktuvnieks ar īsāko (liekto) termiņu kaļ nākamo bloku, kad šis laiks ir pagājis.

Atšķirībā no PoW, gandrīz visa skaitļošana notiek plotēšanas laikā; aktīvā rakšana galvenokārt ir diska ierobežota un ļoti zemas jaudas.

### 2.4 Zināmās ievainojamības iepriekšējās sistēmās

**POC1 sadalījuma kļūda:**
Sākotnējam Burstcoin POC1 formātam bija strukturāla novirze: zema indeksa scoopus bija ievērojami lētāk pārrēķināt lidojumā nekā augsta indeksa scoopus. Tas ieviesa nevienmērīgu laika-atmiņas kompromisu, ļaujot uzbrucējiem samazināt nepieciešamo krātuvi šiem scoopiem un laužot pieņēmumu, ka visi iepriekš aprēķinātie dati bija vienlīdz dārgi.

**XOR kompresijas uzbrukums (POC2):**
POC2 sistēmā uzbrucējs var paņemt jebkuru 8192 nonce kopu un sadalīt tos divos 4096 nonce blokos (A un B). Tā vietā, lai glabātu abus blokus, uzbrucējs glabā tikai atvasinātu struktūru: `A ⊕ transpose(B)`, kur transponēšana apmaina scoop un nonce indeksus — B bloka nonce N scoop S kļūst par nonce S scoop N.

Rakšanas laikā, kad nepieciešams nonce N scoop S, uzbrucējs to rekonstruē:
1. Nolasot saglabāto XOR vērtību pozīcijā (S, N)
2. Aprēķinot nonce N no A bloka, lai iegūtu scoop S
3. Aprēķinot nonce S no B bloka, lai iegūtu transponēto scoop N
4. Veicot XOR visām trim vērtībām, lai atgūtu oriģinālo 64 baitu scoop

Tas samazina krātuvi par 50%, prasot tikai divus nonce aprēķinus katrā meklējumā — izmaksas, kas ir krietni zem sliekšņa, kas nepieciešams pilnas iepriekšaprēķināšanas nodrošināšanai. Uzbrukums ir iespējams, jo rindas aprēķināšana (viens nonce, 4096 scoopi) ir lēta, turpretī kolonnas aprēķināšana (viens scoop pāri 4096 nonce) prasītu visu nonce atjaunošanu. Transponēšanas struktūra atsedz šo nelīdzsvarotību.

Tas demonstrēja nepieciešamību pēc plota formāta, kas novērš šādu strukturētu rekombināciju un likvidē pamatā esošo laika-atmiņas kompromisu. 3.3. sadaļā aprakstīts, kā PoCX risina un novērš šo vājību.

### 2.5 Pāreja uz PoCX

Agrāko PoC sistēmu ierobežojumi skaidri parādīja, ka droša, godīga un decentralizēta krātuves rakšana ir atkarīga no rūpīgi inženierētām plota struktūrām. Bitcoin-PoCX risina šīs problēmas ar nostiprinātu plota formātu, uzlabotu termiņu sadalījumu un mehānismiem decentralizētai pūla rakšanai — aprakstīti nākamajā sadaļā.

---

## 3. PoCX plota formāts

### 3.1 Pamata nonce konstrukcija

Nonce ir 256 KiB datu struktūra, kas deterministiski iegūta no trim parametriem: 20 baitu adreses slodzes, 32 baitu sēklas un 64 bitu nonce indeksa.

Konstrukcija sākas, apvienojot šīs ievades un hešējot tās ar Shabal256, lai iegūtu sākotnējo hešu. Šis hešs kalpo kā sākumpunkts iteratīvam paplašināšanas procesam: Shabal256 tiek pielietots atkārtoti, katram solim atkarīgam no iepriekš ģenerētiem datiem, līdz viss 256 KiB buferis ir aizpildīts. Šis ķēdētais process atspoguļo skaitļošanas darbu, kas veikts plotēšanas laikā.

Beigu difūzijas solis hešē pabeigto buferi un veic XOR rezultātam pāri visiem baitiem. Tas nodrošina, ka viss buferis ir ticis aprēķināts un ka raktuvnieki nevar saīsināt aprēķinu. Pēc tam tiek pielietota PoC2 jaukšana, apmainot katra scoopa apakšējo un augšējo pusi, lai garantētu, ka visi scoopi prasa ekvivalentu skaitļošanas piepūli.

Galīgais nonce sastāv no 4096 scoopiem pa 64 baitiem katrs un veido pamatvienību, ko izmanto rakšanā.

### 3.2 SIMD izlīdzināts plota izkārtojums

Lai maksimizētu caurlaidspēju uz mūsdienu aparatūras, PoCX organizē nonce datus diskā, lai atvieglotu vektorizētu apstrādi. Tā vietā, lai glabātu katru nonce secīgi, PoCX izlīdzina atbilstošos 4 baitu vārdus pāri vairākiem secīgiem nonce blakus. Tas ļauj vienai atmiņas ielādei nodrošināt datus visām SIMD joslām, minimizējot kešatmiņas netrāpījumus un novēršot izkliedēšanas-savākšanas pieskaitāmās izmaksas.

```
Tradicionāls izkārtojums:
Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX SIMD izkārtojums:
Word0: [N0][N1][N2]...[N15]
Word1: [N0][N1][N2]...[N15]
Word2: [N0][N1][N2]...[N15]
```

Šis izkārtojums sniedz labumu gan CPU, gan GPU raktuvniekiem, nodrošinot augstas caurlaidspējas, paralēlu scoop novērtēšanu, vienlaikus saglabājot vienkāršu skalāru piekļuves modeli konsensusa verifikācijai. Tas nodrošina, ka rakšanu ierobežo krātuves joslas platums, nevis CPU skaitļošana, uzturot Proof of Capacity zemas jaudas dabu.

### 3.3 Warp struktūra un XOR-transponēšanas kodēšana

Warp ir pamata krātuves vienība PoCX, kas sastāv no 4096 nonce (1 GiB). Nekompresētais formāts, saukts par X0, satur pamata nonce tieši tādus, kā tie iegūti ar 3.1. sadaļā aprakstīto konstrukciju.

**XOR-transponēšanas kodēšana (X1)**

Lai novērstu strukturālus laika-atmiņas kompromisus, kas bija agrākajās PoC sistēmās, PoCX iegūst nostiprinātu rakšanas formātu X1, pielietojot XOR-transponēšanas kodēšanu X0 warpu pāriem.

Lai konstruētu scoop S no nonce N X1 warpā:

1. Paņemt scoop S no nonce N no pirmā X0 warpa (tiešā pozīcija)
2. Paņemt scoop N no nonce S no otrā X0 warpa (transponētā pozīcija)
3. Veikt XOR abām 64 baitu vērtībām, lai iegūtu X1 scoop

Transponēšanas solis apmaina scoop un nonce indeksus. Matricas izteiksmē — kur rindas attēlo scoopus un kolonnas attēlo nonce — tas apvieno elementu pozīcijā (S, N) pirmajā warpā ar elementu (N, S) otrajā.

**Kāpēc tas novērš kompresijas uzbrukuma virsmu**

XOR-transponēšana savstarpēji saslēdz katru scoop ar veselu pamatā esošo X0 datu rindu un veselu kolonnu. Viena X1 scoop atgūšana tāpēc prasa piekļuvi datiem, kas aptver visus 4096 scoop indeksus. Jebkurš mēģinājums aprēķināt trūkstošos datus prasītu 4096 pilnu nonce atjaunošanu, nevis vienu nonce — likvidējot asimetrisko izmaksu struktūru, ko izmantoja XOR uzbrukums POC2 (2.4. sadaļa).

Rezultātā pilna X1 warpa glabāšana kļūst par vienīgo skaitļošanas ziņā dzīvotspējīgo stratēģiju raktuvniekiem, aizvērtot laika-atmiņas kompromisu, ko izmantoja iepriekšējie dizaini.

### 3.4 Diska izkārtojums

PoCX plota faili sastāv no daudziem secīgiem X1 warpiem. Lai maksimizētu operacionālo efektivitāti rakšanas laikā, dati katrā failā ir organizēti pēc scoop: visi scoop 0 dati no katra warpa tiek glabāti secīgi, kam seko visi scoop 1 dati, un tā tālāk līdz scoop 4095.

Šī **scoop-secīgā kārtošana** ļauj raktuvniekiem nolasīt pilnus datus, kas nepieciešami izvēlētajam scoop, vienā secīgā diska piekļuvē, minimizējot meklēšanas laikus un maksimizējot caurlaidspēju uz standarta krātuves ierīcēm.

Kopā ar 3.3. sadaļas XOR-transponēšanas kodēšanu šis izkārtojums nodrošina, ka fails ir gan **strukturāli nostiprināts**, gan **operacionāli efektīvs**: secīga scoop kārtošana atbalsta optimālu diska I/O, bet SIMD izlīdzināti atmiņas izkārtojumi (skatīt 3.2. sadaļu) nodrošina augstas caurlaidspējas, paralēlu scoop novērtēšanu.

### 3.5 Darba apliecinājuma mērogošana (Xn)

PoCX implementē mērogojamu iepriekšaprēķināšanu caur mērogošanas līmeņu koncepciju, apzīmētu kā Xn, lai pielāgotos aparatūras veiktspējas attīstībai. Sākotnējais X1 formāts atspoguļo pirmo XOR-transponēšanas nostiprināto warpa struktūru.

Katrs mērogošanas līmenis Xn eksponenciāli palielina katrā warpā iegulto darba apliecinājumu salīdzinājumā ar X1: darbs, kas nepieciešams līmenī Xn, ir 2^(n-1) reižu lielāks nekā X1. Pāreja no Xn uz Xn+1 operacionāli ir ekvivalenta XOR pielietošanai pāri blakus esošu warpu pāriem, pakāpeniski ieguldot vairāk darba apliecinājuma, nemainot pamatā esošo plota izmēru.

Esošos plota failus, kas izveidoti zemākos mērogošanas līmeņos, joprojām var izmantot rakšanai, taču tie proporcionāli sniedz mazāku darbu bloku ģenerēšanā, atspoguļojot to zemāko iegulto darba apliecinājumu. Šis mehānisms nodrošina, ka PoCX ploti laika gaitā paliek droši, elastīgi un ekonomiski līdzsvaroti.

### 3.6 Sēklas funkcionalitāte

Sēklas parametrs ļauj vienai adresei izveidot vairākus nepārklājošus plotus bez manuālas koordinācijas.

**Problēma (POC2)**: Raktuvniekiem bija manuāli jāizseko nonce diapazoniem pāri plota failiem, lai izvairītos no pārklāšanās. Pārklājoši nonce tērē krātuvi, nepalielinot rakšanas jaudu.

**Risinājums**: Katrs `(adrese, sēkla)` pāris definē neatkarīgu atslēgtelpu. Ploti ar dažādām sēklām nekad nepārklājas neatkarīgi no nonce diapazoniem. Raktuvnieki var brīvi veidot plotus bez koordinācijas.

---

## 4. Ietilpības apliecinājuma konsensuss

PoCX paplašina Bitcoin Nakamoto konsensusu ar krātuvei piesaistītu apliecinājuma mehānismu. Tā vietā, lai tērētu enerģiju atkārtotai hešēšanai, raktuvnieki iepriekš sagatavo lielus daudzumus iepriekš aprēķinātu datu — plotus — diskā. Bloka ģenerēšanas laikā viņiem jāatrod neliela, neprognozējama šo datu daļa un jāpārveido tā apliecinājumā. Raktuvnieks, kurš nodrošina labāko apliecinājumu paredzētajā laika logā, iegūst tiesības kalt nākamo bloku.

Šajā nodaļā aprakstīts, kā PoCX strukturē bloka metadatus, iegūst neprognozējamību un pārveido statisku krātuvi drošā, zemas dispersijas konsensusa mehānismā.

### 4.1 Bloka struktūra

PoCX saglabā pazīstamo Bitcoin stila bloka galveni, bet ievieš papildu konsensusa laukus, kas nepieciešami uz ietilpību balstītai rakšanai. Šie lauki kopā sasaista bloku ar raktuvnieka saglabāto plotu, tīkla sarežģītību un kriptogrāfisko entropiju, kas definē katru rakšanas izaicinājumu.

Augstā līmenī PoCX bloks satur: bloka augstumu, kas ierakstīts tieši, lai vienkāršotu kontekstuālu validāciju; ģenerēšanas parakstu, svaigas entropijas avotu, kas saista katru bloku ar tā priekšteci; bāzes mērķi, kas atspoguļo tīkla sarežģītību apgrieztā formā (augstākas vērtības atbilst vieglākai rakšanai); PoCX apliecinājumu, kas identificē raktuvnieka plotu, plotēšanā izmantoto kompresijas līmeni, izvēlēto nonce un no tā iegūto kvalitāti; un parakstīšanas atslēgu un parakstu, kas pierāda kontroli pār ietilpību, kas izmantota bloka kalšanai (vai pār piešķirto kalšanas atslēgu).

Apliecinājums iegulst visu konsensusa ziņā būtisko informāciju, kas nepieciešama validatoriem, lai pārrēķinātu izaicinājumu, verificētu izvēlēto scoop un apstiprinātu rezultējošo kvalitāti. Paplašinot, nevis pārprojektējot bloka struktūru, PoCX paliek konceptuāli saskaņots ar Bitcoin, vienlaikus nodrošinot fundamentāli atšķirīgu rakšanas darba avotu.

### 4.2 Ģenerēšanas parakstu ķēde

Ģenerēšanas paraksts nodrošina neprognozējamību, kas nepieciešama drošai Proof of Capacity rakšanai. Katrs bloks iegūst savu ģenerēšanas parakstu no iepriekšējā bloka paraksta un parakstītāja, nodrošinot, ka raktuvnieki nevar paredzēt nākotnes izaicinājumus vai iepriekš aprēķināt izdevīgus plota reģionus:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

Tas rada secību kriptogrāfiski stipru, no raktuvnieka atkarīgu entropijas vērtību. Tā kā raktuvnieka publiskā atslēga nav zināma, līdz iepriekšējais bloks ir publicēts, neviens dalībnieks nevar paredzēt nākotnes scoop izvēles. Tas novērš selektīvu iepriekšaprēķināšanu vai stratēģisku plotēšanu un nodrošina, ka katrs bloks ievieš patiesi svaigu rakšanas darbu.

### 4.3 Kalšanas process

Rakšana PoCX sastāv no saglabāto datu pārveidošanas apliecinājumā, kas pilnībā vadīts no ģenerēšanas paraksta. Lai gan process ir deterministisks, paraksta neprognozējamība nodrošina, ka raktuvnieki nevar sagatavoties iepriekš un tiem atkārtoti jāpiekļūst saviem saglabātajiem plotiem.

**Izaicinājuma atvasināšana (Scoop izvēle):** Raktuvnieks hešē pašreizējo ģenerēšanas parakstu ar bloka augstumu, lai iegūtu scoop indeksu diapazonā 0–4095. Šis indekss nosaka, kurš 64 baitu segments no katra saglabātā nonce piedalās apliecinājumā. Tā kā ģenerēšanas paraksts ir atkarīgs no iepriekšējā bloka parakstītāja, scoop izvēle kļūst zināma tikai bloka publicēšanas brīdī.

**Apliecinājuma novērtēšana (Kvalitātes aprēķins):** Katram nonce plotā raktuvnieks izgūst izvēlēto scoop un hešē to kopā ar ģenerēšanas parakstu, lai iegūtu kvalitāti — 64 bitu vērtību, kuras lielums nosaka raktuvnieka konkurētspēju. Zemāka kvalitāte atbilst labākam apliecinājumam.

**Termiņa formēšana (Time Bending):** Neapstrādātais termiņš ir proporcionāls kvalitātei un apgriezti proporcionāls bāzes mērķim. Mantotajos PoC dizainos šie termiņi sekoja ļoti šķībi eksponenciālam sadalījumam, radot garās astes aizkaves, kas nesniedza papildu drošību. PoCX transformē neapstrādāto termiņu, izmantojot Time Bending (4.4. sadaļa), samazinot dispersiju un nodrošinot prognozējamus bloku intervālus. Kad liektais termiņš beidzas, raktuvnieks kaļ bloku, ieguldot tajā apliecinājumu un parakstot to ar efektīvo kalšanas atslēgu.

### 4.4 Time Bending

Proof of Capacity rada eksponenciāli sadalītus termiņus. Pēc īsa perioda — parasti dažas desmitiem sekundes — katrs raktuvnieks jau ir identificējis savu labāko apliecinājumu, un jebkurš papildu gaidīšanas laiks sniedz tikai latentumu, nevis drošību.

Time Bending pārveido sadalījumu, pielietojot kubsaknes transformāciju:

`deadline_bended = scale × (quality / base_target)^(1/3)`

Mēroga faktors saglabā paredzamo bloka laiku (120 sekundes), vienlaikus dramatiski samazinot dispersiju. Īsie termiņi tiek paplašināti, uzlabojot bloku izplatīšanos un tīkla drošību. Garie termiņi tiek saspiesti, novēršot izņēmumus no ķēdes aizkavēšanas.

![Bloka laika sadalījumi](blocktime_distributions.svg)

Time Bending saglabā pamatā esošā apliecinājuma informatīvo saturu. Tas nemodificē konkurētspēju starp raktuvniekiem; tas tikai pārdala gaidīšanas laiku, lai radītu gludākus, prognozējamākus bloku intervālus. Implementācija izmanto fiksēta punkta aritmētiku (Q42 formāts) un 256 bitu veselus skaitļus, lai nodrošinātu deterministiskus rezultātus visās platformās.

### 4.5 Sarežģītības pielāgošana

PoCX regulē bloku ražošanu, izmantojot bāzes mērķi — apgrieztu sarežģītības mēru. Paredzamais bloka laiks ir proporcionāls attiecībai `quality / base_target`, tāpēc bāzes mērķa palielināšana paātrina bloku veidošanu, bet tā samazināšana palēnina ķēdi.

Sarežģītība tiek pielāgota katrā blokā, izmantojot izmērīto laiku starp nesenajiem blokiem salīdzinājumā ar mērķa intervālu. Šī biežā pielāgošana ir nepieciešama, jo krātuves ietilpību var pievienot vai noņemt ātri — atšķirībā no Bitcoin heš jaudas, kas mainās lēnāk.

Pielāgošana seko diviem vadošajiem ierobežojumiem: **Pakāpeniskums** — katram blokam izmaiņas ir ierobežotas (±20% maksimums), lai izvairītos no svārstībām vai manipulācijām; **Nostiprināšana** — bāzes mērķis nevar pārsniegt savu ģenēzes vērtību, novēršot tīkla sarežģītības pazemināšanu zem sākotnējiem drošības pieņēmumiem.

### 4.6 Bloka derīgums

Bloks PoCX ir derīgs, kad tas uzrāda verificējamu no krātuves iegūtu apliecinājumu, kas saskan ar konsensusa stāvokli. Validatori neatkarīgi pārrēķina scoop izvēli, iegūst paredzamo kvalitāti no iesniegtā nonce un plota metadatiem, pielieto Time Bending transformāciju un apstiprina, ka raktuvniekam bija tiesības kalt bloku deklarētajā laikā.

Konkrēti, derīgam blokam nepieciešams: termiņš kopš vecākbloka ir beidzies; iesniegtā kvalitāte sakrīt ar aprēķināto kvalitāti apliecinājumam; mērogošanas līmenis atbilst tīkla minimumam; ģenerēšanas paraksts sakrīt ar paredzamo vērtību; bāzes mērķis sakrīt ar paredzamo vērtību; bloka paraksts nāk no efektīvā parakstītāja; un coinbase maksā uz efektīvā parakstītāja adresi.

---

## 5. Kalšanas piešķiršana

### 5.1 Motivācija

Kalšanas piešķiršana ļauj plotu īpašniekiem deleģēt bloku kalšanas pilnvaras, nekad nenododot savu plotu īpašumtiesības. Šis mehānisms nodrošina pūla rakšanu un aukstās krātuves iestatījumus, vienlaikus saglabājot PoCX drošības garantijas.

Pūla rakšanā plotu īpašnieki var pilnvarot pūlu kalt blokus viņu vārdā. Pūls komplektē blokus un sadala atlīdzības, bet tas nekad neiegūst turējuma tiesības pār pašiem plotiem. Deleģēšana ir atceļama jebkurā laikā, un plotu īpašnieki paliek brīvi pamest pūlu vai mainīt konfigurācijas bez plotēšanas atkārtošanas.

Piešķiršana arī atbalsta skaidru nodalījumu starp aukstajām un karstajām atslēgām. Privātā atslēga, kas kontrolē plotu, var palikt bezsaistē, kamēr atsevišķa kalšanas atslēga — kas glabājas tiešsaistes mašīnā — veido blokus. Tādējādi kalšanas atslēgas kompromitēšana apdraud tikai kalšanas pilnvaras, nevis īpašumtiesības. Plots paliek drošībā, un piešķiršanu var atsaukt, nekavējoties aizverot drošības plaisu.

Tādējādi kalšanas piešķiršana nodrošina operacionālu elastību, vienlaikus uzturot principu, ka kontrole pār saglabāto ietilpību nekad nedrīkst tikt nodota starpniekiem.

### 5.2 Piešķiršanas protokols

Piešķiršana tiek deklarēta caur OP_RETURN darījumiem, lai izvairītos no nevajadzīgas UTXO kopas pieauguma. Piešķiršanas darījums norāda plota adresi un kalšanas adresi, kas ir pilnvarota veidot blokus, izmantojot šī plota ietilpību. Atsaukšanas darījums satur tikai plota adresi. Abos gadījumos plota īpašnieks pierāda kontroli, parakstot darījuma tērēšanas ievadi.

Katra piešķiršana progresē caur labi definētu stāvokļu secību (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Pēc piešķiršanas darījuma apstiprināšanas sistēma ieiet īsā aktivizācijas fāzē. Šī aizkave — 30 bloki, aptuveni viena stunda — nodrošina stabilitāti bloku sacīkšu laikā un novērš pretrunīgu ātru kalšanas identitāšu pārslēgšanu. Kad šis aktivizācijas periods beidzas, piešķiršana kļūst aktīva un paliek tāda, līdz plota īpašnieks izsniedz atsaukšanu.

Atsaukšanas pāriet ilgākā aizkaves periodā — 720 bloki, aptuveni viena diena. Šajā laikā iepriekšējā kalšanas adrese paliek aktīva. Šī garākā aizkave nodrošina operacionālu stabilitāti pūliem, novēršot stratēģisku "piešķiršanas lēkāšanu" un dodot infrastruktūras nodrošinātājiem pietiekamu noteiktību efektīvai darbībai. Pēc atsaukšanas aizkaves beigām atsaukšana ir pabeigta, un plota īpašnieks ir brīvs noteikt jaunu kalšanas atslēgu.

Piešķiršanas stāvoklis tiek uzturēts konsensusa slāņa struktūrā paralēli UTXO kopai un atbalsta atsaukšanas datus drošai ķēdes reorganizāciju apstrādei.

### 5.3 Validācijas noteikumi

Katram blokam validatori nosaka efektīvo parakstītāju — adresi, kurai jāparaksta bloks un jāsaņem coinbase atlīdzība. Šis parakstītājs ir atkarīgs tikai no piešķiršanas stāvokļa bloka augstumā.

Ja piešķiršana nepastāv vai piešķiršana vēl nav pabeigusi savu aktivizācijas fāzi, plota īpašnieks paliek efektīvais parakstītājs. Kad piešķiršana kļūst aktīva, piešķirtajai kalšanas adresei ir jāparaksta. Atsaukšanas laikā kalšanas adrese turpina parakstīt, līdz atsaukšanas aizkave beidzas. Tikai tad pilnvaras atgriežas pie plota īpašnieka.

Validatori nodrošina, ka bloka paraksts ir izveidots no efektīvā parakstītāja, ka coinbase maksā uz to pašu adresi un ka visas pārejas seko noteiktajām aktivizācijas un atsaukšanas aizkavēm. Tikai plota īpašnieks var izveidot vai atsaukt piešķiršanas; kalšanas atslēgas nevar modificēt vai paplašināt savas atļaujas.

Tādējādi kalšanas piešķiršana ievieš elastīgu deleģēšanu bez uzticēšanās ieviešanas. Pamatā esošās ietilpības īpašumtiesības vienmēr paliek kriptogrāfiski piesaistītas plota īpašniekam, kamēr kalšanas pilnvaras var tikt deleģētas, rotētas vai atsauktas atbilstoši operacionālajām vajadzībām.

---

## 6. Dinamiskā mērogošana

Aparatūrai attīstoties, plotu aprēķināšanas izmaksas samazinās salīdzinājumā ar iepriekš aprēķinātā darba nolasīšanu no diska. Bez pretpasākumiem uzbrucēji galu galā varētu ģenerēt apliecinājumus lidojumā ātrāk nekā raktuvnieki, kas lasa saglabāto darbu, graujot Proof of Capacity drošības modeli.

Lai saglabātu paredzēto drošības rezervi, PoCX implementē mērogošanas grafiku: minimālais nepieciešamais mērogošanas līmenis plotiem laika gaitā pieaug. Katrs mērogošanas līmenis Xn, kā aprakstīts 3.5. sadaļā, iegulst eksponenciāli vairāk darba apliecinājuma plota struktūrā, nodrošinot, ka raktuvnieki turpina piešķirt būtiskus krātuves resursus pat tad, kad skaitļošana kļūst lētāka.

Grafiks ir saskaņots ar tīkla ekonomiskajiem stimuliem, it īpaši bloka atlīdzības dalīšanu. Atlīdzībai par bloku samazinoties, minimālais līmenis pakāpeniski pieaug, saglabājot līdzsvaru starp plotēšanas piepūli un rakšanas potenciālu:

| Periods | Gadi | Dalīšanas | Min. mērogošana | Plota darba reizinātājs |
|---------|------|-----------|-----------------|------------------------|
| Ēra 0 | 0-4 | 0 | X1 | 2× bāzlīnija |
| Ēra 1 | 4-12 | 1-2 | X2 | 4× bāzlīnija |
| Ēra 2 | 12-28 | 3-6 | X3 | 8× bāzlīnija |
| Ēra 3 | 28-60 | 7-14 | X4 | 16× bāzlīnija |
| Ēra 4 | 60-124 | 15-30 | X5 | 32× bāzlīnija |
| Ēra 5 | 124+ | 31+ | X6 | 64× bāzlīnija |

Raktuvnieki pēc izvēles var sagatavot plotus, kas pārsniedz pašreizējo minimumu par vienu līmeni, ļaujot viņiem plānot uz priekšu un izvairīties no tūlītējiem jauninājumiem, kad tīkls pāriet uz nākamo ēru. Šis neobligātais solis nesniedz papildu priekšrocības bloka varbūtības ziņā — tas tikai ļauj gludāku operacionālu pāreju.

Bloki, kas satur apliecinājumus zem minimālā mērogošanas līmeņa to augstumam, tiek uzskatīti par nederīgiem. Validatori pārbauda deklarēto mērogošanas līmeni apliecinājumā pret pašreizējo tīkla prasību konsensusa validācijas laikā, nodrošinot, ka visi iesaistītie raktuvnieki atbilst mainīgajām drošības prasībām.

---

## 7. Rakšanas arhitektūra

PoCX nodala konsensusa kritiskās operācijas no resursu ietilpīgajiem rakšanas uzdevumiem, nodrošinot gan drošību, gan efektivitāti. Mezgls uztur blokķēdi, validē blokus, pārvalda mempool un atklāj RPC saskarni. Ārējie raktuvnieki apstrādā plotu glabāšanu, scoop nolasīšanu, kvalitātes aprēķinu un termiņu pārvaldību. Šis nodalījums uztur konsensusa loģiku vienkāršu un auditējamu, vienlaikus ļaujot raktuvniekiem optimizēt diska caurlaidspēju.

### 7.1 Rakšanas RPC saskarne

Raktuvnieki mijiedarbojas ar mezglu caur minimālu RPC izsaukumu kopu. get_mining_info RPC nodrošina pašreizējo bloka augstumu, ģenerēšanas parakstu, bāzes mērķi, mērķa termiņu un pieņemamo plota mērogošanas līmeņu diapazonu. Izmantojot šo informāciju, raktuvnieki aprēķina kandidātu nonce. submit_nonce RPC ļauj raktuvniekiem iesniegt ierosinātus risinājumus, ietverot plota identifikatoru, nonce indeksu, mērogošanas līmeni un raktuvnieka kontu. Mezgls novērtē iesniegumu un atbild ar aprēķināto termiņu, ja apliecinājums ir derīgs.

### 7.2 Kalšanas plānotājs

Mezgls uztur kalšanas plānotāju, kas seko ienākošajiem iesniegumiem un saglabā tikai labāko risinājumu katram bloka augstumam. Iesniegtie nonce tiek rindoti ar iebūvētām aizsardzībām pret iesniegumu pārpludināšanu vai pakalpojuma atteikuma uzbrukumiem. Plānotājs gaida, līdz aprēķinātais termiņš beidzas vai pienāk labāks risinājums, kurā brīdī tas komplektē bloku, paraksta to ar efektīvo kalšanas atslēgu un publicē to tīklā.

### 7.3 Aizsardzības kalšana

Lai novērstu laika uzbrukumus vai stimulus pulksteņa manipulācijai, PoCX implementē aizsardzības kalšanu. Ja konkurējošs bloks pienāk tam pašam augstumam, plānotājs salīdzina lokālo risinājumu ar jauno bloku. Ja lokālā kvalitāte ir labāka, mezgls kaļ nekavējoties, nevis gaida sākotnējo termiņu. Tas nodrošina, ka raktuvnieki nevar iegūt priekšrocību, tikai pielāgojot lokālos pulksteņus; labākais risinājums vienmēr uzvar, saglabājot godīgumu un tīkla drošību.

---

## 8. Drošības analīze

### 8.1 Draudu modelis

PoCX modelē pretiniekus ar būtiskām, bet ierobežotām spējām. Uzbrucēji var mēģināt pārslogot tīklu ar nederīgiem darījumiem, nepareizi formatētiem blokiem vai viltotiem apliecinājumiem, lai stresa testētu validācijas ceļus. Viņi var brīvi manipulēt savus lokālos pulksteņus un var mēģināt izmantot konsensusa uzvedības malas gadījumus, piemēram, laika zīmogu apstrādi, sarežģītības pielāgošanas dinamiku vai reorganizācijas noteikumus. Tiek arī sagaidīts, ka pretinieki meklēs iespējas pārrakstīt vēsturi caur mērķtiecīgām ķēdes sazarojumiem.

Modelis pieņem, ka neviena puse nekontrolē vairākumu no kopējās tīkla krātuves ietilpības. Tāpat kā ar jebkuru uz resursiem balstītu konsensusa mehānismu, 51% ietilpības uzbrucējs var vienpusēji reorganizēt ķēdi; šis fundamentālais ierobežojums nav specifisks PoCX. PoCX arī pieņem, ka uzbrucēji nevar aprēķināt plota datus ātrāk nekā godīgi raktuvnieki var tos nolasīt no diska. Mērogošanas grafiks (6. sadaļa) nodrošina, ka drošībai nepieciešamā skaitļošanas plaisa laika gaitā pieaug, aparatūrai attīstoties.

Nākamajās sadaļās detalizēti aplūkota katra galvenā uzbrukumu klase un aprakstīti PoCX iebūvētie pretpasākumi.

### 8.2 Ietilpības uzbrukumi

Līdzīgi kā PoW, uzbrucējs ar vairākuma ietilpību var pārrakstīt vēsturi (51% uzbrukums). Lai to panāktu, nepieciešams iegūt fizisko krātuves apjomu, kas lielāks par godīgo tīklu — dārgs un loģistiski prasīgs pasākums. Kad aparatūra ir iegūta, darbības izmaksas ir zemas, bet sākotnējais ieguldījums rada spēcīgu ekonomisku stimulu uzvesties godīgi: ķēdes graušana sabojātu paša uzbrucēja aktīvu bāzes vērtību.

PoC arī izvairās no problēmas "nekas nav likts uz spēles", kas saistīta ar PoS. Lai gan raktuvnieki var skenēt plotus pret vairākiem konkurējošiem sazarojumiem, katra skenēšana patērē reālu laiku — parasti desmitiem sekunžu uz ķēdi. Ar 120 sekunžu bloku intervālu tas būtiski ierobežo vairāku sazarojumu rakšanu, un mēģinājums rakst daudzos sazarojumos vienlaicīgi pasliktina veiktspēju visos. Tāpēc sazarojumu rakšana nav bezmaksas; to fundamentāli ierobežo I/O caurlaidspēja.

Pat ja nākotnes aparatūra ļautu gandrīz tūlītēju plotu skenēšanu (piem., ātrgaitas SSD), uzbrucējam joprojām būtu nepieciešams būtisks fizisko resursu apjoms, lai kontrolētu tīkla ietilpības vairākumu, padarot 51% stila uzbrukumu dārgu un loģistiski sarežģītu.

Visbeidzot, ietilpības uzbrukumus ir krietni grūtāk īrēt nekā heš jaudas uzbrukumus. GPU skaitļošanu var iegūt pēc pieprasījuma un nekavējoties novirzīt uz jebkuru PoW ķēdi. Turpretī PoC prasa fizisku aparatūru, laika ietilpīgu plotēšanu un nepārtrauktas I/O operācijas. Šie ierobežojumi padara īstermiņa, oportūnistiskus uzbrukumus daudz mazāk iespējamus.

### 8.3 Laika uzbrukumi

Laiks spēlē kritiskāku lomu Proof of Capacity nekā Proof of Work. PoW laika zīmogi galvenokārt ietekmē sarežģītības pielāgošanu; PoC tie nosaka, vai raktuvnieka termiņš ir beidzies un tādējādi vai bloks ir tiesīgs kalšanai. Termiņi tiek mērīti attiecībā pret vecākbloka laika zīmogu, bet mezgla lokālais pulkstenis tiek izmantots, lai spriestu, vai ienākošais bloks ir pārāk tālu nākotnē. Šī iemesla dēļ PoCX uzliek stingru laika zīmogu toleranci: bloki nedrīkst atšķirties vairāk par 15 sekundēm no mezgla lokālā pulksteņa (salīdzinājumā ar Bitcoin 2 stundu logu). Šis ierobežojums darbojas abos virzienos — bloki pārāk tālu nākotnē tiek noraidīti, un mezgli ar lēniem pulksteņiem var nepareizi noraidīt derīgus ienākošos blokus.

Tāpēc mezgliem vajadzētu sinhronizēt savus pulksteņus, izmantojot NTP vai līdzvērtīgu laika avotu. PoCX apzināti izvairās no paļaušanās uz tīkla iekšējiem laika avotiem, lai neļautu uzbrucējiem manipulēt uztverto tīkla laiku. Mezgli uzrauga savu nobīdi un izdod brīdinājumus, ja lokālais pulkstenis sāk novirzīties no neseno bloku laika zīmogiem.

Pulksteņa paātrināšana — ātra lokālā pulksteņa palaišana, lai kaltu nedaudz agrāk — sniedz tikai marginālu labumu. Atļautās tolerances robežās aizsardzības kalšana (7.3. sadaļa) nodrošina, ka raktuvnieks ar labāku risinājumu nekavējoties publicēs, ieraugot zemāku agrīnu bloku. Ātrs pulkstenis palīdz raktuvniekam publicēt jau uzvarošu risinājumu dažas sekundes agrāk; tas nevar pārvērst zemāku apliecinājumu uzvarošā.

Mēģinājumi manipulēt sarežģītību caur laika zīmogiem ir ierobežoti ar ±20% katram blokam pielāgošanas griestiem un 24 bloku slīdošo logu, novēršot raktuvniekus no būtiskas sarežģītības ietekmēšanas caur īstermiņa laika spēlēm.

### 8.4 Laika-atmiņas kompromisa uzbrukumi

Laika-atmiņas kompromisi mēģina samazināt krātuves prasības, pārrēķinot plota daļas pēc pieprasījuma. Iepriekšējās Proof of Capacity sistēmas bija neaizsargātas pret šādiem uzbrukumiem, īpaši POC1 scoop-nelīdzsvarotības kļūda un POC2 XOR-transponēšanas kompresijas uzbrukums (2.4. sadaļa). Abi izmantoja asimetrijas tajā, cik dārgi bija atjaunot noteiktas plota datu daļas, ļaujot pretiniekiem samazināt krātuvi, maksājot tikai nelielu skaitļošanas sodu. Arī alternatīvi plotu formāti PoC2 cieš no līdzīgām TMTO vājībām; izcils piemērs ir Chia, kuras plota formātu var patvaļīgi samazināt par faktoru, kas lielāks par 4.

PoCX pilnībā novērš šīs uzbrukuma virsmas caur savu nonce konstrukciju un warpa formātu. Katrā nonce beigu difūzijas solis hešē pilnībā aprēķināto buferi un veic XOR rezultātam pāri visiem baitiem, nodrošinot, ka katra bufera daļa ir atkarīga no katras citas daļas un to nevar saīsināt. Pēc tam PoC2 jaukšana apmaina katra scoop apakšējo un augšējo pusi, izlīdzinot jebkura scoop atgūšanas skaitļošanas izmaksas.

PoCX tālāk novērš POC2 XOR-transponēšanas kompresijas uzbrukumu, iegūstot savu nostiprināto X1 formātu, kur katrs scoop ir XOR no tiešās un transponētās pozīcijas pāri pāroto warpu; tas savstarpēji sasaista katru scoop ar veselu rindu un veselu kolonnu pamatā esošo X0 datu, padarot rekonstrukciju prasošu tūkstošiem pilnu nonce un tādējādi pilnībā novēršot asimetrisko laika-atmiņas kompromisu.

Rezultātā pilna plota glabāšana ir vienīgā skaitļošanas ziņā dzīvotspējīgā stratēģija raktuvniekiem. Neviens zināmais saīsinājums — vai tā būtu daļēja plotēšana, selektīva atjaunošana, strukturēta kompresija vai hibrīdas skaitļošanas-krātuves pieejas — nesniedz būtisku priekšrocību. PoCX nodrošina, ka rakšana paliek stingri piesaistīta krātuvei un ka ietilpība atspoguļo reālu, fizisku apņemšanos.

### 8.5 Piešķiršanas uzbrukumi

PoCX izmanto deterministisku stāvokļa mašīnu, lai pārvaldītu visas plota-uz-kalšanas piešķiršanas. Katra piešķiršana progresē caur labi definētiem stāvokļiem — UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED — ar uzliktām aktivizācijas un atsaukšanas aizkavēm. Tas nodrošina, ka raktuvnieks nevar momentāni mainīt piešķiršanas, lai krāptu sistēmu, vai ātri pārslēgt kalšanas pilnvaras.

Tā kā visām pārejām nepieciešami kriptogrāfiski pierādījumi — konkrēti, plota īpašnieka paraksti, kas verificējami pret ievades UTXO — tīkls var uzticēties katras piešķiršanas leģitimitātei. Mēģinājumi apiet stāvokļa mašīnu vai viltot piešķiršanas tiek automātiski noraidīti konsensusa validācijas laikā. Atkārtošanas uzbrukumi tāpat tiek novērsti ar standarta Bitcoin stila darījumu atkārtošanas aizsardzību, nodrošinot, ka katra piešķiršanas darbība ir unikāli piesaistīta derīgai, neiztērētai ievadei.

Stāvokļa mašīnas pārvaldības, uzlikto aizkavju un kriptogrāfiska pierādījuma kombinācija padara uz piešķiršanu balstītu krāpšanu praktiski neiespējamu: raktuvnieki nevar pārņemt piešķiršanas, veikt ātru pārpiešķiršanu bloku sacīkšu laikā vai apiet atsaukšanas grafikus.

### 8.6 Parakstu drošība

Bloku paraksti PoCX kalpo kā kritiska saikne starp apliecinājumu un efektīvo kalšanas atslēgu, nodrošinot, ka tikai pilnvaroti raktuvnieki var veidot derīgus blokus.

Lai novērstu mainīguma uzbrukumus, paraksti tiek izslēgti no bloka heša aprēķina. Tas novērš mainīgu parakstu riskus, kas varētu graut validāciju vai ļaut bloku aizvietošanas uzbrukumus.

Lai mazinātu pakalpojuma atteikuma vektorus, parakstu un publisko atslēgu izmēri ir fiksēti — 65 baiti kompaktiem parakstiem un 33 baiti saspiestām publiskajām atslēgām — novēršot uzbrucējus no bloku piepūšanas, lai izraisītu resursu izsīkumu vai palēninātu tīkla izplatīšanu.

---

## 9. Implementācija

PoCX ir implementēta kā modulārs paplašinājums Bitcoin Core, ar visu būtisko kodu, kas ietverts savā veltītā apakšdirektorijā un aktivizēts caur funkciju karodziņu. Šis dizains saglabā oriģinālā koda integritāti, ļaujot PoCX tikt iespējotai vai atspējotai tīri, kas vienkāršo testēšanu, auditēšanu un sinhronizāciju ar augšupējām izmaiņām.

Integrācija skar tikai būtiskos punktus, kas nepieciešami Proof of Capacity atbalstam. Bloka galvene ir paplašināta, lai iekļautu PoCX specifiskus laukus, un konsensusa validācija ir pielāgota, lai apstrādātu uz krātuvi balstītus apliecinājumus līdzās tradicionālajām Bitcoin pārbaudēm. Kalšanas sistēma, kas atbildīga par termiņu pārvaldību, plānošanu un raktuvnieku iesniegumiem, ir pilnībā ietverta PoCX moduļos, kamēr RPC paplašinājumi atklāj rakšanas un piešķiršanas funkcionalitāti ārējiem klientiem. Lietotājiem maka saskarne ir uzlabota, lai pārvaldītu piešķiršanas caur OP_RETURN darījumiem, nodrošinot netraucētu mijiedarbību ar jaunajām konsensusa funkcijām.

Visas konsensusa kritiskās operācijas ir implementētas deterministiskā C++ bez ārējām atkarībām, nodrošinot starpplatformu konsekvenci. Shabal256 tiek izmantots hešēšanai, kamēr Time Bending un kvalitātes aprēķins balstās uz fiksēta punkta aritmētiku un 256 bitu operācijām. Kriptogrāfiskās operācijas, piemēram, parakstu verifikācija, izmanto Bitcoin Core esošo secp256k1 bibliotēku.

Izolējot PoCX funkcionalitāti šādā veidā, implementācija paliek auditējama, uzturama un pilnībā saderīga ar notiekošo Bitcoin Core izstrādi, demonstrējot, ka fundamentāli jauns uz krātuvi piesaistīts konsensusa mehānisms var līdzāspastāvēt ar nobriedušu darba apliecinājuma koda bāzi, netraucējot tās integritāti vai lietojamību.

---

## 10. Tīkla parametri

PoCX balstās uz Bitcoin tīkla infrastruktūru un atkārtoti izmanto tās ķēdes parametru ietvaru. Lai atbalstītu uz ietilpību balstītu rakšanu, bloku intervālus, piešķiršanas apstrādi un plotu mērogošanu, vairāki parametri ir paplašināti vai pārrakstīti. Tas ietver bloka laika mērķi, sākotnējo subsīdiju, dalīšanas grafiku, piešķiršanas aktivizācijas un atsaukšanas aizkaves, kā arī tīkla identifikatorus, piemēram, maģiskos baitus, portus un Bech32 prefiksus. Testnet un regtest vides tālāk pielāgo šos parametrus, lai nodrošinātu ātru iterāciju un zemas ietilpības testēšanu.

Zemāk esošās tabulas apkopo rezultējošos mainnet, testnet un regtest iestatījumus, uzsverot, kā PoCX pielāgo Bitcoin pamata parametrus uz krātuvi piesaistītam konsensusa modelim.

### 10.1 Mainnet

| Parametrs | Vērtība |
|-----------|---------|
| Maģiskie baiti | `0xa7 0x3c 0x91 0x5e` |
| Noklusējuma ports | 8888 |
| Bech32 HRP | `pocx` |
| Bloka laika mērķis | 120 sekundes |
| Sākotnējā subsīdija | 10 BTC |
| Dalīšanas intervāls | 1050000 bloki (~4 gadi) |
| Kopējais piedāvājums | ~21 miljons BTC |
| Piešķiršanas aktivizācija | 30 bloki |
| Piešķiršanas atsaukšana | 720 bloki |
| Slīdošais logs | 24 bloki |

### 10.2 Testnet

| Parametrs | Vērtība |
|-----------|---------|
| Maģiskie baiti | `0x6d 0xf2 0x48 0xb3` |
| Noklusējuma ports | 18888 |
| Bech32 HRP | `tpocx` |
| Bloka laika mērķis | 120 sekundes |
| Pārējie parametri | Tādi paši kā mainnet |

### 10.3 Regtest

| Parametrs | Vērtība |
|-----------|---------|
| Maģiskie baiti | `0xfa 0xbf 0xb5 0xda` |
| Noklusējuma ports | 18444 |
| Bech32 HRP | `rpocx` |
| Bloka laika mērķis | 1 sekunde |
| Dalīšanas intervāls | 500 bloki |
| Piešķiršanas aktivizācija | 4 bloki |
| Piešķiršanas atsaukšana | 8 bloki |
| Zemas ietilpības režīms | Iespējots (~4 MB ploti) |

---

## 11. Saistītie darbi

Gadu gaitā vairāki blokķēdes un konsensusa projekti ir izpētījuši uz krātuvi balstītus vai hibrīdus rakšanas modeļus. PoCX balstās uz šo mantojumu, vienlaikus ieviešot uzlabojumus drošībā, efektivitātē un saderībā.

**Burstcoin / Signum.** Burstcoin 2014. gadā ieviesa pirmo praktisko Proof-of-Capacity (PoC) sistēmu, definējot pamatkoncepcijas, piemēram, plotus, nonce, scoopus un uz termiņiem balstītu rakšanu. Tās pēcteči, īpaši Signum (agrāk Burstcoin), paplašināja ekosistēmu un galu galā attīstījās par to, kas pazīstams kā Proof-of-Commitment (PoC+), apvienojot krātuves apņemšanos ar neobligātu stekingu, lai ietekmētu efektīvo ietilpību. PoCX manto uz krātuvi balstīto rakšanas pamatu no šiem projektiem, bet būtiski atšķiras ar nostiprinātu plota formātu (XOR-transponēšanas kodēšana), dinamisku plota darba mērogošanu, termiņu izlīdzināšanu ("Time Bending") un elastīgu piešķiršanas sistēmu — visu, vienlaikus balstīti Bitcoin Core koda bāzē, nevis uzturot atsevišķu tīkla sazarojumu.

**Chia.** Chia implementē Proof of Space and Time, apvienojot uz disku balstītus krātuves apliecinājumus ar laika komponentu, ko uzliek Verificējamas aizkaves funkcijas (VDF). Tās dizains risina noteiktas problēmas par apliecinājumu atkārtotu izmantošanu un svaigu izaicinājumu ģenerēšanu, atšķiroties no klasiskā PoC. PoCX nepieņem šo laikā noenkuroto apliecinājuma modeli; tā vietā tā uztur uz krātuvi piesaistītu konsensusu ar prognozējamiem intervāliem, optimizētu ilgtermiņa saderībai ar UTXO ekonomiku un no Bitcoin atvasinātiem rīkiem.

**Spacemesh.** Spacemesh piedāvā Proof-of-Space-Time (PoST) shēmu, izmantojot DAG balstītu (tīkla) topoloģiju. Šajā modelī dalībniekiem periodiski jāpierāda, ka piešķirtā krātuve paliek neskarta laika gaitā, nevis jāpaļaujas uz vienu iepriekš aprēķinātu datu kopu. PoCX, turpretī, verificē krātuves apņemšanos tikai bloka laikā — ar nostiprinātiem plota formātiem un stingru apliecinājuma validāciju — izvairoties no nepārtrauktu krātuves apliecinājumu pieskaitāmajām izmaksām, vienlaikus saglabājot efektivitāti un decentralizāciju.

---

## 12. Secinājums

Bitcoin-PoCX demonstrē, ka energoefektīvs konsensuss var tikt integrēts Bitcoin Core, vienlaikus saglabājot drošības īpašības un ekonomisko modeli. Galvenie ieguldījumi ietver XOR-transponēšanas kodēšanu (piespiež uzbrucējus aprēķināt 4096 nonce katrā meklējumā, novēršot kompresijas uzbrukumu), Time Bending algoritmu (sadalījuma transformācija samazina bloka laika dispersiju), kalšanas piešķiršanas sistēmu (OP_RETURN balstīta deleģēšana nodrošina nekustodālu pūla rakšanu), dinamisko mērogošanu (saskaņota ar dalīšanām, lai uzturētu drošības rezerves) un minimālo integrāciju (funkciju karodziņiem kontrolēts kods, izolēts veltītā direktorijā).

Sistēma pašlaik ir testnet fāzē. Rakšanas jauda izriet no krātuves ietilpības, nevis no heš ātruma, samazinot enerģijas patēriņu par kārtām, vienlaikus uzturot Bitcoin pārbaudīto ekonomisko modeli.

---

## Atsauces

Bitcoin Core. *Bitcoin Core repozitorijs.* https://github.com/bitcoin/bitcoin

Burstcoin. *Proof of Capacity tehniskā dokumentācija.* 2014.

NIST. *SHA-3 konkurss: Shabal.* 2008.

Cohen, B., Pietrzak, K. *The Chia Network Blockchain.* 2019.

Spacemesh. *Spacemesh protokola dokumentācija.* 2021.

PoC Consortium. *PoCX ietvars.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Bitcoin-PoCX integrācija.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Licence**: MIT
**Organizācija**: Proof of Capacity Consortium
**Statuss**: Testnet fāze
