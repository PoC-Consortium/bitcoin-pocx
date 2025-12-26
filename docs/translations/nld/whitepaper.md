# Bitcoin-PoCX: Energie-efficiente consensus voor Bitcoin Core

**Versie**: 2.0 Concept
**Datum**: December 2025
**Organisatie**: Proof of Capacity Consortium

---

## Samenvatting

Bitcoin's Proof-of-Work (PoW) consensus biedt robuuste beveiliging maar verbruikt aanzienlijke energie door continue real-time hashberekening. Wij presenteren Bitcoin-PoCX, een Bitcoin-fork die PoW vervangt door Proof of Capacity (PoC), waarbij miners grote sets schijfopgeslagen hashes vooraf berekenen en opslaan tijdens het plotten en vervolgens minen door lichtgewicht opzoekingen uit te voeren in plaats van doorlopend hashen. Door berekening te verschuiven van de miningfase naar een eenmalige plotfase, vermindert Bitcoin-PoCX drastisch het energieverbruik terwijl mining op standaardhardware mogelijk wordt, wat de drempel tot deelname verlaagt en centralisatiedruk inherent aan ASIC-gedomineerde PoW vermindert, dit alles terwijl Bitcoin's beveiligingsaannames en economisch gedrag behouden blijven.

Onze implementatie introduceert verschillende belangrijke innovaties:
(1) Een verhard plotformaat dat alle bekende tijd-geheugen-afwegingsaanvallen in bestaande PoC-systemen elimineert, waardoor effectieve miningkracht strikt evenredig blijft aan toegewezen opslagcapaciteit;
(2) Het Time-Bending-algoritme, dat deadline-distributies transformeert van exponentieel naar chi-kwadraat, waardoor bloktijdvariantie wordt verminderd zonder het gemiddelde te wijzigen;
(3) Een OP_RETURN-gebaseerd forging-toewijzingsmechanisme dat niet-custodiale pool-mining mogelijk maakt; en
(4) Dynamische compressieschaling, die plotgeneratiemoeilijkheid verhoogt in lijn met halveringsschema's om langetermijn-veiligheidsmarges te behouden naarmate hardware verbetert.

Bitcoin-PoCX behoudt de architectuur van Bitcoin Core door minimale, functievlag-gebaseerde wijzigingen, waarbij PoC-logica wordt geisoleerd van de bestaande consensuscode. Het systeem behoudt Bitcoin's monetaire beleid door te richten op een 120-seconden blokinterval en de bloksubsidie aan te passen naar 10 BTC. De verminderde subsidie compenseert de vijfvoudige toename in blokfrequentie, waardoor de langetermijn-uitgiftesnelheid in lijn blijft met Bitcoin's oorspronkelijke schema en de ~21 miljoen maximum voorraad behouden blijft.

---

## 1. Inleiding

### 1.1 Motivatie

Bitcoin's Proof-of-Work (PoW) consensus is al meer dan tien jaar bewezen veilig, maar tegen aanzienlijke kosten: miners moeten continu rekenresources uitgeven, wat resulteert in hoog energieverbruik. Naast efficientiezorgen is er een bredere motivatie: het verkennen van alternatieve consensusmechanismen die beveiliging behouden terwijl de drempel tot deelname wordt verlaagd. PoC stelt vrijwel iedereen met standaard opslaghardware in staat effectief te minen, wat de centralisatiedruk vermindert die wordt gezien in ASIC-gedomineerde PoW-mining.

Proof of Capacity (PoC) bereikt dit door miningkracht af te leiden van opslagtoewijding in plaats van doorlopende berekening. Miners berekenen vooraf grote sets schijfopgeslagen hashes - plots - tijdens een eenmalige plotfase. Mining bestaat dan uit lichtgewicht opzoekingen, wat energieverbruik drastisch vermindert terwijl de beveiligingsaannames van resource-gebaseerde consensus behouden blijven.

### 1.2 Integratie met Bitcoin Core

Bitcoin-PoCX integreert PoC-consensus in Bitcoin Core in plaats van een nieuwe blockchain te creeren. Deze aanpak maakt gebruik van Bitcoin Core's bewezen beveiliging, volwassen netwerkstack en breed geadopteerde tooling, terwijl wijzigingen minimaal en functievlag-gebaseerd blijven. PoC-logica is geisoleerd van bestaande consensuscode, wat ervoor zorgt dat kernfunctionaliteit - blokvalidatie, walletoperaties, transactieformaten - grotendeels ongewijzigd blijft.

### 1.3 Ontwerpdoelen

**Beveiliging**: Behoud Bitcoin-equivalente robuustheid; aanvallen vereisen meerderheidsopslagcapaciteit.

**Efficientie**: Verminder doorlopende rekenbelasting tot schijf-I/O-niveaus.

**Toegankelijkheid**: Maak mining met standaardhardware mogelijk, verlaag drempels tot deelname.

**Minimale integratie**: Introduceer PoC-consensus met minimale wijzigingsvoetafdruk.

---

## 2. Achtergrond: Proof of Capacity

### 2.1 Geschiedenis

Proof of Capacity (PoC) werd geintroduceerd door Burstcoin in 2014 als energie-efficient alternatief voor Proof-of-Work (PoW). Burstcoin demonstreerde dat miningkracht kon worden afgeleid van toegewezen opslag in plaats van continue real-time hashing: miners berekenden vooraf grote datasets ("plots") eenmalig en minden vervolgens door kleine, vaste delen ervan te lezen.

Vroege PoC-implementaties bewezen het concept haalbaar maar onthulden ook dat plotformaat en cryptografische structuur kritiek zijn voor beveiliging. Verschillende tijd-geheugen-afwegingen stelden aanvallers in staat effectief te minen met minder opslag dan eerlijke deelnemers. Dit benadrukte dat PoC-beveiliging afhangt van plotontwerp - niet alleen van het gebruiken van opslag als resource.

Burstcoin's nalatenschap vestigde PoC als praktisch consensusmechanisme en leverde de basis waarop PoCX bouwt.

### 2.2 Kernconcepten

PoC-mining is gebaseerd op grote, vooraf berekende plotbestanden opgeslagen op schijf. Deze plots bevatten "bevroren berekening": dure hashing wordt eenmalig uitgevoerd tijdens plotten, en mining bestaat dan uit lichtgewicht schijflezingen en eenvoudige verificatie. Kernelementen omvatten:

**Nonce:**
De basiseenheid van plotgegevens. Elke nonce bevat 4096 scoops (256 KiB totaal) gegenereerd via Shabal256 uit het adres van de miner en de nonce-index.

**Scoop:**
Een 64-byte segment binnen een nonce. Voor elk blok selecteert het netwerk deterministisch een scoop-index (0-4095) gebaseerd op de generatiehandtekening van het vorige blok. Alleen deze scoop per nonce hoeft te worden gelezen.

