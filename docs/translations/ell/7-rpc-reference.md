[← Προηγούμενο: Παράμετροι Δικτύου](6-network-parameters.md) | [Πίνακας Περιεχομένων](index.md) | [Επόμενο: Οδηγός Πορτοφολιού →](8-wallet-guide.md)

---

# Κεφάλαιο 7: Αναφορά Διεπαφής RPC

Πλήρης αναφορά για εντολές RPC Bitcoin-PoCX, συμπεριλαμβανομένων των RPCs εξόρυξης, διαχείρισης αναθέσεων και τροποποιημένων RPCs blockchain.

---

## Πίνακας Περιεχομένων

1. [Διαμόρφωση](#διαμόρφωση)
2. [RPCs Εξόρυξης PoCX](#rpcs-εξόρυξης-pocx)
3. [RPCs Αναθέσεων](#rpcs-αναθέσεων)
4. [Τροποποιημένα RPCs Blockchain](#τροποποιημένα-rpcs-blockchain)
5. [Απενεργοποιημένα RPCs](#απενεργοποιημένα-rpcs)
6. [Παραδείγματα Ενσωμάτωσης](#παραδείγματα-ενσωμάτωσης)

---

## Διαμόρφωση

### Λειτουργία Διακομιστή Εξόρυξης

**Σημαία**: ``

**Σκοπός**: Ενεργοποιεί πρόσβαση RPC για εξωτερικούς εξορύκτες να καλούν RPCs ειδικά για εξόρυξη

**Απαιτήσεις**:
- Απαιτείται για να λειτουργήσει το `submit_nonce`
- Απαιτείται για ορατότητα του διαλόγου ανάθεσης σφυρηλάτησης στο πορτοφόλι Qt

**Χρήση**:
```bash
# Γραμμή εντολών
./bitcoind

# bitcoin.conf
```

**Θεωρήσεις Ασφάλειας**:
- Χωρίς επιπλέον πιστοποίηση πέραν των τυπικών διαπιστευτηρίων RPC
- Τα RPCs εξόρυξης περιορίζονται από τη χωρητικότητα ουράς
- Απαιτείται ακόμα τυπική πιστοποίηση RPC

**Υλοποίηση**: `src/pocx/rpc/mining.cpp`

---

## RPCs Εξόρυξης PoCX

### get_mining_info

**Κατηγορία**: mining
**Απαιτεί Διακομιστή Εξόρυξης**: Όχι
**Απαιτεί Πορτοφόλι**: Όχι

**Σκοπός**: Επιστρέφει τρέχουσες παραμέτρους εξόρυξης που χρειάζονται οι εξωτερικοί εξορύκτες για να σαρώσουν αρχεία plot και να υπολογίσουν deadlines.

**Παράμετροι**: Καμία

**Τιμές Επιστροφής**:
```json
{
  "generation_signature": "abc123...",       // hex, 64 χαρακτήρες
  "base_target": 36650387592,                // αριθμητικό
  "height": 12345,                           // αριθμητικό, ύψος επόμενου block
  "block_hash": "def456...",                 // hex, προηγούμενο block
  "target_quality": 18446744073709551615,    // uint64_max (όλες οι λύσεις γίνονται αποδεκτές)
  "minimum_compression_level": 1,            // αριθμητικό
  "target_compression_level": 2              // αριθμητικό
}
```

**Περιγραφές Πεδίων**:
- `generation_signature`: Ντετερμινιστική εντροπία εξόρυξης για αυτό το ύψος block
- `base_target`: Τρέχουσα δυσκολία (υψηλότερη = ευκολότερη)
- `height`: Ύψος block που πρέπει να στοχεύσουν οι εξορύκτες
- `block_hash`: Hash προηγούμενου block (ενημερωτικό)
- `target_quality`: Κατώφλι ποιότητας (αυτή τη στιγμή uint64_max, χωρίς φιλτράρισμα)
- `minimum_compression_level`: Ελάχιστη συμπίεση που απαιτείται για επικύρωση
- `target_compression_level`: Συνιστώμενη συμπίεση για βέλτιστη εξόρυξη

**Κωδικοί Σφάλματος**:
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Ο κόμβος ακόμα συγχρονίζεται

**Παράδειγμα**:
```bash
bitcoin-cli get_mining_info
```

**Υλοποίηση**: `src/pocx/rpc/mining.cpp:get_mining_info()`

---

### submit_nonce

**Κατηγορία**: mining
**Απαιτεί Διακομιστή Εξόρυξης**: Ναι
**Απαιτεί Πορτοφόλι**: Ναι (για ιδιωτικά κλειδιά)

**Σκοπός**: Υποβάλλει λύση εξόρυξης PoCX. Επικυρώνει την απόδειξη, προσθέτει σε ουρά για time-bended σφυρηλάτηση και δημιουργεί αυτόματα block την προγραμματισμένη ώρα.

**Parameters**:
1. `block_hash` (string hex, required) - Previous block hash
2. `height` (numeric, required) - Block height
3. `generation_signature` (string hex, required) - Generation signature (64 characters)
4. `base_target` (numeric, required) - Base target for this block
5. `account_id` (string, required) - Account ID (ακριβώς 40 χαρακτήρες hex = 20 bytes· διεύθυνση δεν γίνεται δεκτή)
6. `seed` (string, required) - Plot seed (64 hex characters = 32 bytes)
7. `nonce` (numeric, required) - Mining nonce
8. `compression` (numeric, required) - Compression level used (1-6)
9. `raw_quality` (numeric, required) - Raw quality from proof validation

**Τιμές Επιστροφής** (επιτυχία):
```json
{
  "raw_quality": 120,       // ακατέργαστη ποιότητα από επικύρωση απόδειξης
  "poc_time": 45            // time-bended χρόνος σφυρηλάτησης σε δευτερόλεπτα
}
```

Δεν υπάρχει πεδίο `accepted`. Σε περίπτωση απόρριψης, το RPC **δεν** επιστρέφει αντικείμενο JSON — ρίχνει ένα `JSONRPCError` (δείτε Κωδικούς Σφάλματος παρακάτω).

**Βήματα Επικύρωσης**:
1. **Επικύρωση Μορφής** (fail-fast):
   - Account ID: ακριβώς 40 χαρακτήρες hex
   - Seed: ακριβώς 64 χαρακτήρες hex
2. **Επικύρωση Context**:
   - Το ύψος πρέπει να ταιριάζει με τρέχον tip + 1
   - Η generation signature πρέπει να ταιριάζει με την τρέχουσα
3. **Επαλήθευση Πορτοφολιού**:
   - Προσδιορισμός effective signer (έλεγχος για ενεργές αναθέσεις)
   - Επαλήθευση ότι το πορτοφόλι έχει ιδιωτικό κλειδί για effective signer
4. **Επικύρωση Απόδειξης** (ακριβή):
   - Επικύρωση απόδειξης PoCX με όρια συμπίεσης
   - Υπολογισμός ακατέργαστης ποιότητας
5. **Υποβολή Σχεδιαστή**:
   - Προσθήκη nonce σε ουρά για time-bended σφυρηλάτηση
   - Το block θα δημιουργηθεί αυτόματα στο forge_time

**Κωδικοί Σφάλματος** (ρίχνονται ως `JSONRPCError`):
- `RPC_INVALID_PARAMETER`: Μη έγκυρη μορφή (account_id, seed) ή αναντιστοιχία ύψους (`"Invalid height: expected X, got Y"`)
- `RPC_VERIFY_REJECTED`: Αναντιστοιχία generation signature ή αποτυχία επικύρωσης απόδειξης
- `RPC_INVALID_ADDRESS_OR_KEY`: Δεν υπάρχει ιδιωτικό κλειδί για effective signer
- `RPC_WALLET_UNLOCK_NEEDED`: Το πορτοφόλι που κρατά το κλειδί του effective signer είναι κλειδωμένο (ξεκλειδώστε με `walletpassphrase`)
- `RPC_CLIENT_IN_INITIAL_DOWNLOAD`: Η ουρά υποβολής είναι γεμάτη
- `RPC_INTERNAL_ERROR`: Αποτυχία αρχικοποίησης σχεδιαστή PoCX

**Κωδικοί Σφάλματος Επικύρωσης Απόδειξης**:
- `0`: VALIDATION_SUCCESS
- `-1`: VALIDATION_ERROR_NULL_POINTER
- `-2`: VALIDATION_ERROR_INVALID_INPUT
- `-100`: VALIDATION_ERROR_GENERATION_SIGNATURE_PARSE
- `-101`: VALIDATION_ERROR_GENERATION_SIGNATURE_DECODE
- `-106`: VALIDATION_ERROR_QUALITY_CALCULATION

**Παράδειγμα**:
```bash
bitcoin-cli submit_nonce \
  "blockhash..." \
  12345 \
  "gensig..." \
  18325193796 \
  "1234567890abcdef1234567890abcdef12345678" \
  "seed..." \
  999888777 \
  1 \
  123456789
```

**Σημειώσεις**:
- Η υποβολή είναι ασύγχρονη - το RPC επιστρέφει αμέσως, το block σφυρηλατείται αργότερα
- Το Time Bending καθυστερεί τις καλές λύσεις για να επιτρέψει σάρωση plot σε όλο το δίκτυο
- Σύστημα αναθέσεων: αν το plot έχει ανατεθεί, το πορτοφόλι πρέπει να έχει κλειδί διεύθυνσης σφυρηλάτησης
- Τα όρια συμπίεσης προσαρμόζονται δυναμικά βάσει ύψους block

**Υλοποίηση**: `src/pocx/rpc/mining.cpp:submit_nonce()`

---

## RPCs Αναθέσεων

### get_assignment

**Κατηγορία**: mining
**Απαιτεί Διακομιστή Εξόρυξης**: Όχι
**Απαιτεί Πορτοφόλι**: Όχι

**Σκοπός**: Ερωτά την κατάσταση ανάθεσης σφυρηλάτησης για μια διεύθυνση plot. Μόνο ανάγνωση, δεν απαιτείται πορτοφόλι.

**Παράμετροι**:
1. `plot_address` (string, υποχρεωτικό) - Διεύθυνση plot (μορφή bech32 P2WPKH)
2. `height` (αριθμητικό, προαιρετικό) - Ύψος block για ερώτημα (προεπιλογή: τρέχον tip)

**Τιμές Επιστροφής** (χωρίς ανάθεση):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": false,
  "state": "UNASSIGNED"
}
```

**Τιμές Επιστροφής** (ενεργή ανάθεση):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "ASSIGNED",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030
}
```

**Τιμές Επιστροφής** (ανάκληση σε εξέλιξη):
```json
{
  "plot_address": "pocx1qplot...",
  "height": 12345,
  "has_assignment": true,
  "state": "REVOKING",
  "forging_address": "pocx1qforger...",
  "assignment_txid": "abc123...",
  "assignment_height": 12000,
  "activation_height": 12030,
  "revoked": true,
  "revocation_txid": "def456...",
  "revocation_height": 12300,
  "revocation_effective_height": 13020
}
```

**Καταστάσεις Ανάθεσης**:
- `UNASSIGNED`: Δεν υπάρχει ανάθεση
- `ASSIGNING`: Επιβεβαιώθηκε tx ανάθεσης, καθυστέρηση ενεργοποίησης σε εξέλιξη
- `ASSIGNED`: Ανάθεση ενεργή, δικαιώματα σφυρηλάτησης ανατεθειμένα
- `REVOKING`: Επιβεβαιώθηκε tx ανάκλησης, ακόμα ενεργή μέχρι να παρέλθει η καθυστέρηση
- `REVOKED`: Ανάκληση ολοκληρώθηκε, δικαιώματα σφυρηλάτησης επιστράφηκαν στον ιδιοκτήτη plot

**Κωδικοί Σφάλματος**:
- `RPC_INVALID_ADDRESS_OR_KEY`: Μη έγκυρη διεύθυνση ή όχι P2WPKH (bech32)

**Παράδειγμα**:
```bash
bitcoin-cli get_assignment "pocx1qplot..."
bitcoin-cli get_assignment "pocx1qplot..." 800000
```

**Υλοποίηση**: `src/pocx/rpc/assignments.cpp:get_assignment()`

---

### create_assignment

**Κατηγορία**: wallet
**Απαιτεί Διακομιστή Εξόρυξης**: Όχι
**Απαιτεί Πορτοφόλι**: Ναι (πρέπει να είναι φορτωμένο και ξεκλείδωτο)

**Σκοπός**: Δημιουργεί συναλλαγή ανάθεσης σφυρηλάτησης για ανάθεση δικαιωμάτων σφυρηλάτησης σε άλλη διεύθυνση (π.χ., pool εξόρυξης).

**Παράμετροι**:
1. `plot_address` (string, υποχρεωτικό) - Διεύθυνση ιδιοκτήτη plot (πρέπει να κατέχει ιδιωτικό κλειδί, P2WPKH bech32)
2. `forging_address` (string, υποχρεωτικό) - Διεύθυνση για ανάθεση δικαιωμάτων σφυρηλάτησης (P2WPKH bech32)
3. `fee_rate` (αριθμητικό, προαιρετικό) - Ποσοστό τέλους σε BTCX/kvB (προεπιλογή: `0` → η τυπική εκτίμηση ελάχιστου τέλους του πορτοφολιού· η προεπιλογή 10× minRelayFee ισχύει μόνο για τον διάλογο Qt GUI, όχι για αυτό το RPC)

**Τιμές Επιστροφής**:
```json
{
  "txid": "abc123...",
  "hex": "020000...",
  "plot_address": "pocx1qplot...",
  "forging_address": "pocx1qforger..."
}
```

**Απαιτήσεις**:
- Πορτοφόλι φορτωμένο και ξεκλείδωτο
- Ιδιωτικό κλειδί για plot_address στο πορτοφόλι
- Και οι δύο διευθύνσεις πρέπει να είναι P2WPKH (μορφή bech32: pocx1q... mainnet, tpocx1q... testnet)
- Η διεύθυνση plot πρέπει να έχει επιβεβαιωμένα UTXOs (αποδεικνύει ιδιοκτησία)
- Το plot δεν πρέπει να έχει ενεργή ανάθεση (χρησιμοποιήστε πρώτα revoke)

**Δομή Συναλλαγής**:
- Είσοδος: UTXO από διεύθυνση plot (αποδεικνύει ιδιοκτησία)
- Έξοδος: OP_RETURN script (46 bytes) = opcode `OP_RETURN` + 1 byte μήκος push + 44 bytes ωφέλιμο φορτίο δεδομένων (δείκτης `POCX` 4 + plot_address 20 + forging_address 20)
- Έξοδος: Ρέστα επιστρέφονται στο πορτοφόλι

**Ενεργοποίηση**:
- Η ανάθεση γίνεται ASSIGNING κατά την επιβεβαίωση
- Γίνεται ACTIVE μετά από `nForgingAssignmentDelay` blocks
- Η καθυστέρηση αποτρέπει γρήγορη επανανάθεση κατά τη διάρκεια forks αλυσίδας

**Κωδικοί Σφάλματος**:
- `RPC_WALLET_NOT_FOUND`: Δεν υπάρχει διαθέσιμο πορτοφόλι
- `RPC_WALLET_UNLOCK_NEEDED`: Το πορτοφόλι είναι κρυπτογραφημένο και κλειδωμένο
- `RPC_WALLET_ERROR`: Αποτυχία δημιουργίας συναλλαγής
- `RPC_INVALID_ADDRESS_OR_KEY`: Μη έγκυρη μορφή διεύθυνσης

**Παράδειγμα**:
```bash
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..."
bitcoin-cli create_assignment "pocx1qplot..." "pocx1qforger..." 0.0001
```

**Υλοποίηση**: `src/pocx/rpc/assignments_wallet.cpp:create_assignment()`

---

### revoke_assignment

**Κατηγορία**: wallet
**Απαιτεί Διακομιστή Εξόρυξης**: Όχι
**Απαιτεί Πορτοφόλι**: Ναι (πρέπει να είναι φορτωμένο και ξεκλείδωτο)

**Σκοπός**: Ανακαλεί υπάρχουσα ανάθεση σφυρηλάτησης, επιστρέφοντας τα δικαιώματα σφυρηλάτησης στον ιδιοκτήτη plot.

**Παράμετροι**:
1. `plot_address` (string, υποχρεωτικό) - Διεύθυνση plot (πρέπει να κατέχει ιδιωτικό κλειδί, P2WPKH bech32)
2. `fee_rate` (αριθμητικό, προαιρετικό) - Ποσοστό τέλους σε BTCX/kvB (προεπιλογή: `0` → η τυπική εκτίμηση ελάχιστου τέλους του πορτοφολιού· η προεπιλογή 10× minRelayFee ισχύει μόνο για τον διάλογο Qt GUI, όχι για αυτό το RPC)

**Τιμές Επιστροφής**:
```json
{
  "txid": "def456...",
  "hex": "020000...",
  "plot_address": "pocx1qplot..."
}
```

**Απαιτήσεις**:
- Πορτοφόλι φορτωμένο και ξεκλείδωτο
- Ιδιωτικό κλειδί για plot_address στο πορτοφόλι
- Η διεύθυνση plot πρέπει να είναι P2WPKH (μορφή bech32)
- Η διεύθυνση plot πρέπει να έχει επιβεβαιωμένα UTXOs

**Δομή Συναλλαγής**:
- Είσοδος: UTXO από διεύθυνση plot (αποδεικνύει ιδιοκτησία)
- Έξοδος: OP_RETURN script (26 bytes) = opcode `OP_RETURN` + 1 byte μήκος push + 24 bytes ωφέλιμο φορτίο δεδομένων (δείκτης `XCOP` 4 + plot_address 20)
- Έξοδος: Ρέστα επιστρέφονται στο πορτοφόλι

**Αποτέλεσμα**:
- Η κατάσταση μεταβαίνει σε REVOKING αμέσως
- Η διεύθυνση σφυρηλάτησης μπορεί ακόμα να σφυρηλατεί κατά τη διάρκεια της περιόδου καθυστέρησης
- Γίνεται REVOKED μετά από `nForgingRevocationDelay` blocks
- Ο ιδιοκτήτης plot μπορεί να σφυρηλατήσει μετά την ισχύ της ανάκλησης
- Μπορεί να δημιουργήσει νέα ανάθεση μετά την ολοκλήρωση της ανάκλησης

**Κωδικοί Σφάλματος**:
- `RPC_WALLET_NOT_FOUND`: Δεν υπάρχει διαθέσιμο πορτοφόλι
- `RPC_WALLET_UNLOCK_NEEDED`: Το πορτοφόλι είναι κρυπτογραφημένο και κλειδωμένο
- `RPC_WALLET_ERROR`: Αποτυχία δημιουργίας συναλλαγής

**Παράδειγμα**:
```bash
bitcoin-cli revoke_assignment "pocx1qplot..."
bitcoin-cli revoke_assignment "pocx1qplot..." 0.0001
```

**Σημειώσεις**:
- Idempotent: μπορεί να ανακαλέσει ακόμα και αν δεν υπάρχει ενεργή ανάθεση
- Δεν μπορεί να ακυρώσει ανάκληση μόλις υποβληθεί

**Υλοποίηση**: `src/pocx/rpc/assignments_wallet.cpp:revoke_assignment()`

---

## Τροποποιημένα RPCs Blockchain

### getdifficulty

**Τροποποιήσεις PoCX**:
- **Υπολογισμός**: `reference_base_target / current_base_target`
- **Αναφορά**: Χωρητικότητα δικτύου 1 TiB (base_target = 36650387592)
- **Ερμηνεία**: Εκτιμώμενη χωρητικότητα αποθήκευσης δικτύου σε TiB
  - Παράδειγμα: `1.0` = ~1 TiB
  - Παράδειγμα: `1024.0` = ~1 PiB
- **Διαφορά από PoW**: Αντιπροσωπεύει χωρητικότητα, όχι ισχύ hash

**Παράδειγμα**:
```bash
bitcoin-cli getdifficulty
# Επιστρέφει: 2048.5 (δίκτυο ~2 PiB)
```

**Υλοποίηση**: `src/rpc/blockchain.cpp`

---

### getblockheader

**Προστιθέμενα Πεδία PoCX**:
- `time_since_last_block` (αριθμητικό) - Δευτερόλεπτα από το προηγούμενο block (αντικαθιστά mediantime)
- `poc_time` (αριθμητικό) - Time-bended χρόνος σφυρηλάτησης σε δευτερόλεπτα
- `base_target` (αριθμητικό) - Base target δυσκολίας PoCX
- `generation_signature` (string hex) - Generation signature
- `pocx_proof` (αντικείμενο):
  - `account_id` (string hex) - ID λογαριασμού plot (20 bytes)
  - `seed` (string hex) - Seed plot (32 bytes)
  - `nonce` (αριθμητικό) - Nonce εξόρυξης
  - `compression` (αριθμητικό) - Επίπεδο κλιμάκωσης που χρησιμοποιήθηκε
  - `quality` (αριθμητικό) - Δηλωμένη τιμή ποιότητας
- `pubkey` (string hex) - Δημόσιο κλειδί υπογράφοντα block (33 bytes)
- `signer_address` (string) - Διεύθυνση υπογράφοντα block
- `signature` (string hex) - Υπογραφή block (65 bytes)

**Αφαιρεθέντα Πεδία PoCX**:
- `mediantime` - Αφαιρέθηκε (αντικαταστάθηκε από time_since_last_block)

**Παράδειγμα**:
```bash
bitcoin-cli getblockheader <blockhash>
```

**Υλοποίηση**: `src/rpc/blockchain.cpp`

---

### getblock

**Τροποποιήσεις PoCX**: Ίδιες με getblockheader, συν πλήρη δεδομένα συναλλαγών

**Παράδειγμα**:
```bash
bitcoin-cli getblock <blockhash>
bitcoin-cli getblock <blockhash> 2  # verbose με λεπτομέρειες tx
```

**Υλοποίηση**: `src/rpc/blockchain.cpp`

---

### getblockchaininfo

**Προστιθέμενα Πεδία PoCX**:
- `base_target` (αριθμητικό) - Τρέχον base target
- `generation_signature` (string hex) - Τρέχουσα generation signature

**Τροποποιημένα Πεδία PoCX**:
- `difficulty` - Χρησιμοποιεί υπολογισμό PoCX (βάσει χωρητικότητας)

**Αφαιρεθέντα Πεδία PoCX**:
- `mediantime` - Αφαιρέθηκε

**Παράδειγμα**:
```bash
bitcoin-cli getblockchaininfo
```

**Υλοποίηση**: `src/rpc/blockchain.cpp`

---

### getblocktemplate

**Προστιθέμενα Πεδία PoCX**:
- `generation_signature` (string hex) - Για εξόρυξη pool
- `base_target` (αριθμητικό) - Για εξόρυξη pool

**Αφαιρεθέντα Πεδία PoCX**:
- `target` - Αφαιρέθηκε (ειδικό για PoW)
- `noncerange` - Αφαιρέθηκε (ειδικό για PoW)
- `bits` - Αφαιρέθηκε (ειδικό για PoW)

**Σημειώσεις**:
- Περιλαμβάνει ακόμα πλήρη δεδομένα συναλλαγών για κατασκευή block
- Χρησιμοποιείται από διακομιστές pool για συντονισμένη εξόρυξη

**Παράδειγμα**:
```bash
bitcoin-cli getblocktemplate '{"rules": ["segwit"]}'
```

**Υλοποίηση**: `src/rpc/mining.cpp`

---

## Απενεργοποιημένα RPCs

Τα παρακάτω RPCs ειδικά για PoW είναι **απενεργοποιημένα** σε λειτουργία PoCX:

### getnetworkhashps
- **Λόγος**: Το hash rate δεν εφαρμόζεται στο Proof of Capacity
- **Εναλλακτική**: Χρησιμοποιήστε `getdifficulty` για εκτίμηση χωρητικότητας δικτύου

### getmininginfo
- **Λόγος**: Επιστρέφει πληροφορίες ειδικές για PoW
- **Εναλλακτική**: Χρησιμοποιήστε `get_mining_info` (ειδικό για PoCX)

### generate, generatetoaddress, generatetodescriptor, generateblock
- **Status**: Available as hidden commands (functional in regtest for testing)
- **Note**: In regtest PoCX mode, these commands scan for valid PoCX proofs on-the-fly
- **Production**: Use external plotter + miner + `submit_nonce`

**Implementation**: `src/rpc/mining.cpp`

---

## Παραδείγματα Ενσωμάτωσης

### Ενσωμάτωση Εξωτερικού Εξορύκτη

**Βασικός Βρόχος Εξόρυξης**:
```python
import requests
import time

RPC_URL = "http://user:pass@localhost:8332"

def rpc_call(method, params=[]):
    payload = {
        "jsonrpc": "2.0",
        "id": "miner",
        "method": method,
        "params": params
    }
    response = requests.post(RPC_URL, json=payload)
    return response.json()["result"]

# Βρόχος εξόρυξης
while True:
    # 1. Λήψη παραμέτρων εξόρυξης
    info = rpc_call("get_mining_info")

    gen_sig = info["generation_signature"]
    base_target = info["base_target"]
    height = info["height"]
    compression_bounds.nPoCXMinCompression = info["minimum_compression_level"]
    target_compression = info["target_compression_level"]

    # 2. Σάρωση αρχείων plot (εξωτερική υλοποίηση)
    best_nonce = scan_plots(gen_sig, height)

    # 3. Υποβολή καλύτερης λύσης (ρίχνει JSONRPCError σε απόρριψη)
    try:
        result = rpc_call("submit_nonce", [
            info["block_hash"],
            height,
            gen_sig,
            base_target,
            best_nonce["account_id"],
            best_nonce["seed"],
            best_nonce["nonce"],
            best_nonce["compression"],
            best_nonce["raw_quality"]
        ])
        print(f"Λύση έγινε αποδεκτή! Ποιότητα: {result['raw_quality']}, "
              f"Χρόνος σφυρηλάτησης: {result['poc_time']}s")
    except JSONRPCError as e:
        print(f"Απορρίφθηκε: {e}")

    # 4. Αναμονή για επόμενο block
    time.sleep(10)  # Διάστημα ερωτήματος
```

---

### Μοτίβο Ενσωμάτωσης Pool

**Ροή Εργασίας Διακομιστή Pool**:
1. Οι εξορύκτες δημιουργούν αναθέσεις σφυρηλάτησης στη διεύθυνση pool
2. Το pool τρέχει πορτοφόλι με κλειδιά διεύθυνσης σφυρηλάτησης
3. Το pool καλεί `get_mining_info` και διανέμει στους εξορύκτες
4. Οι εξορύκτες υποβάλλουν λύσεις μέσω pool (όχι απευθείας στην αλυσίδα)
5. Το pool επικυρώνει και καλεί `submit_nonce` με τα κλειδιά του pool
6. Το pool διανέμει ανταμοιβές σύμφωνα με την πολιτική pool

**Διαχείριση Αναθέσεων**:
```bash
# Ο εξορύκτης δημιουργεί ανάθεση (από το πορτοφόλι του εξορύκτη)
bitcoin-cli create_assignment "pocx1qminer_plot..." "pocx1qpool..."

# Αναμονή για ενεργοποίηση (30 blocks mainnet)

# Το pool ελέγχει την κατάσταση ανάθεσης
bitcoin-cli get_assignment "pocx1qminer_plot..."

# Το pool μπορεί τώρα να υποβάλει nonces για αυτό το plot
# (το πορτοφόλι pool πρέπει να έχει ιδιωτικό κλειδί pocx1qpool...)
```

---

### Ερωτήματα Block Explorer

**Ερώτημα Δεδομένων Block PoCX**:
```bash
# Λήψη τελευταίου block
BLOCK_HASH=$(bitcoin-cli getbestblockhash)

# Λήψη λεπτομερειών block με απόδειξη PoCX
BLOCK=$(bitcoin-cli getblock $BLOCK_HASH 2)

# Εξαγωγή πεδίων ειδικών για PoCX
echo $BLOCK | jq '{
  height: .height,
  time_since_last: .time_since_last_block,
  poc_time: .poc_time,
  base_target: .base_target,
  generation_signature: .generation_signature,
  pocx_proof: .pocx_proof,
  miner_address: .tx[0].vout[0].scriptPubKey.address
}'
```

**Ανίχνευση Συναλλαγών Ανάθεσης**:
```bash
# Σάρωση συναλλαγής για OP_RETURN
TX=$(bitcoin-cli getrawtransaction <txid> 1)

# Έλεγχος για δείκτη ανάθεσης (POCX = 0x504f4358)
echo $TX | jq '.vout[] | select(.scriptPubKey.asm | startswith("OP_RETURN 504f4358"))'
```

---

## Χειρισμός Σφαλμάτων

### Κοινά Μοτίβα Σφαλμάτων

**Αναντιστοιχία Ύψους** (ρίχνεται `RPC_INVALID_PARAMETER`, κωδικός -8):
```json
{
  "code": -8,
  "message": "Invalid height: expected 12346, got 12345"
}
```
**Λύση**: Επαναλήψτε λήψη πληροφοριών εξόρυξης, η αλυσίδα προχώρησε

**Αναντιστοιχία Generation Signature** (ρίχνεται `RPC_VERIFY_REJECTED`, κωδικός -26):
```json
{
  "code": -26,
  "message": "Generation signature mismatch"
}
```
**Λύση**: Επαναλήψτε λήψη πληροφοριών εξόρυξης, έφτασε νέο block

**Δεν Υπάρχει Ιδιωτικό Κλειδί**:
```json
{
  "code": -5,
  "message": "Δεν υπάρχει διαθέσιμο ιδιωτικό κλειδί για effective signer"
}
```
**Λύση**: Εισαγάγετε κλειδί για διεύθυνση plot ή σφυρηλάτησης

**Ενεργοποίηση Ανάθεσης σε Εκκρεμότητα**:
```json
{
  "plot_address": "pocx1qplot...",
  "state": "ASSIGNING",
  "activation_height": 12030
}
```
**Λύση**: Περιμένετε να παρέλθει η καθυστέρηση ενεργοποίησης

---

## Αναφορές Κώδικα

**RPCs Εξόρυξης**: `src/pocx/rpc/mining.cpp`
**RPCs Αναθέσεων**: `src/pocx/rpc/assignments.cpp`, `src/pocx/rpc/assignments_wallet.cpp`
**RPCs Blockchain**: `src/rpc/blockchain.cpp`
**Επικύρωση Απόδειξης**: `src/pocx/consensus/proof.cpp`, `src/pocx/consensus/signature.cpp`
**Κατάσταση Ανάθεσης**: `src/pocx/assignments/assignment_state.cpp`
**Δημιουργία Συναλλαγής**: `src/pocx/assignments/transactions.cpp`

---

## Διασταυρούμενες Αναφορές

Σχετικά κεφάλαια:
- [Κεφάλαιο 3: Συναίνεση και Εξόρυξη](3-consensus-and-mining.md) - Λεπτομέρειες διαδικασίας εξόρυξης
- [Κεφάλαιο 4: Αναθέσεις Σφυρηλάτησης](4-forging-assignments.md) - Αρχιτεκτονική συστήματος αναθέσεων
- [Κεφάλαιο 6: Παράμετροι Δικτύου](6-network-parameters.md) - Τιμές καθυστέρησης ανάθεσης
- [Κεφάλαιο 8: Οδηγός Πορτοφολιού](8-wallet-guide.md) - GUI για διαχείριση αναθέσεων

---

[← Προηγούμενο: Παράμετροι Δικτύου](6-network-parameters.md) | [Πίνακας Περιεχομένων](index.md) | [Επόμενο: Οδηγός Πορτοφολιού →](8-wallet-guide.md)
