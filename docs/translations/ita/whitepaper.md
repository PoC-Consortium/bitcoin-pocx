# Bitcoin-PoCX: Consenso a efficienza energetica per Bitcoin Core

**Versione**: 2.0 Bozza
**Data**: Dicembre 2025
**Organizzazione**: Proof of Capacity Consortium

---

## Abstract

Il consenso Proof-of-Work (PoW) di Bitcoin fornisce una sicurezza robusta ma consuma energia sostanziale a causa del calcolo continuo di hash in tempo reale. Presentiamo Bitcoin-PoCX, un fork di Bitcoin che sostituisce il PoW con il Proof of Capacity (PoC), dove i miner pre-calcolano e memorizzano grandi set di hash su disco durante il plotting e successivamente minano effettuando lookup leggeri invece di hashing continuo. Spostando il calcolo dalla fase di mining a una fase di plotting una tantum, Bitcoin-PoCX riduce drasticamente il consumo energetico abilitando al contempo il mining su hardware commodity, abbassando le barriere alla partecipazione e mitigando le pressioni di centralizzazione intrinseche nel PoW dominato dagli ASIC, il tutto preservando le assunzioni di sicurezza e il comportamento economico di Bitcoin.

La nostra implementazione introduce diverse innovazioni chiave:
(1) Un formato plot rafforzato che elimina tutti gli attacchi noti di compromesso tempo-memoria nei sistemi PoC esistenti, assicurando che la potenza di mining effettiva rimanga strettamente proporzionale alla capacità di storage impegnata;
(2) L'algoritmo Time-Bending, che trasforma le distribuzioni delle deadline da esponenziale a chi-quadrato, riducendo la varianza dei tempi di blocco senza alterare la media;
(3) Un meccanismo di assegnazione del forging basato su OP_RETURN che abilita il mining in pool non custodiale; e
(4) Lo scaling dinamico della compressione, che aumenta la difficoltà di generazione dei plot in allineamento con i programmi di halving per mantenere i margini di sicurezza a lungo termine man mano che l'hardware migliora.

Bitcoin-PoCX mantiene l'architettura di Bitcoin Core attraverso modifiche minime e contrassegnate con feature flag, isolando la logica PoC dal codice di consenso esistente. Il sistema preserva la politica monetaria di Bitcoin puntando a un intervallo di blocco di 120 secondi e regolando il sussidio di blocco a 10 BTC. Il sussidio ridotto compensa l'aumento di cinque volte della frequenza dei blocchi, mantenendo il tasso di emissione a lungo termine allineato con il programma originale di Bitcoin e conservando l'offerta massima di ~21 milioni.

---

## 1. Introduzione

### 1.1 Motivazione

Il consenso Proof-of-Work (PoW) di Bitcoin si è dimostrato sicuro per oltre un decennio, ma a un costo significativo: i miner devono spendere continuamente risorse computazionali, risultando in un elevato consumo energetico. Oltre alle preoccupazioni sull'efficienza, c'è una motivazione più ampia: esplorare meccanismi di consenso alternativi che mantengano la sicurezza abbassando al contempo le barriere alla partecipazione. Il PoC permette virtualmente a chiunque abbia hardware di storage commodity di minare efficacemente, riducendo le pressioni di centralizzazione osservate nel mining PoW dominato dagli ASIC.

Il Proof of Capacity (PoC) raggiunge questo obiettivo derivando la potenza di mining dall'impegno di storage piuttosto che dal calcolo continuo. I miner pre-calcolano grandi set di hash memorizzati su disco, i plot, durante una fase di plotting una tantum. Il mining consiste quindi in lookup leggeri, riducendo drasticamente l'uso di energia preservando al contempo le assunzioni di sicurezza del consenso basato sulle risorse.

### 1.2 Integrazione con Bitcoin Core

Bitcoin-PoCX integra il consenso PoC in Bitcoin Core piuttosto che creare una nuova blockchain. Questo approccio sfrutta la sicurezza comprovata di Bitcoin Core, lo stack di networking maturo e gli strumenti ampiamente adottati, mantenendo al contempo le modifiche minime e contrassegnate con feature flag. La logica PoC è isolata dal codice di consenso esistente, assicurando che le funzionalità core, validazione dei blocchi, operazioni del wallet, formati delle transazioni, rimangano in gran parte invariate.

### 1.3 Obiettivi di progettazione

**Sicurezza**: Mantenere una robustezza equivalente a Bitcoin; gli attacchi richiedono la capacità di storage maggioritaria.

**Efficienza**: Ridurre il carico computazionale continuo ai livelli di I/O su disco.

**Accessibilità**: Abilitare il mining con hardware commodity, abbassando le barriere all'ingresso.

**Integrazione minima**: Introdurre il consenso PoC con un'impronta di modifica minima.

---

## 2. Background: Proof of Capacity

### 2.1 Storia

Il Proof of Capacity (PoC) è stato introdotto da Burstcoin nel 2014 come alternativa a efficienza energetica al Proof-of-Work (PoW). Burstcoin ha dimostrato che la potenza di mining poteva essere derivata dallo storage impegnato piuttosto che dall'hashing continuo in tempo reale: i miner pre-calcolavano grandi dataset ("plot") una volta e poi minavano leggendo piccole porzioni fisse di essi.

Le prime implementazioni PoC hanno dimostrato la fattibilità del concetto ma hanno anche rivelato che il formato dei plot e la struttura crittografica sono critici per la sicurezza. Diversi compromessi tempo-memoria hanno permesso agli attaccanti di minare efficacemente con meno storage rispetto ai partecipanti onesti. Questo ha evidenziato che la sicurezza del PoC dipende dal design dei plot, non semplicemente dall'uso dello storage come risorsa.

L'eredità di Burstcoin ha stabilito il PoC come meccanismo di consenso pratico e ha fornito le fondamenta su cui PoCX costruisce.

### 2.2 Concetti fondamentali

Il mining PoC si basa su grandi file plot pre-calcolati memorizzati su disco. Questi plot contengono "calcolo congelato": l'hashing costoso viene eseguito una volta durante il plotting, e il mining consiste quindi in letture leggere dal disco e semplice verifica. Gli elementi fondamentali includono:

**Nonce:**
L'unità base dei dati del plot. Ogni nonce contiene 4096 scoop (256 KiB totali) generati tramite Shabal256 dall'indirizzo del miner e dall'indice del nonce.

