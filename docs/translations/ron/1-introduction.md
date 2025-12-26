[📘 Cuprins](index.md) | [Următorul: Formatul plot →](2-plot-format.md)

---

# Capitolul 1: Introducere și prezentare generală

## Ce este Bitcoin-PoCX?

Bitcoin-PoCX este o integrare Bitcoin Core care adaugă suport pentru consensul **Proof of Capacity neXt generation (PoCX)**. Menține arhitectura existentă a Bitcoin Core în timp ce permite o alternativă de minerit eficientă energetic bazată pe Proof of Capacity, ca înlocuitor complet pentru Proof of Work.

**Distincție cheie**: Aceasta este un **lanț nou** fără compatibilitate retroactivă cu Bitcoin PoW. Blocurile PoCX sunt incompatibile cu nodurile PoW prin design.

---

## Identitatea proiectului

- **Organizație**: Proof of Capacity Consortium
- **Numele proiectului**: Bitcoin-PoCX
- **Numele complet**: Bitcoin Core cu integrare PoCX
- **Stare**: Fază Testnet

---

## Ce este Proof of Capacity?

Proof of Capacity (PoC) este un mecanism de consens în care puterea de minerit este proporțională cu **spațiul pe disc** în loc de puterea computațională. Minerii pre-generează fișiere plot mari conținând hash-uri criptografice, apoi folosesc aceste plot-uri pentru a găsi soluții valide pentru blocuri.

**Eficiență energetică**: Fișierele plot sunt generate o singură dată și reutilizate la nesfârșit. Mineritul consumă putere CPU minimă - în principal operațiuni I/O pe disc.

**Îmbunătățiri PoCX**:
- Corectat atacul de compresie XOR-transpose (compromis timp-memorie de 50% în POC2)
- Layout aliniat la 16 nonce-uri pentru hardware modern
- Proof-of-work scalabil în generarea plot-urilor (niveluri de scalare Xn)
- Integrare nativă C++ direct în Bitcoin Core
- Algoritmul Time Bending pentru distribuție îmbunătățită a timpului între blocuri

---

## Prezentare generală a arhitecturii

### Structura depozitului

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + integrare PoCX
│   └── src/pocx/        # Implementare PoCX
├── pocx/                # Framework PoCX core (submodul, doar citire)
└── docs/                # Această documentație
```

### Filosofia de integrare

**Suprafață minimă de integrare**: Modificările sunt izolate în directorul `/src/pocx/` cu hook-uri curate în straturile de validare, minerit și RPC ale Bitcoin Core.

**Marcarea funcționalităților**: Toate modificările sunt sub directive de preprocesor `#ifdef ENABLE_POCX`. Bitcoin Core se compilează normal când sunt dezactivate.

**Compatibilitate cu upstream**: Sincronizarea regulată cu actualizările Bitcoin Core este menținută prin puncte de integrare izolate.

**Implementare nativă C++**: Algoritmi criptografici scalari (Shabal256, calcul scoop, compresie) integrați direct în Bitcoin Core pentru validarea consensului.

---

## Caracteristici principale

### 1. Înlocuire completă a consensului

- **Structura blocului**: Câmpuri specifice PoCX înlocuiesc nonce-ul PoW și biții de dificultate
  - Semnătura de generare (entropie deterministă pentru minerit)
  - Ținta de bază (inversul dificultății)
  - Dovada PoCX (ID cont, seed, nonce)
  - Semnătura blocului (demonstrează proprietatea plot-ului)

- **Validare**: Pipeline de validare în 5 etape de la verificarea header-ului până la conectarea blocului

- **Ajustarea dificultății**: Ajustare la fiecare bloc folosind media mobilă a țintelor de bază recente

### 2. Algoritmul Time Bending

**Problema**: Timpii blocurilor PoC tradiționale urmează o distribuție exponențială, ducând la blocuri lungi când niciun miner nu găsește o soluție bună.

**Soluția**: Transformarea distribuției din exponențială în chi-pătrat folosind rădăcina cubică: `Y = scala × (X^(1/3))`.

**Efectul**: Soluțiile foarte bune sunt forjate mai târziu (rețeaua are timp să scaneze toate discurile, reduce blocurile rapide), soluțiile slabe sunt îmbunătățite. Timpul mediu al blocului este menținut la 120 secunde, blocurile lungi sunt reduse.

**Detalii**: [Capitolul 3: Consens și minerit](3-consensus-and-mining.md)

### 3. Sistemul de atribuire a forjării

**Capabilitate**: Proprietarii de plot-uri pot delega drepturile de forjare către alte adrese, menținând în același timp proprietatea plot-ului.

**Cazuri de utilizare**:
- Minerit în pool (plot-urile se atribuie adresei pool-ului)
- Stocare la rece (cheia de minerit separată de proprietatea plot-ului)
- Minerit multi-parte (infrastructură partajată)

