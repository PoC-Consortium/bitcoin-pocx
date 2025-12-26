[← Edellinen: Konsensus ja louhinta](3-consensus-and-mining.md) | [Sisällysluettelo](index.md) | [Seuraava: Aikasynkronointi →](5-timing-security.md)

---

# Luku 4: PoCX Forging-delegointijärjestelmä

## Tiivistelmä

Tämä dokumentti kuvaa **toteutetun** PoCX forging-delegointijärjestelmän, joka käyttää vain OP_RETURN-pohjaista arkkitehtuuria. Järjestelmä mahdollistaa plotin omistajien delegoida forging-oikeudet erillisille osoitteille ketjuun tallennettavien transaktioiden kautta, täydellä uudelleenjärjestelyn turvallisuudella ja atomisilla tietokantaoperaatioilla.

**Tila:** Täysin toteutettu ja toiminnassa

## Keskeinen suunnittelufilosofia

**Avainperiaate:** Delegoinnit ovat oikeuksia, eivät omaisuutta

- Ei erityisiä UTXO:ita seurattavaksi tai kulutettavaksi
- Delegointitila tallennetaan erillään UTXO-joukosta
- Omistajuus todistetaan transaktion allekirjoituksella, ei UTXO:n kuluttamisella
- Täysi historiatiedot täydellistä auditointia varten
- Atomiset tietokantapäivitykset LevelDB-eräkirjoituksilla

## Transaktiorakenne

### Delegointitransaktion muoto

```
Syötteet:
  [0]: Mikä tahansa plotin omistajan hallitsema UTXO (todistaa omistajuuden + maksaa kulut)
       On oltava allekirjoitettu plotin omistajan yksityisellä avaimella
  [1+]: Valinnaiset lisäsyötteet kulujen kattamiseen

Tulosteet:
  [0]: OP_RETURN (POCX-merkki + plotin osoite + forging-osoite)
       Muoto: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Koko: 46 tavua yhteensä (1 tavu OP_RETURN + 1 tavu pituus + 44 tavua dataa)
       Arvo: 0 BTC (kuluttamaton, ei lisätä UTXO-joukkoon)

  [1]: Vaihtoraha takaisin käyttäjälle (valinnainen, tavallinen P2WPKH)
```

**Toteutus:** `src/pocx/assignments/opcodes.cpp:25-52`

### Peruutustransaktion muoto

```
Syötteet:
  [0]: Mikä tahansa plotin omistajan hallitsema UTXO (todistaa omistajuuden + maksaa kulut)
       On oltava allekirjoitettu plotin omistajan yksityisellä avaimella
  [1+]: Valinnaiset lisäsyötteet kulujen kattamiseen

Tulosteet:
  [0]: OP_RETURN (XCOP-merkki + plotin osoite)
       Muoto: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Koko: 26 tavua yhteensä (1 tavu OP_RETURN + 1 tavu pituus + 24 tavua dataa)
       Arvo: 0 BTC (kuluttamaton, ei lisätä UTXO-joukkoon)

  [1]: Vaihtoraha takaisin käyttäjälle (valinnainen, tavallinen P2WPKH)
```

**Toteutus:** `src/pocx/assignments/opcodes.cpp:54-77`

### Merkit

- **Delegointimerkki:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Peruutusmerkki:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Toteutus:** `src/pocx/assignments/opcodes.cpp:15-19`

### Transaktion keskeiset ominaisuudet

- Vakio Bitcoin-transaktioita (ei protokollamuutoksia)
- OP_RETURN-tulosteet ovat todistetusti kuluttamattomia (ei koskaan lisätä UTXO-joukkoon)
- Plotin omistajuus todistetaan allekirjoituksella syötteessä[0] plotin osoitteesta
- Edullinen (~200 tavua, tyypillisesti <0.0001 BTC maksu)
- Lompakko valitsee automaattisesti suurimman UTXO:n plotin osoitteesta omistajuuden todistamiseen

## Tietokanta-arkkitehtuuri

### Tallennusrakenne

