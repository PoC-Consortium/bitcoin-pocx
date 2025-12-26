[← Iepriekšējā: RPC atsauce](7-rpc-reference.md) | [📘 Satura rādītājs](index.md)

---

# 8. nodaļa: Maka un GUI lietotāja ceļvedis

Pilnīgs Bitcoin-PoCX Qt maka un kalšanas piešķīrumu pārvaldības ceļvedis.

---

## Satura rādītājs

1. [Pārskats](#pārskats)
2. [Valūtas vienības](#valūtas-vienības)
3. [Kalšanas piešķīrumu dialogs](#kalšanas-piešķīrumu-dialogs)
4. [Darījumu vēsture](#darījumu-vēsture)
5. [Adrešu prasības](#adrešu-prasības)
6. [Kalnrūpniecības integrācija](#kalnrūpniecības-integrācija)
7. [Problēmu novēršana](#problēmu-novēršana)
8. [Drošības labākā prakse](#drošības-labākā-prakse)

---

## Pārskats

### Bitcoin-PoCX maka funkcijas

Bitcoin-PoCX Qt maciņš (`bitcoin-qt`) nodrošina:
- Standarta Bitcoin Core maka funkcionalitāti (sūtīt, saņemt, darījumu pārvaldība)
- **Kalšanas piešķīrumu pārvaldnieks**: GUI piešķīrumu izveidei/atsaukšanai
- **Kalnrūpniecības servera režīms**: `-miningserver` karodziņš iespējo ar kalnrūpniecību saistītas funkcijas
- **Darījumu vēsture**: Piešķīrumu un atsaukšanas darījumu attēlošana

### Maka palaišana

**Tikai mezgls** (bez kalnrūpniecības):
```bash
./build/bin/bitcoin-qt
```

**Ar kalnrūpniecību** (iespējo piešķīrumu dialogu):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Komandrindas alternatīva**:
```bash
./build/bin/bitcoind -miningserver
```

### Kalnrūpniecības prasības

**Kalnrūpniecības operācijām**:
- `-miningserver` karodziņš nepieciešams
- Maciņš ar P2WPKH adresēm un privātajām atslēgām
- Ārējs ploteris (`pocx_plotter`) plotfailu ģenerēšanai
- Ārējs kalnracis (`pocx_miner`) kalnrūpniecībai

**Pūla kalnrūpniecībai**:
- Izveidot kalšanas piešķīrumu pūla adresei
- Maciņš nav nepieciešams pūla serverī (pūls pārvalda atslēgas)

---

## Valūtas vienības

### Vienību attēlošana

Bitcoin-PoCX izmanto **BTCX** valūtas vienību (nevis BTC):

| Vienība | Satoši | Attēlošana |
|------|----------|---------|
| **BTCX** | 100000000 | 1.00000000 BTCX |
| **mBTCX** | 100000 | 1000.00 mBTCX |
| **µBTCX** | 100 | 1000000.00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**GUI iestatījumi**: Preferences → Display → Unit

---

## Kalšanas piešķīrumu dialogs

### Piekļuve dialogam

**Izvēlne**: `Wallet → Forging Assignments`
**Rīkjosla**: Kalnrūpniecības ikona (redzama tikai ar `-miningserver` karodziņu)
**Loga izmērs**: 600×450 pikseļi

### Dialoga režīmi

#### 1. režīms: Izveidot piešķīrumu

**Mērķis**: Deleģēt kalšanas tiesības pūlam vai citai adresei, saglabājot plotfaila īpašumtiesības.

**Lietošanas gadījumi**:
- Pūla kalnrūpniecība (piešķirt pūla adresei)
- Aukstā glabāšana (kalnrūpniecības atslēga atdalīta no plotfaila īpašumtiesībām)
- Dalīta infrastruktūra (deleģēt karstajam maciņam)

**Prasības**:
- Plotfaila adrese (P2WPKH bech32, jāpieder privātā atslēga)
- Kalšanas adrese (P2WPKH bech32, atšķirīga no plotfaila adreses)
- Maciņš atbloķēts (ja šifrēts)
- Plotfaila adresei ir apstiprināti UTXO

**Soļi**:
1. Izvēlieties "Create Assignment" režīmu
2. Izvēlieties plotfaila adresi no nolaižamās izvēlnes vai ievadiet manuāli
3. Ievadiet kalšanas adresi (pūla vai pilnvarnieka)
4. Noklikšķiniet "Send Assignment" (poga iespējota, kad ievades derīgas)
5. Darījums tiek pārraidīts nekavējoties
6. Piešķīrums aktīvs pēc `nForgingAssignmentDelay` blokiem:
   - Mainnet/Testnet: 30 bloki (~1 stunda)
   - Regtest: 4 bloki (~4 sekundes)

**Darījuma maksa**: Noklusējums 10× `minRelayFee` (pielāgojama)

**Darījuma struktūra**:
- Ievade: UTXO no plotfaila adreses (pierāda īpašumtiesības)
- OP_RETURN izvade: `POCX` marķieris + plot_address + forging_address (46 baiti)
- Atlikuma izvade: Atgriezts maciņā

#### 2. režīms: Atsaukt piešķīrumu

**Mērķis**: Atcelt kalšanas piešķīrumu un atgriezt tiesības plotfaila īpašniekam.

**Prasības**:
- Plotfaila adrese (jāpieder privātā atslēga)
- Maciņš atbloķēts (ja šifrēts)
- Plotfaila adresei ir apstiprināti UTXO

**Soļi**:
1. Izvēlieties "Revoke Assignment" režīmu
2. Izvēlieties plotfaila adresi
3. Noklikšķiniet "Send Revocation"
4. Darījums tiek pārraidīts nekavējoties
5. Atsaukšana stājas spēkā pēc `nForgingRevocationDelay` blokiem:
   - Mainnet/Testnet: 720 bloki (~24 stundas)
   - Regtest: 8 bloki (~8 sekundes)

**Efekts**:
- Kalšanas adrese joprojām var kalst aizkaves periodā
- Plotfaila īpašnieks atgūst tiesības pēc atsaukšanas pabeigšanas
- Var izveidot jaunu piešķīrumu pēc tam

**Darījuma struktūra**:
- Ievade: UTXO no plotfaila adreses (pierāda īpašumtiesības)
- OP_RETURN izvade: `XCOP` marķieris + plot_address (26 baiti)
- Atlikuma izvade: Atgriezts maciņā

#### 3. režīms: Pārbaudīt piešķīruma statusu

**Mērķis**: Vaicāt pašreizējo piešķīruma stāvokli jebkurai plotfaila adresei.

**Prasības**: Nav (tikai lasīšana, nav nepieciešams maciņš)

**Soļi**:
1. Izvēlieties "Check Assignment Status" režīmu
2. Ievadiet plotfaila adresi
3. Noklikšķiniet "Check Status"
4. Statusa lodziņš parāda pašreizējo stāvokli ar detaļām

**Stāvokļa indikatori** (ar krāsu kodējumu):

**Pelēks - UNASSIGNED**
```
UNASSIGNED - Piešķīrums neeksistē
```

**Oranžs - ASSIGNING**
```
ASSIGNING - Piešķīrums gaida aktivizāciju
Kalšanas adrese: pocx1qforger...
Izveidots augstumā: 12000
Aktivizējas augstumā: 12030 (5 bloki atlikuši)
```

**Zaļš - ASSIGNED**
```
ASSIGNED - Aktīvs piešķīrums
Kalšanas adrese: pocx1qforger...
Izveidots augstumā: 12000
Aktivizēts augstumā: 12030
```

**Sarkani oranžs - REVOKING**
```
REVOKING - Atsaukšana gaida
Kalšanas adrese: pocx1qforger... (joprojām aktīva)
Piešķīrums izveidots augstumā: 12000
Atsaukts augstumā: 12300
Atsaukšana stājas spēkā augstumā: 13020 (50 bloki atlikuši)
```

**Sarkans - REVOKED**
```
REVOKED - Piešķīrums atsaukts
Iepriekš piešķirts: pocx1qforger...
Piešķīrums izveidots augstumā: 12000
Atsaukts augstumā: 12300
Atsaukšana stājās spēkā augstumā: 13020
```

---

## Darījumu vēsture

### Piešķīruma darījuma attēlošana

**Tips**: "Assignment"
**Ikona**: Kalnrūpniecības ikona (tāda pati kā iegūtiem blokiem)

**Adreses kolonna**: Plotfaila adrese (adrese, kuras kalšanas tiesības tiek piešķirtas)
**Summas kolonna**: Darījuma maksa (negatīva, izejošs darījums)
**Statusa kolonna**: Apstiprinājumu skaits (0-6+)

**Detaļas** (uzklikšķinot):
- Darījuma ID
- Plotfaila adrese
- Kalšanas adrese (parsēta no OP_RETURN)
- Izveidots augstumā
- Aktivizācijas augstums
- Darījuma maksa
- Laikspiedogs

### Atsaukšanas darījuma attēlošana

**Tips**: "Revocation"
**Ikona**: Kalnrūpniecības ikona

**Adreses kolonna**: Plotfaila adrese
**Summas kolonna**: Darījuma maksa (negatīva)
**Statusa kolonna**: Apstiprinājumu skaits

**Detaļas** (uzklikšķinot):
- Darījuma ID
- Plotfaila adrese
- Atsaukts augstumā
- Atsaukšanas spēkā stāšanās augstums
- Darījuma maksa
- Laikspiedogs

### Darījumu filtrēšana

**Pieejamie filtri**:
- "All" (noklusējums, ietver piešķīrumus/atsaukšanas)
- Datumu diapazons
- Summas diapazons
- Meklēt pēc adreses
- Meklēt pēc darījuma ID
- Meklēt pēc iezīmes (ja adrese iezīmēta)

**Piezīme**: Piešķīrumu/atsaukšanas darījumi pašlaik parādās zem "All" filtra. Veltīts tipa filtrs vēl nav implementēts.

### Darījumu kārtošana

**Kārtošanas secība** (pēc tipa):
- Ģenerēts (tips 0)
- Saņemts (tips 1-3)
- Piešķīrums (tips 4)
- Atsaukšana (tips 5)
- Nosūtīts (tips 6+)

---

## Adrešu prasības

### Tikai P2WPKH (SegWit v0)

**Kalšanas operācijām nepieciešams**:
- Bech32 kodētas adreses (sākas ar "pocx1q" mainnet, "tpocx1q" testnet, "rpocx1q" regtest)
- P2WPKH (Pay-to-Witness-Public-Key-Hash) formāts
- 20 baitu atslēgas jaucējvērtība

**NAV atbalstīts**:
- P2PKH (mantots, sākas ar "1")
- P2SH (ietīts SegWit, sākas ar "3")
- P2TR (Taproot, sākas ar "bc1p")

**Pamatojums**: PoCX bloku parakstiem nepieciešams specifisks liecības v0 formāts pierādījuma validācijai.

### Adrešu nolaižamā saraksta filtrēšana

**Plotfaila adreses ComboBox**:
- Automātiski aizpildīts ar maka saņemšanas adresēm
- Filtrē ārā ne-P2WPKH adreses
- Parāda formātu: "Iezīme (adrese)" ja iezīmēta, citādi tikai adrese
- Pirmais elements: "-- Enter custom address --" manuālai ievadei

**Manuāla ievade**:
- Validē formātu, kad ievadīts
- Jābūt derīgam bech32 P2WPKH
- Poga atspējota, ja nederīgs formāts

### Validācijas kļūdu ziņojumi

**Dialoga kļūdas**:
- "Plot address must be P2WPKH (bech32)"
- "Forging address must be P2WPKH (bech32)"
- "Invalid address format"
- "No coins available at the plot address. Cannot prove ownership."
- "Cannot create transactions with watch-only wallet"
- "Wallet not available"
- "Wallet locked" (no RPC)

---

## Kalnrūpniecības integrācija

### Iestatīšanas prasības

**Mezgla konfigurācija**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Maka prasības**:
- P2WPKH adreses plotfailu īpašumtiesībām
- Privātās atslēgas kalnrūpniecībai (vai kalšanas adrese, ja izmanto piešķīrumus)
- Apstiprināti UTXO darījumu izveidei

**Ārējie rīki**:
- `pocx_plotter`: Ģenerēt plotfailus
- `pocx_miner`: Skenēt plotfailus un iesniegt nonces

### Darbplūsma

#### Solo kalnrūpniecība

1. **Ģenerēt plotfailus**:
   ```bash
   pocx_plotter --account <plot_address_hash160> --seed <32_bytes> --nonces <count>
   ```

2. **Palaist mezglu** ar kalnrūpniecības serveri:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Konfigurēt kalnraci**:
   - Norādīt uz mezgla RPC galapunktu
   - Norādīt plotfailu direktorijas
   - Konfigurēt konta ID (no plotfaila adreses)

4. **Sākt kalnrūpniecību**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /path/to/plots
   ```

5. **Uzraudzīt**:
   - Kalnracis izsauc `get_mining_info` katru bloku
   - Skenē plotfailus labākajam termiņam
   - Izsauc `submit_nonce`, kad atrasts risinājums
   - Mezgls automātiski validē un kalš bloku

#### Pūla kalnrūpniecība

1. **Ģenerēt plotfailus** (tāpat kā solo kalnrūpniecībā)

2. **Izveidot kalšanas piešķīrumu**:
   - Atvērt kalšanas piešķīrumu dialogu
   - Izvēlēties plotfaila adresi
   - Ievadīt pūla kalšanas adresi
   - Noklikšķināt "Send Assignment"
   - Gaidīt aktivizācijas aizkavi (30 bloki testnet)

3. **Konfigurēt kalnraci**:
   - Norādīt uz **pūla** galapunktu (ne lokālo mezglu)
   - Pūls apstrādā `submit_nonce` uz ķēdi

4. **Pūla darbība**:
   - Pūla maciņam ir kalšanas adreses privātās atslēgas
   - Pūls validē iesniegums no kalnračiem
   - Pūls izsauc `submit_nonce` uz blokķēdi
   - Pūls izplata atlīdzības saskaņā ar pūla politiku

### Coinbase atlīdzības

**Bez piešķīruma**:
- Coinbase maksā tieši plotfaila īpašnieka adresei
- Pārbaudiet atlikumu plotfaila adresē

**Ar piešķīrumu**:
- Coinbase maksā kalšanas adresei
- Pūls saņem atlīdzības
- Kalnracis saņem daļu no pūla

**Atlīdzību grafiks**:
- Sākotnēji: 10 BTCX uz bloku
- Dalīšana: Ik 1050000 blokus (~4 gadi)
- Grafiks: 10 → 5 → 2.5 → 1.25 → ...

---

## Problēmu novēršana

### Biežākās problēmas

#### "Wallet does not have private key for plot address"

**Cēlonis**: Maciņam nepieder adrese
**Risinājums**:
- Importēt privāto atslēgu caur `importprivkey` RPC
- Vai izmantot citu plotfaila adresi, kas pieder maciņam

#### "Assignment already exists for this plot"

**Cēlonis**: Plotfails jau piešķirts citai adresei
**Risinājums**:
1. Atsaukt esošo piešķīrumu
2. Gaidīt atsaukšanas aizkavi (720 bloki testnet)
3. Izveidot jaunu piešķīrumu

#### "Address format not supported"

**Cēlonis**: Adrese nav P2WPKH bech32
**Risinājums**:
- Izmantot adreses, kas sākas ar "pocx1q" (mainnet) vai "tpocx1q" (testnet)
- Ģenerēt jaunu adresi, ja nepieciešams: `getnewaddress "" "bech32"`

#### "Transaction fee too low"

**Cēlonis**: Tīkla mempool pārslogots vai maksa pārāk zema retranslācijai
**Risinājums**:
- Palielināt maksas likmes parametru
- Gaidīt mempool attīrīšanos

#### "Assignment not yet active"

**Cēlonis**: Aktivizācijas aizkave vēl nav pagājusi
**Risinājums**:
- Pārbaudīt statusu: atlikušie bloki līdz aktivizācijai
- Gaidīt aizkaves perioda pabeigšanos

#### "No coins available at the plot address"

**Cēlonis**: Plotfaila adresei nav apstiprinātu UTXO
**Risinājums**:
1. Nosūtīt līdzekļus uz plotfaila adresi
2. Gaidīt 1 apstiprinājumu
3. Mēģināt piešķīruma izveidi vēlreiz

#### "Cannot create transactions with watch-only wallet"

**Cēlonis**: Maciņš importēja adresi bez privātās atslēgas
**Risinājums**: Importēt pilnu privāto atslēgu, ne tikai adresi

#### "Forging Assignment tab not visible"

**Cēlonis**: Mezgls palaists bez `-miningserver` karodziņa
**Risinājums**: Restartēt ar `bitcoin-qt -server -miningserver`

### Atkļūdošanas soļi

1. **Pārbaudīt maka statusu**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Verificēt adreses īpašumtiesības**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Pārbaudīt: "iswatchonly": false, "ismine": true
   ```

3. **Pārbaudīt piešķīruma statusu**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Apskatīt nesenos darījumus**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Pārbaudīt mezgla sinhronizāciju**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Verificēt: blocks == headers (pilnībā sinhronizēts)
   ```

---

## Drošības labākā prakse

### Plotfaila adreses drošība

**Atslēgu pārvaldība**:
- Glabājiet plotfaila adreses privātās atslēgas droši
- Piešķīruma darījumi pierāda īpašumtiesības caur parakstu
- Tikai plotfaila īpašnieks var izveidot/atsaukt piešķīrumus

**Dublējums**:
- Regulāri dublējiet maciņu (`dumpwallet` vai `backupwallet`)
- Glabājiet wallet.dat drošā vietā
- Ierakstiet atkopšanas frāzes, ja izmantojat HD maciņu

### Kalšanas adreses deleģēšana

**Drošības modelis**:
- Kalšanas adrese saņem bloku atlīdzības
- Kalšanas adrese var parakstīt blokus (kalnrūpniecība)
- Kalšanas adrese **nevar** modificēt vai atsaukt piešķīrumu
- Plotfaila īpašnieks saglabā pilnu kontroli

**Lietošanas gadījumi**:
- **Karstā maka deleģēšana**: Plotfaila atslēga aukstajā glabātuvē, kalšanas atslēga karstajā maciņā kalnrūpniecībai
- **Pūla kalnrūpniecība**: Deleģēt pūlam, saglabāt plotfaila īpašumtiesības
- **Dalīta infrastruktūra**: Vairāki kalnrači, viena kalšanas adrese

### Tīkla laika sinhronizācija

**Svarīgums**:
- PoCX konsensam nepieciešams precīzs laiks
- Pulksteņa nobīde >10s aktivizē brīdinājumu
- Pulksteņa nobīde >15s novērš kalnrūpniecību

**Risinājums**:
- Turiet sistēmas pulksteni sinhronizētu ar NTP
- Uzraugiet: `bitcoin-cli getnetworkinfo` laika nobīdes brīdinājumiem
- Izmantojiet uzticamus NTP serverus

### Piešķīrumu aizkaves

**Aktivizācijas aizkave** (30 bloki testnet):
- Novērš ātru pārpiešķiršanu ķēdes dakšu laikā
- Ļauj tīklam sasniegt konsensus
- Nevar apiet

**Atsaukšanas aizkave** (720 bloki testnet):
- Nodrošina stabilitāti kalnrūpniecības pūliem
- Novērš piešķīrumu "griefing" uzbrukumus
- Kalšanas adrese paliek aktīva aizkaves laikā

### Maka šifrēšana

**Iespējot šifrēšanu**:
```bash
bitcoin-cli encryptwallet "jusu_parole"
```

**Atbloķēt darījumiem**:
```bash
bitcoin-cli walletpassphrase "jusu_parole" 300
```

**Labākā prakse**:
- Izmantojiet spēcīgu paroli (20+ simboli)
- Neglabājiet paroli vienkāršā tekstā
- Bloķējiet maciņu pēc piešķīrumu izveides

---

## Koda atsauces

**Kalšanas piešķīrumu dialogs**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Darījumu attēlošana**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Darījumu parsēšana**: `src/qt/transactionrecord.cpp`
**Maka integrācija**: `src/pocx/assignments/transactions.cpp`
**Piešķīrumu RPC**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI galvenais**: `src/qt/bitcoingui.cpp`

---

## Savstarpējās atsauces

Saistītās nodaļas:
- [3. nodaļa: Konsensa un kalnrūpniecības process](3-consensus-and-mining.md) - Kalnrūpniecības process
- [4. nodaļa: Kalšanas piešķīrumi](4-forging-assignments.md) - Piešķīrumu arhitektūra
- [6. nodaļa: Tīkla parametri](6-network-parameters.md) - Piešķīrumu aizkaves vērtības
- [7. nodaļa: RPC atsauce](7-rpc-reference.md) - RPC komandu detaļas

---

[← Iepriekšējā: RPC atsauce](7-rpc-reference.md) | [📘 Satura rādītājs](index.md)
