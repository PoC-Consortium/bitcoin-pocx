# Bitcoin-PoCX: Energieffektiv konsensus for Bitcoin Core

**Version**: 2.0 Udkast
**Dato**: December 2025
**Organisation**: Proof of Capacity Consortium

---

## Abstrakt

Bitcoins Proof-of-Work (PoW)-konsensus giver robust sikkerhed, men forbruger betydelig energi pa grund af kontinuerlig realtids-hashberegning. Vi praesenterer Bitcoin-PoCX, en Bitcoin-fork, der erstatter PoW med Proof of Capacity (PoC), hvor minere forberegner og gemmer store saet af disklagrede hashes under plotting og efterfolgende miner ved at udføre letvaegts-opslag i stedet for igangvaerende hashing. Ved at flytte beregning fra miningfasen til en engangspottingfase reducerer Bitcoin-PoCX drastisk energiforbruget, mens det muliggor mining pa standardhardware, saenker adgangsbarrieren og mindsker centraliseringspresset, der er iboende i ASIC-domineret PoW, alt imens Bitcoins sikkerhedsantagelser og okonomiske adfaerd bevares.

Vores implementering introducerer flere nogleinnovationer:
(1) Et haerdet plotformat, der eliminerer alle kendte tid-hukommelse-afvejningsangreb i eksisterende PoC-systemer, hvilket sikrer, at effektiv miningkraft forbliver strengt proportional med engageret lagerkapacitet;
(2) Time-Bending-algoritmen, der transformerer deadline-fordelinger fra eksponentiel til chi-kvadrat, reducerer bloktidsvarians uden at aendre gennemsnittet;
(3) En OP_RETURN-baseret forging-assignment-mekanisme, der muliggor ikke-custodial pool-mining; og
(4) Dynamisk kompressionsskalering, der oger plotgenereringssvaerhedsgrad i overensstemmelse med halveringsplaner for at opretholde langsigtede sikkerhedsmarginer, efterhanden som hardware forbedres.

Bitcoin-PoCX opretholder Bitcoin Cores arkitektur gennem minimale, feature-flaggede modifikationer, der isolerer PoC-logik fra den eksisterende konsensuskode. Systemet bevarer Bitcoins pengepolitik ved at sigte mod et 120-sekunders blokinterval og justere bloksubsidien til 10 BTC. Den reducerede subsidie opvejer den femdobbelte forogelse i blokfrekvens og holder den langsigtede udstedelsesrate i overensstemmelse med Bitcoins oprindelige plan og opretholder den maksimale forsyning pa ~21 millioner.

---

## 1. Introduktion

### 1.1 Motivation

Bitcoins Proof-of-Work (PoW)-konsensus har vist sig sikker i mere end et arti, men til betydelige omkostninger: minere skal kontinuerligt forbruge beregningsressourcer, hvilket resulterer i hojt energiforbrug. Ud over effektivitetsbekymringer er der en bredere motivation: at udforske alternative konsensusmekanismer, der opretholder sikkerhed, mens de saenker adgangsbarrieren. PoC muliggor, at praktisk talt alle med standardlagringshardware kan mine effektivt, hvilket reducerer det centraliseringspres, der ses i ASIC-domineret PoW-mining.

Proof of Capacity (PoC) opnar dette ved at udlede miningkraft fra lagerforpligtelse i stedet for igangvaerende beregning. Minere forberegner store saet af disklagrede hashes - plots - under en engangspottingfase. Mining bestar derefter af letvaegts-opslag, hvilket drastisk reducerer energiforbrug, mens sikkerhedsantagelserne for ressourcebaseret konsensus bevares.

### 1.2 Integration med Bitcoin Core

Bitcoin-PoCX integrerer PoC-konsensus i Bitcoin Core i stedet for at skabe en ny blockchain. Denne tilgang udnytter Bitcoin Cores beviste sikkerhed, modne netvaerksstack og bredt adopterede vaerktojer, mens modifikationer holdes minimale og feature-flaggede. PoC-logik er isoleret fra eksisterende konsensuskode, hvilket sikrer, at kernefunktionalitet - blokvalidering, wallet-operationer, transaktionsformater - forbliver stort set uaendret.

### 1.3 Designmal

**Sikkerhed**: Bevar Bitcoin-aequivalent robusthed; angreb kraever flertalskapacitet.

**Effektivitet**: Reducer igangvaerende beregningsbelastning til disk-I/O-niveauer.

**Tilgaengelighed**: Muliggor mining med standardhardware, saenker adgangsbarrierer.

**Minimal integration**: Introducer PoC-konsensus med minimalt modifikationsaftryk.

---

## 2. Baggrund: Proof of Capacity

### 2.1 Historie

Proof of Capacity (PoC) blev introduceret af Burstcoin i 2014 som et energieffektivt alternativ til Proof-of-Work (PoW). Burstcoin demonstrerede, at miningkraft kunne udledes fra engageret lager i stedet for kontinuerlig realtids-hashing: minere forberegnede store datasaet ("plots") en gang og minede derefter ved at laese sma, faste dele af dem.

Tidlige PoC-implementeringer beviste, at konceptet var levedygtigt, men afslorede ogsa, at plotformat og kryptografisk struktur er kritiske for sikkerhed. Flere tid-hukommelse-afvejninger tillod angribere at mine effektivt med mindre lager end aerlige deltagere. Dette fremhaevede, at PoC-sikkerhed afhaenger af plotdesign - ikke blot af at bruge lager som en ressource.

Burstcoins arv etablerede PoC som en praktisk konsensusmekanisme og gav det fundament, som PoCX bygger pa.

### 2.2 Kernebegreber

PoC-mining er baseret pa store, forberegnede plotfiler gemt pa disk. Disse plots indeholder "frosset beregning": dyr hashing udfores en gang under plotting, og mining bestar derefter af letvaegts-disklaesninger og simpel verifikation. Kerneelementer inkluderer:

**Nonce:**
Den grundlaeggende enhed af plotdata. Hver nonce indeholder 4096 scoops (256 KiB i alt) genereret via Shabal256 fra minerens adresse og nonceindeks.

**Scoop:**
Et 64-byte segment inde i en nonce. For hver blok vaelger netvaerket deterministisk et scoopindeks (0-4095) baseret pa den forrige bloks generationssignatur. Kun denne scoop pr. nonce skal laeses.

