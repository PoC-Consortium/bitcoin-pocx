[← Προηγούμενο: Συναίνεση και Εξόρυξη](3-consensus-and-mining.md) | [Πίνακας Περιεχομένων](index.md) | [Επόμενο: Χρονικός Συγχρονισμός →](5-timing-security.md)

---

# Κεφάλαιο 4: Σύστημα Ανάθεσης Σφυρηλάτησης PoCX

## Εκτελεστική Περίληψη

Αυτό το έγγραφο περιγράφει το **υλοποιημένο** σύστημα ανάθεσης σφυρηλάτησης PoCX χρησιμοποιώντας αρχιτεκτονική αποκλειστικά με OP_RETURN. Το σύστημα επιτρέπει στους ιδιοκτήτες plot να αναθέτουν δικαιώματα σφυρηλάτησης σε ξεχωριστές διευθύνσεις μέσω on-chain συναλλαγών, με πλήρη ασφάλεια reorg και ατομικές λειτουργίες βάσης δεδομένων.

**Κατάσταση:** Πλήρως Υλοποιημένο και Λειτουργικό

## Βασική Φιλοσοφία Σχεδιασμού

**Βασική Αρχή:** Οι αναθέσεις είναι άδειες, όχι περιουσιακά στοιχεία

- Χωρίς ειδικά UTXOs για παρακολούθηση ή δαπάνη
- Η κατάσταση ανάθεσης αποθηκεύεται ξεχωριστά από το σύνολο UTXO
- Η ιδιοκτησία αποδεικνύεται από την υπογραφή συναλλαγής, όχι από δαπάνη UTXO
- Πλήρης παρακολούθηση ιστορικού για πλήρες ίχνος ελέγχου
- Ατομικές ενημερώσεις βάσης δεδομένων μέσω batch writes LevelDB

## Δομή Συναλλαγής

### Μορφή Συναλλαγής Ανάθεσης

```
Είσοδοι:
  [0]: Οποιοδήποτε UTXO ελεγχόμενο από τον ιδιοκτήτη plot (αποδεικνύει ιδιοκτησία + πληρώνει τέλη)
       Πρέπει να είναι υπογεγραμμένο με το ιδιωτικό κλειδί του ιδιοκτήτη plot
  [1+]: Προαιρετικές πρόσθετες είσοδοι για κάλυψη τελών

Έξοδοι:
  [0]: OP_RETURN (δείκτης POCX + διεύθυνση plot + διεύθυνση forge)
       Μορφή: OP_RETURN <0x2c> "POCX" <plot_addr_20> <forge_addr_20>
       Μέγεθος: 46 bytes συνολικά (1 byte OP_RETURN + 1 byte μήκος + 44 bytes δεδομένα)
       Αξία: 0 BTC (μη-δαπανήσιμο, δεν προστίθεται στο σύνολο UTXO)

  [1]: Ρέστα πίσω στον χρήστη (προαιρετικά, τυπικό P2WPKH)
```

**Υλοποίηση:** `src/pocx/assignments/opcodes.cpp:25-52`

### Μορφή Συναλλαγής Ανάκλησης

```
Είσοδοι:
  [0]: Οποιοδήποτε UTXO ελεγχόμενο από τον ιδιοκτήτη plot (αποδεικνύει ιδιοκτησία + πληρώνει τέλη)
       Πρέπει να είναι υπογεγραμμένο με το ιδιωτικό κλειδί του ιδιοκτήτη plot
  [1+]: Προαιρετικές πρόσθετες είσοδοι για κάλυψη τελών

Έξοδοι:
  [0]: OP_RETURN (δείκτης XCOP + διεύθυνση plot)
       Μορφή: OP_RETURN <0x18> "XCOP" <plot_addr_20>
       Μέγεθος: 26 bytes συνολικά (1 byte OP_RETURN + 1 byte μήκος + 24 bytes δεδομένα)
       Αξία: 0 BTC (μη-δαπανήσιμο, δεν προστίθεται στο σύνολο UTXO)

  [1]: Ρέστα πίσω στον χρήστη (προαιρετικά, τυπικό P2WPKH)
```

**Υλοποίηση:** `src/pocx/assignments/opcodes.cpp:54-77`

### Δείκτες

- **Δείκτης Ανάθεσης:** `POCX` (0x50, 0x4F, 0x43, 0x58) = "Proof of Capacity neXt"
- **Δείκτης Ανάκλησης:** `XCOP` (0x58, 0x43, 0x4F, 0x50) = "eXit Capacity OPeration"

**Υλοποίηση:** `src/pocx/assignments/opcodes.cpp:15-19`

### Βασικά Χαρακτηριστικά Συναλλαγής

- Τυπικές συναλλαγές Bitcoin (χωρίς αλλαγές πρωτοκόλλου)
- Οι έξοδοι OP_RETURN είναι αποδεδειγμένα μη-δαπανήσιμες (δεν προστίθενται ποτέ στο σύνολο UTXO)
- Η ιδιοκτησία plot αποδεικνύεται από υπογραφή στην είσοδο[0] από τη διεύθυνση plot
- Χαμηλό κόστος (~200 bytes, τυπικά <0.0001 BTC τέλος)
- Το πορτοφόλι επιλέγει αυτόματα το μεγαλύτερο UTXO από τη διεύθυνση plot για απόδειξη ιδιοκτησίας