Kaikki delegointidata tallennetaan samaan LevelDB-tietokantaan kuin UTXO-joukko (`chainstate/`), mutta erillisillä avain-etuliitteillä:

```
chainstate/ LevelDB:
├─ UTXO-joukko (Bitcoin Core standardi)
│  └─ 'C'-etuliite: COutPoint → Coin
│
└─ Delegointitila (PoCX-lisäykset)
   └─ 'A'-etuliite: (plot_address, assignment_txid) → ForgingAssignment
       └─ Täysi historia: kaikki delegoinnit per plotti ajan myötä
```

**Toteutus:** `src/txdb.cpp:237-348`

### ForgingAssignment-rakenne

```cpp
struct ForgingAssignment {
    // Identiteetti
    std::array<uint8_t, 20> plotAddress;      // Plotin omistaja (20-tavuinen P2WPKH-tiiviste)
    std::array<uint8_t, 20> forgingAddress;   // Forging-oikeuksien haltija (20-tavuinen P2WPKH-tiiviste)

    // Delegoinnin elinkaari
    uint256 assignment_txid;                   // Transaktio joka loi delegoinnin
    int assignment_height;                     // Lohkon korkeus luotaessa
    int assignment_effective_height;           // Milloin tulee aktiiviseksi (korkeus + viive)

    // Peruutuksen elinkaari
    bool revoked;                              // Onko tämä peruutettu?
    uint256 revocation_txid;                   // Transaktio joka peruutti
    int revocation_height;                     // Lohkon korkeus peruutettaessa
    int revocation_effective_height;           // Milloin peruutus voimassa (korkeus + viive)

    // Tilakyselyn metodit
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Toteutus:** `src/coins.h:111-178`

### Delegointitilat

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Ei delegointia
    ASSIGNING = 1,   // Delegointi luotu, odottaa aktivointiviivettä
    ASSIGNED = 2,    // Delegointi aktiivinen, forging sallittu
    REVOKING = 3,    // Peruutettu, mutta yhä aktiivinen viivejakson ajan
    REVOKED = 4      // Täysin peruutettu, ei enää aktiivinen
};
```

**Toteutus:** `src/coins.h:98-104`

### Tietokanta-avaimet

```cpp
// Historia-avain: tallentaa täyden delegointitietueen
// Avainmuoto: (etuliite, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Plotin osoite (20 tavua)
    int assignment_height;                // Korkeus lajittelun optimointia varten
    uint256 assignment_txid;              // Transaktiotunniste
};
```

**Toteutus:** `src/txdb.cpp:245-262`

### Historian seuranta

- Jokainen delegointi tallennetaan pysyvästi (ei koskaan poisteta ellei reorg)
- Useita delegointeja per plotti seurataan ajan myötä
- Mahdollistaa täydellisen auditointijäljen ja historiallisten tilakyselyiden
- Peruutetut delegoinnit pysyvät tietokannassa `revoked=true`-tilassa

## Lohkon käsittely

### ConnectBlock-integraatio

Delegointi- ja peruutus-OP_RETURNit käsitellään lohkon liittämisen aikana `validation.cpp`-tiedostossa:

```cpp
// Sijainti: Skriptivalidoinnin jälkeen, ennen UpdateCoinsia
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Jäsennä OP_RETURN-data
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Varmenna omistajuus (tx:n on oltava plotin omistajan allekirjoittama)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Tarkista plotin tila (on oltava UNASSIGNED tai REVOKED)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Luo uusi delegointi
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Tallenna kumoamisdata
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Jäsennä OP_RETURN-data
            auto plot_addr = ParseRevocationOpReturn(output);

            // Varmenna omistajuus
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Hae nykyinen delegointi
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Tallenna vanha tila kumoamista varten
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Merkitse peruutetuksi
            ForgingAssignment revoked = *existing;
            revoked.revoked = true;
            revoked.revocation_txid = tx.GetHash();
            revoked.revocation_height = height;
            revoked.revocation_effective_height = height + consensus.nForgingRevocationDelay;

            view.UpdateForgingAssignment(revoked);
        }
    }
}
#endif

// UpdateCoins jatkuu normaalisti (ohittaa automaattisesti OP_RETURN-tulosteet)
```