**Generationssignatur:**
En 256-bit vaerdi afledt fra den forrige blok. Den giver entropi til scoopvalg og forebygger, at minere kan forudsige fremtidige scoopindekser.

**Warp:**
En strukturel gruppe af 4096 nonces (1 GiB). Warps er den relevante enhed for kompressionsresistente plotformater.

### 2.3 Miningproces og kvalitetspipeline

PoC-mining bestar af et engangspottingtrin og en letvaegts pr.-blok-rutine:

**Engangsopsaetning:**
- Plotgenerering: Beregn nonces via Shabal256 og skriv dem til disk.

**Pr.-blok mining:**
- Scoopvalg: Bestem scoopindekset fra generationssignaturen.
- Plotscanning: Laes den scoop fra alle nonces i minerens plots.

**Kvalitetspipeline:**
- Ra kvalitet: Hash hver scoop med generationssignaturen ved hjaelp af Shabal256Lite for at fa en 64-bit kvalitetsvaerdi (lavere er bedre).
- Deadline: Konverter kvalitet til en deadline ved hjaelp af base target (en svaerhedsjusteret parameter, der sikrer, at netvaerket nar sit malbloktidsinterval): `deadline = quality / base_target`
- Bendet deadline: Anvend Time-Bending-transformationen for at reducere varians, mens forventet bloktid bevares.

**Blokforging:**
Mineren med den korteste (bendede) deadline forger den naeste blok, nar den tid er forlobet.

I modsaetning til PoW sker naesten al beregning under plotting; aktiv mining er primaert diskbundet og meget lavenergi.

### 2.4 Kendte sarbarheder i tidligere systemer

**POC1-fordelingsfejl:**
Det originale Burstcoin POC1-format udviste en strukturel skavhed: lavindeks-scoops var betydeligt billigere at genberegne on-the-fly end hojindeks-scoops. Dette introducerede en ujeavnt tid-hukommelse-afvejning, der tillod angribere at reducere kraevede lager til disse scoops og bryde antagelsen om, at alle forberegnede data var lige dyre.

**XOR-kompressionsangreb (POC2):**
I POC2 kan en angriber tage et hvilket som helst saet af 8192 nonces og opdele dem i to blokke af 4096 nonces (A og B). I stedet for at gemme begge blokke gemmer angriberen kun en afledt struktur: `A XOR transpose(B)`, hvor transposen bytter scoop- og nonceindekser - scoop S af nonce N i blok B bliver scoop N af nonce S.

Under mining, nar scoop S af nonce N er nodvendig, rekonstruerer angriberen den ved at:
1. Laese den gemte XOR-vaerdi pa position (S, N)
2. Beregne nonce N fra blok A for at fa scoop S
3. Beregne nonce S fra blok B for at fa den transponerede scoop N
4. XOR'e alle tre vaerdier for at gendanne den originale 64-byte scoop

Dette reducerer lager med 50%, mens det kun kraever to nonceberegninger pr. opslag - en omkostning langt under den graense, der er nodvendig for at haandhaeve fuld forberegning. Angrebet er levedygtigt, fordi beregning af en raekke (en nonce, 4096 scoops) er billig, mens beregning af en kolonne (en enkelt scoop pa tvaers af 4096 nonces) ville kraeve regenerering af alle nonces. Transponestrukturen eksponerer denne ubalance.

Dette demonstrerede behovet for et plotformat, der forebygger sadan struktureret rekombination og fjerner den underliggende tid-hukommelse-afvejning. Afsnit 3.3 beskriver, hvordan PoCX adresserer og loser denne svaghed.

### 2.5 Overgang til PoCX

Begraensningerne ved tidligere PoC-systemer gjorde det klart, at sikker, fair og decentraliseret lagermining afhaenger af omhyggeligt konstruerede plotstrukturer. Bitcoin-PoCX adresserer disse problemer med et haerdet plotformat, forbedret deadline-fordeling og mekanismer til decentraliseret pool-mining - beskrevet i naeste afsnit.

---

## 3. PoCX-plotformat

### 3.1 Basenoncekonstruktion

En nonce er en 256 KiB-datastruktur afledt deterministisk fra tre parametre: en 20-byte adressepayload, en 32-byte seed og et 64-bit nonceindeks.

Konstruktion begynder med at kombinere disse inputs og hashe dem med Shabal256 for at producere en initial hash. Denne hash tjener som udgangspunkt for en iterativ udvidelsesproces: Shabal256 anvendes gentagne gange, hvor hvert trin afhaenger af tidligere genererede data, indtil hele 256 KiB-bufferen er fyldt. Denne kaedede proces repraesenterer det beregningsmssige arbejde udfrt under plotting.

Et afsluttende diffusionstrin hasher den faerdigudfyldte buffer og XOR'er resultatet pa tvaers af alle bytes. Dette sikrer, at den fulde buffer er blevet beregnet, og at minere ikke kan genvejsberegne. PoC2-shuffle anvendes derefter, der bytter de nedre og ovre halvdele af hver scoop for at garantere, at alle scoops kraever aequivalent beregningsindsats.

Den endelige nonce bestar af 4096 scoops a 64 bytes hver og danner den fundamentale enhed brugt i mining.

### 3.2 SIMD-justeret plotlayout

For at maksimere gennemstroemning pa moderne hardware organiserer PoCX noncedata pa disk for at lette vektoriseret behandling. I stedet for at gemme hver nonce sekventielt justerer PoCX korresponderende 4-byte ord pa tvaers af flere fortløbende nonces sammenhaengende. Dette tillader en enkelt hukommelseshentning at levere data til alle SIMD-baner, minimere cache-misses og eliminere scatter-gather-overhead.

```
Traditionelt layout:
Nonce0: [O0][O1][O2][O3]...
Nonce1: [O0][O1][O2][O3]...
Nonce2: [O0][O1][O2][O3]...

PoCX SIMD-layout:
Ord0: [N0][N1][N2]...[N15]
Ord1: [N0][N1][N2]...[N15]
Ord2: [N0][N1][N2]...[N15]
```

Dette layout gavner bade CPU- og GPU-minere og muliggor hoj-gennemstroemnings, paralleliseret scoopvaluering, mens det bevarer et simpelt skalart adgangsmoenster til konsensusverifikation. Det sikrer, at mining er begraenset af lagringsbandbredde snarere end CPU-beregning og opretholder den lavenergi-natur af Proof of Capacity.

