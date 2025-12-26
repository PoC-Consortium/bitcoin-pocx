[← Iliyotangulia: Marejeleo ya RPC](7-rpc-reference.md) | [Yaliyomo](index.md)

---

# Sura ya 8: Mwongozo wa Mtumiaji wa Pochi na GUI

Mwongozo kamili wa pochi ya Bitcoin-PoCX Qt na usimamizi wa ugawaji wa kuunda.

---

## Yaliyomo

1. [Muhtasari](#muhtasari)
2. [Vitengo vya Sarafu](#vitengo-vya-sarafu)
3. [Kisanduku cha Mazungumzo cha Ugawaji wa Kuunda](#kisanduku-cha-mazungumzo-cha-ugawaji-wa-kuunda)
4. [Historia ya Miamala](#historia-ya-miamala)
5. [Mahitaji ya Anwani](#mahitaji-ya-anwani)
6. [Muungano wa Uchimbaji](#muungano-wa-uchimbaji)
7. [Utatuzi wa Matatizo](#utatuzi-wa-matatizo)
8. [Mazoea Bora ya Usalama](#mazoea-bora-ya-usalama)

---

## Muhtasari

### Vipengele vya Pochi ya Bitcoin-PoCX

Pochi ya Bitcoin-PoCX Qt (`bitcoin-qt`) inatoa:
- Utendaji wa kawaida wa pochi ya Bitcoin Core (kutuma, kupokea, usimamizi wa miamala)
- **Meneja wa Ugawaji wa Kuunda**: GUI ya kuunda/kubatilisha ugawaji wa plot
- **Hali ya Seva ya Uchimbaji**: Bendera ya `-miningserver` inawezesha vipengele vinavyohusiana na uchimbaji
- **Historia ya Miamala**: Kuonyesha miamala ya ugawaji na kubatilisha

### Kuanzisha Pochi

**Nodi Pekee** (hakuna uchimbaji):
```bash
./build/bin/bitcoin-qt
```

**Na Uchimbaji** (inawezesha kisanduku cha mazungumzo cha ugawaji):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Mbadala wa Mstari wa Amri**:
```bash
./build/bin/bitcoind -miningserver
```

### Mahitaji ya Uchimbaji

**Kwa Operesheni za Uchimbaji**:
- Bendera ya `-miningserver` inahitajika
- Pochi na anwani za P2WPKH na funguo za kibinafsi
- Plotter wa nje (`pocx_plotter`) kwa uzalishaji wa plot
- Miner wa nje (`pocx_miner`) kwa uchimbaji

**Kwa Uchimbaji wa Dimbwi**:
- Unda ugawaji wa kuunda kwa anwani ya dimbwi
- Pochi haihitajiki kwenye seva ya dimbwi (dimbwi linasimamia funguo)

---

## Vitengo vya Sarafu

### Kuonyesha Kitengo

Bitcoin-PoCX inatumia kitengo cha sarafu **BTCX** (sio BTC):

| Kitengo | Satoshi | Kuonyesha |
|------|----------|---------|
| **BTCX** | 100000000 | 1.00000000 BTCX |
| **mBTCX** | 100000 | 1000.00 mBTCX |
| **µBTCX** | 100 | 1000000.00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**Mipangilio ya GUI**: Mapendeleo → Kuonyesha → Kitengo

---

## Kisanduku cha Mazungumzo cha Ugawaji wa Kuunda

### Kufikia Kisanduku cha Mazungumzo

**Menyu**: `Pochi → Ugawaji wa Kuunda`
**Toolbar**: Ikoni ya uchimbaji (inaonekana tu na bendera ya `-miningserver`)
**Ukubwa wa Dirisha**: Pikseli 600×450

### Hali za Kisanduku cha Mazungumzo

#### Hali ya 1: Unda Ugawaji

**Madhumuni**: Kabidhi haki za kuunda kwa dimbwi au anwani nyingine huku ukihifadhi umiliki wa plot.

**Matumizi**:
- Uchimbaji wa dimbwi (kabidhi kwa anwani ya dimbwi)
- Hifadhi baridi (ufunguo wa uchimbaji tofauti na umiliki wa plot)
- Miundombinu iliyoshirikiwa (kabidhi kwa pochi ya moto)

**Mahitaji**:
- Anwani ya plot (P2WPKH bech32, lazima umiliki ufunguo wa kibinafsi)
- Anwani ya kuunda (P2WPKH bech32, tofauti na anwani ya plot)
- Pochi imefunguliwa (ikiwa imesimbwa)
- Anwani ya plot ina UTXO zilizothibitishwa

**Hatua**:
1. Chagua hali ya "Unda Ugawaji"
2. Chagua anwani ya plot kutoka orodha au ingiza kwa mkono
3. Ingiza anwani ya kuunda (dimbwi au mwakilishi)
4. Bonyeza "Tuma Ugawaji" (kitufe kinawezeshwa wakati ingizo ni halali)
5. Muamala unatangazwa mara moja
6. Ugawaji unakuwa hai baada ya bloku `nForgingAssignmentDelay`:
   - Mainnet/Testnet: bloku 30 (~saa 1)
   - Regtest: bloku 4 (~sekunde 4)

**Ada ya Muamala**: Default 10× `minRelayFee` (inaweza kusanidiwa)

**Muundo wa Muamala**:
- Ingizo: UTXO kutoka anwani ya plot (inathibitisha umiliki)
- Tokeo la OP_RETURN: Alama ya `POCX` + plot_address + forging_address (byte 46)
- Tokeo la chenji: Inarudi kwa pochi

#### Hali ya 2: Batilisha Ugawaji

**Madhumuni**: Ghairi ugawaji wa kuunda na rudisha haki kwa mmiliki wa plot.

**Mahitaji**:
- Anwani ya plot (lazima umiliki ufunguo wa kibinafsi)
- Pochi imefunguliwa (ikiwa imesimbwa)
- Anwani ya plot ina UTXO zilizothibitishwa

**Hatua**:
1. Chagua hali ya "Batilisha Ugawaji"
2. Chagua anwani ya plot
3. Bonyeza "Tuma Kubatilisha"
4. Muamala unatangazwa mara moja
5. Kubatilisha kunakuwa hai baada ya bloku `nForgingRevocationDelay`:
   - Mainnet/Testnet: bloku 720 (~saa 24)
   - Regtest: bloku 8 (~sekunde 8)

**Athari**:
- Anwani ya kuunda bado inaweza kuunda wakati wa kipindi cha ucheleweshaji
- Mmiliki wa plot anarudishiwa haki baada ya kubatilisha kukamilika
- Anaweza kuunda ugawaji mpya baadaye

**Muundo wa Muamala**:
- Ingizo: UTXO kutoka anwani ya plot (inathibitisha umiliki)
- Tokeo la OP_RETURN: Alama ya `XCOP` + plot_address (byte 26)
- Tokeo la chenji: Inarudi kwa pochi

#### Hali ya 3: Angalia Hali ya Ugawaji

**Madhumuni**: Hoji hali ya sasa ya ugawaji kwa anwani yoyote ya plot.

**Mahitaji**: Hakuna (kusoma pekee, hakuna pochi inayohitajika)

**Hatua**:
1. Chagua hali ya "Angalia Hali ya Ugawaji"
2. Ingiza anwani ya plot
3. Bonyeza "Angalia Hali"
4. Kisanduku cha hali kinaonyesha hali ya sasa na maelezo

**Viashiria vya Hali** (vimepakwa rangi):

**Kijivu - UNASSIGNED**
```
UNASSIGNED - Hakuna ugawaji uliopo
```

**Machungwa - ASSIGNING**
```
ASSIGNING - Ugawaji unasubiri uanzishaji
Anwani ya Kuunda: pocx1qforger...
Iliundwa katika urefu: 12000
Inakuwa hai katika urefu: 12030 (bloku 5 zimebaki)
```

**Kijani - ASSIGNED**
```
ASSIGNED - Ugawaji unaofanya kazi
Anwani ya Kuunda: pocx1qforger...
Iliundwa katika urefu: 12000
Ilikuwa hai katika urefu: 12030
```

**Machungwa-Nyekundu - REVOKING**
```
REVOKING - Kubatilisha kunasubiri
Anwani ya Kuunda: pocx1qforger... (bado inafanya kazi)
Ugawaji uliundwa katika urefu: 12000
Ulibatilishwa katika urefu: 12300
Kubatilisha kunakuwa hai katika urefu: 13020 (bloku 50 zimebaki)
```

**Nyekundu - REVOKED**
```
REVOKED - Ugawaji umebatilishwa
Hapo awali ilikabidhiwa kwa: pocx1qforger...
Ugawaji uliundwa katika urefu: 12000
Ulibatilishwa katika urefu: 12300
Kubatilisha kulikuwa hai katika urefu: 13020
```

---

## Historia ya Miamala

### Kuonyesha Muamala wa Ugawaji

**Aina**: "Ugawaji"
**Ikoni**: Ikoni ya uchimbaji (sawa na bloku zilizochimbwa)

**Safu ya Anwani**: Anwani ya plot (anwani ambayo haki zake za kuunda zinagawiwa)
**Safu ya Kiasi**: Ada ya muamala (hasi, muamala unaotoka)
**Safu ya Hali**: Idadi ya uthibitisho (0-6+)

**Maelezo** (unapobonyeza):
- Kitambulisho cha muamala
- Anwani ya plot
- Anwani ya kuunda (imechanaguliwa kutoka OP_RETURN)
- Iliundwa katika urefu
- Urefu wa uanzishaji
- Ada ya muamala
- Muda

### Kuonyesha Muamala wa Kubatilisha

**Aina**: "Kubatilisha"
**Ikoni**: Ikoni ya uchimbaji

**Safu ya Anwani**: Anwani ya plot
**Safu ya Kiasi**: Ada ya muamala (hasi)
**Safu ya Hali**: Idadi ya uthibitisho

**Maelezo** (unapobonyeza):
- Kitambulisho cha muamala
- Anwani ya plot
- Ilibatilishwa katika urefu
- Urefu wa kubatilisha kukuwa hai
- Ada ya muamala
- Muda

### Kuchuja Miamala

**Vichujio Vinavyopatikana**:
- "Zote" (default, inajumuisha ugawaji/kubatilisha)
- Kipindi cha tarehe
- Kipindi cha kiasi
- Kutafuta kwa anwani
- Kutafuta kwa kitambulisho cha muamala
- Kutafuta kwa lebo (ikiwa anwani imepewa lebo)

**Kumbuka**: Miamala ya Ugawaji/Kubatilisha kwa sasa inaonekana chini ya kichujio cha "Zote". Kichujio maalum cha aina bado hakijatekelezwa.

### Kupanga Miamala

**Mpangilio wa Kupanga** (kwa aina):
- Ilizalishwa (aina 0)
- Ilipokelewa (aina 1-3)
- Ugawaji (aina 4)
- Kubatilisha (aina 5)
- Ilitumwa (aina 6+)

---

## Mahitaji ya Anwani

### P2WPKH (SegWit v0) Pekee

**Operesheni za kuunda zinahitaji**:
- Anwani zilizosimbwa kwa Bech32 (zinaanza na "pocx1q" mainnet, "tpocx1q" testnet, "rpocx1q" regtest)
- Muundo wa P2WPKH (Pay-to-Witness-Public-Key-Hash)
- Hash ya ufunguo wa byte 20

**HAISAIDIWI**:
- P2PKH (za zamani, zinaanza na "1")
- P2SH (SegWit iliyofungwa, zinaanza na "3")
- P2TR (Taproot, zinaanza na "bc1p")

**Sababu**: Sahihi za bloku za PoCX zinahitaji muundo maalum wa shahidi v0 kwa uthibitishaji wa uthibitisho.

### Kuchuja Orodha ya Anwani

**ComboBox ya Anwani ya Plot**:
- Inajazwa moja kwa moja na anwani za kupokea za pochi
- Inachuja anwani zisizo za P2WPKH
- Inaonyesha muundo: "Lebo (anwani)" ikiwa imepewa lebo, vinginevyo anwani pekee
- Kipengele cha kwanza: "-- Ingiza anwani ya desturi --" kwa kuingiza kwa mkono

**Kuingiza kwa Mkono**:
- Inathiditisha muundo inapoingizwa
- Lazima iwe bech32 P2WPKH halali
- Kitufe kimezimwa ikiwa muundo si sahihi

### Ujumbe wa Kosa wa Uthibitishaji

**Makosa ya Kisanduku cha Mazungumzo**:
- "Anwani ya plot lazima iwe P2WPKH (bech32)"
- "Anwani ya kuunda lazima iwe P2WPKH (bech32)"
- "Muundo wa anwani si sahihi"
- "Hakuna sarafu zinazopatikana kwenye anwani ya plot. Haiwezi kuthibitisha umiliki."
- "Haiwezi kuunda miamala na pochi ya kuangalia pekee"
- "Pochi haipatikani"
- "Pochi imefungwa" (kutoka RPC)

---

## Muungano wa Uchimbaji

### Mahitaji ya Usanidi

**Usanidi wa Nodi**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Mahitaji ya Pochi**:
- Anwani za P2WPKH kwa umiliki wa plot
- Funguo za kibinafsi kwa uchimbaji (au anwani ya kuunda ikiwa unatumia ugawaji)
- UTXO zilizothibitishwa kwa uundaji wa miamala

**Zana za Nje**:
- `pocx_plotter`: Zalisha faili za plot
- `pocx_miner`: Changanua plot na wasilisha nonce

### Mtiririko wa Kazi

#### Uchimbaji wa Peke Yako

1. **Zalisha Faili za Plot**:
   ```bash
   pocx_plotter --account <plot_address_hash160> --seed <32_bytes> --nonces <count>
   ```

2. **Anzisha Nodi** na seva ya uchimbaji:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Sanidi Miner**:
   - Elekeza kwa endpoint ya RPC ya nodi
   - Bainisha saraka za faili za plot
   - Sanidi kitambulisho cha akaunti (kutoka anwani ya plot)

4. **Anza Uchimbaji**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /path/to/plots
   ```

5. **Fuatilia**:
   - Miner inaita `get_mining_info` kila bloku
   - Inachanganua plot kwa tarehe ya mwisho bora zaidi
   - Inaita `submit_nonce` suluhisho linapopatikana
   - Nodi inathiditisha na kuunda bloku moja kwa moja

#### Uchimbaji wa Dimbwi

1. **Zalisha Faili za Plot** (sawa na peke yako)

2. **Unda Ugawaji wa Kuunda**:
   - Fungua Kisanduku cha Mazungumzo cha Ugawaji wa Kuunda
   - Chagua anwani ya plot
   - Ingiza anwani ya kuunda ya dimbwi
   - Bonyeza "Tuma Ugawaji"
   - Subiri ucheleweshaji wa uanzishaji (bloku 30 testnet)

3. **Sanidi Miner**:
   - Elekeza kwa endpoint ya **dimbwi** (sio nodi ya ndani)
   - Dimbwi linashughulikia `submit_nonce` kwa mtandao

4. **Operesheni ya Dimbwi**:
   - Pochi ya dimbwi ina funguo za kibinafsi za anwani ya kuunda
   - Dimbwi linathiditisha uwasilishaji kutoka kwa wachimbaji
   - Dimbwi linaita `submit_nonce` kwa blockchain
   - Dimbwi linasambaza zawadi kulingana na sera ya dimbwi

### Zawadi za Coinbase

**Hakuna Ugawaji**:
- Coinbase inalipa anwani ya mmiliki wa plot moja kwa moja
- Angalia bakaa katika anwani ya plot

**Na Ugawaji**:
- Coinbase inalipa anwani ya kuunda
- Dimbwi linapokea zawadi
- Mchimbaji anapokea sehemu kutoka dimbwi

**Ratiba ya Zawadi**:
- Awali: 10 BTCX kwa bloku
- Nusu: Kila bloku 1050000 (~miaka 4)
- Ratiba: 10 → 5 → 2.5 → 1.25 → ...

---

## Utatuzi wa Matatizo

### Matatizo ya Kawaida

#### "Pochi haina ufunguo wa kibinafsi kwa anwani ya plot"

**Sababu**: Pochi haimimiliki anwani
**Suluhisho**:
- Ingiza ufunguo wa kibinafsi kupitia RPC ya `importprivkey`
- Au tumia anwani tofauti ya plot inayomilikiwa na pochi

#### "Ugawaji tayari upo kwa plot hii"

**Sababu**: Plot tayari imekabidhiwa kwa anwani nyingine
**Suluhisho**:
1. Batilisha ugawaji uliopo
2. Subiri ucheleweshaji wa kubatilisha (bloku 720 testnet)
3. Unda ugawaji mpya

#### "Muundo wa anwani hausaidiwi"

**Sababu**: Anwani si P2WPKH bech32
**Suluhisho**:
- Tumia anwani zinazoanza na "pocx1q" (mainnet) au "tpocx1q" (testnet)
- Zalisha anwani mpya ikiwa inahitajika: `getnewaddress "" "bech32"`

#### "Ada ya muamala ni ndogo sana"

**Sababu**: Msongamano wa mempool ya mtandao au ada ni ndogo sana kwa upitishaji
**Suluhisho**:
- Ongeza kigezo cha kiwango cha ada
- Subiri mempool isafishwe

#### "Ugawaji bado haujaanza"

**Sababu**: Ucheleweshaji wa uanzishaji bado haujapita
**Suluhisho**:
- Angalia hali: bloku zilizobaki hadi uanzishaji
- Subiri kipindi cha ucheleweshaji kikamilike

#### "Hakuna sarafu zinazopatikana kwenye anwani ya plot"

**Sababu**: Anwani ya plot haina UTXO zilizothibitishwa
**Suluhisho**:
1. Tuma fedha kwa anwani ya plot
2. Subiri uthibitisho 1
3. Jaribu tena kuunda ugawaji

#### "Haiwezi kuunda miamala na pochi ya kuangalia pekee"

**Sababu**: Pochi iliingiza anwani bila ufunguo wa kibinafsi
**Suluhisho**: Ingiza ufunguo kamili wa kibinafsi, si anwani pekee

#### "Kichupo cha Ugawaji wa Kuunda hakionekani"

**Sababu**: Nodi ilianzishwa bila bendera ya `-miningserver`
**Suluhisho**: Anzisha tena na `bitcoin-qt -server -miningserver`

### Hatua za Utatuzi

1. **Angalia Hali ya Pochi**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Thibitisha Umiliki wa Anwani**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Angalia: "iswatchonly": false, "ismine": true
   ```

3. **Angalia Hali ya Ugawaji**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Ona Miamala ya Hivi Karibuni**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Angalia Usawazishaji wa Nodi**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Thibitisha: blocks == headers (imesawazishwa kikamilifu)
   ```

---

## Mazoea Bora ya Usalama

### Usalama wa Anwani ya Plot

**Usimamizi wa Ufunguo**:
- Hifadhi funguo za kibinafsi za anwani ya plot kwa usalama
- Miamala ya ugawaji inathibitisha umiliki kupitia sahihi
- Mmiliki wa plot pekee anaweza kuunda/kubatilisha ugawaji

**Hifadhi Nakala**:
- Hifadhi nakala ya pochi mara kwa mara (`dumpwallet` au `backupwallet`)
- Hifadhi wallet.dat mahali salama
- Andika misemo ya uokoaji ikiwa unatumia pochi ya HD

### Ukabidhi wa Anwani ya Kuunda

**Mfumo wa Usalama**:
- Anwani ya kuunda inapokea zawadi za bloku
- Anwani ya kuunda inaweza kusaini bloku (uchimbaji)
- Anwani ya kuunda **haiwezi** kurekebisha au kubatilisha ugawaji
- Mmiliki wa plot anabaki na udhibiti kamili

**Matumizi**:
- **Ukabidhi wa Pochi ya Moto**: Ufunguo wa plot katika hifadhi baridi, ufunguo wa kuunda katika pochi ya moto kwa uchimbaji
- **Uchimbaji wa Dimbwi**: Kabidhi kwa dimbwi, dumisha umiliki wa plot
- **Miundombinu Iliyoshirikiwa**: Wachimbaji wengi, anwani moja ya kuunda

### Usawazishaji wa Muda wa Mtandao

**Umuhimu**:
- Makubaliano ya PoCX yanahitaji muda sahihi
- Mkengeuko wa saa >10s unasababisha onyo
- Mkengeuko wa saa >15s unazuia uchimbaji

**Suluhisho**:
- Dumisha saa ya mfumo ikiwa imesawazishwa na NTP
- Fuatilia: `bitcoin-cli getnetworkinfo` kwa maonyo ya mkengeuko wa muda
- Tumia seva za NTP za kuaminika

### Ucheleweshaji wa Ugawaji

**Ucheleweshaji wa Uanzishaji** (bloku 30 testnet):
- Unazuia ugawaji upya wa haraka wakati wa fork za mtandao
- Unaruhusu mtandao kufikia makubaliano
- Hauwezi kupitwa

**Ucheleweshaji wa Kubatilisha** (bloku 720 testnet):
- Unatoa uthabiti kwa madimbwi ya uchimbaji
- Unazuia mashambulizi ya "kusogea kwa ugawaji"
- Anwani ya kuunda inabaki hai wakati wa ucheleweshaji

### Usimbaji wa Pochi

**Wezesha Usimbaji**:
```bash
bitcoin-cli encryptwallet "nywila_yako"
```

**Fungua kwa Miamala**:
```bash
bitcoin-cli walletpassphrase "nywila_yako" 300
```

**Mazoea Bora**:
- Tumia nywila imara (herufi 20+)
- Usihifadhi nywila katika maandishi wazi
- Funga pochi baada ya kuunda ugawaji

---

## Marejeleo ya Msimbo

**Kisanduku cha Mazungumzo cha Ugawaji wa Kuunda**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Kuonyesha Miamala**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Kuchambua Miamala**: `src/qt/transactionrecord.cpp`
**Muungano wa Pochi**: `src/pocx/assignments/transactions.cpp`
**RPC za Ugawaji**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI Kuu**: `src/qt/bitcoingui.cpp`

---

## Marejeleo ya Msalaba

Sura zinazohusiana:
- [Sura ya 3: Makubaliano na Uchimbaji](3-consensus-and-mining.md) - Mchakato wa uchimbaji
- [Sura ya 4: Ugawaji wa Kuunda](4-forging-assignments.md) - Muundo wa ugawaji
- [Sura ya 6: Vigezo vya Mtandao](6-network-parameters.md) - Thamani za ucheleweshaji wa ugawaji
- [Sura ya 7: Marejeleo ya RPC](7-rpc-reference.md) - Maelezo ya amri za RPC

---

[← Iliyotangulia: Marejeleo ya RPC](7-rpc-reference.md) | [Yaliyomo](index.md)