**Toteutus:** `src/validation.cpp:2775-2878`

### Omistajuuden varmennus

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Tarkista että vähintään yksi syöte on plotin omistajan allekirjoittama
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // Poimi kohde
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // Tarkista onko P2WPKH plotin osoitteeseen
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Bitcoin Core on jo validoinut allekirjoituksen
                return true;
            }
        }
    }
    return false;
}
```

**Toteutus:** `src/pocx/assignments/opcodes.cpp:217-256`

### Aktivointiviiveet

Delegoinneilla ja peruutuksilla on konfiguroitavat aktivointiviiveet reorg-hyökkäysten estämiseksi:

```cpp
// Konsensusparametrit (konfiguroitavissa verkkokohtaisesti)
// Esimerkki: 30 lohkoa = ~1 tunti 2 minuutin lohkoajalla
consensus.nForgingAssignmentDelay;   // Delegoinnin aktivointiviive
consensus.nForgingRevocationDelay;   // Peruutuksen aktivointiviive
```

**Tilasiirtymät:**
- Delegointi: `UNASSIGNED → ASSIGNING (viive) → ASSIGNED`
- Peruutus: `ASSIGNED → REVOKING (viive) → REVOKED`

**Toteutus:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Mempoolin validointi

Delegointi- ja peruutustransaktiot validoidaan mempoolin hyväksynnässä kelvollisuuden hylkäämiseksi ennen verkkopropagaatiota.

### Transaktiotason tarkistukset (CheckTransaction)

Suoritetaan `src/consensus/tx_check.cpp`-tiedostossa ilman ketjun tilan käyttöä:

1. **Maksimissaan yksi POCX OP_RETURN:** Transaktio ei voi sisältää useita POCX/XCOP-merkkejä

**Toteutus:** `src/consensus/tx_check.cpp:63-77`

### Mempoolin hyväksyntätarkistukset (PreChecks)

Suoritetaan `src/validation.cpp`-tiedostossa täydellä ketjun tilan ja mempoolin käytöllä:

#### Delegoinnin validointi

1. **Plotin omistajuus:** Transaktion on oltava plotin omistajan allekirjoittama
2. **Plotin tila:** Plotin on oltava UNASSIGNED (0) tai REVOKED (4) -tilassa
3. **Mempoolin konfliktit:** Ei muuta delegointia tälle plotille mempoolissa (ensimmäinen nähdään voittaa)

#### Peruutuksen validointi

1. **Plotin omistajuus:** Transaktion on oltava plotin omistajan allekirjoittama
2. **Aktiivinen delegointi:** Plotin on oltava vain ASSIGNED (2) -tilassa
3. **Mempoolin konfliktit:** Ei muuta peruutusta tälle plotille mempoolissa

**Toteutus:** `src/validation.cpp:898-993`

### Validointivirta

```
Transaktion lähetys
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Max yksi POCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Varmenna plotin omistajuus
  ✓ Tarkista delegoinnin tila
  ✓ Tarkista mempoolin konfliktit
       ↓
   Kelvollinen → Hyväksy mempooliin
   Kelvoton → Hylkää (älä propagoi)
       ↓
Lohkon louhinta
       ↓
ConnectBlock() [validation.cpp]
  ✓ Uudelleenvalidoi kaikki tarkistukset (syvyyspuolustus)
  ✓ Sovella tilamuutokset
  ✓ Tallenna kumoamistiedot
