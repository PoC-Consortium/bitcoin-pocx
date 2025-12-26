[<- Eelmine: Graafikuvorming](2-plot-format.md) | [Sisukord](index.md) | [Järgmine: Sepistamisülesanded ->](4-forging-assignments.md)

---

# Peatükk 3: Bitcoin-PoCX konsensus ja kaevandamisprotsess

Täielik tehniline spetsifikatsioon PoCX (uue põlvkonna mahtutõestus) konsensusmehhanismist ja kaevandamisprotsessist, mis on integreeritud Bitcoin Core'i.

---

## Sisukord

1. [Ülevaade](#ülevaade)
2. [Konsensuse arhitektuur](#konsensuse-arhitektuur)
3. [Kaevandamisprotsess](#kaevandamisprotsess)
4. [Ploki valideerimine](#ploki-valideerimine)
5. [Ülesannete süsteem](#ülesannete-süsteem)
6. [Võrgulevik](#võrgulevik)
7. [Tehnilised detailid](#tehnilised-detailid)

---

## Ülevaade

Bitcoin-PoCX implementeerib puhta mahtutõestuse konsensusmehhanismi täieliku asendusena Bitcoin'i tööst tuletatud tõestusele. See on uus ahel ilma tagasiühilduvuse nõueteta.

**Põhiomadused:**
- **Energiatõhus:** Kaevandamine kasutab eelgenereeritud graafikufaile arvutusräsimise asemel
- **Ajapaindega tähtajad:** Jaotuse teisendamine (eksponentsiaalne->hii-ruut) vähendab pikki plokke, parandab keskmisi plokiaegu
- **Ülesannete tugi:** Graafikuomanikud saavad delegeerida sepistamisõigusi teistele aadressidele
- **Natiivne C++ integratsioon:** Krüptograafilised algoritmid implementeeritud C++-s konsensuse valideerimiseks

**Kaevandamise voog:**
```
Väline kaevandaja -> get_mining_info -> Arvuta nonce -> submit_nonce ->
Sepistaja järjekord -> Tähtaja ootamine -> Ploki sepistamine -> Võrgulevik ->
Ploki valideerimine -> Ahela laiendamine
```

---

## Konsensuse arhitektuur

### Ploki struktuur

PoCX plokid laiendavad Bitcoin'i ploki struktuuri täiendavate konsensuse väljadega:

```cpp
struct PoCXProof {
    std::array<uint8_t, 32> seed;             // Graafiku seeme (32 baiti)
    std::array<uint8_t, 20> account_id;       // Graafiku aadress (20-baidine hash160)
    uint32_t compression;                     // Skaleerimistase (1-255)
    uint64_t nonce;                           // Kaevandamise nonce (64-bit)
    uint64_t quality;                         // Väidetav kvaliteet (PoC räsi väljund)
};

class CBlockHeader {
    // Standardsed Bitcoin väljad
    int32_t nVersion;
    uint256 hashPrevBlock;
    uint256 hashMerkleRoot;
    uint32_t nTime;

    // PoCX konsensuse väljad (asendavad nBits ja nNonce)
    int nHeight;                              // Ploki kõrgus (kontekstivaba valideerimine)
    uint256 generationSignature;              // Genereerimisallkiri (kaevandamise entroopia)
    uint64_t nBaseTarget;                     // Raskuse parameeter (pöördraskus)
    PoCXProof pocxProof;                      // Kaevandamise tõestus

    // Ploki allkirja väljad
    std::array<uint8_t, 33> vchPubKey;        // Kompresseeritud avalik võti (33 baiti)
    std::array<uint8_t, 65> vchSignature;     // Kompaktne allkiri (65 baiti)
};

class CBlock : public CBlockHeader {
    std::vector<CTransactionRef> vtx;         // Tehingud
};
```

**Märkus:** Allkiri (`vchSignature`) on välja arvatud ploki räsi arvutamisest, et takistada muudetavust.

**Implementatsioon:** `src/primitives/block.h`

### Genereerimisallkiri

Genereerimisallkiri loob kaevandamise entroopia ja takistab eelarvutusrünnakuid.

**Arvutamine:**
```
generationSignature = SHA256(eelmine_genereerimisallkiri || eelmise_kaevandaja_pubkey)
```

**Geneesisplokk:** Kasutab kodeeritud algset genereerimisallkirja

**Implementatsioon:** `src/pocx/node/node.cpp:GetNewBlockContext()`

### Baassihtmärk (raskus)

Baassihtmärk on raskuse pöördväärtus - kõrgemad väärtused tähendavad kergemat kaevandamist.

**Kohandamise algoritm:**
- Sihtplokkide aeg: 120 sekundit (mainnet), 1 sekund (regtest)
- Kohandamise intervall: Igal plokil
- Kasutab hiljutiste baassihtmärkide libisevat keskmist
- Piiratud, et takistada ekstreemseid raskuse kõikumisi

**Implementatsioon:** `src/consensus/params.h`, raskuse kohandamine ploki loomisel

### Skaleerimistasemed

PoCX toetab skaleeritavat tööst tuletatud tõestust graafikufailides läbi skaleerimistasemete (Xn).

**Dünaamilised piirid:**
```cpp
struct CompressionBounds {
    uint8_t nPoCXMinCompression;     // Minimaalne aktsepteeritud tase
    uint8_t nPoCXTargetCompression;  // Soovitatav tase
};
```

**Skaleerimise kasvu graafik:**
- Eksponentsiaalsed intervallid: Aastad 4, 12, 28, 60, 124 (poolnemised 1, 3, 7, 15, 31)
- Minimaalne skaleerimistase suureneb 1 võrra
- Sihtskaleermistase suureneb 1 võrra
- Säilitab ohutuspiiri graafiku loomise ja otsimise kulude vahel
- Maksimaalne skaleerimistase: 255

**Implementatsioon:** `src/pocx/algorithms/algorithms.h:GetPoCXCompressionBounds()`

---

## Kaevandamisprotsess

### 1. Kaevandusteabe hankimine

**RPC käsk:** `get_mining_info`

**Protsess:**
1. Kutsu `GetNewBlockContext(chainman)`, et hankida praegune plokiahela olek
2. Arvuta dünaamilised kompressiooni piirid praeguse kõrguse jaoks
3. Tagasta kaevandamisparameetrid

**Vastus:**
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

**Implementatsioon:** `src/pocx/rpc/mining.cpp:get_mining_info()`

**Märkused:**
- Vastuse genereerimisel lukke ei hoita
- Konteksti hankimine käsitleb `cs_main` sisemiselt
- `block_hash` on kaasas viitamiseks, kuid ei kasutata valideerimisel

### 2. Väline kaevandamine

**Välise kaevandaja kohustused:**
1. Loe graafikufaile kettalt
2. Arvuta scoop genereerimisallkirja ja kõrguse põhjal
3. Leia nonce parima tähtajaga
4. Esita sõlmele `submit_nonce` kaudu

**Graafikufaili vorming:**
- Põhineb POC2 vormingul (Burstcoin)
- Täiustatud turvaparandustega ja skaleeritavuse täiustustega
- Vaata omistust `CLAUDE.md`-s

**Kaevandaja implementatsioon:** Väline (nt põhineb Scavenger'il)

### 3. Nonce esitamine ja valideerimine

**RPC käsk:** `submit_nonce`

**Parameetrid:**
```
height, generation_signature, account_id, seed, nonce, quality (valikuline)
```

**Valideerimise voog (optimeeritud järjekord):**

#### Samm 1: Kiire vormingu valideerimine
```cpp
// Account ID: 40 hex tähemärki = 20 baiti
if (account_id.length() != 40 || !IsHex(account_id)) reject;

// Seed: 64 hex tähemärki = 32 baiti
if (seed.length() != 64 || !IsHex(seed)) reject;
```

#### Samm 2: Konteksti hankimine
```cpp
auto context = pocx::consensus::GetNewBlockContext(chainman);
// Tagastab: height, generation_signature, base_target, block_hash
```

**Lukustamine:** `cs_main` käsitletakse sisemiselt, RPC lõimes lukke ei hoita

#### Samm 3: Konteksti valideerimine
```cpp
// Kõrguse kontroll
if (height != context.height) reject;

// Genereerimisallkirja kontroll
if (submitted_gen_sig != context.generation_signature) reject;
```

#### Samm 4: Rahakoti verifitseerimine
```cpp
// Määra efektiivne allkirjastaja (arvestades ülesandeid)
effective_signer = GetEffectiveSigner(plot_address, height, view);

// Kontrolli, kas sõlmel on privaatvõti efektiivse allkirjastaja jaoks
if (!HaveAccountKey(effective_signer, wallet)) reject;
```

**Ülesannete tugi:** Graafikuomanik võib määrata sepistamisõigused teisele aadressile. Rahakotis peab olema võti efektiivse allkirjastaja jaoks, mitte tingimata graafikuomaniku jaoks.

#### Samm 5: Tõestuse valideerimine
```cpp
bool success = pocx_validate_block(
    generation_signature_hex,
    base_target,
    account_payload,     // 20 baiti
    block_height,
    nonce,
    seed,                // 32 baiti
    min_compression,
    max_compression,
    &result             // Väljund: quality, deadline
);
```

**Algoritm:**
1. Dekodeeri genereerimisallkiri hex-ist
2. Arvuta parim kvaliteet kompressioonivahemikus, kasutades SIMD-optimeeritud algoritme
3. Valideeri, et kvaliteet vastab raskusnõuetele
4. Tagasta töötlemata kvaliteediväärtus

**Implementatsioon:** `src/pocx/consensus/validation.cpp:pocx_validate_block()`

#### Samm 6: Ajapainde arvutamine
```cpp
// Töötlemata raskusega kohandatud tähtaeg (sekundites)
uint64_t deadline_seconds = quality / base_target;

// Ajapaindega sepistamisaeg (sekundites)
uint64_t forge_time = CalculateTimeBendedDeadline(
    quality, base_target, block_time
);
```

**Ajapainde valem:**
```
Y = scale * (X^(1/3))
kus:
  X = quality / base_target
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Eesmärk:** Teisendab eksponentsiaalse hii-ruut jaotuseks. Väga head lahendused sepistavad hiljem (võrgul on aega kettaid skaneerida), kehvad lahendused paranevad. Vähendab pikki plokke, säilitab 120s keskmise.

**Implementatsioon:** `src/pocx/algorithms/time_bending.cpp:CalculateTimeBendedDeadline()`

#### Samm 7: Sepistajale esitamine
```cpp
g_pocx_scheduler->SubmitNonce(
    account_id,
    seed,
    nonce,
    raw_quality,      // MITTE tähtaeg - arvutatakse sepistajal ümber
    height,
    generation_signature
);
```

**Järjekorrapõhine disain:**
- Esitamine õnnestub alati (lisatakse järjekorda)
- RPC tagastab kohe
- Töötaja lõim töötleb asünkroonselt

**Implementatsioon:** `src/pocx/rpc/mining.cpp:submit_nonce()`

### 4. Sepistaja järjekorra töötlemine

**Arhitektuur:**
- Üks püsiv töötaja lõim
- FIFO esitamise järjekord
- Lukuvaba sepistamise olek (ainult töötaja lõim)
- Pole pesastatud lukke (deadlock'i ennetamine)

**Töötaja lõime põhitsükkel:**
```cpp
while (!shutdown) {
    // 1. Kontrolli järjekorras esitamisi
    if (has_submission) {
        ProcessSubmission(submission);
        continue;
    }

    // 2. Oota tähtaega või uut esitamist
    if (has_forging_state) {
        WaitForDeadlineOrNewSubmission();
    } else {
        WaitForNewSubmission();
    }
}
```

**ProcessSubmission loogika:**
```cpp
1. Hangi värske kontekst: GetNewBlockContext(*chainman)

2. Aegumise kontrollid (vaikne loobumine):
   - Kõrguse mittevastavus -> loobu
   - Genereerimisallkirja mittevastavus -> loobu
   - Tipu ploki räsi muutunud (ümberkorraldus) -> lähtesta sepistamise olek

3. Kvaliteedi võrdlus:
   - Kui quality >= current_best -> loobu

4. Arvuta ajapaindega tähtaeg:
   deadline = CalculateTimeBendedDeadline(quality, base_target, block_time)

5. Uuenda sepistamise olekut:
   - Tühista olemasolev sepistamine (kui leiti parem)
   - Salvesta: account_id, seed, nonce, quality, deadline
   - Arvuta: forge_time = block_time + deadline_seconds
   - Salvesta tipu räsi ümberkorralduse tuvastamiseks
```

**Implementatsioon:** `src/pocx/mining/scheduler.cpp:ProcessSubmission()`

### 5. Tähtaja ootamine ja ploki sepistamine

**WaitForDeadlineOrNewSubmission:**

**Ootamise tingimused:**
```cpp
condition_variable.wait_until(forge_time, [&] {
    return shutdown ||
           !submission_queue.empty() ||
           forging_cancelled;
});
```

**Kui tähtaeg saabub - värske konteksti valideerimine:**
```cpp
1. Hangi praegune kontekst: GetNewBlockContext(*chainman)

2. Kõrguse valideerimine:
   if (forging_height != current_height) {
       reset_forging_state();
       return;
   }

3. Genereerimisallkirja valideerimine:
   if (forging_gen_sig != current_gen_sig) {
       reset_forging_state();
       return;
   }

4. Baassihtmärgi äärjuht:
   if (forging_base_target != current_base_target) {
       // Arvuta tähtaeg ümber uue baassihtmärgiga
       new_deadline = CalculateTimeBendedDeadline(quality, new_base_target, block_time);
       update_forge_time(new_deadline);
       return; // Oota uuesti
   }

5. Kõik kehtib -> ForgeBlock()
```

**ForgeBlock protsess:**

```cpp
1. Määra efektiivne allkirjastaja (ülesannete tugi):
   effective_signer = GetEffectiveSigner(plot_address, height, view);

2. Loo coinbase skript:
   coinbase_script = P2WPKH(effective_signer);  // Maksab efektiivsele allkirjastajale

3. Loo ploki mall:
   options.coinbase_output_script = coinbase_script;
   options.use_mempool = true;
   template = mining->createNewBlock(options);

4. Lisa PoCX tõestus:
   block.pocxProof.account_id = plot_address;    // Algne graafiku aadress
   block.pocxProof.seed = seed;
   block.pocxProof.nonce = nonce;

5. Arvuta Merkle juur ümber:
   block.hashMerkleRoot = BlockMerkleRoot(block);

6. Allkirjasta plokk:
   // Kasuta efektiivse allkirjastaja võtit (võib erineda graafikuomanikust)
   hash = PoCXBlockSignatureHash(block.GetHash());
   key.SignCompact(hash, signature);
   block.vchSignature = signature;
   block.vchPubKey = effective_signer_pubkey;

7. Esita ahelale:
   chainman->ProcessNewBlock(block, force=true, min_pow_checked=true);

8. Tulemuse käsitlemine:
   if (accepted) {
       log_success();
       reset_forging_state();  // Valmis järgmiseks plokiks
   } else {
       log_failure();
       reset_forging_state();
   }
```

**Implementatsioon:** `src/pocx/mining/scheduler.cpp:ForgeBlock()`

**Põhilised disainiotsused:**
- Coinbase maksab efektiivsele allkirjastajale (austab ülesandeid)
- Tõestus sisaldab algset graafiku aadressi (valideerimiseks)
- Allkiri efektiivse allkirjastaja võtmega (omandi tõestus)
- Malli loomine kaasab automaatselt mempool'i tehinguid

---

## Ploki valideerimine

### Sissetuleva ploki valideerimise voog

Kui plokk saadakse võrgust või esitatakse lokaalselt, läbib see valideerimise mitmes etapis:

### Etapp 1: Päise valideerimine (CheckBlockHeader)

**Kontekstivaba valideerimine:**

```cpp
static bool CheckBlockHeader(
    const CBlockHeader& block,
    BlockValidationState& state,
    const Consensus::Params& consensusParams,
    bool fCheckPOW = true
)
```

**PoCX valideerimine (kui ENABLE_POCX on defineeritud):**
```cpp
if (block.nHeight > 0 && fCheckPOW) {
    // Põhiline allkirja valideerimine (ülesannete tuge veel pole)
    if (!VerifyPoCXBlockCompactSignature(block)) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-pocx-sig");
    }
}
```

**Põhiline allkirja valideerimine:**
1. Kontrolli pubkey ja allkirja väljade olemasolu
2. Valideeri pubkey suurus (33 baiti kompresseeritud)
3. Valideeri allkirja suurus (65 baiti kompaktne)
4. Taasta pubkey allkirjast: `pubkey.RecoverCompact(hash, signature)`
5. Verifitseeri, et taastatud pubkey vastab salvestatud pubkey-le

**Implementatsioon:** `src/validation.cpp:CheckBlockHeader()`
**Allkirja loogika:** `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`

### Etapp 2: Ploki valideerimine (CheckBlock)

**Valideerib:**
- Merkle juure korrektsust
- Tehingute kehtivust
- Coinbase nõudeid
- Ploki suuruse piiranguid
- Standardseid Bitcoin konsensusreegleid

**Implementatsioon:** `src/consensus/validation.cpp:CheckBlock()`

### Etapp 3: Kontekstuaalne päise valideerimine (ContextualCheckBlockHeader)

**PoCX-spetsiifiline valideerimine:**

```cpp
#ifdef ENABLE_POCX
    // Samm 1: Valideeri genereerimisallkiri
    uint256 expected_gen_sig = CalculateGenerationSignature(pindexPrev);
    if (block.generationSignature != expected_gen_sig) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-gen-sig");
    }

    // Samm 2: Valideeri baassihtmärk
    uint64_t expected_base_target = CalculateNextBaseTarget(pindexPrev, block.nTime);
    if (block.nBaseTarget != expected_base_target) {
        return state.Invalid(BLOCK_INVALID_HEADER, "bad-diff");
    }

    // Samm 3: Valideeri mahtutõestus
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

    // Samm 4: Verifitseeri tähtaja ajastus
    uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
    if (result.deadline > elapsed_time) {
        return state.Invalid(BLOCK_INVALID_HEADER, "pocx-deadline-not-met");
    }
#endif
```

**Valideerimise sammud:**
1. **Genereerimisallkiri:** Peab vastama eelmisest plokist arvutatud väärtusele
2. **Baassihtmärk:** Peab vastama raskuse kohandamise arvutusele
3. **Skaleerimistase:** Peab vastama võrgu miinimumile (`compression >= min_compression`)
4. **Kvaliteedi väide:** Esitatud kvaliteet peab vastama tõestusest arvutatud kvaliteedile
5. **Mahtutõestus:** Krüptograafilise tõestuse valideerimine (SIMD-optimeeritud)
6. **Tähtaja ajastus:** Ajapaindega tähtaeg (`poc_time`) peab olema <= möödunud aeg

**Implementatsioon:** `src/validation.cpp:ContextualCheckBlockHeader()`

### Etapp 4: Ploki ühendamine (ConnectBlock)

**Täielik kontekstuaalne valideerimine:**

```cpp
#ifdef ENABLE_POCX
    // Laiendatud allkirja valideerimine ülesannete toega
    if (pindex->nHeight > 0 && !fJustCheck) {
        if (!VerifyPoCXBlockCompactSignature(block, view, pindex->nHeight)) {
            return state.Invalid(BLOCK_CONSENSUS, "bad-pocx-assignment-sig");
        }
    }
#endif
```

**Laiendatud allkirja valideerimine:**
1. Soorita põhiline allkirja valideerimine
2. Ekstrakteeri konto ID taastatud pubkey-st
3. Hangi efektiivne allkirjastaja graafiku aadressi jaoks: `GetEffectiveSigner(plot_address, height, view)`
4. Verifitseeri, et pubkey konto vastab efektiivsele allkirjastajale

**Ülesannete loogika:**
```cpp
std::array<uint8_t, 20> GetEffectiveSigner(
    const std::array<uint8_t, 20>& plotAddress,
    int nHeight,
    const CCoinsViewCache& view
) {
    auto assignment = view.GetForgingAssignment(plotAddress, nHeight);

    if (assignment.has_value() && assignment->IsActiveAtHeight(nHeight)) {
        return assignment->forgingAddress;  // Tagasta määratud allkirjastaja
    }

    return plotAddress;  // Ülesannet pole - graafikuomanik allkirjastab
}
```

**Implementatsioon:**
- Ühendamine: `src/validation.cpp:ConnectBlock()`
- Laiendatud valideerimine: `src/pocx/consensus/pocx.cpp:VerifyPoCXBlockCompactSignature()`
- Ülesannete loogika: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`

### Etapp 5: Ahela aktiveerimine

**ProcessNewBlock voog:**
```cpp
bool ProcessNewBlock(const std::shared_ptr<const CBlock>& block,
                    bool force_processing,
                    bool min_pow_checked,
                    bool* new_block)
{
    1. AcceptBlock -> Valideeri ja salvesta kettale
    2. ActivateBestChain -> Uuenda ahela tippu, kui see on parim ahel
    3. Teavita võrku uuest plokist
}
```

**Implementatsioon:** `src/validation.cpp:ProcessNewBlock()`

### Valideerimise kokkuvõte

**Täielik valideerimise tee:**
```
Ploki vastuvõtmine
    ↓
CheckBlockHeader (põhiline allkiri)
    ↓
CheckBlock (tehingud, merkle)
    ↓
ContextualCheckBlockHeader (gen sig, base target, PoC tõestus, tähtaeg)
    ↓
ConnectBlock (laiendatud allkiri ülesannetega, oleku üleminekud)
    ↓
ActivateBestChain (ümberkorralduste käsitlemine, ahela laiendamine)
    ↓
Võrgulevik
```

---

## Ülesannete süsteem

### Ülevaade

Ülesanded võimaldavad graafikuomanikel delegeerida sepistamisõigused teistele aadressidele, säilitades samal ajal graafikuomandi.

**Kasutusjuhud:**
- Basseinikaevandamine (graafikud määratakse basseini aadressile)
- Külm hoiustamine (kaevandamisvõti eraldi graafikuomandist)
- Mitme osapoolega kaevandamine (jagatud infrastruktuur)

### Ülesannete arhitektuur

**OP_RETURN-ainult disain:**
- Ülesandeid hoitakse OP_RETURN väljundites (pole UTXO-d)
- Pole kulutamisnõudeid (pole tolmu, pole tasusid hoidmise eest)
- Jälgitakse CCoinsViewCache laiendatud olekus
- Aktiveeritakse pärast viivitusperioodi (vaikimisi: 4 plokki)

**Ülesannete olekud:**
```cpp
enum class ForgingState : uint8_t {
    UNASSIGNED = 0,  // Ülesannet pole
    ASSIGNING = 1,   // Ülesanne ootab aktiveerimist (viivitusperiood)
    ASSIGNED = 2,    // Ülesanne aktiivne, sepistamine lubatud
    REVOKING = 3,    // Tühistamine ootab (viivitusperiood, endiselt aktiivne)
    REVOKED = 4      // Tühistamine lõppenud, ülesanne enam mitte aktiivne
};
```

### Ülesannete loomine

**Tehingu vorming:**
```cpp
Transaction {
    inputs: [any]  // Tõestab graafiku aadressi omandi
    outputs: [
        OP_RETURN <ASSIGN_MAGIC> <plot_address> <forging_address>
    ]
}
```

**Valideerimisreeglid:**
1. Sisend peab olema allkirjastatud graafikuomaniku poolt (tõestab omandi)
2. OP_RETURN sisaldab kehtivaid ülesande andmeid
3. Graafik peab olema UNASSIGNED või REVOKED
4. Pole duplikaatülesandeid ootamas mempool'is
5. Minimaalne tehingutasu makstud

**Aktiveerimine:**
- Ülesanne saab ASSIGNING oleku kinnitamise kõrgusel
- Saab ASSIGNED oleku pärast viivitusperioodi (4 plokki regtest, 30 plokki mainnet)
- Viivitus takistab kiireid ümberseadistusi plokkide võidujooksude ajal

**Implementatsioon:** `src/script/forging_assignment.h`, valideerimine ConnectBlock'is

### Ülesannete tühistamine

**Tehingu vorming:**
```cpp
Transaction {
    inputs: [any]  // Tõestab graafiku aadressi omandi
    outputs: [
        OP_RETURN <REVOKE_MAGIC> <plot_address>
    ]
}
```

**Tulemus:**
- Kohene oleku üleminek REVOKED-ile
- Graafikuomanik saab kohe sepistada
- Saab pärast luua uue ülesande

### Ülesannete valideerimine kaevandamise ajal

**Efektiivse allkirjastaja määramine:**
```cpp
// submit_nonce valideerimisel
effective_signer = GetEffectiveSigner(plot_address, height, view);
if (!HaveAccountKey(effective_signer, wallet)) reject;

// Ploki sepistamisel
coinbase_script = P2WPKH(effective_signer);  // Tasu läheb siia

// Ploki allkirjastamisel
signature = effective_signer_key.SignCompact(hash);  // Peab allkirjastama efektiivse allkirjastajaga
```

**Ploki valideerimine:**
```cpp
// VerifyPoCXBlockCompactSignature'is (laiendatud)
effective_signer = GetEffectiveSigner(proof.account_id, height, view);
pubkey_account = ExtractAccountIDFromPubKey(block.vchPubKey);
if (pubkey_account != effective_signer) reject;
```

**Põhiomadused:**
- Tõestus sisaldab alati algset graafiku aadressi
- Allkiri peab olema efektiivselt allkirjastajalt
- Coinbase maksab efektiivsele allkirjastajale
- Valideerimine kasutab ülesande olekut ploki kõrgusel

---

## Võrgulevik

### Ploki teadaanne

**Standardne Bitcoin P2P protokoll:**
1. Sepistatud plokk esitatakse `ProcessNewBlock()` kaudu
2. Plokk valideeritakse ja lisatakse ahelale
3. Võrgu teavitus: `GetMainSignals().BlockConnected()`
4. P2P kiht edastab ploki teistele sõlmedele

**Implementatsioon:** Standardne Bitcoin Core net_processing

### Ploki edastamine

**Kompaktsed plokid (BIP 152):**
- Kasutatakse tõhusaks ploki levitamiseks
- Algselt saadetakse ainult tehingu ID-d
- Partnerid küsivad puuduvaid tehinguid

**Täieliku ploki edastamine:**
- Varuvõimalus, kui kompaktsed plokid ebaõnnestuvad
- Täielikud ploki andmed edastatakse

### Ahela ümberkorraldused

**Ümberkorralduse käsitlemine:**
```cpp
// Sepistaja töötaja lõimes
if (current_tip_hash != stored_tip_hash) {
    // Ahela ümberkorraldus tuvastatud
    reset_forging_state();
    log("Ahela tipp muutus, lähtestan sepistamise");
}
```

**Plokiahela tasemel:**
- Standardne Bitcoin Core ümberkorralduse käsitlemine
- Parim ahel määratakse chainwork'i järgi
- Lahtiühendatud plokid tagastatakse mempool'i

---

## Tehnilised detailid

### Deadlock'i ennetamine

**ABBA deadlock'i muster (ennetatud):**
```
Lõim A: cs_main -> cs_wallet
Lõim B: cs_wallet -> cs_main
```

**Lahendus:**
1. **submit_nonce:** Null cs_main kasutust
   - `GetNewBlockContext()` käsitleb lukustamist sisemiselt
   - Kogu valideerimine enne sepistajale esitamist

2. **Sepistaja:** Järjekorrapõhine arhitektuur
   - Üks töötaja lõim (pole lõimede liitumisi)
   - Värske kontekst igal juurdepääsul
   - Pole pesastatud lukke

3. **Rahakoti kontrollid:** Tehakse enne kulukaid operatsioone
   - Varane tagasilükkamine, kui võtit pole
   - Eraldi plokiahela oleku juurdepääsust

### Jõudluse optimeerimised

**Kiire ebaõnnestumine valideerimisel:**
```cpp
1. Vormingu kontrollid (kohesed)
2. Konteksti valideerimine (kerge)
3. Rahakoti verifitseerimine (lokaalne)
4. Tõestuse valideerimine (kulukas SIMD)
```

**Üks konteksti hankimine:**
- Üks `GetNewBlockContext()` kutse esitamise kohta
- Vahemälu tulemused mitmeks kontrolliks
- Pole korduvaid cs_main haaramisi

**Järjekorra tõhusus:**
- Kerge esitamise struktuur
- Pole base_target/deadline'i järjekorras (arvutatakse värskelt ümber)
- Minimaalne mälu jalajälg

### Aegumise käsitlemine

**"Lihtne" sepistaja disain:**
- Pole plokiahela sündmuste tellimusi
- Laisk valideerimine vajadusel
- Vaikne loobumine aegunud esitamistest

**Eelised:**
- Lihtne arhitektuur
- Pole keerukat sünkroniseerimist
- Vastupidav äärjuhtudele

**Käsitletud äärjuhud:**
- Kõrguse muutused -> loobu
- Genereerimisallkirja muutused -> loobu
- Baassihtmärgi muutused -> arvuta tähtaeg ümber
- Ümberkorraldused -> lähtesta sepistamise olek

### Krüptograafilised detailid

**Genereerimisallkiri:**
```cpp
SHA256(eelmine_genereerimisallkiri || eelmise_kaevandaja_pubkey_33baiti)
```

**Ploki allkirja räsi:**
```cpp
hash = SHA256(SHA256("POCX Signed Block:\n" || block_hash_hex))
```

**Kompaktne allkirja vorming:**
- 65 baiti: [taastamise_id][r][s]
- Võimaldab avaliku võtme taastamist
- Kasutatakse ruumi kokkuhoiuks

**Konto ID:**
- 20-baidine HASH160 kompresseeritud avalikust võtmest
- Vastab Bitcoin'i aadressi vormingutele (P2PKH, P2WPKH)

### Tulevased täiustused

**Dokumenteeritud piirangud:**
1. Pole jõudluse mõõdikuid (esitamise määrad, tähtaegade jaotused)
2. Pole detailset vigade kategoriseerimist kaevandajatele
3. Piiratud sepistaja oleku päringud (praegune tähtaeg, järjekorra sügavus)

**Võimalikud parandused:**
- RPC sepistaja oleku jaoks
- Mõõdikud kaevandamise tõhususeks
- Täiustatud logimine silumiseks
- Basseini protokolli tugi

---

## Koodi viited

**Põhiimplementatsioonid:**
- RPC liides: `src/pocx/rpc/mining.cpp`
- Sepistaja järjekord: `src/pocx/mining/scheduler.cpp`
- Konsensuse valideerimine: `src/pocx/consensus/validation.cpp`
- Tõestuse valideerimine: `src/pocx/consensus/pocx.cpp`
- Ajapainde: `src/pocx/algorithms/time_bending.cpp`
- Ploki valideerimine: `src/validation.cpp` (CheckBlockHeader, ConnectBlock)
- Ülesannete loogika: `src/pocx/consensus/validation.cpp:GetEffectiveSigner()`
- Konteksti haldamine: `src/pocx/node/node.cpp:GetNewBlockContext()`

**Andmestruktuurid:**
- Ploki vorming: `src/primitives/block.h`
- Konsensuse parameetrid: `src/consensus/params.h`
- Ülesannete jälgimine: `src/coins.h` (CCoinsViewCache laiendused)

---

## Lisa: Algoritmide spetsifikatsioonid

### Ajapainde valem

**Matemaatiline definitsioon:**
```
deadline_seconds = quality / base_target  (töötlemata)

time_bended_deadline = scale * (deadline_seconds)^(1/3)

kus:
  scale = block_time / (cbrt(block_time) * Gamma(4/3))
  Gamma(4/3) ≈ 0.892979511
```

**Implementatsioon:**
- Püsipunktaritmeetika (Q42 vorming)
- Ainult täisarvu kuupjuure arvutamine
- Optimeeritud 256-bit aritmeetikaks

### Kvaliteedi arvutamine

**Protsess:**
1. Genereeri scoop genereerimisallkirjast ja kõrgusest
2. Loe graafiku andmed arvutatud scoop'i jaoks
3. Räsi: `SHABAL256(generation_signature || scoop_data)`
4. Testi skaleerimistasemeid min-ist max-ini
5. Tagasta parim leitud kvaliteet

**Skaleerimine:**
- Tase X0: POC2 baastase (teoreetiline)
- Tase X1: XOR-transponeeri baastase
- Tase Xn: 2^(n-1) × X1 töö manustatud
- Kõrgem skaleerimine = rohkem graafiku genereerimise tööd

### Baassihtmärgi kohandamine

**Kohandamine igal plokil:**
1. Arvuta hiljutiste baassihtmärkide libisev keskmine
2. Arvuta tegelik ajavahemik vs siht-ajavahemik libiseva akna jaoks
3. Kohanda baassihtmärki proportsionaalselt
4. Piira, et takistada ekstreemseid kõikumisi

**Valem:**
```
avg_base_target = moving_average(hiljutised baassihtmärgid)
adjustment_factor = actual_timespan / target_timespan
new_base_target = avg_base_target * adjustment_factor
new_base_target = clamp(new_base_target, min, max)
```

---

*See dokumentatsioon kajastab täielikku PoCX konsensuse implementatsiooni oktoobri 2025 seisuga.*

---

[<- Eelmine: Graafikuvorming](2-plot-format.md) | [Sisukord](index.md) | [Järgmine: Sepistamisülesanded ->](4-forging-assignments.md)
