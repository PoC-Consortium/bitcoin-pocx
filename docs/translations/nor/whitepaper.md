# Bitcoin-PoCX: Energieffektiv konsensus for Bitcoin Core

**Versjon**: 2.0 utkast
**Dato**: Desember 2025
**Organisasjon**: Proof of Capacity Consortium

---

## Sammendrag

Bitcoins Proof-of-Work (PoW)-konsensus gir robust sikkerhet, men bruker betydelig energi på grunn av kontinuerlig sanntids hashberegning. Vi presenterer Bitcoin-PoCX, en Bitcoin-fork som erstatter PoW med Proof of Capacity (PoC), der minere forhåndsberegner og lagrer store sett med disklagrede hasher under plotting og deretter miner ved å utføre lette oppslag i stedet for pågående hashing. Ved å flytte beregning fra miningfasen til en engangs plottingfase, reduserer Bitcoin-PoCX dramatisk energiforbruket samtidig som det muliggjør mining på standardmaskinvare, senker deltakelsesbarrieren og demper sentraliseringspresset som er iboende i ASIC-dominert PoW, alt mens Bitcoins sikkerhetsforutsetninger og økonomiske oppførsel bevares.

Vår implementasjon introduserer flere viktige innovasjoner:
(1) Et herdet plotformat som eliminerer alle kjente tid-minne-avveiningsangrep i eksisterende PoC-systemer, og sikrer at effektiv miningkraft forblir strengt proporsjonal med forpliktet lagringskapasitet;
(2) Time-Bending-algoritmen, som transformerer deadline-fordelinger fra eksponentiell til kjikvadrat, og reduserer blokktidsvarians uten å endre gjennomsnittet;
(3) En OP_RETURN-basert forging-tildelingsmekanisme som muliggjør ikke-depotmessig pool-mining; og
(4) Dynamisk komprimeringsskalering, som øker plotgenereringsvanskeligheten i tråd med halveringsplaner for å opprettholde langsiktige sikkerhetsmarginer etter hvert som maskinvare forbedres.

Bitcoin-PoCX opprettholder Bitcoin Cores arkitektur gjennom minimale, feature-flaggede modifikasjoner, og isolerer PoC-logikk fra den eksisterende konsensuskoden. Systemet bevarer Bitcoins pengepolitikk ved å sikte mot et 120-sekunders blokkintervall og justere blokksubsidien til 10 BTC. Den reduserte subsidien oppveier den femdoble økningen i blokkfrekvens, og holder den langsiktige utstedelsesraten på linje med Bitcoins opprinnelige plan og opprettholder den maksimale forsyningen på ~21 millioner.

---

## 1. Introduksjon

### 1.1 Motivasjon

Bitcoins Proof-of-Work (PoW)-konsensus har vist seg sikker i over et tiår, men til betydelig kostnad: minere må kontinuerlig bruke beregningsressurser, noe som resulterer i høyt energiforbruk. Utover effektivitetshensyn er det en bredere motivasjon: å utforske alternative konsensusmekanismer som opprettholder sikkerhet samtidig som deltakelsesbarrieren senkes. PoC gjør det mulig for praktisk talt hvem som helst med standard lagringsmaskinvare å mine effektivt, og reduserer sentraliseringspresset som sees i ASIC-dominert PoW-mining.

Proof of Capacity (PoC) oppnår dette ved å utlede miningkraft fra lagringsforpliktelse i stedet for pågående beregning. Minere forhåndsberegner store sett med disklagrede hasher - plotter - under en engangs plottingfase. Mining består deretter av lette oppslag, noe som drastisk reduserer energibruken samtidig som sikkerhetsforutsetningene for ressursbasert konsensus bevares.

### 1.2 Integrasjon med Bitcoin Core

Bitcoin-PoCX integrerer PoC-konsensus i Bitcoin Core i stedet for å opprette en ny blockchain. Denne tilnærmingen utnytter Bitcoin Cores bevisede sikkerhet, modne nettverksstabel og bredt adopterte verktøy, samtidig som modifikasjonene holdes minimale og feature-flagget. PoC-logikk er isolert fra eksisterende konsensuskode, noe som sikrer at kjernefunksjonalitet - blokkvalidering, lommebokoperasjoner, transaksjonsformater - forblir stort sett uendret.

### 1.3 Designmål

**Sikkerhet**: Behold Bitcoin-ekvivalent robusthet; angrep krever majoritetslagringskapasitet.

**Effektivitet**: Reduser pågående beregningsbelastning til disk-I/O-nivåer.

**Tilgjengelighet**: Muliggjør mining med standardmaskinvare, og senker deltakelsesbarrierene.

**Minimal integrasjon**: Introduser PoC-konsensus med minimalt modifikasjonsfotavtrykk.

---

## 2. Bakgrunn: Proof of Capacity

### 2.1 Historikk

Proof of Capacity (PoC) ble introdusert av Burstcoin i 2014 som et energieffektivt alternativ til Proof-of-Work (PoW). Burstcoin demonstrerte at miningkraft kunne utledes fra forpliktet lagring i stedet for kontinuerlig sanntids hashing: minere forhåndsberegnet store datasett («plotter») én gang og minet deretter ved å lese små, faste deler av dem.

Tidlige PoC-implementasjoner beviste at konseptet var levedyktig, men avslørte også at plotformat og kryptografisk struktur er kritisk for sikkerhet. Flere tid-minne-avveininger tillot angripere å mine effektivt med mindre lagring enn ærlige deltakere. Dette fremhevet at PoC-sikkerhet avhenger av plotdesign - ikke bare av å bruke lagring som en ressurs.

Burstcoins arv etablerte PoC som en praktisk konsensusmekanisme og ga grunnlaget som PoCX bygger på.

### 2.2 Kjernekonsepter

PoC-mining er basert på store, forhåndsberegnede plotfiler lagret på disk. Disse plottene inneholder «frosset beregning»: dyr hashing utføres én gang under plotting, og mining består deretter av lette disklesninger og enkel verifisering. Kjerneelementer inkluderer:

**Nonce:**
Den grunnleggende enheten av plotdata. Hver nonce inneholder 4096 scoops (256 KiB totalt) generert via Shabal256 fra minerens adresse og nonce-indeks.

**Scoop:**
Et 64-byte segment inne i en nonce. For hver blokk velger nettverket deterministisk en scoop-indeks (0-4095) basert på forrige blokks generasjonssignatur. Kun denne scoopen per nonce må leses.