```

### Syvyyspuolustus

Kaikki mempoolin validointitarkistukset suoritetaan uudelleen `ConnectBlock()`-vaiheessa suojaamaan:
- Mempoolin ohitushyökkäyksiltä
- Kelvottomilta lohkoilta haitallisten louhijoiden toimesta
- Reunatapauksissa reorg-skenaarioiden aikana

Lohkon validointi pysyy konsensuksen kannalta määräävänä.

## Atomiset tietokantapäivitykset

### Kolmitasoinen arkkitehtuuri

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (muistivälimuisti)    │  ← Delegointimuutokset seurataan muistissa
│   - Coins: cacheCoins                   │
│   - Delegoinnit: pendingAssignments     │
│   - Muutosseuranta: dirtyPlots          │
│   - Poistot: deletedAssignments         │
│   - Muistiseuranta: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (tietokantakerros)       │  ← Yksi atominen kirjoitus
│   - BatchWrite(): UTXO:t + Delegoinnit  │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (levytallennus)               │  ← ACID-takuut
│   - Atominen transaktio                 │
└─────────────────────────────────────────┘
```

### Flush-prosessi

Kun `view.Flush()` kutsutaan lohkon liittämisen aikana:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Kirjoita kolikkomuutokset pohjalle
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Kirjoita delegointimuutokset atomisesti
    if (fOk && !dirtyPlots.empty()) {
        // Kerää muuttuneet delegoinnit
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // Tyhjä - käyttämätön

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // Kirjoita tietokantaan
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // Tyhjennä seuranta
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // Vapauta muisti
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Toteutus:** `src/coins.cpp:278-315`

### Tietokannan eräkirjoitus

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Yksi LevelDB-erä

    // 1. Merkitse siirtymätila
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Kirjoita kaikki kolikkomuutokset
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Merkitse yhdenmukainen tila
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. ATOMINEN COMMIT
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Delegoinnit kirjoitetaan erikseen mutta samassa tietokantakontekstissa
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // Käyttämätön parametri (säilytetty API-yhteensopivuutta varten)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // Uusi erä, mutta sama tietokanta

    // Kirjoita delegointihistoria
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // Poista poistetut delegoinnit historiasta
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // ATOMINEN COMMIT
    return m_db->WriteBatch(batch);
}
```

**Toteutus:** `src/txdb.cpp:332-348`

### Atomiisuustakuut

**Mikä on atomista:**
- Kaikki lohkon kolikkomuutokset kirjoitetaan atomisesti
- Kaikki lohkon delegointimuutokset kirjoitetaan atomisesti
- Tietokanta pysyy yhdenmukaisena kaatumisten yli

**Nykyinen rajoitus:**
- Kolikot ja delegoinnit kirjoitetaan **erillisillä** LevelDB-eräoperaatioilla
- Molemmat operaatiot tapahtuvat `view.Flush()`-kutsun aikana, mutta eivät yhdellä atomisella kirjoituksella
- Käytännössä: Molemmat erät valmistuvat nopeasti peräkkäin ennen levyn fsync-operaatiota
- Riski on minimaalinen: Molemmat pitäisi toistaa samasta lohkosta kaatumisen palautuksen aikana

**Huomautus:** Tämä poikkeaa alkuperäisestä arkkitehtuurisuunnitelmasta, joka vaati yhden yhtenäisen erän. Nykyinen toteutus käyttää kahta erää mutta ylläpitää yhdenmukaisuuden Bitcoin Coren olemassa olevien kaatumispalautusmekanismien kautta (DB_HEAD_BLOCKS-merkki).

## Reorg-käsittely

### Kumoamisdatarakenne

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Delegointi lisättiin (poista kumoamisessa)
        MODIFIED = 1,   // Delegointia muokattiin (palauta kumoamisessa)
        REVOKED = 2     // Delegointi peruutettiin (palauta kumoamisessa)
    };

    UndoType type;
    ForgingAssignment assignment;  // Täysi tila ennen muutosta
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // UTXO-kumoamisdata
    std::vector<ForgingUndo> vforgingundo;  // Delegoinnin kumoamisdata
};
```

**Toteutus:** `src/undo.h:63-105`

### DisconnectBlock-prosessi

