[<- Eelmine: RPC viide](7-rpc-reference.md) | [Sisukord](index.md)

---

# Peatükk 8: Rahakoti ja graafilise liidese kasutusjuhend

Täielik juhend Bitcoin-PoCX Qt rahakotile ja sepistamisülesannete haldamisele.

---

## Sisukord

1. [Ülevaade](#ülevaade)
2. [Valuutaühikud](#valuutaühikud)
3. [Sepistamisülesannete dialoog](#sepistamisülesannete-dialoog)
4. [Tehingute ajalugu](#tehingute-ajalugu)
5. [Aadressi nõuded](#aadressi-nõuded)
6. [Kaevandamise integratsioon](#kaevandamise-integratsioon)
7. [Veaotsing](#veaotsing)
8. [Turvalisuse parimad praktikad](#turvalisuse-parimad-praktikad)

---

## Ülevaade

### Bitcoin-PoCX rahakoti funktsioonid

Bitcoin-PoCX Qt rahakott (`bitcoin-qt`) pakub:
- Standardset Bitcoin Core rahakoti funktsionaalsust (saatmine, vastuvõtmine, tehingute haldamine)
- **Sepistamisülesannete haldur**: GUI graafikuülesannete loomiseks/tühistamiseks
- **Kaevandamisserveri režiim**: `-miningserver` lipp lubab kaevandamisega seotud funktsioone
- **Tehingute ajalugu**: Ülesande ja tühistamise tehingute kuvamine

### Rahakoti käivitamine

**Ainult sõlm** (kaevandamiseta):
```bash
./build/bin/bitcoin-qt
```

**Kaevandamisega** (lubab ülesannete dialoogi):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Käsurea alternatiiv**:
```bash
./build/bin/bitcoind -miningserver
```

### Kaevandamise nõuded

**Kaevandamisoperatsioonideks**:
- `-miningserver` lipp vajalik
- Rahakott P2WPKH aadresside ja privaatvõtmetega
- Väline graafikukoostaja (`pocx_plotter`) graafikute genereerimiseks
- Väline kaevandaja (`pocx_miner`) kaevandamiseks

**Basseinikaevandamiseks**:
- Loo sepistamisülesanne basseini aadressile
- Basseiniserveris rahakotti pole vaja (bassein haldab võtmeid)

---

## Valuutaühikud

### Ühikute kuvamine

Bitcoin-PoCX kasutab **BTCX** valuutaühikut (mitte BTC):

| Ühik | Satoshid | Kuvamine |
|------|----------|----------|
| **BTCX** | 100000000 | 1.00000000 BTCX |
| **mBTCX** | 100000 | 1000.00 mBTCX |
| **µBTCX** | 100 | 1000000.00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**GUI seaded**: Eelistused -> Kuva -> Ühik

---

## Sepistamisülesannete dialoog

### Dialoogi avamine

**Menüü**: `Rahakott -> Sepistamisülesanded`
**Tööriistariba**: Kaevandamise ikoon (nähtav ainult `-miningserver` lipuga)
**Akna suurus**: 600×450 pikslit

### Dialoogirežiimid

#### Režiim 1: Loo ülesanne

**Eesmärk**: Delegeeri sepistamisõigused basseinile või teisele aadressile, säilitades graafikuomandi.

**Kasutusjuhud**:
- Basseinikaevandamine (määra basseini aadressile)
- Külm hoiustamine (kaevandamisvõti eraldi graafikuomandist)
- Jagatud infrastruktuur (delegeeri kuumale rahakotile)

**Nõuded**:
- Graafiku aadress (P2WPKH bech32, peab omama privaatvõtit)
- Sepistamise aadress (P2WPKH bech32, erinev graafiku aadressist)
- Rahakott lukustamata (kui krüpteeritud)
- Graafiku aadressil kinnitatud UTXO-d

**Sammud**:
1. Vali "Loo ülesanne" režiim
2. Vali graafiku aadress rippmenüüst või sisesta käsitsi
3. Sisesta sepistamise aadress (bassein või delegaat)
4. Klõpsa "Saada ülesanne" (nupp lubatud, kui sisendid kehtivad)
5. Tehing edastatakse kohe
6. Ülesanne aktiivne pärast `nForgingAssignmentDelay` plokke:
   - Mainnet/Testnet: 30 plokki (~1 tund)
   - Regtest: 4 plokki (~4 sekundit)

**Tehingutasu**: Vaikimisi 10× `minRelayFee` (kohandatav)

**Tehingu struktuur**:
- Sisend: UTXO graafiku aadressilt (tõestab omandi)
- OP_RETURN väljund: `POCX` marker + graafiku_aadress + sepistamise_aadress (46 baiti)
- Vahetusväljund: Tagastatakse rahakotti

#### Režiim 2: Tühista ülesanne

**Eesmärk**: Tühista sepistamisülesanne ja tagasta õigused graafikuomanikule.

**Nõuded**:
- Graafiku aadress (peab omama privaatvõtit)
- Rahakott lukustamata (kui krüpteeritud)
- Graafiku aadressil kinnitatud UTXO-d

**Sammud**:
1. Vali "Tühista ülesanne" režiim
2. Vali graafiku aadress
3. Klõpsa "Saada tühistamine"
4. Tehing edastatakse kohe
5. Tühistamine jõustub pärast `nForgingRevocationDelay` plokke:
   - Mainnet/Testnet: 720 plokki (~24 tundi)
   - Regtest: 8 plokki (~8 sekundit)

**Tulemus**:
- Sepistamise aadress saab endiselt sepistada viivitusperioodi jooksul
- Graafikuomanik taastab õigused pärast tühistamise lõppu
- Saab pärast luua uue ülesande

**Tehingu struktuur**:
- Sisend: UTXO graafiku aadressilt (tõestab omandi)
- OP_RETURN väljund: `XCOP` marker + graafiku_aadress (26 baiti)
- Vahetusväljund: Tagastatakse rahakotti

#### Režiim 3: Kontrolli ülesande staatust

**Eesmärk**: Päri praegust ülesande olekut mis tahes graafiku aadressi jaoks.

**Nõuded**: Puuduvad (ainult lugemiseks, rahakotti pole vaja)

**Sammud**:
1. Vali "Kontrolli ülesande staatust" režiim
2. Sisesta graafiku aadress
3. Klõpsa "Kontrolli staatust"
4. Staatuse kast kuvab praegust olekut koos detailidega

**Oleku indikaatorid** (värvikooditud):

**Hall - UNASSIGNED (Määramata)**
```
UNASSIGNED - Ülesannet pole
```

**Oranž - ASSIGNING (Määramisel)**
```
ASSIGNING - Ülesanne ootab aktiveerimist
Sepistamise aadress: pocx1qforger...
Loodud kõrgusel: 12000
Aktiveerub kõrgusel: 12030 (5 plokki jäänud)
```

**Roheline - ASSIGNED (Määratud)**
```
ASSIGNED - Aktiivne ülesanne
Sepistamise aadress: pocx1qforger...
Loodud kõrgusel: 12000
Aktiveeritud kõrgusel: 12030
```

**Punakaspunane - REVOKING (Tühistamisel)**
```
REVOKING - Tühistamine ootel
Sepistamise aadress: pocx1qforger... (endiselt aktiivne)
Ülesanne loodud kõrgusel: 12000
Tühistatud kõrgusel: 12300
Tühistamine jõustub kõrgusel: 13020 (50 plokki jäänud)
```

**Punane - REVOKED (Tühistatud)**
```
REVOKED - Ülesanne tühistatud
Varem määratud: pocx1qforger...
Ülesanne loodud kõrgusel: 12000
Tühistatud kõrgusel: 12300
Tühistamine jõustus kõrgusel: 13020
```

---

## Tehingute ajalugu

### Ülesande tehingu kuvamine

**Tüüp**: "Ülesanne"
**Ikoon**: Kaevandamise ikoon (sama mis kaevandatud plokkidel)

**Aadressi veerg**: Graafiku aadress (aadress, mille sepistamisõigused määratakse)
**Summa veerg**: Tehingutasu (negatiivne, väljaminev tehing)
**Staatuse veerg**: Kinnituste arv (0-6+)

**Detailid** (klikkides):
- Tehingu ID
- Graafiku aadress
- Sepistamise aadress (parsitud OP_RETURN-ist)
- Loodud kõrgusel
- Aktiveerimise kõrgus
- Tehingutasu
- Ajatempel

### Tühistamise tehingu kuvamine

**Tüüp**: "Tühistamine"
**Ikoon**: Kaevandamise ikoon

**Aadressi veerg**: Graafiku aadress
**Summa veerg**: Tehingutasu (negatiivne)
**Staatuse veerg**: Kinnituste arv

**Detailid** (klikkides):
- Tehingu ID
- Graafiku aadress
- Tühistatud kõrgusel
- Tühistamise jõustumise kõrgus
- Tehingutasu
- Ajatempel

### Tehingute filtreerimine

**Saadaolevad filtrid**:
- "Kõik" (vaikimisi, sisaldab ülesandeid/tühistamisi)
- Kuupäevavahemik
- Summavahemik
- Otsing aadressi järgi
- Otsing tehingu ID järgi
- Otsing sildi järgi (kui aadress on sildistatud)

**Märkus**: Ülesande/tühistamise tehingud ilmuvad praegu "Kõik" filtri all. Pühendatud tüübifilter pole veel implementeeritud.

### Tehingute sorteerimine

**Sortimise järjekord** (tüübi järgi):
- Genereeritud (tüüp 0)
- Vastuvõetud (tüüp 1-3)
- Ülesanne (tüüp 4)
- Tühistamine (tüüp 5)
- Saadetud (tüüp 6+)

---

## Aadressi nõuded

### Ainult P2WPKH (SegWit v0)

**Sepistamisoperatsioonid nõuavad**:
- Bech32 kodeeritud aadresse (algavad "pocx1q" mainnet, "tpocx1q" testnet, "rpocx1q" regtest)
- P2WPKH (Pay-to-Witness-Public-Key-Hash) vorming
- 20-baidine võtme räsi

**EI toetata**:
- P2PKH (pärand, algab "1"-ga)
- P2SH (mähitud SegWit, algab "3"-ga)
- P2TR (Taproot, algab "bc1p"-ga)

**Põhjendus**: PoCX ploki allkirjad nõuavad spetsiifilist witness v0 vormingut tõestuse valideerimiseks.

### Aadressi rippmenüü filtreerimine

**Graafiku aadressi ComboBox**:
- Automaatselt täidetud rahakoti vastuvõtvaadressidega
- Filtreerib välja mitte-P2WPKH aadressid
- Näitab vormingus: "Silt (aadress)" kui sildistatud, muidu lihtsalt aadress
- Esimene üksus: "-- Sisesta kohandatud aadress --" käsitsi sisestamiseks

**Käsitsi sisestamine**:
- Valideerib vormingut sisestamisel
- Peab olema kehtiv bech32 P2WPKH
- Nupp keelatud, kui vorming kehtetu

### Valideerimise veateated

**Dialoogi vead**:
- "Graafiku aadress peab olema P2WPKH (bech32)"
- "Sepistamise aadress peab olema P2WPKH (bech32)"
- "Kehtetu aadressi vorming"
- "Graafiku aadressil pole münte. Ei saa tõestada omandi."
- "Ei saa luua tehinguid ainult vaatamise rahakotiga"
- "Rahakott pole saadaval"
- "Rahakott lukustatud" (RPC-st)

---

## Kaevandamise integratsioon

### Seadistuse nõuded

**Sõlme konfiguratsioon**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Rahakoti nõuded**:
- P2WPKH aadressid graafikuomandi jaoks
- Privaatvõtmed kaevandamiseks (või sepistamise aadress, kui kasutatakse ülesandeid)
- Kinnitatud UTXO-d tehingute loomiseks

**Välised tööriistad**:
- `pocx_plotter`: Genereeri graafikufaile
- `pocx_miner`: Skaneeri graafikuid ja esita nonce'e

### Töövoog

#### Üksi kaevandamine

1. **Genereeri graafikufailid**:
   ```bash
   pocx_plotter --account <graafiku_aadressi_hash160> --seed <32_baiti> --nonces <kogus>
   ```

2. **Käivita sõlm** kaevandamisserveriga:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Konfigureeri kaevandaja**:
   - Suuna sõlme RPC lõpp-punktile
   - Määra graafikufailide kataloogid
   - Konfigureeri konto ID (graafiku aadressist)

4. **Alusta kaevandamist**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /tee/graafikuteni
   ```

5. **Jälgi**:
   - Kaevandaja kutsub `get_mining_info` igal plokil
   - Skaneerib graafikuid parima tähtaja leidmiseks
   - Kutsub `submit_nonce`, kui lahendus leitud
   - Sõlm valideerib ja sepistab ploki automaatselt

#### Basseinikaevandamine

1. **Genereeri graafikufailid** (sama mis üksi kaevandamisel)

2. **Loo sepistamisülesanne**:
   - Ava sepistamisülesannete dialoog
   - Vali graafiku aadress
   - Sisesta basseini sepistamise aadress
   - Klõpsa "Saada ülesanne"
   - Oota aktiveerimise viivitust (30 plokki testnet)

3. **Konfigureeri kaevandaja**:
   - Suuna **basseini** lõpp-punktile (mitte kohalikule sõlmele)
   - Bassein käsitleb `submit_nonce` ahelale

4. **Basseini töö**:
   - Basseini rahakotis on sepistamise aadressi privaatvõtmed
   - Bassein valideerib esitamisi kaevandajatelt
   - Bassein kutsub `submit_nonce` plokiahelale
   - Bassein jagab tasud vastavalt basseini poliitikale

### Coinbase tasud

**Ülesannet pole**:
- Coinbase maksab graafikuomaniku aadressile otse
- Kontrolli saldot graafiku aadressil

**Ülesandega**:
- Coinbase maksab sepistamise aadressile
- Bassein saab tasud
- Kaevandaja saab osa basseinilt

**Tasude graafik**:
- Algne: 10 BTCX ploki kohta
- Poolnemine: Iga 1050000 ploki järel (~4 aastat)
- Graafik: 10 -> 5 -> 2.5 -> 1.25 -> ...

---

## Veaotsing

### Levinud probleemid

#### "Rahakotis pole graafiku aadressi privaatvõtit"

**Põhjus**: Rahakott ei oma aadressi
**Lahendus**:
- Impordi privaatvõti `importprivkey` RPC kaudu
- Või kasuta teist rahakotile kuuluvat graafiku aadressi

#### "Sellele graafikule on juba ülesanne"

**Põhjus**: Graafik on juba määratud teisele aadressile
**Lahendus**:
1. Tühista olemasolev ülesanne
2. Oota tühistamise viivitust (720 plokki testnet)
3. Loo uus ülesanne

#### "Aadressi vorming pole toetatud"

**Põhjus**: Aadress pole P2WPKH bech32
**Lahendus**:
- Kasuta aadresse, mis algavad "pocx1q" (mainnet) või "tpocx1q" (testnet)
- Vajadusel genereeri uus aadress: `getnewaddress "" "bech32"`

#### "Tehingutasu liiga madal"

**Põhjus**: Võrgu mempool'i ülekoormus või tasu liiga madal edastamiseks
**Lahendus**:
- Suurenda tasumäära parameetrit
- Oota mempool'i tühjendamist

#### "Ülesanne pole veel aktiivne"

**Põhjus**: Aktiveerimise viivitus pole veel möödunud
**Lahendus**:
- Kontrolli staatust: mitu plokki aktiveerimiseni jäänud
- Oota viivitusperioodi lõpuni

#### "Graafiku aadressil pole münte"

**Põhjus**: Graafiku aadressil pole kinnitatud UTXO-sid
**Lahendus**:
1. Saada vahendid graafiku aadressile
2. Oota 1 kinnitus
3. Proovi uuesti ülesande loomist

#### "Ei saa luua tehinguid ainult vaatamise rahakotiga"

**Põhjus**: Rahakott importis aadressi ilma privaatvõtmeta
**Lahendus**: Impordi täielik privaatvõti, mitte ainult aadress

#### "Sepistamisülesannete sakk pole nähtav"

**Põhjus**: Sõlm käivitati ilma `-miningserver` liputa
**Lahendus**: Taaskäivita `bitcoin-qt -server -miningserver`

### Silumise sammud

1. **Kontrolli rahakoti staatust**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Verifitseeri aadressi omand**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Kontrolli: "iswatchonly": false, "ismine": true
   ```

3. **Kontrolli ülesande staatust**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Vaata hiljutisi tehinguid**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Kontrolli sõlme sünkroniseerimist**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Verifitseeri: blocks == headers (täielikult sünkroniseeritud)
   ```

---

## Turvalisuse parimad praktikad

### Graafiku aadressi turvalisus

**Võtmete haldamine**:
- Hoia graafiku aadressi privaatvõtmeid turvaliselt
- Ülesande tehingud tõestavad omandi allkirja kaudu
- Ainult graafikuomanik saab luua/tühistada ülesandeid

**Varundamine**:
- Varunda rahakotti regulaarselt (`dumpwallet` või `backupwallet`)
- Hoia wallet.dat turvalises kohas
- Salvesta taastefraasid, kui kasutad HD rahakotti

### Sepistamise aadressi delegeerimine

**Turvamudel**:
- Sepistamise aadress saab ploki tasud
- Sepistamise aadress saab allkirjastada plokke (kaevandamine)
- Sepistamise aadress **ei saa** muuta ega tühistada ülesannet
- Graafikuomanik säilitab täieliku kontrolli

**Kasutusjuhud**:
- **Kuuma rahakoti delegeerimine**: Graafikuvõti külmas hoiustuses, sepistamisvõti kuumas rahakotis kaevandamiseks
- **Basseinikaevandamine**: Delegeeri basseinile, säilita graafikuomand
- **Jagatud infrastruktuur**: Mitu kaevandajat, üks sepistamise aadress

### Võrgu ajasünkroniseerimine

**Tähtsus**:
- PoCX konsensus nõuab täpset aega
- Kellanihe >10s käivitab hoiatuse
- Kellanihe >15s takistab kaevandamist

**Lahendus**:
- Hoia süsteemikell sünkroniseeritud NTP-ga
- Jälgi: `bitcoin-cli getnetworkinfo` ajanihe hoiatuste jaoks
- Kasuta usaldusväärseid NTP servereid

### Ülesannete viivitused

**Aktiveerimise viivitus** (30 plokki testnet):
- Takistab kiiret ümberseadistamist ahela hargnemisel
- Võimaldab võrgul jõuda konsensusele
- Ei saa mööda minna

**Tühistamise viivitus** (720 plokki testnet):
- Tagab stabiilsuse kaevandamisbasseinidele
- Takistab ülesande "kiusamise" rünnakuid
- Sepistamise aadress jääb viivituse ajal aktiivseks

### Rahakoti krüpteerimine

**Luba krüpteerimine**:
```bash
bitcoin-cli encryptwallet "sinu_parool"
```

**Lukusta lahti tehinguteks**:
```bash
bitcoin-cli walletpassphrase "sinu_parool" 300
```

**Parimad praktikad**:
- Kasuta tugevat parooli (20+ tähemärki)
- Ära hoia parooli lihttekstina
- Lukusta rahakott pärast ülesannete loomist

---

## Koodi viited

**Sepistamisülesannete dialoog**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Tehingute kuvamine**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Tehingute parsimine**: `src/qt/transactionrecord.cpp`
**Rahakoti integratsioon**: `src/pocx/assignments/transactions.cpp`
**Ülesannete RPC-d**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI peamine**: `src/qt/bitcoingui.cpp`

---

## Ristviited

Seotud peatükid:
- [Peatükk 3: Konsensus ja kaevandamine](3-consensus-and-mining.md) - Kaevandamisprotsess
- [Peatükk 4: Sepistamisülesanded](4-forging-assignments.md) - Ülesannete arhitektuur
- [Peatükk 6: Võrguparameetrid](6-network-parameters.md) - Ülesannete viivituse väärtused
- [Peatükk 7: RPC viide](7-rpc-reference.md) - RPC käskude detailid

---

[<- Eelmine: RPC viide](7-rpc-reference.md) | [Sisukord](index.md)
