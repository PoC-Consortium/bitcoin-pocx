[← Předchozí: Reference RPC](7-rpc-reference.md) | [Obsah](index.md)

---

# Kapitola 8: Průvodce peněženkou a GUI

Kompletní průvodce Qt peněženkou Bitcoin-PoCX a správou forging přiřazení.

---

## Obsah

1. [Přehled](#přehled)
2. [Měnové jednotky](#měnové-jednotky)
3. [Dialog forging přiřazení](#dialog-forging-přiřazení)
4. [Historie transakcí](#historie-transakcí)
5. [Požadavky na adresy](#požadavky-na-adresy)
6. [Integrace těžby](#integrace-těžby)
7. [Řešení problémů](#řešení-problémů)
8. [Osvědčené bezpečnostní postupy](#osvědčené-bezpečnostní-postupy)

---

## Přehled

### Funkce peněženky Bitcoin-PoCX

Qt peněženka Bitcoin-PoCX (`bitcoin-qt`) poskytuje:
- Standardní funkce peněženky Bitcoin Core (odesílání, příjem, správa transakcí)
- **Správce forging přiřazení**: GUI pro vytváření/revokaci přiřazení plotů
- **Režim těžebního serveru**: Příznak `-miningserver` povoluje funkce související s těžbou
- **Historie transakcí**: Zobrazení transakcí přiřazení a revokace

### Spuštění peněženky

**Pouze uzel** (bez těžby):
```bash
./build/bin/bitcoin-qt
```

**S těžbou** (povoluje dialog přiřazení):
```bash
./build/bin/bitcoin-qt -server -miningserver
```

**Alternativa příkazového řádku**:
```bash
./build/bin/bitcoind -miningserver
```

### Požadavky na těžbu

**Pro těžební operace**:
- Vyžadován příznak `-miningserver`
- Peněženka s P2WPKH adresami a privátními klíči
- Externí plotter (`pocx_plotter`) pro generování plotů
- Externí miner (`pocx_miner`) pro těžbu

**Pro poolovou těžbu**:
- Vytvořte forging přiřazení na adresu poolu
- Peněženka není vyžadována na serveru poolu (pool spravuje klíče)

---

## Měnové jednotky

### Zobrazení jednotek

Bitcoin-PoCX používá měnovou jednotku **BTCX** (ne BTC):

| Jednotka | Satoshi | Zobrazení |
|----------|---------|-----------|
| **BTCX** | 100000000 | 1,00000000 BTCX |
| **mBTCX** | 100000 | 1000,00 mBTCX |
| **µBTCX** | 100 | 1000000,00 µBTCX |
| **satoshi** | 1 | 100000000 sat |

**Nastavení GUI**: Předvolby → Zobrazení → Jednotka

---

## Dialog forging přiřazení

### Přístup k dialogu

**Menu**: `Peněženka → Forging přiřazení`
**Panel nástrojů**: Ikona těžby (viditelná pouze s příznakem `-miningserver`)
**Velikost okna**: 600×450 pixelů

### Režimy dialogu

#### Režim 1: Vytvořit přiřazení

**Účel**: Delegovat práva na forging na pool nebo jinou adresu při zachování vlastnictví plotu.

**Případy použití**:
- Poolová těžba (přiřadit na adresu poolu)
- Studené úložiště (těžební klíč oddělený od vlastnictví plotu)
- Sdílená infrastruktura (delegovat na hot wallet)

**Požadavky**:
- Adresa plotu (P2WPKH bech32, musíte vlastnit privátní klíč)
- Forging adresa (P2WPKH bech32, odlišná od adresy plotu)
- Peněženka odemčena (pokud je zašifrována)
- Adresa plotu má potvrzená UTXO

**Kroky**:
1. Vyberte režim "Vytvořit přiřazení"
2. Vyberte adresu plotu z rozbalovací nabídky nebo zadejte ručně
3. Zadejte forging adresu (pool nebo delegát)
4. Klikněte "Odeslat přiřazení" (tlačítko povoleno, když jsou vstupy platné)
5. Transakce okamžitě vysílána
6. Přiřazení aktivní po `nForgingAssignmentDelay` blocích:
   - Mainnet/Testnet: 30 bloků (~1 hodina)
   - Regtest: 4 bloky (~4 sekundy)

**Transakční poplatek**: Výchozí 10× `minRelayFee` (přizpůsobitelný)

**Struktura transakce**:
- Vstup: UTXO z adresy plotu (prokazuje vlastnictví)
- Výstup OP_RETURN: marker `POCX` + plot_address + forging_address (46 bajtů)
- Výstup pro zbytek: Vrácen do peněženky

#### Režim 2: Revokovat přiřazení

**Účel**: Zrušit forging přiřazení a vrátit práva vlastníkovi plotu.

**Požadavky**:
- Adresa plotu (musíte vlastnit privátní klíč)
- Peněženka odemčena (pokud je zašifrována)
- Adresa plotu má potvrzená UTXO

**Kroky**:
1. Vyberte režim "Revokovat přiřazení"
2. Vyberte adresu plotu
3. Klikněte "Odeslat revokaci"
4. Transakce okamžitě vysílána
5. Revokace účinná po `nForgingRevocationDelay` blocích:
   - Mainnet/Testnet: 720 bloků (~24 hodin)
   - Regtest: 8 bloků (~8 sekund)

**Efekt**:
- Forging adresa může stále provádět forging během období zpoždění
- Vlastník plotu získává zpět práva po dokončení revokace
- Poté může vytvořit nové přiřazení

**Struktura transakce**:
- Vstup: UTXO z adresy plotu (prokazuje vlastnictví)
- Výstup OP_RETURN: marker `XCOP` + plot_address (26 bajtů)
- Výstup pro zbytek: Vrácen do peněženky

#### Režim 3: Zkontrolovat stav přiřazení

**Účel**: Dotaz na aktuální stav přiřazení pro libovolnou adresu plotu.

**Požadavky**: Žádné (pouze pro čtení, peněženka není potřeba)

**Kroky**:
1. Vyberte režim "Zkontrolovat stav přiřazení"
2. Zadejte adresu plotu
3. Klikněte "Zkontrolovat stav"
4. Stavový box zobrazí aktuální stav s detaily

**Indikátory stavu** (barevně kódované):

**Šedá - UNASSIGNED**
```
NEPŘIŘAZENO - Přiřazení neexistuje
```

**Oranžová - ASSIGNING**
```
PŘIŘAZUJE SE - Přiřazení čeká na aktivaci
Forging adresa: pocx1qforger...
Vytvořeno ve výšce: 12000
Aktivuje se ve výšce: 12030 (zbývá 5 bloků)
```

**Zelená - ASSIGNED**
```
PŘIŘAZENO - Aktivní přiřazení
Forging adresa: pocx1qforger...
Vytvořeno ve výšce: 12000
Aktivováno ve výšce: 12030
```

**Červenooranžová - REVOKING**
```
REVOKUJE SE - Revokace čeká
Forging adresa: pocx1qforger... (stále aktivní)
Přiřazení vytvořeno ve výšce: 12000
Revokováno ve výšce: 12300
Revokace účinná ve výšce: 13020 (zbývá 50 bloků)
```

**Červená - REVOKED**
```
REVOKOVÁNO - Přiřazení revokováno
Dříve přiřazeno na: pocx1qforger...
Přiřazení vytvořeno ve výšce: 12000
Revokováno ve výšce: 12300
Revokace účinná ve výšce: 13020
```

---

## Historie transakcí

### Zobrazení transakce přiřazení

**Typ**: "Přiřazení"
**Ikona**: Ikona těžby (stejná jako vytěžené bloky)

**Sloupec adresy**: Adresa plotu (adresa, jejíž práva na forging jsou přiřazována)
**Sloupec částky**: Transakční poplatek (záporný, odchozí transakce)
**Sloupec stavu**: Počet potvrzení (0-6+)

**Detaily** (po kliknutí):
- ID transakce
- Adresa plotu
- Forging adresa (parsována z OP_RETURN)
- Vytvořeno ve výšce
- Výška aktivace
- Transakční poplatek
- Časové razítko

### Zobrazení transakce revokace

**Typ**: "Revokace"
**Ikona**: Ikona těžby

**Sloupec adresy**: Adresa plotu
**Sloupec částky**: Transakční poplatek (záporný)
**Sloupec stavu**: Počet potvrzení

**Detaily** (po kliknutí):
- ID transakce
- Adresa plotu
- Revokováno ve výšce
- Výška účinnosti revokace
- Transakční poplatek
- Časové razítko

### Filtrování transakcí

**Dostupné filtry**:
- "Vše" (výchozí, zahrnuje přiřazení/revokace)
- Rozsah dat
- Rozsah částek
- Hledání podle adresy
- Hledání podle ID transakce
- Hledání podle štítku (pokud je adresa označena)

**Poznámka**: Transakce přiřazení/revokace se aktuálně zobrazují pod filtrem "Vše". Dedikovaný filtr typu zatím není implementován.

### Řazení transakcí

**Pořadí řazení** (podle typu):
- Vygenerováno (typ 0)
- Přijato (typ 1-3)
- Přiřazení (typ 4)
- Revokace (typ 5)
- Odesláno (typ 6+)

---

## Požadavky na adresy

### Pouze P2WPKH (SegWit v0)

**Forging operace vyžadují**:
- Bech32 kódované adresy (začínající na "pocx1q" mainnet, "tpocx1q" testnet, "rpocx1q" regtest)
- Formát P2WPKH (Pay-to-Witness-Public-Key-Hash)
- 20bajtový hash klíče

**NEPODPOROVÁNO**:
- P2PKH (legacy, začínající na "1")
- P2SH (zabalený SegWit, začínající na "3")
- P2TR (Taproot, začínající na "bc1p")

**Zdůvodnění**: Podpisy bloků PoCX vyžadují specifický formát witness v0 pro validaci důkazu.

### Filtrování rozbalovací nabídky adres

**ComboBox adresy plotu**:
- Automaticky naplněn přijímacími adresami peněženky
- Odfiltruje non-P2WPKH adresy
- Zobrazuje formát: "Štítek (adresa)" pokud je označeno, jinak pouze adresa
- První položka: "-- Zadejte vlastní adresu --" pro ruční zadání

**Ruční zadání**:
- Validuje formát při zadání
- Musí být platný bech32 P2WPKH
- Tlačítko zakázáno, pokud je formát neplatný

### Chybové zprávy validace

**Chyby dialogu**:
- "Adresa plotu musí být P2WPKH (bech32)"
- "Forging adresa musí být P2WPKH (bech32)"
- "Neplatný formát adresy"
- "Na adrese plotu nejsou žádné coiny. Nelze prokázat vlastnictví."
- "Nelze vytvářet transakce s watch-only peněženkou"
- "Peněženka není dostupná"
- "Peněženka uzamčena" (z RPC)

---

## Integrace těžby

### Požadavky na nastavení

**Konfigurace uzlu**:
```bash
# bitcoin.conf
miningserver=1
server=1
```

**Požadavky na peněženku**:
- P2WPKH adresy pro vlastnictví plotu
- Privátní klíče pro těžbu (nebo forging adresu, pokud používáte přiřazení)
- Potvrzená UTXO pro vytváření transakcí

**Externí nástroje**:
- `pocx_plotter`: Generování plot souborů
- `pocx_miner`: Skenování plotů a odesílání nonces

### Workflow

#### Sólová těžba

1. **Vygenerovat plot soubory**:
   ```bash
   pocx_plotter --account <hash160_adresy_plotu> --seed <32_bajtů> --nonces <počet>
   ```

2. **Spustit uzel** s těžebním serverem:
   ```bash
   bitcoin-qt -server -miningserver
   ```

3. **Nakonfigurovat miner**:
   - Nasměrovat na RPC endpoint uzlu
   - Specifikovat adresáře plot souborů
   - Nakonfigurovat account ID (z adresy plotu)

4. **Spustit těžbu**:
   ```bash
   pocx_miner --rpc-url http://localhost:8332 --plots /cesta/k/plotum
   ```

5. **Monitorovat**:
   - Miner volá `get_mining_info` každý blok
   - Skenuje ploty pro nejlepší deadline
   - Volá `submit_nonce`, když je nalezeno řešení
   - Uzel automaticky validuje a vytváří blok

#### Poolová těžba

1. **Vygenerovat plot soubory** (stejné jako sólová těžba)

2. **Vytvořit forging přiřazení**:
   - Otevřít dialog forging přiřazení
   - Vybrat adresu plotu
   - Zadat forging adresu poolu
   - Kliknout "Odeslat přiřazení"
   - Čekat na zpoždění aktivace (30 bloků testnet)

3. **Nakonfigurovat miner**:
   - Nasměrovat na endpoint **poolu** (ne lokální uzel)
   - Pool zpracovává `submit_nonce` do řetězce

4. **Provoz poolu**:
   - Peněženka poolu má privátní klíče forging adresy
   - Pool validuje odesílání od těžařů
   - Pool volá `submit_nonce` do blockchainu
   - Pool distribuuje odměny podle politiky poolu

### Odměny coinbase

**Bez přiřazení**:
- Coinbase platí přímo na adresu vlastníka plotu
- Zkontrolujte zůstatek na adrese plotu

**S přiřazením**:
- Coinbase platí na forging adresu
- Pool přijímá odměny
- Těžař přijímá podíl od poolu

**Harmonogram odměn**:
- Počáteční: 10 BTCX za blok
- Halving: Každých 1050000 bloků (~4 roky)
- Harmonogram: 10 → 5 → 2,5 → 1,25 → ...

---

## Řešení problémů

### Běžné problémy

#### "Peněženka nemá privátní klíč pro adresu plotu"

**Příčina**: Peněženka nevlastní adresu
**Řešení**:
- Importujte privátní klíč přes `importprivkey` RPC
- Nebo použijte jinou adresu plotu vlastněnou peněženkou

#### "Pro tento plot již existuje přiřazení"

**Příčina**: Plot je již přiřazen na jinou adresu
**Řešení**:
1. Revokujte existující přiřazení
2. Čekejte na zpoždění revokace (720 bloků testnet)
3. Vytvořte nové přiřazení

#### "Formát adresy není podporován"

**Příčina**: Adresa není P2WPKH bech32
**Řešení**:
- Použijte adresy začínající na "pocx1q" (mainnet) nebo "tpocx1q" (testnet)
- V případě potřeby vygenerujte novou adresu: `getnewaddress "" "bech32"`

#### "Transakční poplatek je příliš nízký"

**Příčina**: Zatížení mempoolu sítě nebo poplatek příliš nízký pro přenos
**Řešení**:
- Zvyšte parametr sazby poplatku
- Čekejte na vyčištění mempoolu

#### "Přiřazení ještě není aktivní"

**Příčina**: Zpoždění aktivace ještě neuplynulo
**Řešení**:
- Zkontrolujte stav: zbývající bloky do aktivace
- Čekejte na dokončení období zpoždění

#### "Na adrese plotu nejsou žádné coiny"

**Příčina**: Adresa plotu nemá potvrzená UTXO
**Řešení**:
1. Odešlete prostředky na adresu plotu
2. Čekejte na 1 potvrzení
3. Zkuste znovu vytvořit přiřazení

#### "Nelze vytvářet transakce s watch-only peněženkou"

**Příčina**: Peněženka importovala adresu bez privátního klíče
**Řešení**: Importujte kompletní privátní klíč, ne pouze adresu

#### "Záložka forging přiřazení není viditelná"

**Příčina**: Uzel spuštěn bez příznaku `-miningserver`
**Řešení**: Restartujte s `bitcoin-qt -server -miningserver`

### Kroky ladění

1. **Zkontrolujte stav peněženky**:
   ```bash
   bitcoin-cli getwalletinfo
   ```

2. **Ověřte vlastnictví adresy**:
   ```bash
   bitcoin-cli getaddressinfo pocx1qplot...
   # Zkontrolujte: "iswatchonly": false, "ismine": true
   ```

3. **Zkontrolujte stav přiřazení**:
   ```bash
   bitcoin-cli get_assignment pocx1qplot...
   ```

4. **Zobrazit nedávné transakce**:
   ```bash
   bitcoin-cli listtransactions "*" 10
   ```

5. **Zkontrolovat synchronizaci uzlu**:
   ```bash
   bitcoin-cli getblockchaininfo
   # Ověřte: blocks == headers (plně synchronizováno)
   ```

---

## Osvědčené bezpečnostní postupy

### Bezpečnost adresy plotu

**Správa klíčů**:
- Ukládejte privátní klíče adresy plotu bezpečně
- Transakce přiřazení prokazují vlastnictví podpisem
- Pouze vlastník plotu může vytvářet/revokovat přiřazení

**Záloha**:
- Pravidelně zálohujte peněženku (`dumpwallet` nebo `backupwallet`)
- Ukládejte wallet.dat na bezpečném místě
- Zaznamenejte obnovovací fráze, pokud používáte HD peněženku

### Delegování forging adresy

**Bezpečnostní model**:
- Forging adresa přijímá odměny za bloky
- Forging adresa může podepisovat bloky (těžba)
- Forging adresa **nemůže** modifikovat nebo revokovat přiřazení
- Vlastník plotu si zachovává plnou kontrolu

**Případy použití**:
- **Delegování hot wallet**: Klíč plotu ve studeném úložišti, forging klíč v hot wallet pro těžbu
- **Poolová těžba**: Delegovat na pool, zachovat vlastnictví plotu
- **Sdílená infrastruktura**: Více těžařů, jedna forging adresa

### Synchronizace síťového času

**Důležitost**:
- Konsenzus PoCX vyžaduje přesný čas
- Drift hodin >10s spouští varování
- Drift hodin >15s zabraňuje těžbě

**Řešení**:
- Udržujte systémové hodiny synchronizované s NTP
- Monitorujte: `bitcoin-cli getnetworkinfo` pro varování o časovém offsetu
- Používejte spolehlivé NTP servery

### Zpoždění přiřazení

**Zpoždění aktivace** (30 bloků testnet):
- Zabraňuje rychlému přeřazení během forků řetězce
- Umožňuje síti dosáhnout konsenzu
- Nelze obejít

**Zpoždění revokace** (720 bloků testnet):
- Poskytuje stabilitu pro těžební pooly
- Zabraňuje útokům "griefingu" přiřazením
- Forging adresa zůstává aktivní během zpoždění

### Šifrování peněženky

**Povolení šifrování**:
```bash
bitcoin-cli encryptwallet "vase_heslo"
```

**Odemčení pro transakce**:
```bash
bitcoin-cli walletpassphrase "vase_heslo" 300
```

**Osvědčené postupy**:
- Používejte silné heslo (20+ znaků)
- Neukládejte heslo v prostém textu
- Zamkněte peněženku po vytvoření přiřazení

---

## Reference kódu

**Dialog forging přiřazení**: `src/qt/forgingassignmentdialog.cpp`, `src/qt/forgingassignmentdialog.h`
**Zobrazení transakcí**: `src/qt/transactionrecord.cpp`, `src/qt/transactiontablemodel.cpp`
**Parsování transakcí**: `src/qt/transactionrecord.cpp`
**Integrace peněženky**: `src/pocx/assignments/transactions.cpp`
**RPC přiřazení**: `src/pocx/rpc/assignments_wallet.cpp`
**Hlavní GUI**: `src/qt/bitcoingui.cpp`

---

## Křížové odkazy

Související kapitoly:
- [Kapitola 3: Konsenzus a těžba](3-consensus-and-mining.md) - Proces těžby
- [Kapitola 4: Forging přiřazení](4-forging-assignments.md) - Architektura přiřazení
- [Kapitola 6: Síťové parametry](6-network-parameters.md) - Hodnoty zpoždění přiřazení
- [Kapitola 7: Reference RPC](7-rpc-reference.md) - Detaily RPC příkazů

---

[← Předchozí: Reference RPC](7-rpc-reference.md) | [Obsah](index.md)
