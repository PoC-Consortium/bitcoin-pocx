[← Nakaraan: Sanggunian ng RPC](7-rpc-reference.md) | [📘 Talaan ng mga Nilalaman](index.md)

---

# Kabanata 8: Gabay sa Wallet at GUI ng Gumagamit

Kumpletong gabay sa Bitcoin-PoCX Qt wallet at pamamahala ng forging assignment.

---

## Talaan ng mga Nilalaman

1. [Pangkalahatang-tanaw](#pangkalahatang-tanaw)
2. [Mga Yunit ng Pera](#mga-yunit-ng-pera)
3. [Dialog ng Forging Assignment](#dialog-ng-forging-assignment)
4. [Kasaysayan ng Transaksyon](#kasaysayan-ng-transaksyon)
5. [Mga Kinakailangan sa Address](#mga-kinakailangan-sa-address)
6. [Integrasyon sa Mining](#integrasyon-sa-mining)
7. [Troubleshooting](#troubleshooting)
8. [Mga Pinakamahusay na Kasanayan sa Seguridad](#mga-pinakamahusay-na-kasanayan-sa-seguridad)

---

## Pangkalahatang-tanaw

### Mga Tampok ng Bitcoin-PoCX Wallet

Ang Bitcoin-PoCX Qt wallet (`bitcoin-qt`) ay nagbibigay ng:
- Standard na functionality ng Bitcoin Core wallet (magpadala, makatanggap, pamamahala ng transaksyon)
- **Forging Assignment Manager**: GUI para sa paggawa/pag-revoke ng mga plot assignment
- **Mining Server Mode**: Ang `-miningserver` flag ay nagpapagana ng mga tampok na may kinalaman sa mining
- **Kasaysayan ng Transaksyon**: Display ng assignment at revocation transaction

### Pagpapaandar ng Wallet

**Node Lamang** (walang mining):
```bash
./build/bin/bitcoin-qt
```

**May Mining** (pinapagana ang assignment dialog):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Alternatibong Command Line**:
```bash
./build/bin/bitcoind -miningserver
```

### Mga Kinakailangan sa Mining

**Para sa mga Operasyon ng Mining**:
- Kinakailangan ang `-miningserver` flag
- Wallet na may mga P2WPKH address at private key
- External plotter (`pocx_plotter`) para sa plot generation
- External miner (`pocx_miner`) para sa mining

**Para sa Pool Mining**:
- Gumawa ng forging assignment sa pool address
- Hindi kinakailangan ang wallet sa pool server (ang pool ang namamahala ng mga key)

---

## Mga Yunit ng Pera

### Display ng Yunit

Gumagamit ang Bitcoin-PoCX ng **BTCX** na yunit ng pera (hindi BTC):

| Yunit | Satoshi | Display |
|------|----------|---------|
| **BTCX** | 100000000 | 1.00000000 BTCX |
| **mBTCX** | 100000 | 1000.00 mBTCX |
| **µBTCX** | 100 | 1000000.00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**Mga Setting ng GUI**: Preferences → Display → Unit

---

## Dialog ng Forging Assignment

### Pag-access sa Dialog

**Menu**: `Wallet → Forging Assignments`
**Toolbar**: Mining icon (makikita lamang kapag may `-miningserver` flag)
**Laki ng Window**: 600×450 pixel

### Mga Mode ng Dialog

#### Mode 1: Gumawa ng Assignment

**Layunin**: Magdelega ng mga karapatan sa forging sa pool o ibang address habang pinapanatili ang pagmamay-ari ng plot.

**Mga Kaso ng Paggamit**:
- Pool mining (mag-assign sa pool address)
- Cold storage (ang mining key ay hiwalay sa pagmamay-ari ng plot)
- Shared infrastructure (magdelega sa hot wallet)

**Mga Kinakailangan**:
- Plot address (P2WPKH bech32, dapat nagmamay-ari ng private key)
- Forging address (P2WPKH bech32, iba sa plot address)
- Naka-unlock ang wallet (kung naka-encrypt)
- Ang plot address ay may mga nakumpirmang UTXO

**Mga Hakbang**:
1. Piliin ang "Create Assignment" mode
2. Pumili ng plot address mula sa dropdown o manual na ilagay
3. Ilagay ang forging address (pool o delegado)
4. I-click ang "Send Assignment" (na-enable ang button kapag valid ang mga input)
5. Agad na ibino-broadcast ang transaksyon
6. Nagiging aktibo ang assignment pagkatapos ng `nForgingAssignmentDelay` block:
   - Mainnet/Testnet: 30 block (~1 oras)
   - Regtest: 4 block (~4 segundo)

**Transaction Fee**: Default na 10× `minRelayFee` (nako-customize)

**Istruktura ng Transaksyon**:
- Input: UTXO mula sa plot address (nagpapatunay ng pagmamay-ari)
- OP_RETURN output: `POCX` marker + plot_address + forging_address (46 byte)
- Change output: Ibinabalik sa wallet

#### Mode 2: Mag-revoke ng Assignment

**Layunin**: Kanselahin ang forging assignment at ibalik ang mga karapatan sa may-ari ng plot.

**Mga Kinakailangan**:
- Plot address (dapat nagmamay-ari ng private key)
- Naka-unlock ang wallet (kung naka-encrypt)
- Ang plot address ay may mga nakumpirmang UTXO

**Mga Hakbang**:
1. Piliin ang "Revoke Assignment" mode
2. Pumili ng plot address
3. I-click ang "Send Revocation"
4. Agad na ibino-broadcast ang transaksyon
5. Nagiging epektibo ang revocation pagkatapos ng `nForgingRevocationDelay` block:
   - Mainnet/Testnet: 720 block (~24 oras)
   - Regtest: 8 block (~8 segundo)

**Epekto**:
- Ang forging address ay maaari pa ring mag-forge sa panahon ng delay period
- Ang may-ari ng plot ay nakukuha ulit ang mga karapatan pagkatapos makumpleto ang revocation
- Maaaring gumawa ng bagong assignment pagkatapos

**Istruktura ng Transaksyon**:
- Input: UTXO mula sa plot address (nagpapatunay ng pagmamay-ari)
- OP_RETURN output: `XCOP` marker + plot_address (26 byte)
- Change output: Ibinabalik sa wallet

#### Mode 3: Suriin ang Assignment Status

**Layunin**: I-query ang kasalukuyang assignment state para sa anumang plot address.

**Mga Kinakailangan**: Wala (read-only, hindi kailangan ang wallet)

**Mga Hakbang**:
1. Piliin ang "Check Assignment Status" mode
2. Ilagay ang plot address
3. I-click ang "Check Status"
4. Ang status box ay nagpapakita ng kasalukuyang state na may mga detalye

**Mga State Indicator** (may-kulay na coding):

**Gray - UNASSIGNED**
```
UNASSIGNED - Walang assignment
```

**Orange - ASSIGNING**
```
ASSIGNING - Nakabinbin ang activation ng assignment
Forging Address: pocx1qforger...
Ginawa sa height: 12000
Magka-activate sa height: 12030 (5 block ang natitira)
```

**Green - ASSIGNED**
```
ASSIGNED - Aktibong assignment
Forging Address: pocx1qforger...
Ginawa sa height: 12000
Na-activate sa height: 12030
```

**Red-Orange - REVOKING**
```
REVOKING - Nakabinbin ang revocation
Forging Address: pocx1qforger... (aktibo pa rin)
Ginawa ang assignment sa height: 12000
Na-revoke sa height: 12300
Magiging epektibo ang revocation sa height: 13020 (50 block ang natitira)
```

**Red - REVOKED**
```
REVOKED - Na-revoke ang assignment
Dating naka-assign sa: pocx1qforger...
Ginawa ang assignment sa height: 12000
Na-revoke sa height: 12300
Naging epektibo ang revocation sa height: 13020
```

---

## Kasaysayan ng Transaksyon

### Display ng Assignment Transaction

**Uri**: "Assignment"
**Icon**: Mining icon (pareho sa mga mined block)

**Address Column**: Plot address (address na ang mga karapatan sa forging ay ina-assign)
**Amount Column**: Transaction fee (negatibo, papalabas na transaksyon)
**Status Column**: Bilang ng confirmation (0-6+)

**Mga Detalye** (kapag nag-click):
- Transaction ID
- Plot address
- Forging address (na-parse mula sa OP_RETURN)
- Ginawa sa height
- Activation height
- Transaction fee
- Timestamp

### Display ng Revocation Transaction

**Uri**: "Revocation"
**Icon**: Mining icon

**Address Column**: Plot address
**Amount Column**: Transaction fee (negatibo)
**Status Column**: Bilang ng confirmation

**Mga Detalye** (kapag nag-click):
- Transaction ID
- Plot address
- Na-revoke sa height
- Revocation effective height
- Transaction fee
- Timestamp

### Pag-filter ng Transaksyon

**Mga Available na Filter**:
- "All" (default, kasama ang mga assignment/revocation)
- Saklaw ng petsa
- Saklaw ng halaga
- Paghahanap ayon sa address
- Paghahanap ayon sa transaction ID
- Paghahanap ayon sa label (kung naka-label ang address)

**Tandaan**: Ang mga Assignment/Revocation transaction ay kasalukuyang lumalabas sa ilalim ng "All" filter. Hindi pa naipapatupad ang dedikadong type filter.

### Pag-sort ng Transaksyon

**Pagkakasunud-sunod ng Pag-sort** (ayon sa uri):
- Generated (type 0)
- Received (type 1-3)
- Assignment (type 4)
- Revocation (type 5)
- Sent (type 6+)

---

## Mga Kinakailangan sa Address

### P2WPKH (SegWit v0) Lamang

**Kinakailangan ng mga forging operation ang**:
- Mga Bech32 encoded address (nagsisimula sa "pocx1q" mainnet, "tpocx1q" testnet, "rpocx1q" regtest)
- P2WPKH (Pay-to-Witness-Public-Key-Hash) format
- 20-byte key hash

**HINDI Sinusuportahan**:
- P2PKH (legacy, nagsisimula sa "1")
- P2SH (wrapped SegWit, nagsisimula sa "3")
- P2TR (Taproot, nagsisimula sa "bc1p")

**Rasyonal**: Ang mga PoCX block signature ay nangangailangan ng tiyak na witness v0 format para sa proof validation.

### Pag-filter ng Address Dropdown

**Plot Address ComboBox**:
- Awtomatikong napupunan ng mga receiving address ng wallet
- Inalis ang mga hindi P2WPKH address
- Ipinapakita ang format: "Label (address)" kung naka-label, kung hindi ay address lamang
- Unang item: "-- Enter custom address --" para sa manual entry

**Manual Entry**:
- Vine-validate ang format kapag inilagay
- Dapat valid na bech32 P2WPKH
- Naka-disable ang button kung invalid ang format

### Mga Mensahe ng Validation Error

**Mga Dialog Error**:
- "Plot address must be P2WPKH (bech32)"
- "Forging address must be P2WPKH (bech32)"
- "Invalid address format"
- "No coins available at the plot address. Cannot prove ownership."
- "Cannot create transactions with watch-only wallet"
- "Wallet not available"
- "Wallet locked" (mula sa RPC)

---

## Integrasyon sa Mining

### Mga Kinakailangan sa Setup

**Node Configuration**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Mga Kinakailangan ng Wallet**:
- Mga P2WPKH address para sa pagmamay-ari ng plot
- Mga private key para sa mining (o forging address kung gumagamit ng mga assignment)
- Mga nakumpirmang UTXO para sa paggawa ng transaksyon

**Mga External Tool**:
- `pocx_plotter`: Mag-generate ng mga plot file
- `pocx_miner`: I-scan ang mga plot at magsumite ng mga nonce

### Workflow

#### Solo Mining

1. **Mag-generate ng mga Plot File**:
   ```bash
   pocx_plotter --account <plot_address_hash160> --seed <32_bytes> --nonces <count>
   ```

2. **Simulan ang Node** na may mining server:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **I-configure ang Miner**:
   - Ituro sa node RPC endpoint
   - Tukuyin ang mga direktoryo ng plot file
   - I-configure ang account ID (mula sa plot address)

4. **Simulan ang Mining**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /path/to/plots
   ```

5. **Subaybayan**:
   - Tinatawagan ng miner ang `get_mining_info` bawat block
   - Ini-scan ang mga plot para sa pinakamahusay na deadline
   - Tinatawagan ang `submit_nonce` kapag may nakitang solusyon
   - Awtomatikong vine-validate ng node at nag-forge ng block

#### Pool Mining

1. **Mag-generate ng mga Plot File** (pareho sa solo mining)

2. **Gumawa ng Forging Assignment**:
   - Buksan ang Forging Assignment Dialog
   - Piliin ang plot address
   - Ilagay ang forging address ng pool
   - I-click ang "Send Assignment"
   - Maghintay ng activation delay (30 block testnet)

3. **I-configure ang Miner**:
   - Ituro sa **pool** endpoint (hindi lokal na node)
   - Hinahawakan ng pool ang `submit_nonce` sa chain

4. **Operasyon ng Pool**:
   - Ang pool wallet ay may mga private key ng forging address
   - Vine-validate ng pool ang mga submission mula sa mga miner
   - Tinatawagan ng pool ang `submit_nonce` sa blockchain
   - Ibinahagi ng pool ang mga reward ayon sa polisiya ng pool

### Mga Coinbase Reward

**Walang Assignment**:
- Direktang nagbabayad ang coinbase sa plot owner address
- Suriin ang balanse sa plot address

**May Assignment**:
- Nagbabayad ang coinbase sa forging address
- Natatanggap ng pool ang mga reward
- Natatanggap ng miner ang bahagi mula sa pool

**Iskedyul ng Reward**:
- Initial: 10 BTCX bawat block
- Halving: Bawat 1050000 block (~4 na taon)
- Iskedyul: 10 → 5 → 2.5 → 1.25 → ...

---

## Troubleshooting

### Mga Karaniwang Isyu

#### "Wallet does not have private key for plot address"

**Sanhi**: Ang wallet ay hindi nagmamay-ari ng address
**Solusyon**:
- I-import ang private key sa pamamagitan ng `importprivkey` RPC
- O gumamit ng ibang plot address na pag-aari ng wallet

#### "Assignment already exists for this plot"

**Sanhi**: Naka-assign na ang plot sa ibang address
**Solusyon**:
1. I-revoke ang kasalukuyang assignment
2. Maghintay ng revocation delay (720 block testnet)
3. Gumawa ng bagong assignment

#### "Address format not supported"

**Sanhi**: Hindi P2WPKH bech32 ang address
**Solusyon**:
- Gumamit ng mga address na nagsisimula sa "pocx1q" (mainnet) o "tpocx1q" (testnet)
- Mag-generate ng bagong address kung kailangan: `getnewaddress "" "bech32"`

#### "Transaction fee too low"

**Sanhi**: Congestion ng network mempool o masyadong mababa ang fee para sa relay
**Solusyon**:
- Pataasin ang fee rate parameter
- Maghintay na ma-clear ang mempool

#### "Assignment not yet active"

**Sanhi**: Hindi pa lumipas ang activation delay
**Solusyon**:
- Suriin ang status: ilang block ang natitira bago ma-activate
- Maghintay na makumpleto ang delay period

#### "No coins available at the plot address"

**Sanhi**: Walang nakumpirmang UTXO ang plot address
**Solusyon**:
1. Magpadala ng pondo sa plot address
2. Maghintay ng 1 confirmation
3. Subukang muli ang paggawa ng assignment

#### "Cannot create transactions with watch-only wallet"

**Sanhi**: Ang wallet ay nag-import ng address nang walang private key
**Solusyon**: I-import ang buong private key, hindi lamang ang address

#### "Hindi nakikita ang Forging Assignment tab"

**Sanhi**: Sinimulan ang node nang walang `-miningserver` flag
**Solusyon**: I-restart gamit ang `bitcoin-qt -server -miningserver`

### Mga Hakbang sa Debug

1. **Suriin ang Wallet Status**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **I-verify ang Pagmamay-ari ng Address**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Suriin: "iswatchonly": false, "ismine": true
   ```

3. **Suriin ang Assignment Status**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Tingnan ang mga Kamakailang Transaksyon**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Suriin ang Node Sync**:
   ```bash
   bitcoin-cli getblockchaininfo
   # I-verify: blocks == headers (ganap na na-sync)
   ```

---

## Mga Pinakamahusay na Kasanayan sa Seguridad

### Seguridad ng Plot Address

**Pamamahala ng Key**:
- I-store nang secure ang mga private key ng plot address
- Ang mga assignment transaction ay nagpapatunay ng pagmamay-ari sa pamamagitan ng signature
- Tanging ang may-ari ng plot lamang ang maaaring gumawa/mag-revoke ng mga assignment

**Backup**:
- Regular na i-backup ang wallet (`dumpwallet` o `backupwallet`)
- I-store ang wallet.dat sa secure na lokasyon
- I-record ang mga recovery phrase kung gumagamit ng HD wallet

### Pag-delegate ng Forging Address

**Modelo ng Seguridad**:
- Natatanggap ng forging address ang mga block reward
- Maaaring lagdaan ng forging address ang mga block (mining)
- Ang forging address ay **hindi maaaring** baguhin o i-revoke ang assignment
- Pinapanatili ng may-ari ng plot ang buong kontrol

**Mga Kaso ng Paggamit**:
- **Hot Wallet Delegation**: Ang plot key ay nasa cold storage, ang forging key ay nasa hot wallet para sa mining
- **Pool Mining**: Magdelega sa pool, panatilihin ang pagmamay-ari ng plot
- **Shared Infrastructure**: Maraming miner, isang forging address

### Sinkronisasyon ng Oras ng Network

**Kahalagahan**:
- Ang consensus ng PoCX ay nangangailangan ng tumpak na oras
- Ang clock drift na >10s ay nag-trigger ng babala
- Ang clock drift na >15s ay pumipigil sa mining

**Solusyon**:
- Panatilihing naka-synchronize ang system clock sa NTP
- Subaybayan: `bitcoin-cli getnetworkinfo` para sa mga babala sa time offset
- Gumamit ng mga maaasahang NTP server

### Mga Assignment Delay

**Activation Delay** (30 block testnet):
- Pumipigil sa mabilis na reassignment sa panahon ng mga chain fork
- Pinapayagan ang network na maabot ang consensus
- Hindi maaaring i-bypass

**Revocation Delay** (720 block testnet):
- Nagbibigay ng katatagan para sa mga mining pool
- Pumipigil sa mga "griefing" attack ng assignment
- Ang forging address ay nananatiling aktibo sa panahon ng delay

### Encryption ng Wallet

**I-enable ang Encryption**:
```bash
bitcoin-cli encryptwallet "your_passphrase"
```

**I-unlock para sa mga Transaksyon**:
```bash
bitcoin-cli walletpassphrase "your_passphrase" 300
```

**Mga Pinakamahusay na Kasanayan**:
- Gumamit ng matibay na passphrase (20+ na karakter)
- Huwag i-store ang passphrase sa plain text
- I-lock ang wallet pagkatapos gumawa ng mga assignment

---

## Mga Sanggunian ng Code

**Forging Assignment Dialog**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Transaction Display**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Transaction Parsing**: `src/qt/transactionrecord.cpp`
**Wallet Integration**: `src/pocx/assignments/transactions.cpp`
**Assignment RPCs**: `src/pocx/rpc/assignments_wallet.cpp`
**GUI Main**: `src/qt/bitcoingui.cpp`

---

## Mga Cross-Reference

Mga kaugnay na kabanata:
- [Kabanata 3: Consensus at Mining](3-consensus-and-mining.md) - Proseso ng mining
- [Kabanata 4: Mga Forging Assignment](4-forging-assignments.md) - Arkitektura ng assignment
- [Kabanata 6: Mga Parameter ng Network](6-network-parameters.md) - Mga halaga ng assignment delay
- [Kabanata 7: Sanggunian ng RPC](7-rpc-reference.md) - Mga detalye ng RPC command

---

[← Nakaraan: Sanggunian ng RPC](7-rpc-reference.md) | [📘 Talaan ng mga Nilalaman](index.md)