**Scoop:**
Un segmento da 64 byte all'interno di un nonce. Per ogni blocco, la rete seleziona deterministicamente un indice di scoop (0-4095) basato sulla generation signature del blocco precedente. Solo questo scoop per nonce deve essere letto.

**Generation Signature:**
Un valore a 256 bit derivato dal blocco precedente. Fornisce entropia per la selezione dello scoop e impedisce ai miner di prevedere gli indici di scoop futuri.

**Warp:**
Un gruppo strutturale di 4096 nonce (1 GiB). I warp sono l'unità rilevante per i formati plot resistenti alla compressione.

### 2.3 Processo di mining e pipeline della qualità

Il mining PoC consiste in un passo di plotting una tantum e una routine leggera per ogni blocco:

**Setup una tantum:**
- Generazione del plot: Calcolare i nonce tramite Shabal256 e scriverli su disco.

**Mining per blocco:**
- Selezione dello scoop: Determinare l'indice dello scoop dalla generation signature.
- Scansione del plot: Leggere quello scoop da tutti i nonce nei plot del miner.

**Pipeline della qualità:**
- Qualità raw: Hashare ogni scoop con la generation signature usando Shabal256Lite per ottenere un valore di qualità a 64 bit (più basso è migliore).
- Deadline: Convertire la qualità in una deadline usando il base target (un parametro regolato per difficoltà che assicura che la rete raggiunga l'intervallo di blocco target): `deadline = quality / base_target`
- Deadline piegata: Applicare la trasformazione Time-Bending per ridurre la varianza preservando il tempo di blocco atteso.

**Forging del blocco:**
Il miner con la deadline (piegata) più breve forgia il blocco successivo una volta trascorso quel tempo.

A differenza del PoW, quasi tutto il calcolo avviene durante il plotting; il mining attivo è principalmente limitato dal disco e a bassissimo consumo energetico.

### 2.4 Vulnerabilità note nei sistemi precedenti

**Difetto nella distribuzione POC1:**
Il formato POC1 originale di Burstcoin mostrava un bias strutturale: gli scoop a indice basso erano significativamente meno costosi da ricalcolare al volo rispetto agli scoop a indice alto. Questo introduceva un compromesso tempo-memoria non uniforme, permettendo agli attaccanti di ridurre lo storage richiesto per quegli scoop e rompendo l'assunzione che tutti i dati pre-calcolati fossero ugualmente costosi.

**Attacco di compressione XOR (POC2):**
In POC2, un attaccante può prendere qualsiasi set di 8192 nonce e partizionarli in due blocchi di 4096 nonce (A e B). Invece di memorizzare entrambi i blocchi, l'attaccante memorizza solo una struttura derivata: `A ⊕ transpose(B)`, dove la trasposizione scambia gli indici di scoop e nonce, lo scoop S del nonce N nel blocco B diventa lo scoop N del nonce S.

Durante il mining, quando serve lo scoop S del nonce N, l'attaccante lo ricostruisce:
1. Leggendo il valore XOR memorizzato alla posizione (S, N)
2. Calcolando il nonce N dal blocco A per ottenere lo scoop S
3. Calcolando il nonce S dal blocco B per ottenere lo scoop N trasposto
4. Effettuando lo XOR di tutti e tre i valori per recuperare lo scoop originale da 64 byte

Questo riduce lo storage del 50%, richiedendo solo due calcoli di nonce per lookup, un costo molto al di sotto della soglia necessaria per imporre la pre-computazione completa. L'attacco è praticabile perché calcolare una riga (un nonce, 4096 scoop) è poco costoso, mentre calcolare una colonna (un singolo scoop attraverso 4096 nonce) richiederebbe di rigenerare tutti i nonce. La struttura trasposta espone questo squilibrio.

Questo ha dimostrato la necessità di un formato plot che prevenga tale ricombinazione strutturata e rimuova il sottostante compromesso tempo-memoria. La Sezione 3.3 descrive come PoCX affronta e risolve questa debolezza.

### 2.5 Transizione a PoCX

Le limitazioni dei sistemi PoC precedenti hanno reso chiaro che il mining basato su storage sicuro, equo e decentralizzato dipende da strutture dei plot attentamente ingegnerizzate. Bitcoin-PoCX affronta questi problemi con un formato plot rafforzato, una distribuzione delle deadline migliorata e meccanismi per il mining in pool decentralizzato, descritti nella prossima sezione.

---

## 3. Formato plot PoCX

### 3.1 Costruzione del nonce base

Un nonce è una struttura dati da 256 KiB derivata deterministicamente da tre parametri: un payload indirizzo da 20 byte, un seed da 32 byte e un indice nonce a 64 bit.

La costruzione inizia combinando questi input e hashandoli con Shabal256 per produrre un hash iniziale. Questo hash serve come punto di partenza per un processo di espansione iterativo: Shabal256 viene applicato ripetutamente, con ogni passo che dipende dai dati generati precedentemente, fino a riempire l'intero buffer da 256 KiB. Questo processo concatenato rappresenta il lavoro computazionale eseguito durante il plotting.

Un passo finale di diffusione hasha il buffer completato e effettua lo XOR del risultato su tutti i byte. Questo assicura che l'intero buffer sia stato calcolato e che i miner non possano abbreviare il calcolo. Viene poi applicato lo shuffle POC2, che scambia le metà inferiore e superiore di ogni scoop per garantire che tutti gli scoop richiedano uno sforzo computazionale equivalente.

Il nonce finale consiste di 4096 scoop da 64 byte ciascuno e forma l'unità fondamentale usata nel mining.

### 3.2 Layout del plot allineato SIMD

Per massimizzare il throughput sull'hardware moderno, PoCX organizza i dati dei nonce su disco per facilitare l'elaborazione vettorizzata. Invece di memorizzare ogni nonce sequenzialmente, PoCX allinea le word da 4 byte corrispondenti attraverso più nonce consecutivi in modo contiguo. Questo permette a un singolo fetch di memoria di fornire dati per tutte le lane SIMD, minimizzando i cache miss ed eliminando l'overhead scatter-gather.

```
Layout tradizionale:
Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

Layout SIMD PoCX:
Word0: [N0][N1][N2]...[N15]
Word1: [N0][N1][N2]...[N15]
Word2: [N0][N1][N2]...[N15]
```

Questo layout beneficia sia i miner CPU che GPU, abilitando una valutazione degli scoop ad alto throughput e parallelizzata mantenendo al contempo un pattern di accesso scalare semplice per la verifica del consenso. Assicura che il mining sia limitato dalla larghezza di banda dello storage piuttosto che dal calcolo CPU, mantenendo la natura a basso consumo del Proof of Capacity.

### 3.3 Struttura dei warp e codifica XOR-Transpose

Un warp è l'unità di storage fondamentale in PoCX, composta da 4096 nonce (1 GiB). Il formato non compresso, riferito come X0, contiene i nonce base esattamente come prodotti dalla costruzione nella Sezione 3.1.

**Codifica XOR-Transpose (X1)**

Per rimuovere i compromessi strutturali tempo-memoria presenti nei sistemi PoC precedenti, PoCX deriva un formato di mining rafforzato, X1, applicando una codifica XOR-transpose a coppie di warp X0.

Per costruire lo scoop S del nonce N in un warp X1:

1. Prendere lo scoop S del nonce N dal primo warp X0 (posizione diretta)
2. Prendere lo scoop N del nonce S dal secondo warp X0 (posizione trasposta)
3. Effettuare lo XOR dei due valori da 64 byte per ottenere lo scoop X1

Il passo di trasposizione scambia gli indici di scoop e nonce. In termini matriciali, dove le righe rappresentano gli scoop e le colonne rappresentano i nonce, combina l'elemento alla posizione (S, N) nel primo warp con l'elemento alla posizione (N, S) nel secondo.

**Perché questo elimina la superficie di attacco della compressione**

La codifica XOR-transpose interconnette ogni scoop con un'intera riga e un'intera colonna dei dati X0 sottostanti. Recuperare un singolo scoop X1 richiede quindi l'accesso a dati che coprono tutti i 4096 indici di scoop. Qualsiasi tentativo di calcolare i dati mancanti richiederebbe di rigenerare 4096 nonce completi, piuttosto che un singolo nonce, rimuovendo la struttura dei costi asimmetrica sfruttata dall'attacco XOR per POC2 (Sezione 2.4).

Di conseguenza, memorizzare l'intero warp X1 diventa l'unica strategia computazionalmente praticabile per i miner, chiudendo il compromesso tempo-memoria sfruttato nei design precedenti.

### 3.4 Layout su disco

I file plot PoCX consistono di molti warp X1 consecutivi. Per massimizzare l'efficienza operativa durante il mining, i dati all'interno di ogni file sono organizzati per scoop: tutti i dati dello scoop 0 da ogni warp sono memorizzati sequenzialmente, seguiti da tutti i dati dello scoop 1, e così via, fino allo scoop 4095.

Questo **ordinamento sequenziale per scoop** permette ai miner di leggere i dati completi richiesti per uno scoop selezionato in un singolo accesso sequenziale al disco, minimizzando i tempi di seek e massimizzando il throughput sui dispositivi di storage commodity.

Combinato con la codifica XOR-transpose della Sezione 3.3, questo layout assicura che il file sia sia **strutturalmente rafforzato** che **operativamente efficiente**: l'ordinamento sequenziale degli scoop supporta l'I/O su disco ottimale, mentre i layout di memoria allineati SIMD (vedi Sezione 3.2) permettono una valutazione degli scoop ad alto throughput e parallelizzata.

### 3.5 Scaling del Proof-of-Work (Xn)

PoCX implementa la pre-computazione scalabile attraverso il concetto di livelli di scaling, denotati Xn, per adattarsi all'evoluzione delle prestazioni hardware. Il formato baseline X1 rappresenta la prima struttura warp rafforzata XOR-transpose.

Ogni livello di scaling Xn aumenta il proof-of-work incorporato in ogni warp esponenzialmente rispetto a X1: il lavoro richiesto al livello Xn è 2^(n-1) volte quello di X1. La transizione da Xn a Xn+1 è operativamente equivalente all'applicazione di uno XOR attraverso coppie di warp adiacenti, incorporando incrementalmente più proof-of-work senza cambiare la dimensione del plot sottostante.

I file plot esistenti creati a livelli di scaling inferiori possono ancora essere usati per il mining, ma contribuiscono proporzionalmente meno lavoro verso la generazione dei blocchi, riflettendo il loro proof-of-work incorporato inferiore. Questo meccanismo assicura che i plot PoCX rimangano sicuri, flessibili ed economicamente bilanciati nel tempo.

### 3.6 Funzionalità seed

Il parametro seed abilita plot multipli non sovrapposti per indirizzo senza coordinamento manuale.

**Problema (POC2)**: I miner dovevano tracciare manualmente gli intervalli di nonce attraverso i file plot per evitare sovrapposizioni. I nonce sovrapposti sprecano storage senza aumentare la potenza di mining.

**Soluzione**: Ogni coppia `(indirizzo, seed)` definisce uno spazio delle chiavi indipendente. I plot con seed diversi non si sovrappongono mai, indipendentemente dagli intervalli di nonce. I miner possono creare plot liberamente senza coordinamento.

---

## 4. Consenso Proof of Capacity

PoCX estende il consenso Nakamoto di Bitcoin con un meccanismo di prova vincolato allo storage. Invece di spendere energia in hashing ripetuto, i miner impegnano grandi quantità di dati pre-calcolati, i plot, su disco. Durante la generazione dei blocchi, devono localizzare una piccola porzione imprevedibile di questi dati e trasformarla in una prova. Il miner che fornisce la migliore prova entro la finestra temporale attesa guadagna il diritto di forgiare il blocco successivo.

Questo capitolo descrive come PoCX struttura i metadati dei blocchi, deriva l'imprevedibilità e trasforma lo storage statico in un meccanismo di consenso sicuro a bassa varianza.

### 4.1 Struttura dei blocchi

PoCX mantiene il familiare header dei blocchi in stile Bitcoin ma introduce campi di consenso aggiuntivi richiesti per il mining basato sulla capacità. Questi campi legano collettivamente il blocco al plot memorizzato del miner, alla difficoltà della rete e all'entropia crittografica che definisce ogni sfida di mining.

Ad alto livello, un blocco PoCX contiene: l'altezza del blocco, registrata esplicitamente per semplificare la validazione contestuale; la generation signature, una fonte di entropia fresca che collega ogni blocco al suo predecessore; il base target, che rappresenta la difficoltà della rete in forma inversa (valori più alti corrispondono a mining più facile); la prova PoCX, che identifica il plot del miner, il livello di compressione usato durante il plotting, il nonce selezionato e la qualità derivata da esso; e una chiave di firma e firma, che dimostrano il controllo della capacità usata per forgiare il blocco (o di una chiave di forging assegnata).

La prova incorpora tutte le informazioni rilevanti per il consenso necessarie ai validatori per ricalcolare la sfida, verificare lo scoop scelto e confermare la qualità risultante. Estendendo piuttosto che riprogettando la struttura dei blocchi, PoCX rimane concettualmente allineato con Bitcoin abilitando al contempo una fonte fondamentalmente diversa di lavoro di mining.

### 4.2 Catena delle generation signature

La generation signature fornisce l'imprevedibilità richiesta per il mining Proof of Capacity sicuro. Ogni blocco deriva la sua generation signature dalla firma e dal firmatario del blocco precedente, assicurando che i miner non possano anticipare le sfide future o pre-calcolare regioni vantaggiose del plot:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

Questo produce una sequenza di valori di entropia crittograficamente forti e dipendenti dal miner. Poiché la chiave pubblica di un miner è sconosciuta fino alla pubblicazione del blocco precedente, nessun partecipante può prevedere le future selezioni di scoop. Questo previene la pre-computazione selettiva o il plotting strategico e assicura che ogni blocco introduca lavoro di mining genuinamente fresco.

### 4.3 Processo di forging

Il mining in PoCX consiste nel trasformare i dati memorizzati in una prova guidata interamente dalla generation signature. Sebbene il processo sia deterministico, l'imprevedibilità della firma assicura che i miner non possano prepararsi in anticipo e debbano accedere ripetutamente ai loro plot memorizzati.

**Derivazione della sfida (selezione dello scoop):** Il miner hasha la generation signature corrente con l'altezza del blocco per ottenere un indice di scoop nell'intervallo 0-4095. Questo indice determina quale segmento da 64 byte di ogni nonce memorizzato partecipa alla prova. Poiché la generation signature dipende dal firmatario del blocco precedente, la selezione dello scoop diventa nota solo al momento della pubblicazione del blocco.

**Valutazione della prova (calcolo della qualità):** Per ogni nonce in un plot, il miner recupera lo scoop selezionato e lo hasha insieme alla generation signature per ottenere una qualità, un valore a 64 bit la cui magnitudine determina la competitività del miner. Una qualità più bassa corrisponde a una prova migliore.

**Formazione della deadline (Time Bending):** La deadline raw è proporzionale alla qualità e inversamente proporzionale al base target. Nei design PoC legacy, queste deadline seguivano una distribuzione esponenziale altamente asimmetrica, producendo ritardi con code lunghe che non fornivano sicurezza aggiuntiva. PoCX trasforma la deadline raw usando il Time Bending (Sezione 4.4), riducendo la varianza e assicurando intervalli di blocco prevedibili. Una volta trascorsa la deadline piegata, il miner forgia un blocco incorporando la prova e firmandolo con la chiave di forging effettiva.

### 4.4 Time Bending

Il Proof of Capacity produce deadline distribuite esponenzialmente. Dopo un breve periodo, tipicamente alcune decine di secondi, ogni miner ha già identificato la sua migliore prova, e qualsiasi tempo di attesa aggiuntivo contribuisce solo latenza, non sicurezza.

Il Time Bending rimodella la distribuzione applicando una trasformazione a radice cubica:

`deadline_piegata = scala × (quality / base_target)^(1/3)`

Il fattore di scala preserva il tempo di blocco atteso (120 secondi) riducendo drasticamente la varianza. Le deadline brevi vengono espanse, migliorando la propagazione dei blocchi e la sicurezza della rete. Le deadline lunghe vengono compresse, impedendo agli outlier di ritardare la catena.

![Distribuzioni dei tempi di blocco](blocktime_distributions.svg)

Il Time Bending mantiene il contenuto informativo della prova sottostante. Non modifica la competitività tra i miner; riallocca solo il tempo di attesa per produrre intervalli di blocco più fluidi e prevedibili. L'implementazione usa aritmetica a virgola fissa (formato Q42) e interi a 256 bit per assicurare risultati deterministici su tutte le piattaforme.

### 4.5 Regolazione della difficoltà

PoCX regola la produzione dei blocchi usando il base target, una misura inversa della difficoltà. Il tempo di blocco atteso è proporzionale al rapporto `quality / base_target`, quindi aumentare il base target accelera la creazione dei blocchi mentre diminuirlo rallenta la catena.

La difficoltà si regola ad ogni blocco usando il tempo misurato tra i blocchi recenti rispetto all'intervallo target. Questa regolazione frequente è necessaria perché la capacità di storage può essere aggiunta o rimossa rapidamente, a differenza dell'hashpower di Bitcoin, che cambia più lentamente.

La regolazione segue due vincoli guida: **Gradualità**, le modifiche per blocco sono limitate (±20% massimo) per evitare oscillazioni o manipolazioni; **Rafforzamento**, il base target non può superare il suo valore genesis, impedendo alla rete di abbassare mai la difficoltà sotto le assunzioni di sicurezza originali.

### 4.6 Validità dei blocchi

Un blocco in PoCX è valido quando presenta una prova derivata dallo storage verificabile e consistente con lo stato del consenso. I validatori ricalcolano indipendentemente la selezione dello scoop, derivano la qualità attesa dal nonce inviato e dai metadati del plot, applicano la trasformazione Time Bending e confermano che il miner era idoneo a forgiare il blocco al momento dichiarato.

Specificamente, un blocco valido richiede: la deadline è trascorsa dal blocco padre; la qualità inviata corrisponde alla qualità calcolata per la prova; il livello di scaling soddisfa il minimo della rete; la generation signature corrisponde al valore atteso; il base target corrisponde al valore atteso; la firma del blocco proviene dal firmatario effettivo; e il coinbase paga all'indirizzo del firmatario effettivo.

---

## 5. Assegnazioni di forging

### 5.1 Motivazione

Le assegnazioni di forging permettono ai proprietari dei plot di delegare l'autorità di forging dei blocchi senza mai cedere la proprietà dei loro plot. Questo meccanismo abilita il mining in pool e le configurazioni di cold storage preservando al contempo le garanzie di sicurezza di PoCX.

Nel mining in pool, i proprietari dei plot possono autorizzare un pool a forgiare blocchi per loro conto. Il pool assembla i blocchi e distribuisce le ricompense, ma non ottiene mai la custodia dei plot stessi. La delega è revocabile in qualsiasi momento, e i proprietari dei plot rimangono liberi di lasciare un pool o cambiare configurazioni senza dover rifare il plotting.

Le assegnazioni supportano anche una netta separazione tra chiavi cold e hot. La chiave privata che controlla il plot può rimanere offline, mentre una chiave di forging separata, memorizzata su una macchina online, produce i blocchi. Una compromissione della chiave di forging quindi compromette solo l'autorità di forging, non la proprietà. Il plot rimane al sicuro e l'assegnazione può essere revocata, chiudendo immediatamente la falla di sicurezza.

Le assegnazioni di forging forniscono quindi flessibilità operativa mantenendo il principio che il controllo sulla capacità memorizzata non deve mai essere trasferito a intermediari.

### 5.2 Protocollo delle assegnazioni

Le assegnazioni sono dichiarate attraverso transazioni OP_RETURN per evitare la crescita non necessaria del set UTXO. Una transazione di assegnazione specifica l'indirizzo del plot e l'indirizzo di forging che è autorizzato a produrre blocchi usando la capacità di quel plot. Una transazione di revoca contiene solo l'indirizzo del plot. In entrambi i casi, il proprietario del plot dimostra il controllo firmando l'input di spesa della transazione.

Ogni assegnazione progredisce attraverso una sequenza di stati ben definiti (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Dopo che una transazione di assegnazione viene confermata, il sistema entra in una breve fase di attivazione. Questo ritardo, 30 blocchi, circa un'ora, assicura la stabilità durante le competizioni per i blocchi e previene il cambio rapido e adversariale delle identità di forging. Una volta che questo periodo di attivazione scade, l'assegnazione diventa attiva e rimane tale fino a quando il proprietario del plot emette una revoca.

Le revoche transitano in un periodo di ritardo più lungo di 720 blocchi, circa un giorno. Durante questo tempo, il precedente indirizzo di forging rimane attivo. Questo ritardo più lungo fornisce stabilità operativa per i pool, prevenendo lo "assignment hopping" strategico e dando ai fornitori di infrastruttura abbastanza certezza per operare efficientemente. Dopo che il ritardo di revoca scade, la revoca si completa, e il proprietario del plot è libero di designare una nuova chiave di forging.

Lo stato delle assegnazioni è mantenuto in una struttura a livello di consenso parallela al set UTXO e supporta dati di undo per la gestione sicura delle riorganizzazioni della catena.

### 5.3 Regole di validazione

Per ogni blocco, i validatori determinano il firmatario effettivo, l'indirizzo che deve firmare il blocco e ricevere la ricompensa coinbase. Questo firmatario dipende solamente dallo stato dell'assegnazione all'altezza del blocco.

Se non esiste alcuna assegnazione o l'assegnazione non ha ancora completato la sua fase di attivazione, il proprietario del plot rimane il firmatario effettivo. Una volta che un'assegnazione diventa attiva, l'indirizzo di forging assegnato deve firmare. Durante la revoca, l'indirizzo di forging continua a firmare fino alla scadenza del ritardo di revoca. Solo allora l'autorità ritorna al proprietario del plot.

I validatori impongono che la firma del blocco sia prodotta dal firmatario effettivo, che il coinbase paghi allo stesso indirizzo, e che tutte le transizioni seguano i ritardi di attivazione e revoca prescritti. Solo il proprietario del plot può creare o revocare assegnazioni; le chiavi di forging non possono modificare o estendere i propri permessi.

Le assegnazioni di forging introducono quindi una delega flessibile senza introdurre fiducia. La proprietà della capacità sottostante rimane sempre crittograficamente ancorata al proprietario del plot, mentre l'autorità di forging può essere delegata, ruotata o revocata secondo le esigenze operative.

---

## 6. Scaling dinamico

Man mano che l'hardware evolve, il costo di calcolo dei plot diminuisce rispetto alla lettura del lavoro pre-calcolato dal disco. Senza contromisure, gli attaccanti potrebbero eventualmente generare prove al volo più velocemente di quanto i miner leggano il lavoro memorizzato, minando il modello di sicurezza del Proof of Capacity.

Per preservare il margine di sicurezza previsto, PoCX implementa un programma di scaling: il livello di scaling minimo richiesto per i plot aumenta nel tempo. Ogni livello di scaling Xn, come descritto nella Sezione 3.5, incorpora esponenzialmente più proof-of-work nella struttura del plot, assicurando che i miner continuino a impegnare risorse di storage sostanziali anche man mano che il calcolo diventa più economico.

Il programma si allinea con gli incentivi economici della rete, in particolare gli halving delle ricompense dei blocchi. Man mano che la ricompensa per blocco diminuisce, il livello minimo aumenta gradualmente, preservando l'equilibrio tra sforzo di plotting e potenziale di mining:

| Periodo | Anni | Halving | Scaling min | Moltiplicatore lavoro plot |
|---------|------|---------|-------------|---------------------------|
| Epoca 0 | 0-4 | 0 | X1 | 2× baseline |
| Epoca 1 | 4-12 | 1-2 | X2 | 4× baseline |
| Epoca 2 | 12-28 | 3-6 | X3 | 8× baseline |
| Epoca 3 | 28-60 | 7-14 | X4 | 16× baseline |
| Epoca 4 | 60-124 | 15-30 | X5 | 32× baseline |
| Epoca 5 | 124+ | 31+ | X6 | 64× baseline |

I miner possono opzionalmente preparare plot che superano di un livello il minimo corrente, permettendo loro di pianificare in anticipo ed evitare aggiornamenti immediati quando la rete transita all'epoca successiva. Questo passo opzionale non conferisce un vantaggio aggiuntivo in termini di probabilità di blocco, permette semplicemente una transizione operativa più fluida.

I blocchi contenenti prove sotto il livello di scaling minimo per la loro altezza sono considerati non validi. I validatori controllano il livello di scaling dichiarato nella prova rispetto al requisito corrente della rete durante la validazione del consenso, assicurando che tutti i miner partecipanti soddisfino le aspettative di sicurezza in evoluzione.

---

## 7. Architettura del mining

PoCX separa le operazioni critiche per il consenso dai compiti ad alta intensità di risorse del mining, abilitando sia sicurezza che efficienza. Il nodo mantiene la blockchain, valida i blocchi, gestisce la mempool ed espone un'interfaccia RPC. I miner esterni gestiscono lo storage dei plot, la lettura degli scoop, il calcolo della qualità e la gestione delle deadline. Questa separazione mantiene la logica del consenso semplice e verificabile permettendo ai miner di ottimizzare per il throughput del disco.

### 7.1 Interfaccia RPC per il mining

I miner interagiscono con il nodo attraverso un set minimo di chiamate RPC. L'RPC get_mining_info fornisce l'altezza del blocco corrente, la generation signature, il base target, la deadline target e l'intervallo accettabile dei livelli di scaling dei plot. Usando queste informazioni, i miner calcolano i nonce candidati. L'RPC submit_nonce permette ai miner di inviare una soluzione proposta, incluso l'identificatore del plot, l'indice del nonce, il livello di scaling e l'account del miner. Il nodo valuta l'invio e risponde con la deadline calcolata se la prova è valida.

### 7.2 Scheduler del forging

Il nodo mantiene uno scheduler del forging, che traccia gli invii in arrivo e mantiene solo la migliore soluzione per ogni altezza di blocco. I nonce inviati sono messi in coda con protezioni integrate contro il flooding degli invii o attacchi denial-of-service. Lo scheduler attende fino alla scadenza della deadline calcolata o all'arrivo di una soluzione superiore, a quel punto assembla un blocco, lo firma usando la chiave di forging effettiva e lo pubblica nella rete.

### 7.3 Forging difensivo

Per prevenire attacchi di timing o incentivi alla manipolazione dell'orologio, PoCX implementa il forging difensivo. Se arriva un blocco concorrente per la stessa altezza, lo scheduler confronta la soluzione locale con il nuovo blocco. Se la qualità locale è superiore, il nodo forgia immediatamente piuttosto che attendere la deadline originale. Questo assicura che i miner non possano ottenere un vantaggio semplicemente regolando gli orologi locali; la soluzione migliore prevale sempre, preservando l'equità e la sicurezza della rete.

---

## 8. Analisi della sicurezza

### 8.1 Modello delle minacce

PoCX modella avversari con capacità sostanziali ma limitate. Gli attaccanti possono tentare di sovraccaricare la rete con transazioni non valide, blocchi malformati o prove fabbricate per stressare i percorsi di validazione. Possono manipolare liberamente i loro orologi locali e possono cercare di sfruttare casi limite nel comportamento del consenso come la gestione dei timestamp, le dinamiche di regolazione della difficoltà o le regole di riorganizzazione. Ci si aspetta anche che gli avversari sondino opportunità per riscrivere la storia attraverso fork mirati della catena.

Il modello assume che nessuna singola parte controlli la maggioranza della capacità di storage totale della rete. Come con qualsiasi meccanismo di consenso basato sulle risorse, un attaccante con capacità del 51% può riorganizzare unilateralmente la catena; questa limitazione fondamentale non è specifica di PoCX. PoCX assume anche che gli attaccanti non possano calcolare i dati dei plot più velocemente di quanto i miner onesti possano leggerli dal disco. Il programma di scaling (Sezione 6) assicura che il gap computazionale richiesto per la sicurezza cresca nel tempo man mano che l'hardware migliora.

Le sezioni seguenti esaminano ogni principale classe di attacco in dettaglio e descrivono le contromisure integrate in PoCX.

### 8.2 Attacchi alla capacità

Come il PoW, un attaccante con capacità maggioritaria può riscrivere la storia (un attacco del 51%). Raggiungere questo richiede l'acquisizione di un'impronta di storage fisica più grande della rete onesta, un'impresa costosa e logisticamente impegnativa. Una volta ottenuto l'hardware, i costi operativi sono bassi, ma l'investimento iniziale crea un forte incentivo economico a comportarsi onestamente: minare la catena danneggerebbe il valore della base di asset dell'attaccante stesso.

Il PoC evita anche il problema nothing-at-stake associato al PoS. Sebbene i miner possano scansionare i plot contro fork multipli concorrenti, ogni scansione consuma tempo reale, tipicamente nell'ordine di decine di secondi per catena. Con un intervallo di blocco di 120 secondi, questo limita intrinsecamente il mining multi-fork, e tentare di minare molti fork simultaneamente degrada le prestazioni su tutti. Il mining di fork non è quindi gratuito; è fondamentalmente vincolato dal throughput di I/O.

Anche se hardware futuro permettesse la scansione dei plot quasi istantanea (es., SSD ad alta velocità), un attaccante affronterebbe comunque un requisito sostanziale di risorse fisiche per controllare la maggioranza della capacità della rete, rendendo un attacco in stile 51% costoso e logisticamente impegnativo.

Infine, gli attacchi alla capacità sono molto più difficili da noleggiare rispetto agli attacchi all'hashpower. Il calcolo GPU può essere acquisito su richiesta e reindirizzato istantaneamente a qualsiasi catena PoW. Al contrario, il PoC richiede hardware fisico, plotting che richiede tempo e operazioni di I/O continue. Questi vincoli rendono gli attacchi opportunistici a breve termine molto meno fattibili.

### 8.3 Attacchi al timing

Il timing gioca un ruolo più critico nel Proof of Capacity rispetto al Proof of Work. Nel PoW, i timestamp influenzano principalmente la regolazione della difficoltà; nel PoC, determinano se la deadline di un miner è trascorsa e quindi se un blocco è idoneo per il forging. Le deadline sono misurate rispetto al timestamp del blocco padre, ma l'orologio locale di un nodo è usato per giudicare se un blocco in arrivo è troppo lontano nel futuro. Per questo motivo PoCX impone una tolleranza stretta sui timestamp: i blocchi non possono deviare più di 15 secondi dall'orologio locale del nodo (rispetto alla finestra di 2 ore di Bitcoin). Questo limite funziona in entrambe le direzioni: i blocchi troppo lontani nel futuro vengono rifiutati, e i nodi con orologi lenti possono rifiutare incorrettamente blocchi validi in arrivo.

I nodi dovrebbero quindi sincronizzare i loro orologi usando NTP o una sorgente temporale equivalente. PoCX evita deliberatamente di fare affidamento su sorgenti temporali interne alla rete per prevenire che gli attaccanti manipolino il tempo percepito della rete. I nodi monitorano la propria deriva ed emettono avvisi se l'orologio locale inizia a divergere dai timestamp dei blocchi recenti.

L'accelerazione dell'orologio, far andare un orologio locale veloce per forgiare leggermente prima, fornisce solo un beneficio marginale. Entro la tolleranza permessa, il forging difensivo (Sezione 7.3) assicura che un miner con una soluzione migliore pubblicherà immediatamente vedendo un blocco inferiore anticipato. Un orologio veloce aiuta solo un miner a pubblicare una soluzione già vincente qualche secondo prima; non può convertire una prova inferiore in una vincente.

I tentativi di manipolare la difficoltà tramite i timestamp sono limitati da un cap di regolazione per blocco di ±20% e una finestra mobile di 24 blocchi, prevenendo che i miner influenzino significativamente la difficoltà attraverso giochi di timing a breve termine.

### 8.4 Attacchi di compromesso tempo-memoria

I compromessi tempo-memoria tentano di ridurre i requisiti di storage ricalcolando parti del plot su richiesta. I sistemi Proof of Capacity precedenti erano vulnerabili a tali attacchi, in particolare il difetto di sbilanciamento degli scoop POC1 e l'attacco di compressione XOR-transpose POC2 (Sezione 2.4). Entrambi sfruttavano asimmetrie nel costo di rigenerazione di certe porzioni dei dati del plot, permettendo agli avversari di tagliare lo storage pagando solo una piccola penalità computazionale. Inoltre, formati plot alternativi a POC2 soffrono di debolezze TMTO simili; un esempio prominente è Chia, il cui formato plot può essere ridotto arbitrariamente di un fattore maggiore di 4.

PoCX rimuove completamente queste superfici di attacco attraverso la sua costruzione dei nonce e il formato dei warp. All'interno di ogni nonce, il passo finale di diffusione hasha il buffer completamente calcolato e effettua lo XOR del risultato su tutti i byte, assicurando che ogni parte del buffer dipenda da ogni altra parte e non possa essere abbreviata. Successivamente, lo shuffle POC2 scambia le metà inferiore e superiore di ogni scoop, equalizzando il costo computazionale di recupero di qualsiasi scoop.

PoCX elimina ulteriormente l'attacco di compressione XOR-transpose POC2 derivando il suo formato rafforzato X1, dove ogni scoop è lo XOR di una posizione diretta e una trasposta attraverso coppie di warp; questo interconnette ogni scoop con un'intera riga e un'intera colonna dei dati X0 sottostanti, rendendo la ricostruzione richiedente migliaia di nonce completi e rimuovendo così completamente il compromesso tempo-memoria asimmetrico.

Di conseguenza, memorizzare l'intero plot è l'unica strategia computazionalmente praticabile per i miner. Nessuna scorciatoia nota, che sia plotting parziale, rigenerazione selettiva, compressione strutturata o approcci ibridi calcolo-storage, fornisce un vantaggio significativo. PoCX assicura che il mining rimanga strettamente vincolato allo storage e che la capacità rifletta un impegno reale e fisico.

### 8.5 Attacchi alle assegnazioni

PoCX usa una macchina a stati deterministica per governare tutte le assegnazioni plot-a-forger. Ogni assegnazione progredisce attraverso stati ben definiti, UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED, con ritardi di attivazione e revoca imposti. Questo assicura che un miner non possa cambiare istantaneamente le assegnazioni per imbrogliare il sistema o cambiare rapidamente l'autorità di forging.

Poiché tutte le transizioni richiedono prove crittografiche, specificamente, firme dal proprietario del plot che sono verificabili rispetto all'input UTXO, la rete può fidarsi della legittimità di ogni assegnazione. I tentativi di bypassare la macchina a stati o forgiare assegnazioni sono automaticamente rifiutati durante la validazione del consenso. Gli attacchi di replay sono similmente prevenuti dalle protezioni standard di replay delle transazioni in stile Bitcoin, assicurando che ogni azione di assegnazione sia univocamente legata a un input valido e non speso.

La combinazione di governance della macchina a stati, ritardi imposti e prove crittografiche rende l'imbroglio basato sulle assegnazioni praticamente impossibile: i miner non possono dirottare assegnazioni, effettuare rapide riassegnazioni durante le competizioni per i blocchi o aggirare i programmi di revoca.

### 8.6 Sicurezza delle firme

Le firme dei blocchi in PoCX servono come collegamento critico tra una prova e la chiave di forging effettiva, assicurando che solo i miner autorizzati possano produrre blocchi validi.

Per prevenire attacchi di malleabilità, le firme sono escluse dal calcolo dell'hash del blocco. Questo elimina i rischi di firme malleabili che potrebbero minare la validazione o permettere attacchi di sostituzione dei blocchi.

Per mitigare i vettori denial-of-service, le dimensioni delle firme e delle chiavi pubbliche sono fisse, 65 byte per le firme compatte e 33 byte per le chiavi pubbliche compresse, prevenendo che gli attaccanti gonfino i blocchi per attivare esaurimento delle risorse o rallentare la propagazione nella rete.

---

## 9. Implementazione

PoCX è implementato come estensione modulare di Bitcoin Core, con tutto il codice rilevante contenuto all'interno della propria sottodirectory dedicata e attivato attraverso un feature flag. Questo design preserva l'integrità del codice originale, permettendo a PoCX di essere abilitato o disabilitato in modo pulito, il che semplifica test, audit e mantenimento della sincronizzazione con le modifiche upstream.

L'integrazione tocca solo i punti essenziali necessari per supportare il Proof of Capacity. L'header del blocco è stato esteso per includere campi specifici PoCX, e la validazione del consenso è stata adattata per elaborare prove basate sullo storage insieme ai controlli Bitcoin tradizionali. Il sistema di forging, responsabile della gestione delle deadline, della pianificazione e degli invii dei miner, è completamente contenuto nei moduli PoCX, mentre le estensioni RPC espongono le funzionalità di mining e assegnazione ai client esterni. Per gli utenti, l'interfaccia del wallet è stata migliorata per gestire le assegnazioni attraverso transazioni OP_RETURN, abilitando un'interazione fluida con le nuove funzionalità di consenso.

Tutte le operazioni critiche per il consenso sono implementate in C++ deterministico senza dipendenze esterne, assicurando consistenza cross-platform. Shabal256 è usato per l'hashing, mentre il Time Bending e il calcolo della qualità si basano su aritmetica a virgola fissa e operazioni a 256 bit. Le operazioni crittografiche come la verifica delle firme sfruttano la libreria secp256k1 esistente di Bitcoin Core.

Isolando la funzionalità PoCX in questo modo, l'implementazione rimane verificabile, manutenibile e completamente compatibile con lo sviluppo continuo di Bitcoin Core, dimostrando che un meccanismo di consenso fondamentalmente nuovo e vincolato allo storage può coesistere con un codebase proof-of-work maturo senza interromperne l'integrità o l'usabilità.

---

## 10. Parametri di rete

PoCX si basa sull'infrastruttura di rete di Bitcoin e riutilizza il suo framework dei parametri di catena. Per supportare il mining basato sulla capacità, gli intervalli di blocco, la gestione delle assegnazioni e lo scaling dei plot, diversi parametri sono stati estesi o sovrascritti. Questo include il tempo di blocco target, il sussidio iniziale, il programma di halving, i ritardi di attivazione e revoca delle assegnazioni, così come gli identificatori di rete come magic bytes, porte e prefissi Bech32. Gli ambienti testnet e regtest regolano ulteriormente questi parametri per abilitare iterazione rapida e test a bassa capacità.

Le tabelle seguenti riassumono le impostazioni risultanti per mainnet, testnet e regtest, evidenziando come PoCX adatta i parametri core di Bitcoin a un modello di consenso vincolato allo storage.

### 10.1 Mainnet

| Parametro | Valore |
|-----------|--------|
| Magic bytes | `0xa7 0x3c 0x91 0x5e` |
| Porta predefinita | 8888 |
| HRP Bech32 | `pocx` |
| Tempo di blocco target | 120 secondi |
| Sussidio iniziale | 10 BTC |
| Intervallo di halving | 1050000 blocchi (~4 anni) |
| Offerta totale | ~21 milioni BTC |
| Attivazione assegnazione | 30 blocchi |
| Revoca assegnazione | 720 blocchi |
| Finestra mobile | 24 blocchi |

### 10.2 Testnet

| Parametro | Valore |
|-----------|--------|
| Magic bytes | `0x6d 0xf2 0x48 0xb3` |
| Porta predefinita | 18888 |
| HRP Bech32 | `tpocx` |
| Tempo di blocco target | 120 secondi |
| Altri parametri | Come mainnet |

### 10.3 Regtest

| Parametro | Valore |
|-----------|--------|
| Magic bytes | `0xfa 0xbf 0xb5 0xda` |
| Porta predefinita | 18444 |
| HRP Bech32 | `rpocx` |
| Tempo di blocco target | 1 secondo |
| Intervallo di halving | 500 blocchi |
| Attivazione assegnazione | 4 blocchi |
| Revoca assegnazione | 8 blocchi |
| Modalità bassa capacità | Abilitata (~4 MB plot) |

---

## 11. Lavori correlati

Nel corso degli anni, diversi progetti blockchain e di consenso hanno esplorato modelli di mining basati sullo storage o ibridi. PoCX costruisce su questa tradizione introducendo al contempo miglioramenti in sicurezza, efficienza e compatibilità.

**Burstcoin / Signum.** Burstcoin ha introdotto il primo sistema Proof-of-Capacity (PoC) pratico nel 2014, definendo concetti core come plot, nonce, scoop e mining basato su deadline. I suoi successori, in particolare Signum (precedentemente Burstcoin), hanno esteso l'ecosistema e alla fine si sono evoluti in quello che è noto come Proof-of-Commitment (PoC+), combinando l'impegno di storage con staking opzionale per influenzare la capacità effettiva. PoCX eredita le fondamenta del mining basato sullo storage da questi progetti, ma diverge significativamente attraverso un formato plot rafforzato (codifica XOR-transpose), scaling dinamico del lavoro sui plot, smoothing delle deadline ("Time Bending") e un sistema di assegnazioni flessibile, il tutto ancorandosi nel codebase di Bitcoin Core piuttosto che mantenere un fork di rete standalone.

**Chia.** Chia implementa Proof of Space and Time, combinando prove di storage basate su disco con una componente temporale imposta tramite Verifiable Delay Functions (VDF). Il suo design affronta certe preoccupazioni sul riutilizzo delle prove e la generazione di sfide fresche, distinto dal PoC classico. PoCX non adotta quel modello di prova ancorato al tempo; invece, mantiene un consenso vincolato allo storage con intervalli prevedibili, ottimizzato per la compatibilità a lungo termine con l'economia UTXO e gli strumenti derivati da Bitcoin.

**Spacemesh.** Spacemesh propone uno schema Proof-of-Space-Time (PoST) usando una topologia di rete basata su DAG (mesh). In questo modello, i partecipanti devono periodicamente dimostrare che lo storage allocato rimane intatto nel tempo, piuttosto che fare affidamento su un singolo dataset pre-calcolato. PoCX, al contrario, verifica l'impegno di storage solo al momento del blocco, con formati plot rafforzati e validazione rigorosa delle prove, evitando l'overhead delle prove di storage continue preservando al contempo efficienza e decentralizzazione.

---

## 12. Conclusione

Bitcoin-PoCX dimostra che il consenso a efficienza energetica può essere integrato in Bitcoin Core preservando le proprietà di sicurezza e il modello economico. I contributi chiave includono la codifica XOR-transpose (costringe gli attaccanti a calcolare 4096 nonce per lookup, eliminando l'attacco di compressione), l'algoritmo Time Bending (la trasformazione della distribuzione riduce la varianza dei tempi di blocco), il sistema di assegnazione del forging (la delega basata su OP_RETURN abilita il mining in pool non custodiale), lo scaling dinamico (allineato con gli halving per mantenere i margini di sicurezza), e l'integrazione minima (codice con feature flag isolato in una directory dedicata).

Il sistema è attualmente in fase testnet. La potenza di mining deriva dalla capacità di storage piuttosto che dall'hash rate, riducendo il consumo energetico di ordini di grandezza mantenendo al contempo il modello economico comprovato di Bitcoin.

---

## Riferimenti

Bitcoin Core. *Repository Bitcoin Core.* https://github.com/bitcoin/bitcoin

Burstcoin. *Documentazione tecnica Proof of Capacity.* 2014.

NIST. *Competizione SHA-3: Shabal.* 2008.

Cohen, B., Pietrzak, K. *The Chia Network Blockchain.* 2019.

Spacemesh. *Documentazione del protocollo Spacemesh.* 2021.

PoC Consortium. *Framework PoCX.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Integrazione Bitcoin-PoCX.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Licenza**: MIT
**Organizzazione**: Proof of Capacity Consortium
**Stato**: Fase Testnet