**Arhitectură**: Design bazat exclusiv pe OP_RETURN - fără UTXO-uri speciale, atribuirile sunt urmărite separat în baza de date chainstate.

**Detalii**: [Capitolul 4: Atribuiri de forjare](4-forging-assignments.md)

### 4. Forjarea defensivă

**Problema**: Ceasurile rapide ar putea oferi avantaje de sincronizare în cadrul toleranței de 15 secunde pentru viitor.

**Soluția**: La primirea unui bloc concurent la aceeași înălțime, verifică automat calitatea locală. Dacă este mai bună, forjează imediat.

**Efectul**: Elimină stimulentul pentru manipularea ceasului - ceasurile rapide ajută doar dacă aveți deja cea mai bună soluție.

**Detalii**: [Capitolul 5: Securitatea sincronizării](5-timing-security.md)

### 5. Scalarea dinamică a compresiei

**Aliniere economică**: Cerințele nivelului de scalare cresc după un calendar exponențial (Anii 4, 12, 28, 60, 124 = înjumătățirile 1, 3, 7, 15, 31).

**Efectul**: Pe măsură ce recompensele de bloc scad, dificultatea generării plot-urilor crește. Menține marja de siguranță între costurile de creare și căutare a plot-urilor.

**Previne**: Inflația capacității din cauza hardware-ului mai rapid în timp.

**Detalii**: [Capitolul 6: Parametri de rețea](6-network-parameters.md)

---

## Filosofia de design

### Siguranța codului

- Practici de programare defensivă pe tot parcursul
- Gestionare cuprinzătoare a erorilor în căile de validare
- Fără blocări imbricate (prevenirea deadlock-urilor)
- Operațiuni atomice pe baza de date (UTXO + atribuiri împreună)

### Arhitectură modulară

- Separare clară între infrastructura Bitcoin Core și consensul PoCX
- Framework-ul PoCX core furnizează primitive criptografice
- Bitcoin Core furnizează framework-ul de validare, baza de date, rețeaua

### Optimizări de performanță

- Ordonare a validării pentru eșec rapid (verificări ieftine mai întâi)
- O singură achiziție de context per trimitere (fără achiziții repetate de cs_main)
- Operațiuni atomice pe baza de date pentru consistență

### Siguranță la reorganizări

- Date de anulare complete pentru modificările stării atribuirilor
- Resetarea stării de forjare la schimbarea vârfului lanțului
- Detectarea învechirilor la toate punctele de validare

---

## Cum diferă PoCX de Proof of Work

| Aspect | Bitcoin (PoW) | Bitcoin-PoCX |
|--------|---------------|--------------|
| **Resursă de minerit** | Putere computațională (rată de hash) | Spațiu pe disc (capacitate) |
| **Consum energetic** | Ridicat (hashing continuu) | Scăzut (doar I/O pe disc) |
| **Procesul de minerit** | Găsește nonce cu hash < țintă | Găsește nonce cu deadline < timp scurs |
| **Dificultate** | Câmpul `bits`, ajustat la fiecare 2016 blocuri | Câmpul `base_target`, ajustat la fiecare bloc |
| **Timp bloc** | ~10 minute (distribuție exponențială) | 120 secunde (time-bended, varianță redusă) |
| **Subvenție** | 50 BTC → 25 → 12,5 → ... | 10 BTC → 5 → 2,5 → ... |
| **Hardware** | ASIC-uri (specializate) | HDD-uri (hardware de uz general) |
| **Identitatea minerului** | Anonim | Proprietarul plot-ului sau delegat |

---

## Cerințe de sistem

### Operarea nodului

**La fel ca Bitcoin Core**:
- **CPU**: Procesor modern x86_64
- **Memorie**: 4-8 GB RAM
- **Stocare**: Lanț nou, momentan gol (poate crește de ~4× mai repede decât Bitcoin datorită blocurilor de 2 minute și bazei de date de atribuiri)
- **Rețea**: Conexiune stabilă la internet
- **Ceas**: Sincronizare NTP recomandată pentru operare optimă

**Notă**: Fișierele plot NU sunt necesare pentru operarea nodului.

### Cerințe pentru minerit

**Cerințe suplimentare pentru minerit**:
- **Fișiere plot**: Pre-generate folosind `pocx_plotter` (implementarea de referință)
- **Software de minerit**: `pocx_miner` (implementarea de referință) se conectează prin RPC
- **Portofel**: `bitcoind` sau `bitcoin-qt` cu chei private pentru adresa de minerit. Mineritul în pool nu necesită portofel local.

---

## Primii pași

### 1. Compilarea Bitcoin-PoCX