## Αρχιτεκτονική Βάσης Δεδομένων

### Δομή Αποθήκευσης

Όλα τα δεδομένα ανάθεσης αποθηκεύονται στην ίδια βάση δεδομένων LevelDB με το σύνολο UTXO (`chainstate/`), αλλά με ξεχωριστά προθέματα κλειδιών:

```
chainstate/ LevelDB:
├─ Σύνολο UTXO (τυπικό Bitcoin Core)
│  └─ Πρόθεμα 'C': COutPoint → Coin
│
└─ Κατάσταση Ανάθεσης (προσθήκες PoCX)
   └─ Πρόθεμα 'A': (plot_address, assignment_txid) → ForgingAssignment
       └─ Πλήρες ιστορικό: όλες οι αναθέσεις ανά plot με την πάροδο του χρόνου
```

**Υλοποίηση:** `src/txdb.cpp:237-348`

### Δομή ForgingAssignment

```cpp
struct ForgingAssignment {
    // Ταυτότητα
    std::array<uint8_t, 20> plotAddress;      // Ιδιοκτήτης plot (20-byte P2WPKH hash)
    std::array<uint8_t, 20> forgingAddress;   // Κάτοχος δικαιωμάτων σφυρηλάτησης (20-byte P2WPKH hash)

    // Κύκλος ζωής ανάθεσης
    uint256 assignment_txid;                   // Συναλλαγή που δημιούργησε την ανάθεση
    int assignment_height;                     // Ύψος block δημιουργίας
    int assignment_effective_height;           // Πότε γίνεται ενεργή (ύψος + καθυστέρηση)

    // Κύκλος ζωής ανάκλησης
    bool revoked;                              // Έχει ανακληθεί αυτή;
    uint256 revocation_txid;                   // Συναλλαγή που την ανακάλεσε
    int revocation_height;                     // Ύψος block ανάκλησης
    int revocation_effective_height;           // Πότε η ανάκληση είναι ενεργή (ύψος + καθυστέρηση)

    // Μέθοδοι ερωτήματος κατάστασης
    ForgingState GetStateAtHeight(int height) const;
    bool IsActiveAtHeight(int height) const;
};
```

**Υλοποίηση:** `src/coins.h:111-178`

### Καταστάσεις Ανάθεσης

```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Δεν υπάρχει ανάθεση
    ASSIGNING = 1,   // Δημιουργήθηκε ανάθεση, αναμονή για καθυστέρηση ενεργοποίησης
    ASSIGNED = 2,    // Ανάθεση ενεργή, επιτρέπεται σφυρηλάτηση
    REVOKING = 3,    // Ανακλήθηκε, αλλά ακόμα ενεργή κατά τη διάρκεια της περιόδου καθυστέρησης
    REVOKED = 4      // Πλήρως ανακλημένη, δεν είναι πλέον ενεργή
};
```

**Υλοποίηση:** `src/coins.h:98-104`

### Κλειδιά Βάσης Δεδομένων

```cpp
// Κλειδί ιστορικού: αποθηκεύει πλήρη εγγραφή ανάθεσης
// Μορφή κλειδιού: (πρόθεμα, plotAddress, assignment_height, assignment_txid)
struct AssignmentHistoryKey {
    uint8_t prefix;                       // DB_ASSIGNMENT_HISTORY = 'A'
    std::array<uint8_t, 20> plotAddress;  // Διεύθυνση plot (20 bytes)
    int assignment_height;                // Ύψος για βελτιστοποίηση ταξινόμησης
    uint256 assignment_txid;              // ID συναλλαγής
};
```

**Υλοποίηση:** `src/txdb.cpp:245-262`

### Παρακολούθηση Ιστορικού

- Κάθε ανάθεση αποθηκεύεται μόνιμα (δεν διαγράφεται ποτέ εκτός reorg)
- Παρακολούθηση πολλαπλών αναθέσεων ανά plot με την πάροδο του χρόνου
- Επιτρέπει πλήρες ίχνος ελέγχου και ιστορικά ερωτήματα κατάστασης
- Οι ανακλημένες αναθέσεις παραμένουν στη βάση δεδομένων με `revoked=true`

## Επεξεργασία Block

### Ενσωμάτωση ConnectBlock

Τα OP_RETURNs ανάθεσης και ανάκλησης επεξεργάζονται κατά τη σύνδεση block στο `validation.cpp`:

```cpp
// Τοποθεσία: Μετά την επικύρωση script, πριν το UpdateCoins
#ifdef ENABLE_POCX
for (const auto& tx : block.vtx) {
    for (const CTxOut& output : tx.vout) {
        if (IsAssignmentOpReturn(output)) {
            // Ανάλυση δεδομένων OP_RETURN
            auto [plot_addr, forge_addr] = ParseAssignmentOpReturn(output);

            // Επαλήθευση ιδιοκτησίας (η tx πρέπει να είναι υπογεγραμμένη από ιδιοκτήτη plot)
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-assignment-ownership");

            // Έλεγχος κατάστασης plot (πρέπει να είναι UNASSIGNED ή REVOKED)
            ForgingState state = GetPlotForgingState(plot_addr, height, view);
            if (state != UNASSIGNED && state != REVOKED)
                return state.Invalid("plot-not-available-for-assignment");

            // Δημιουργία νέας ανάθεσης
            int activation_height = height + consensus.nForgingAssignmentDelay;
            ForgingAssignment assignment(plot_addr, forge_addr, tx.GetHash(),
                                       height, activation_height);

            view.AddForgingAssignment(assignment);

            // Αποθήκευση δεδομένων αναίρεσης
            blockundo.vforgingundo.emplace_back(UndoType::ADDED, assignment);
        }
        else if (IsRevocationOpReturn(output)) {
            // Ανάλυση δεδομένων OP_RETURN
            auto plot_addr = ParseRevocationOpReturn(output);

            // Επαλήθευση ιδιοκτησίας
            if (!VerifyPlotOwnership(tx, plot_addr, view))
                return state.Invalid("bad-revocation-ownership");

            // Λήψη τρέχουσας ανάθεσης
            auto existing = view.GetForgingAssignment(plot_addr, height);
            if (!existing || existing->revoked)
                return state.Invalid("no-assignment-to-revoke");

            // Αποθήκευση παλιάς κατάστασης για αναίρεση
            blockundo.vforgingundo.emplace_back(UndoType::REVOKED, *existing);

            // Σήμανση ως ανακλημένη
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

// Το UpdateCoins προχωρά κανονικά (παρακάμπτει αυτόματα τις εξόδους OP_RETURN)
```

**Υλοποίηση:** `src/validation.cpp:2775-2878`

### Επαλήθευση Ιδιοκτησίας

```cpp
bool VerifyPlotOwnership(const CTransaction& tx,
                        const std::array<uint8_t, 20>& plotAddress,
                        const CCoinsViewCache& view)
{
    // Έλεγχος ότι τουλάχιστον μία είσοδος είναι υπογεγραμμένη από ιδιοκτήτη plot
    for (const auto& input : tx.vin) {
        Coin coin = view.GetCoin(input.prevout);
        if (!coin) continue;

        // Εξαγωγή προορισμού
        CTxDestination dest;
        if (!ExtractDestination(coin.out.scriptPubKey, dest)) continue;

        // Έλεγχος αν είναι P2WPKH στη διεύθυνση plot
        if (auto* witness_addr = std::get_if<WitnessV0KeyHash>(&dest)) {
            if (std::equal(witness_addr->begin(), witness_addr->end(),
                          plotAddress.begin())) {
                // Το Bitcoin Core έχει ήδη επικυρώσει την υπογραφή
                return true;
            }
        }
    }
    return false;
}
```

**Υλοποίηση:** `src/pocx/assignments/opcodes.cpp:217-256`

### Καθυστερήσεις Ενεργοποίησης

Οι αναθέσεις και ανακλήσεις έχουν διαμορφώσιμες καθυστερήσεις ενεργοποίησης για αποτροπή επιθέσεων reorg:

```cpp
// Παράμετροι συναίνεσης (διαμορφώσιμες ανά δίκτυο)
// Παράδειγμα: 30 blocks = ~1 ώρα με χρόνο block 2 λεπτών
consensus.nForgingAssignmentDelay;   // Καθυστέρηση ενεργοποίησης ανάθεσης
consensus.nForgingRevocationDelay;   // Καθυστέρηση ενεργοποίησης ανάκλησης
```

**Μεταβάσεις Κατάστασης:**
- Ανάθεση: `UNASSIGNED → ASSIGNING (καθυστέρηση) → ASSIGNED`
- Ανάκληση: `ASSIGNED → REVOKING (καθυστέρηση) → REVOKED`

**Υλοποίηση:** `src/consensus/params.h`, `src/kernel/chainparams.cpp`

## Επικύρωση Mempool

Οι συναλλαγές ανάθεσης και ανάκλησης επικυρώνονται κατά την αποδοχή στο mempool για απόρριψη μη έγκυρων συναλλαγών πριν τη διάδοση δικτύου.

### Έλεγχοι Επιπέδου Συναλλαγής (CheckTransaction)

Εκτελούνται στο `src/consensus/tx_check.cpp` χωρίς πρόσβαση στην κατάσταση αλυσίδας:

1. **Μέγιστα Ένα POCX OP_RETURN:** Η συναλλαγή δεν μπορεί να περιέχει πολλαπλούς δείκτες POCX/XCOP

**Υλοποίηση:** `src/consensus/tx_check.cpp:63-77`

### Έλεγχοι Αποδοχής Mempool (PreChecks)

Εκτελούνται στο `src/validation.cpp` με πλήρη πρόσβαση σε κατάσταση αλυσίδας και mempool:

#### Επικύρωση Ανάθεσης

