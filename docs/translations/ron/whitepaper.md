# Bitcoin-PoCX: Consens eficient energetic pentru Bitcoin Core

**Versiune**: 2.0 Draft
**Dată**: Decembrie 2025
**Organizație**: Proof of Capacity Consortium

---

## Rezumat

Consensul Proof-of-Work (PoW) al Bitcoin oferă securitate robustă, dar consumă energie substanțială din cauza calculului hash-urilor în timp real în mod continuu. Prezentăm Bitcoin-PoCX, un fork Bitcoin care înlocuiește PoW cu Proof of Capacity (PoC), unde minerii precalculează și stochează seturi mari de hash-uri stocate pe disc în timpul creării plot-urilor și ulterior minează prin căutări ușoare în loc de hashing continuu. Prin mutarea calculului din faza de minerit într-o fază unică de creare a plot-urilor, Bitcoin-PoCX reduce drastic consumul de energie permițând în același timp mineritul pe hardware de uz general, reducând barierele de participare și atenuând presiunile de centralizare inerente în PoW dominat de ASIC-uri, toate acestea păstrând ipotezele de securitate și comportamentul economic al Bitcoin.

Implementarea noastră introduce mai multe inovații cheie:
(1) Un format de plot întărit care elimină toate atacurile cunoscute de compromis timp-memorie din sistemele PoC existente, asigurând că puterea efectivă de minerit rămâne strict proporțională cu capacitatea de stocare angajată;
(2) Algoritmul Time-Bending, care transformă distribuțiile deadline-urilor din exponențiale în chi-pătrat, reducând varianța timpului de bloc fără a modifica media;
(3) Un mecanism de atribuire a forjării bazat pe OP_RETURN care permite mineritul în pool non-custodial; și
(4) Scalarea dinamică a compresiei, care crește dificultatea generării plot-urilor în aliniere cu calendarele de înjumătățire pentru a menține marjele de securitate pe termen lung pe măsură ce hardware-ul se îmbunătățește.

Bitcoin-PoCX menține arhitectura Bitcoin Core prin modificări minime, marcate cu flag-uri de funcționalitate, izolând logica PoC de codul de consens existent. Sistemul păstrează politica monetară a Bitcoin prin țintirea unui interval de bloc de 120 de secunde și ajustarea subvenției de bloc la 10 BTC. Subvenția redusă compensează creșterea de cinci ori a frecvenței blocurilor, păstrând rata de emisie pe termen lung aliniată cu calendarul original al Bitcoin și menținând oferta maximă de ~21 milioane.

---

## 1. Introducere

### 1.1 Motivație

Consensul Proof-of-Work (PoW) al Bitcoin s-a dovedit sigur de mai bine de un deceniu, dar la un cost semnificativ: minerii trebuie să cheltuiască continuu resurse computaționale, rezultând un consum ridicat de energie. Dincolo de preocupările legate de eficiență, există o motivație mai largă: explorarea mecanismelor de consens alternative care mențin securitatea în timp ce reduc barierele de participare. PoC permite practic oricui are hardware de stocare de uz general să mineze eficient, reducând presiunile de centralizare observate în mineritul PoW dominat de ASIC-uri.

Proof of Capacity (PoC) realizează acest lucru prin derivarea puterii de minerit din angajamentul de stocare mai degrabă decât din calculul continuu. Minerii precalculează seturi mari de hash-uri stocate pe disc - plot-uri - într-o fază unică de creare a plot-urilor. Mineritul constă apoi în căutări ușoare, reducând drastic consumul de energie păstrând în același timp ipotezele de securitate ale consensului bazat pe resurse.

### 1.2 Integrarea cu Bitcoin Core

Bitcoin-PoCX integrează consensul PoC în Bitcoin Core mai degrabă decât crearea unui blockchain nou. Această abordare valorifică securitatea dovedită a Bitcoin Core, stiva de rețea matură și instrumentele larg adoptate, păstrând în același timp modificările minime și marcate cu flag-uri de funcționalitate. Logica PoC este izolată de codul de consens existent, asigurând că funcționalitatea de bază - validarea blocurilor, operațiunile portofelului, formatele tranzacțiilor - rămâne în mare parte neschimbată.

### 1.3 Obiective de design

**Securitate**: Păstrarea robusteții echivalente cu Bitcoin; atacurile necesită capacitate majoritate de stocare.

**Eficiență**: Reducerea sarcinii computaționale continue la niveluri de I/O pe disc.

**Accesibilitate**: Permite mineritul cu hardware de uz general, reducând barierele de intrare.

**Integrare minimă**: Introducerea consensului PoC cu amprentă minimă de modificare.

---

## 2. Context: Proof of Capacity

### 2.1 Istoric

