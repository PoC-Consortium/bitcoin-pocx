# Bitcoin-PoCX: Energieffektiv konsensus för Bitcoin Core

**Version**: 2.0 Utkast
**Datum**: December 2025
**Organisation**: Proof of Capacity Consortium

---

## Sammanfattning

Bitcoins Proof-of-Work (PoW)-konsensus ger robust säkerhet men förbrukar betydande energi på grund av kontinuerlig realtidshashberäkning. Vi presenterar Bitcoin-PoCX, en Bitcoin-fork som ersätter PoW med Proof of Capacity (PoC), där miners förberäknar och lagrar stora mängder disklagrade hashar under plottning och sedan minar genom att utföra lättviktiga uppslagningar istället för pågående hashning. Genom att flytta beräkning från miningfasen till en engångs-plottningsfas minskar Bitcoin-PoCX dramatiskt energiförbrukningen samtidigt som mining möjliggörs på standardhårdvara, vilket sänker tröskeln för deltagande och mildrar centraliseringstrycket som är inneboende i ASIC-dominerad PoW, allt medan Bitcoins säkerhetsantaganden och ekonomiska beteende bevaras.

Vår implementation introducerar flera nyckelinnovationer:
(1) Ett härdat plotformat som eliminerar alla kända tid-minnesavvägningsattacker i befintliga PoC-system, vilket säkerställer att effektiv miningkraft förblir strikt proportionell mot bunden lagringskapacitet;
(2) Time Bending-algoritmen, som omvandlar deadline-fördelningar från exponentiella till chi-kvadrat, vilket minskar blocktidsvarians utan att ändra medelvärdet;
(3) En OP_RETURN-baserad forging-assignment-mekanism som möjliggör icke-förvaringsbaserad poolmining; och
(4) Dynamisk kompressionsskalning, som ökar plotgenereringssvårighet i linje med halveringsscheman för att bibehålla långsiktiga säkerhetsmarginaler när hårdvara förbättras.

Bitcoin-PoCX behåller Bitcoin Cores arkitektur genom minimala, funktionsflaggade modifikationer, vilket isolerar PoC-logik från den befintliga konsensuskoden. Systemet bevarar Bitcoins monetära policy genom att sikta på ett 120-sekunders blockintervall och justera blocksubventionen till 10 BTC. Den reducerade subventionen kompenserar för den femfaldiga ökningen i blockfrekvens, håller den långsiktiga emissionstakten i linje med Bitcoins ursprungliga schema och bibehåller det maximala utbudet på ~21 miljoner.

---

## 1. Introduktion

### 1.1 Motivation

Bitcoins Proof-of-Work (PoW)-konsensus har visat sig säker under mer än ett decennium, men till betydande kostnad: miners måste kontinuerligt förbruka beräkningsresurser, vilket resulterar i hög energiförbrukning. Utöver effektivitetsproblem finns en bredare motivation: att utforska alternativa konsensusmekanismer som bibehåller säkerhet samtidigt som tröskeln för deltagande sänks. PoC möjliggör för praktiskt taget alla med standardlagringshårdvara att mina effektivt, vilket minskar centraliseringstrycket som ses i ASIC-dominerad PoW-mining.

Proof of Capacity (PoC) uppnår detta genom att härleda miningkraft från lagringsbindning snarare än pågående beräkning. Miners förberäknar stora mängder disklagrade hashar - plottar - under en engångs-plottningsfas. Mining består sedan av lättviktiga uppslagningar, vilket drastiskt minskar energianvändningen samtidigt som säkerhetsantagandena för resursbaserad konsensus bevaras.

### 1.2 Integration med Bitcoin Core

Bitcoin-PoCX integrerar PoC-konsensus i Bitcoin Core snarare än att skapa en ny blockchain. Detta tillvägagångssätt utnyttjar Bitcoin Cores beprövade säkerhet, mogna nätverksstack och allmänt antagna verktyg, samtidigt som modifieringar hålls minimala och funktionsflaggade. PoC-logik är isolerad från befintlig konsensuskod, vilket säkerställer att kärnfunktionalitet - blockvalidering, plånboksoperationer, transaktionsformat - förblir i stort sett oförändrad.

### 1.3 Designmål

**Säkerhet**: Behåll Bitcoin-ekvivalent robusthet; attacker kräver majoritetslagringskapacitet.

**Effektivitet**: Minska pågående beräkningsbelastning till disk-I/O-nivåer.

**Tillgänglighet**: Möjliggör mining med standardhårdvara, sänk trösklar för deltagande.

**Minimal integration**: Introducera PoC-konsensus med minimalt modifieringsavtryck.

---

## 2. Bakgrund: Proof of Capacity

### 2.1 Historik

Proof of Capacity (PoC) introducerades av Burstcoin 2014 som ett energieffektivt alternativ till Proof-of-Work (PoW). Burstcoin demonstrerade att miningkraft kunde härledas från bunden lagring snarare än kontinuerlig realtidshashning: miners förberäknade stora datamängder ("plottar") en gång och minade sedan genom att läsa små, fasta delar av dem.

Tidiga PoC-implementationer bevisade konceptets genomförbarhet men avslöjade också att plotformat och kryptografisk struktur är kritiska för säkerhet. Flera tid-minnesavvägningar tillät angripare att mina effektivt med mindre lagring än ärliga deltagare. Detta framhävde att PoC-säkerhet beror på plotdesign - inte bara på att använda lagring som resurs.

Burstcoins arv etablerade PoC som en praktisk konsensusmekanism och gav grunden som PoCX bygger på.

### 2.2 Kärnkoncept

PoC-mining baseras på stora, förberäknade plotfiler lagrade på disk. Dessa plottar innehåller "frusen beräkning": dyr hashning utförs en gång under plottning, och mining består sedan av lättviktiga diskläsningar och enkel verifiering. Kärnelement inkluderar:

**Nonce:**
Den grundläggande enheten av plotdata. Varje nonce innehåller 4096 scoops (256 KiB totalt) genererade via Shabal256 från miners adress och nonce-index.

**Scoop:**
Ett 64-byte-segment inuti en nonce. För varje block väljer nätverket deterministiskt ett scoop-index (0-4095) baserat på föregående blocks generationssignatur. Endast denna scoop per nonce måste läsas.