**Generatiehandtekening:**
Een 256-bit waarde afgeleid van het vorige blok. Het biedt entropie voor scoopselectie en voorkomt dat miners toekomstige scoop-indices kunnen voorspellen.

**Warp:**
Een structurele groep van 4096 nonces (1 GiB). Warps zijn de relevante eenheid voor compressie-resistente plotformaten.

### 2.3 Miningproces en kwaliteitspijplijn

PoC-mining bestaat uit een eenmalige plotstap en een lichtgewichte per-blokroutine:

**Eenmalige setup:**
- Plotgeneratie: Bereken nonces via Shabal256 en schrijf ze naar schijf.

**Per-blok mining:**
- Scoopselectie: Bepaal de scoop-index uit de generatiehandtekening.
- Plotscanning: Lees die scoop van alle nonces in de plots van de miner.

**Kwaliteitspijplijn:**
- Ruwe kwaliteit: Hash elke scoop met de generatiehandtekening met Shabal256Lite om een 64-bit kwaliteitswaarde te verkrijgen (lager is beter).
- Deadline: Converteer kwaliteit naar een deadline met de base target (een moeilijkheidsaangepaste parameter die ervoor zorgt dat het netwerk zijn doelblokinterval bereikt): `deadline = kwaliteit / base_target`
- Gebogen deadline: Pas de Time-Bending-transformatie toe om variantie te verminderen terwijl verwachte bloktijd behouden blijft.

**Blok forgen:**
De miner met de kortste (gebogen) deadline forgt het volgende blok zodra die tijd is verstreken.

In tegenstelling tot PoW vindt vrijwel alle berekening plaats tijdens plotten; actieve mining is voornamelijk schijfgebonden en zeer laag in stroomverbruik.

### 2.4 Bekende kwetsbaarheden in eerdere systemen

**POC1-distributiefout:**
Het originele Burstcoin POC1-formaat vertoonde een structurele bias: lage-index scoops waren significant goedkoper om on-the-fly te herberekenen dan hoge-index scoops. Dit introduceerde een niet-uniforme tijd-geheugen-afweging, waardoor aanvallers vereiste opslag voor die scoops konden verminderen en de aanname ondermijnden dat alle vooraf berekende gegevens even duur waren.

**XOR-compressie-aanval (POC2):**
In POC2 kan een aanvaller elke set van 8192 nonces nemen en deze partitioneren in twee blokken van 4096 nonces (A en B). In plaats van beide blokken op te slaan, slaat de aanvaller alleen een afgeleide structuur op: `A XOR transpose(B)`, waarbij de transpose scoop- en nonce-indices verwisselt - scoop S van nonce N in blok B wordt scoop N van nonce S.

Tijdens mining, wanneer scoop S van nonce N nodig is, reconstrueert de aanvaller het door:
1. De opgeslagen XOR-waarde op positie (S, N) te lezen
2. Nonce N van blok A te berekenen om scoop S te verkrijgen
3. Nonce S van blok B te berekenen om de getransponeerde scoop N te verkrijgen
4. Alle drie waarden te XORen om de originele 64-byte scoop te herstellen

Dit vermindert opslag met 50%, terwijl slechts twee nonceberekeningen per opzoekactie nodig zijn - een kost ver onder de drempel die nodig is om volledige voorberekening af te dwingen. De aanval is haalbaar omdat het berekenen van een rij (een nonce, 4096 scoops) goedkoop is, terwijl het berekenen van een kolom (een enkele scoop over 4096 nonces) het regenereren van alle nonces zou vereisen. De transpose-structuur legt deze onevenwichtigheid bloot.

Dit demonstreerde de behoefte aan een plotformaat dat dergelijke gestructureerde recombinatie voorkomt en de onderliggende tijd-geheugen-afweging verwijdert. Sectie 3.3 beschrijft hoe PoCX deze zwakte aanpakt en oplost.

### 2.5 Transitie naar PoCX

De beperkingen van eerdere PoC-systemen maakten duidelijk dat veilige, eerlijke en gedecentraliseerde opslagmining afhangt van zorgvuldig ontworpen plotstructuren. Bitcoin-PoCX pakt deze problemen aan met een verhard plotformaat, verbeterde deadline-distributie en mechanismen voor gedecentraliseerde pool-mining - beschreven in de volgende sectie.

---

## 3. PoCX-plotformaat

### 3.1 Basisnonce-constructie

Een nonce is een 256 KiB datastructuur deterministisch afgeleid van drie parameters: een 20-byte adreslading, een 32-byte seed, en een 64-bit nonce-index.

Constructie begint met het combineren van deze invoer en het hashen ervan met Shabal256 om een initiele hash te produceren. Deze hash dient als startpunt voor een iteratief expansieproces: Shabal256 wordt herhaaldelijk toegepast, waarbij elke stap afhangt van eerder gegenereerde gegevens, totdat de volledige 256 KiB buffer is gevuld. Dit geketende proces vertegenwoordigt het rekenwerk dat tijdens plotten wordt uitgevoerd.

Een laatste diffusiestap hasht de voltooide buffer en XORt het resultaat over alle bytes. Dit zorgt ervoor dat de volledige buffer is berekend en dat miners de berekening niet kunnen afkorten. De PoC2-shuffle wordt dan toegepast, waarbij de onderste en bovenste helften van elke scoop worden verwisseld om te garanderen dat alle scoops gelijkwaardige rekeninspanning vereisen.

De uiteindelijke nonce bestaat uit 4096 scoops van elk 64 bytes en vormt de fundamentele eenheid die in mining wordt gebruikt.

### 3.2 SIMD-uitgelijnde plotlayout

Om doorvoer op moderne hardware te maximaliseren, organiseert PoCX noncegegevens op schijf om gevectoriseerde verwerking te vergemakkelijken. In plaats van elke nonce sequentieel op te slaan, lijnt PoCX overeenkomstige 4-byte woorden over meerdere opeenvolgende nonces aaneengesloten uit. Dit stelt een enkele geheugenophaling in staat om gegevens voor alle SIMD-lanes te leveren, waardoor cache-misses worden geminimaliseerd en scatter-gather-overhead wordt geelimineerd.

```
Traditionele layout:
Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX SIMD-layout:
Woord0: [N0][N1][N2]...[N15]
Woord1: [N0][N1][N2]...[N15]
Woord2: [N0][N1][N2]...[N15]
```

Deze layout is gunstig voor zowel CPU- als GPU-miners, wat hoge-doorvoer, geparallelliseerde scoop-evaluatie mogelijk maakt terwijl een eenvoudig scalair toegangspatroon voor consensusverificatie behouden blijft. Het zorgt ervoor dat mining wordt beperkt door opslagbandbreedte in plaats van CPU-berekening, wat de lage-energieaard van Proof of Capacity behoudt.