Kun lohko irrotetaan reorgin aikana:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... vakio UTXO-irrotus ...

    // Lue kumoamisdata levyltä
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Kumoa delegointimuutokset (käsittele käänteisessä järjestyksessä)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Delegointi lisättiin - poista se
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Delegointi peruutettiin - palauta peruuttamaton tila
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Delegointia muokattiin - palauta edellinen tila
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Toteutus:** `src/validation.cpp:2381-2415`

### Välimuistin hallinta reorgin aikana

```cpp
class CCoinsViewCache {
private:
    // Delegointivälimuistit
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Seuraa muutettuja plotteja
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // Seuraa poistoja
    mutable size_t cachedAssignmentsUsage{0};  // Muistiseuranta

public:
    void AddForgingAssignment(const ForgingAssignment& assignment) {
        pendingAssignments[assignment.plotAddress].push_back(assignment);
        dirtyPlots.insert(assignment.plotAddress);
        cachedAssignmentsUsage += sizeof(ForgingAssignment);
    }

    void RemoveForgingAssignment(const std::array<uint8_t, 20>& plotAddress,
                                 const uint256& assignment_txid) {
        auto key = std::make_pair(plotAddress, assignment_txid);
        deletedAssignments.insert(key);
        dirtyPlots.insert(plotAddress);
        if (cachedAssignmentsUsage >= sizeof(ForgingAssignment)) {
            cachedAssignmentsUsage -= sizeof(ForgingAssignment);
        }
    }

    void RestoreForgingAssignment(const ForgingAssignment& assignment) {
        pendingAssignments[assignment.plotAddress].push_back(assignment);
        dirtyPlots.insert(assignment.plotAddress);
        auto key = std::make_pair(assignment.plotAddress, assignment.assignment_txid);
        deletedAssignments.erase(key);
        if (true) {
            cachedAssignmentsUsage += sizeof(ForgingAssignment);
        }
    }
};
```

**Toteutus:** `src/coins.cpp:494-565`

## RPC-rajapinta

### Solmukomennot (ei vaadi lompakkoa)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Palauttaa plotin osoitteen nykyisen delegointitilan:
```json
{
  "plot_address": "pocx1qplot...",
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 100,
  "activation_height": 244,
  "revoked": false
}
```

**Toteutus:** `src/pocx/rpc/assignments.cpp:31-126`

### Lompakkokomennot (vaatii lompakon)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Luo delegointitransaktion:
- Valitsee automaattisesti suurimman UTXO:n plotin osoitteesta omistajuuden todistamiseksi
- Rakentaa transaktion OP_RETURN + vaihtorahatulosteella
- Allekirjoittaa plotin omistajan avaimella
- Lähettää verkkoon

**Toteutus:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Luo peruutustransaktion:
- Valitsee automaattisesti suurimman UTXO:n plotin osoitteesta omistajuuden todistamiseksi
- Rakentaa transaktion OP_RETURN + vaihtorahatulosteella
- Allekirjoittaa plotin omistajan avaimella
- Lähettää verkkoon

**Toteutus:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### Lompakon transaktion luonti

Lompakon transaktion luontiprosessi:

```cpp
1. Jäsennä ja validoi osoitteet (on oltava P2WPKH bech32)
2. Etsi suurin UTXO plotin osoitteesta (todistaa omistajuuden)
3. Luo väliaikainen transaktio valetuloksella
4. Allekirjoita transaktio (saa tarkan koon todistajadatalla)
5. Korvaa valetuloste OP_RETURNilla
6. Säädä maksut suhteellisesti kokomuutoksen perusteella
7. Allekirjoita lopullinen transaktio uudelleen
8. Lähetä verkkoon
```

**Keskeinen oivallus:** Lompakon on kulutettava plotin osoitteesta omistajuuden todistamiseksi, joten se pakottaa automaattisesti kolikon valinnan kyseisestä osoitteesta.

**Toteutus:** `src/pocx/assignments/transactions.cpp:38-263`

## Tiedostorakenne

### Keskeiset toteutustiedostot