**Generationssignatur:**
Ett 256-bitars värde härlett från föregående block. Det ger enttropi för scoop-urval och förhindrar miners från att förutse framtida scoop-index.

**Warp:**
En strukturell grupp om 4096 nonces (1 GiB). Warpar är den relevanta enheten för kompressionsresistenta plotformat.

### 2.3 Miningprocess och kvalitetspipeline

PoC-mining består av ett engångs-plottningssteg och en lättviktig per-block-rutin:

**Engångsinstallation:**
- Plotgenerering: Beräkna nonces via Shabal256 och skriv dem till disk.

**Per-block-mining:**
- Scoop-urval: Bestäm scoop-index från generationssignaturen.
- Plotskanning: Läs den scoopen från alla nonces i miners plottar.

**Kvalitetspipeline:**
- Rå kvalitet: Hasha varje scoop med generationssignaturen med Shabal256Lite för att erhålla ett 64-bitars kvalitetsvärde (lägre är bättre).
- Deadline: Konvertera kvalitet till en deadline med basmålet (en svårighetsjusterad parameter som säkerställer att nätverket når sitt målblockintervall): `deadline = quality / base_target`
- Böjd deadline: Applicera Time Bending-transformationen för att minska varians samtidigt som förväntad blocktid bevaras.

**Blockforgning:**
Minern med kortast (böjd) deadline forgar nästa block när den tiden har förflutit.

Till skillnad från PoW sker nästan all beräkning under plottning; aktiv mining är primärt diskbunden och mycket lågeffektiv.

### 2.4 Kända sårbarheter i tidigare system

**POC1-fördelningsbrist:**
Det ursprungliga Burstcoin POC1-formatet uppvisade en strukturell bias: låg-index-scoops var betydligt billigare att omberäkna i realtid än hög-index-scoops. Detta introducerade en ojämn tid-minnesavvägning, vilket tillät angripare att minska erforderlig lagring för de scooparna och bröt antagandet att all förberäknad data var lika dyr.

**XOR-kompressionsattack (POC2):**
I POC2 kan en angripare ta vilken uppsättning av 8192 nonces som helst och partitionera dem i två block om 4096 nonces (A och B). Istället för att lagra båda blocken lagrar angriparen endast en härledd struktur: `A ⊕ transpose(B)`, där transponeringen byter scoop- och nonce-index - scoop S av nonce N i block B blir scoop N av nonce S.

Under mining, när scoop S av nonce N behövs, rekonstruerar angriparen den genom att:
1. Läsa det lagrade XOR-värdet vid position (S, N)
2. Beräkna nonce N från block A för att erhålla scoop S
3. Beräkna nonce S från block B för att erhålla den transponerade scoop N
4. XOR:a alla tre värden för att återställa den ursprungliga 64-byte-scoopen

Detta minskar lagring med 50%, medan endast två nonce-beräkningar per uppslag krävs - en kostnad långt under tröskeln som behövs för att upprätthålla fullständig förberäkning. Attacken är genomförbar eftersom beräkning av en rad (en nonce, 4096 scoops) är billig, medan beräkning av en kolumn (en enskild scoop över 4096 nonces) skulle kräva regenerering av alla nonces. Transponeringsstrukturen exponerar denna obalans.

Detta demonstrerade behovet av ett plotformat som förhindrar sådan strukturerad rekombination och tar bort den underliggande tid-minnesavvägningen. Avsnitt 3.3 beskriver hur PoCX adresserar och löser denna svaghet.

### 2.5 Övergång till PoCX

Begränsningarna hos tidigare PoC-system gjorde klart att säker, rättvis och decentraliserad lagringsmining beror på noggrant konstruerade plotstrukturer. Bitcoin-PoCX adresserar dessa problem med ett härdat plotformat, förbättrad deadline-fördelning och mekanismer för decentraliserad poolmining - beskrivet i nästa avsnitt.

---

## 3. PoCX-plotformat

### 3.1 Basnonce-konstruktion

En nonce är en 256 KiB-datastruktur härledd deterministiskt från tre parametrar: en 20-byte adresspayload, ett 32-byte seed och ett 64-bitars nonce-index.

Konstruktion börjar med att kombinera dessa indata och hasha dem med Shabal256 för att producera en initial hash. Denna hash fungerar som startpunkt för en iterativ expansionsprocess: Shabal256 appliceras upprepade gånger, med varje steg beroende på tidigare genererad data, tills hela 256 KiB-bufferten är fylld. Denna kedjade process representerar det beräkningsarbete som utförs under plottning.

Ett slutligt diffusionssteg hashar den färdiga bufferten och XOR:ar resultatet över alla bytes. Detta säkerställer att hela bufferten har beräknats och att miners inte kan genväga beräkningen. PoC2-blandningen appliceras sedan, vilket byter de nedre och övre halvorna av varje scoop för att garantera att alla scoops kräver ekvivalent beräkningsinsats.

Den slutliga noncen består av 4096 scoops om 64 bytes vardera och utgör den fundamentala enheten som används i mining.

### 3.2 SIMD-justerad plotlayout

För att maximera genomströmning på modern hårdvara organiserar PoCX nonce-data på disk för att underlätta vektoriserad bearbetning. Istället för att lagra varje nonce sekventiellt justerar PoCX motsvarande 4-byte-ord över flera konsekutiva nonces sammanhängande. Detta tillåter en enskild minnesinhämtning att tillhandahålla data för alla SIMD-lanes, minimerar cachemissar och eliminerar scatter-gather-overhead.

```
Traditionell layout:
Nonce0: [O0][O1][O2][O3]...
Nonce1: [O0][O1][O2][O3]...
Nonce2: [O0][O1][O2][O3]...

PoCX SIMD-layout:
Ord0: [N0][N1][N2]...[N15]
Ord1: [N0][N1][N2]...[N15]
Ord2: [N0][N1][N2]...[N15]
```

Denna layout gynnar både CPU- och GPU-miners, möjliggör hög genomströmning, parallelliserad scoop-utvärdering samtidigt som ett enkelt skalärt åtkomstmönster behålls för konsensusverifiering. Det säkerställer att mining begränsas av lagringsbandbredd snarare än CPU-beräkning, bibehåller den lågeffektiva naturen hos Proof of Capacity.

