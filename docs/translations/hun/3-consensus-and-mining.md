[← Előző: Plotfájl Formátum](2-plot-format.md) | [📘 Tartalomjegyzék](index.md) | [Következő: Kovácsolási Megbízások →](4-forging-assignments.md)

---

# 3. Fejezet: Bitcoin-PoCX Konszenzus és Bányászati Folyamat

A PoCX (Proof of Capacity neXt generation) konszenzus mechanizmus és bányászati folyamat teljes műszaki specifikációja, integrálva a Bitcoin Core-ba.

---

## Tartalomjegyzék

1. [Áttekintés](#áttekintés)
2. [Konszenzus Architektúra](#konszenzus-architektúra)
3. [Bányászati Folyamat](#bányászati-folyamat)
4. [Blokk Validáció](#blokk-validáció)
5. [Megbízási Rendszer](#megbízási-rendszer)
6. [Hálózati Terjesztés](#hálózati-terjesztés)
7. [Műszaki Részletek](#műszaki-részletek)

---

## Áttekintés

A Bitcoin-PoCX egy tiszta Proof of Capacity konszenzus mechanizmust valósít meg a Bitcoin Proof of Work teljes helyettesítéseként. Ez egy új lánc visszafelé kompatibilitási követelmények nélkül.

**Fő Tulajdonságok:**
- **Energiahatékony:** A bányászat előre generált plotfájlokat használ számítási hash-elés helyett
- **Time Bended Határidők:** Eloszlás transzformáció (exponenciálisról chi-négyzetre) csökkenti a hosszú blokkokat, javítja az átlagos blokkidőket
- **Megbízás Támogatás:** Plot tulajdonosok kovácsolási jogokat delegálhatnak más címekre
- **Natív C++ Integráció:** Kriptográfiai algoritmusok C++-ban implementálva konszenzus validációhoz

**Bányászati Folyamat:**
```
Külső Bányász → get_mining_info → Nonce Számítás → submit_nonce →
Kovácsoló Sor → Határidő Várakozás → Blokk Kovácsolás → Hálózati Terjesztés →
Blokk Validáció → Lánc Bővítés
```

---

## Konszenzus Architektúra

### Blokk Szerkezet

A PoCX blokkok kibővítik a Bitcoin blokk szerkezetét további konszenzus mezőkkel:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Plot seed (32 bájt)
    std::array<uint8_t, 20> account_id;       // Plot cím (20 bájtos hash160)
    uint32_t compression;                     // Skálázási szint (1-255)
    uint64_t nonce;                           // Bányászati nonce (64-bit)
    uint64_t quality;                         // Igényelt minőség (PoC hash kimenet)
};

class CBlockHeader {
    // Szabványos Bitcoin mezők
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCX konszenzus mezők (felváltják nBits és nNonce mezőket)
    int nHeight;                              // Blokk magasság (kontextusfüggetlen validáció)
    uint256 generationSignature;              // Generációs aláírás (bányászati entrópia)
    uint64_t nBaseTarget;                     // Nehézség paraméter (inverz nehézség)
    PoCXProof pocxProof;                      // Bányászati bizonyíték

    // Blokk aláírás mezők
    std::array<uint8_t, 33> vchPubKey;        // Tömörített publikus kulcs (33 bájt)
    std::array<uint8_t, 65> vchSignature;     // Kompakt aláírás (65 bájt)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Tranzakciók
};
```

**Megjegyzés:** Az aláírás (`vchSignature`) ki van zárva a blokk hash számításból a módosíthatóság megakadályozása érdekében.

**Implementáció:** `src/primitives/block.h`

### Generációs Aláírás

A generációs aláírás bányászati entrópiát hoz létre és megakadályozza az előszámítási támadásokat.

**Számítás:**
```
generationSignature = SHA256(előző_generationSignature || előző_bányász_pubkey)
```

**Genezis Blokk:** Rögzített kezdeti generációs aláírást használ

**Implementáció:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Alap Célérték (Nehézség)

Az alap célérték a nehézség inverze — magasabb értékek könnyebb bányászatot jelentenek.

**Beállítási Algoritmus:**
- Cél blokkidő: 120 másodperc (mainnet), 1 másodperc (regtest)
- Beállítási intervallum: Minden blokk
- Mozgóátlagot használ a legutóbbi alap célértékekből
- Korlátozva a szélsőséges nehézségi kilengések megakadályozására

**Implementáció:** `src/consensus/params.h`, nehézség beállítás a blokk létrehozásban

### Skálázási Szintek

A PoCX támogatja a skálázható proof-of-work-öt a plotfájlokban skálázási szinteken (Xn) keresztül.

**Dinamikus Határok:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimum elfogadott szint
    uint8_t nPoCXTargetCompression;  // Ajánlott szint
};
```

**Skálázás Növelési Ütemterv:**
- Exponenciális intervallumok: 4., 12., 28., 60., 124. év (1., 3., 7., 15., 31. felezés)
- Minimum skálázási szint 1-gyel növekszik
- Cél skálázási szint 1-gyel növekszik
- Fenntartja a biztonsági határt a plot létrehozási és keresési költségek között
- Maximum skálázási szint: 255

**Implementáció:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Bányászati Folyamat

### 1. Bányászati Információ Lekérés

**RPC Parancs:** `get_mining_info`

**Folyamat:**
1. `GetNewBlockContext(chainman)` hívása az aktuális blokklánc állapot lekéréséhez
2. Dinamikus tömörítési határok számítása az aktuális magassághoz
3. Bányászati paraméterek visszaadása

**Válasz:**
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

**Implementáció:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Megjegyzések:**
- Nincs zár tartva a válasz generálás során
- Kontextus beszerzés belsőleg kezeli a `cs_main`-t
- `block_hash` hivatkozásként szerepel, de nem használt a validációban

### 2. Külső Bányászat

**Külső bányász felelősségei:**
1. Plotfájlok olvasása lemezről
2. Scoop számítása generációs aláírás és magasság alapján
3. Legjobb határidővel rendelkező nonce megtalálása
4. Beküldés a csomópontnak `submit_nonce`-on keresztül

**Plotfájl Formátum:**
- POC2 formátumon alapul (Burstcoin)
- Biztonsági javításokkal és skálázhatósági fejlesztésekkel kibővítve
- Lásd attribúciót a `CLAUDE.md`-ben

**Bányász Implementáció:** Külső (pl. Scavenger alapján)

### 3. Nonce Beküldés és Validáció

**RPC Parancs:** `submit_nonce`

**Paraméterek:**
```
height, generation_signature, account_id, seed, nonce, quality (opcionális)
```

**Validációs Folyamat (Optimalizált Sorrend):**

#### 1. Lépés: Gyors Formátum Validáció
```cpp
// Account ID: 40 hex karakter = 20 bájt
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 hex karakter = 32 bájt
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### 2. Lépés: Kontextus Beszerzés
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Visszaad: height, generation_signature, base_target, block_hash
```

**Zárolás:** `cs_main` belsőleg kezelt, nincs zár tartva az RPC szálban

#### 3. Lépés: Kontextus Validáció
```cpp
// Magasság ellenőrzés
if (height != context.height) reject;

// Generációs aláírás ellenőrzés
if (submitted_gen_sig != context.generation_signature) reject;
```

#### 4. Lépés: Tárca Ellenőrzés
```cpp
// Effektív aláíró meghatározása (megbízások figyelembevételével)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Ellenőrzés, hogy a csomópont rendelkezik-e privát kulccsal az effektív aláíróhoz
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Megbízás Támogatás:** A plot tulajdonos kovácsolási jogokat rendelhet másik címhez. A tárcának az effektív aláíró kulcsával kell rendelkeznie, nem feltétlenül a plot tulajdonoséval.

#### 5. Lépés: Bizonyíték Validáció
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 bájt
    block_height,
    nonce,
    seed,                // 32 bájt
    min_compression,
    max_compression,
    &result             // Kimenet: quality, deadline
);
```

**Algoritmus:**
1. Generációs aláírás dekódolása hex-ből
2. Legjobb minőség számítása tömörítési tartományban SIMD-optimalizált algoritmusokkal
3. Minőség validálása a nehézségi követelményeknek való megfelelésre
4. Nyers minőség érték visszaadása

**Implementáció:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### 6. Lépés: Time Bending Számítás
```cpp
// Nyers nehézség-állított határidő (másodperc)
uint64_t deadline_seconds = quality / base_target;

// Time Bended kovácsolási idő (másodperc)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Time Bending Formula:**
```
Y = scale * (X^(1/3))
ahol:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Cél:** Exponenciálist chi-négyzet eloszlássá transzformál. A nagyon jó megoldások később kovácsolódnak (a hálózatnak van ideje átnézni a lemezeket), a gyenge megoldások javulnak. Csökkenti a hosszú blokkokat, fenntartja a 120mp átlagot.

**Implementáció:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### 7. Lépés: Kovácsoló Beküldés
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // NEM határidő - újraszámolva a kovácsolóban
    height,
    generation_signature
);
```

**Sor-Alapú Tervezés:**
- Beküldés mindig sikeres (hozzáadva a sorhoz)
- RPC azonnal visszatér
- Munkaszál aszinkron módon dolgoz fel

**Implementáció:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Kovácsoló Sor Feldolgozás

**Architektúra:**
- Egyetlen perzisztens munkaszál
- FIFO beküldési sor
- Zármentes kovácsolási állapot (csak munkaszál)
- Nincsenek beágyazott zárak (holtpont megelőzés)

**Munkaszál Fő Ciklus:**
```cpp
while (!shutdown) {
    // 1. Sorban álló beküldések ellenőrzése
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Várakozás határidőre vagy új beküldésre
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**ProcessSubmission Logika:**
```cpp
1. Friss kontextus lekérése: GetNewBlockContext(*chainman)

2. Elavultság ellenőrzések (csendes eldobás):
   - Magasság eltérés → eldobás
   - Generációs aláírás eltérés → eldobás
   - Csúcs blokk hash változott (reorg) → kovácsolási állapot visszaállítás

3. Minőség összehasonlítás:
   - Ha quality >= current_best → eldobás

4. Time Bended határidő számítása:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Kovácsolási állapot frissítése:
   - Meglévő kovácsolás törlése (ha jobb találat)
   - Tárolás: account_id, seed, nonce, quality, deadline
   - Számítás: forge_time = block_time + deadline_seconds
   - Csúcs hash tárolása reorg észleléshez
```

**Implementáció:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Határidő Várakozás és Blokk Kovácsolás

**WaitForDeadlineOrNewSubmission:**

**Várakozási Feltételek:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Amikor a Határidő Lejár - Friss Kontextus Validáció:**
```cpp
1. Aktuális kontextus lekérése: GetNewBlockContext(*chainman)

2. Magasság validáció:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Generációs aláírás validáció:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Alap célérték szélső eset:
   if (forging_base_target != current_base_target) {
       // Határidő újraszámítása új alap célértékkel
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Újra várakozás
   }

5. Minden érvényes → ForgeBlock()
```

**ForgeBlock Folyamat:**

```cpp
1. Effektív aláíró meghatározása (megbízás támogatás):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Coinbase script létrehozása:
   coinbase_script = P2WPKH(effective_signer);  // Effektív aláírónak fizet

3. Blokk sablon létrehozása:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. PoCX bizonyíték hozzáadása:
   block.pocxProof.account_id = plot_address;    // Eredeti plot cím
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Merkle gyökér újraszámítása:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Blokk aláírása:
   // Effektív aláíró kulcsát használja (eltérhet a plot tulajdonostól)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Beküldés a láncnak:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Eredmény kezelés:
   if (accepted) {
       log_success();
       reset_forging_state();  // Kész a következő blokkra
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implementáció:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Fő Tervezési Döntések:**
- Coinbase az effektív aláírónak fizet (megbízások tiszteletben tartása)
- Bizonyíték az eredeti plot címet tartalmazza (validációhoz)
- Aláírás az effektív aláíró kulcsától (tulajdonjog bizonyítása)
- Sablon létrehozás automatikusan tartalmazza a mempool tranzakciókat

---

## Blokk Validáció

### Bejövő Blokk Validációs Folyamat

Amikor egy blokk érkezik a hálózatról vagy helyben kerül beküldésre, validáción megy keresztül több szakaszban:

### 1. Szakasz: Fejléc Validáció (CheckBlockHeader)

**Kontextusfüggetlen Validáció:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX Validáció (amikor ENABLE_POCX definiálva):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Alapvető aláírás validáció (még nincs megbízás támogatás)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Alapvető Aláírás Validáció:**
1. Pubkey és aláírás mezők meglétének ellenőrzése
2. Pubkey méret validálása (33 bájt tömörített)
3. Aláírás méret validálása (65 bájt kompakt)
4. Pubkey helyreállítása aláírásból: `pubkey.RecoverCompact(hash, signature)`
5. Helyreállított pubkey egyezésének ellenőrzése a tárolt pubkey-jel

**Implementáció:** `src/validation.cpp:CheckBlockHeader()`
**Aláírás Logika:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### 2. Szakasz: Blokk Validáció (CheckBlock)

**Validál:**
- Merkle gyökér helyesség
- Tranzakció érvényesség
- Coinbase követelmények
- Blokk méret korlátok
- Szabványos Bitcoin konszenzus szabályok

**Implementáció:** `src/consensus/validation.cpp:CheckBlock()`

### 3. Szakasz: Kontextuális Fejléc Validáció (ContextualCheckBlockHeader)

**PoCX-Specifikus Validáció:**

```cpp
#ifdef ENABLE_POCX
    // 1. Lépés: Generációs aláírás validálása
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // 2. Lépés: Alap célérték validálása
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // 3. Lépés: Proof of capacity validálása
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

    // 4. Lépés: Határidő időzítés ellenőrzése
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Validációs Lépések:**
1. **Generációs Aláírás:** Egyeznie kell az előző blokkból számított értékkel
2. **Alap Célérték:** Egyeznie kell a nehézség beállítási számítással
3. **Skálázási Szint:** Meg kell felelnie a hálózati minimumnak (`compression >= min_compression`)
4. **Minőség Igény:** A beküldött minőségnek egyeznie kell a bizonyítékból számított minőséggel
5. **Proof of Capacity:** Kriptográfiai bizonyíték validáció (SIMD-optimalizált)
6. **Határidő Időzítés:** Time-bended határidő (`poc_time`) ≤ eltelt idő kell legyen

**Implementáció:** `src/validation.cpp:ContextualCheckBlockHeader()`

### 4. Szakasz: Blokk Csatlakoztatás (ConnectBlock)

**Teljes Kontextuális Validáció:**

```cpp
#ifdef ENABLE_POCX
    // Kiterjesztett aláírás validáció megbízás támogatással
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Kiterjesztett Aláírás Validáció:**
1. Alapvető aláírás validáció végrehajtása
2. Account ID kinyerése helyreállított pubkey-ből
3. Effektív aláíró lekérése plot címhez: `GetEffectiveSigner(plot_address, height, view)`
4. Pubkey account egyezésének ellenőrzése az effektív aláíróval

**Megbízás Logika:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Megbízott aláíró visszaadása
    }

    return plotAddress;  // Nincs megbízás - plot tulajdonos aláír
}
```

**Implementáció:**
- Csatlakoztatás: `src/validation.cpp:ConnectBlock()`
- Kiterjesztett validáció: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Megbízás logika: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### 5. Szakasz: Lánc Aktiválás

**ProcessNewBlock Folyamat:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock → Validálás és lemezre tárolás
    2. ActivateBestChain → Lánccsúcs frissítése, ha ez a legjobb lánc
    3. Hálózat értesítése az új blokkról
}
```

**Implementáció:** `src/validation.cpp:ProcessNewBlock()`

### Validáció Összefoglaló

**Teljes Validációs Útvonal:**
```
Blokk Fogadás
    ↓
CheckBlockHeader (alapvető aláírás)
    ↓
CheckBlock (tranzakciók, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, base target, PoC bizonyíték, határidő)
    ↓
ConnectBlock (kiterjesztett aláírás megbízásokkal, állapot átmenetek)
    ↓
ActivateBestChain (reorg kezelés, lánc bővítés)
    ↓
Hálózati Terjesztés
```

---

## Megbízási Rendszer

### Áttekintés

A megbízások lehetővé teszik a plot tulajdonosoknak, hogy kovácsolási jogokat delegáljanak más címekre, miközben megtartják a plot tulajdonjogát.

**Felhasználási Esetek:**
- Pool bányászat (plotok pool címhez rendelése)
- Hideg tárolás (bányász kulcs elkülönítése a plot tulajdonjogtól)
- Többrésztvevős bányászat (megosztott infrastruktúra)

### Megbízás Architektúra

**Csak OP_RETURN Tervezés:**
- Megbízások OP_RETURN kimenetekben tárolva (nincs UTXO)
- Nincsenek költési követelmények (nincs dust, nincs díj a tartásért)
- CCoinsViewCache kiterjesztett állapotában nyilvántartva
- Késleltetési periódus után aktiválódik (alapértelmezett: 4 blokk)

**Megbízás Állapotok:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Nincs megbízás
    ASSIGNING = 1,   // Megbízás aktiválásra vár (késleltetési periódus)
    ASSIGNED = 2,    // Megbízás aktív, kovácsolás engedélyezett
    REVOKING = 3,    // Visszavonás folyamatban (késleltetési periódus, még aktív)
    REVOKED = 4      // Visszavonás befejezve, megbízás már nem aktív
};
```

### Megbízások Létrehozása

**Tranzakció Formátum:**
```cpp
Transaction {
    inputs: [any]  // Plot tulajdonjog bizonyítása
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Validációs Szabályok:**
1. Bemenetet plot tulajdonosnak kell aláírnia (tulajdonjog bizonyítása)
2. OP_RETURN érvényes megbízás adatokat tartalmaz
3. Plot UNASSIGNED vagy REVOKED állapotban kell legyen
4. Nincs duplikált függő megbízás a mempool-ban
5. Minimum tranzakciós díj fizetve

**Aktiválás:**
- Megbízás ASSIGNING-gá válik megerősítési magasságnál
- ASSIGNED lesz késleltetési periódus után (4 blokk regtest, 30 blokk mainnet)
- Késleltetés megakadályozza a gyors újrahozzárendelést blokkversenyek során

**Implementáció:** `src/script/forging_assignment.h`, validáció ConnectBlock-ban

### Megbízások Visszavonása

**Tranzakció Formátum:**
```cpp
Transaction {
    inputs: [any]  // Plot tulajdonjog bizonyítása
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Hatás:**
- Azonnali állapotátmenet REVOKED-ra
- Plot tulajdonos azonnal kovácsolhat
- Utána új megbízás létrehozható

### Megbízás Validáció Bányászat Közben

**Effektív Aláíró Meghatározás:**
```cpp
// submit_nonce validációban
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// Blokk kovácsolásban
coinbase_script = P2WPKH(effective_signer);  // Jutalom ide megy

// Blokk aláírásban
signature = effective_signer_key.SignCompact(hash);  // Effektív aláíróval kell aláírni
```

**Blokk Validáció:**
```cpp
// VerifyPoCXBlockCompactSignature-ban (kiterjesztett)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Fő Tulajdonságok:**
- Bizonyíték mindig az eredeti plot címet tartalmazza
- Aláírásnak az effektív aláírótól kell származnia
- Coinbase az effektív aláírónak fizet
- Validáció a blokk magasságnál érvényes megbízás állapotot használja

---

## Hálózati Terjesztés

### Blokk Bejelentés

**Szabványos Bitcoin P2P Protokoll:**
1. Kovécsolt blokk beküldve `ProcessNewBlock()`-on keresztül
2. Blokk validálva és lánchoz adva
3. Hálózati értesítés: `GetMainSignals().BlockConnected()`
4. P2P réteg terjeszti a blokkot társaknak

**Implementáció:** Szabványos Bitcoin Core net_processing

### Blokk Továbbítás

**Kompakt Blokkok (BIP 152):**
- Hatékony blokk terjesztéshez használt
- Csak tranzakció ID-k küldve kezdetben
- Társak kérik a hiányzó tranzakciókat

**Teljes Blokk Továbbítás:**
- Tartalék, amikor a kompakt blokkok sikertelenek
- Teljes blokk adat továbbítva

### Lánc Reorganizációk

**Reorg Kezelés:**
```cpp
// Kovácsoló munkaszálban
if (current_tip_hash != stored_tip_hash) {
    // Lánc reorganizáció észlelve
    reset_forging_state();
    log("Chain tip changed, resetting forging");
}
```

**Blokklánc-Szintű:**
- Szabványos Bitcoin Core reorg kezelés
- Legjobb lánc chainwork alapján meghatározva
- Leválasztott blokkok visszakerülnek a mempool-ba

---

## Műszaki Részletek

### Holtpont Megelőzés

**ABBA Holtpont Minta (Megelőzve):**
```
A Szál: cs_main → cs_wallet
B Szál: cs_wallet → cs_main
```

**Megoldás:**
1. **submit_nonce:** Nulla cs_main használat
   - `GetNewBlockContext()` belsőleg kezeli a zárolást
   - Minden validáció kovácsoló beküldés előtt

2. **Kovácsoló:** Sor-alapú architektúra
   - Egyetlen munkaszál (nincs szál csatlakozás)
   - Friss kontextus minden hozzáférésnél
   - Nincsenek beágyazott zárak

3. **Tárca ellenőrzések:** Költséges műveletek előtt végrehajtva
   - Korai elutasítás, ha nincs elérhető kulcs
   - Elkülönítve a blokklánc állapot hozzáféréstől

### Teljesítmény Optimalizációk

**Gyors-Hiba Validáció:**
```cpp
1. Formátum ellenőrzések (azonnali)
2. Kontextus validáció (könnyűsúlyú)
3. Tárca ellenőrzés (helyi)
4. Bizonyíték validáció (költséges SIMD)
```

**Egyetlen Kontextus Lekérés:**
- Egy `GetNewBlockContext()` hívás beküldésenként
- Eredmények gyorsítótárazása többszöri ellenőrzésekhez
- Nincs ismételt cs_main beszerzés

**Sor Hatékonyság:**
- Könnyűsúlyú beküldési struktúra
- Nincs base_target/deadline a sorban (frissen újraszámolva)
- Minimális memórialábnyom

### Elavultság Kezelés

**"Buta" Kovácsoló Tervezés:**
- Nincs blokklánc esemény feliratkozás
- Lusta validáció szükség esetén
- Elavult beküldések csendes eldobása

**Előnyök:**
- Egyszerű architektúra
- Nincs komplex szinkronizáció
- Robusztus szélső esetekben

**Kezelt Szélső Esetek:**
- Magasság változások → eldobás
- Generációs aláírás változások → eldobás
- Alap célérték változások → határidő újraszámítása
- Reorg-ok → kovácsolási állapot visszaállítás

### Kriptográfiai Részletek

**Generációs Aláírás:**
```cpp
SHA256(előző_generációs_aláírás || előző_bányász_pubkey_33bájt)
```

**Blokk Aláírás Hash:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Kompakt Aláírás Formátum:**
- 65 bájt: [recovery_id][r][s]
- Lehetővé teszi a publikus kulcs helyreállítását
- Helytakarékosságra használt

**Account ID:**
- 20 bájtos HASH160 a tömörített publikus kulcsból
- Megegyezik a Bitcoin cím formátumokkal (P2PKH, P2WPKH)

### Jövőbeli Fejlesztések

**Dokumentált Korlátozások:**
1. Nincsenek teljesítménymutatók (beküldési ráták, határidő eloszlások)
2. Nincs részletes hibakategorizáció bányászoknak
3. Korlátozott kovácsoló állapot lekérdezés (aktuális határidő, sormélység)

**Lehetséges Fejlesztések:**
- RPC kovácsoló állapothoz
- Mutatók bányászati hatékonysághoz
- Fejlett naplózás hibakereséshez
- Pool protokoll támogatás

---

## Kód Hivatkozások

**Központi Implementációk:**
- RPC Interfész: `src/pocx/rpc/mining.cpp`
- Kovácsoló Sor: `src/pocx/mining/scheduler.cpp`
- Konszenzus Validáció: `src/pocx/consensus/validation.cpp`
- Bizonyíték Validáció: `src/pocx/consensus/pocx.cpp`
- Time Bending: `src/pocx/algorithms/time_bending.cpp`
- Blokk Validáció: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Megbízás Logika: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Kontextus Kezelés: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Adatstruktúrák:**
- Blokk Formátum: `src/primitives/block.h`
- Konszenzus Paraméterek: `src/consensus/params.h`
- Megbízás Nyilvántartás: `src/coins.h` (CCoinsViewCache kiterjesztések)

---

## Függelék: Algoritmus Specifikációk

### Time Bending Formula

**Matematikai Definíció:**
```
deadline_seconds = quality / base_target  (nyers)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

ahol:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Implementáció:**
- Fixpontos aritmetika (Q42 formátum)
- Csak egész köbgyök számítás
- 256-bites aritmetikára optimalizált

### Minőség Számítás

**Folyamat:**
1. Scoop generálása generációs aláírásból és magasságból
2. Plot adat olvasása a számított scoop-hoz
3. Hash: `SHABAL256(generációs_aláírás || scoop_adat)`
4. Skálázási szintek tesztelése min-től max-ig
5. Legjobb talált minőség visszaadása

**Skálázás:**
- X0 szint: POC2 alapvonal (elméleti)
- X1 szint: XOR-transzponálás alapvonal
- Xn szint: 2^(n-1) × X1 munka beágyazva
- Magasabb skálázás = több plot generálási munka

### Alap Célérték Beállítás

**Minden blokk beállítás:**
1. Mozgóátlag számítása legutóbbi alap célértékekből
2. Tényleges időtartam vs cél időtartam számítása gördülő ablakhoz
3. Alap célérték arányos beállítása
4. Korlátozás szélsőséges kilengések megakadályozására

**Formula:**
```
avg_base_target = mozgó_átlag(legutóbbi alap célértékek)
adjustment_factor = tényleges_időtartam / cél_időtartam
new_base_target = avg_base_target * adjustment_factor
new_base_target = korlátoz(new_base_target, min, max)
```

---

*Ez a dokumentáció a teljes PoCX konszenzus implementációt tükrözi 2025 októberi állapot szerint.*

---

[← Előző: Plotfájl Formátum](2-plot-format.md) | [📘 Tartalomjegyzék](index.md) | [Következő: Kovácsolási Megbízások →](4-forging-assignments.md)