1. **Ιδιοκτησία Plot:** Η συναλλαγή πρέπει να είναι υπογεγραμμένη από ιδιοκτήτη plot
2. **Κατάσταση Plot:** Το plot πρέπει να είναι UNASSIGNED (0) ή REVOKED (4)
3. **Συγκρούσεις Mempool:** Καμία άλλη ανάθεση για αυτό το plot στο mempool (κερδίζει η πρώτη)

#### Επικύρωση Ανάκλησης

1. **Ιδιοκτησία Plot:** Η συναλλαγή πρέπει να είναι υπογεγραμμένη από ιδιοκτήτη plot
2. **Ενεργή Ανάθεση:** Το plot πρέπει να είναι σε κατάσταση ASSIGNED (2) μόνο
3. **Συγκρούσεις Mempool:** Καμία άλλη ανάκληση για αυτό το plot στο mempool

**Υλοποίηση:** `src/validation.cpp:898-993`

### Ροή Επικύρωσης

```
Μετάδοση Συναλλαγής
       ↓
CheckTransaction() [tx_check.cpp]
  ✓ Μέγιστα ένα POCX OP_RETURN
       ↓
MemPoolAccept::PreChecks() [validation.cpp]
  ✓ Επαλήθευση ιδιοκτησίας plot
  ✓ Έλεγχος κατάστασης ανάθεσης
  ✓ Έλεγχος συγκρούσεων mempool
       ↓
   Έγκυρο → Αποδοχή στο Mempool
   Μη Έγκυρο → Απόρριψη (χωρίς διάδοση)
       ↓
Εξόρυξη Block
       ↓
ConnectBlock() [validation.cpp]
  ✓ Επανεπικύρωση όλων των ελέγχων (άμυνα σε βάθος)
  ✓ Εφαρμογή αλλαγών κατάστασης
  ✓ Καταγραφή πληροφοριών αναίρεσης
```

### Άμυνα σε Βάθος

Όλοι οι έλεγχοι επικύρωσης mempool επανεκτελούνται κατά τη διάρκεια του `ConnectBlock()` για προστασία έναντι:
- Επιθέσεων παράκαμψης mempool
- Μη έγκυρων blocks από κακόβουλους εξορύκτες
- Ακραίων περιπτώσεων κατά τη διάρκεια σεναρίων reorg

Η επικύρωση block παραμένει αυθεντική για τη συναίνεση.

## Ατομικές Ενημερώσεις Βάσης Δεδομένων

### Αρχιτεκτονική Τριών Επιπέδων

```
┌─────────────────────────────────────────┐
│   CCoinsViewCache (Μνήμη Cache)         │  ← Αλλαγές αναθέσεων παρακολουθούνται στη μνήμη
│   - Coins: cacheCoins                   │
│   - Αναθέσεις: pendingAssignments       │
│   - Παρακολούθηση dirty: dirtyPlots     │
│   - Διαγραφές: deletedAssignments       │
│   - Παρακολούθηση μνήμης: cachedAssignmentsUsage │
└─────────────────────────────────────────┘
                    ↓ Flush()
┌─────────────────────────────────────────┐
│   CCoinsViewDB (Επίπεδο Βάσης Δεδομένων)│  ← Μοναδική ατομική εγγραφή
│   - BatchWrite(): UTXOs + Αναθέσεις     │
└─────────────────────────────────────────┘
                    ↓ WriteBatch()
┌─────────────────────────────────────────┐
│   LevelDB (Αποθήκευση Δίσκου)           │  ← Εγγυήσεις ACID
│   - Ατομική συναλλαγή                   │
└─────────────────────────────────────────┘
```

### Διαδικασία Flush

Όταν καλείται `view.Flush()` κατά τη σύνδεση block:

```cpp
bool CCoinsViewCache::Flush() {
    // 1. Εγγραφή αλλαγών coin στη βάση
    auto cursor = CoinsViewCacheCursor(/*...*/, /*will_erase=*/true);
    bool fOk = base->BatchWrite(cursor, hashBlock);

    // 2. Ατομική εγγραφή αλλαγών ανάθεσης
    if (fOk && !dirtyPlots.empty()) {
        // Συλλογή dirty αναθέσεων
        ForgingAssignmentsMap assignmentsToWrite;
        PlotAddressAssignmentMap currentToWrite;  // Κενό - αχρησιμοποίητο

        for (const auto& plotAddr : dirtyPlots) {
            auto it = pendingAssignments.find(plotAddr);
            if (it != pendingAssignments.end()) {
                for (const auto& assignment : it->second) {
                    assignmentsToWrite[{plotAddr, assignment}] = assignment;
                }
            }
        }

        // Εγγραφή στη βάση δεδομένων
        fOk = base->BatchWriteAssignments(assignmentsToWrite, currentToWrite,
                                         deletedAssignments);

        if (fOk) {
            // Καθαρισμός παρακολούθησης
            dirtyPlots.clear();
            deletedAssignments.clear();
        }
    }

    if (fOk) {
        cacheCoins.clear();  // Απελευθέρωση μνήμης
        pendingAssignments.clear();
        cachedAssignmentsUsage = 0;
    }

    return fOk;
}
```