### 3.3 Warp-struktur och XOR-transponering-kodning

En warp är den fundamentala lagringsenheten i PoCX, bestående av 4096 nonces (1 GiB). Det okomprimerade formatet, kallat X0, innehåller basnonces exakt som producerade av konstruktionen i avsnitt 3.1.

**XOR-transponering-kodning (X1)**

För att ta bort de strukturella tid-minnesavvägningarna som finns i tidigare PoC-system härleder PoCX ett härdat miningformat, X1, genom att applicera XOR-transponering-kodning på par av X0-warpar.

För att konstruera scoop S av nonce N i en X1-warp:

1. Ta scoop S av nonce N från den första X0-warpen (direkt position)
2. Ta scoop N av nonce S från den andra X0-warpen (transponerad position)
3. XOR:a de två 64-byte-värdena för att erhålla X1-scoopen

Transponeringssteget byter scoop- och nonce-index. I matristermer - där rader representerar scoops och kolumner representerar nonces - kombinerar det elementet vid position (S, N) i den första warpen med elementet vid (N, S) i den andra.

**Varför detta eliminerar kompressionsattackytan**

XOR-transponeringen sammanflätar varje scoop med en hel rad och en hel kolumn av den underliggande X0-datan. Att återställa en enskild X1-scoop kräver därför åtkomst till data som spänner över alla 4096 scoop-index. Varje försök att beräkna saknad data skulle kräva regenerering av 4096 fullständiga nonces, snarare än en enskild nonce - vilket tar bort den asymmetriska kostnadsstrukturen som utnyttjades av XOR-attacken för POC2 (avsnitt 2.4).

Som ett resultat blir lagring av den fullständiga X1-warpen den enda beräkningsmässigt gångbara strategin för miners, vilket stänger tid-minnesavvägningen som utnyttjades i tidigare designer.

### 3.4 Disklayout

PoCX-plotfiler består av många konsekutiva X1-warpar. För att maximera operativ effektivitet under mining organiseras datan inom varje fil efter scoop: all scoop 0-data från varje warp lagras sekventiellt, följt av all scoop 1-data, och så vidare, upp till scoop 4095.

Denna **scoop-sekventiella ordning** tillåter miners att läsa den fullständiga datan som krävs för en vald scoop i en enda sekventiell diskåtkomst, minimerar söktider och maximerar genomströmning på standardlagringsenheter.

Kombinerat med XOR-transponering-kodningen i avsnitt 3.3 säkerställer denna layout att filen är både **strukturellt härdad** och **operationellt effektiv**: sekventiell scoop-ordning stöder optimal disk-I/O, medan SIMD-justerade minneslayouter (se avsnitt 3.2) tillåter hög genomströmning, parallelliserad scoop-utvärdering.

### 3.5 Proof-of-Work-skalning (Xn)

PoCX implementerar skalbar förberäkning genom konceptet skalningsnivåer, betecknade Xn, för att anpassa sig till utvecklande hårdvaruprestanda. Baslinjen X1-formatet representerar den första XOR-transponering-härdade warp-strukturen.

Varje skalningsnivå Xn ökar det proof-of-work som är inbäddat i varje warp exponentiellt relativt X1: arbetet som krävs vid nivå Xn är 2^(n-1) gånger det för X1. Övergång från Xn till Xn+1 är operationellt ekvivalent med att applicera en XOR över par av angränsande warpar, vilket inkrementellt bäddar in mer proof-of-work utan att ändra den underliggande plotstorleken.

Befintliga plotfiler skapade vid lägre skalningsnivåer kan fortfarande användas för mining, men de bidrar proportionellt mindre arbete mot blockgenerering, vilket reflekterar deras lägre inbäddade proof-of-work. Denna mekanism säkerställer att PoCX-plottar förblir säkra, flexibla och ekonomiskt balanserade över tid.

### 3.6 Seed-funktionalitet

Seed-parametern möjliggör flera icke-överlappande plottar per adress utan manuell koordinering.

**Problem (POC2)**: Miners var tvungna att manuellt spåra nonce-intervall över plotfiler för att undvika överlappning. Överlappande nonces slösar lagring utan att öka miningkraft.

**Lösning**: Varje `(adress, seed)`-par definierar ett oberoende nyckelutrymme. Plottar med olika seeds överlappar aldrig, oavsett nonce-intervall. Miners kan skapa plottar fritt utan koordinering.

---

## 4. Proof of Capacity-konsensus

PoCX utökar Bitcoins Nakamoto-konsensus med en lagringsbunden bevismekanism. Istället för att förbruka energi på upprepad hashning binder miners stora mängder förberäknad data - plottar - till disk. Under blockgenerering måste de lokalisera en liten, oförutsägbar del av denna data och omvandla den till ett bevis. Minern som tillhandahåller det bästa beviset inom det förväntade tidsfönstret får rätten att forga nästa block.

Detta kapitel beskriver hur PoCX strukturerar blockmetadata, härleder oförutsägbarhet och omvandlar statisk lagring till en säker konsensusmekanism med låg varians.

### 4.1 Blockstruktur

PoCX behåller den välbekanta Bitcoin-stil-blockheadern men introducerar ytterligare konsensusfält som krävs för kapacitetsbaserad mining. Dessa fält binder kollektivt blocket till miners lagrade plot, nätverkets svårighet och den kryptografiska entropin som definierar varje miningutmaning.

På en hög nivå innehåller ett PoCX-block: blockhöjden, registrerad explicit för att förenkla kontextuell validering; generationssignaturen, en källa till färsk entropi som länkar varje block till sin föregångare; basmålet, som representerar nätverkssvårighet i inverterad form (högre värden motsvarar enklare mining); PoCX-beviset, som identifierar miners plot, kompressionsnivån använd under plottning, den valda noncen och kvaliteten härledd från den; och en signeringsnyckel och signatur, som bevisar kontroll över den kapacitet som används för att forga blocket (eller en tilldelad forgingsnyckel).

Beviset bäddar in all konsensusrelevant information som behövs av validerare för att omberäkna utmaningen, verifiera den valda scoopen och bekräfta den resulterande kvaliteten. Genom att utöka snarare än omdesigna blockstrukturen förblir PoCX konceptuellt i linje med Bitcoin samtidigt som en fundamentalt annorlunda källa till miningarbete möjliggörs.