### 3.3 Warpstruktur og XOR-transpose-kodning

En warp er den fundamentale lagerenhed i PoCX, bestaende af 4096 nonces (1 GiB). Det ukomprimerede format, refereret til som X0, indeholder basenonces praecis som produceret af konstruktionen i afsnit 3.1.

**XOR-transpose-kodning (X1)**

For at fjerne de strukturelle tid-hukommelse-afvejninger til stede i tidligere PoC-systemer udleder PoCX et haerdet miningformat, X1, ved at anvende XOR-transpose-kodning pa par af X0-warps.

For at konstruere scoop S af nonce N i en X1-warp:

1. Tag scoop S af nonce N fra den forste X0-warp (direkte position)
2. Tag scoop N af nonce S fra den anden X0-warp (transponeret position)
3. XOR de to 64-byte vaerdier for at fa X1-scoopen

Transposetrinnet bytter scoop- og nonceindekser. I matrixtermer - hvor raekker repraesenterer scoops og kolonner repraesenterer nonces - kombinerer det elementet pa position (S, N) i den forste warp med elementet pa (N, S) i den anden.

**Hvorfor dette eliminerer kompressionsangrebsoverfladen**

XOR-transposen sammenlaaser hver scoop med en hel raekke og en hel kolonne af de underliggende X0-data. Gendannelse af en enkelt X1-scoop kraever derfor adgang til data, der spaender over alle 4096 scoopindekser. Ethvert forsog pa at beregne manglende data ville kraeve regenerering af 4096 fulde nonces, snarere end en enkelt nonce - hvilket fjerner den asymmetriske omkostningsstruktur, der udnyttes af XOR-angrebet for POC2 (afsnit 2.4).

Som resultat bliver lagring af den fulde X1-warp den eneste beregningsmssigt levedygtige strategi for minere, hvilket lukker tid-hukommelse-afvejningen udnyttet i tidligere designs.

### 3.4 Disklayout

PoCX-plotfiler bestar af mange fortløbende X1-warps. For at maksimere operationel effektivitet under mining er dataene inden for hver fil organiseret efter scoop: alle scoop 0-data fra hver warp gemmes sekventielt, efterfulgt af alle scoop 1-data, og sa videre op til scoop 4095.

Denne **scoop-sekventielle ordning** tillader minere at laese de komplette data kraevet til en valgt scoop i en enkelt sekventiel diskadgang, minimere sogetider og maksimere gennemstroemning pa standardlagringsenheder.

Kombineret med XOR-transpose-kodningen fra afsnit 3.3 sikrer dette layout, at filen er bade **strukturelt haerdet** og **operationelt effektiv**: sekventiel scoopordning understotter optimal disk-I/O, mens SIMD-justerede hukommelseslayouts (se afsnit 3.2) tillader hoj-gennemstroemnings, paralleliseret scoopvaluering.

### 3.5 Proof-of-Work-skalering (Xn)

PoCX implementerer skalerbar forberegning gennem konceptet skaleringsniveauer, betegnet Xn, for at tilpasse sig udviklende hardwareydeevne. Baseline X1-formatet repraesenterer den forste XOR-transpose-haerdede warpstruktur.

Hvert skaleringsniveau Xn oger den proof-of-work, der er indlejret i hver warp, eksponentielt i forhold til X1: det arbejde, der kraeves pa niveau Xn, er 2^(n-1) gange det for X1. Overgang fra Xn til Xn+1 svarer operationelt til at anvende en XOR pa tvaers af par af tilstodende warps, hvilket gradvist indlejrer mere proof-of-work uden at aendre den underliggende plotstorrelse.

Eksisterende plotfiler oprettet pa lavere skaleringsniveauer kan stadig bruges til mining, men de bidrager proportionalt mindre arbejde mod blokgenerering, hvilket afspejler deres lavere indlejrede proof-of-work. Denne mekanisme sikrer, at PoCX-plots forbliver sikre, fleksible og okonomisk balancerede over tid.

### 3.6 Seed-funktionalitet

Seedparameteren muliggor flere ikke-overlappende plots pr. adresse uden manuel koordinering.

**Problem (POC2)**: Minere skulle manuelt spore nonceintervaller pa tvaers af plotfiler for at undga overlap. Overlappende nonces spilder lager uden at oge miningkraft.

**Losning**: Hvert `(adresse, seed)`-par definerer et uafhaengigt noglerum. Plots med forskellige seeds overlapper aldrig, uanset nonceintervaller. Minere kan oprette plots frit uden koordinering.

---

## 4. Proof of Capacity-konsensus

PoCX udvider Bitcoins Nakamoto-konsensus med en lagerbundet bevismekanisme. I stedet for at forbruge energi pa gentagen hashing forpligter minere store maengder forberegnede data - plots - til disk. Under blokgenerering skal de lokalisere en lille, uforudsigelig del af disse data og transformere dem til et bevis. Mineren, der leverer det bedste bevis inden for det forventede tidsvindue, optjener retten til at forge den naeste blok.

Dette kapitel beskriver, hvordan PoCX strukturerer blokmetadata, udleder uforudsigelighed og transformerer statisk lager til en sikker, lavvarians-konsensusmekanisme.

### 4.1 Blokstruktur

PoCX bevarer den velkendte Bitcoin-stil blokheader, men introducerer yderligere konsensusfelter kraevet til kapacitetsbaseret mining. Disse felter binder tilsammen blokken til minerens gemte plot, netvaerkets svaerhed og den kryptografiske entropi, der definerer hver miningudfordring.

Pa et hojt niveau indeholder en PoCX-blok: blokhojden, registreret eksplicit for at forenkle kontekstuel validering; generationssignaturen, en kilde til frisk entropi, der forbinder hver blok til sin forgaenger; base target, der repraesenterer netvaerkssvaerhed i omvendt form (hojere vaerdier svarer til lettere mining); PoCX-beviset, der identificerer minerens plot, det kompressionsniveau, der bruges under plotting, den valgte nonce og kvaliteten afledt fra den; og en signeringsnogle og signatur, der beviser kontrol over den kapacitet, der bruges til at forge blokken (eller af en tildelt forging-nogle).