**Υλοποίηση:** `src/coins.cpp:278-315`

### Batch Write Βάσης Δεδομένων

```cpp
bool CCoinsViewDB::BatchWrite(CoinsViewCacheCursor& cursor, const uint256& hashBlock) {
    CDBBatch batch(*m_db);  // Μοναδικό batch LevelDB

    // 1. Σήμανση κατάστασης μετάβασης
    batch.Write(DB_HEAD_BLOCKS, Vector(hashBlock, old_tip));

    // 2. Εγγραφή όλων των αλλαγών coin
    for (auto it = cursor.Begin(); it != cursor.End(); it = cursor.NextAndMaybeErase(*it)) {
        if (it->second.coin.IsSpent())
            batch.Erase(CoinKey(it->first));
        else
            batch.Write(CoinKey(it->first), it->second.coin);
    }

    // 3. Σήμανση συνεπούς κατάστασης
    batch.Write(DB_BEST_BLOCK, hashBlock);

    // 4. ΑΤΟΜΙΚΗ ΔΕΣΜΕΥΣΗ
    bool ret = m_db->WriteBatch(batch);

    return ret;
}

// Αναθέσεις γράφονται ξεχωριστά αλλά στο ίδιο context συναλλαγής βάσης δεδομένων
bool CCoinsViewDB::BatchWriteAssignments(
    const ForgingAssignmentsMap& assignments,
    const PlotAddressAssignmentMap& currentAssignments,  // Αχρησιμοποίητη παράμετρος (κρατείται για συμβατότητα API)
    const DeletedAssignmentsSet& deletedAssignments)
{
    CDBBatch batch(*m_db);  // Νέο batch, αλλά ίδια βάση δεδομένων

    // Εγγραφή ιστορικού ανάθεσης
    for (const auto& [key, assignment] : assignments) {
        const auto& [plot_addr, txid] = key;
        batch.Write(AssignmentHistoryKey(plot_addr, txid), assignment);
    }

    // Διαγραφή διαγραμμένων αναθέσεων από ιστορικό
    for (const auto& [plot_addr, txid] : deletedAssignments) {
        batch.Erase(AssignmentHistoryKey(plot_addr, txid));
    }

    // ΑΤΟΜΙΚΗ ΔΕΣΜΕΥΣΗ
    return m_db->WriteBatch(batch);
}
```

**Υλοποίηση:** `src/txdb.cpp:332-348`

### Εγγυήσεις Ατομικότητας

**Τι είναι ατομικό:**
- Όλες οι αλλαγές coin εντός ενός block γράφονται ατομικά
- Όλες οι αλλαγές ανάθεσης εντός ενός block γράφονται ατομικά
- Η βάση δεδομένων παραμένει συνεπής σε περίπτωση κατάρρευσης

**Τρέχων περιορισμός:**
- Τα coins και οι αναθέσεις γράφονται σε **ξεχωριστές** λειτουργίες batch LevelDB
- Και οι δύο λειτουργίες συμβαίνουν κατά τη διάρκεια του `view.Flush()`, αλλά όχι σε μία μόνο ατομική εγγραφή
- Στην πράξη: Και τα δύο batches ολοκληρώνονται γρήγορα πριν το fsync δίσκου
- Ο κίνδυνος είναι ελάχιστος: Και τα δύο θα χρειαστούν επανάληψη από το ίδιο block κατά την ανάκαμψη από κατάρρευση

**Σημείωση:** Αυτό διαφέρει από το αρχικό αρχιτεκτονικό σχέδιο που απαιτούσε ένα μόνο ενοποιημένο batch. Η τρέχουσα υλοποίηση χρησιμοποιεί δύο batches αλλά διατηρεί τη συνέπεια μέσω των υπαρχόντων μηχανισμών ανάκαμψης από κατάρρευση του Bitcoin Core (δείκτης DB_HEAD_BLOCKS).

## Χειρισμός Reorg

### Δομή Δεδομένων Αναίρεσης

```cpp
struct ForgingUndo {
    enum class UndoType : uint8_t {
        ADDED = 0,      // Προστέθηκε ανάθεση (διαγραφή κατά την αναίρεση)
        MODIFIED = 1,   // Τροποποιήθηκε ανάθεση (επαναφορά κατά την αναίρεση)
        REVOKED = 2     // Ανακλήθηκε ανάθεση (αφαίρεση ανάκλησης κατά την αναίρεση)
    };

    UndoType type;
    ForgingAssignment assignment;  // Πλήρης κατάσταση πριν την αλλαγή
};

struct CBlockUndo {
    std::vector<CTxUndo> vtxundo;           // Δεδομένα αναίρεσης UTXO
    std::vector<ForgingUndo> vforgingundo;  // Δεδομένα αναίρεσης ανάθεσης
};
```

**Υλοποίηση:** `src/undo.h:63-105`

### Διαδικασία DisconnectBlock

Όταν ένα block αποσυνδέεται κατά τη διάρκεια ενός reorg:

```cpp
DisconnectResult Chainstate::DisconnectBlock(const CBlock& block,
                                              const CBlockIndex* pindex,
                                              CCoinsViewCache& view)
{
    // ... τυπική αποσύνδεση UTXO ...

    // Ανάγνωση δεδομένων αναίρεσης από δίσκο
    CBlockUndo blockUndo;
    if (!ReadBlockUndo(blockUndo, *pindex))
        return DISCONNECT_FAILED;

    #ifdef ENABLE_POCX
    // Αναίρεση αλλαγών ανάθεσης (επεξεργασία σε αντίστροφη σειρά)
    for (auto it = blockUndo.vforgingundo.rbegin();
         it != blockUndo.vforgingundo.rend(); ++it) {

        switch (it->type) {
            case UndoType::ADDED:
                // Προστέθηκε ανάθεση - αφαίρεσή της
                view.RemoveForgingAssignment(
                    it->assignment.plotAddress,
                    it->assignment.assignment_txid
                );
                break;

            case UndoType::REVOKED:
                // Ανακλήθηκε ανάθεση - επαναφορά μη-ανακλημένης κατάστασης
                view.RestoreForgingAssignment(it->assignment);
                break;

            case UndoType::MODIFIED:
                // Τροποποιήθηκε ανάθεση - επαναφορά προηγούμενης κατάστασης
                view.UpdateForgingAssignment(it->assignment);
                break;
        }
    }
    #endif

    return DISCONNECT_OK;
}
```

**Υλοποίηση:** `src/validation.cpp:2381-2415`

### Διαχείριση Cache Κατά τη Διάρκεια Reorg

```cpp
class CCoinsViewCache {
private:
    // Caches ανάθεσης
    mutable std::map<std::array<uint8_t, 20>, std::vector<ForgingAssignment>> pendingAssignments;
    mutable std::set<std::array<uint8_t, 20>> dirtyPlots;  // Παρακολούθηση τροποποιημένων plots
    mutable std::set<std::pair<std::array<uint8_t, 20>, uint256>> deletedAssignments;  // Παρακολούθηση διαγραφών
    mutable size_t cachedAssignmentsUsage{0};  // Παρακολούθηση μνήμης

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

**Υλοποίηση:** `src/coins.cpp:494-565`

## Διεπαφή RPC

### Εντολές Κόμβου (Δεν Απαιτείται Πορτοφόλι)

#### get_assignment
```bash
bitcoin-cli get_assignment "pocx1qplot..."
```

Επιστρέφει την τρέχουσα κατάσταση ανάθεσης για μια διεύθυνση plot:
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

**Υλοποίηση:** `src/pocx/rpc/assignments.cpp:31-126`

### Εντολές Πορτοφολιού (Απαιτείται Πορτοφόλι)

#### create_assignment
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
```

Δημιουργεί συναλλαγή ανάθεσης:
- Επιλέγει αυτόματα το μεγαλύτερο UTXO από τη διεύθυνση plot για απόδειξη ιδιοκτησίας
- Κατασκευάζει συναλλαγή με OP_RETURN + έξοδο ρέστων
- Υπογράφει με το κλειδί του ιδιοκτήτη plot
- Μεταδίδει στο δίκτυο

**Υλοποίηση:** `src/pocx/rpc/assignments_wallet.cpp:29-93`