### 4.2 Generationssignaturkedja

Generationssignaturen tillhandahåller den oförutsägbarhet som krävs för säker Proof of Capacity-mining. Varje block härleder sin generationssignatur från föregående blocks signatur och signerare, vilket säkerställer att miners inte kan förutse framtida utmaningar eller förberäkna fördelaktiga plotregioner:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

Detta producerar en sekvens av kryptografiskt starka, minerberoende entropi-värden. Eftersom en miners publika nyckel är okänd tills föregående block publiceras kan ingen deltagare förutse framtida scoop-urval. Detta förhindrar selektiv förberäkning eller strategisk plottning och säkerställer att varje block introducerar genuint färskt miningarbete.

### 4.3 Forgningsprocess

Mining i PoCX består av att omvandla lagrad data till ett bevis drivet helt av generationssignaturen. Även om processen är deterministisk säkerställer oförutsägbarheten hos signaturen att miners inte kan förbereda i förväg och upprepade gånger måste komma åt sina lagrade plottar.

**Utmaningshärledning (scoop-urval):** Minern hashar den aktuella generationssignaturen med blockhöjden för att erhålla ett scoop-index i intervallet 0-4095. Detta index bestämmer vilket 64-byte-segment av varje lagrad nonce som deltar i beviset. Eftersom generationssignaturen beror på föregående blocks signerare blir scoop-urval känt först vid ögonblicket för blockpublicering.

**Bevisutvärdering (kvalitetsberäkning):** För varje nonce i en plot hämtar minern den valda scoopen och hashar den tillsammans med generationssignaturen för att erhålla en kvalitet - ett 64-bitars värde vars magnitud bestämmer miners konkurrenskraft. Lägre kvalitet motsvarar ett bättre bevis.

**Deadline-formning (Time Bending):** Den råa deadlinen är proportionell mot kvaliteten och omvänt proportionell mot basmålet. I äldre PoC-designer följde dessa deadlines en mycket skev exponentiell fördelning, producerande långa svansförseningar som inte gav ytterligare säkerhet. PoCX omvandlar den råa deadlinen med Time Bending (avsnitt 4.4), minskar varians och säkerställer förutsägbara blockintervall. När den böjda deadlinen löper ut forgar minern ett block genom att bädda in beviset och signera det med den effektiva forgingnnyckeln.

### 4.4 Time Bending

Proof of Capacity producerar exponentiellt fördelade deadlines. Efter en kort period - typiskt några tiotal sekunder - har varje miner redan identifierat sitt bästa bevis, och eventuell ytterligare väntetid bidrar endast latens, inte säkerhet.

Time Bending omformar fördelningen genom att applicera en kubikrot-transformation:

`deadline_bended = scale × (quality / base_target)^(1/3)`

Skalfaktorn bevarar den förväntade blocktiden (120 sekunder) samtidigt som variansen minskas dramatiskt. Korta deadlines utökas, vilket förbättrar blockpropagering och nätverkssäkerhet. Långa deadlines komprimeras, vilket förhindrar utliggare från att försena kedjan.

![Blocktidsfördelningar](blocktime_distributions.svg)

Time Bending bibehåller det informationsinnehåll som finns i det underliggande beviset. Det modifierar inte konkurrenskraft bland miners; det omfördelar endast väntetid för att producera jämnare, mer förutsägbara blockintervall. Implementationen använder fastpunktsaritmetik (Q42-format) och 256-bitars heltal för att säkerställa deterministiska resultat över alla plattformar.

### 4.5 Svårighetsjustering

PoCX reglerar blockproduktion med basmålet, ett inverterat svårighetsmått. Den förväntade blocktiden är proportionell mot kvoten `quality / base_target`, så att öka basmålet accelererar blockskapande medan minskning saktar ner kedjan.

Svårighet justeras varje block med den uppmätta tiden mellan senaste block jämfört med målintervallet. Denna frekventa justering är nödvändig eftersom lagringskapacitet kan läggas till eller tas bort snabbt - till skillnad från Bitcoins hashkraft, som ändras långsammare.

Justeringen följer två vägledande begränsningar: **Gradualitet** - per-block-ändringar är begränsade (±20% maximum) för att undvika oscillationer eller manipulation; **Härdning** - basmålet kan inte överstiga sitt genesisvärde, vilket förhindrar nätverket från att någonsin sänka svårigheten under de ursprungliga säkerhetsantagandena.

### 4.6 Blockgiltighet

Ett block i PoCX är giltigt när det presenterar ett verifierbart lagringshärlett bevis konsistent med konsensustillståndet. Validerare omberäknar oberoende scoop-urvalet, härleder den förväntade kvaliteten från den inlämnade noncen och plotmetadata, applicerar Time Bending-transformationen och bekräftar att minern var berättigad att forga blocket vid den deklarerade tiden.

Specifikt kräver ett giltigt block: deadlinen har förflutit sedan föräldrarrblocket; den inlämnade kvaliteten matchar den beräknade kvaliteten för beviset; skalningsnivån uppfyller nätverkets minimum; generationssignaturen matchar det förväntade värdet; basmålet matchar det förväntade värdet; blocksignaturen kommer från den effektiva signeraren; och coinbase betalar till den effektiva signerarens adress.

---

## 5. Forging Assignments

### 5.1 Motivation

Forging assignments tillåter plotägare att delegera blockforgnings-auktoritet utan att någonsin överlämna ägarskap över sina plottar. Denna mekanism möjliggör poolmining och kalllagringskonfigurationer samtidigt som PoCX:s säkerhetsgarantier bevaras.

I poolmining kan plotägare auktorisera en pool att forga block för deras räkning. Poolen sammanställer block och distribuerar belöningar, men den får aldrig förvar över plottarna själva. Delegering är reversibel när som helst, och plotägare förblir fria att lämna en pool eller ändra konfigurationer utan omplotning.