**Generasjonssignatur:**
En 256-bits verdi utledet fra forrige blokk. Den gir entropi for scoop-valg og forhindrer minere fra å forutsi fremtidige scoop-indekser.

**Warp:**
En strukturell gruppe på 4096 nonces (1 GiB). Warps er den relevante enheten for kompresjonsresistente plotformater.

### 2.3 Miningprosess og kvalitetspipeline

PoC-mining består av et engangs plottingtrinn og en lettvekts per-blokk-rutine:

**Engangsoppsett:**
- Plotgenerering: Beregn nonces via Shabal256 og skriv dem til disk.

**Per-blokk-mining:**
- Scoop-valg: Bestem scoop-indeksen fra generasjonssignaturen.
- Plotskanning: Les den scoopen fra alle nonces i minerens plotter.

**Kvalitetspipeline:**
- Rå kvalitet: Hash hver scoop med generasjonssignaturen ved bruk av Shabal256Lite for å få en 64-bits kvalitetsverdi (lavere er bedre).
- Deadline: Konverter kvalitet til en deadline ved bruk av base target (en vanskelighetsjustert parameter som sikrer at nettverket når sitt målrettede blokkintervall): `deadline = quality / base_target`
- Bended deadline: Bruk Time-Bending-transformasjonen for å redusere varians samtidig som forventet blokktid bevares.

**Blokkforging:**
Mineren med den korteste (bended) deadline forger neste blokk når den tiden har gått.

I motsetning til PoW skjer nesten all beregning under plotting; aktiv mining er primært diskbundet og veldig lavenergi.

### 2.4 Kjente sårbarheter i tidligere systemer

**POC1-fordelingsfeil:**
Det opprinnelige Burstcoin POC1-formatet viste en strukturell skjevhet: lavindeks-scoops var betydelig billigere å reberegne i sanntid enn høyindeks-scoops. Dette introduserte en ikke-uniform tid-minne-avveining, som tillot angripere å redusere nødvendig lagring for disse scoopene og brøt antakelsen om at alle forhåndsberegnede data var like dyre.

**XOR-komprimeringsangrep (POC2):**
I POC2 kan en angriper ta et hvilket som helst sett med 8192 nonces og partisjonere dem i to blokker på 4096 nonces (A og B). I stedet for å lagre begge blokkene, lagrer angriperen bare en avledet struktur: `A XOR transpose(B)`, der transponeringen bytter scoop- og nonce-indekser - scoop S av nonce N i blokk B blir scoop N av nonce S.

Under mining, når scoop S av nonce N trengs, rekonstruerer angriperen den ved å:
1. Lese den lagrede XOR-verdien på posisjon (S, N)
2. Beregne nonce N fra blokk A for å få scoop S
3. Beregne nonce S fra blokk B for å få den transponerte scoop N
4. XOR-e alle tre verdier for å gjenopprette den opprinnelige 64-byte scoopen

Dette reduserer lagring med 50%, samtidig som det bare krever to nonce-beregninger per oppslag - en kostnad langt under terskelen som trengs for å håndheve full forhåndsberegning. Angrepet er levedyktig fordi beregning av en rad (én nonce, 4096 scoops) er billig, mens beregning av en kolonne (en enkelt scoop på tvers av 4096 nonces) ville kreve regenerering av alle nonces. Transponestrukturen eksponerer denne ubalansen.

Dette demonstrerte behovet for et plotformat som forhindrer slik strukturert rekombinasjon og fjerner den underliggende tid-minne-avveiningen. Seksjon 3.3 beskriver hvordan PoCX adresserer og løser denne svakheten.

### 2.5 Overgang til PoCX

Begrensningene i tidligere PoC-systemer gjorde det klart at sikker, rettferdig og desentralisert lagringsmining avhenger av nøye konstruerte plotstrukturer. Bitcoin-PoCX adresserer disse problemene med et herdet plotformat, forbedret deadline-fordeling og mekanismer for desentralisert pool-mining - beskrevet i neste seksjon.

---

## 3. PoCX-plotformat

### 3.1 Base nonce-konstruksjon

En nonce er en 256 KiB-datastruktur utledet deterministisk fra tre parametere: en 20-byte adressepayload, en 32-byte seed og en 64-bit nonce-indeks.

Konstruksjonen begynner med å kombinere disse inputene og hashe dem med Shabal256 for å produsere en initial hash. Denne hashen fungerer som utgangspunkt for en iterativ ekspansjonsprosess: Shabal256 anvendes gjentatte ganger, med hvert trinn avhengig av tidligere genererte data, til hele 256 KiB-bufferen er fylt. Denne kjedede prosessen representerer det beregningsmessige arbeidet utført under plotting.

Et siste diffusjonstrinn hasher den fullførte bufferen og XOR-er resultatet på tvers av alle bytes. Dette sikrer at hele bufferen er beregnet og at minere ikke kan ta snarveier i beregningen. PoC2-shuffle anvendes deretter, og bytter de nedre og øvre halvdelene av hver scoop for å garantere at alle scoops krever ekvivalent beregningsmessig innsats.

Den endelige noncen består av 4096 scoops på 64 bytes hver og danner den fundamentale enheten brukt i mining.

### 3.2 SIMD-justert plotlayout

For å maksimere gjennomstrømning på moderne maskinvare, organiserer PoCX nonce-data på disk for å legge til rette for vektorisert prosessering. I stedet for å lagre hver nonce sekvensielt, justerer PoCX tilsvarende 4-byte ord på tvers av flere påfølgende nonces sammenhengende. Dette lar en enkelt minnehenting gi data for alle SIMD-baner, minimerer cache-misser og eliminerer scatter-gather-overhead.

```
Tradisjonell layout:
Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX SIMD-layout:
Word0: [N0][N1][N2]...[N15]
Word1: [N0][N1][N2]...[N15]
Word2: [N0][N1][N2]...[N15]
```

Denne layouten gagner både CPU- og GPU-minere, og muliggjør høygjennomstrømning, parallellisert scoop-evaluering samtidig som et enkelt skalatilgangsmønster for konsensusverifisering opprettholdes. Det sikrer at mining er begrenset av lagringsbåndbredde i stedet for CPU-beregning, og opprettholder den lavenergi-naturen til Proof of Capacity.