### 3.3 Warpstructuur en XOR-transpose-codering

Een warp is de fundamentele opslageenheid in PoCX, bestaande uit 4096 nonces (1 GiB). Het ongecomprimeerde formaat, aangeduid als X0, bevat basisnonces precies zoals geproduceerd door de constructie in Sectie 3.1.

**XOR-transpose-codering (X1)**

Om de structurele tijd-geheugen-afwegingen die aanwezig zijn in eerdere PoC-systemen te verwijderen, leidt PoCX een verhard miningformaat, X1, af door XOR-transpose-codering toe te passen op paren van X0-warps.

Om scoop S van nonce N te construeren in een X1-warp:

1. Neem scoop S van nonce N van de eerste X0-warp (directe positie)
2. Neem scoop N van nonce S van de tweede X0-warp (getransponeerde positie)
3. XOR de twee 64-byte waarden om de X1-scoop te verkrijgen

De transpose-stap verwisselt scoop- en nonce-indices. In matrixtermen - waarbij rijen scoops en kolommen nonces vertegenwoordigen - combineert het het element op positie (S, N) in de eerste warp met het element op (N, S) in de tweede.

**Waarom dit het aanvalsoppervlak van compressie elimineert**

De XOR-transpose koppelt elke scoop aan een volledige rij en een volledige kolom van de onderliggende X0-gegevens. Het herstellen van een enkele X1-scoop vereist daarom toegang tot gegevens die alle 4096 scoop-indices omvatten. Elke poging om ontbrekende gegevens te berekenen zou het regenereren van 4096 volledige nonces vereisen, in plaats van een enkele nonce - waardoor de asymmetrische kostenstructuur die door de XOR-aanval voor POC2 werd benut (Sectie 2.4) wordt verwijderd.

Als gevolg hiervan wordt het opslaan van de volledige X1-warp de enige rekenkundig haalbare strategie voor miners, waardoor de tijd-geheugen-afweging die in eerdere ontwerpen werd benut, wordt gesloten.

### 3.4 Schijflayout

PoCX-plotbestanden bestaan uit vele opeenvolgende X1-warps. Om operationele efficientie tijdens mining te maximaliseren, zijn de gegevens binnen elk bestand georganiseerd per scoop: alle scoop 0-gegevens van elke warp worden sequentieel opgeslagen, gevolgd door alle scoop 1-gegevens, enzovoort, tot scoop 4095.

Deze **scoop-sequentiele ordening** stelt miners in staat om de volledige gegevens die nodig zijn voor een geselecteerde scoop te lezen in een enkele sequentiele schijftoegang, waardoor zoektijden worden geminimaliseerd en doorvoer op standaard opslagapparaten wordt gemaximaliseerd.

Gecombineerd met de XOR-transpose-codering van Sectie 3.3, zorgt deze layout ervoor dat het bestand zowel **structureel verhard** als **operationeel efficient** is: sequentiele scoop-ordening ondersteunt optimale schijf-I/O, terwijl SIMD-uitgelijnde geheugenlayouts (zie Sectie 3.2) hoge-doorvoer, geparallelliseerde scoop-evaluatie mogelijk maken.

### 3.5 Proof-of-Work-schaling (Xn)

PoCX implementeert schaalbare voorberekening via het concept van schaalniveaus, aangeduid als Xn, om zich aan te passen aan evoluerende hardwareprestaties. Het basis X1-formaat vertegenwoordigt de eerste XOR-transpose verharde warpstructuur.

Elk schaalniveau Xn verhoogt de proof-of-work ingebed in elke warp exponentieel ten opzichte van X1: het werk vereist op niveau Xn is 2^(n-1) keer dat van X1. Overgaan van Xn naar Xn+1 is operationeel gelijkwaardig aan het toepassen van een XOR over paren van aangrenzende warps, wat geleidelijk meer proof-of-work inbedt zonder de onderliggende plotgrootte te veranderen.

Bestaande plotbestanden gecreeerd op lagere schaalniveaus kunnen nog steeds worden gebruikt voor mining, maar ze dragen proportioneel minder werk bij aan blokgeneratie, wat hun lagere ingebedde proof-of-work weerspiegelt. Dit mechanisme zorgt ervoor dat PoCX-plots veilig, flexibel en economisch gebalanceerd blijven na verloop van tijd.

### 3.6 Seed-functionaliteit

De seedparameter maakt meerdere niet-overlappende plots per adres mogelijk zonder handmatige coordinatie.

**Probleem (POC2)**: Miners moesten handmatig noncebereiken bijhouden over plotbestanden om overlap te voorkomen. Overlappende nonces verspillen opslag zonder miningkracht te verhogen.

**Oplossing**: Elk `(adres, seed)`-paar definieert een onafhankelijke sleutelruimte. Plots met verschillende seeds overlappen nooit, ongeacht noncebereiken. Miners kunnen vrij plots creeren zonder coordinatie.

---

## 4. Proof of Capacity-consensus

PoCX breidt Bitcoin's Nakamoto-consensus uit met een opslag-gebonden bewijsmechanisme. In plaats van energie te besteden aan herhaald hashen, committeren miners grote hoeveelheden vooraf berekende gegevens - plots - aan schijf. Tijdens blokgeneratie moeten ze een klein, onvoorspelbaar deel van deze gegevens lokaliseren en transformeren naar een bewijs. De miner die het beste bewijs levert binnen het verwachte tijdvenster verdient het recht om het volgende blok te forgen.

Dit hoofdstuk beschrijft hoe PoCX blokmetadata structureert, onvoorspelbaarheid afleidt, en statische opslag transformeert naar een veilig, laag-variantie consensusmechanisme.

### 4.1 Blokstructuur

PoCX behoudt de vertrouwde Bitcoin-stijl blokheader maar introduceert aanvullende consensusvelden vereist voor capaciteitsgebaseerde mining. Deze velden binden collectief het blok aan de opgeslagen plot van de miner, de moeilijkheid van het netwerk, en de cryptografische entropie die elke mininguitdaging definieert.

Op hoog niveau bevat een PoCX-blok: de blokhoogte, expliciet geregistreerd om contextuele validatie te vereenvoudigen; de generatiehandtekening, een bron van verse entropie die elk blok verbindt met zijn voorganger; de base target, die netwerkmoeilijkheid vertegenwoordigt in inverse vorm (hogere waarden komen overeen met makkelijker minen); het PoCX-bewijs, dat de plot van de miner identificeert, het compressieniveau gebruikt tijdens plotten, de geselecteerde nonce, en de kwaliteit die eruit is afgeleid; en een ondertekeningssleutel en handtekening, die controle bewijzen over de capaciteit die is gebruikt om het blok te forgen (of van een toegewezen forgingsleutel).