Tilldelningar stöder också en ren separation mellan kalla och varma nycklar. Den privata nyckeln som kontrollerar plottet kan förbli offline, medan en separat forgingnyckel - lagrad på en online-maskin - producerar block. En kompromiss av forgingnyckeln kompromissar därför endast forgingsauktoritet, inte ägarskap. Plottet förblir säkert och tilldelningen kan återkallas, vilket stänger säkerhetsluckan omedelbart.

Forging assignments ger därför operativ flexibilitet samtidigt som principen bibehålls att kontroll över lagrad kapacitet aldrig får överföras till mellanhänder.

### 5.2 Tilldelningsprotokoll

Tilldelningar deklareras genom OP_RETURN-transaktioner för att undvika onödig tillväxt av UTXO-setet. En tilldelningsstransaktion specificerar plotadressen och forgingsadressen som är auktoriserad att producera block med den plottens kapacitet. En återkallelsetransaktion innehåller endast plotadressen. I båda fallen bevisar plotägaren kontroll genom att signera spenderingsinputen för transaktionen.

Varje tilldelning fortskrider genom en sekvens av väldefinierade tillstånd (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Efter att en tilldelningsstransaktion bekräftas går systemet in i en kort aktiveringsfas. Denna fördröjning - 30 block, ungefär en timme - säkerställer stabilitet under blockraces och förhindrar antagonistiskt snabbt byte av forgingsidentiteter. När denna aktiveringsperiod löper ut blir tilldelningen aktiv och förblir så tills plotägaren utfärdar en återkallelse.

Återkallelser övergår till en längre fördröjningsperiod på 720 block, ungefär en dag. Under denna tid förblir den tidigare forgingsadressen aktiv. Denna längre fördröjning ger operativ stabilitet för pooler, förhindrar strategiskt "tilldelningshoppande" och ger infrastrukturleverantörer tillräcklig säkerhet för att arbeta effektivt. Efter att återkallelsefördröjningen löper ut slutförs återkallelsen, och plotägaren är fri att utse en ny forgingnyckel.

Tilldelningsstatus bibehålls i en konsensuslagerstruktur parallell med UTXO-setet och stöder undo-data för säker hantering av kedjereorganiseringar.

### 5.3 Valideringsregler

För varje block bestämmer validerare den effektiva signeraren - adressen som måste signera blocket och ta emot coinbase-belöningen. Denna signerare beror uteslutande på tilldelningsstatus vid blockets höjd.

Om ingen tilldelning existerar eller tilldelningen ännu inte har slutfört sin aktiveringsfas förblir plotägaren den effektiva signeraren. När en tilldelning blir aktiv måste den tilldelade forgingsadressen signera. Under återkallelse fortsätter forgingsadressen att signera tills återkallelsefördröjningen löper ut. Först då återgår auktoritet till plotägaren.

Validerare upprätthåller att blocksignaturen produceras av den effektiva signeraren, att coinbase betalar till samma adress, och att alla övergångar följer de föreskrivna aktiverings- och återkallelsefördröjningarna. Endast plotägaren kan skapa eller återkalla tilldelningar; forgingnycklar kan inte modifiera eller utöka sina egna behörigheter.

Forging assignments introducerar därför flexibel delegering utan att introducera förtroende. Ägarskap av den underliggande kapaciteten förblir alltid kryptografiskt förankrad till plotägaren, medan forgingsauktoritet kan delegeras, roteras eller återkallas när operativa behov utvecklas.

---

## 6. Dynamisk skalning

När hårdvara utvecklas minskar kostnaden för att beräkna plottar relativt läsning av förberäknat arbete från disk. Utan motåtgärder kunde angripare så småningom generera bevis i realtid snabbare än miners som läser lagrat arbete, vilket underminerar säkerhetsmodellen för Proof of Capacity.

För att bevara den avsedda säkerhetsmarginalen implementerar PoCX ett skalningsschema: den minsta erforderliga skalningsnivån för plottar ökar över tid. Varje skalningsnivå Xn, som beskrivet i avsnitt 3.5, bäddar in exponentiellt mer proof-of-work inom plotstrukturen, vilket säkerställer att miners fortsätter att binda betydande lagringsresurser även när beräkning blir billigare.

Schemat anpassas till nätverkets ekonomiska incitament, särskilt blockbelöningshalveringar. När belöningen per block minskar ökar gradvis minimalnivån, vilket bevarar balansen mellan plottningsinsats och miningpotential:

| Period | År | Halveringar | Min skalning | Plotarbetsmultiplikator |
|--------|-----|-------------|--------------|-------------------------|
| Epok 0 | 0-4 | 0 | X1 | 2× baslinje |
| Epok 1 | 4-12 | 1-2 | X2 | 4× baslinje |
| Epok 2 | 12-28 | 3-6 | X3 | 8× baslinje |
| Epok 3 | 28-60 | 7-14 | X4 | 16× baslinje |
| Epok 4 | 60-124 | 15-30 | X5 | 32× baslinje |
| Epok 5 | 124+ | 31+ | X6 | 64× baslinje |

Miners kan valfritt förbereda plottar som överskrider den nuvarande minimalnivån med en nivå, vilket tillåter dem att planera framåt och undvika omedelbara uppgraderingar när nätverket övergår till nästa epok. Detta valfria steg ger inte ytterligare fördel i termer av blocksannolikhet - det möjliggör bara en smidigare operativ övergång.

Block som innehåller bevis under minsta skalningsnivå för sin höjd anses ogiltiga. Validerare kontrollerar den deklarerade skalningsnivån i beviset mot det aktuella nätverkskravet under konsensusvalidering, vilket säkerställer att alla deltagande miners uppfyller de utvecklande säkerhetsförväntningarna.

---

## 7. Miningarkitektur

PoCX separerar konsensuskritiska operationer från de resursintensiva uppgifterna för mining, vilket möjliggör både säkerhet och effektivitet. Noden bibehåller blockkedjan, validerar block, hanterar mempoolen och exponerar ett RPC-gränssnitt. Externa miners hanterar plotlagring, scoop-läsning, kvalitetsberäkning och deadline-hantering. Denna separation håller konsensuslogik enkel och granskningsbar samtidigt som miners kan optimera för diskgenomströmning.

### 7.1 Mining-RPC-gränssnitt

Miners interagerar med noden genom en minimal uppsättning RPC-anrop. get_mining_info RPC tillhandahåller den aktuella blockhöjden, generationssignaturen, basmålet, måldeadlinen och det acceptabla intervallet av plotskalningsnivåer. Med denna information beräknar miners kandidatnonces. submit_nonce RPC tillåter miners att skicka en föreslagen lösning, inklusive plotidentifierare, nonce-index, skalningsnivå och minerkonto. Noden utvärderar inlämningen och svarar med den beräknade deadlinen om beviset är giltigt.

### 7.2 Forgningsschemaläggare

Noden bibehåller en forgningsschemaläggare, som spårar inkommande inlämningar och behåller endast den bästa lösningen för varje blockhöjd. Inlämnade nonces köas med inbyggda skydd mot inlämningsöversvämning eller denial-of-service-attacker. Schemaläggaren väntar tills den beräknade deadlinen löper ut eller en överlägsen lösning anländer, varefter den sammanställer ett block, signerar det med den effektiva forgingnyckeln och publicerar det till nätverket.

### 7.3 Defensiv forgning

För att förhindra tidsattacker eller incitament för klockmanipulation implementerar PoCX defensiv forgning. Om ett konkurrerande block anländer för samma höjd jämför schemaläggaren den lokala lösningen med det nya blocket. Om den lokala kvaliteten är överlägsen forgar noden omedelbart snarare än att vänta på den ursprungliga deadlinen. Detta säkerställer att miners inte kan få fördel genom att endast justera lokala klockor; den bästa lösningen vinner alltid, vilket bevarar rättvisa och nätverkssäkerhet.

---

## 8. Säkerhetsanalys

### 8.1 Hotmodell

PoCX modellerar motståndare med betydande men begränsade kapaciteter. Angripare kan försöka överbelasta nätverket med ogiltiga transaktioner, felformade block eller fabricerade bevis för att stresstesta valideringsvägar. De kan fritt manipulera sina lokala klockor och kan försöka utnyttja kantfall i konsensusbeteende såsom tidsstämpelhantering, svårighetsjusteringsdynamik eller reorganiseringsregler. Motståndare förväntas också sondera efter möjligheter att skriva om historik genom riktade kedjeforks.

Modellen antar att ingen enskild part kontrollerar en majoritet av total nätverkslagringskapacitet. Som med vilken resursbaserad konsensusmekanism som helst kan en 51% kapacitetsangripare ensidigt reorganisera kedjan; denna fundamentala begränsning är inte specifik för PoCX. PoCX antar också att angripare inte kan beräkna plotdata snabbare än ärliga miners kan läsa den från disk. Skalningsschemat (avsnitt 6) säkerställer att det beräkningsgap som krävs för säkerhet växer över tid när hårdvara förbättras.

Avsnitten som följer undersöker varje stor attackklass i detalj och beskriver de motåtgärder som är inbyggda i PoCX.

### 8.2 Kapacitetsattacker

Liksom PoW kan en angripare med majoritetskapacitet skriva om historik (en 51%-attack). Att uppnå detta kräver att man förvärvar ett fysiskt lagringsavtryck större än det ärliga nätverket - ett dyrt och logistiskt krävande åtagande. När hårdvaran väl erhållits är driftskostnaderna låga, men den initiala investeringen skapar ett starkt ekonomiskt incitament att bete sig ärligt: att underminera kedjan skulle skada värdet på angriparens egen tillgångsbas.

PoC undviker också nothing-at-stake-problemet associerat med PoS. Även om miners kan skanna plottar mot flera konkurrerande forks konsumerar varje skanning reell tid - typiskt i storleksordningen tiotals sekunder per kedja. Med ett 120-sekunders blockintervall begränsar detta inneboende multi-fork-mining, och att försöka mina många forks samtidigt försämrar prestanda på alla. Fork-mining är därför inte kostnadsfri; den är fundamentalt begränsad av I/O-genomströmning.

Även om framtida hårdvara tillät nästan ögonblicklig plotskanning (t.ex. höghastighets-SSD:er), skulle en angripare fortfarande möta ett betydande fysiskt resurskrav för att kontrollera en majoritet av nätverkskapacitet, vilket gör en 51%-stil attack dyr och logistiskt utmanande.

Slutligen är kapacitetsattacker mycket svårare att hyra än hashkraftsattacker. GPU-beräkning kan förvärvas på begäran och omdirigeras till vilken PoW-kedja som helst omedelbart. Däremot kräver PoC fysisk hårdvara, tidsintensiv plottning och pågående I/O-operationer. Dessa begränsningar gör kortsiktiga, opportunistiska attacker mycket mindre genomförbara.

### 8.3 Tidsattacker

Timing spelar en mer kritisk roll i Proof of Capacity än i Proof of Work. I PoW påverkar tidsstämplar primärt svårighetsjustering; i PoC bestämmer de om en miners deadline har förflutit och därmed om ett block är berättigat till forgning. Deadlines mäts relativt föräldra-blockets tidsstämpel, men en nods lokala klocka används för att bedöma om ett inkommande block ligger för långt i framtiden. Av denna anledning upprätthåller PoCX en tight tidsstämpeltolerans: block får inte avvika mer än 15 sekunder från nodens lokala klocka (jämfört med Bitcoins 2-timmarsfönster). Denna gräns fungerar i båda riktningarna - block för långt i framtiden avvisas, och noder med långsamma klockor kan felaktigt avvisa giltiga inkommande block.

Noder bör därför synkronisera sina klockor med NTP eller en motsvarande tidskälla. PoCX undviker medvetet att förlita sig på nätverksinterna tidskällor för att förhindra angripare från att manipulera uppfattad nätverkstid. Noder övervakar sin egen drift och avger varningar om den lokala klockan börjar avvika från senaste blocktidsstämplar.

Klockacceleration - att köra en snabb lokal klocka för att forga något tidigare - ger endast marginell fördel. Inom den tillåtna toleransen säkerställer defensiv forgning (avsnitt 7.3) att en miner med en bättre lösning omedelbart kommer att publicera vid att se ett underlägset tidigt block. En snabb klocka hjälper bara en miner att publicera en redan vinnande lösning några sekunder tidigare; den kan inte konvertera ett underlägset bevis till ett vinnande.

Försök att manipulera svårighet via tidsstämplar begränsas av en ±20% per-block-justeringsgräns och ett 24-blocks rullande fönster, vilket förhindrar miners från att meningsfullt påverka svårighet genom kortsiktiga tidsspel.

### 8.4 Tid-minnesavvägningsattacker

Tid-minnesavvägningar försöker minska lagringskrav genom att omberäkna delar av plottet på begäran. Tidigare Proof of Capacity-system var sårbara för sådana attacker, mest anmärkningsvärt POC1 scoop-obalansbristen och POC2 XOR-transponerings-kompressionsattacken (avsnitt 2.4). Båda utnyttjade asymmetrier i hur dyrt det var att regenerera vissa delar av plotdata, vilket tillät motståndare att skära lagring medan de endast betalade en liten beräkningsstraff. Dessutom lider alternativa plotformat till PoC2 av liknande TMTO-svagheter; ett framträdande exempel är Chia, vars plotformat kan reduceras godtyckligt med en faktor större än 4.

PoCX tar bort dessa attackytor helt genom sin nonce-konstruktion och warp-format. Inom varje nonce hashar det slutliga diffusionssteget den fullständigt beräknade bufferten och XOR:ar resultatet över alla bytes, vilket säkerställer att varje del av bufferten beror på varannan del och inte kan genvägars. Efteråt byter PoC2-blandningen de nedre och övre halvorna av varje scoop, vilket utjämnar beräkningskostnaden för att återställa vilken scoop som helst.

PoCX eliminerar vidare POC2 XOR-transponerings-kompressionsattacken genom att härleda sitt härdade X1-format, där varje scoop är XOR:et av en direkt och en transponerad position över parade warpar; detta sammanflätar varje scoop med en hel rad och en hel kolumn av underliggande X0-data, vilket gör rekonstruktion kräver tusentals fullständiga nonces och därmed tar bort den asymmetriska tid-minnesavvägningen helt.

Som ett resultat är lagring av det fullständiga plottet den enda beräkningsmässigt gångbara strategin för miners. Ingen känd genväg - vare sig partiell plottning, selektiv regenerering, strukturerad kompression eller hybridberäknings-lagringsmetoder - ger en meningsfull fördel. PoCX säkerställer att mining förblir strikt lagringsbunden och att kapacitet reflekterar verklig, fysisk bindning.

### 8.5 Tilldelningsattacker

PoCX använder en deterministisk tillståndsmaskin för att styra alla plot-till-forger-tilldelningar. Varje tilldelning fortskrider genom väldefinierade tillstånd - UNASSIGNED -> ASSIGNING -> ASSIGNED -> REVOKING -> REVOKED - med upprätthållna aktiverings- och återkallelsefördröjningar. Detta säkerställer att en miner inte kan ögonblickligen ändra tilldelningar för att fuska i systemet eller snabbt byta forgingsauktoritet.

Eftersom alla övergångar kräver kryptografiska bevis - specifikt signaturer av plotägaren som är verifierbara mot input-UTXO:n - kan nätverket lita på legitimiteten hos varje tilldelning. Försök att förbigå tillståndsmaskinen eller förfalska tilldelningar avvisas automatiskt under konsensusvalidering. Replay-attacker förhindras likaså av standard Bitcoin-stil transaktionsreplay-skydd, vilket säkerställer att varje tilldelningsåtgärd är unikt knuten till en giltig, ospenderad input.

Kombinationen av tillståndsmaskin-styrning, upprätthållna fördröjningar och kryptografiskt bevis gör tilldelningsbaserat fusk praktiskt omöjligt: miners kan inte kapa tilldelningar, utföra snabb omtilldelning under blockraces eller kringgå återkallelsescheman.

### 8.6 Signatursäkerhet

Blocksignaturer i PoCX fungerar som en kritisk länk mellan ett bevis och den effektiva forgingnyckeln, vilket säkerställer att endast auktoriserade miners kan producera giltiga block.

För att förhindra formbarhetssattacker exkluderas signaturer från blockhashberäkningen. Detta eliminerar risker för formbara signaturer som kunde underminera validering eller tillåta blockersättningsattacker.

För att mildra denial-of-service-vektorer är signatur- och publika nyckel-storlekar fasta - 65 bytes för kompakta signaturer och 33 bytes för komprimerade publika nycklar - vilket förhindrar angripare från att blåsa upp block för att utlösa resursutmattning eller sakta ner nätverkspropagering.

---

## 9. Implementation

PoCX implementeras som en modulär utökning till Bitcoin Core, med all relevant kod innesluten i sin egen dedikerade underkatalog och aktiverad genom en funktionsflagga. Denna design bevarar integriteten hos den ursprungliga koden, vilket tillåter PoCX att aktiveras eller inaktiveras rent, vilket förenklar testning, granskning och synkronisering med uppströmsändringar.

Integrationen berör endast de väsentliga punkter som är nödvändiga för att stödja Proof of Capacity. Blockheadern har utökats för att inkludera PoCX-specifika fält, och konsensusvalidering har anpassats för att bearbeta lagringsbaserade bevis tillsammans med traditionella Bitcoin-kontroller. Forgingssystemet, ansvarigt för att hantera deadlines, schemaläggning och minerinlämningar, är helt innesluten inom PoCX-modulerna, medan RPC-utökningar exponerar mining- och tilldelningsfunktionalitet till externa klienter. För användare har plånboksgränssnittet förbättrats för att hantera tilldelningar genom OP_RETURN-transaktioner, vilket möjliggör sömlös interaktion med de nya konsensusfunktionerna.

Alla konsensuskritiska operationer implementeras i deterministisk C++ utan externa beroenden, vilket säkerställer plattformsoberoende konsistens. Shabal256 används för hashning, medan Time Bending och kvalitetsberäkning förlitar sig på fastpunktsaritmetik och 256-bitars operationer. Kryptografiska operationer såsom signaturverifiering utnyttjar Bitcoin Cores befintliga secp256k1-bibliotek.

Genom att isolera PoCX-funktionalitet på detta sätt förblir implementationen granskningsbar, underhållbar och fullt kompatibel med pågående Bitcoin Core-utveckling, vilket demonstrerar att en fundamentalt ny lagringsbunden konsensusmekanism kan samexistera med en mogen proof-of-work-kodbas utan att störa dess integritet eller användbarhet.

---

## 10. Nätverksparametrar

PoCX bygger på Bitcoins nätverksinfrastruktur och återanvänder dess kedjeparameterramverk. För att stödja kapacitetsbaserad mining, blockintervall, tilldelningshantering och plotskalning har flera parametrar utökats eller åsidosatts. Detta inkluderar blocktidsmålet, initial subvention, halveringsschema, aktiverings- och återkallelsefördröjningar för tilldelningar, samt nätverksidentifierare såsom magiska bytes, portar och Bech32-prefix. Testnet- och regtest-miljöer justerar ytterligare dessa parametrar för att möjliggöra snabb iteration och lågkapacitetstestning.

Tabellerna nedan sammanfattar de resulterande mainnet-, testnet- och regtest-inställningarna, och framhäver hur PoCX anpassar Bitcoins kärnparametrar till en lagringsbunden konsensusmodell.

### 10.1 Mainnet

| Parameter | Värde |
|-----------|-------|
| Magiska bytes | `0xa7 0x3c 0x91 0x5e` |
| Standardport | 8888 |
| Bech32 HRP | `pocx` |
| Blocktidsmål | 120 sekunder |
| Initial subvention | 10 BTC |
| Halveringsintervall | 1050000 block (~4 år) |
| Total tillgång | ~21 miljoner BTC |
| Tilldelningsaktivering | 30 block |
| Tilldelningsåterkallelse | 720 block |
| Rullande fönster | 24 block |

### 10.2 Testnet

| Parameter | Värde |
|-----------|-------|
| Magiska bytes | `0x6d 0xf2 0x48 0xb3` |
| Standardport | 18888 |
| Bech32 HRP | `tpocx` |
| Blocktidsmål | 120 sekunder |
| Övriga parametrar | Samma som mainnet |

### 10.3 Regtest

| Parameter | Värde |
|-----------|-------|
| Magiska bytes | `0xfa 0xbf 0xb5 0xda` |
| Standardport | 18444 |
| Bech32 HRP | `rpocx` |
| Blocktidsmål | 1 sekund |
| Halveringsintervall | 500 block |
| Tilldelningsaktivering | 4 block |
| Tilldelningsåterkallelse | 8 block |
| Lågkapacitetsläge | Aktiverat (~4 MB plottar) |

---

## 11. Relaterat arbete

Genom åren har flera blockchain- och konsensusprojekt utforskat lagringsbaserade eller hybrid-miningmodeller. PoCX bygger på detta arv samtidigt som förbättringar introduceras inom säkerhet, effektivitet och kompatibilitet.

**Burstcoin / Signum.** Burstcoin introducerade det första praktiska Proof-of-Capacity (PoC)-systemet 2014, och definierade kärnkoncept såsom plottar, nonces, scoops och deadline-baserad mining. Dess efterföljare, särskilt Signum (tidigare Burstcoin), utökade ekosystemet och utvecklades så småningom till det som kallas Proof-of-Commitment (PoC+), som kombinerar lagringsbindning med valfri staking för att påverka effektiv kapacitet. PoCX ärver den lagringsbaserade mininggrunden från dessa projekt, men avviker betydligt genom ett härdat plotformat (XOR-transponering-kodning), dynamisk plot-arbetsskalning, deadline-utjämning ("Time Bending") och ett flexibelt tilldelningssystem - allt medan förankring sker i Bitcoin Core-kodbasen snarare än att bibehålla en fristående nätverksfork.

**Chia.** Chia implementerar Proof of Space and Time, som kombinerar diskbaserade lagringsbevis med en tidskomponent upprätthållen via Verifiable Delay Functions (VDFs). Dess design adresserar vissa bekymmer om bevisåteranvändning och färsk utmaningsgenerering, distinkt från klassisk PoC. PoCX antar inte den tidsförankrade bevismodellen; istället bibehåller det en lagringsbunden konsensus med förutsägbara intervall, optimerad för långsiktig kompatibilitet med UTXO-ekonomi och Bitcoin-härledda verktyg.

**Spacemesh.** Spacemesh föreslår ett Proof-of-Space-Time (PoST)-schema med en DAG-baserad (mesh) nätverkstopologi. I denna modell måste deltagare periodiskt bevisa att allokerad lagring förblir intakt över tid, snarare än att förlita sig på en enda förberäknad datamängd. PoCX verifierar däremot lagringsbindning endast vid blocktid - med härdade plotformat och rigorös bevisvalidering - vilket undviker overheaden för kontinuerliga lagringsbevis samtidigt som effektivitet och decentralisering bevaras.

---

## 12. Slutsats

Bitcoin-PoCX demonstrerar att energieffektiv konsensus kan integreras i Bitcoin Core samtidigt som säkerhetsegenskaper och ekonomisk modell bevaras. Nyckelbidrag inkluderar XOR-transponering-kodningen (tvingar angripare att beräkna 4096 nonces per uppslag, vilket eliminerar kompressionsattacken), Time Bending-algoritmen (fördelningsomvandling minskar blocktidsvarians), forging assignment-systemet (OP_RETURN-baserad delegering möjliggör icke-förvaringsbaserad poolmining), dynamisk skalning (anpassad till halveringar för att bibehålla säkerhetsmarginaler) och minimal integration (funktionsflaggad kod isolerad i dedikerad katalog).

Systemet befinner sig för närvarande i testnetfas. Miningkraft härleds från lagringskapacitet snarare än hashrate, vilket minskar energiförbrukningen med storleksordningar samtidigt som Bitcoins beprövade ekonomiska modell bibehålls.

---

## Referenser

Bitcoin Core. *Bitcoin Core Repository.* https://github.com/bitcoin/bitcoin

Burstcoin. *Proof of Capacity Technical Documentation.* 2014.

NIST. *SHA-3 Competition: Shabal.* 2008.

Cohen, B., Pietrzak, K. *The Chia Network Blockchain.* 2019.

Spacemesh. *Spacemesh Protocol Documentation.* 2021.

PoC Consortium. *PoCX Framework.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Bitcoin-PoCX Integration.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Licens**: MIT
**Organisation**: Proof of Capacity Consortium
**Status**: Testnetfas