### 3.3 Warp-struktur og XOR-transpose-koding

En warp er den fundamentale lagringsenheten i PoCX, bestående av 4096 nonces (1 GiB). Det ukomprimerte formatet, referert til som X0, inneholder base-nonces nøyaktig som produsert av konstruksjonen i seksjon 3.1.

**XOR-transpose-koding (X1)**

For å fjerne de strukturelle tid-minne-avveiningene som er til stede i tidligere PoC-systemer, utleder PoCX et herdet miningformat, X1, ved å anvende en XOR-transpose-koding på par av X0-warps.

For å konstruere scoop S av nonce N i en X1-warp:

1. Ta scoop S av nonce N fra den første X0-warpen (direkte posisjon)
2. Ta scoop N av nonce S fra den andre X0-warpen (transponert posisjon)
3. XOR de to 64-byte-verdiene for å få X1-scoopen

Transpose-trinnet bytter scoop- og nonce-indekser. I matrisetermer - der rader representerer scoops og kolonner representerer nonces - kombinerer det elementet på posisjon (S, N) i den første warpen med elementet på (N, S) i den andre.

**Hvorfor dette eliminerer komprimeringsangrepsflaten**

XOR-transpose sammenlåser hver scoop med en hel rad og en hel kolonne av de underliggende X0-dataene. Å gjenopprette en enkelt X1-scoop krever derfor tilgang til data som spenner over alle 4096 scoop-indekser. Ethvert forsøk på å beregne manglende data ville kreve regenerering av 4096 fulle nonces, i stedet for en enkelt nonce - noe som fjerner den asymmetriske kostnadsstrukturen som utnyttes av XOR-angrepet for POC2 (seksjon 2.4).

Som et resultat blir lagring av den fulle X1-warpen den eneste beregningsmessig levedyktige strategien for minere, og lukker tid-minne-avveiningen som ble utnyttet i tidligere design.

### 3.4 Disklayout

PoCX-plotfiler består av mange påfølgende X1-warps. For å maksimere operasjonell effektivitet under mining, er dataene i hver fil organisert etter scoop: all scoop 0-data fra hver warp lagres sekvensielt, etterfulgt av all scoop 1-data, og så videre, opp til scoop 4095.

Denne **scoop-sekvensielle ordningen** lar minere lese de komplette dataene som kreves for en valgt scoop i en enkelt sekvensiell disktilgang, minimerer søketider og maksimerer gjennomstrømning på standard lagringsenheter.

Kombinert med XOR-transpose-kodingen fra seksjon 3.3, sikrer denne layouten at filen er både **strukturelt herdet** og **operasjonelt effektiv**: sekvensiell scoop-ordning støtter optimal disk-I/O, mens SIMD-justerte minnelayout (se seksjon 3.2) muliggjør høygjennomstrømning, parallellisert scoop-evaluering.

### 3.5 Proof-of-Work-skalering (Xn)

PoCX implementerer skalerbar forhåndsberegning gjennom konseptet med skaleringsnivåer, betegnet Xn, for å tilpasse seg utviklende maskinvareytelse. Grunnlinjen X1-formatet representerer den første XOR-transpose-herdede warp-strukturen.

Hvert skaleringsnivå Xn øker proof-of-work innebygd i hver warp eksponentielt i forhold til X1: arbeidet som kreves på nivå Xn er 2^(n-1) ganger det for X1. Overgang fra Xn til Xn+1 er operasjonelt ekvivalent med å anvende en XOR på tvers av par av tilstøtende warps, og innebygger inkrementelt mer proof-of-work uten å endre den underliggende plotstørrelsen.

Eksisterende plotfiler opprettet på lavere skaleringsnivåer kan fortsatt brukes for mining, men de bidrar proporsjonalt mindre arbeid mot blokkgenerering, noe som reflekterer deres lavere innebygde proof-of-work. Denne mekanismen sikrer at PoCX-plotter forblir sikre, fleksible og økonomisk balanserte over tid.

### 3.6 Seed-funksjonalitet

Seed-parameteren muliggjør flere ikke-overlappende plotter per adresse uten manuell koordinering.

**Problem (POC2)**: Minere måtte manuelt spore nonce-områder på tvers av plotfiler for å unngå overlapping. Overlappende nonces sløser lagring uten å øke miningkraft.

**Løsning**: Hvert `(adresse, seed)`-par definerer et uavhengig nøkkelrom. Plotter med forskjellige seeds overlapper aldri, uavhengig av nonce-områder. Minere kan opprette plotter fritt uten koordinering.

---

## 4. Proof of Capacity-konsensus

PoCX utvider Bitcoins Nakamoto-konsensus med en lagringsbundet bevismekanisme. I stedet for å bruke energi på gjentatt hashing, forplikter minere store mengder forhåndsberegnede data - plotter - til disk. Under blokkgenerering må de lokalisere en liten, uforutsigbar del av disse dataene og transformere dem til et bevis. Mineren som gir det beste beviset innenfor det forventede tidsvinduet tjener retten til å forge neste blokk.

Dette kapittelet beskriver hvordan PoCX strukturerer blokkmetadata, utleder uforutsigbarhet og transformerer statisk lagring til en sikker konsensusmekanisme med lav varians.

### 4.1 Blokkstruktur

PoCX beholder den kjente Bitcoin-stil blokkheaderen, men introduserer tilleggsfelt for konsensus som kreves for kapasitetsbasert mining. Disse feltene binder samlet blokken til minerens lagrede plot, nettverkets vanskelighet og den kryptografiske entropien som definerer hver miningutfordring.

På et høyt nivå inneholder en PoCX-blokk: blokkhøyden, registrert eksplisitt for å forenkle kontekstuell validering; generasjonssignaturen, en kilde til fersk entropi som kobler hver blokk til sin forgjenger; base target, som representerer nettverksvanskelighet i invers form (høyere verdier tilsvarer enklere mining); PoCX-beviset, som identifiserer minerens plot, komprimeringsnivået brukt under plotting, den valgte noncen og kvaliteten utledet fra den; og en signeringsnøkkel og signatur, som beviser kontroll over kapasiteten brukt til å forge blokken (eller over en tildelt forging-nøkkel).

Beviset innebygger all konsensusrelevant informasjon som trengs av validatorer for å reberegne utfordringen, verifisere den valgte scoopen og bekrefte den resulterende kvaliteten. Ved å utvide i stedet for å redesigne blokkstrukturen, forblir PoCX konseptuelt på linje med Bitcoin samtidig som det muliggjør en fundamentalt annerledes kilde til miningarbeid.