Proof of Capacity (PoC) a fost introdus de Burstcoin în 2014 ca o alternativă eficientă energetic la Proof-of-Work (PoW). Burstcoin a demonstrat că puterea de minerit putea fi derivată din stocare angajată mai degrabă decât din hashing continuu în timp real: minerii precalculau seturi mari de date („plot-uri") o singură dată și apoi minau prin citirea unor porțiuni mici, fixe din acestea.

Implementările timpurii PoC au dovedit că conceptul este viabil, dar au relevat și că formatul plot-ului și structura criptografică sunt critice pentru securitate. Mai multe compromisuri timp-memorie au permis atacatorilor să mineze eficient cu mai puțină stocare decât participanții onești. Acest lucru a evidențiat că securitatea PoC depinde de designul plot-ului - nu doar de utilizarea stocării ca resursă.

Moștenirea Burstcoin a stabilit PoC ca mecanism de consens practic și a furnizat fundația pe care PoCX construiește.

### 2.2 Concepte de bază

Mineritul PoC se bazează pe fișiere plot mari, precalculate, stocate pe disc. Aceste plot-uri conțin „calcul înghețat": hashing-ul costisitor este efectuat o singură dată în timpul creării plot-ului, iar mineritul constă apoi în citiri ușoare de pe disc și verificare simplă. Elementele de bază includ:

**Nonce:**
Unitatea de bază a datelor plot. Fiecare nonce conține 4096 scoop-uri (256 KiB în total) generate prin Shabal256 din adresa minerului și indexul nonce-ului.

**Scoop:**
Un segment de 64 de octeți din interiorul unui nonce. Pentru fiecare bloc, rețeaua selectează determinist un index de scoop (0-4095) bazat pe semnătura de generare a blocului anterior. Doar acest scoop per nonce trebuie citit.

**Semnătura de generare:**
O valoare de 256 de biți derivată din blocul anterior. Furnizează entropia pentru selecția scoop-ului și previne minerii să anticipeze indicii de scoop viitori.

**Warp:**
Un grup structural de 4096 nonce-uri (1 GiB). Warp-urile sunt unitatea relevantă pentru formatele de plot rezistente la compresie.

### 2.3 Procesul de minerit și fluxul de calitate

Mineritul PoC constă într-un pas unic de creare a plot-ului și o rutină ușoară per-bloc:

**Configurare unică:**
- Generarea plot-ului: Calculați nonce-urile prin Shabal256 și scrieți-le pe disc.

**Minerit per-bloc:**
- Selecția scoop-ului: Determinați indexul scoop-ului din semnătura de generare.
- Scanarea plot-ului: Citiți acel scoop din toate nonce-urile din plot-urile minerului.

**Fluxul de calitate:**
- Calitate brută: Hash-uiți fiecare scoop cu semnătura de generare folosind Shabal256Lite pentru a obține o valoare de calitate pe 64 de biți (mai mică este mai bună).
- Deadline: Convertiți calitatea într-un deadline folosind ținta de bază (un parametru ajustat la dificultate care asigură că rețeaua atinge intervalul de bloc țintit): `deadline = quality / base_target`
- Deadline bended: Aplicați transformarea Time-Bending pentru a reduce varianța păstrând în același timp timpul de bloc așteptat.

**Forjarea blocului:**
Minerul cu deadline-ul (bended) cel mai scurt forjează următorul bloc odată ce acel timp a trecut.

Spre deosebire de PoW, aproape tot calculul are loc în timpul creării plot-ului; mineritul activ este în principal limitat de disc și consumă foarte puțină energie.

### 2.4 Vulnerabilități cunoscute în sistemele anterioare

**Defectul de distribuție POC1:**
Formatul original Burstcoin POC1 a prezentat o părtinire structurală: scoop-urile cu indici mici erau semnificativ mai ieftine de recalculat din mers decât scoop-urile cu indici mari. Aceasta a introdus un compromis timp-memorie neuniform, permițând atacatorilor să reducă stocarea necesară pentru acele scoop-uri și încălcând presupunerea că toate datele precalculate erau la fel de costisitoare.

**Atacul de compresie XOR (POC2):**
În POC2, un atacator poate lua orice set de 8192 nonce-uri și le poate partiționa în două blocuri de 4096 nonce-uri (A și B). În loc să stocheze ambele blocuri, atacatorul stochează doar o structură derivată: `A ⊕ transpose(B)`, unde transpunerea schimbă indicii scoop și nonce - scoop-ul S al nonce-ului N din blocul B devine scoop-ul N al nonce-ului S.

În timpul mineritului, când este nevoie de scoop-ul S al nonce-ului N, atacatorul îl reconstruiește prin:
1. Citirea valorii XOR stocate la poziția (S, N)
2. Calculul nonce-ului N din blocul A pentru a obține scoop-ul S
3. Calculul nonce-ului S din blocul B pentru a obține scoop-ul N transpus
4. XOR-area tuturor celor trei valori pentru a recupera scoop-ul original de 64 de octeți

Aceasta reduce stocarea cu 50%, necesitând doar două calcule de nonce per căutare - un cost mult sub pragul necesar pentru a impune precalcularea completă. Atacul este viabil deoarece calculul unui rând (un nonce, 4096 scoop-uri) este ieftin, în timp ce calculul unei coloane (un singur scoop de la 4096 nonce-uri) ar necesita regenerarea tuturor nonce-urilor. Structura transpunerii expune acest dezechilibru.

Aceasta a demonstrat necesitatea unui format de plot care previne astfel de recombinări structurate și elimină compromisul timp-memorie subiacent. Secțiunea 3.3 descrie modul în care PoCX abordează și rezolvă această slăbiciune.

### 2.5 Tranziția la PoCX

Limitările sistemelor PoC anterioare au clarificat faptul că mineritul sigur, echitabil și descentralizat bazat pe stocare depinde de structuri de plot atent proiectate. Bitcoin-PoCX abordează aceste probleme cu un format de plot întărit, distribuție îmbunătățită a deadline-urilor și mecanisme pentru mineritul descentralizat în pool - descrise în secțiunea următoare.

---

## 3. Formatul plot PoCX

### 3.1 Construcția nonce-ului de bază

Un nonce este o structură de date de 256 KiB derivată determinist din trei parametri: un payload de adresă de 20 de octeți, un seed de 32 de octeți și un index de nonce pe 64 de biți.

Construcția începe prin combinarea acestor intrări și hash-uirea lor cu Shabal256 pentru a produce un hash inițial. Acest hash servește ca punct de plecare pentru un proces de expansiune iterativă: Shabal256 este aplicat repetat, fiecare pas depinzând de datele generate anterior, până când întregul buffer de 256 KiB este umplut. Acest proces înlănțuit reprezintă munca computațională efectuată în timpul creării plot-ului.

Un pas final de difuzie hash-uiește buffer-ul completat și XOR-ează rezultatul pe toți octeții. Aceasta asigură că întregul buffer a fost calculat și că minerii nu pot scurtcircuita calculul. Amestecarea PoC2 este apoi aplicată, interschimbând jumătățile inferioară și superioară ale fiecărui scoop pentru a garanta că toate scoop-urile necesită efort computațional echivalent.

Nonce-ul final constă din 4096 scoop-uri de 64 de octeți fiecare și formează unitatea fundamentală folosită în minerit.

### 3.2 Layout de plot aliniat SIMD

Pentru a maximiza throughput-ul pe hardware modern, PoCX organizează datele nonce-urilor pe disc pentru a facilita procesarea vectorizată. În loc să stocheze fiecare nonce secvențial, PoCX aliniază cuvintele de 4 octeți corespunzătoare de la mai multe nonce-uri consecutive contiguu. Aceasta permite unei singure achiziții de memorie să furnizeze date pentru toate pistele SIMD, minimizând ratările de cache și eliminând overhead-ul de dispersare-colectare.

```
Layout tradițional:
Nonce0: [C0][C1][C2][C3]...
Nonce1: [C0][C1][C2][C3]...
Nonce2: [C0][C1][C2][C3]...

Layout SIMD PoCX:
Cuvânt0: [N0][N1][N2]...[N15]
Cuvânt1: [N0][N1][N2]...[N15]
Cuvânt2: [N0][N1][N2]...[N15]
```

Acest layout beneficiază atât minerii CPU cât și GPU, permițând evaluarea scoop-urilor paralelizată cu throughput ridicat, păstrând în același timp un model de acces scalar simplu pentru verificarea consensului. Asigură că mineritul este limitat de lățimea de bandă a stocării mai degrabă decât de calculul CPU, menținând natura de consum redus de energie a Proof of Capacity.

### 3.3 Structura warp și codificarea XOR-Transpose

Un warp este unitatea fundamentală de stocare în PoCX, constând din 4096 nonce-uri (1 GiB). Formatul necomprimat, denumit X0, conține nonce-uri de bază exact așa cum sunt produse de construcția din Secțiunea 3.1.

**Codificarea XOR-Transpose (X1)**

Pentru a elimina compromisurile timp-memorie structurale prezente în sistemele PoC anterioare, PoCX derivă un format de minerit întărit, X1, prin aplicarea unei codificări XOR-transpose perechilor de warp-uri X0.

Pentru a construi scoop-ul S al nonce-ului N într-un warp X1:

1. Se ia scoop-ul S al nonce-ului N din primul warp X0 (poziție directă)
2. Se ia scoop-ul N al nonce-ului S din al doilea warp X0 (poziție transpusă)
3. Se XOR-ează cele două valori de 64 de octeți pentru a obține scoop-ul X1

Pasul de transpunere schimbă indicii scoop și nonce. În termeni matriciali - unde rândurile reprezintă scoop-uri și coloanele reprezintă nonce-uri - combină elementul de la poziția (S, N) din primul warp cu elementul de la (N, S) din al doilea.

**De ce elimină suprafața de atac a compresiei**

XOR-transpose interconectează fiecare scoop cu un rând întreg și o coloană întreagă din datele X0 subiacente. Recuperarea unui singur scoop X1 necesită astfel acces la date care acoperă toți cei 4096 indici de scoop. Orice încercare de a calcula datele lipsă ar necesita regenerarea a 4096 nonce-uri complete, mai degrabă decât un singur nonce - eliminând structura de cost asimetrică exploatată de atacul XOR pentru POC2 (Secțiunea 2.4).

Ca rezultat, stocarea întregului warp X1 devine singura strategie viabilă computațional pentru mineri, închizând compromisul timp-memorie exploatat în design-urile anterioare.

### 3.4 Layout pe disc

Fișierele plot PoCX constau din multe warp-uri X1 consecutive. Pentru a maximiza eficiența operațională în timpul mineritului, datele din fiecare fișier sunt organizate pe scoop: toate datele scoop 0 din fiecare warp sunt stocate secvențial, urmate de toate datele scoop 1 și așa mai departe, până la scoop 4095.

Această **ordonare secvențială pe scoop** permite minerilor să citească datele complete necesare pentru un scoop selectat într-un singur acces secvențial pe disc, minimizând timpii de căutare și maximizând throughput-ul pe dispozitivele de stocare de uz general.

Combinată cu codificarea XOR-transpose din Secțiunea 3.3, acest layout asigură că fișierul este atât **întărit structural** cât și **eficient operațional**: ordonarea secvențială pe scoop suportă I/O optim pe disc, în timp ce layout-urile de memorie aliniate SIMD (vezi Secțiunea 3.2) permit evaluarea scoop-urilor paralelizată cu throughput ridicat.

### 3.5 Scalarea Proof-of-Work (Xn)

PoCX implementează precalculare scalabilă prin conceptul de niveluri de scalare, notate Xn, pentru a se adapta la performanța hardware în evoluție. Formatul de bază X1 reprezintă prima structură warp întărită XOR-transpose.

Fiecare nivel de scalare Xn crește proof-of-work încorporat în fiecare warp exponențial relativ la X1: munca necesară la nivelul Xn este de 2^(n-1) ori cea a X1. Tranziția de la Xn la Xn+1 este operațional echivalentă cu aplicarea unui XOR peste perechi de warp-uri adiacente, încorporând incremental mai mult proof-of-work fără a schimba dimensiunea plot-ului subiacent.

Fișierele plot existente create la niveluri de scalare inferioare pot fi încă folosite pentru minerit, dar contribuie proporțional mai puțină muncă la generarea blocurilor, reflectând proof-of-work-ul lor încorporat inferior. Acest mecanism asigură că plot-urile PoCX rămân sigure, flexibile și echilibrate economic în timp.

### 3.6 Funcționalitatea seed

Parametrul seed permite plot-uri multiple fără suprapunere per adresă fără coordonare manuală.

**Problema (POC2)**: Minerii trebuiau să urmărească manual intervalele de nonce între fișierele plot pentru a evita suprapunerile. Nonce-urile suprapuse risipesc stocarea fără a crește puterea de minerit.

**Soluția**: Fiecare pereche `(adresă, seed)` definește un spațiu de chei independent. Plot-urile cu seed-uri diferite nu se suprapun niciodată, indiferent de intervalele de nonce. Minerii pot crea plot-uri liber fără coordonare.

---

## 4. Consensul Proof of Capacity

PoCX extinde consensul Nakamoto al Bitcoin cu un mecanism de dovadă legat de stocare. În loc să cheltuiască energie pentru hashing repetat, minerii angajează cantități mari de date precalculate - plot-uri - pe disc. În timpul generării blocului, trebuie să localizeze o porțiune mică, imprevizibilă a acestor date și să o transforme într-o dovadă. Minerul care furnizează cea mai bună dovadă în fereastra de timp așteptată câștigă dreptul de a forja următorul bloc.

Acest capitol descrie modul în care PoCX structurează metadatele blocului, derivă imprevizibilitatea și transformă stocarea statică într-un mecanism de consens sigur, cu varianță redusă.

### 4.1 Structura blocului

PoCX păstrează header-ul de bloc în stil Bitcoin familiar, dar introduce câmpuri de consens suplimentare necesare pentru mineritul bazat pe capacitate. Aceste câmpuri leagă colectiv blocul de plot-ul stocat al minerului, de dificultatea rețelei și de entropia criptografică care definește fiecare provocare de minerit.

La nivel înalt, un bloc PoCX conține: înălțimea blocului, înregistrată explicit pentru a simplifica validarea contextuală; semnătura de generare, o sursă de entropie proaspătă care leagă fiecare bloc de predecesorul său; ținta de bază, reprezentând dificultatea rețelei în formă inversă (valori mai mari corespund unui minerit mai ușor); dovada PoCX, identificând plot-ul minerului, nivelul de compresie folosit în timpul creării plot-ului, nonce-ul selectat și calitatea derivată din acesta; și o cheie de semnare și semnătură, demonstrând controlul asupra capacității folosite pentru a forja blocul (sau al unei chei de forjare atribuite).

Dovada încorporează toate informațiile relevante pentru consens necesare validatorilor pentru a recalcula provocarea, a verifica scoop-ul ales și a confirma calitatea rezultată. Prin extinderea mai degrabă decât reproiectarea structurii blocului, PoCX rămâne aliniat conceptual cu Bitcoin permițând în același timp o sursă fundamental diferită de muncă de minerit.

### 4.2 Lanțul semnăturilor de generare

Semnătura de generare furnizează imprevizibilitatea necesară pentru mineritul Proof of Capacity sigur. Fiecare bloc derivă semnătura sa de generare din semnătura și semnatarul blocului anterior, asigurând că minerii nu pot anticipa provocările viitoare sau precalcula regiuni de plot avantajoase:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

Aceasta produce o secvență de valori de entropie puternice criptografic, dependente de miner. Deoarece cheia publică a unui miner este necunoscută până când blocul anterior este publicat, niciun participant nu poate prezice selecțiile de scoop viitoare. Aceasta previne precalcularea selectivă sau crearea strategică de plot-uri și asigură că fiecare bloc introduce muncă de minerit cu adevărat proaspătă.

### 4.3 Procesul de forjare

Mineritul în PoCX constă în transformarea datelor stocate într-o dovadă condusă în întregime de semnătura de generare. Deși procesul este determinist, imprevizibilitatea semnăturii asigură că minerii nu se pot pregăti în avans și trebuie să acceseze repetat plot-urile lor stocate.

**Derivarea provocării (selecția scoop-ului):** Minerul hash-uiește semnătura de generare curentă cu înălțimea blocului pentru a obține un index de scoop în intervalul 0-4095. Acest index determină care segment de 64 de octeți din fiecare nonce stocat participă la dovadă. Deoarece semnătura de generare depinde de semnatarul blocului anterior, selecția scoop-ului devine cunoscută doar în momentul publicării blocului.

**Evaluarea dovezii (calculul calității):** Pentru fiecare nonce dintr-un plot, minerul preia scoop-ul selectat și îl hash-uiește împreună cu semnătura de generare pentru a obține o calitate - o valoare pe 64 de biți a cărei magnitudine determină competitivitatea minerului. Calitatea mai mică corespunde unei dovezi mai bune.

**Formarea deadline-ului (Time Bending):** Deadline-ul brut este proporțional cu calitatea și invers proporțional cu ținta de bază. În design-urile PoC legacy, aceste deadline-uri urmau o distribuție exponențială foarte asimetrică, producând întârzieri cu cozi lungi care nu ofereau securitate suplimentară. PoCX transformă deadline-ul brut folosind Time Bending (Secțiunea 4.4), reducând varianța și asigurând intervale de bloc previzibile. Odată ce deadline-ul bended trece, minerul forjează un bloc încorporând dovada și semnându-l cu cheia de forjare efectivă.

### 4.4 Time Bending

Proof of Capacity produce deadline-uri distribuite exponențial. După o perioadă scurtă - de obicei câteva zeci de secunde - fiecare miner și-a identificat deja cea mai bună dovadă, iar orice timp de așteptare suplimentar contribuie doar latență, nu securitate.

Time Bending reformează distribuția prin aplicarea unei transformări cu rădăcină cubică:

`deadline_bended = scale × (quality / base_target)^(1/3)`

Factorul de scalare păstrează timpul de bloc așteptat (120 secunde) reducând dramatic varianța. Deadline-urile scurte sunt extinse, îmbunătățind propagarea blocurilor și siguranța rețelei. Deadline-urile lungi sunt comprimate, prevenind valorile extreme să întârzie lanțul.

![Distribuții timp bloc](blocktime_distributions.svg)

Time Bending menține conținutul informațional al dovezii subiacente. Nu modifică competitivitatea între mineri; realocă doar timpul de așteptare pentru a produce intervale de bloc mai netede, mai previzibile. Implementarea folosește aritmetică în virgulă fixă (format Q42) și numere întregi pe 256 de biți pentru a asigura rezultate deterministe pe toate platformele.

### 4.5 Ajustarea dificultății

PoCX reglează producția de blocuri folosind ținta de bază, o măsură inversă a dificultății. Timpul de bloc așteptat este proporțional cu raportul `quality / base_target`, deci creșterea țintei de bază accelerează crearea blocurilor în timp ce scăderea ei încetinește lanțul.

Dificultatea se ajustează la fiecare bloc folosind timpul măsurat între blocurile recente comparativ cu intervalul țintă. Această ajustare frecventă este necesară deoarece capacitatea de stocare poate fi adăugată sau eliminată rapid - spre deosebire de puterea de hash a Bitcoin, care se schimbă mai lent.

Ajustarea urmează două constrângeri directoare: **Gradualitate** - modificările per-bloc sunt limitate (maximum ±20%) pentru a evita oscilațiile sau manipularea; **Întărire** - ținta de bază nu poate depăși valoarea sa genesis, prevenind rețeaua să scadă vreodată dificultatea sub ipotezele de securitate originale.

### 4.6 Validitatea blocului

Un bloc în PoCX este valid când prezintă o dovadă verificabilă derivată din stocare, consistentă cu starea consensului. Validatorii recalculează independent selecția scoop-ului, derivă calitatea așteptată din nonce-ul trimis și metadatele plot-ului, aplică transformarea Time Bending și confirmă că minerul era eligibil să forjeze blocul la momentul declarat.

Concret, un bloc valid necesită: deadline-ul a trecut de la blocul părinte; calitatea trimisă corespunde calității calculate pentru dovadă; nivelul de scalare îndeplinește minimul rețelei; semnătura de generare corespunde valorii așteptate; ținta de bază corespunde valorii așteptate; semnătura blocului provine de la semnatarul efectiv; și coinbase-ul plătește la adresa semnatarului efectiv.

---

## 5. Atribuiri de forjare

### 5.1 Motivație

Atribuirile de forjare permit proprietarilor de plot-uri să delege autoritatea de forjare a blocurilor fără a renunța vreodată la proprietatea plot-urilor lor. Acest mecanism permite mineritul în pool și configurările de stocare la rece păstrând în același timp garanțiile de securitate ale PoCX.

În mineritul în pool, proprietarii de plot-uri pot autoriza un pool să forjeze blocuri în numele lor. Pool-ul asamblează blocuri și distribuie recompense, dar nu câștigă niciodată custodia asupra plot-urilor în sine. Delegarea este reversibilă oricând, iar proprietarii de plot-uri rămân liberi să părăsească un pool sau să schimbe configurațiile fără a face plot-uri noi.

Atribuirile suportă de asemenea o separare clară între cheile reci și cele calde. Cheia privată care controlează plot-ul poate rămâne offline, în timp ce o cheie de forjare separată - stocată pe o mașină online - produce blocuri. Un compromis al cheii de forjare compromite astfel doar autoritatea de forjare, nu proprietatea. Plot-ul rămâne în siguranță și atribuirea poate fi revocată, închizând imediat breșa de securitate.

Atribuirile de forjare oferă astfel flexibilitate operațională menținând în același timp principiul că controlul asupra capacității stocate nu trebuie niciodată transferat intermediarilor.

### 5.2 Protocolul de atribuire

Atribuirile sunt declarate prin tranzacții OP_RETURN pentru a evita creșterea inutilă a setului UTXO. O tranzacție de atribuire specifică adresa plot-ului și adresa de forjare autorizată să producă blocuri folosind capacitatea acelui plot. O tranzacție de revocare conține doar adresa plot-ului. În ambele cazuri, proprietarul plot-ului demonstrează controlul prin semnarea intrării de cheltuire a tranzacției.

Fiecare atribuire progresează printr-o secvență de stări bine definite (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). După ce o tranzacție de atribuire confirmă, sistemul intră într-o scurtă fază de activare. Această întârziere - 30 blocuri, aproximativ o oră - asigură stabilitatea în timpul curselor de blocuri și previne comutarea rapidă adversarială a identităților de forjare. Odată ce această perioadă de activare expiră, atribuirea devine activă și rămâne astfel până când proprietarul plot-ului emite o revocare.

Revocările tranziționează într-o perioadă de întârziere mai lungă de 720 blocuri, aproximativ o zi. În acest timp, adresa de forjare anterioară rămâne activă. Această întârziere mai lungă oferă stabilitate operațională pentru pool-uri, prevenind „saltul strategic de atribuiri" și oferind furnizorilor de infrastructură suficientă certitudine pentru a opera eficient. După ce întârzierea de revocare expiră, revocarea se completează și proprietarul plot-ului este liber să desemneze o nouă cheie de forjare.

Starea atribuirii este menținută într-o structură la nivelul consensului paralelă cu setul UTXO și suportă date de anulare pentru gestionarea sigură a reorganizărilor de lanț.

### 5.3 Reguli de validare

Pentru fiecare bloc, validatorii determină semnatarul efectiv - adresa care trebuie să semneze blocul și să primească recompensa coinbase. Acest semnatar depinde exclusiv de starea atribuirii la înălțimea blocului.

Dacă nu există atribuire sau atribuirea nu și-a completat încă faza de activare, proprietarul plot-ului rămâne semnatarul efectiv. Odată ce o atribuire devine activă, adresa de forjare atribuită trebuie să semneze. În timpul revocării, adresa de forjare continuă să semneze până când întârzierea de revocare expiră. Abia atunci autoritatea revine la proprietarul plot-ului.

Validatorii impun ca semnătura blocului să fie produsă de semnatarul efectiv, ca coinbase-ul să plătească la aceeași adresă și ca toate tranzițiile să urmeze întârzierile prescrise de activare și revocare. Doar proprietarul plot-ului poate crea sau revoca atribuiri; cheile de forjare nu pot modifica sau extinde propriile lor permisiuni.

Atribuirile de forjare introduc astfel delegare flexibilă fără a introduce încredere. Proprietatea capacității subiacente rămâne întotdeauna ancorată criptografic de proprietarul plot-ului, în timp ce autoritatea de forjare poate fi delegată, rotită sau revocată pe măsură ce nevoile operaționale evoluează.

---

## 6. Scalare dinamică

Pe măsură ce hardware-ul evoluează, costul calculării plot-urilor scade relativ la citirea muncii precalculate de pe disc. Fără contramăsuri, atacatorii ar putea în cele din urmă genera dovezi din mers mai repede decât minerii care citesc munca stocată, subminând modelul de securitate al Proof of Capacity.

Pentru a păstra marja de securitate intenționată, PoCX implementează un calendar de scalare: nivelul minim de scalare necesar pentru plot-uri crește în timp. Fiecare nivel de scalare Xn, așa cum este descris în Secțiunea 3.5, încorporează proof-of-work exponențial mai mult în structura plot-ului, asigurând că minerii continuă să angajeze resurse de stocare substanțiale chiar și pe măsură ce calculul devine mai ieftin.

Calendarul se aliniază cu stimulentele economice ale rețelei, în special înjumătățirile recompenselor de bloc. Pe măsură ce recompensa per bloc scade, nivelul minim crește treptat, păstrând echilibrul între efortul de creare a plot-urilor și potențialul de minerit:

| Perioadă | Ani | Înjumătățiri | Scalare min | Multiplicator muncă plot |
|----------|-----|--------------|-------------|--------------------------|
| Epoca 0 | 0-4 | 0 | X1 | 2× linie de bază |
| Epoca 1 | 4-12 | 1-2 | X2 | 4× linie de bază |
| Epoca 2 | 12-28 | 3-6 | X3 | 8× linie de bază |
| Epoca 3 | 28-60 | 7-14 | X4 | 16× linie de bază |
| Epoca 4 | 60-124 | 15-30 | X5 | 32× linie de bază |
| Epoca 5 | 124+ | 31+ | X6 | 64× linie de bază |

Minerii pot opțional pregăti plot-uri care depășesc minimul curent cu un nivel, permițându-le să planifice în avans și să evite actualizări imediate când rețeaua tranziționează la următoarea epocă. Acest pas opțional nu conferă avantaj suplimentar în termeni de probabilitate de bloc - permite doar o tranziție operațională mai lină.

Blocurile care conțin dovezi sub nivelul minim de scalare pentru înălțimea lor sunt considerate invalide. Validatorii verifică nivelul de scalare declarat în dovadă față de cerința curentă a rețelei în timpul validării consensului, asigurând că toți minerii participanți îndeplinesc așteptările de securitate în evoluție.

---

## 7. Arhitectura mineritului

PoCX separă operațiunile critice pentru consens de sarcinile intensive de resurse ale mineritului, permițând atât securitate cât și eficiență. Nodul menține blockchain-ul, validează blocurile, gestionează mempool-ul și expune o interfață RPC. Minerii externi gestionează stocarea plot-urilor, citirea scoop-urilor, calculul calității și gestionarea deadline-urilor. Această separare păstrează logica consensului simplă și auditabilă permițând în același timp minerilor să optimizeze pentru throughput-ul discului.

### 7.1 Interfața RPC de minerit

Minerii interacționează cu nodul printr-un set minimal de apeluri RPC. RPC-ul get_mining_info furnizează înălțimea curentă a blocului, semnătura de generare, ținta de bază, deadline-ul țintă și intervalul acceptabil al nivelurilor de scalare a plot-urilor. Folosind aceste informații, minerii calculează nonce-urile candidate. RPC-ul submit_nonce permite minerilor să trimită o soluție propusă, incluzând identificatorul plot-ului, indexul nonce-ului, nivelul de scalare și contul minerului. Nodul evaluează trimiterea și răspunde cu deadline-ul calculat dacă dovada este validă.

### 7.2 Planificatorul de forjare

Nodul menține un planificator de forjare, care urmărește trimiterile primite și reține doar cea mai bună soluție pentru fiecare înălțime de bloc. Nonce-urile trimise sunt puse în coadă cu protecții încorporate împotriva flood-ului de trimiteri sau atacurilor de denial-of-service. Planificatorul așteaptă până când deadline-ul calculat expiră sau o soluție superioară sosește, moment în care asamblează un bloc, îl semnează folosind cheia de forjare efectivă și îl publică în rețea.

### 7.3 Forjare defensivă

Pentru a preveni atacurile de sincronizare sau stimulentele pentru manipularea ceasului, PoCX implementează forjarea defensivă. Dacă un bloc concurent sosește pentru aceeași înălțime, planificatorul compară soluția locală cu noul bloc. Dacă calitatea locală este superioară, nodul forjează imediat mai degrabă decât să aștepte deadline-ul original. Aceasta asigură că minerii nu pot câștiga un avantaj doar prin ajustarea ceasurilor locale; cea mai bună soluție prevalează întotdeauna, păstrând echitatea și securitatea rețelei.

---

## 8. Analiză de securitate

### 8.1 Model de amenințare

PoCX modelează adversari cu capabilități substanțiale dar limitate. Atacatorii pot încerca să supraîncarce rețeaua cu tranzacții invalide, blocuri malformate sau dovezi fabricate pentru a testa căile de validare. Pot manipula liber ceasurile lor locale și pot încerca să exploateze cazuri marginale în comportamentul consensului cum ar fi gestionarea timestamp-urilor, dinamica ajustării dificultății sau regulile de reorganizare. De asemenea, se așteaptă ca adversarii să sondeze oportunități de a rescrie istoria prin fork-uri de lanț țintite.

Modelul presupune că nicio singură parte nu controlează majoritatea capacității totale de stocare a rețelei. Ca în cazul oricărui mecanism de consens bazat pe resurse, un atacator cu 51% capacitate poate reorganiza unilateral lanțul; această limitare fundamentală nu este specifică PoCX. PoCX presupune de asemenea că atacatorii nu pot calcula datele plot-ului mai repede decât minerii onești le pot citi de pe disc. Calendarul de scalare (Secțiunea 6) asigură că decalajul computațional necesar pentru securitate crește în timp pe măsură ce hardware-ul se îmbunătățește.

Secțiunile următoare examinează în detaliu fiecare clasă majoră de atac și descriu contramăsurile încorporate în PoCX.

### 8.2 Atacuri de capacitate

Ca și PoW, un atacator cu capacitate majoritară poate rescrie istoria (un atac de 51%). Realizarea acestui lucru necesită achiziționarea unei amprente fizice de stocare mai mari decât rețeaua onestă - o întreprindere costisitoare și dificilă din punct de vedere logistic. Odată ce hardware-ul este obținut, costurile operaționale sunt scăzute, dar investiția inițială creează un stimulent economic puternic de a se comporta onest: subminarea lanțului ar afecta valoarea propriei baze de active a atacatorului.

PoC evită de asemenea problema „nothing-at-stake" asociată cu PoS. Deși minerii pot scana plot-urile contra mai multor fork-uri concurente, fiecare scanare consumă timp real - de obicei de ordinul zecilor de secunde per lanț. Cu un interval de bloc de 120 de secunde, aceasta limitează inerent mineritul pe mai multe fork-uri, iar încercarea de a mina multe fork-uri simultan degradează performanța pe toate. Mineritul pe fork-uri nu este astfel fără cost; este fundamental constrâns de throughput-ul I/O.

Chiar dacă hardware-ul viitor ar permite scanarea aproape instantanee a plot-urilor (de exemplu, SSD-uri de mare viteză), un atacator s-ar confrunta în continuare cu o cerință substanțială de resurse fizice pentru a controla o majoritate a capacității rețelei, făcând un atac în stil 51% costisitor și provocator din punct de vedere logistic.

În cele din urmă, atacurile de capacitate sunt mult mai greu de închiriat decât atacurile de putere de hash. Calculul GPU poate fi achiziționat la cerere și redirecționat către orice lanț PoW instant. În schimb, PoC necesită hardware fizic, creare de plot-uri intensivă în timp și operații I/O continue. Aceste constrângeri fac atacurile oportuniste pe termen scurt mult mai puțin fezabile.

### 8.3 Atacuri de sincronizare

Sincronizarea joacă un rol mai critic în Proof of Capacity decât în Proof of Work. În PoW, timestamp-urile influențează în principal ajustarea dificultății; în PoC, ele determină dacă deadline-ul unui miner a trecut și astfel dacă un bloc este eligibil pentru forjare. Deadline-urile sunt măsurate relativ la timestamp-ul blocului părinte, dar ceasul local al unui nod este folosit pentru a judeca dacă un bloc primit este prea mult în viitor. Din acest motiv, PoCX impune o toleranță strictă a timestamp-ului: blocurile nu pot devia mai mult de 15 secunde de la ceasul local al nodului (comparativ cu fereastra de 2 ore a Bitcoin). Această limită funcționează în ambele direcții - blocurile prea mult în viitor sunt respinse, iar nodurile cu ceasuri lente pot respinge incorect blocurile primite valide.

Nodurile ar trebui astfel să-și sincronizeze ceasurile folosind NTP sau o sursă de timp echivalentă. PoCX evită în mod deliberat să se bazeze pe surse de timp interne rețelei pentru a preveni atacatorii să manipuleze timpul perceput al rețelei. Nodurile își monitorizează propria derivă și emit avertizări dacă ceasul local începe să se abată de la timestamp-urile blocurilor recente.

Accelerarea ceasului - rularea unui ceas local rapid pentru a forja puțin mai devreme - oferă doar un beneficiu marginal. În cadrul toleranței permise, forjarea defensivă (Secțiunea 7.3) asigură că un miner cu o soluție mai bună va publica imediat la vederea unui bloc devreme inferior. Un ceas rapid ajută doar un miner să publice o soluție deja câștigătoare cu câteva secunde mai devreme; nu poate converti o dovadă inferioară într-una câștigătoare.

Încercările de a manipula dificultatea prin timestamp-uri sunt limitate de o plafonare de ajustare de ±20% per-bloc și o fereastră rulantă de 24 de blocuri, prevenind minerii să influențeze semnificativ dificultatea prin jocuri de sincronizare pe termen scurt.

### 8.4 Atacuri de compromis timp-memorie

Compromisurile timp-memorie încearcă să reducă cerințele de stocare prin recalcularea părților din plot la cerere. Sistemele Proof of Capacity anterioare erau vulnerabile la astfel de atacuri, mai ales defectul de dezechilibru al scoop-urilor POC1 și atacul de compresie XOR-transpose POC2 (Secțiunea 2.4). Ambele exploatau asimetrii în cât de costisitor era să regenereze anumite porțiuni ale datelor plot-ului, permițând adversarilor să reducă stocarea plătind doar o penalizare computațională mică. De asemenea, formatele de plot alternative la PoC2 suferă de slăbiciuni TMTO similare; un exemplu proeminent este Chia, al cărui format de plot poate fi redus arbitrar cu un factor mai mare de 4.

PoCX elimină complet aceste suprafețe de atac prin construcția sa de nonce și formatul warp. În cadrul fiecărui nonce, pasul final de difuzie hash-uiește buffer-ul complet calculat și XOR-ează rezultatul pe toți octeții, asigurând că fiecare parte a buffer-ului depinde de fiecare altă parte și nu poate fi scurtcircuitată. După aceea, amestecarea PoC2 schimbă jumătățile inferioară și superioară ale fiecărui scoop, egalizând costul computațional al recuperării oricărui scoop.

PoCX elimină în continuare atacul de compresie XOR-transpose POC2 prin derivarea formatului său X1 întărit, unde fiecare scoop este XOR-ul unei poziții directe și a uneia transpuse peste warp-uri pereche; aceasta interconectează fiecare scoop cu un rând întreg și o coloană întreagă de date X0 subiacente, făcând reconstrucția să necesite mii de nonce-uri complete și eliminând astfel complet compromisul timp-memorie asimetric.

Ca rezultat, stocarea întregului plot este singura strategie viabilă computațional pentru mineri. Nicio scurtătură cunoscută - fie creare parțială de plot-uri, regenerare selectivă, compresie structurată sau abordări hibride calcul-stocare - nu oferă un avantaj semnificativ. PoCX asigură că mineritul rămâne strict legat de stocare și că capacitatea reflectă angajament real, fizic.

### 8.5 Atacuri de atribuire

PoCX folosește o mașină de stări deterministă pentru a guverna toate atribuirile plot-la-forger. Fiecare atribuire progresează prin stări bine definite - UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED - cu întârzieri de activare și revocare impuse. Aceasta asigură că un miner nu poate schimba instantaneu atribuirile pentru a frauda sistemul sau comuta rapid autoritatea de forjare.

Deoarece toate tranzițiile necesită dovezi criptografice - concret, semnături de către proprietarul plot-ului care sunt verificabile contra UTXO-ului de intrare - rețeaua poate avea încredere în legitimitatea fiecărei atribuiri. Încercările de a ocoli mașina de stări sau de a falsifica atribuiri sunt automat respinse în timpul validării consensului. Atacurile de reluare sunt de asemenea prevenite prin protecțiile standard Bitcoin de reluare a tranzacțiilor, asigurând că fiecare acțiune de atribuire este legată unic de o intrare validă, necheltuită.

Combinația de guvernare prin mașină de stări, întârzieri impuse și dovadă criptografică face fraudarea bazată pe atribuiri practic imposibilă: minerii nu pot deturna atribuiri, efectua reatribuire rapidă în timpul curselor de blocuri sau ocoli calendarele de revocare.

### 8.6 Securitatea semnăturilor

Semnăturile de bloc în PoCX servesc ca o legătură critică între o dovadă și cheia de forjare efectivă, asigurând că doar minerii autorizați pot produce blocuri valide.

Pentru a preveni atacurile de maleabilitate, semnăturile sunt excluse din calculul hash-ului blocului. Aceasta elimină riscurile semnăturilor maleabile care ar putea submina validarea sau permite atacuri de înlocuire a blocurilor.

Pentru a atenua vectorii de denial-of-service, dimensiunile semnăturilor și cheilor publice sunt fixe - 65 de octeți pentru semnături compacte și 33 de octeți pentru chei publice comprimate - prevenind atacatorii să umfle blocurile pentru a declanșa epuizarea resurselor sau să încetinească propagarea în rețea.

---

## 9. Implementare

PoCX este implementat ca o extensie modulară a Bitcoin Core, cu tot codul relevant conținut în propriul subdirector dedicat și activat printr-un flag de funcționalitate. Acest design păstrează integritatea codului original, permițând activarea sau dezactivarea curată a PoCX, ceea ce simplifică testarea, auditarea și sincronizarea cu modificările upstream.

Integrarea atinge doar punctele esențiale necesare pentru a suporta Proof of Capacity. Header-ul blocului a fost extins pentru a include câmpuri specifice PoCX, iar validarea consensului a fost adaptată pentru a procesa dovezile bazate pe stocare alături de verificările tradiționale Bitcoin. Sistemul de forjare, responsabil pentru gestionarea deadline-urilor, planificarea și trimiterile minerilor, este complet conținut în modulele PoCX, în timp ce extensiile RPC expun funcționalitatea de minerit și atribuiri clienților externi. Pentru utilizatori, interfața portofelului a fost îmbunătățită pentru a gestiona atribuirile prin tranzacții OP_RETURN, permițând interacțiune fără cusur cu noile funcționalități de consens.

Toate operațiunile critice pentru consens sunt implementate în C++ determinist fără dependențe externe, asigurând consistență cross-platformă. Shabal256 este folosit pentru hashing, în timp ce Time Bending și calculul calității se bazează pe aritmetică în virgulă fixă și operații pe 256 de biți. Operațiunile criptografice cum ar fi verificarea semnăturilor valorifică biblioteca secp256k1 existentă a Bitcoin Core.

Prin izolarea funcționalității PoCX în acest mod, implementarea rămâne auditabilă, mentenabilă și complet compatibilă cu dezvoltarea continuă a Bitcoin Core, demonstrând că un mecanism de consens nou, fundamental legat de stocare, poate coexista cu o bază de cod proof-of-work matură fără a-i perturba integritatea sau utilizabilitatea.

---

## 10. Parametri de rețea

PoCX construiește pe infrastructura de rețea a Bitcoin și reutilizează framework-ul său de parametri de lanț. Pentru a suporta mineritul bazat pe capacitate, intervalele de bloc, gestionarea atribuirilor și scalarea plot-urilor, mai mulți parametri au fost extinși sau suprascriși. Aceasta include ținta timpului de bloc, subvenția inițială, calendarul de înjumătățire, întârzierile de activare și revocare a atribuirilor, precum și identificatorii de rețea cum ar fi octeții magici, porturile și prefixele Bech32. Mediile testnet și regtest ajustează în continuare acești parametri pentru a permite iterație rapidă și testare cu capacitate redusă.

Tabelele de mai jos rezumă setările rezultate pentru mainnet, testnet și regtest, evidențiind modul în care PoCX adaptează parametrii de bază ai Bitcoin la un model de consens legat de stocare.

### 10.1 Mainnet

| Parametru | Valoare |
|-----------|---------|
| Octeți magici | `0xa7 0x3c 0x91 0x5e` |
| Port implicit | 8888 |
| HRP Bech32 | `pocx` |
| Ținta timp bloc | 120 secunde |
| Subvenție inițială | 10 BTC |
| Interval înjumătățire | 1050000 blocuri (~4 ani) |
| Ofertă totală | ~21 milioane BTC |
| Activare atribuire | 30 blocuri |
| Revocare atribuire | 720 blocuri |
| Fereastră rulantă | 24 blocuri |

### 10.2 Testnet

| Parametru | Valoare |
|-----------|---------|
| Octeți magici | `0x6d 0xf2 0x48 0xb3` |
| Port implicit | 18888 |
| HRP Bech32 | `tpocx` |
| Ținta timp bloc | 120 secunde |
| Alți parametri | La fel ca mainnet |

### 10.3 Regtest

| Parametru | Valoare |
|-----------|---------|
| Octeți magici | `0xfa 0xbf 0xb5 0xda` |
| Port implicit | 18444 |
| HRP Bech32 | `rpocx` |
| Ținta timp bloc | 1 secundă |
| Interval înjumătățire | 500 blocuri |
| Activare atribuire | 4 blocuri |
| Revocare atribuire | 8 blocuri |
| Mod capacitate redusă | Activat (plot-uri de ~4 MB) |

---

## 11. Lucrări conexe

De-a lungul anilor, mai multe proiecte blockchain și de consens au explorat modele de minerit bazate pe stocare sau hibride. PoCX construiește pe această linie păstrând în același timp îmbunătățiri în securitate, eficiență și compatibilitate.

**Burstcoin / Signum.** Burstcoin a introdus primul sistem practic Proof-of-Capacity (PoC) în 2014, definind concepte de bază precum plot-uri, nonce-uri, scoop-uri și minerit bazat pe deadline. Succesorii săi, în special Signum (fostul Burstcoin), au extins ecosistemul și în cele din urmă au evoluat în ceea ce este cunoscut ca Proof-of-Commitment (PoC+), combinând angajamentul de stocare cu staking opțional pentru a influența capacitatea efectivă. PoCX moștenește fundația de minerit bazată pe stocare de la aceste proiecte, dar diverge semnificativ prin format de plot întărit (codificare XOR-transpose), scalare dinamică a muncii de plot, netezirea deadline-urilor („Time Bending") și un sistem flexibil de atribuiri - toate acestea ancorate în baza de cod Bitcoin Core mai degrabă decât menținerea unui fork de rețea independent.

**Chia.** Chia implementează Proof of Space and Time, combinând dovezile de stocare bazate pe disc cu o componentă temporală impusă prin Verifiable Delay Functions (VDF-uri). Design-ul său abordează anumite preocupări legate de reutilizarea dovezilor și generarea de provocări proaspete, distincte de PoC clasic. PoCX nu adoptă acel model de dovadă ancorat temporal; în schimb, menține un consens legat de stocare cu intervale previzibile, optimizat pentru compatibilitate pe termen lung cu economia UTXO și instrumentele derivate din Bitcoin.

**Spacemesh.** Spacemesh propune o schemă Proof-of-Space-Time (PoST) folosind o topologie de rețea bazată pe DAG (mesh). În acest model, participanții trebuie să demonstreze periodic că stocarea alocată rămâne intactă în timp, mai degrabă decât să se bazeze pe un singur set de date precalculate. PoCX, în schimb, verifică angajamentul de stocare doar la momentul blocului - cu formate de plot întărite și validare riguroasă a dovezilor - evitând overhead-ul dovezilor continue de stocare păstrând în același timp eficiența și descentralizarea.

---

## 12. Concluzie

Bitcoin-PoCX demonstrează că consensul eficient energetic poate fi integrat în Bitcoin Core păstrând proprietățile de securitate și modelul economic. Contribuțiile cheie includ codificarea XOR-transpose (forțează atacatorii să calculeze 4096 nonce-uri per căutare, eliminând atacul de compresie), algoritmul Time Bending (transformarea distribuției reduce varianța timpului de bloc), sistemul de atribuire a forjării (delegarea bazată pe OP_RETURN permite mineritul în pool non-custodial), scalarea dinamică (aliniată cu înjumătățirile pentru a menține marjele de securitate) și integrarea minimă (cod marcat cu flag-uri de funcționalitate izolat într-un director dedicat).

Sistemul este momentan în faza testnet. Puterea de minerit derivă din capacitatea de stocare mai degrabă decât din rata de hash, reducând consumul de energie cu ordine de mărime păstrând în același timp modelul economic dovedit al Bitcoin.

---

## Referințe

Bitcoin Core. *Bitcoin Core Repository.* https://github.com/bitcoin/bitcoin

Burstcoin. *Proof of Capacity Technical Documentation.* 2014.

NIST. *SHA-3 Competition: Shabal.* 2008.

Cohen, B., Pietrzak, K. *The Chia Network Blockchain.* 2019.

Spacemesh. *Spacemesh Protocol Documentation.* 2021.

PoC Consortium. *PoCX Framework.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Bitcoin-PoCX Integration.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Licență**: MIT
**Organizație**: Proof of Capacity Consortium
**Stare**: Fază Testnet