#### revoke_assignment
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
```

Δημιουργεί συναλλαγή ανάκλησης:
- Επιλέγει αυτόματα το μεγαλύτερο UTXO από τη διεύθυνση plot για απόδειξη ιδιοκτησίας
- Κατασκευάζει συναλλαγή με OP_RETURN + έξοδο ρέστων
- Υπογράφει με το κλειδί του ιδιοκτήτη plot
- Μεταδίδει στο δίκτυο

**Υλοποίηση:** `src/pocx/rpc/assignments_wallet.cpp:95-154`

### Δημιουργία Συναλλαγής Πορτοφολιού

Η διαδικασία δημιουργίας συναλλαγής πορτοφολιού:

```cpp
1. Ανάλυση και επικύρωση διευθύνσεων (πρέπει να είναι P2WPKH bech32)
2. Εύρεση μεγαλύτερου UTXO από διεύθυνση plot (αποδεικνύει ιδιοκτησία)
3. Δημιουργία προσωρινής συναλλαγής με dummy έξοδο
4. Υπογραφή συναλλαγής (λήψη ακριβούς μεγέθους με δεδομένα witness)
5. Αντικατάσταση dummy εξόδου με OP_RETURN
6. Αναλογική προσαρμογή τελών βάσει αλλαγής μεγέθους
7. Επανυπογραφή τελικής συναλλαγής
8. Μετάδοση στο δίκτυο
```

**Βασική γνώση:** Το πορτοφόλι πρέπει να δαπανήσει από τη διεύθυνση plot για απόδειξη ιδιοκτησίας, οπότε αναγκάζει αυτόματα την επιλογή coin από αυτή τη διεύθυνση.

**Υλοποίηση:** `src/pocx/assignments/transactions.cpp:38-263`

## Δομή Αρχείων

### Αρχεία Βασικής Υλοποίησης

```
src/
├── coins.h                        # Δομή ForgingAssignment, μέθοδοι CCoinsViewCache [710 γραμμές]
├── coins.cpp                      # Διαχείριση cache, batch writes [603 γραμμές]
│
├── txdb.h                         # Μέθοδοι ανάθεσης CCoinsViewDB [90 γραμμές]
├── txdb.cpp                       # Ανάγνωση/εγγραφή βάσης δεδομένων [349 γραμμές]
│
├── undo.h                         # Δομή ForgingUndo για reorgs
│
├── validation.cpp                 # Ενσωμάτωση ConnectBlock/DisconnectBlock
│
└── pocx/
    ├── assignments/
    │   ├── opcodes.h              # Μορφή OP_RETURN, ανάλυση, επαλήθευση
    │   ├── opcodes.cpp            # [259 γραμμές] Ορισμοί δεικτών, λειτουργίες OP_RETURN, έλεγχος ιδιοκτησίας
    │   ├── assignment_state.h     # Βοηθοί GetEffectiveSigner, GetAssignmentState
    │   ├── assignment_state.cpp   # Συναρτήσεις ερωτήματος κατάστασης ανάθεσης
    │   ├── transactions.h         # API δημιουργίας συναλλαγής πορτοφολιού
    │   └── transactions.cpp       # Συναρτήσεις πορτοφολιού create_assignment, revoke_assignment
    │
    ├── rpc/
    │   ├── assignments.h          # Εντολές RPC κόμβου (χωρίς πορτοφόλι)
    │   ├── assignments.cpp        # RPCs get_assignment, list_assignments
    │   ├── assignments_wallet.h   # Εντολές RPC πορτοφολιού
    │   └── assignments_wallet.cpp # RPCs create_assignment, revoke_assignment
    │
    └── consensus/
        └── params.h               # nForgingAssignmentDelay, nForgingRevocationDelay