### 4.2 Generasjonssignaturkjede

Generasjonssignaturen gir uforutsigbarheten som kreves for sikker Proof of Capacity-mining. Hver blokk utleder sin generasjonssignatur fra forrige blokks signatur og signerer, noe som sikrer at minere ikke kan forutse fremtidige utfordringer eller forhåndsberegne fordelaktige plotregioner:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

Dette produserer en sekvens av kryptografisk sterke, miner-avhengige entropiverdier. Fordi en miners offentlige nøkkel er ukjent til forrige blokk er publisert, kan ingen deltaker forutsi fremtidige scoop-valg. Dette forhindrer selektiv forhåndsberegning eller strategisk plotting og sikrer at hver blokk introduserer genuint ferskt miningarbeid.

### 4.3 Forgingprosess

Mining i PoCX består av å transformere lagrede data til et bevis drevet helt av generasjonssignaturen. Selv om prosessen er deterministisk, sikrer uforutsigbarheten til signaturen at minere ikke kan forberede seg på forhånd og må gjentatte ganger få tilgang til sine lagrede plotter.

**Utfordringutledning (scoop-valg):** Mineren hasher den gjeldende generasjonssignaturen med blokkhøyden for å få en scoop-indeks i området 0-4095. Denne indeksen bestemmer hvilket 64-byte segment av hver lagrede nonce som deltar i beviset. Fordi generasjonssignaturen avhenger av forrige blokks signerer, blir scoop-valget kjent først i øyeblikket for blokkpublisering.

**Bevisevaluering (kvalitetsberegning):** For hver nonce i et plot henter mineren den valgte scoopen og hasher den sammen med generasjonssignaturen for å få en kvalitet - en 64-bits verdi hvis størrelse bestemmer minerens konkurranseevne. Lavere kvalitet tilsvarer et bedre bevis.

**Deadline-dannelse (Time Bending):** Den rå deadline er proporsjonal med kvaliteten og omvendt proporsjonal med base target. I eldre PoC-design fulgte disse deadlines en sterkt skjev eksponentialfordeling, som produserte lange haleforsinkelser som ikke ga noen ekstra sikkerhet. PoCX transformerer den rå deadline ved bruk av Time Bending (seksjon 4.4), reduserer varians og sikrer forutsigbare blokkintervaller. Når den bended deadline utløper, forger mineren en blokk ved å innebygge beviset og signere det med den effektive forging-nøkkelen.

### 4.4 Time Bending

Proof of Capacity produserer eksponentielt fordelte deadlines. Etter en kort periode - typisk noen titalls sekunder - har hver miner allerede identifisert sitt beste bevis, og all ekstra ventetid bidrar bare latens, ikke sikkerhet.

Time Bending omformer fordelingen ved å anvende en kubikkrot-transformasjon:

`deadline_bended = scale × (quality / base_target)^(1/3)`

Skalafaktoren bevarer forventet blokktid (120 sekunder) samtidig som variansen reduseres dramatisk. Korte deadlines utvides, noe som forbedrer blokkpropagering og nettverkssikkerhet. Lange deadlines komprimeres, noe som forhindrer outliers fra å forsinke kjeden.

![Blokktidsfordelinger](blocktime_distributions.svg)

Time Bending opprettholder informasjonsinnholdet i det underliggende beviset. Det endrer ikke konkurranseevnen blant minere; det omfordeler bare ventetid for å produsere jevnere, mer forutsigbare blokkintervaller. Implementasjonen bruker fastpunktaritmetikk (Q42-format) og 256-bits heltall for å sikre deterministiske resultater på tvers av alle plattformer.

### 4.5 Vanskelighetsjustering

PoCX regulerer blokkproduksjon ved bruk av base target, et inversvanskelighetsmål. Den forventede blokktiden er proporsjonal med forholdet `quality / base_target`, så økning av base target akselererer blokkoppretting mens reduksjon bremser kjeden.

Vanskeligheten justeres hver blokk ved bruk av den målte tiden mellom nylige blokker sammenlignet med målintervallet. Denne hyppige justeringen er nødvendig fordi lagringskapasitet kan legges til eller fjernes raskt - i motsetning til Bitcoins hashkraft, som endrer seg saktere.

Justeringen følger to veiledende begrensninger: **Gradualitet** - per-blokk-endringer er begrenset (±20% maksimum) for å unngå oscillasjoner eller manipulasjon; **Herding** - base target kan ikke overstige sin genesis-verdi, noe som forhindrer nettverket fra noensinne å senke vanskeligheten under de opprinnelige sikkerhetsforutsetningene.

### 4.6 Blokkgyldighet

En blokk i PoCX er gyldig når den presenterer et verifiserbart lagringsavledet bevis som er konsistent med konsenustilstanden. Validatorer reberegner uavhengig scoop-valget, utleder den forventede kvaliteten fra den innsendte noncen og plotmetadataene, anvender Time Bending-transformasjonen og bekrefter at mineren var berettiget til å forge blokken på den deklarerte tiden.

Spesifikt krever en gyldig blokk: deadline har utløpt siden foreldreblokken; den innsendte kvaliteten samsvarer med den beregnede kvaliteten for beviset; skaleringsnivået møter nettverksminimum; generasjonssignaturen samsvarer med forventet verdi; base target samsvarer med forventet verdi; blokksignaturen kommer fra den effektive signereren; og coinbase betaler til den effektive signererens adresse.

---

## 5. Forging-tildelinger

### 5.1 Motivasjon

Forging-tildelinger lar ploteiere delegere blokkforging-myndighet uten noensinne å gi fra seg eierskap til sine plotter. Denne mekanismen muliggjør pool-mining og kaldlagringsoppsett samtidig som sikkerhetsgarantiene til PoCX bevares.

I pool-mining kan ploteiere autorisere en pool til å forge blokker på deres vegne. Poolen sammenstiller blokker og distribuerer belønninger, men den får aldri depot over selve plottene. Delegering kan reverseres når som helst, og ploteiere er frie til å forlate en pool eller endre konfigurasjoner uten å plotte på nytt.