```bash
# Clonare cu submodule
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Compilare cu PoCX activat
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Detalii**: Consultați `CLAUDE.md` în rădăcina depozitului

### 2. Rularea nodului

**Doar nod**:
```bash
./build/bin/bitcoind
# sau
./build/bin/bitcoin-qt
```

**Pentru minerit** (activează accesul RPC pentru mineri externi):
```bash
./build/bin/bitcoind -miningserver
# sau
./build/bin/bitcoin-qt -server -miningserver
```

**Detalii**: [Capitolul 6: Parametri de rețea](6-network-parameters.md)

### 3. Generarea fișierelor plot

Folosiți `pocx_plotter` (implementarea de referință) pentru a genera fișiere plot în format PoCX.

**Detalii**: [Capitolul 2: Formatul plot](2-plot-format.md)

### 4. Configurarea mineritului

Folosiți `pocx_miner` (implementarea de referință) pentru a vă conecta la interfața RPC a nodului.

**Detalii**: [Capitolul 7: Referință RPC](7-rpc-reference.md) și [Capitolul 8: Ghid portofel](8-wallet-guide.md)

---

## Atribuiri

### Formatul plot

Bazat pe formatul POC2 (Burstcoin) cu îmbunătățiri:
- Corectat defectul de securitate (atacul de compresie XOR-transpose)
- Proof-of-work scalabil
- Layout optimizat pentru SIMD
- Funcționalitate seed

### Proiecte sursă

- **pocx_miner**: Implementare de referință bazată pe [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Implementare de referință bazată pe [engraver](https://github.com/PoC-Consortium/engraver)

**Atribuire completă**: [Capitolul 2: Formatul plot](2-plot-format.md)

---

## Rezumatul specificațiilor tehnice

- **Timp bloc**: 120 secunde (mainnet), 1 secundă (regtest)
- **Subvenție bloc**: 10 BTC inițial, înjumătățire la fiecare 1050000 blocuri (~4 ani)
- **Ofertă totală**: ~21 milioane BTC (la fel ca Bitcoin)
- **Toleranță viitor**: 15 secunde (blocurile cu până la 15s în avans sunt acceptate)
- **Avertisment ceas**: 10 secunde (avertizează operatorii despre deriva ceasului)
- **Întârziere atribuire**: 30 blocuri (~1 oră)
- **Întârziere revocare**: 720 blocuri (~24 ore)
- **Format adresă**: Doar P2WPKH (bech32, pocx1q...) pentru operațiunile de minerit PoCX și atribuirile de forjare

---

## Organizarea codului

**Modificări Bitcoin Core**: Modificări minime la fișierele de bază, marcate cu `#ifdef ENABLE_POCX`

**Implementare PoCX nouă**: Izolată în directorul `src/pocx/`

---

## Considerații de securitate

### Securitatea sincronizării

- Toleranța de 15 secunde pentru viitor previne fragmentarea rețelei
- Pragul de avertizare de 10 secunde alertează operatorii despre deriva ceasului
- Forjarea defensivă elimină stimulentul pentru manipularea ceasului
- Time Bending reduce impactul varianței de sincronizare

**Detalii**: [Capitolul 5: Securitatea sincronizării](5-timing-security.md)

### Securitatea atribuirilor

- Design bazat exclusiv pe OP_RETURN (fără manipulare UTXO)
- Semnătura tranzacției demonstrează proprietatea plot-ului
- Întârzierile de activare previn manipularea rapidă a stării
- Date de anulare sigure la reorganizări pentru toate modificările de stare

**Detalii**: [Capitolul 4: Atribuiri de forjare](4-forging-assignments.md)

### Securitatea consensului

- Semnătura este exclusă din hash-ul blocului (previne maleabilitatea)
- Dimensiuni de semnătură limitate (previne DoS)
- Validarea limitelor de compresie (previne dovezile slabe)
- Ajustarea dificultății la fiecare bloc (reactivă la schimbările de capacitate)

**Detalii**: [Capitolul 3: Consens și minerit](3-consensus-and-mining.md)

---

## Starea rețelei

**Mainnet**: Încă nelansat
**Testnet**: Disponibil pentru testare
**Regtest**: Complet funcțional pentru dezvoltare

**Parametrii blocului genesis**: [Capitolul 6: Parametri de rețea](6-network-parameters.md)

---

## Pașii următori

**Pentru înțelegerea PoCX**: Continuați cu [Capitolul 2: Formatul plot](2-plot-format.md) pentru a învăța despre structura fișierelor plot și evoluția formatului.

**Pentru configurarea mineritului**: Săriți la [Capitolul 7: Referință RPC](7-rpc-reference.md) pentru detalii de integrare.

**Pentru rularea unui nod**: Consultați [Capitolul 6: Parametri de rețea](6-network-parameters.md) pentru opțiuni de configurare.

---

[📘 Cuprins](index.md) | [Următorul: Formatul plot →](2-plot-format.md)
