[← Anterior: Sincronizare temporală](5-timing-security.md) | [📘 Cuprins](index.md) | [Următorul: Referință RPC →](7-rpc-reference.md)

---

# Capitolul 6: Parametri de rețea și configurare

Referință completă pentru configurarea rețelei Bitcoin-PoCX în toate tipurile de rețea.

---

## Cuprins

1. [Parametrii blocului genesis](#parametrii-blocului-genesis)
2. [Configurarea chainparams](#configurarea-chainparams)
3. [Parametri de consens](#parametri-de-consens)
4. [Coinbase și recompense de bloc](#coinbase-și-recompense-de-bloc)
5. [Scalare dinamică](#scalare-dinamică)
6. [Configurarea rețelei](#configurarea-rețelei)
7. [Structura directorului de date](#structura-directorului-de-date)

---

## Parametrii blocului genesis

### Calculul țintei de bază

**Formulă**: `genesis_base_target = 2^42 / block_time_seconds`

**Rațiune**:
- Fiecare nonce reprezintă 256 KiB (64 octeți × 4096 scoop-uri)
- 1 TiB = 2^22 nonce-uri (presupunerea capacității inițiale a rețelei)
- Calitatea minimă așteptată pentru n nonce-uri ≈ 2^64 / n
- Pentru 1 TiB: E(quality) = 2^64 / 2^22 = 2^42
- Prin urmare: base_target = 2^42 / block_time

**Valori calculate**:
- Mainnet/Testnet/Signet (120s): `36650387592`
- Regtest (1s): Folosește modul de calibrare pentru capacitate redusă

### Mesajul genesis

Toate rețelele folosesc același mesaj genesis ca Bitcoin:
```
"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"
```

**Implementare**: `src/kernel/chainparams.cpp`

---

## Configurarea chainparams

### Parametri mainnet

**Identitate rețea**:
- **Octeți magici**: `0xa7 0x3c 0x91 0x5e`
- **Port implicit**: `8888`
- **HRP Bech32**: `pocx`

**Prefixe de adrese** (Base58):
- PUBKEY_ADDRESS: `85` (adresele încep cu 'P')
- SCRIPT_ADDRESS: `90` (adresele încep cu 'R')
- SECRET_KEY: `128`

**Sincronizarea blocurilor**:
- **Ținta timp bloc**: `120` secunde (2 minute)
- **Interval țintă**: `1209600` secunde (14 zile)
- **MAX_FUTURE_BLOCK_TIME**: `15` secunde

**Recompense de bloc**:
- **Subvenție inițială**: `10 BTC`
- **Interval înjumătățire**: `1050000` blocuri (~4 ani)
- **Număr de înjumătățiri**: Maximum 64 înjumătățiri

**Ajustarea dificultății**:
- **Fereastră rulantă**: `24` blocuri
- **Ajustare**: La fiecare bloc
- **Algoritm**: Medie mobilă exponențială

**Întârzieri atribuiri**:
- **Activare**: `30` blocuri (~1 oră)
- **Revocare**: `720` blocuri (~24 ore)

### Parametri testnet

**Identitate rețea**:
- **Octeți magici**: `0x6d 0xf2 0x48 0xb3`
- **Port implicit**: `18888`
- **HRP Bech32**: `tpocx`

**Prefixe de adrese** (Base58):
- PUBKEY_ADDRESS: `127`
- SCRIPT_ADDRESS: `132`
- SECRET_KEY: `255`

**Sincronizarea blocurilor**:
- **Ținta timp bloc**: `120` secunde
- **MAX_FUTURE_BLOCK_TIME**: `15` secunde
- **Permite dificultate minimă**: `true`

**Recompense de bloc**:
- **Subvenție inițială**: `10 BTC`
- **Interval înjumătățire**: `1050000` blocuri

**Ajustarea dificultății**:
- **Fereastră rulantă**: `24` blocuri

**Întârzieri atribuiri**:
- **Activare**: `30` blocuri (~1 oră)
- **Revocare**: `720` blocuri (~24 ore)

### Parametri regtest

**Identitate rețea**:
- **Octeți magici**: `0xfa 0xbf 0xb5 0xda`
- **Port implicit**: `18444`
- **HRP Bech32**: `rpocx`

**Prefixe de adrese** (compatibil Bitcoin):
- PUBKEY_ADDRESS: `111`
- SCRIPT_ADDRESS: `196`
- SECRET_KEY: `239`

**Sincronizarea blocurilor**:
- **Ținta timp bloc**: `1` secundă (minerit instantaneu pentru testare)
- **Interval țintă**: `86400` secunde (1 zi)
- **MAX_FUTURE_BLOCK_TIME**: `15` secunde

**Recompense de bloc**:
- **Subvenție inițială**: `10 BTC`
- **Interval înjumătățire**: `500` blocuri

**Ajustarea dificultății**:
- **Fereastră rulantă**: `24` blocuri
- **Permite dificultate minimă**: `true`
- **Fără re-țintire**: `true`
- **Calibrare capacitate redusă**: `true` (folosește calibrare de 16 nonce-uri în loc de 1 TiB)

**Întârzieri atribuiri**:
- **Activare**: `4` blocuri (~4 secunde)
- **Revocare**: `8` blocuri (~8 secunde)

### Parametri signet

**Identitate rețea**:
- **Octeți magici**: Primii 4 octeți din SHA256d(signet_challenge)
- **Port implicit**: `38333`
- **HRP Bech32**: `tpocx`

**Sincronizarea blocurilor**:
- **Ținta timp bloc**: `120` secunde
- **MAX_FUTURE_BLOCK_TIME**: `15` secunde

**Recompense de bloc**:
- **Subvenție inițială**: `10 BTC`
- **Interval înjumătățire**: `1050000` blocuri

**Ajustarea dificultății**:
- **Fereastră rulantă**: `24` blocuri

---

## Parametri de consens

### Parametri de sincronizare

**MAX_FUTURE_BLOCK_TIME**: `15` secunde
- Specific PoCX (Bitcoin folosește 2 ore)
- Rațiune: Sincronizarea PoC necesită validare aproape în timp real
- Blocurile cu mai mult de 15s în viitor sunt respinse

**Avertizare offset timp**: `10` secunde
- Operatorii sunt avertizați când ceasul nodului deviază >10s de la timpul rețelei
- Fără aplicare, doar informațional

**Ținte timp bloc**:
- Mainnet/Testnet/Signet: `120` secunde
- Regtest: `1` secundă

**TIMESTAMP_WINDOW**: `15` secunde (egal cu MAX_FUTURE_BLOCK_TIME)

**Implementare**: `src/chain.h`, `src/validation.cpp`

### Parametri de ajustare a dificultății

**Dimensiunea ferestrei rulante**: `24` blocuri (toate rețelele)
- Medie mobilă exponențială a timpilor recenți ai blocurilor
- Ajustare la fiecare bloc
- Reactiv la schimbările de capacitate

**Implementare**: `src/consensus/params.h`, logica dificultății în crearea blocului

### Parametri ai sistemului de atribuiri

**nForgingAssignmentDelay** (întârziere de activare):
- Mainnet: `30` blocuri (~1 oră)
- Testnet: `30` blocuri (~1 oră)
- Regtest: `4` blocuri (~4 secunde)

**nForgingRevocationDelay** (întârziere de revocare):
- Mainnet: `720` blocuri (~24 ore)
- Testnet: `720` blocuri (~24 ore)
- Regtest: `8` blocuri (~8 secunde)

**Rațiune**:
- Întârzierea de activare previne reatribuirea rapidă în timpul curselor de blocuri
- Întârzierea de revocare oferă stabilitate și previne abuzurile

**Implementare**: `src/consensus/params.h`

---

## Coinbase și recompense de bloc

### Calendarul subvenției de bloc

**Subvenție inițială**: `10 BTC` (toate rețelele)

**Calendarul înjumătățirilor**:
- La fiecare `1050000` blocuri (mainnet/testnet)
- La fiecare `500` blocuri (regtest)
- Continuă pentru maximum 64 înjumătățiri

**Progresia înjumătățirilor**:
```
Înjumătățire 0: 10.00000000 BTC  (blocuri 0 - 1049999)
Înjumătățire 1:  5.00000000 BTC  (blocuri 1050000 - 2099999)
Înjumătățire 2:  2.50000000 BTC  (blocuri 2100000 - 3149999)
Înjumătățire 3:  1.25000000 BTC  (blocuri 3150000 - 4199999)
...
```

**Oferta totală**: ~21 milioane BTC (la fel ca Bitcoin)

### Regulile ieșirii coinbase

**Destinația plății**:
- **Fără atribuire**: Coinbase plătește adresa plot-ului (proof.account_id)
- **Cu atribuire**: Coinbase plătește adresa de forjare (semnatarul efectiv)

**Format ieșire**: Doar P2WPKH
- Coinbase trebuie să plătească la adresă bech32 SegWit v0
- Generată din cheia publică a semnatarului efectiv

**Rezoluția atribuirii**:
```cpp
effective_signer = GetEffectiveSigner(plot_address, height, view);
coinbase_script = P2WPKH(effective_signer);
```

**Implementare**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`

---

## Scalare dinamică

### Limite de scalare

**Scop**: Crește dificultatea generării plot-urilor pe măsură ce rețeaua maturizează pentru a preveni inflația capacității

**Structură**:
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Nivel minim acceptat
    uint8_t nPoCXTargetCompression;  // Nivel recomandat
};
```

**Relație**: `target = min + 1` (întotdeauna un nivel deasupra minimului)

### Calendarul creșterii scalării

Nivelurile de scalare cresc după un **calendar exponențial** bazat pe intervalele de înjumătățire:

| Perioadă de timp | Înălțime bloc | Înjumătățiri | Min | Țintă |
|------------------|---------------|--------------|-----|-------|
| Anii 0-4 | 0 la 1049999 | 0 | X1 | X2 |
| Anii 4-12 | 1050000 la 3149999 | 1-2 | X2 | X3 |
| Anii 12-28 | 3150000 la 7349999 | 3-6 | X3 | X4 |
| Anii 28-60 | 7350000 la 15749999 | 7-14 | X4 | X5 |
| Anii 60-124 | 15750000 la 32549999 | 15-30 | X5 | X6 |
| Anii 124+ | 32550000+ | 31+ | X6 | X7 |

**Înălțimi cheie** (ani → înjumătățiri → blocuri):
- Anul 4: Înjumătățirea 1 la blocul 1050000
- Anul 12: Înjumătățirea 3 la blocul 3150000
- Anul 28: Înjumătățirea 7 la blocul 7350000
- Anul 60: Înjumătățirea 15 la blocul 15750000
- Anul 124: Înjumătățirea 31 la blocul 32550000

### Dificultatea nivelului de scalare

**Scalarea PoW**:
- Nivelul de scalare X0: Linie de bază POC2 (teoretic)
- Nivelul de scalare X1: Linie de bază XOR-transpose
- Nivelul de scalare Xn: 2^(n-1) × munca X1 încorporată
- Fiecare nivel dublează munca de generare a plot-ului

**Aliniere economică**:
- Recompensele de bloc se înjumătățesc → dificultatea generării plot-ului crește
- Menține marja de siguranță: costul creării plot-ului > costul căutării
- Previne inflația capacității din îmbunătățirile hardware

### Validarea plot-urilor

**Reguli de validare**:
- Dovezile trimise trebuie să aibă nivel de scalare ≥ minim
- Dovezile cu scalare > țintă sunt acceptate dar ineficiente
- Dovezile sub minim: respinse (PoW insuficient)

**Obținerea limitelor**:
```cpp
auto bounds = GetPoCXCompressionBounds(height, halving_interval);
```

**Implementare**: `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`, `src/pocx/consensus/params.cpp`

---

## Configurarea rețelei

### Noduri sursă și semințe DNS

**Stare**: Placeholder pentru lansarea mainnet

**Configurare planificată**:
- Noduri sursă: TBD
- Semințe DNS: TBD

**Stare curentă** (testnet/regtest):
- Fără infrastructură dedicată de semințe
- Conexiuni manuale către peer-i suportate prin `-addnode`

**Implementare**: `src/kernel/chainparams.cpp`

### Puncte de control

**Punct de control genesis**: Întotdeauna blocul 0

**Puncte de control suplimentare**: Niciunul configurat în prezent

**Viitor**: Punctele de control vor fi adăugate pe măsură ce mainnet-ul progresează

---

## Configurarea protocolului P2P

### Versiunea protocolului

**Bază**: Protocolul Bitcoin Core v30.0
- **Versiune protocol**: Moștenită de la Bitcoin Core
- **Biți de serviciu**: Servicii standard Bitcoin
- **Tipuri de mesaje**: Mesaje P2P standard Bitcoin

**Extensii PoCX**:
- Header-ele blocurilor includ câmpuri specifice PoCX
- Mesajele de bloc includ date de dovadă PoCX
- Regulile de validare aplică consensul PoCX

**Compatibilitate**: Nodurile PoCX sunt incompatibile cu nodurile Bitcoin PoW (consens diferit)

**Implementare**: `src/protocol.h`, `src/net_processing.cpp`

---

## Structura directorului de date

### Directorul implicit

**Locație**: `.bitcoin/` (la fel ca Bitcoin Core)
- Linux: `~/.bitcoin/`
- macOS: `~/Library/Application Support/Bitcoin/`
- Windows: `%APPDATA%\Bitcoin\`

### Conținutul directorului

```
.bitcoin/
├── blocks/              # Datele blocurilor
│   ├── blk*.dat        # Fișiere de blocuri
│   ├── rev*.dat        # Date de anulare
│   └── index/          # Indexul blocurilor (LevelDB)
├── chainstate/         # Setul UTXO + atribuiri de forjare (LevelDB)
├── wallets/            # Fișierele portofelului
│   └── wallet.dat      # Portofelul implicit
├── bitcoin.conf        # Fișier de configurare
├── debug.log           # Log de depanare
├── peers.dat           # Adrese peer-i
├── mempool.dat         # Persistența mempool-ului
└── banlist.dat         # Peer-i interziși
```

### Diferențe cheie față de Bitcoin

**Baza de date chainstate**:
- Standard: Setul UTXO
- **Adăugare PoCX**: Starea atribuirilor de forjare
- Actualizări atomice: UTXO + atribuiri actualizate împreună
- Date de anulare sigure la reorganizări pentru atribuiri

**Fișierele de blocuri**:
- Format standard de bloc Bitcoin
- **Adăugare PoCX**: Extins cu câmpuri de dovadă PoCX (account_id, seed, nonce, semnătură, pubkey)

### Exemplu de fișier de configurare

**bitcoin.conf**:
```ini
# Selecția rețelei
#testnet=1
#regtest=1

# Server de minerit PoCX (necesar pentru minerii externi)
miningserver=1

# Setări RPC
server=1
rpcuser=numeutilizator
rpcpassword=paroladumneavoastra
rpcallowip=127.0.0.1
rpcport=8332

# Setări de conexiune
listen=1
port=8888
maxconnections=125

# Ținta timp bloc (informațional, aplicată de consens)
# 120 secunde pentru mainnet/testnet
```

---

## Referințe cod

**Chainparams**: `src/kernel/chainparams.cpp`
**Parametri consens**: `src/consensus/params.h`
**Limite compresie**: `src/pocx/algorithms/algorithms.h`, `src/pocx/consensus/params.cpp`
**Calculul țintei de bază genesis**: `src/pocx/consensus/params.cpp`
**Logica plății coinbase**: `src/pocx/mining/scheduler.cpp:ForgeBlock()`
**Stocarea stării atribuirilor**: `src/coins.h`, `src/coins.cpp` (extensii CCoinsViewCache)

---

## Referințe încrucișate

Capitole conexe:
- [Capitolul 2: Formatul plot](2-plot-format.md) - Niveluri de scalare în generarea plot-urilor
- [Capitolul 3: Consens și minerit](3-consensus-and-mining.md) - Validarea scalării, sistemul de atribuiri
- [Capitolul 4: Atribuiri de forjare](4-forging-assignments.md) - Parametrii întârzierii atribuirilor
- [Capitolul 5: Securitatea sincronizării](5-timing-security.md) - Rațiunea MAX_FUTURE_BLOCK_TIME

---

[← Anterior: Sincronizare temporală](5-timing-security.md) | [📘 Cuprins](index.md) | [Următorul: Referință RPC →](7-rpc-reference.md)