Het bewijs bedt alle consensus-relevante informatie in die validators nodig hebben om de uitdaging te herberekenen, de gekozen scoop te verifieren, en de resulterende kwaliteit te bevestigen. Door uit te breiden in plaats van de blokstructuur te herontwerpen, blijft PoCX conceptueel afgestemd op Bitcoin terwijl een fundamenteel andere bron van miningwerk mogelijk wordt gemaakt.

### 4.2 Generatiehandtekeningketen

De generatiehandtekening biedt de onvoorspelbaarheid vereist voor veilige Proof of Capacity-mining. Elk blok leidt zijn generatiehandtekening af van de handtekening en ondertekenaar van het vorige blok, waardoor miners toekomstige uitdagingen niet kunnen anticiperen of voordelige plotregio's kunnen voorberekenen:

`generatieHandtekening[n] = SHA256(generatieHandtekening[n-1] || miner_pubkey[n-1])`

Dit produceert een reeks cryptografisch sterke, miner-afhankelijke entropiewaarden. Omdat de publieke sleutel van een miner onbekend is tot het vorige blok is gepubliceerd, kan geen deelnemer toekomstige scoopselecties voorspellen. Dit voorkomt selectieve voorberekening of strategisch plotten en zorgt ervoor dat elk blok echt vers miningwerk introduceert.

### 4.3 Forgingproces

Mining in PoCX bestaat uit het transformeren van opgeslagen gegevens naar een bewijs volledig gedreven door de generatiehandtekening. Hoewel het proces deterministisch is, zorgt de onvoorspelbaarheid van de handtekening ervoor dat miners niet van tevoren kunnen voorbereiden en herhaaldelijk hun opgeslagen plots moeten benaderen.

**Uitdagingsafleiding (Scoopselectie):** De miner hasht de huidige generatiehandtekening met de blokhoogte om een scoop-index te verkrijgen in het bereik 0-4095. Deze index bepaalt welk 64-byte segment van elke opgeslagen nonce deelneemt aan het bewijs. Omdat de generatiehandtekening afhangt van de ondertekenaar van het vorige blok, wordt scoopselectie pas bekend op het moment van blokpublicatie.

**Bewijsevaluatie (Kwaliteitsberekening):** Voor elke nonce in een plot haalt de miner de geselecteerde scoop op en hasht deze samen met de generatiehandtekening om een kwaliteit te verkrijgen - een 64-bit waarde waarvan de grootte de competitiviteit van de miner bepaalt. Lagere kwaliteit komt overeen met een beter bewijs.

**Deadline-formatie (Time Bending):** De ruwe deadline is evenredig aan de kwaliteit en omgekeerd evenredig aan de base target. In legacy PoC-ontwerpen volgden deze deadlines een sterk scheve exponentiele verdeling, wat lange staartvertragingen produceerde die geen aanvullende beveiliging boden. PoCX transformeert de ruwe deadline met Time Bending (Sectie 4.4), waardoor variantie wordt verminderd en voorspelbare blokintervallen worden gegarandeerd. Zodra de gebogen deadline verstrijkt, forgt de miner een blok door het bewijs in te bedden en het te ondertekenen met de effectieve forgingsleutel.

### 4.4 Time Bending

Proof of Capacity produceert exponentieel verdeelde deadlines. Na een korte periode - typisch enkele tientallen seconden - heeft elke miner al hun beste bewijs geidentificeerd, en elke extra wachttijd draagt alleen latentie bij, geen beveiliging.

Time Bending hervormt de verdeling door een kubusworteltransformatie toe te passen:

`deadline_gebogen = schaal x (kwaliteit / base_target)^(1/3)`

De schaalfactor behoudt de verwachte bloktijd (120 seconden) terwijl variantie dramatisch wordt verminderd. Korte deadlines worden uitgerekt, wat blokpropagatie en netwerkbeveiliging verbetert. Lange deadlines worden gecomprimeerd, wat voorkomt dat uitschieters de keten vertragen.

![Bloktijdverdelingen](blocktime_distributions.svg)

Time Bending behoudt de informatieinhoud van het onderliggende bewijs. Het wijzigt competitiviteit tussen miners niet; het herverdeelt alleen wachttijd om soepelere, voorspelbaardere blokintervallen te produceren. De implementatie gebruikt fixed-point rekenkunde (Q42-formaat) en 256-bit integers om deterministische resultaten over alle platforms te garanderen.

### 4.5 Moeilijkheidsaanpassing

PoCX reguleert blokproductie met de base target, een inverse moeilijkheidsmaat. De verwachte bloktijd is evenredig aan de verhouding `kwaliteit / base_target`, dus het verhogen van de base target versnelt blokcreatie terwijl het verlagen de keten vertraagt.

Moeilijkheid past zich elk blok aan met behulp van de gemeten tijd tussen recente blokken vergeleken met het doelinterval. Deze frequente aanpassing is noodzakelijk omdat opslagcapaciteit snel kan worden toegevoegd of verwijderd - in tegenstelling tot Bitcoin's hashkracht, die langzamer verandert.

De aanpassing volgt twee leidende beperkingen: **Geleidelijkheid** - per-blokwijzigingen zijn begrensd (maximaal +-20%) om oscillaties of manipulatie te voorkomen; **Verharding** - de base target kan zijn genesiswaarde niet overschrijden, wat voorkomt dat het netwerk ooit moeilijkheid verlaagt onder de oorspronkelijke beveiligingsaannames.

### 4.6 Blokgeldigheid

Een blok in PoCX is geldig wanneer het een verifieerbaar opslag-afgeleid bewijs presenteert consistent met de consensusstatus. Validators herberekenen onafhankelijk de scoopselectie, leiden de verwachte kwaliteit af uit de ingediende nonce en plotmetadata, passen de Time Bending-transformatie toe, en bevestigen dat de miner in aanmerking kwam om het blok te forgen op de gedeclareerde tijd.

Specifiek vereist een geldig blok: de deadline is verstreken sinds het ouderblok; de ingediende kwaliteit komt overeen met de berekende kwaliteit voor het bewijs; het schaalniveau voldoet aan het netwerkminimum; de generatiehandtekening komt overeen met de verwachte waarde; de base target komt overeen met de verwachte waarde; de blokhandtekening komt van de effectieve ondertekenaar; en de coinbase betaalt aan het adres van de effectieve ondertekenaar.

---

## 5. Forging-toewijzingen

### 5.1 Motivatie

Forging-toewijzingen stellen ploteigenaren in staat om blok-forgingautoriteit te delegeren zonder ooit eigenaarschap van hun plots af te staan. Dit mechanisme maakt pool-mining en cold-storage-setups mogelijk terwijl de beveiligingsgaranties van PoCX behouden blijven.

