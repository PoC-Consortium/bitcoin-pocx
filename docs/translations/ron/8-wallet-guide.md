[← Anterior: Referință RPC](7-rpc-reference.md) | [📘 Cuprins](index.md)

---

# Capitolul 8: Ghid de utilizare portofel și GUI

Ghid complet pentru portofelul Qt Bitcoin-PoCX și gestionarea atribuirilor de forjare.

---

## Cuprins

1. [Prezentare generală](#prezentare-generală)
2. [Unități monetare](#unități-monetare)
3. [Dialogul de atribuire a forjării](#dialogul-de-atribuire-a-forjării)
4. [Istoricul tranzacțiilor](#istoricul-tranzacțiilor)
5. [Cerințe pentru adrese](#cerințe-pentru-adrese)
6. [Integrarea mineritului](#integrarea-mineritului)
7. [Depanare](#depanare)
8. [Bune practici de securitate](#bune-practici-de-securitate)

---

## Prezentare generală

### Funcționalitățile portofelului Bitcoin-PoCX

Portofelul Qt Bitcoin-PoCX (`bitcoin-qt`) oferă:
- Funcționalitatea standard a portofelului Bitcoin Core (trimitere, primire, gestionarea tranzacțiilor)
- **Manager atribuiri forjare**: GUI pentru crearea/revocarea atribuirilor de plot-uri
- **Mod server de minerit**: Flag-ul `` activează funcționalitățile legate de minerit
- **Istoric tranzacții**: Afișarea tranzacțiilor de atribuire și revocare

### Pornirea portofelului

**Doar nod** (fără minerit):
```bash
./build/bin/bitcoin-qt
```

**Cu minerit** (activează dialogul de atribuiri):
```bash
./build/bin/bitcoin-qt -server
```

**Alternativă linie de comandă**:
```bash
./build/bin/bitcoind
```

### Cerințe pentru minerit

**Pentru operațiuni de minerit**:
- Flag-ul `` necesar
- Portofel cu adrese P2WPKH și chei private
- Plotter extern (`pocx_plotter`) pentru generarea plot-urilor
- Miner extern (`pocx_miner`) pentru minerit

**Pentru mineritul în pool**:
- Creați atribuire de forjare către adresa pool-ului
- Portofelul nu este necesar pe serverul pool-ului (pool-ul gestionează cheile)

---

## Unități monetare

### Afișarea unităților

Bitcoin-PoCX folosește unitatea monetară **BTCX** (nu BTC):

| Unitate | Satoshi | Afișare |
|---------|---------|---------|
| **BTCX** | 100000000 | 1.00000000 BTCX |
| **mBTCX** | 100000 | 1000.00 mBTCX |
| **µBTCX** | 100 | 1000000.00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**Setări GUI**: Preferințe → Afișare → Unitate

---

## Dialogul de atribuire a forjării

### Accesarea dialogului

**Meniu**: `Portofel → Atribuiri forjare`
**Bara de instrumente**: Pictograma de minerit (vizibilă doar cu flag-ul ``)
**Dimensiune fereastră**: 600×450 pixeli

### Modurile dialogului

#### Modul 1: Creare atribuire

**Scop**: Delegați drepturile de forjare către pool sau altă adresă, păstrând în același timp proprietatea plot-ului.

**Cazuri de utilizare**:
- Minerit în pool (atribuire către adresa pool-ului)
- Stocare la rece (cheia de minerit separată de proprietatea plot-ului)
- Infrastructură partajată (delegare către portofel online)

**Cerințe**:
- Adresă plot (P2WPKH bech32, trebuie să dețineți cheia privată)
- Adresă forjare (P2WPKH bech32, diferită de adresa plot)
- Portofel deblocat (dacă este criptat)
- Adresa plot are UTXO-uri confirmate

**Pași**:
1. Selectați modul „Creare atribuire"
2. Alegeți adresa plot din dropdown sau introduceți manual
3. Introduceți adresa de forjare (pool sau delegat)
4. Faceți clic pe „Trimite atribuire" (butonul activat când intrările sunt valide)
5. Tranzacția este difuzată imediat
6. Atribuirea devine activă după `nForgingAssignmentDelay` blocuri:
   - Mainnet/Testnet: 30 blocuri (~1 oră)
   - Regtest: 4 blocuri (~4 secunde)

**Taxa de tranzacție**: Implicit 10× `minRelayFee` (personalizabilă)

**Structura tranzacției**:
- Intrare: UTXO de la adresa plot (demonstrează proprietatea)
- Ieșire OP_RETURN: marker `POCX` + plot_address + forging_address (46 octeți)
- Ieșire rest: Returnat în portofel

#### Modul 2: Revocare atribuire

**Scop**: Anulați atribuirea de forjare și returnați drepturile proprietarului plot-ului.

**Cerințe**:
- Adresă plot (trebuie să dețineți cheia privată)
- Portofel deblocat (dacă este criptat)
- Adresa plot are UTXO-uri confirmate

**Pași**:
1. Selectați modul „Revocare atribuire"
2. Alegeți adresa plot
3. Faceți clic pe „Trimite revocare"
4. Tranzacția este difuzată imediat
5. Revocarea devine efectivă după `nForgingRevocationDelay` blocuri:
   - Mainnet/Testnet: 720 blocuri (~24 ore)
   - Regtest: 8 blocuri (~8 secunde)

**Efect**:
- Adresa de forjare poate încă forja în perioada de întârziere
- Proprietarul plot-ului recâștigă drepturile după finalizarea revocării
- Poate crea atribuire nouă ulterior

**Structura tranzacției**:
- Intrare: UTXO de la adresa plot (demonstrează proprietatea)
- Ieșire OP_RETURN: marker `XCOP` + plot_address (26 octeți)
- Ieșire rest: Returnat în portofel

#### Modul 3: Verificare stare atribuire

**Scop**: Interogați starea curentă a atribuirii pentru orice adresă de plot.

**Cerințe**: Niciunul (doar citire, fără portofel necesar)

**Pași**:
1. Selectați modul „Verifică stare atribuire"
2. Introduceți adresa plot
3. Faceți clic pe „Verifică stare"
4. Caseta de stare afișează starea curentă cu detalii

**Indicatoare de stare** (codificate pe culori):

**Gri - UNASSIGNED**
```
NEATRIBUIT - Nu există atribuire
```

**Portocaliu - ASSIGNING**
```
ÎN ATRIBUIRE - Atribuire în așteptarea activării
Adresă forjare: pocx1qforger...
Creată la înălțimea: 12000
Se activează la înălțimea: 12030 (5 blocuri rămase)
```

**Verde - ASSIGNED**
```
ATRIBUIT - Atribuire activă
Adresă forjare: pocx1qforger...
Creată la înălțimea: 12000
Activată la înălțimea: 12030
```

**Roșu-portocaliu - REVOKING**
```
ÎN REVOCARE - Revocare în așteptare
Adresă forjare: pocx1qforger... (încă activă)
Atribuire creată la înălțimea: 12000
Revocată la înălțimea: 12300
Revocare efectivă la înălțimea: 13020 (50 blocuri rămase)
```

**Roșu - REVOKED**
```
REVOCATĂ - Atribuire revocată
Anterior atribuită lui: pocx1qforger...
Atribuire creată la înălțimea: 12000
Revocată la înălțimea: 12300
Revocare efectivă la înălțimea: 13020
```

---

## Istoricul tranzacțiilor

### Afișarea tranzacțiilor de atribuire

**Tip**: „Atribuire"
**Pictogramă**: Pictogramă de minerit (la fel ca blocurile minate)

**Coloana adresă**: Adresa plot (adresa ale cărei drepturi de forjare sunt atribuite)
**Coloana sumă**: Taxa tranzacției (negativă, tranzacție de ieșire)
**Coloana stare**: Număr de confirmări (0-6+)

**Detalii** (la clic):
- ID tranzacție
- Adresă plot
- Adresă forjare (parsată din OP_RETURN)
- Creată la înălțime
- Înălțime activare
- Taxa tranzacției
- Timestamp

### Afișarea tranzacțiilor de revocare

**Tip**: „Revocare"
**Pictogramă**: Pictogramă de minerit

**Coloana adresă**: Adresa plot
**Coloana sumă**: Taxa tranzacției (negativă)
**Coloana stare**: Număr de confirmări

**Detalii** (la clic):
- ID tranzacție
- Adresă plot
- Revocată la înălțime
- Înălțime efectivă revocare
- Taxa tranzacției
- Timestamp

### Filtrarea tranzacțiilor

**Filtre disponibile**:
- „Toate" (implicit, include atribuiri/revocări)
- Interval de date
- Interval de sume
- Căutare după adresă
- Căutare după ID tranzacție
- Căutare după etichetă (dacă adresa are etichetă)

**Notă**: Tranzacțiile de atribuire/revocare apar momentan sub filtrul „Toate". Filtrul dedicat pentru tip nu este încă implementat.

### Sortarea tranzacțiilor

**Ordine de sortare** (după tip):
- Generat (tip 0)
- Primit (tip 1-3)
- Atribuire (tip 4)
- Revocare (tip 5)
- Trimis (tip 6+)

---

## Cerințe pentru adrese

### Doar P2WPKH (SegWit v0)

**Operațiunile de forjare necesită**:
- Adrese codificate Bech32 (începând cu „pocx1q" mainnet, „tpocx1q" testnet, „rpocx1q" regtest)
- Format P2WPKH (Pay-to-Witness-Public-Key-Hash)
- Hash de cheie de 20 octeți

**NU sunt suportate**:
- P2PKH (legacy, începând cu „1")
- P2SH (SegWit wrapped, începând cu „3")
- P2TR (Taproot, începând cu „bc1p")

**Rațiune**: Semnăturile blocurilor PoCX necesită format specific witness v0 pentru validarea dovezii.

### Filtrarea dropdown-ului de adrese

**ComboBox adresă plot**:
- Populat automat cu adresele de primire din portofel
- Filtrează adresele non-P2WPKH
- Afișează format: „Etichetă (adresă)" dacă are etichetă, altfel doar adresa
- Primul element: „-- Introduceți adresă personalizată --"Plot address must be segwit v0 (bech32)"
- „Adresa de forjare trebuie să fie P2WPKH (bech32)"
- „Format de adresă invalid"
- „Fără monede disponibile la adresa plot. Nu se poate demonstra proprietatea."
- „Nu se pot crea tranzacții cu portofel doar-vizualizare"
- „Portofel indisponibil"
- „Portofel blocat" (de la RPC)

---

## Integrarea mineritului

### Cerințe de configurare

**Configurare nod**:
```bash
# bitcoin.conf
server=1
```

**Cerințe portofel**:
- Adrese P2WPKH pentru proprietatea plot-ului
- Chei private pentru minerit (sau adresa de forjare dacă folosiți atribuiri)
- UTXO-uri confirmate pentru crearea tranzacțiilor

**Instrumente externe**:
- `pocx_plotter`: Generează fișiere plot
- `pocx_miner`: Scanează plot-uri și trimite nonce-uri

### Flux de lucru

#### Minerit solo

1. **Generați fișiere plot**:
   ```bash
   pocx_plotter --account <hash160_adresa_plot> --seed <32_octeti> --nonces <numar>
   ```

2. **Porniți nodul** cu server de minerit:
   ```bash
   bitcoin-qt -server
   ```

3. **Configurați minerul**:
   - Îndreptați către endpoint-ul RPC al nodului
   - Specificați directoarele fișierelor plot
   - Configurați ID-ul contului (din adresa plot)

4. **Porniți mineritul**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /cale/catre/ploturi
   ```

5. **Monitorizați**:
   - Minerul apelează `get_mining_info` la fiecare bloc
   - Scanează plot-urile pentru cel mai bun deadline
   - Apelează `submit_nonce` când găsește soluție
   - Nodul validează și forjează blocul automat

#### Minerit în pool

1. **Generați fișiere plot** (la fel ca mineritul solo)

2. **Creați atribuire de forjare**:
   - Deschideți dialogul de atribuire forjare
   - Selectați adresa plot
   - Introduceți adresa de forjare a pool-ului
   - Faceți clic pe „Trimite atribuire"
   - Așteptați întârzierea de activare (30 blocuri testnet)

3. **Configurați minerul**:
   - Îndreptați către endpoint-ul **pool-ului** (nu nodul local)
   - Pool-ul gestionează `submit_nonce` către lanț

4. **Operațiunea pool-ului**:
   - Portofelul pool-ului are cheile private ale adresei de forjare
   - Pool-ul validează trimiterile de la mineri
   - Pool-ul apelează `submit_nonce` către blockchain
   - Pool-ul distribuie recompensele conform politicii pool-ului

### Recompense Coinbase

**Fără atribuire**:
- Coinbase plătește direct adresa proprietarului plot-ului
- Verificați soldul la adresa plot-ului

**Cu atribuire**:
- Coinbase plătește adresa de forjare
- Pool-ul primește recompensele
- Minerul primește partea de la pool

**Calendarul recompenselor**:
- Inițial: 10 BTCX per bloc
- Înjumătățire: La fiecare 1050000 blocuri (~4 ani)
- Calendar: 10 → 5 → 2,5 → 1,25 → ...

---

## Depanare

### Probleme comune

#### „Portofelul nu are cheia privată pentru adresa plot"

**Cauză**: Portofelul nu deține adresa
**Soluție**:
- Importați cheia privată prin RPC `importprivkey`
- Sau folosiți altă adresă plot deținută de portofel

#### „Atribuire existentă pentru acest plot"

**Cauză**: Plot-ul deja atribuit altei adrese
**Soluție**:
1. Revocați atribuirea existentă
2. Așteptați întârzierea de revocare (720 blocuri testnet)
3. Creați atribuire nouă

#### „Format de adresă nesuportat"

**Cauză**: Adresa nu este P2WPKH bech32
**Soluție**:
- Folosiți adrese începând cu „pocx1q" (mainnet) sau „tpocx1q" (testnet)
- Generați adresă nouă dacă este necesar: `getnewaddress "" "bech32"`

#### „Taxa de tranzacție prea mică"

**Cauză**: Congestie mempool sau taxă prea mică pentru relay
**Soluție**:
- Creșteți parametrul ratei taxei
- Așteptați să se elibereze mempool-ul

#### „Atribuire nu este încă activă"

**Cauză**: Întârzierea de activare nu s-a scurs încă
**Soluție**:
- Verificați starea: blocuri rămase până la activare
- Așteptați să se completeze perioada de întârziere

#### „Fără monede disponibile la adresa plot"

**Cauză**: Adresa plot nu are UTXO-uri confirmate
**Soluție**:
1. Trimiteți fonduri la adresa plot
2. Așteptați 1 confirmare
3. Reîncercați crearea atribuirii

#### „Nu se pot crea tranzacții cu portofel doar-vizualizare"

**Cauză**: Portofelul a importat adresa fără cheie privată
**Soluție**: Importați cheia privată completă, nu doar adresa

#### „Tab-ul atribuire forjare nu este vizibil"

**Cauză**: Nodul pornit fără flag-ul ``
**Soluție**: Reporniți cu `bitcoin-qt -server`

### Pași de depanare

1. **Verificați starea portofelului**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Verificați proprietatea adresei**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Verificați: "iswatchonly": false, "ismine": true
   ```

3. **Verificați starea atribuirii**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Vizualizați tranzacțiile recente**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Verificați sincronizarea nodului**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Verificați: blocks == headers (complet sincronizat)
   ```

---

## Bune practici de securitate

### Securitatea adresei plot

**Gestionarea cheilor**:
- Stocați cheile private ale adresei plot în siguranță
- Tranzacțiile de atribuire demonstrează proprietatea prin semnătură
- Doar proprietarul plot-ului poate crea/revoca atribuiri

**Backup**:
- Faceți backup regulat la portofel (`dumpwallet` sau `backupwallet`)
- Stocați wallet.dat într-o locație sigură
- Înregistrați frazele de recuperare dacă folosiți portofel HD

### Delegarea adresei de forjare

**Model de securitate**:
- Adresa de forjare primește recompensele de bloc
- Adresa de forjare poate semna blocuri (minerit)
- Adresa de forjare **nu poate** modifica sau revoca atribuirea
- Proprietarul plot-ului păstrează controlul complet

**Cazuri de utilizare**:
- **Delegare portofel online**: Cheia plot în stocare la rece, cheia de forjare în portofel online pentru minerit
- **Minerit în pool**: Delegare către pool, păstrare proprietate plot
- **Infrastructură partajată**: Mineri multipli, o singură adresă de forjare

### Sincronizarea timpului rețelei

**Importanță**:
- Consensul PoCX necesită timp precis
- Deriva ceasului >10s declanșează avertizare
- Deriva ceasului >15s previne mineritul

**Soluție**:
- Păstrați ceasul sistemului sincronizat cu NTP
- Monitorizați: `bitcoin-cli getnetworkinfo` pentru avertizări offset timp
- Folosiți servere NTP fiabile

### Întârzieri atribuiri

**Întârziere activare** (30 blocuri testnet):
- Previne reatribuirea rapidă în timpul fork-urilor de lanț
- Permite rețelei să atingă consensul
- Nu poate fi ocolită

**Întârziere revocare** (720 blocuri testnet):
- Oferă stabilitate pentru pool-urile de minerit
- Previne atacurile de „hopping" între atribuiri
- Adresa de forjare rămâne activă în timpul întârzierii

### Criptarea portofelului

**Activați criptarea**:
```bash
bitcoin-cli encryptwallet "fraza_dumneavoastra_de_parola"
```

**Deblocați pentru tranzacții**:
```bash
bitcoin-cli walletpassphrase "fraza_dumneavoastra_de_parola" 300
```

**Bune practici**:
- Folosiți parolă puternică (20+ caractere)
- Nu stocați parola în text clar
- Blocați portofelul după crearea atribuirilor

---

## Referințe cod

**Dialogul atribuire forjare**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Afișare tranzacții**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Parsare tranzacții**: `src/qt/transactionrecord.cpp`
**Integrare portofel**: `src/pocx/assignments/transactions.cpp`
**RPC-uri atribuiri**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI principal**: `src/qt/bitcoingui.cpp`

---

## Referințe încrucișate

Capitole conexe:
- [Capitolul 3: Consens și minerit](3-consensus-and-mining.md) - Procesul de minerit
- [Capitolul 4: Atribuiri de forjare](4-forging-assignments.md) - Arhitectura atribuirilor
- [Capitolul 6: Parametri de rețea](6-network-parameters.md) - Valorile întârzierilor atribuirilor
- [Capitolul 7: Referință RPC](7-rpc-reference.md) - Detalii comenzi RPC

---

[← Anterior: Referință RPC](7-rpc-reference.md) | [📘 Cuprins](index.md)