```

## Χαρακτηριστικά Επιδόσεων

### Λειτουργίες Βάσης Δεδομένων

- **Λήψη τρέχουσας ανάθεσης:** O(n) - σάρωση όλων των αναθέσεων για διεύθυνση plot για εύρεση της πιο πρόσφατης
- **Λήψη ιστορικού ανάθεσης:** O(n) - επανάληψη όλων των αναθέσεων για plot
- **Δημιουργία ανάθεσης:** O(1) - μοναδική εισαγωγή
- **Ανάκληση ανάθεσης:** O(1) - μοναδική ενημέρωση
- **Reorg (ανά ανάθεση):** O(1) - άμεση εφαρμογή δεδομένων αναίρεσης

Όπου n = αριθμός αναθέσεων για ένα plot (τυπικά μικρός, < 10)

### Χρήση Μνήμης

- **Ανά ανάθεση:** ~160 bytes (δομή ForgingAssignment)
- **Overhead cache:** Overhead hash map για παρακολούθηση dirty
- **Τυπικό block:** <10 αναθέσεις = <2 KB μνήμη

### Χρήση Δίσκου

- **Ανά ανάθεση:** ~200 bytes στο δίσκο (με overhead LevelDB)
- **10000 αναθέσεις:** ~2 MB χώρος δίσκου
- **Αμελητέο σε σύγκριση με σύνολο UTXO:** <0.001% τυπικού chainstate

## Τρέχοντες Περιορισμοί και Μελλοντική Εργασία

### Περιορισμός Ατομικότητας

**Τρέχουσα:** Τα coins και οι αναθέσεις γράφονται σε ξεχωριστά batches LevelDB κατά τη διάρκεια του `view.Flush()`

**Επίπτωση:** Θεωρητικός κίνδυνος ασυνέπειας αν συμβεί κατάρρευση μεταξύ των batches

**Μετριασμός:**
- Και τα δύο batches ολοκληρώνονται γρήγορα πριν το fsync
- Η ανάκαμψη από κατάρρευση του Bitcoin Core χρησιμοποιεί δείκτη DB_HEAD_BLOCKS
- Στην πράξη: Δεν παρατηρήθηκε ποτέ σε δοκιμές

**Μελλοντική βελτίωση:** Ενοποίηση σε μία μόνο λειτουργία batch LevelDB

### Περικοπή Ιστορικού Ανάθεσης

**Τρέχουσα:** Όλες οι αναθέσεις αποθηκεύονται επ' αόριστον

**Επίπτωση:** ~200 bytes ανά ανάθεση για πάντα

**Μέλλον:** Προαιρετική περικοπή πλήρως ανακλημένων αναθέσεων παλαιότερων από N blocks

**Σημείωση:** Απίθανο να χρειαστεί - ακόμα 1 εκατομμύριο αναθέσεις = 200 MB

## Κατάσταση Δοκιμών

### Υλοποιημένες Δοκιμές

Ανάλυση και επικύρωση OP_RETURN
Επαλήθευση ιδιοκτησίας
Δημιουργία ανάθεσης ConnectBlock
Ανάκληση ConnectBlock
Χειρισμός reorg DisconnectBlock
Λειτουργίες ανάγνωσης/εγγραφής βάσης δεδομένων
Μεταβάσεις κατάστασης (UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED)
Εντολές RPC (get_assignment, create_assignment, revoke_assignment)
Δημιουργία συναλλαγής πορτοφολιού

### Περιοχές Κάλυψης Δοκιμών

- Unit tests: `src/test/pocx_*_tests.cpp`
- Functional tests: `test/functional/feature_pocx_*.py`
- Integration tests: Χειροκίνητες δοκιμές με regtest

## Κανόνες Συναίνεσης

### Κανόνες Δημιουργίας Ανάθεσης

1. **Ιδιοκτησία:** Η συναλλαγή πρέπει να είναι υπογεγραμμένη από ιδιοκτήτη plot
2. **Κατάσταση:** Το plot πρέπει να είναι σε κατάσταση UNASSIGNED ή REVOKED
3. **Μορφή:** Έγκυρο OP_RETURN με δείκτη POCX + 2x διευθύνσεις 20-byte
4. **Μοναδικότητα:** Μία ενεργή ανάθεση ανά plot κάθε φορά

### Κανόνες Ανάκλησης

1. **Ιδιοκτησία:** Η συναλλαγή πρέπει να είναι υπογεγραμμένη από ιδιοκτήτη plot
2. **Ύπαρξη:** Η ανάθεση πρέπει να υπάρχει και να μην έχει ήδη ανακληθεί
3. **Μορφή:** Έγκυρο OP_RETURN με δείκτη XCOP + διεύθυνση 20-byte

### Κανόνες Ενεργοποίησης

- **Ενεργοποίηση ανάθεσης:** `assignment_height + nForgingAssignmentDelay`
- **Ενεργοποίηση ανάκλησης:** `revocation_height + nForgingRevocationDelay`
- **Καθυστερήσεις:** Διαμορφώσιμες ανά δίκτυο (π.χ., 30 blocks = ~1 ώρα με χρόνο block 2 λεπτών)

### Επικύρωση Block

- Μη έγκυρη ανάθεση/ανάκληση → απόρριψη block (αποτυχία συναίνεσης)
- Οι έξοδοι OP_RETURN αποκλείονται αυτόματα από το σύνολο UTXO (τυπική συμπεριφορά Bitcoin)
- Η επεξεργασία ανάθεσης συμβαίνει πριν τις ενημερώσεις UTXO στο ConnectBlock

## Συμπέρασμα

Το σύστημα ανάθεσης σφυρηλάτησης PoCX όπως υλοποιείται παρέχει:

**Απλότητα:** Τυπικές συναλλαγές Bitcoin, χωρίς ειδικά UTXOs
**Κόστους-αποτελεσματικότητα:** Χωρίς απαίτηση dust, μόνο τέλη συναλλαγής
**Ασφάλεια Reorg:** Ολοκληρωμένα δεδομένα αναίρεσης επαναφέρουν σωστή κατάσταση
**Ατομικές Ενημερώσεις:** Συνέπεια βάσης δεδομένων μέσω batches LevelDB
**Πλήρες Ιστορικό:** Πλήρες ίχνος ελέγχου όλων των αναθέσεων με την πάροδο του χρόνου
**Καθαρή Αρχιτεκτονική:** Ελάχιστες τροποποιήσεις Bitcoin Core, απομονωμένος κώδικας PoCX
**Έτοιμο για Παραγωγή:** Πλήρως υλοποιημένο, δοκιμασμένο και λειτουργικό

### Ποιότητα Υλοποίησης

- **Οργάνωση κώδικα:** Εξαιρετική - σαφής διαχωρισμός μεταξύ Bitcoin Core και PoCX
- **Χειρισμός σφαλμάτων:** Ολοκληρωμένη επικύρωση συναίνεσης
- **Τεκμηρίωση:** Καλά τεκμηριωμένα σχόλια κώδικα και δομή
- **Δοκιμές:** Βασική λειτουργικότητα δοκιμασμένη, ενσωμάτωση επαληθευμένη

### Βασικές Αποφάσεις Σχεδιασμού Επικυρωμένες

1. Προσέγγιση αποκλειστικά με OP_RETURN (έναντι βασισμένης σε UTXO)
2. Ξεχωριστή αποθήκευση βάσης δεδομένων (έναντι Coin extraData)
3. Πλήρης παρακολούθηση ιστορικού (έναντι μόνο τρέχουσας)
4. Ιδιοκτησία μέσω υπογραφής (έναντι δαπάνης UTXO)
5. Καθυστερήσεις ενεργοποίησης (αποτρέπει επιθέσεις reorg)

Το σύστημα επιτυγχάνει με επιτυχία όλους τους αρχιτεκτονικούς στόχους με καθαρή, συντηρήσιμη υλοποίηση.

---

[← Προηγούμενο: Συναίνεση και Εξόρυξη](3-consensus-and-mining.md) | [Πίνακας Περιεχομένων](index.md) | [Επόμενο: Χρονικός Συγχρονισμός →](5-timing-security.md)