Bij pool-mining kunnen ploteigenaren een pool autoriseren om blokken namens hen te forgen. De pool assembleert blokken en distribueert beloningen, maar krijgt nooit custody over de plots zelf. Delegatie is op elk moment reversibel, en ploteigenaren blijven vrij om een pool te verlaten of configuraties te wijzigen zonder opnieuw te plotten.

Toewijzingen ondersteunen ook een schone scheiding tussen koude en warme sleutels. De privesleutel die het plot controleert kan offline blijven, terwijl een aparte forgingsleutel - opgeslagen op een online machine - blokken produceert. Een compromittering van de forgingsleutel compromitteert daarom alleen forgingautoriteit, niet eigenaarschap. Het plot blijft veilig en de toewijzing kan worden ingetrokken, wat de beveiligingskloof onmiddellijk sluit.

Forging-toewijzingen bieden dus operationele flexibiliteit terwijl het principe wordt gehandhaafd dat controle over opgeslagen capaciteit nooit moet worden overgedragen aan intermediairs.

### 5.2 Toewijzingsprotocol

Toewijzingen worden gedeclareerd via OP_RETURN-transacties om onnodige groei van de UTXO-set te voorkomen. Een toewijzingstransactie specificeert het plotadres en het forgingadres dat is geautoriseerd om blokken te produceren met de capaciteit van dat plot. Een intrekkingstransactie bevat alleen het plotadres. In beide gevallen bewijst de ploteigenaar controle door de bestedings-invoer van de transactie te ondertekenen.