```
src/
├── coins.h                        # ForgingAssignment-rakenne, CCoinsViewCache-metodit [710 riviä]
├── coins.cpp                      # Välimuistin hallinta, eräkirjoitukset [603 riviä]
│
├── txdb.h                         # CCoinsViewDB-delegointimetodit [90 riviä]
├── txdb.cpp                       # Tietokannan luku/kirjoitus [349 riviä]
│
├── undo.h                         # ForgingUndo-rakenne reorgeille
│
├── validation.cpp                 # ConnectBlock/DisconnectBlock-integraatio
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # OP_RETURN-muoto, jäsennys, varmennus
    │   ├── opcodes.cpp            # [259 riviä] Merkkimäärittelyt, OP_RETURN-operaatiot, omistajuustarkistus
    │   ├── assignment_state.h     # GetEffectiveSigner, GetAssignmentState-apufunktiot
    │   ├── assignment_state.cpp   # Delegointitilan kyselyfunktiot
    │   ├── transactions.h         # Lompakon transaktion luonti-API
    │   └── transactions.cpp       # create_assignment, revoke_assignment lompakkofunktiot
    │
    ├── rpc/
    │   ├── assignments.h          # Solmun RPC-komennot (ei lompakkoa)
    │   ├── assignments.cpp        # get_assignment, list_assignments RPC:t
    │   ├── assignments_wallet.h   # Lompakon RPC-komennot
    │   └── assignments_wallet.cpp # create_assignment, revoke_assignment RPC:t
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Suorituskykyominaisuudet

### Tietokantaoperaatiot

- **Hae nykyinen delegointi:** O(n) - skannaa kaikki plotin osoitteen delegoinnit löytääkseen viimeisimmän
- **Hae delegointihistoria:** O(n) - iteroi kaikki plotin delegoinnit
- **Luo delegointi:** O(1) - yksi lisäys
- **Peruuta delegointi:** O(1) - yksi päivitys
- **Reorg (per delegointi):** O(1) - suora kumoamisdatan soveltaminen

Missä n = plotin delegointien määrä (tyypillisesti pieni, < 10)

### Muistinkäyttö

- **Per delegointi:** ~160 tavua (ForgingAssignment-rakenne)
- **Välimuistin yläpuoli:** Hajautustaulun yläpuoli muutosseurannalle
- **Tyypillinen lohko:** <10 delegointia = <2 KB muistia

### Levynkäyttö

- **Per delegointi:** ~200 tavua levyllä (LevelDB-yläpuolella)
- **10000 delegointia:** ~2 MB levytilaa
- **Merkityksetön verrattuna UTXO-joukkoon:** <0.001 % tyypillisestä chainstatesta

## Nykyiset rajoitukset ja tuleva työ

### Atomiisuusrajoitus

**Nykyinen:** Kolikot ja delegoinnit kirjoitetaan erillisissä LevelDB-erissä `view.Flush()`-kutsun aikana

**Vaikutus:** Teoreettinen epäyhdenmukaisuusriski jos kaatuminen tapahtuu erien välillä

**Lievennys:**
- Molemmat erät valmistuvat nopeasti ennen fsync-operaatiota
- Bitcoin Coren kaatumispalautus käyttää DB_HEAD_BLOCKS-merkkiä
- Käytännössä: Ei koskaan havaittu testauksessa

**Tuleva parannus:** Yhdistäminen yhdeksi LevelDB-eräoperaatioksi

### Delegointihistorian leikkaus

**Nykyinen:** Kaikki delegoinnit tallennetaan loputtomiin

**Vaikutus:** ~200 tavua per delegointi ikuisesti

**Tulevaisuus:** Valinnainen täysin peruutettujen delegointien leikkaus N lohkon jälkeen

**Huomautus:** Tuskin tarvitaan – jopa 1 miljoonaa delegointia = 200 MB

## Testaustila

### Toteutetut testit

✅ OP_RETURN-jäsennys ja validointi
✅ Omistajuuden varmennus
✅ ConnectBlock-delegoinnin luonti
✅ ConnectBlock-peruutus
✅ DisconnectBlock-reorg-käsittely
✅ Tietokannan luku/kirjoitusoperaatiot
✅ Tilasiirtymät (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
✅ RPC-komennot (get_assignment, create_assignment, revoke_assignment)
✅ Lompakon transaktion luonti

### Testien kattavuusalueet

- Yksikkötestit: `src/test/pocx_*_tests.cpp`
- Toiminnalliset testit: `test/functional/feature_pocx_*.py`
- Integraatiotestit: Manuaalinen testaus regtestillä

## Konsensussäännöt

### Delegoinnin luontisäännöt

1. **Omistajuus:** Transaktion on oltava plotin omistajan allekirjoittama
2. **Tila:** Plotin on oltava UNASSIGNED- tai REVOKED-tilassa
3. **Muoto:** Kelvollinen OP_RETURN POCX-merkillä + 2x 20-tavuinen osoite
4. **Uniikkius:** Yksi aktiivinen delegointi per plotti kerrallaan

### Peruutussäännöt

1. **Omistajuus:** Transaktion on oltava plotin omistajan allekirjoittama
2. **Olemassaolo:** Delegoinnin on oltava olemassa eikä jo peruutettu
3. **Muoto:** Kelvollinen OP_RETURN XCOP-merkillä + 20-tavuinen osoite

### Aktivointisäännöt

- **Delegoinnin aktivointi:** `assignment_height + nForgingAssignmentDelay`
- **Peruutuksen aktivointi:** `revocation_height + nForgingRevocationDelay`
- **Viiveet:** Konfiguroitavissa verkkokohtaisesti (esim. 30 lohkoa = ~1 tunti 2 minuutin lohkoajalla)

### Lohkon validointi

- Kelvoton delegointi/peruutus → lohko hylätään (konsensusvirhe)
- OP_RETURN-tulosteet poissuljetaan automaattisesti UTXO-joukosta (vakio Bitcoin-käyttäytyminen)
- Delegointien käsittely tapahtuu ennen UTXO-päivityksiä ConnectBlockissa

## Johtopäätökset

Toteutettu PoCX forging-delegointijärjestelmä tarjoaa:

✅ **Yksinkertaisuus:** Vakio Bitcoin-transaktioita, ei erityisiä UTXO:ita
✅ **Kustannustehokkuus:** Ei pölyvaatimusta, vain transaktiomaksut
✅ **Reorg-turvallisuus:** Kattava kumoamisdata palauttaa oikean tilan
✅ **Atomiset päivitykset:** Tietokantayhdenmukaisuus LevelDB-erien kautta
✅ **Täysi historia:** Täydellinen auditointijälki kaikista delegoinneista ajan myötä
✅ **Puhdas arkkitehtuuri:** Minimaaliset Bitcoin Core -muutokset, eristetty PoCX-koodi
✅ **Tuotantovalmis:** Täysin toteutettu, testattu ja toiminnassa

### Toteutuksen laatu

- **Koodin organisointi:** Erinomainen - selkeä erottelu Bitcoin Coren ja PoCX:n välillä
- **Virheenkäsittely:** Kattava konsensusvalidointi
- **Dokumentaatio:** Koodikommentit ja rakenne hyvin dokumentoitu
- **Testaus:** Ydintoiminnallisuus testattu, integraatio varmennettu

### Keskeiset suunnittelupäätökset vahvistettu

1. ✅ Vain OP_RETURN -lähestymistapa (vs UTXO-pohjainen)
2. ✅ Erillinen tietokantatallennus (vs Coin extraData)
3. ✅ Täysi historiaseuranta (vs vain nykyinen)
4. ✅ Omistajuus allekirjoituksella (vs UTXO:n kulutus)
5. ✅ Aktivointiviiveet (estää reorg-hyökkäykset)

Järjestelmä saavuttaa onnistuneesti kaikki arkkitehtuuritavoitteet puhtaalla, ylläpidettävällä toteutuksella.

---

[← Edellinen: Konsensus ja louhinta](3-consensus-and-mining.md) | [Sisällysluettelo](index.md) | [Seuraava: Aikasynkronointi →](5-timing-security.md)