Tildelinger støtter også en ren separasjon mellom kalde og varme nøkler. Den private nøkkelen som kontrollerer plottet kan forbli offline, mens en separat forging-nøkkel - lagret på en online maskin - produserer blokker. Et kompromiss av forging-nøkkelen kompromitterer derfor bare forging-myndighet, ikke eierskap. Plottet forblir trygt og tildelingen kan oppheves, og lukker sikkerhetsgapet umiddelbart.

Forging-tildelinger gir dermed operasjonell fleksibilitet samtidig som prinsippet opprettholdes om at kontroll over lagret kapasitet aldri må overføres til mellommenn.

### 5.2 Tildelingsprotokoll

Tildelinger deklareres gjennom OP_RETURN-transaksjoner for å unngå unødvendig vekst av UTXO-settet. En tildelingstransaksjon spesifiserer plotadressen og forging-adressen som er autorisert til å produsere blokker ved bruk av det plottets kapasitet. En opphevingstransaksjon inneholder kun plotadressen. I begge tilfeller beviser ploteieren kontroll ved å signere forbruksinputen til transaksjonen.

Hver tildeling går gjennom en sekvens av veldefinerte tilstander (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Etter at en tildelingstransaksjon bekreftes, går systemet inn i en kort aktiveringsfase. Denne forsinkelsen - 30 blokker, omtrent én time - sikrer stabilitet under blokkras og forhindrer motstanderes raske bytte av forging-identiteter. Når denne aktiveringsperioden utløper, blir tildelingen aktiv og forblir slik til ploteieren utsteder en oppheving.

Opphevinger går over i en lengre forsinkelsesperiode på 720 blokker, omtrent én dag. I løpet av denne tiden forblir den tidligere forging-adressen aktiv. Denne lengre forsinkelsen gir operasjonell stabilitet for pools, forhindrer strategisk «tildelingshopping» og gir infrastrukturleverandører nok sikkerhet til å operere effektivt. Etter at opphevingsforsinkelsen utløper, fullføres opphevingen, og ploteieren er fri til å utpeke en ny forging-nøkkel.

Tildelingstilstanden opprettholdes i en konsensuslagstruktur parallelt med UTXO-settet og støtter undo-data for sikker håndtering av kjede-reorganiseringer.

### 5.3 Valideringsregler

For hver blokk bestemmer validatorer den effektive signereren - adressen som må signere blokken og motta coinbase-belønningen. Denne signereren avhenger utelukkende av tildelingstilstanden ved blokkens høyde.

Hvis ingen tildeling eksisterer eller tildelingen ikke har fullført sin aktiveringsfase, forblir ploteieren den effektive signereren. Når en tildeling blir aktiv, må den tildelte forging-adressen signere. Under oppheving fortsetter forging-adressen å signere til opphevingsforsinkelsen utløper. Først da returnerer myndigheten til ploteieren.

Validatorer håndhever at blokksignaturen er produsert av den effektive signereren, at coinbase betaler til samme adresse, og at alle overganger følger de foreskrevne aktiverings- og opphevingsforsinkelsene. Kun ploteieren kan opprette eller oppheve tildelinger; forging-nøkler kan ikke modifisere eller utvide sine egne tillatelser.

Forging-tildelinger introduserer derfor fleksibel delegering uten å introdusere tillit. Eierskap av den underliggende kapasiteten forblir alltid kryptografisk forankret til ploteieren, mens forging-myndighet kan delegeres, roteres eller oppheves etter hvert som operasjonelle behov utvikler seg.

---

## 6. Dynamisk skalering

Etter hvert som maskinvare utvikler seg, reduseres kostnaden for å beregne plotter relativt til å lese forhåndsberegnet arbeid fra disk. Uten mottiltak kunne angripere til slutt generere bevis i sanntid raskere enn minere som leser lagret arbeid, noe som ville undergrave sikkerhetsmodellen til Proof of Capacity.

For å bevare den tiltenkte sikkerhetsmarginen, implementerer PoCX en skaleringsplan: det minimum påkrevde skaleringsnivået for plotter øker over tid. Hvert skaleringsnivå Xn, som beskrevet i seksjon 3.5, innebygger eksponentielt mer proof-of-work i plotstrukturen, og sikrer at minere fortsetter å forplikte betydelige lagringsressurser selv når beregning blir billigere.

Planen er på linje med nettverkets økonomiske insentiver, spesielt blokkbelønningshalveringer. Etter hvert som belønningen per blokk reduseres, øker minimumsnivået gradvis, og bevarer balansen mellom plottinginnsats og miningpotensial:

| Periode | År | Halveringer | Min skalering | Plotarbeidsmultiplikator |
|---------|-----|-------------|---------------|-------------------------|
| Epoke 0 | 0-4 | 0 | X1 | 2× grunnlinje |
| Epoke 1 | 4-12 | 1-2 | X2 | 4× grunnlinje |
| Epoke 2 | 12-28 | 3-6 | X3 | 8× grunnlinje |
| Epoke 3 | 28-60 | 7-14 | X4 | 16× grunnlinje |
| Epoke 4 | 60-124 | 15-30 | X5 | 32× grunnlinje |
| Epoke 5 | 124+ | 31+ | X6 | 64× grunnlinje |

Minere kan valgfritt forberede plotter som overstiger gjeldende minimum med ett nivå, noe som lar dem planlegge fremover og unngå umiddelbare oppgraderinger når nettverket går over til neste epoke. Dette valgfrie trinnet gir ingen ekstra fordel når det gjelder blokkssannsynlighet - det tillater bare en jevnere operasjonell overgang.

Blokker som inneholder bevis under minimum skaleringsnivå for deres høyde anses som ugyldige. Validatorer sjekker det deklarerte skaleringsnivået i beviset mot gjeldende nettverkskrav under konsensusvalidering, og sikrer at alle deltakende minere møter de utviklende sikkerhetsforventningene.

---

## 7. Mining-arkitektur

PoCX separerer konsensuskritiske operasjoner fra de ressursintensive oppgavene med mining, og muliggjør både sikkerhet og effektivitet. Noden opprettholder blockchain, validerer blokker, administrerer mempool og eksponerer et RPC-grensesnitt. Eksterne minere håndterer plotlagring, scoop-lesing, kvalitetsberegning og deadline-administrasjon. Denne separasjonen holder konsensuslogikk enkel og reviderbar samtidig som minere kan optimalisere for diskgjennomstrømning.

### 7.1 Mining RPC-grensesnitt

Minere interagerer med noden gjennom et minimalt sett med RPC-kall. get_mining_info RPC gir gjeldende blokkhøyde, generasjonssignatur, base target, måldeadline og det akseptable området for plotskaleringsnivåer. Ved bruk av denne informasjonen beregner minere kandidatnonces. submit_nonce RPC lar minere sende inn en foreslått løsning, inkludert plotidentifikator, nonce-indeks, skaleringsnivå og minerkonto. Noden evaluerer innsendingen og svarer med den beregnede deadline hvis beviset er gyldig.

### 7.2 Forging-planlegger

Noden opprettholder en forging-planlegger, som sporer innkommende innsendinger og beholder kun den beste løsningen for hver blokkhøyde. Innsendte nonces køes med innebygde beskyttelser mot innsendingsflom eller denial-of-service-angrep. Planleggeren venter til den beregnede deadline utløper eller en bedre løsning ankommer, på hvilket punkt den sammenstiller en blokk, signerer den ved bruk av den effektive forging-nøkkelen og publiserer den til nettverket.

### 7.3 Defensiv forging

For å forhindre timingangrep eller insentiver for klokkemanipulasjon, implementerer PoCX defensiv forging. Hvis en konkurrerende blokk ankommer for samme høyde, sammenligner planleggeren den lokale løsningen med den nye blokken. Hvis den lokale kvaliteten er bedre, forger noden umiddelbart i stedet for å vente på den opprinnelige deadline. Dette sikrer at minere ikke kan oppnå en fordel bare ved å justere lokale klokker; den beste løsningen vinner alltid, og bevarer rettferdighet og nettverkssikkerhet.

---

## 8. Sikkerhetsanalyse

### 8.1 Trusselmodell

PoCX modellerer motstandere med betydelige, men begrensede kapabiliteter. Angripere kan forsøke å overbelaste nettverket med ugyldige transaksjoner, misdannede blokker eller fabrikkerte bevis for å stresse valideringsbaner. De kan fritt manipulere sine lokale klokker og kan prøve å utnytte grensetilfeller i konsensusoppførsel som tidsstempelhåndtering, vanskelighetsjusteringsdynamikk eller reorganiseringsregler. Motstandere forventes også å lete etter muligheter til å omskrive historikk gjennom målrettede kjedegafler.

Modellen antar at ingen enkelt part kontrollerer et flertall av total nettverkslagringskapasitet. Som med enhver ressursbasert konsensusmekanisme, kan en 51%-kapasitetsangriper unilateralt reorganisere kjeden; denne fundamentale begrensningen er ikke spesifikk for PoCX. PoCX antar også at angripere ikke kan beregne plotdata raskere enn ærlige minere kan lese det fra disk. Skaleringsplanen (seksjon 6) sikrer at det beregningsmessige gapet som kreves for sikkerhet vokser over tid etter hvert som maskinvare forbedres.

Seksjonene som følger undersøker hver større angrepsklasse i detalj og beskriver mottiltakene innebygd i PoCX.

### 8.2 Kapasitetsangrep

Som PoW, kan en angriper med majoritetskapasitet omskrive historikk (et 51%-angrep). Å oppnå dette krever anskaffelse av et fysisk lagringsfotavtrykk større enn det ærlige nettverket - en dyr og logistisk krevende foretagende. Når maskinvaren er anskaffet, er driftskostnadene lave, men den initiale investeringen skaper et sterkt økonomisk insentiv til å oppføre seg ærlig: å undergrave kjeden ville skade verdien av angriperens egen aktivabase.

PoC unngår også nothing-at-stake-problemet assosiert med PoS. Selv om minere kan skanne plotter mot flere konkurrerende gafler, bruker hver skanning reell tid - typisk i størrelsesorden titalls sekunder per kjede. Med et 120-sekunders blokkintervall begrenser dette iboende flergrenet mining, og forsøk på å mine mange gafler samtidig degraderer ytelsen på alle. Gaffel-mining er derfor ikke kostnadsfritt; det er fundamentalt begrenset av I/O-gjennomstrømning.

Selv om fremtidig maskinvare tillot nær-øyeblikkelig plotskanning (f.eks. høyhastighets SSD-er), ville en angriper fortsatt møte et betydelig fysisk ressurskrav for å kontrollere et flertall av nettverkskapasitet, noe som gjør et 51%-stil angrep dyrt og logistisk utfordrende.

Til slutt er kapasitetsangrep langt vanskeligere å leie enn hashkraftangrep. GPU-beregning kan anskaffes på forespørsel og omdirigeres til enhver PoW-kjede umiddelbart. I kontrast krever PoC fysisk maskinvare, tidkrevende plotting og pågående I/O-operasjoner. Disse begrensningene gjør kortsiktige, opportunistiske angrep langt mindre gjennomførbare.

### 8.3 Timingangrep

Timing spiller en mer kritisk rolle i Proof of Capacity enn i Proof of Work. I PoW påvirker tidsstempler primært vanskelighetsjustering; i PoC bestemmer de om en miners deadline har utløpt og dermed om en blokk er berettiget til forging. Deadlines måles relativt til foreldreblokkens tidsstempel, men en nodes lokale klokke brukes til å bedømme om en innkommende blokk ligger for langt i fremtiden. Av denne grunn håndhever PoCX en stram tidsstempeltoleranse: blokker kan ikke avvike mer enn 15 sekunder fra nodens lokale klokke (sammenlignet med Bitcoins 2-timers vindu). Denne grensen fungerer i begge retninger - blokker for langt i fremtiden avvises, og noder med trege klokker kan feilaktig avvise gyldige innkommende blokker.

Noder bør derfor synkronisere sine klokker ved bruk av NTP eller en tilsvarende tidskilde. PoCX unngår bevisst å stole på nettverksinterne tidskilder for å forhindre at angripere manipulerer oppfattet nettverkstid. Noder overvåker sitt eget avvik og sender advarsler hvis den lokale klokken begynner å avvike fra nylige blokktidsstempler.

Klokkeakselerasjon - å kjøre en rask lokal klokke for å forge litt tidligere - gir bare marginal fordel. Innenfor den tillatte toleransen sikrer defensiv forging (seksjon 7.3) at en miner med en bedre løsning umiddelbart vil publisere ved å se en dårligere tidlig blokk. En rask klokke hjelper bare en miner å publisere en allerede-vinnende løsning noen få sekunder tidligere; den kan ikke konvertere et dårligere bevis til et vinnende.

Forsøk på å manipulere vanskelighet via tidsstempler er begrenset av en ±20% per-blokk justeringsgrense og et 24-blokks rullende vindu, som forhindrer minere fra å meningsfullt påvirke vanskelighet gjennom kortsiktige timingspill.

### 8.4 Tid-minne-avveiningsangrep

Tid-minne-avveininger forsøker å redusere lagringskrav ved å reberegne deler av plottet på forespørsel. Tidligere Proof of Capacity-systemer var sårbare for slike angrep, mest bemerkelsesverdig POC1 scoop-ubalansefeil og POC2 XOR-transpose-komprimeringsangrep (seksjon 2.4). Begge utnyttet asymmetrier i hvor dyrt det var å regenerere visse deler av plotdata, noe som tillot motstandere å kutte lagring mens de bare betalte en liten beregningsmessig straff. Alternative plotformater til PoC2 lider også av lignende TMTO-svakheter; et fremtredende eksempel er Chia, hvis plotformat kan reduseres vilkårlig med en faktor større enn 4.

PoCX fjerner disse angrepsoverflatene helt gjennom sin nonce-konstruksjon og warp-format. Innenfor hver nonce hasher det siste diffusjonstrinnet den fullstendig beregnede bufferen og XOR-er resultatet på tvers av alle bytes, noe som sikrer at hver del av bufferen avhenger av hver annen del og ikke kan snarveies. Etterpå bytter PoC2-shuffle de nedre og øvre halvdelene av hver scoop, og utjevner den beregningsmessige kostnaden for å gjenopprette enhver scoop.

PoCX eliminerer videre POC2 XOR-transpose-komprimeringsangrepet ved å utlede sitt herdede X1-format, der hver scoop er XOR av en direkte og en transponert posisjon på tvers av parede warps; dette sammenlåser hver scoop med en hel rad og en hel kolonne av underliggende X0-data, noe som gjør rekonstruksjon avhengig av tusenvis av fulle nonces og dermed fjerner den asymmetriske tid-minne-avveiningen helt.

Som et resultat er lagring av det fulle plottet den eneste beregningsmessig levedyktige strategien for minere. Ingen kjent snarvei - enten delvis plotting, selektiv regenerering, strukturert komprimering eller hybride beregning-lagring-tilnærminger - gir en meningsfull fordel. PoCX sikrer at mining forblir strengt lagringsbundet og at kapasitet reflekterer reell, fysisk forpliktelse.

### 8.5 Tildelingsangrep

PoCX bruker en deterministisk tilstandsmaskin for å styre alle plot-til-forger-tildelinger. Hver tildeling går gjennom veldefinerte tilstander - UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED - med håndhevede aktiverings- og opphevingsforsinkelser. Dette sikrer at en miner ikke kan øyeblikkelig endre tildelinger for å jukse systemet eller raskt bytte forging-myndighet.

Fordi alle overganger krever kryptografiske bevis - spesifikt signaturer fra ploteieren som er verifiserbare mot input-UTXO - kan nettverket stole på legitimiteten til hver tildeling. Forsøk på å omgå tilstandsmaskinen eller forfalske tildelinger avvises automatisk under konsensusvalidering. Replay-angrep forhindres likeledes av standard Bitcoin-stil transaksjonsreplay-beskyttelser, noe som sikrer at hver tildelingshandling er unikt knyttet til en gyldig, ubrukt input.

Kombinasjonen av tilstandsmaskin-styring, håndhevede forsinkelser og kryptografisk bevis gjør tildelingsbasert juks praktisk talt umulig: minere kan ikke kapre tildelinger, utføre rask omtildeling under blokkras eller omgå opphevingsplaner.

### 8.6 Signatursikkerhet

Blokksignaturer i PoCX fungerer som en kritisk kobling mellom et bevis og den effektive forging-nøkkelen, og sikrer at kun autoriserte minere kan produsere gyldige blokker.

For å forhindre formbarhetsangrep, ekskluderes signaturer fra blokkhash-beregningen. Dette eliminerer risikoen for formbare signaturer som kunne undergrave validering eller tillate blokkutskiftningsangrep.

For å avbøte denial-of-service-vektorer, er signatur- og offentlig nøkkel-størrelser faste - 65 bytes for kompakte signaturer og 33 bytes for komprimerte offentlige nøkler - noe som forhindrer angripere fra å blåse opp blokker for å utløse ressursutmattelse eller bremse nettverkspropagering.

---

## 9. Implementasjon

PoCX er implementert som en modulær utvidelse til Bitcoin Core, med all relevant kode inneholdt i sin egen dedikerte underkatalog og aktivert gjennom et feature-flagg. Dette designet bevarer integriteten til den opprinnelige koden, og lar PoCX aktiveres eller deaktiveres rent, noe som forenkler testing, revisjon og synkronisering med oppstrømsendringer.

Integrasjonen berører kun de essensielle punktene som er nødvendige for å støtte Proof of Capacity. Blokkheaderen er utvidet til å inkludere PoCX-spesifikke felt, og konsensusvalidering er tilpasset for å behandle lagringsbaserte bevis sammen med tradisjonelle Bitcoin-sjekker. Forging-systemet, ansvarlig for å administrere deadlines, planlegging og miner-innsendinger, er fullstendig inneholdt i PoCX-modulene, mens RPC-utvidelser eksponerer mining- og tildelingsfunksjonalitet til eksterne klienter. For brukere er lommebokgrensesnittet forbedret for å administrere tildelinger gjennom OP_RETURN-transaksjoner, noe som muliggjør sømløs interaksjon med de nye konsensusfunksjonene.

Alle konsensuskritiske operasjoner er implementert i deterministisk C++ uten eksterne avhengigheter, noe som sikrer kryssplattform-konsistens. Shabal256 brukes for hashing, mens Time Bending og kvalitetsberegning er avhengige av fastpunktaritmetikk og 256-bits operasjoner. Kryptografiske operasjoner som signaturverifisering utnytter Bitcoin Cores eksisterende secp256k1-bibliotek.

Ved å isolere PoCX-funksjonalitet på denne måten, forblir implementasjonen reviderbar, vedlikeholdbar og fullt kompatibel med pågående Bitcoin Core-utvikling, og demonstrerer at en fundamentalt ny lagringsbundet konsensusmekanisme kan sameksistere med en moden proof-of-work-kodebase uten å forstyrre dens integritet eller brukervennlighet.

---

## 10. Nettverksparametere

PoCX bygger på Bitcoins nettverksinfrastruktur og gjenbruker dens kjedeparameterrammeverk. For å støtte kapasitetsbasert mining, blokkintervaller, tildelingshåndtering og plotskalering, er flere parametere utvidet eller overstyrt. Dette inkluderer blokktidsmål, initial subsidie, halveringsplan, tildelingsaktiverings- og opphevingsforsinkelser, samt nettverksidentifikatorer som magic bytes, porter og Bech32-prefikser. Testnett- og regtest-miljøer justerer videre disse parameterne for å muliggjøre rask iterasjon og lavkapasitetstesting.

Tabellene nedenfor oppsummerer de resulterende mainnet-, testnett- og regtest-innstillingene, og fremhever hvordan PoCX tilpasser Bitcoins kjerneparametere til en lagringsbundet konsensusmodell.

### 10.1 Mainnet

| Parameter | Verdi |
|-----------|-------|
| Magic bytes | `0xa7 0x3c 0x91 0x5e` |
| Standardport | 8888 |
| Bech32 HRP | `pocx` |
| Blokktidsmål | 120 sekunder |
| Initial subsidie | 10 BTC |
| Halveringsintervall | 1050000 blokker (~4 år) |
| Total forsyning | ~21 millioner BTC |
| Tildelingsaktivering | 30 blokker |
| Tildelingsoppheving | 720 blokker |
| Rullende vindu | 24 blokker |

### 10.2 Testnett

| Parameter | Verdi |
|-----------|-------|
| Magic bytes | `0x6d 0xf2 0x48 0xb3` |
| Standardport | 18888 |
| Bech32 HRP | `tpocx` |
| Blokktidsmål | 120 sekunder |
| Andre parametere | Samme som mainnet |

### 10.3 Regtest

| Parameter | Verdi |
|-----------|-------|
| Magic bytes | `0xfa 0xbf 0xb5 0xda` |
| Standardport | 18444 |
| Bech32 HRP | `rpocx` |
| Blokktidsmål | 1 sekund |
| Halveringsintervall | 500 blokker |
| Tildelingsaktivering | 4 blokker |
| Tildelingsoppheving | 8 blokker |
| Lavkapasitetsmodus | Aktivert (~4 MB plotter) |

---

## 11. Relatert arbeid

Gjennom årene har flere blockchain- og konsensusprosjekter utforsket lagringsbaserte eller hybride miningmodeller. PoCX bygger på denne linjen samtidig som det introduserer forbedringer innen sikkerhet, effektivitet og kompatibilitet.

**Burstcoin / Signum.** Burstcoin introduserte det første praktiske Proof-of-Capacity (PoC)-systemet i 2014, og definerte kjernekonsepter som plotter, nonces, scoops og deadline-basert mining. Dets etterfølgere, spesielt Signum (tidligere Burstcoin), utvidet økosystemet og utviklet seg til slutt til det som er kjent som Proof-of-Commitment (PoC+), som kombinerer lagringsforpliktelse med valgfri staking for å påvirke effektiv kapasitet. PoCX arver det lagringsbaserte mininggrunnlaget fra disse prosjektene, men avviker betydelig gjennom et herdet plotformat (XOR-transpose-koding), dynamisk plot-arbeidsskalering, deadline-utjevning («Time Bending») og et fleksibelt tildelingssystem - alt mens det forankres i Bitcoin Core-kodebasen i stedet for å opprettholde en frittstående nettverksgaffel.

**Chia.** Chia implementerer Proof of Space and Time, som kombinerer diskbaserte lagringsbevis med en tidskomponent håndhevet via Verifiable Delay Functions (VDFs). Dets design adresserer visse bekymringer om bevisgjenbruk og fersk utfordringsgenerering, distinkt fra klassisk PoC. PoCX adopterer ikke den tidsforankrede bevismodellen; i stedet opprettholder det en lagringsbundet konsensus med forutsigbare intervaller, optimalisert for langsiktig kompatibilitet med UTXO-økonomi og Bitcoin-avledede verktøy.

**Spacemesh.** Spacemesh foreslår et Proof-of-Space-Time (PoST)-skjema som bruker en DAG-basert (mesh) nettverkstopologi. I denne modellen må deltakere periodisk bevise at allokert lagring forblir intakt over tid, i stedet for å stole på et enkelt forhåndsberegnet datasett. PoCX, i kontrast, verifiserer lagringsforpliktelse kun ved blokktidspunkt - med herdede plotformater og rigorøs bevisvalidering - og unngår overhead fra kontinuerlige lagringsbevis samtidig som effektivitet og desentralisering bevares.

---

## 12. Konklusjon

Bitcoin-PoCX demonstrerer at energieffektiv konsensus kan integreres i Bitcoin Core samtidig som sikkerhetsegenskap og økonomisk modell bevares. Viktige bidrag inkluderer XOR-transpose-koding (tvinger angripere til å beregne 4096 nonces per oppslag, eliminerer komprimeringsangrepet), Time Bending-algoritmen (fordelingstransformasjon reduserer blokktidsvarians), forging-tildelingssystemet (OP_RETURN-basert delegering muliggjør ikke-depotmessig pool-mining), dynamisk skalering (på linje med halveringer for å opprettholde sikkerhetsmarginer), og minimal integrasjon (feature-flagget kode isolert i en dedikert katalog).

Systemet er for øyeblikket i testnett-fase. Miningkraft utledes fra lagringskapasitet i stedet for hashrate, noe som reduserer energiforbruk med størrelsesordener samtidig som Bitcoins bevisede økonomiske modell opprettholdes.

---

## Referanser

Bitcoin Core. *Bitcoin Core Repository.* https://github.com/bitcoin/bitcoin

Burstcoin. *Proof of Capacity Technical Documentation.* 2014.

NIST. *SHA-3 Competition: Shabal.* 2008.

Cohen, B., Pietrzak, K. *The Chia Network Blockchain.* 2019.

Spacemesh. *Spacemesh Protocol Documentation.* 2021.

PoC Consortium. *PoCX Framework.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Bitcoin-PoCX Integration.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Lisens**: MIT
**Organisasjon**: Proof of Capacity Consortium
**Status**: Testnett-fase