Elke toewijzing doorloopt een reeks goed gedefinieerde statussen (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Nadat een toewijzingstransactie bevestigt, gaat het systeem een korte activeringsfase in. Deze vertraging - 30 blokken, ruwweg een uur - zorgt voor stabiliteit tijdens blokraces en voorkomt vijandige snelle wisseling van forgingidentiteiten. Zodra deze activeringsperiode verstrijkt, wordt de toewijzing actief en blijft zo tot de ploteigenaar een intrekking uitgeeft.

Intrekkingen gaan over naar een langere vertragingsperiode van 720 blokken, ongeveer een dag. Gedurende deze tijd blijft het vorige forgingadres actief. Deze langere vertraging biedt operationele stabiliteit voor pools, voorkomt strategisch "toewijzingshoppen" en geeft infrastructuurproviders voldoende zekerheid om efficient te opereren. Nadat de intrekkingsvertraging verstrijkt, voltooit de intrekking, en de ploteigenaar is vrij om een nieuwe forgingsleutel aan te wijzen.

De toewijzingsstatus wordt bijgehouden in een consensuslaagstructuur parallel aan de UTXO-set en ondersteunt undo-gegevens voor veilige afhandeling van ketenherschikkingen.

### 5.3 Validatieregels

Voor elk blok bepalen validators de effectieve ondertekenaar - het adres dat het blok moet ondertekenen en de coinbase-beloning moet ontvangen. Deze ondertekenaar hangt uitsluitend af van de toewijzingsstatus op de hoogte van het blok.

Als geen toewijzing bestaat of de toewijzing zijn activeringsfase nog niet heeft voltooid, blijft de ploteigenaar de effectieve ondertekenaar. Zodra een toewijzing actief wordt, moet het toegewezen forgingadres ondertekenen. Tijdens intrekking blijft het forgingadres ondertekenen tot de intrekkingsvertraging verstrijkt. Pas dan keert autoriteit terug naar de ploteigenaar.

Validators handhaven dat de blokhandtekening wordt geproduceerd door de effectieve ondertekenaar, dat de coinbase aan hetzelfde adres betaalt, en dat alle overgangen de voorgeschreven activerings- en intrekkingsvertragingen volgen. Alleen de ploteigenaar kan toewijzingen creeren of intrekken; forgingsleutels kunnen hun eigen machtigingen niet wijzigen of uitbreiden.

Forging-toewijzingen introduceren dus flexibele delegatie zonder vertrouwen. Eigenaarschap van de onderliggende capaciteit blijft altijd cryptografisch verankerd aan de ploteigenaar, terwijl forgingautoriteit kan worden gedelegeerd, gerouleerd of ingetrokken naarmate operationele behoeften evolueren.

---

## 6. Dynamische schaling

Naarmate hardware evolueert, dalen de kosten voor het berekenen van plots ten opzichte van het lezen van vooraf berekend werk van schijf. Zonder tegenmaatregelen zouden aanvallers uiteindelijk bewijzen on-the-fly kunnen genereren sneller dan miners opgeslagen werk lezen, wat het beveiligingsmodel van Proof of Capacity ondermijnt.

Om de beoogde veiligheidsmarge te behouden, implementeert PoCX een schalingsschema: het minimum vereiste schaalniveau voor plots neemt toe na verloop van tijd. Elk schaalniveau Xn, zoals beschreven in Sectie 3.5, bedt exponentieel meer proof-of-work in binnen de plotstructuur, waardoor miners aanzienlijke opslagresources blijven committeren zelfs naarmate berekening goedkoper wordt.

Het schema is afgestemd op de economische prikkels van het netwerk, met name blokbeloningshalveringen. Naarmate de beloning per blok afneemt, neemt het minimumniveau geleidelijk toe, wat de balans behoudt tussen plotteringsinspanning en miningpotentieel:

| Periode | Jaren | Halveringen | Min schaling | Plotwerk-multiplicator |
|---------|-------|-------------|--------------|------------------------|
| Epoch 0 | 0-4 | 0 | X1 | 2x basislijn |
| Epoch 1 | 4-12 | 1-2 | X2 | 4x basislijn |
| Epoch 2 | 12-28 | 3-6 | X3 | 8x basislijn |
| Epoch 3 | 28-60 | 7-14 | X4 | 16x basislijn |
| Epoch 4 | 60-124 | 15-30 | X5 | 32x basislijn |
| Epoch 5 | 124+ | 31+ | X6 | 64x basislijn |

Miners kunnen optioneel plots voorbereiden die het huidige minimum met een niveau overschrijden, waardoor ze vooruit kunnen plannen en onmiddellijke upgrades kunnen voorkomen wanneer het netwerk overgaat naar de volgende epoch. Deze optionele stap biedt geen aanvullend voordeel in termen van blokwaarschijnlijkheid - het staat alleen een soepelere operationele transitie toe.

Blokken die bewijzen bevatten onder het minimum schaalniveau voor hun hoogte worden als ongeldig beschouwd. Validators controleren het gedeclareerde schaalniveau in het bewijs tegen de huidige netwerkvereiste tijdens consensusvalidatie, waardoor alle deelnemende miners aan de evoluerende beveiligingsverwachtingen voldoen.

---

## 7. Miningarchitectuur

PoCX scheidt consensus-kritieke operaties van de resource-intensieve taken van mining, wat zowel beveiliging als efficientie mogelijk maakt. De node onderhoudt de blockchain, valideert blokken, beheert de mempool, en stelt een RPC-interface beschikbaar. Externe miners handelen plotopslag, scoop-lezen, kwaliteitsberekening en deadline-beheer af. Deze scheiding houdt consensuslogica eenvoudig en auditeerbaar terwijl miners kunnen optimaliseren voor schijfdoorvoer.

### 7.1 Mining RPC-interface

Miners interageren met de node via een minimale set RPC-aanroepen. De get_mining_info RPC biedt de huidige blokhoogte, generatiehandtekening, base target, doeldeadline, en het acceptabele bereik van plotschaalniveaus. Met deze informatie berekenen miners kandidaat-nonces. De submit_nonce RPC stelt miners in staat een voorgestelde oplossing in te dienen, inclusief de plotidentificator, nonce-index, schaalniveau en miner-account. De node evalueert de indiening en reageert met de berekende deadline als het bewijs geldig is.

### 7.2 Forging-scheduler

De node onderhoudt een forging-scheduler, die binnenkomende indieningen bijhoudt en alleen de beste oplossing voor elke blokhoogte behoudt. Ingediende nonces worden in de wachtrij geplaatst met ingebouwde beschermingen tegen indieningsoverstroming of denial-of-service-aanvallen. De scheduler wacht tot de berekende deadline verstrijkt of een superieure oplossing arriveert, waarna het een blok assembleert, ondertekent met de effectieve forgingsleutel, en publiceert naar het netwerk.

### 7.3 Defensief forgen

Om timingaanvallen of prikkels voor klokmanipulatie te voorkomen, implementeert PoCX defensief forgen. Als een concurrerend blok arriveert voor dezelfde hoogte, vergelijkt de scheduler de lokale oplossing met het nieuwe blok. Als de lokale kwaliteit superieur is, forgt de node onmiddellijk in plaats van te wachten op de originele deadline. Dit zorgt ervoor dat miners geen voordeel kunnen behalen door alleen lokale klokken aan te passen; de beste oplossing wint altijd, wat eerlijkheid en netwerkbeveiliging behoudt.

---

## 8. Beveiligingsanalyse

### 8.1 Dreigingsmodel

PoCX modelleert tegenstanders met aanzienlijke maar begrensde mogelijkheden. Aanvallers kunnen proberen het netwerk te overbelasten met ongeldige transacties, misvormde blokken, of vervalste bewijzen om validatiepaden te stresstesten. Ze kunnen hun lokale klokken vrij manipuleren en kunnen proberen randgevallen in consensusgedrag te exploiteren zoals tijdstempelafhandeling, moeilijkheidsaanpassingsdynamiek, of herschikkingsregels. Tegenstanders worden ook verwacht te zoeken naar mogelijkheden om geschiedenis te herschrijven via gerichte ketenvorken.

Het model veronderstelt dat geen enkele partij een meerderheid van de totale netwerkopslagcapaciteit controleert. Zoals met elk resource-gebaseerd consensusmechanisme kan een 51%-capaciteitsaanvaller eenzijdig de keten reorganiseren; deze fundamentele beperking is niet specifiek voor PoCX. PoCX veronderstelt ook dat aanvallers plotgegevens niet sneller kunnen berekenen dan eerlijke miners het van schijf kunnen lezen. Het schalingsschema (Sectie 6) zorgt ervoor dat de rekenkloof die nodig is voor beveiliging groeit na verloop van tijd naarmate hardware verbetert.

De volgende secties onderzoeken elke belangrijke aanvalsklasse in detail en beschrijven de tegenmaatregelen ingebouwd in PoCX.

### 8.2 Capaciteitsaanvallen

Net als PoW kan een aanvaller met meerderheidscapaciteit geschiedenis herschrijven (een 51%-aanval). Dit bereiken vereist het verwerven van een fysieke opslagvoetafdruk groter dan het eerlijke netwerk - een dure en logistiek veeleisende onderneming. Zodra de hardware is verkregen, zijn operationele kosten laag, maar de initiele investering creert een sterke economische prikkel om eerlijk te gedragen: het ondermijnen van de keten zou de waarde van de eigen activabasis van de aanvaller beschadigen.

PoC vermijdt ook het nothing-at-stake-probleem geassocieerd met PoS. Hoewel miners plots kunnen scannen tegen meerdere concurrerende vorken, verbruikt elke scan echte tijd - typisch in de orde van tientallen seconden per keten. Met een 120-seconden blokinterval beperkt dit inherent multi-fork mining, en proberen veel vorken tegelijk te minen verslechtert prestaties op allemaal. Fork-mining is daarom niet kosteloos; het is fundamenteel beperkt door I/O-doorvoer.

Zelfs als toekomstige hardware near-instantane plotscanning zou toestaan (bijv. snelle SSD's), zou een aanvaller nog steeds een aanzienlijke fysieke resourcevereiste hebben om een meerderheid van netwerkcapaciteit te controleren, wat een 51%-stijl aanval duur en logistiek uitdagend maakt.

Ten slotte is capaciteit veel moeilijker te huren dan hashkracht. GPU-compute kan op aanvraag worden verkregen en direct worden omgeleid naar elke PoW-keten. PoC vereist daarentegen fysieke hardware, tijdintensief plotten, en doorlopende I/O-operaties. Deze beperkingen maken kortetermijn, opportunistische aanvallen veel minder haalbaar.

### 8.3 Timingaanvallen

Timing speelt een kritiekere rol in Proof of Capacity dan in Proof of Work. In PoW beinvloeden tijdstempels voornamelijk moeilijkheidsaanpassing; in PoC bepalen ze of de deadline van een miner is verstreken en dus of een blok in aanmerking komt voor forging. Deadlines worden gemeten ten opzichte van de tijdstempel van het ouderblok, maar de lokale klok van een node wordt gebruikt om te beoordelen of een binnenkomend blok te ver in de toekomst ligt. Om deze reden handhaaft PoCX een strakke tijdstempeltolerantie: blokken mogen niet meer dan 15 seconden afwijken van de lokale klok van de node (vergeleken met Bitcoin's 2-uur venster). Deze limiet werkt in beide richtingen - blokken te ver in de toekomst worden afgewezen, en nodes met trage klokken kunnen ten onrechte geldige binnenkomende blokken afwijzen.

Nodes moeten daarom hun klokken synchroniseren met NTP of een equivalente tijdbron. PoCX vermijdt opzettelijk vertrouwen op netwerk-interne tijdbronnen om te voorkomen dat aanvallers waargenomen netwerktijd manipuleren. Nodes monitoren hun eigen verschuiving en geven waarschuwingen als de lokale klok begint af te wijken van recente bloktijdstempels.

Klokversnelling - een snelle lokale klok draaien om iets eerder te forgen - biedt slechts marginaal voordeel. Binnen de toegestane tolerantie zorgt defensief forgen (Sectie 7.3) ervoor dat een miner met een betere oplossing onmiddellijk zal publiceren bij het zien van een inferieur vroeg blok. Een snelle klok helpt een miner alleen een reeds-winnende oplossing een paar seconden eerder te publiceren; het kan een inferieur bewijs niet omzetten in een winnend bewijs.

Pogingen om moeilijkheid te manipuleren via tijdstempels zijn begrensd door een +-20% per-blokaanpassingslimiet en een 24-blokken rollend venster, wat voorkomt dat miners moeilijkheid zinvol beinvloeden door kortetermijn-timingspellen.

### 8.4 Tijd-geheugen-afwegingsaanvallen

Tijd-geheugen-afwegingen proberen opslagvereisten te verminderen door delen van het plot op aanvraag te herberekenen. Eerdere Proof of Capacity-systemen waren kwetsbaar voor dergelijke aanvallen, met name de POC1 scoop-onevenwichtigheidsfout en de POC2 XOR-transpose compressie-aanval (Sectie 2.4). Beide maakten misbruik van asymmetrieen in hoe duur het was om bepaalde delen van plotgegevens te regenereren, waardoor tegenstanders opslag konden verminderen terwijl ze slechts een kleine rekenboete betaalden. Ook alternatieve plotformaten voor PoC2 lijden aan vergelijkbare TMTO-zwakheden; een prominent voorbeeld is Chia, waarvan het plotformaat willekeurig kan worden verminderd met een factor groter dan 4.

PoCX verwijdert deze aanvalsoppervlakken volledig via zijn nonceconstructie en warpformaat. Binnen elke nonce hasht de laatste diffusiestap de volledig berekende buffer en XORt het resultaat over alle bytes, waardoor elk deel van de buffer afhangt van elk ander deel en niet kan worden afgekort. Daarna verwisselt de PoC2-shuffle de onderste en bovenste helften van elke scoop, waardoor de rekenkosten van het herstellen van elke scoop worden gelijkgetrokken.

PoCX elimineert verder de POC2 XOR-transpose compressie-aanval door zijn verharde X1-formaat af te leiden, waarbij elke scoop de XOR is van een directe en een getransponeerde positie over gepaarde warps; dit koppelt elke scoop aan een volledige rij en een volledige kolom van onderliggende X0-gegevens, waardoor reconstructie duizenden volledige nonces vereist en daarmee de asymmetrische tijd-geheugen-afweging volledig wordt verwijderd.

Als gevolg hiervan is het opslaan van het volledige plot de enige rekenkundig haalbare strategie voor miners. Geen bekende afkorting - of het nu gedeeltelijk plotten, selectieve regeneratie, gestructureerde compressie, of hybride compute-opslag-benaderingen betreft - biedt een betekenisvol voordeel. PoCX zorgt ervoor dat mining strikt opslag-gebonden blijft en dat capaciteit echte, fysieke toewijding weerspiegelt.

### 8.5 Toewijzingsaanvallen

PoCX gebruikt een deterministische toestandsmachine om alle plot-naar-forger toewijzingen te beheren. Elke toewijzing doorloopt goed gedefinieerde statussen - UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED - met afgedwongen activerings- en intrekkingsvertragingen. Dit zorgt ervoor dat een miner niet onmiddellijk toewijzingen kan wijzigen om het systeem te bedriegen of snel forgingautoriteit kan wisselen.

Omdat alle overgangen cryptografische bewijzen vereisen - specifiek handtekeningen door de ploteigenaar die verifieerbaar zijn tegen de invoer-UTXO - kan het netwerk de legitimiteit van elke toewijzing vertrouwen. Pogingen om de toestandsmachine te omzeilen of toewijzingen te vervalsen worden automatisch afgewezen tijdens consensusvalidatie. Replay-aanvallen worden eveneens voorkomen door standaard Bitcoin-stijl transactie-replay-beschermingen, waardoor elke toewijzingsactie uniek is gebonden aan een geldige, onbestede invoer.

De combinatie van toestandsmachine-beheer, afgedwongen vertragingen, en cryptografisch bewijs maakt toewijzingsgebaseerd bedrog praktisch onmogelijk: miners kunnen geen toewijzingen kapen, snelle hertoewijzing uitvoeren tijdens blokraces, of intrekkingsschema's omzeilen.

### 8.6 Handtekeningbeveiliging

Blokhandtekeningen in PoCX dienen als kritieke link tussen een bewijs en de effectieve forgingsleutel, waardoor alleen geautoriseerde miners geldige blokken kunnen produceren.

Om malleability-aanvallen te voorkomen, worden handtekeningen uitgesloten van de blokhash-berekening. Dit elimineert risico's van vervormbare handtekeningen die validatie kunnen ondermijnen of blokvervangingsaanvallen kunnen toestaan.

Om denial-of-service-vectoren te beperken, zijn handtekening- en publieke sleutelgroottes vast - 65 bytes voor compacte handtekeningen en 33 bytes voor gecomprimeerde publieke sleutels - wat voorkomt dat aanvallers blokken opblazen om resource-uitputting te triggeren of netwerkpropagatie te vertragen.

---

## 9. Implementatie

PoCX is geimplementeerd als modulaire extensie op Bitcoin Core, met alle relevante code in zijn eigen toegewijde subdirectory en geactiveerd via een functievlag. Dit ontwerp behoudt de integriteit van de originele code, waardoor PoCX schoon kan worden in- of uitgeschakeld, wat testen, auditen en synchroniseren met upstream-wijzigingen vereenvoudigt.

De integratie raakt alleen de essentiele punten die nodig zijn om Proof of Capacity te ondersteunen. De blokheader is uitgebreid om PoCX-specifieke velden op te nemen, en consensusvalidatie is aangepast om opslag-gebaseerde bewijzen te verwerken naast traditionele Bitcoin-controles. Het forgingsysteem, verantwoordelijk voor het beheren van deadlines, scheduling en miner-indieningen, is volledig vervat in de PoCX-modules, terwijl RPC-extensies mining- en toewijzingsfunctionaliteit beschikbaar stellen aan externe clients. Voor gebruikers is de wallet-interface verbeterd om toewijzingen te beheren via OP_RETURN-transacties, wat naadloze interactie met de nieuwe consensusfuncties mogelijk maakt.

Alle consensus-kritieke operaties zijn geimplementeerd in deterministisch C++ zonder externe afhankelijkheden, wat cross-platform consistentie garandeert. Shabal256 wordt gebruikt voor hashing, terwijl Time Bending en kwaliteitsberekening vertrouwen op fixed-point rekenkunde en 256-bit operaties. Cryptografische operaties zoals handtekeningverificatie benutten Bitcoin Core's bestaande secp256k1-bibliotheek.

Door PoCX-functionaliteit op deze manier te isoleren, blijft de implementatie auditeerbaar, onderhoudbaar en volledig compatibel met doorlopende Bitcoin Core-ontwikkeling, wat demonstreert dat een fundamenteel nieuw opslag-gebonden consensusmechanisme kan coexisteren met een volwassen proof-of-work codebase zonder de integriteit of bruikbaarheid ervan te verstoren.

---

## 10. Netwerkparameters

PoCX bouwt voort op Bitcoin's netwerkinfrastructuur en hergebruikt het ketenparameterframework. Om capaciteitsgebaseerde mining, blokintervallen, toewijzingsafhandeling en plotschaling te ondersteunen, zijn verschillende parameters uitgebreid of overschreven. Dit omvat het bloktijddoel, initiele subsidie, halveringsschema, activerings- en intrekkingsvertragingen voor toewijzingen, evenals netwerkidentificatoren zoals magic bytes, poorten en Bech32-voorvoegsels. Testnet- en regtest-omgevingen passen deze parameters verder aan om snelle iteratie en lage-capaciteitstesten mogelijk te maken.

De tabellen hieronder vatten de resulterende mainnet-, testnet- en regtest-instellingen samen, en benadrukken hoe PoCX Bitcoin's kernparameters aanpast aan een opslag-gebonden consensusmodel.

### 10.1 Mainnet

| Parameter | Waarde |
|-----------|--------|
| Magic bytes | `0xa7 0x3c 0x91 0x5e` |
| Standaardpoort | 8888 |
| Bech32 HRP | `pocx` |
| Bloktijddoel | 120 seconden |
| Initiele subsidie | 10 BTC |
| Halveringsinterval | 1050000 blokken (~4 jaar) |
| Totale voorraad | ~21 miljoen BTC |
| Toewijzingsactivering | 30 blokken |
| Toewijzingsintrekking | 720 blokken |
| Rollend venster | 24 blokken |

### 10.2 Testnet

| Parameter | Waarde |
|-----------|--------|
| Magic bytes | `0x6d 0xf2 0x48 0xb3` |
| Standaardpoort | 18888 |
| Bech32 HRP | `tpocx` |
| Bloktijddoel | 120 seconden |
| Overige parameters | Zelfde als mainnet |

### 10.3 Regtest

| Parameter | Waarde |
|-----------|--------|
| Magic bytes | `0xfa 0xbf 0xb5 0xda` |
| Standaardpoort | 18444 |
| Bech32 HRP | `rpocx` |
| Bloktijddoel | 1 seconde |
| Halveringsinterval | 500 blokken |
| Toewijzingsactivering | 4 blokken |
| Toewijzingsintrekking | 8 blokken |
| Lage-capaciteitsmodus | Ingeschakeld (~4 MB plots) |

---

## 11. Gerelateerd werk

Door de jaren heen hebben verschillende blockchain- en consensusprojecten opslag-gebaseerde of hybride miningmodellen verkend. PoCX bouwt voort op deze lijn terwijl verbeteringen worden geintroduceerd in beveiliging, efficientie en compatibiliteit.

**Burstcoin / Signum.** Burstcoin introduceerde het eerste praktische Proof-of-Capacity (PoC) systeem in 2014, en definieerde kernconcepten zoals plots, nonces, scoops en deadline-gebaseerde mining. Zijn opvolgers, met name Signum (voorheen Burstcoin), breidden het ecosysteem uit en evolueerden uiteindelijk naar wat bekend staat als Proof-of-Commitment (PoC+), dat opslagtoewijding combineert met optioneel staken om effectieve capaciteit te beinvloeden. PoCX erft de opslag-gebaseerde miningbasis van deze projecten, maar wijkt significant af via een verhard plotformaat (XOR-transpose-codering), dynamische plotwerk-schaling, deadline-afvlakking ("Time Bending"), en een flexibel toewijzingssysteem - dit alles terwijl het verankerd is in de Bitcoin Core-codebase in plaats van een zelfstandige netwerkfork te onderhouden.

**Chia.** Chia implementeert Proof of Space and Time, dat schijf-gebaseerde opslagbewijzen combineert met een tijdcomponent afgedwongen via Verifiable Delay Functions (VDF's). Het ontwerp adresseert bepaalde zorgen over bewijshergebruik en verse uitdaginggeneratie, onderscheiden van klassieke PoC. PoCX adopteert dat tijd-verankerde bewijsmodel niet; in plaats daarvan handhaaft het een opslag-gebonden consensus met voorspelbare intervallen, geoptimaliseerd voor langetermijncompatibiliteit met UTXO-economie en Bitcoin-afgeleide tooling.

**Spacemesh.** Spacemesh stelt een Proof-of-Space-Time (PoST) schema voor met een DAG-gebaseerde (mesh) netwerktopologie. In dit model moeten deelnemers periodiek bewijzen dat toegewezen opslag intact blijft na verloop van tijd, in plaats van te vertrouwen op een enkele vooraf berekende dataset. PoCX daarentegen verifieert alleen opslagtoewijding op bloktijd - met verharde plotformaten en rigoureuze bewijsvalidatie - wat de overhead van continue opslagbewijzen vermijdt terwijl efficientie en decentralisatie behouden blijven.

---

## 12. Conclusie

Bitcoin-PoCX demonstreert dat energie-efficiente consensus kan worden geintegreerd in Bitcoin Core terwijl beveiligingseigenschappen en economisch model behouden blijven. Belangrijke bijdragen omvatten de XOR-transpose-codering (dwingt aanvallers 4096 nonces te berekenen per opzoekactie, wat de compressie-aanval elimineert), het Time Bending-algoritme (distributietransformatie vermindert bloktijdvariantie), het forging-toewijzingssysteem (OP_RETURN-gebaseerde delegatie maakt niet-custodiale pool-mining mogelijk), dynamische schaling (afgestemd op halveringen om veiligheidsmarges te behouden), en minimale integratie (functievlag-gebaseerde code geisoleerd in een toegewijde directory).

Het systeem is momenteel in testnetfase. Miningkracht is afgeleid van opslagcapaciteit in plaats van hashrate, wat energieverbruik met ordes van grootte vermindert terwijl Bitcoin's bewezen economische model behouden blijft.

---

## Referenties

Bitcoin Core. *Bitcoin Core Repository.* https://github.com/bitcoin/bitcoin

Burstcoin. *Proof of Capacity Technical Documentation.* 2014.

NIST. *SHA-3 Competition: Shabal.* 2008.

Cohen, B., Pietrzak, K. *The Chia Network Blockchain.* 2019.

Spacemesh. *Spacemesh Protocol Documentation.* 2021.

PoC Consortium. *PoCX Framework.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Bitcoin-PoCX Integration.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Licentie**: MIT
**Organisatie**: Proof of Capacity Consortium
**Status**: Testnetfase
