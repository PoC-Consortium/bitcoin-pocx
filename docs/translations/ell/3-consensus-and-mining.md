[← Προηγούμενο: Μορφή Plot](2-plot-format.md) | [Πίνακας Περιεχομένων](index.md) | [Επόμενο: Αναθέσεις Σφυρηλάτησης →](4-forging-assignments.md)

---

# Κεφάλαιο 3: Διαδικασία Συναίνεσης και Εξόρυξης Bitcoin-PoCX

Πλήρης τεχνική προδιαγραφή του μηχανισμού συναίνεσης PoCX (Proof of Capacity neXt generation) και της διαδικασίας εξόρυξης ενσωματωμένης στο Bitcoin Core.

---

## Πίνακας Περιεχομένων

1. [Επισκόπηση](#επισκόπηση)
2. [Αρχιτεκτονική Συναίνεσης](#αρχιτεκτονική-συναίνεσης)
3. [Διαδικασία Εξόρυξης](#διαδικασία-εξόρυξης)
4. [Επικύρωση Block](#επικύρωση-block)
5. [Σύστημα Αναθέσεων](#σύστημα-αναθέσεων)
6. [Διάδοση Δικτύου](#διάδοση-δικτύου)
7. [Τεχνικές Λεπτομέρειες](#τεχνικές-λεπτομέρειες)

---

## Επισκόπηση

Το Bitcoin-PoCX υλοποιεί έναν καθαρό μηχανισμό συναίνεσης Proof of Capacity ως πλήρη αντικατάσταση του Proof of Work του Bitcoin. Αυτή είναι μια νέα αλυσίδα χωρίς απαιτήσεις συμβατότητας προς τα πίσω.

**Βασικές Ιδιότητες:**
- **Ενεργειακά Αποδοτική:** Η εξόρυξη χρησιμοποιεί προ-δημιουργημένα αρχεία plot αντί υπολογιστικού hashing
- **Time Bended Deadlines:** Μετασχηματισμός κατανομής (εκθετική→chi-squared) μειώνει τα μεγάλα blocks, βελτιώνει τους μέσους χρόνους block
- **Υποστήριξη Αναθέσεων:** Οι ιδιοκτήτες plot μπορούν να αναθέσουν δικαιώματα σφυρηλάτησης σε άλλες διευθύνσεις
- **Εγγενής Ενσωμάτωση C++:** Κρυπτογραφικοί αλγόριθμοι υλοποιημένοι σε C++ για επικύρωση συναίνεσης

**Ροή Εξόρυξης:**
```
Εξωτερικός Εξορύκτης → get_mining_info → Υπολογισμός Nonce → submit_nonce →
Ουρά Σφυρηλάτησης → Αναμονή Deadline → Σφυρηλάτηση Block → Διάδοση Δικτύου →
Επικύρωση Block → Επέκταση Αλυσίδας
```

---

## Αρχιτεκτονική Συναίνεσης

### Δομή Block

Τα blocks PoCX επεκτείνουν τη δομή block του Bitcoin με πρόσθετα πεδία συναίνεσης:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Seed plot (32 bytes)
    std::array<uint8_t, 20> account_id;       // Διεύθυνση plot (20-byte hash160)
    uint32_t compression;                     // Επίπεδο κλιμάκωσης (1-255)
    uint64_t nonce;                           // Nonce εξόρυξης (64-bit)
    uint64_t quality;                         // Δηλωμένη ποιότητα (έξοδος PoC hash)
};

class CBlockHeader {
    // Τυπικά πεδία Bitcoin
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // Πεδία συναίνεσης PoCX (αντικαθιστούν nBits και nNonce)
    int nHeight;                              // Ύψος block (επικύρωση χωρίς context)
    uint256 generationSignature;              // Generation signature (εντροπία εξόρυξης)
    uint64_t nBaseTarget;                     // Παράμετρος δυσκολίας (αντίστροφη δυσκολία)
    PoCXProof pocxProof;                      // Απόδειξη εξόρυξης

    // Πεδία υπογραφής block
    std::array<uint8_t, 33> vchPubKey;        // Συμπιεσμένο δημόσιο κλειδί (33 bytes)
    std::array<uint8_t, 65> vchSignature;     // Compact υπογραφή (65 bytes)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Συναλλαγές
};
```

**Σημείωση:** Η υπογραφή (`vchSignature`) εξαιρείται από τον υπολογισμό hash του block για αποτροπή ευπλαστότητας.

**Υλοποίηση:** `src/primitives/block.h`

### Generation Signature

Η generation signature δημιουργεί εντροπία εξόρυξης και αποτρέπει επιθέσεις προ-υπολογισμού.

**Υπολογισμός:**
```
generationSignature = SHA256(prev_generationSignature || prev_miner_pubkey)
```

**Genesis Block:** Χρησιμοποιεί μια σκληροκωδικοποιημένη αρχική generation signature

**Υλοποίηση:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Base Target (Δυσκολία)

Το base target είναι το αντίστροφο της δυσκολίας - υψηλότερες τιμές σημαίνουν ευκολότερη εξόρυξη.

**Αλγόριθμος Προσαρμογής:**
- Στόχος χρόνου block: 120 δευτερόλεπτα (mainnet), 1 δευτερόλεπτο (regtest)
- Διάστημα προσαρμογής: Κάθε block
- Χρησιμοποιεί κινητό μέσο όρο πρόσφατων base targets
- Περιορίζεται για αποτροπή ακραίων διακυμάνσεων δυσκολίας

**Υλοποίηση:** `src/consensus/params.h`, λογική προσαρμογής δυσκολίας στη δημιουργία block

### Επίπεδα Κλιμάκωσης

Το PoCX υποστηρίζει κλιμακούμενο proof-of-work σε αρχεία plot μέσω επιπέδων κλιμάκωσης (Xn).

**Δυναμικά Όρια:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Ελάχιστο αποδεκτό επίπεδο
    uint8_t nPoCXTargetCompression;  // Συνιστώμενο επίπεδο
};
```

**Πρόγραμμα Αύξησης Κλιμάκωσης:**
- Εκθετικά διαστήματα: Έτη 4, 12, 28, 60, 124 (halvings 1, 3, 7, 15, 31)
- Το ελάχιστο επίπεδο κλιμάκωσης αυξάνεται κατά 1
- Το επίπεδο στόχου κλιμάκωσης αυξάνεται κατά 1
- Διατηρεί περιθώριο ασφαλείας μεταξύ κόστους δημιουργίας plot και κόστους αναζήτησης
- Μέγιστο επίπεδο κλιμάκωσης: 255

**Υλοποίηση:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Διαδικασία Εξόρυξης

### 1. Ανάκτηση Πληροφοριών Εξόρυξης

**Εντολή RPC:** `get_mining_info`

**Διαδικασία:**
1. Κλήση `GetNewBlockContext(chainman)` για λήψη τρέχουσας κατάστασης blockchain
2. Υπολογισμός δυναμικών ορίων συμπίεσης για τρέχον ύψος
3. Επιστροφή παραμέτρων εξόρυξης

**Απάντηση:**
```json
{
  "generation_signature": "abc123...",
  "base_target": 18325193796,
  "height": 12345,
  "block_hash": "def456...",
  "target_quality": 18446744073709551615,
  "minimum_compression_level": 0,
  "target_compression_level": 0
}
```

**Υλοποίηση:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Σημειώσεις:**
- Δεν κρατούνται locks κατά τη δημιουργία απάντησης
- Η απόκτηση context χειρίζεται το `cs_main` εσωτερικά
- Το `block_hash` περιλαμβάνεται για αναφορά αλλά δεν χρησιμοποιείται στην επικύρωση

### 2. Εξωτερική Εξόρυξη

**Ευθύνες εξωτερικού εξορύκτη:**
1. Ανάγνωση αρχείων plot από δίσκο
2. Υπολογισμός scoop βάσει generation signature και ύψους
3. Εύρεση nonce με το καλύτερο deadline
4. Υποβολή στον κόμβο μέσω `submit_nonce`

**Μορφή Αρχείου Plot:**
- Βασισμένη στη μορφή POC2 (Burstcoin)
- Βελτιωμένη με διορθώσεις ασφαλείας και βελτιώσεις κλιμάκωσης
- Δείτε απόδοση στο `CLAUDE.md`

**Υλοποίηση Εξορύκτη:** Εξωτερική (π.χ., βασισμένη στο Scavenger)

### 3. Υποβολή και Επικύρωση Nonce

**Εντολή RPC:** `submit_nonce`

**Παράμετροι:**
```
height, generation_signature, account_id, seed, nonce, quality (προαιρετικά)
```

**Ροή Επικύρωσης (Βελτιστοποιημένη Σειρά):**

#### Βήμα 1: Γρήγορη Επικύρωση Μορφής
```cpp
// Account ID: 40 hex χαρακτήρες = 20 bytes
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 hex χαρακτήρες = 32 bytes
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Βήμα 2: Απόκτηση Context
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Επιστρέφει: height, generation_signature, base_target, block_hash
```

**Κλείδωμα:** Το `cs_main` χειρίζεται εσωτερικά, δεν κρατούνται locks στο RPC thread

#### Βήμα 3: Επικύρωση Context
```cpp
// Έλεγχος ύψους
if (height != context.height) reject;

// Έλεγχος generation signature
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Βήμα 4: Επαλήθευση Πορτοφολιού
```cpp
// Προσδιορισμός effective signer (λαμβάνοντας υπόψη αναθέσεις)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Έλεγχος αν ο κόμβος έχει ιδιωτικό κλειδί για effective signer
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Υποστήριξη Αναθέσεων:** Ο ιδιοκτήτης plot μπορεί να αναθέσει δικαιώματα σφυρηλάτησης σε άλλη διεύθυνση. Το πορτοφόλι πρέπει να έχει κλειδί για τον effective signer, όχι απαραίτητα τον ιδιοκτήτη plot.

#### Βήμα 5: Επικύρωση Απόδειξης
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 bytes
    block_height,
    nonce,
    seed,                // 32 bytes
    min_compression,
    max_compression,
    &result             // Έξοδος: quality, deadline
);
```

**Αλγόριθμος:**
1. Αποκωδικοποίηση generation signature από hex
2. Υπολογισμός καλύτερης ποιότητας στο εύρος συμπίεσης χρησιμοποιώντας αλγορίθμους βελτιστοποιημένους με SIMD
3. Επικύρωση ότι η ποιότητα πληροί τις απαιτήσεις δυσκολίας
4. Επιστροφή ακατέργαστης τιμής ποιότητας

**Υλοποίηση:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Βήμα 6: Υπολογισμός Time Bending
```cpp
// Ακατέργαστο deadline προσαρμοσμένο σε δυσκολία (δευτερόλεπτα)
uint64_t deadline_seconds = quality / base_target;

// Time Bended χρόνος σφυρηλάτησης (δευτερόλεπτα)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Τύπος Time Bending:**
```
Y = scale * (X^(1/3))
όπου:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Σκοπός:** Μετασχηματίζει εκθετική σε κατανομή chi-squared. Πολύ καλές λύσεις σφυρηλατούνται αργότερα (το δίκτυο έχει χρόνο να σαρώσει δίσκους), οι κακές λύσεις βελτιώνονται. Μειώνει τα μεγάλα blocks, διατηρεί μέσο όρο 120s.

**Υλοποίηση:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Βήμα 7: Υποβολή στον Σχεδιαστή
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // ΟΧΙ deadline - επανυπολογίζεται στον forger
    height,
    generation_signature
);
```

**Σχεδιασμός Βασισμένος σε Ουρά:**
- Η υποβολή πετυχαίνει πάντα (προστίθεται στην ουρά)
- Το RPC επιστρέφει αμέσως
- Το worker thread επεξεργάζεται ασύγχρονα

**Υλοποίηση:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Επεξεργασία Ουράς Σφυρηλάτησης

**Αρχιτεκτονική:**
- Μόνο ένα μόνιμο worker thread
- Ουρά υποβολής FIFO
- Κατάσταση σφυρηλάτησης χωρίς lock (μόνο worker thread)
- Χωρίς εμφωλευμένα locks (πρόληψη deadlock)

**Κύριος Βρόχος Worker Thread:**
```cpp
while (!shutdown) {
    // 1. Έλεγχος για υποβολές στην ουρά
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Αναμονή για deadline ή νέα υποβολή
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**Λογική ProcessSubmission:**
```cpp
1. Λήψη φρέσκου context: GetNewBlockContext(*chainman)

2. Έλεγχοι παλαιότητας (σιωπηλή απόρριψη):
   - Αναντιστοιχία ύψους → απόρριψη
   - Αναντιστοιχία generation signature → απόρριψη
   - Αλλαγή hash block tip (reorg) → επαναφορά κατάστασης σφυρηλάτησης

3. Σύγκριση ποιότητας:
   - Εάν quality >= current_best → απόρριψη

4. Υπολογισμός Time Bended deadline:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Ενημέρωση κατάστασης σφυρηλάτησης:
   - Ακύρωση υπάρχουσας σφυρηλάτησης (αν βρέθηκε καλύτερη)
   - Αποθήκευση: account_id, seed, nonce, quality, deadline
   - Υπολογισμός: forge_time = block_time + deadline_seconds
   - Αποθήκευση tip hash για ανίχνευση reorg
```

**Υλοποίηση:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Αναμονή Deadline και Σφυρηλάτηση Block

**WaitForDeadlineOrNewSubmission:**

**Συνθήκες Αναμονής:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Όταν το Deadline Φτάσει - Επικύρωση Φρέσκου Context:**
```cpp
1. Λήψη τρέχοντος context: GetNewBlockContext(*chainman)

2. Επικύρωση ύψους:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Επικύρωση generation signature:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Ακραία περίπτωση base target:
   if (forging_base_target != current_base_target) {
       // Επανυπολογισμός deadline με νέο base target
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Αναμονή ξανά
   }

5. Όλα έγκυρα → ForgeBlock()
```

**Διαδικασία ForgeBlock:**

```cpp
1. Προσδιορισμός effective signer (υποστήριξη ανάθεσης):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Δημιουργία coinbase script:
   coinbase_script = P2WPKH(effective_signer);  // Πληρώνει effective signer

3. Δημιουργία block template:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Προσθήκη PoCX proof:
   block.pocxProof.account_id = plot_address;    // Αρχική διεύθυνση plot
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Επανυπολογισμός merkle root:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Υπογραφή block:
   // Χρήση κλειδιού effective signer (μπορεί να διαφέρει από ιδιοκτήτη plot)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Υποβολή στην αλυσίδα:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Χειρισμός αποτελέσματος:
   if (accepted) {
       log_success();
       reset_forging_state();  // Έτοιμο για επόμενο block
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Υλοποίηση:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Βασικές Αποφάσεις Σχεδιασμού:**
- Το coinbase πληρώνει τον effective signer (σεβασμός αναθέσεων)
- Η απόδειξη περιέχει την αρχική διεύθυνση plot (για επικύρωση)
- Υπογραφή από κλειδί effective signer (απόδειξη ιδιοκτησίας)
- Η δημιουργία template περιλαμβάνει αυτόματα συναλλαγές mempool

---

## Επικύρωση Block

### Ροή Επικύρωσης Εισερχόμενου Block

Όταν ένα block λαμβάνεται από το δίκτυο ή υποβάλλεται τοπικά, υποβάλλεται σε επικύρωση σε πολλαπλά στάδια:

### Στάδιο 1: Επικύρωση Κεφαλίδας (CheckBlockHeader)

**Επικύρωση Χωρίς Context:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**Επικύρωση PoCX (όταν ορίζεται το ENABLE_POCX):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Βασική επικύρωση υπογραφής (χωρίς υποστήριξη ανάθεσης ακόμα)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Βασική Επικύρωση Υπογραφής:**
1. Έλεγχος παρουσίας πεδίων pubkey και signature
2. Επικύρωση μεγέθους pubkey (33 bytes συμπιεσμένο)
3. Επικύρωση μεγέθους υπογραφής (65 bytes compact)
4. Ανάκτηση pubkey από υπογραφή: `pubkey.RecoverCompact(hash, signature)`
5. Επαλήθευση ότι το ανακτημένο pubkey ταιριάζει με το αποθηκευμένο pubkey

**Υλοποίηση:** `src/validation.cpp:CheckBlockHeader()`
**Λογική Υπογραφής:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Στάδιο 2: Επικύρωση Block (CheckBlock)

**Επικυρώνει:**
- Ορθότητα Merkle root
- Εγκυρότητα συναλλαγών
- Απαιτήσεις coinbase
- Όρια μεγέθους block
- Τυπικούς κανόνες συναίνεσης Bitcoin

**Υλοποίηση:** `src/consensus/validation.cpp:CheckBlock()`

### Στάδιο 3: Επικύρωση Κεφαλίδας με Context (ContextualCheckBlockHeader)

**Επικύρωση Ειδική για PoCX:**

```cpp
#ifdef ENABLE_POCX
    // Βήμα 1: Επικύρωση generation signature
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Βήμα 2: Επικύρωση base target
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Βήμα 3: Επικύρωση proof of capacity
    auto compression_bounds = GetPoCXCompressionBounds(block.nHeight, halving_interval);
    auto result = ValidateProofOfCapacity(
        block.generationSignature,
        block.pocxProof,
        block.nBaseTarget,
        block.nHeight,
        compression_bounds.nPoCXMinCompression,
        compression_bounds.nPoCXTargetCompression,
        block_time
    );

    if (!result.is_valid) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-proof");
    }

    // Βήμα 4: Επαλήθευση χρονισμού deadline
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Βήματα Επικύρωσης:**
1. **Generation Signature:** Πρέπει να ταιριάζει με την υπολογισμένη τιμή από το προηγούμενο block
2. **Base Target:** Πρέπει να ταιριάζει με τον υπολογισμό προσαρμογής δυσκολίας
3. **Επίπεδο Κλιμάκωσης:** Πρέπει να πληροί το ελάχιστο δικτύου (`compression >= min_compression`)
4. **Δήλωση Ποιότητας:** Η υποβληθείσα ποιότητα πρέπει να ταιριάζει με την υπολογισμένη ποιότητα από την απόδειξη
5. **Proof of Capacity:** Κρυπτογραφική επικύρωση απόδειξης (βελτιστοποιημένη με SIMD)
6. **Χρονισμός Deadline:** Το time-bended deadline (`poc_time`) πρέπει να είναι ≤ elapsed time

**Υλοποίηση:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Στάδιο 4: Σύνδεση Block (ConnectBlock)

**Πλήρης Επικύρωση με Context:**

```cpp
#ifdef ENABLE_POCX
    // Εκτεταμένη επικύρωση υπογραφής με υποστήριξη ανάθεσης
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Εκτεταμένη Επικύρωση Υπογραφής:**
1. Εκτέλεση βασικής επικύρωσης υπογραφής
2. Εξαγωγή account ID από ανακτημένο pubkey
3. Λήψη effective signer για διεύθυνση plot: `GetEffectiveSigner(plot_address, height, view)`
4. Επαλήθευση ότι ο λογαριασμός pubkey ταιριάζει με τον effective signer

**Λογική Ανάθεσης:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Επιστροφή assigned signer
    }

    return plotAddress;  // Χωρίς ανάθεση - ο ιδιοκτήτης plot υπογράφει
}
```

**Υλοποίηση:**
- Σύνδεση: `src/validation.cpp:ConnectBlock()`
- Εκτεταμένη επικύρωση: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Λογική ανάθεσης: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Στάδιο 5: Ενεργοποίηση Αλυσίδας

**Ροή ProcessNewBlock:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Επικύρωση και αποθήκευση στο δίσκο
    2. ActivateBestChain → Ενημέρωση chain tip αν αυτή είναι η καλύτερη αλυσίδα
    3. Ειδοποίηση δικτύου για νέο block
}
```

**Υλοποίηση:** `src/validation.cpp:ProcessNewBlock()`

### Σύνοψη Επικύρωσης

**Πλήρης Διαδρομή Επικύρωσης:**
```
Λήψη Block
    ↓
CheckBlockHeader (βασική υπογραφή)
    ↓
CheckBlock (συναλλαγές, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, base target, PoC proof, deadline)
    ↓
ConnectBlock (εκτεταμένη υπογραφή με αναθέσεις, μεταβάσεις κατάστασης)
    ↓
ActivateBestChain (χειρισμός reorg, επέκταση αλυσίδας)
    ↓
Διάδοση Δικτύου
```

---

## Σύστημα Αναθέσεων

### Επισκόπηση

Οι αναθέσεις επιτρέπουν στους ιδιοκτήτες plot να αναθέτουν δικαιώματα σφυρηλάτησης σε άλλες διευθύνσεις διατηρώντας την ιδιοκτησία του plot.

**Περιπτώσεις Χρήσης:**
- Εξόρυξη σε pool (τα plots αναθέτουν στη διεύθυνση pool)
- Cold storage (κλειδί εξόρυξης ξεχωριστό από την ιδιοκτησία plot)
- Εξόρυξη πολλών μερών (κοινή υποδομή)

### Αρχιτεκτονική Αναθέσεων

**Σχεδιασμός Αποκλειστικά με OP_RETURN:**
- Οι αναθέσεις αποθηκεύονται σε εξόδους OP_RETURN (χωρίς UTXO)
- Χωρίς απαιτήσεις δαπάνης (χωρίς dust, χωρίς τέλη για κράτηση)
- Παρακολούθηση σε εκτεταμένη κατάσταση CCoinsViewCache
- Ενεργοποιούνται μετά από περίοδο καθυστέρησης (προεπιλογή: 4 blocks)

**Καταστάσεις Ανάθεσης:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Δεν υπάρχει ανάθεση
    ASSIGNING = 1,   // Ανάθεση σε αναμονή ενεργοποίησης (περίοδος καθυστέρησης)
    ASSIGNED = 2,    // Ανάθεση ενεργή, επιτρέπεται σφυρηλάτηση
    REVOKING = 3,    // Ανάκληση σε αναμονή (περίοδος καθυστέρησης, ακόμα ενεργή)
    REVOKED = 4      // Ανάκληση ολοκληρώθηκε, ανάθεση δεν είναι πλέον ενεργή
};
```

### Δημιουργία Αναθέσεων

**Μορφή Συναλλαγής:**
```cpp
Transaction {
    inputs: [any]  // Αποδεικνύει ιδιοκτησία διεύθυνσης plot
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Κανόνες Επικύρωσης:**
1. Η είσοδος πρέπει να είναι υπογεγραμμένη από τον ιδιοκτήτη plot (αποδεικνύει ιδιοκτησία)
2. Το OP_RETURN περιέχει έγκυρα δεδομένα ανάθεσης
3. Το plot πρέπει να είναι UNASSIGNED ή REVOKED
4. Χωρίς διπλές αναθέσεις σε αναμονή στο mempool
5. Ελάχιστο τέλος συναλλαγής πληρωμένο

**Ενεργοποίηση:**
- Η ανάθεση γίνεται ASSIGNING στο ύψος επιβεβαίωσης
- Γίνεται ASSIGNED μετά την περίοδο καθυστέρησης (4 blocks regtest, 30 blocks mainnet)
- Η καθυστέρηση αποτρέπει γρήγορες επανααναθέσεις κατά τη διάρκεια block races

**Υλοποίηση:** `src/script/forging_assignment.h`, επικύρωση στο ConnectBlock

### Ανάκληση Αναθέσεων

**Μορφή Συναλλαγής:**
```cpp
Transaction {
    inputs: [any]  // Αποδεικνύει ιδιοκτησία διεύθυνσης plot
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Αποτέλεσμα:**
- Άμεση μετάβαση κατάστασης σε REVOKED
- Ο ιδιοκτήτης plot μπορεί να σφυρηλατήσει αμέσως
- Μπορεί να δημιουργήσει νέα ανάθεση μετά

### Επικύρωση Ανάθεσης Κατά την Εξόρυξη

**Προσδιορισμός Effective Signer:**
```cpp
// Στην επικύρωση submit_nonce
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// Στη σφυρηλάτηση block
coinbase_script = P2WPKH(effective_signer);  // Η ανταμοιβή πηγαίνει εδώ

// Στην υπογραφή block
signature = effective_signer_key.SignCompact(hash);  // Πρέπει να υπογράψει με effective signer
```

**Επικύρωση Block:**
```cpp
// Στο VerifyPoCXBlockCompactSignature (εκτεταμένο)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Βασικές Ιδιότητες:**
- Η απόδειξη περιέχει πάντα την αρχική διεύθυνση plot
- Η υπογραφή πρέπει να είναι από τον effective signer
- Το coinbase πληρώνει τον effective signer
- Η επικύρωση χρησιμοποιεί την κατάσταση ανάθεσης στο ύψος block

---

## Διάδοση Δικτύου

### Ανακοίνωση Block

**Τυπικό Πρωτόκολλο P2P Bitcoin:**
1. Το σφυρηλατημένο block υποβάλλεται μέσω `ProcessNewBlock()`
2. Το block επικυρώνεται και προστίθεται στην αλυσίδα
3. Ειδοποίηση δικτύου: `GetMainSignals().BlockConnected()`
4. Το επίπεδο P2P μεταδίδει το block στους peers

**Υλοποίηση:** Τυπική επεξεργασία δικτύου Bitcoin Core

### Αναμετάδοση Block

**Compact Blocks (BIP 152):**
- Χρησιμοποιούνται για αποδοτική διάδοση block
- Αρχικά αποστέλλονται μόνο τα transaction IDs
- Οι peers ζητούν τις ελλείπουσες συναλλαγές

**Πλήρης Αναμετάδοση Block:**
- Εφεδρική όταν αποτυγχάνουν τα compact blocks
- Μεταδίδονται πλήρη δεδομένα block

### Αναδιοργανώσεις Αλυσίδας

**Χειρισμός Reorg:**
```cpp
// Στο worker thread του forger
if (current_tip_hash != stored_tip_hash) {
    // Ανιχνεύθηκε αναδιοργάνωση αλυσίδας
    reset_forging_state();
    log("Chain tip changed, resetting forging");
}
```

**Επίπεδο Blockchain:**
- Τυπικός χειρισμός reorg Bitcoin Core
- Η καλύτερη αλυσίδα καθορίζεται από το chainwork
- Τα αποσυνδεδεμένα blocks επιστρέφουν στο mempool

---

## Τεχνικές Λεπτομέρειες

### Πρόληψη Deadlock

**Μοτίβο Deadlock ABBA (Αποτρέπεται):**
```
Thread A: cs_main → cs_wallet
Thread B: cs_wallet → cs_main
```

**Λύση:**
1. **submit_nonce:** Μηδενική χρήση cs_main
   - Το `GetNewBlockContext()` χειρίζεται το κλείδωμα εσωτερικά
   - Όλη η επικύρωση πριν την υποβολή στον forger

2. **Forger:** Αρχιτεκτονική βασισμένη σε ουρά
   - Μόνο ένα worker thread (χωρίς thread joins)
   - Φρέσκο context σε κάθε πρόσβαση
   - Χωρίς εμφωλευμένα locks

3. **Έλεγχοι πορτοφολιού:** Εκτελούνται πριν τις ακριβές λειτουργίες
   - Πρώιμη απόρριψη αν δεν υπάρχει διαθέσιμο κλειδί
   - Ξεχωριστά από την πρόσβαση στην κατάσταση blockchain

### Βελτιστοποιήσεις Επιδόσεων

**Επικύρωση Γρήγορης Αποτυχίας:**
```cpp
1. Έλεγχοι μορφής (άμεσοι)
2. Επικύρωση context (ελαφριά)
3. Επαλήθευση πορτοφολιού (τοπική)
4. Επικύρωση απόδειξης (ακριβή SIMD)
```

**Μία Λήψη Context:**
- Μία κλήση `GetNewBlockContext()` ανά υποβολή
- Προσωρινή αποθήκευση αποτελεσμάτων για πολλαπλούς ελέγχους
- Χωρίς επαναλαμβανόμενες αποκτήσεις cs_main

**Αποδοτικότητα Ουράς:**
- Ελαφριά δομή υποβολής
- Χωρίς base_target/deadline στην ουρά (επανυπολογίζονται φρέσκα)
- Ελάχιστο αποτύπωμα μνήμης

### Χειρισμός Παλαιότητας

**"Απλός" Σχεδιασμός Forger:**
- Χωρίς εγγραφές σε συμβάντα blockchain
- Τεμπέλικη επικύρωση όταν χρειάζεται
- Σιωπηλές απορρίψεις παλαιών υποβολών

**Οφέλη:**
- Απλή αρχιτεκτονική
- Χωρίς πολύπλοκο συγχρονισμό
- Ανθεκτική σε ακραίες περιπτώσεις

**Ακραίες Περιπτώσεις που Χειρίζονται:**
- Αλλαγές ύψους → απόρριψη
- Αλλαγές generation signature → απόρριψη
- Αλλαγές base target → επανυπολογισμός deadline
- Reorgs → επαναφορά κατάστασης σφυρηλάτησης

### Κρυπτογραφικές Λεπτομέρειες

**Generation Signature:**
```cpp
SHA256(prev_generation_signature || prev_miner_pubkey_33bytes)
```

**Block Signature Hash:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Μορφή Compact Signature:**
- 65 bytes: [recovery_id][r][s]
- Επιτρέπει ανάκτηση δημόσιου κλειδιού
- Χρησιμοποιείται για αποδοτικότητα χώρου

**Account ID:**
- 20-byte HASH160 συμπιεσμένου δημόσιου κλειδιού
- Ταιριάζει με μορφές διευθύνσεων Bitcoin (P2PKH, P2WPKH)

### Μελλοντικές Βελτιώσεις

**Τεκμηριωμένοι Περιορισμοί:**
1. Χωρίς μετρικές επιδόσεων (ρυθμοί υποβολής, κατανομές deadline)
2. Χωρίς λεπτομερή κατηγοριοποίηση σφαλμάτων για εξορύκτες
3. Περιορισμένη αναζήτηση κατάστασης forger (τρέχον deadline, βάθος ουράς)

**Πιθανές Βελτιώσεις:**
- RPC για κατάσταση forger
- Μετρικές για αποδοτικότητα εξόρυξης
- Βελτιωμένη καταγραφή για αποσφαλμάτωση
- Υποστήριξη πρωτοκόλλου pool

---

## Αναφορές Κώδικα

**Βασικές Υλοποιήσεις:**
- Διεπαφή RPC: `src/pocx/rpc/mining.cpp`
- Ουρά Σφυρηλάτησης: `src/pocx/mining/scheduler.cpp`
- Επικύρωση Συναίνεσης: `src/pocx/consensus/validation.cpp`
- Επικύρωση Απόδειξης: `src/pocx/consensus/pocx.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- Επικύρωση Block: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Λογική Ανάθεσης: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Διαχείριση Context: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Δομές Δεδομένων:**
- Μορφή Block: `src/primitives/block.h`
- Παράμετροι Συναίνεσης: `src/consensus/params.h`
- Παρακολούθηση Αναθέσεων: `src/coins.h` (επεκτάσεις CCoinsViewCache)

---

## Παράρτημα: Προδιαγραφές Αλγορίθμων

### Τύπος Time Bending

**Μαθηματικός Ορισμός:**
```
deadline_seconds = quality / base_target  (ακατέργαστο)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

όπου:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Υλοποίηση:**
- Αριθμητική σταθερής υποδιαστολής (μορφή Q42)
- Υπολογισμός κυβικής ρίζας μόνο με ακέραιους
- Βελτιστοποιημένο για αριθμητική 256-bit

### Υπολογισμός Ποιότητας

**Διαδικασία:**
1. Δημιουργία scoop από generation signature και ύψος
2. Ανάγνωση δεδομένων plot για υπολογισμένο scoop
3. Hash: `SHABAL256(generation_signature || scoop_data)`
4. Δοκιμή επιπέδων κλιμάκωσης από min σε max
5. Επιστροφή καλύτερης ποιότητας που βρέθηκε

**Κλιμάκωση:**
- Επίπεδο X0: Βασική γραμμή POC2 (θεωρητικό)
- Επίπεδο X1: Βασική γραμμή XOR-transpose
- Επίπεδο Xn: 2^(n-1) × ενσωματωμένη εργασία X1
- Υψηλότερη κλιμάκωση = περισσότερη εργασία δημιουργίας plot

### Προσαρμογή Base Target

**Προσαρμογή κάθε block:**
1. Υπολογισμός κινητού μέσου όρου πρόσφατων base targets
2. Υπολογισμός πραγματικού timespan έναντι target timespan για κυλιόμενο παράθυρο
3. Αναλογική προσαρμογή base target
4. Περιορισμός για αποτροπή ακραίων διακυμάνσεων

**Τύπος:**
```
avg_base_target = moving_average(πρόσφατα base targets)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*Αυτή η τεκμηρίωση αντικατοπτρίζει την πλήρη υλοποίηση συναίνεσης PoCX από τον Οκτώβριο 2025.*

---

[← Προηγούμενο: Μορφή Plot](2-plot-format.md) | [Πίνακας Περιεχομένων](index.md) | [Επόμενο: Αναθέσεις Σφυρηλάτησης →](4-forging-assignments.md)