Beviset indlejrer al konsensusrelevant information, der er nodvendig for, at validatorer kan genberegne udfordringen, verificere den valgte scoop og bekraefte den resulterende kvalitet. Ved at udvide snarere end at omdesigne blokstrukturen forbliver PoCX konceptuelt tilpasset Bitcoin, mens det muliggor en fundamentalt anderledes kilde til miningarbejde.

### 4.2 Generationssignaturkaede

Generationssignaturen giver den uforudsigelighed, der kraeves til sikker Proof of Capacity-mining. Hver blok udleder sin generationssignatur fra den forrige bloks signatur og underskriver, hvilket sikrer, at minere ikke kan forudsige fremtidige udfordringer eller forberegne fordelagtige plotomrader:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

Dette producerer en sekvens af kryptografisk staerke, minerafhaengige entropivaerdier. Fordi en miners offentlige nogle er ukendt, indtil den forrige blok offentliggores, kan ingen deltager forudsige fremtidige scoopvalg. Dette forebygger selektiv forberegning eller strategisk plotting og sikrer, at hver blok introducerer aegte frisk miningarbejde.

### 4.3 Forgingproces

Mining i PoCX bestar af at transformere gemte data til et bevis drevet udelukkende af generationssignaturen. Selvom processen er deterministisk, sikrer signaturens uforudsigelighed, at minere ikke kan forberede sig pa forhand og gentagne gange skal tilga deres gemte plots.

**Udfordringsafledning (scoopvalg):** Mineren hasher den nuvaerende generationssignatur med blokhojden for at fa et scoopindeks i intervallet 0-4095. Dette indeks bestemmer, hvilket 64-byte segment af hver gemt nonce deltager i beviset. Fordi generationssignaturen afhaenger af den forrige bloks underskriver, bliver scoopvalg forst kendt i oejeblikket for blokoffentliggørelse.

**Bevisvaluering (kvalitetsberegning):** For hver nonce i et plot henter mineren den valgte scoop og hasher den sammen med generationssignaturen for at fa en kvalitet - en 64-bit vaerdi, hvis storrelse bestemmer minerens konkurrenceevne. Lavere kvalitet svarer til et bedre bevis.

**Deadlineformation (Time Bending):** Den ra deadline er proportional med kvaliteten og omvendt proportional med base target. I aeldre PoC-designs fulgte disse deadlines en stærkt skaev eksponentiel fordeling, der producerede lange haleforsinkelser, der ikke gav yderligere sikkerhed. PoCX transformerer den ra deadline ved hjaelp af Time Bending (afsnit 4.4), reducerer varians og sikrer forudsigelige blokintervaller. Nar den bendede deadline udlober, forger mineren en blok ved at indlejre beviset og signere det med den effektive forging-nogle.

### 4.4 Time Bending

Proof of Capacity producerer eksponentielt fordelte deadlines. Efter en kort periode - typisk nogle fa dusin sekunder - har hver miner allerede identificeret deres bedste bevis, og enhver yderligere ventetid bidrager kun med latens, ikke sikkerhed.

Time Bending omformer fordelingen ved at anvende en kubikrodstransformation:

`deadline_bended = scale x (quality / base_target)^(1/3)`

Skalafaktoren bevarer den forventede bloktid (120 sekunder), mens den dramatisk reducerer varians. Korte deadlines udvides, hvilket forbedrer blokpropagering og netvaerkssikkerhed. Lange deadlines komprimeres, hvilket forebygger outliers i at forsinke kaeden.

![Bloktidsfordelinger](blocktime_distributions.svg)

Time Bending opretholder informationsindholdet i det underliggende bevis. Det modificerer ikke konkurrenceevne blandt minere; det omfordeler kun ventetid for at producere glaettere, mere forudsigelige blokintervaller. Implementeringen bruger fikspunkt-aritmetik (Q42-format) og 256-bit heltal for at sikre deterministiske resultater pa tvaers af alle platforme.

### 4.5 Svaerhedsjustering

PoCX regulerer blokproduktion ved hjaelp af base target, et omvendt svaerhedsmal. Den forventede bloktid er proportional med forholdet `quality / base_target`, sa forogelse af base target accelererer blokoprettelse, mens reduktion af det saenker kaeden.

Svaerhed justeres ved hver blok ved hjaelp af den malte tid mellem nylige blokke sammenlignet med malintervallet. Denne hyppige justering er nodvendig, fordi lagerkapacitet kan tilfojes eller fjernes hurtigt - i modsaetning til Bitcoins hashkraft, der aendrer sig langsommere.

Justeringen folger to vejledende begraensninger: **Gradualitet** - pr.-blok-aendringer er begraensede (+/-20% maksimalt) for at undga oscillationer eller manipulation; **Haerdning** - base target kan ikke overstige sin genesis-vaerdi, hvilket forebygger, at netvaerket nogensinde saenker svaerhed under de oprindelige sikkerhedsantagelser.

### 4.6 Blokgyldighed

En blok i PoCX er gyldig, nar den praesenterer et verificerbart lagerafledt bevis, der er konsistent med konsensustilstanden. Validatorer genberegner uafhaengigt scoopvalget, udleder den forventede kvalitet fra den indsendte nonce og plotmetadata, anvender Time Bending-transformationen og bekraefter, at mineren var berettiget til at forge blokken pa det erklaerede tidspunkt.

Specifikt kraever en gyldig blok: deadlinen er udlobet siden foraeblrokken; den indsendte kvalitet matcher den beregnede kvalitet for beviset; skaleringsniveauet opfylder netvaerksminimum; generationssignaturen matcher den forventede vaerdi; base target matcher den forventede vaerdi; bloksignaturen kommer fra den effektive underskriver; og coinbase betaler til den effektive underskriverens adresse.

---

## 5. Forging Assignments

### 5.1 Motivation

Forging assignments tillader plotejere at delegere blokforgingsautoritet uden nogensinde at opgive ejerskab af deres plots. Denne mekanisme muliggor pool-mining og cold-storage-opsaetninger, mens sikkerhedsgarantierne for PoCX bevares.

I pool-mining kan plotejere autorisere en pool til at forge blokke pa deres vegne. Poolen samler blokke og distribuerer beloninger, men den far aldrig custody over selve plotterne. Delegering er reversibel til enhver tid, og plotejere forbliver frie til at forlade en pool eller aendre konfigurationer uden genplotning.

Assignments understotter ogsa en ren adskillelse mellem kolde og varme nogler. Den private nogle, der kontrollerer plottet, kan forblive offline, mens en separat forging-nogle - gemt pa en online maskine - producerer blokke. Et kompromis af forging-noglen kompromitterer derfor kun forgingsautoritet, ikke ejerskab. Plottet forbliver sikkert, og assignmentet kan tilbagekaldes, hvilket lukker sikkerhedshullet ojeblikkelig.

Forging assignments giver sa operationel fleksibilitet, mens princippet om, at kontrol over gemt kapacitet aldrig ma overfores til mellemaend, opretholdes.

### 5.2 Assignment-protokol

Assignments erklares gennem OP_RETURN-transaktioner for at undga unodvendig vaekst af UTXO-saettet. En assignment-transaktion specificerer plotadressen og forging-adressen, der er autoriseret til at producere blokke ved hjaelp af det plots kapacitet. En tilbagekaldelsestransaktion indeholder kun plotadressen. I begge tilfaelde beviser plotejeren kontrol ved at signere forbrugsinputtet af transaktionen.

Hvert assignment skrider frem gennem en sekvens af veldefinerede tilstande (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Efter at en assignment-transaktion bekraeftes, gar systemet ind i en kort aktiveringsfase. Denne forsinkelse - 30 blokke, omkring en time - sikrer stabilitet under blokveddelob og forebygger fjendtlig hurtig skift af forging-identiteter. Nar denne aktiveringsperiode udlober, bliver assignmentet aktivt og forbliver sa, indtil plotejeren udsteder en tilbagekaldelse.

Tilbagekaldelser overgår til en laengere forsinkelsesperiode pa 720 blokke, ca. en dag. I denne tid forbliver den tidligere forging-adresse aktiv. Denne laengere forsinkelse giver operationel stabilitet for pools, forebygger strategisk "assignment-hopping" og giver infrastrukturudbydere nok sikkerhed til at operere effektivt. Efter at tilbagekaldelsesforsinkelsen udlober, faerdigudfres tilbagekaldelsen, og plotejeren er fri til at udpege en ny forging-nogle.

Assignment-tilstanden vedligeholdes i en konsensuslag-struktur parallelt med UTXO-saettet og understotter undo-data til sikker handtering af kaedereorganiseringer.

### 5.3 Valideringsregler

For hver blok bestemmer validatorer den effektive underskriver - adressen, der skal signere blokken og modtage coinbase-belonningen. Denne underskriver afhaenger udelukkende af assignment-tilstanden ved blokkens hojde.

Hvis der ikke eksisterer noget assignment, eller assignmentet endnu ikke har faerdiggjort sin aktiveringsfase, forbliver plotejeren den effektive underskriver. Nar et assignment bliver aktivt, skal den tildelte forging-adresse signere. Under tilbagekaldelse fortsaetter forging-adressen med at signere, indtil tilbagekaldelsesforsinkelsen udlober. Forst derefter vender autoritet tilbage til plotejeren.

Validatorer haandhaever, at bloksignaturen er produceret af den effektive underskriver, at coinbase betaler til den samme adresse, og at alle overgange folger de foreskrevne aktiverings- og tilbagekaldelsesforsinkelser. Kun plotejeren kan oprette eller tilbagekalde assignments; forging-nogler kan ikke modificere eller udvide deres egne tilladelser.

Forging assignments introducerer sa fleksibel delegering uden at introducere tillid. Ejerskab af den underliggende kapacitet forbliver altid kryptografisk forankret til plotejeren, mens forgingsautoritet kan delegeres, roteres eller tilbagekaldes, efterhanden som operationelle behov udvikler sig.

---

## 6. Dynamisk skalering

Efterhanden som hardware udvikler sig, falder omkostningerne ved at beregne plots i forhold til at laese forberegnet arbejde fra disk. Uden modforanstaltninger kunne angribere til sidst generere beviser on-the-fly hurtigere end minere, der laeser gemt arbejde, hvilket underminerer sikkerhedsmodellen for Proof of Capacity.

For at bevare den tilsigtede sikkerhedsmargin implementerer PoCX en skaleringsplan: det mindste kraevede skaleringsniveau for plots stiger over tid. Hvert skaleringsniveau Xn, som beskrevet i afsnit 3.5, indlejrer eksponentielt mere proof-of-work inden i plotstrukturen, hvilket sikrer, at minere fortsat forpligter betydelige lagerressourcer, selv efterhanden som beregning bliver billigere.

Planen tilpasser sig netvaerkets okonomiske incitamenter, saerligt blokbelonningshalveringer. Efterhanden som belonningen pr. blok falder, stiger minimumsniveauet gradvist, hvilket bevarer balancen mellem plottingsindsats og miningpotentiale:

| Periode | Ar | Halveringer | Min. skalering | Plotarbejdsmultiplikator |
|---------|-----|------------|----------------|-------------------------|
| Epoke 0 | 0-4 | 0 | X1 | 2x baseline |
| Epoke 1 | 4-12 | 1-2 | X2 | 4x baseline |
| Epoke 2 | 12-28 | 3-6 | X3 | 8x baseline |
| Epoke 3 | 28-60 | 7-14 | X4 | 16x baseline |
| Epoke 4 | 60-124 | 15-30 | X5 | 32x baseline |
| Epoke 5 | 124+ | 31+ | X6 | 64x baseline |

Minere kan valgfrit forberede plots, der overstiger det nuvaerende minimum med et niveau, hvilket tillader dem at planlaeegge forud og undga ojeblikkelige opgraderinger, nar netvaerket overgår til den naeste epoke. Dette valgfrie trin giver ikke yderligere fordel med hensyn til bloksandsynlighed - det tillader blot en glaettere operationel overgang.

Blokke indeholdende beviser under minimumskaleringsniveauet for deres hojde betragtes som ugyldige. Validatorer kontrollerer det erklaerede skaleringsniveau i beviset mod det aktuelle netvaerkskrav under konsensusvalidering, hvilket sikrer, at alle deltagende minere opfylder de udviklende sikkerhedsforventninger.

---

## 7. Miningarkitektur

PoCX adskiller konsenskritiske operationer fra de ressourceintensive opgaver ved mining og muliggor bade sikkerhed og effektivitet. Noden vedligeholder blockchainen, validerer blokke, styrer mempoolen og eksponerer en RPC-graenseflade. Eksterne minere handterer plotlagring, scooplsning, kvalitetsberegning og deadlinestyring. Denne adskillelse holder konsensuslogik simpel og reviderbar, mens den tillader minere at optimere til diskgennemstroemning.

### 7.1 Mining RPC-graenseflade

Minere interagerer med noden gennem et minimalt saet af RPC-kald. get_mining_info RPC'en giver den nuvaerende blokhojde, generationssignatur, base target, maldeadline og det acceptable interval af plotskaleringsniveauer. Ved hjaelp af denne information beregner minere kandidatnonces. submit_nonce RPC'en tillader minere at indsende en forestaende losning, inklusive plotidentifikatoren, nonceindeks, skaleringsniveau og minerkonto. Noden evaluerer indsendelsen og svarer med den beregnede deadline, hvis beviset er gyldigt.

### 7.2 Forging-scheduler

Noden vedligeholder en forging-scheduler, der sporer indgaende indsendelser og kun bevarer den bedste losning for hver blokhojde. Indsendte nonces saettes i ko med indbyggede beskyttelser mod indsendelsesflooding eller denial-of-service-angreb. Scheduleren venter, indtil den beregnede deadline udlober, eller en overlegent losning ankommer, hvorefter den samler en blok, signerer den med den effektive forging-nogle og offentliggor den til netvaerket.

### 7.3 Defensiv forging

For at forebygge timingangreb eller incitamenter til urmanipulation implementerer PoCX defensiv forging. Hvis en konkurrerende blok ankommer for den samme hojde, sammenligner scheduleren den lokale losning med den nye blok. Hvis den lokale kvalitet er overlegen, forger noden ojeblikkelig i stedet for at vente pa den oprindelige deadline. Dette sikrer, at minere ikke kan opna en fordel blot ved at justere lokale ure; den bedste losning sejrer altid, hvilket bevarer fairness og netvaerkssikkerhed.

---

## 8. Sikkerhedsanalyse

### 8.1 Trusselmodel

PoCX modellerer modstandere med betydelige, men begraensede kapaciteter. Angribere kan forsoge at overbelaste netvaerket med ugyldige transaktioner, misdannede blokke eller fabrikerede beviser for at stresseteste valideringsstier. De kan frit manipulere deres lokale ure og kan forsoge at udnytte kanttilfaelde i konsensusadfaerd sasom tidsstempelhandtering, svaerhedsjusteringsdynamik eller reorganiseringsregler. Modstandere forventes ogsa at sonde efter muligheder for at omskrive historie gennem malrettede kaedegafler.

Modellen antager, at ingen enkelt part kontrollerer et flertal af den samlede netvaerkslagringskapacitet. Som med enhver ressourcebaseret konsensusmekanisme kan en 51%-kapacitetsangriber ensidigt reorganisere kaeden; denne fundamentale begraensning er ikke specifik for PoCX. PoCX antager ogsa, at angribere ikke kan beregne plotdata hurtigere end aerlige minere kan laese det fra disk. Skaleringsplanen (afsnit 6) sikrer, at det beregningsmssige gab, der kraeves til sikkerhed, vokser over tid, efterhanden som hardware forbedres.

De folgende afsnit undersoger hver stoerre angrebsklasse i detaljer og beskriver de modforanstaltninger, der er indbygget i PoCX.

### 8.2 Kapacitetsangreb

Ligesom PoW kan en angriber med flertalskapacitet omskrive historie (et 51%-angreb). At opna dette kraever anskaffelse af et fysisk lageraftryk storre end det aerlige netvaerk - en dyr og logistisk kraevende bestrcebelse. Nar hardwaren er anskaffet, er driftsomkostningerne lave, men den indledende investering skaber et staerkt okonomisk incitament til at opfore sig aerligt: at underminere kaeden ville skade vaerdien af angriberens egen aktivbase.

PoC undgar ogsa nothing-at-stake-problemet forbundet med PoS. Selvom minere kan scanne plots mod flere konkurrerende gafler, forbruger hver scanning reel tid - typisk i storrelsesordenen titals sekunder pr. kaede. Med et 120-sekunders blokinterval begraenser dette iboende multi-gaffel-mining, og forsog pa at mine mange gafler samtidig forringer ydeevnen pa dem alle. Gaffel-mining er derfor ikke omkostningsfrit; det er fundamentalt begraenset af I/O-gennemstroemning.

Selv hvis fremtidig hardware tillod naer-ojeblikkelig plotscanning (f.eks. højhastighedsSSD'er), ville en angriber stadig sta over for et betydeligt fysisk ressourcekrav for at kontrollere et flertal af netvaerkskapacitet, hvilket gor et 51%-stil angreb dyrt og logistisk udfordrende.

Endelig er kapacitetsangreb langt svaerere at leje end hashkraftangreb. GPU-beregning kan anskaffes pa eftersporgsel og omdirigeres til enhver PoW-kaede ojeblikkelig. I modsaetning hertil kraever PoC fysisk hardware, tidskraevende plotting og igangvaerende I/O-operationer. Disse begraensninger gor kortsigtede, opportunistiske angreb langt mindre gennemforlige.

### 8.3 Timingangreb

Timing spiller en mere kritisk rolle i Proof of Capacity end i Proof of Work. I PoW pavirker tidsstempler primaert svaerhedsjustering; i PoC bestemmer de, om en miners deadline er udlobet, og dermed om en blok er berettiget til forging. Deadlines males i forhold til foraelderblokens tidsstempel, men en nodes lokale ur bruges til at bedoome, om en indgaende blok ligger for langt i fremtiden. Af denne grund haandhaever PoCX en stram tidsstempeltolerance: blokke ma ikke afvige mere end 15 sekunder fra nodens lokale ur (sammenlignet med Bitcoins 2-timers vindue). Denne graense fungerer i begge retninger - blokke for langt i fremtiden afvises, og noder med langsomme ure kan fejlagtigt afvise gyldige indgaende blokke.

Noder bor derfor synkronisere deres ure ved hjaelp af NTP eller en aequivalent tidskilde. PoCX undgar bevidst at stole pa netvaerksinterne tidskilder for at forebygge angribere i at manipulere opfattet netvaerkstid. Noder overvager deres egen drift og udsender advarsler, hvis det lokale ur begynder at afvige fra nylige bloktidsstempler.

Uracceleration - at kore et hurtigt lokalt ur for at forge lidt tidligere - giver kun marginal fordel. Inden for den tilladte tolerance sikrer defensiv forging (afsnit 7.3), at en miner med en bedre losning ojeblikkelig offentliggor ved at se en ringere tidlig blok. Et hurtigt ur hjaelper kun en miner med at offentliggore en allerede-vindende losning et par sekunder tidligere; det kan ikke konvertere et ringere bevis til et vindende.

Forsog pa at manipulere svaerhed via tidsstempler er begraenset af et +/-20% pr.-blok-justeringsloft og et 24-blok rullende vindue, hvilket forebygger minere i meningsfuldt at pavirke svaerhed gennem kortsigtede timingspil.

### 8.4 Tid-hukommelse-afvejningsangreb

Tid-hukommelse-afvejninger forsoegepr at reducere lagerkrav ved at genberegne dele af plottet on-demand. Tidligere Proof of Capacity-systemer var sarbare over for sadanne angreb, mest bemaaerkelsesvaerdigt POC1 scoop-ubalancefejlen og POC2 XOR-transpose-kompressionsangrebet (afsnit 2.4). Begge udnyttede asymmetrier i, hvor dyrt det var at regenerere bestemte dele af plotdata, hvilket tillod modstandere at skare i lager, mens de kun betalte en lille beregningsstrof. Ogsa alternative plotformater til PoC2 lider af lignende TMTO-svagheder; et fremtraedende eksempel er Chia, hvis plotformat kan reduceres vilkarligt med en faktor storre end 4.

PoCX fjerner disse angrebsoverflader fuldstaendigt gennem sin noncekonstruktion og warpformat. Inden for hver nonce hasher det afsluttende diffusionstrin den fuldstaendigt beregnede buffer og XOR'er resultatet pa tvaers af alle bytes, hvilket sikrer, at hver del af bufferen afhaenger af hver anden del og ikke kan genvejsberegnes. Bagefter bytter PoC2-shuffle de nedre og ovre halvdele af hver scoop, hvilket udligner den beregningsmssige omkostning ved at gendanne enhver scoop.

PoCX eliminerer yderligere POC2 XOR-transpose-kompressionsangrebet ved at udlede sit haerdede X1-format, hvor hver scoop er XOR af en direkte og en transponeret position pa tvaers af parrede warps; dette sammenlaaser hver scoop med en hel raekke og en hel kolonne af underliggende X0-data, hvilket gor rekonstruktion kraever tusindvis af fulde nonces og derved fjerner den asymmetriske tid-hukommelse-afvejning fuldstaendigt.

Som resultat er lagring af det fulde plot den eneste beregningsmssigt levedygtige strategi for minere. Ingen kendt genvej - hvad enten det er delvis plotting, selektiv regenerering, struktureret kompression eller hybrid beregnings-lager-tilgange - giver en meningsfuld fordel. PoCX sikrer, at mining forbliver strengt lagerbundet, og at kapacitet afspejler reel, fysisk forpligtelse.

### 8.5 Assignment-angreb

PoCX bruger en deterministisk tilstandsmaskine til at styre alle plot-til-forger-assignments. Hvert assignment skrider frem gennem veldefinerede tilstande - UNASSIGNED -> ASSIGNING -> ASSIGNED -> REVOKING -> REVOKED - med haandhaevede aktiverings- og tilbagekaldelsesforsinkelser. Dette sikrer, at en miner ikke kan ojeblikkelig aendre assignments for at snyde systemet eller hurtigt skifte forgingsautoritet.

Fordi alle overgange kraever kryptografiske beviser - specifikt signaturer fra plotejeren, der kan verificeres mod input-UTXO'en - kan netvaerket stole pa legitimiteten af hvert assignment. Forsog pa at omga tilstandsmaskinen eller falske assignments afvises automatisk under konsensusvalidering. Replay-angreb forebygges ligeledes af standard Bitcoin-stil transaktions-replay-beskyttelser, hvilket sikrer, at hver assignment-handling er unikt knyttet til et gyldigt, ubrugt input.

Kombinationen af tilstandsmaskinestyring, haandhaevede forsinkelser og kryptografisk bevis gor assignment-baseret snyd praktisk umuligt: minere kan ikke kapre assignments, udføre hurtig omtildeling under blokveddelob eller omga tilbagekaldelsesplaner.

### 8.6 Signatursikkerhed

Bloksignaturer i PoCX tjener som et kritisk link mellem et bevis og den effektive forging-nogle og sikrer, at kun autoriserede minere kan producere gyldige blokke.

For at forebygge formbarhehdsangreb ekskluderes signaturer fra blokhash-beregningen. Dette eliminerer risici for formbare signaturer, der kunne underminere validering eller tillade blokerstattningsangreb.

For at afbode denial-of-service-vektorer er signatur- og offentlig nogle-storrelser faste - 65 bytes til kompakte signaturer og 33 bytes til komprimerede offentlige nogler - hvilket forebygger angribere i at oppuste blokke for at udlose ressourceudtomning eller langsommere netvaerkspropagering.

---

## 9. Implementering

PoCX er implementeret som en modulaer udvidelse til Bitcoin Core, med al relevant kode indeholdt i sin egen dedikerede undermappe og aktiveret gennem et feature-flag. Dette design bevarer integriteten af den originale kode og tillader PoCX at blive aktiveret eller deaktiveret rent, hvilket forenkler test, revision og at holde sig synkroniseret med upstream-aendringer.

Integrationen bercrer kun de vaesentlige punkter, der er nodvendige for at understotte Proof of Capacity. Blokheaderen er blevet udvidet til at inkludere PoCX-specifikke felter, og konsensusvalidering er blevet tilpasset til at behandle lagerbaserede beviser sammen med traditionelle Bitcoin-kontroller. Forging-systemet, der er ansvarligt for styring af deadlines, planlaegning og minerindsendelser, er fuldt indeholdt i PoCX-modulerne, mens RPC-udvidelser eksponerer mining- og assignment-funktionalitet til eksterne klienter. For brugere er wallet-graeensefladen blevet forbedret til at styre assignments gennem OP_RETURN-transaktioner, hvilket muliggor gnidningslos interaktion med de nye konsensusfunktioner.

Alle konsenskritiske operationer er implementeret i deterministisk C++ uden eksterne afhaengigheder, hvilket sikrer tvaerplatformskonsekvens. Shabal256 bruges til hashing, mens Time Bending og kvalitetsberegning er afhaengige af fikspunkt-aritmetik og 256-bit operationer. Kryptografiske operationer sasom signaturverifikation udnytter Bitcoin Cores eksisterende secp256k1-bibliotek.

Ved at isolere PoCX-funktionalitet pa denne made forbliver implementeringen reviderbar, vedligeholdelig og fuldt kompatibel med igangvaerende Bitcoin Core-udvikling, hvilket demonstrerer, at en fundamentalt ny lagerbundet konsensusmekanisme kan sameksistere med en moden proof-of-work-kodebase uden at forstyrre dens integritet eller brugbarhed.

---

## 10. Netvaerksparametre

PoCX bygger pa Bitcoins netvaerksinfrastruktur og genbruger dens kaedeparameterramme. For at understotte kapacitetsbaseret mining, blokintervaller, assignment-handtering og plotskalering er flere parametre blevet udvidet eller tilsidesat. Dette inkluderer bloktidsmal, indledende subsidie, halveringsplan, assignment-aktiverings- og tilbagekaldelsesforsinkelser samt netvaerksidentifikatorer sasom magic bytes, porte og Bech32-praefixer. Testnet- og regtest-miljoer justerer yderligere disse parametre for at muliggore hurtig iteration og lavkapacitetstest.

Tabellerne nedenfor opsummerer de resulterende mainnet-, testnet- og regtest-indstillinger og fremhaever, hvordan PoCX tilpasser Bitcoins kerneparametre til en lagerbundet konsensusmodel.

### 10.1 Mainnet

| Parameter | Vaerdi |
|-----------|--------|
| Magic bytes | `0xa7 0x3c 0x91 0x5e` |
| Standardport | 8888 |
| Bech32 HRP | `pocx` |
| Bloktidsmal | 120 sekunder |
| Indledende subsidie | 10 BTC |
| Halveringsinterval | 1050000 blokke (~4 ar) |
| Samlet forsyning | ~21 millioner BTC |
| Assignment-aktivering | 30 blokke |
| Assignment-tilbagekaldelse | 720 blokke |
| Rullende vindue | 24 blokke |

### 10.2 Testnet

| Parameter | Vaerdi |
|-----------|--------|
| Magic bytes | `0x6d 0xf2 0x48 0xb3` |
| Standardport | 18888 |
| Bech32 HRP | `tpocx` |
| Bloktidsmal | 120 sekunder |
| Andre parametre | Samme som mainnet |

### 10.3 Regtest

| Parameter | Vaerdi |
|-----------|--------|
| Magic bytes | `0xfa 0xbf 0xb5 0xda` |
| Standardport | 18444 |
| Bech32 HRP | `rpocx` |
| Bloktidsmal | 1 sekund |
| Halveringsinterval | 500 blokke |
| Assignment-aktivering | 4 blokke |
| Assignment-tilbagekaldelse | 8 blokke |
| Lavkapacitetstilstand | Aktiveret (~4 MB plots) |

---

## 11. Relateret arbejde

Gennem arene har flere blockchain- og konsensusprojekter udforsket lagerbaserede eller hybride miningmodeller. PoCX bygger pa denne slaegtslinje, mens det introducerer forbedringer i sikkerhed, effektivitet og kompatibilitet.

**Burstcoin / Signum.** Burstcoin introducerede det forste praktiske Proof-of-Capacity (PoC)-system i 2014 og definerede kernebegreber sasom plots, nonces, scoops og deadline-baseret mining. Dets efterfolgere, navnlig Signum (tidligere Burstcoin), udvidede okosystemet og udviklede sig til sidst til det, der er kendt som Proof-of-Commitment (PoC+), der kombinerer lagerforpligtelse med valgfrit staking for at pavirke effektiv kapacitet. PoCX arver det lagerbaserede miningfundament fra disse projekter, men adskiller sig betydeligt gennem et haerdet plotformat (XOR-transpose-kodning), dynamisk plotarbejdsskalering, deadline-udglatning ("Time Bending") og et fleksibelt assignment-system - alt imens det forankres i Bitcoin Core-kodebasen snarere end at opretholde en standalone netvaerksfork.

**Chia.** Chia implementerer Proof of Space and Time, der kombinerer diskbaserede lagerbeviser med en tidskomponent haandhaevet via Verifiable Delay Functions (VDFs). Dets design adresserer visse bekymringer om bevisgengebrugn og frisk udfordringsgenerering, distinkt fra klassisk PoC. PoCX adopterer ikke den tidsforankrede bevismodel; i stedet opretholder det en lagerbundet konsensus med forudsigelige intervaller, optimeret til langsigtet kompatibilitet med UTXO-okonomi og Bitcoin-afledt vaerktoj.

**Spacemesh.** Spacemesh foreslar et Proof-of-Space-Time (PoST)-skema ved hjaelp af en DAG-baseret (mesh) netvaerkstopologi. I denne model skal deltagere periodisk bevise, at allokeret lager forbliver intakt over tid, snarere end at stole pa et enkelt forberegnet datasaet. PoCX verificerer derimod lagerforpligtelse kun ved bloktid - med haerdede plotformater og rigoroes bevisvalidering - og undgar overheaden af kontinuerlige lagerbeviser, mens effektivitet og decentralisering bevares.

---

## 12. Konklusion

Bitcoin-PoCX demonstrerer, at energieffektiv konsensus kan integreres i Bitcoin Core, mens sikkerhedsegenskaber og okonomisk model bevares. Nøglebidrag inkluderer XOR-transpose-kodning (tvinger angribere til at beregne 4096 nonces pr. opslag, eliminerer kompressionsangrebet), Time Bending-algoritmen (fordelingstransformation reducerer bloktidsvarians), forging assignment-systemet (OP_RETURN-baseret delegering muliggor ikke-custodial pool-mining), dynamisk skalering (tilpasset halveringer for at opretholde sikkerhedsmarginer) og minimal integration (feature-flagget kode isoleret i en dedikeret mappe).

Systemet er i oejeblikket i testnet-fase. Miningkraft stammer fra lagerkapacitet snarere end hashrate, hvilket reducerer energiforbrug med storrelsesordener, mens Bitcoins beviste okonomiske model opretholdes.

---

## Referencer

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
**Status**: Testnet-fase
