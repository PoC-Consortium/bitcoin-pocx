[← Nakaraan: Mga Forging Assignment](4-forging-assignments.md) | [📘 Talaan ng mga Nilalaman](index.md) | [Susunod: Mga Parameter ng Network →](6-network-parameters.md)

---

# Kabanata 5: Sinkronisasyon ng Oras at Seguridad

## Pangkalahatang-tanaw

Ang consensus ng PoCX ay nangangailangan ng tumpak na sinkronisasyon ng oras sa buong network. Idokumento ng kabanatang ito ang mga mekanismo ng seguridad na may kinalaman sa oras, toleransya sa clock drift, at pag-uugali ng defensive forging.

**Mga Pangunahing Mekanismo**:
- 15-segundong future tolerance para sa mga block timestamp
- 10-segundong sistema ng babala sa clock drift
- Defensive forging (anti-clock manipulation)
- Integrasyon ng Time Bending algorithm

---

## Talaan ng mga Nilalaman

1. [Mga Kinakailangan sa Sinkronisasyon ng Oras](#mga-kinakailangan-sa-sinkronisasyon-ng-oras)
2. [Pagtukoy ng Clock Drift at mga Babala](#pagtukoy-ng-clock-drift-at-mga-babala)
3. [Mekanismo ng Defensive Forging](#mekanismo-ng-defensive-forging)
4. [Pagsusuri ng Banta sa Seguridad](#pagsusuri-ng-banta-sa-seguridad)
5. [Mga Pinakamahusay na Kasanayan para sa mga Tagapagpatakbo ng Node](#mga-pinakamahusay-na-kasanayan-para-sa-mga-tagapagpatakbo-ng-node)

---

## Mga Kinakailangan sa Sinkronisasyon ng Oras

### Mga Constant at Parameter

**Pagsasaayos ng Bitcoin-PoCX:**
```cpp
// src/chain.h:31
static constexpr int64_t MAX_FUTURE_BLOCK_TIME = 15;  // 15 segundo

// src/node/timeoffsets.h:27
static constexpr std::chrono::seconds WARN_THRESHOLD{10};  // 10 segundo
```

### Mga Validation Check

**Validation ng Block Timestamp** (`src/validation.cpp:4547-4561`):
```cpp
// 1. Monotonic check: timestamp >= nakaraang block timestamp
if (block.nTime < pindexPrev->nTime) {
    return state.Invalid("time-too-old");
}

// 2. Future check: timestamp <= ngayon + 15 segundo
if (block.Time() > NodeClock::now() + std::chrono::seconds{MAX_FUTURE_BLOCK_TIME}) {
    return state.Invalid("time-too-new");
}

// 3. Deadline check: lumipas na oras >= deadline
uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
if (result.deadline > elapsed_time) {
    return state.Invalid("bad-pocx-timing");
}
```

### Talahanayan ng Epekto ng Clock Drift

| Clock Offset | Makakapag-sync? | Makakapag-mine? | Katayuan ng Validation | Kompetitibong Epekto |
|--------------|-----------|-----------|-------------------|-------------------|
| -30s mabagal | ❌ HINDI - Nabigo ang future check | N/A | **PATAY NA NODE** | Hindi makalahok |
| -14s mabagal | ✅ Oo | ✅ Oo | Huli ang forging, pumasa ang validation | Talo sa mga karera |
| 0s perpekto | ✅ Oo | ✅ Oo | Optimal | Optimal |
| +14s mabilis | ✅ Oo | ✅ Oo | Maaga ang forging, pumasa ang validation | Panalo sa mga karera |
| +16s mabilis | ✅ Oo | ❌ Nabigo ang future check | Hindi makakapag-propagate ng mga block | Makakapag-sync, hindi makakapag-mine |

**Pangunahing Insight**: Ang 15-segundong window ay simetriko para sa pakikilahok (±14.9s), ngunit ang mabilis na mga orasan ay nagbibigay ng hindi patas na kompetitibong kalamangan sa loob ng toleransya.

### Integrasyon ng Time Bending

Binabago ng Time Bending algorithm (na detalyado sa [Kabanata 3](3-consensus-and-mining.md#time-bending-calculation)) ang mga raw deadline gamit ang cube root:

```
time_bended_deadline = scale × (deadline_seconds)^(1/3)
```

**Pakikipag-ugnayan sa Clock Drift**:
- Ang mas mahusay na mga solusyon ay nag-fo-forge nang mas maaga (ang cube root ay nagpapalaki ng mga pagkakaiba sa kalidad)
- Ang clock drift ay nakakaapekto sa oras ng forging kumpara sa network
- Ang defensive forging ay nagsisiguro ng kompetisyong batay sa kalidad sa kabila ng timing variance

---

## Pagtukoy ng Clock Drift at mga Babala

### Sistema ng Babala

Sinusubaybayan ng Bitcoin-PoCX ang time offset sa pagitan ng lokal na node at mga network peer.

**Mensahe ng Babala** (kapag ang drift ay lumampas ng 10 segundo):
> "Ang petsa at oras ng iyong computer ay mukhang higit sa 10 segundo ang layo sa sync sa network, maaari itong humantong sa pagkabigo ng PoCX consensus. Mangyaring suriin ang orasan ng iyong sistema."

**Implementasyon**: `src/node/timeoffsets.cpp`

### Rasyonal ng Disenyo

**Bakit 10 segundo?**
- Nagbibigay ng 5-segundong safety buffer bago ang 15-segundong tolerance limit
- Mas mahigpit kaysa sa default ng Bitcoin Core (10 minuto)
- Angkop para sa mga kinakailangan sa timing ng PoC

**Preventive Approach**:
- Maagang babala bago ang kritikal na pagkabigo
- Pinapayagan ang mga operator na ayusin ang mga isyu nang proactive
- Binabawasan ang network fragmentation mula sa mga time-related na pagkabigo

---

## Mekanismo ng Defensive Forging

### Ano Ito

Ang defensive forging ay isang standard na pag-uugali ng miner sa Bitcoin-PoCX na nag-aalis ng mga kalamangan batay sa timing sa produksyon ng block. Kapag ang iyong miner ay nakatanggap ng nakikipagkumpitensyang block sa parehong taas, awtomatiko nitong sinusuri kung mayroon kang mas mahusay na solusyon. Kung gayon, agad nitong i-forge ang iyong block, tinitiyak ang kompetisyong batay sa kalidad sa halip na kompetisyong batay sa clock-manipulation.

### Ang Problema

Pinapayagan ng consensus ng PoCX ang mga block na may mga timestamp hanggang 15 segundo sa hinaharap. Ang toleransyang ito ay kinakailangan para sa pandaigdigang sinkronisasyon ng network. Gayunpaman, lumilikha ito ng pagkakataon para sa clock manipulation:

**Walang Defensive Forging:**
- Miner A: Tamang oras, quality 800 (mas mabuti), naghihintay ng tamang deadline
- Miner B: Mabilis na orasan (+14s), quality 1000 (mas masama), nag-forge ng 14 segundo nang maaga
- Resulta: Panalo si Miner B sa karera sa kabila ng mas mababang proof-of-capacity work

**Ang Isyu:** Ang clock manipulation ay nagbibigay ng kalamangan kahit na may mas masamang kalidad, sinasaktan ang prinsipyo ng proof-of-capacity.

### Ang Solusyon: Dalawang-Layer na Depensa

#### Layer 1: Babala sa Clock Drift (Preventive)

Sinusubaybayan ng Bitcoin-PoCX ang time offset sa pagitan ng iyong node at mga network peer. Kung ang iyong orasan ay lumihis ng higit sa 10 segundo mula sa network consensus, makakatanggap ka ng babala na nag-aalerto sa iyo na ayusin ang mga isyu sa orasan bago sila magdulot ng mga problema.

#### Layer 2: Defensive Forging (Reactive)

Kapag may ibang miner na nag-publish ng block sa parehong taas na minumina mo:

1. **Pagtukoy**: Natukoy ng iyong node ang kompetisyon sa parehong taas
2. **Validation**: Kinukuha at vine-validate ang kalidad ng nakikipagkumpitensyang block
3. **Paghahambing**: Sinusuri kung mas mabuti ang iyong kalidad
4. **Tugon**: Kung mas mabuti, agad na i-forge ang iyong block

**Resulta:** Natatanggap ng network ang parehong block at pinipili ang may mas mahusay na kalidad sa pamamagitan ng standard fork resolution.

### Paano Ito Gumagana

#### Senaryo: Kompetisyon sa Parehong Taas

```
Oras 150s: Miner B (orasan +10s) nag-forge na may quality 1000
           → Ang block timestamp ay nagpapakita ng 160s (10s sa hinaharap)

Oras 150s: Nakatanggap ang iyong node ng block ni Miner B
           → Natukoy: parehong taas, quality 1000
           → Mayroon ka: quality 800 (mas mabuti!)
           → Aksyon: Mag-forge kaagad na may tamang timestamp (150s)

Oras 152s: Vine-validate ng network ang parehong block
           → Parehong valid (sa loob ng 15s tolerance)
           → Panalo ang Quality 800 (mas mababa = mas mabuti)
           → Ang iyong block ang nagiging chain tip
```

#### Senaryo: Tunay na Reorg

```
Ang iyong mining height 100, nag-publish ang kalaban ng block 99
→ Hindi kompetisyon sa parehong taas
→ HINDI na-trigger ang defensive forging
→ Nagpapatuloy ang normal na reorg handling
```

### Mga Benepisyo

**Zero na Insentibo para sa Clock Manipulation**
- Ang mabilis na mga orasan ay tumutulong lamang kung mayroon ka na ng pinakamahusay na kalidad
- Ang clock manipulation ay nagiging walang saysay sa ekonomiya

**Ipinatutupad ang Kompetisyong Batay sa Kalidad**
- Pinipilit ang mga miner na makipagkumpitensya sa aktwal na proof-of-capacity work
- Pinapanatili ang integridad ng PoCX consensus

**Seguridad ng Network**
- Lumalaban sa mga timing-based na gaming strategy
- Walang kinakailangang pagbabago sa consensus - purong pag-uugali ng miner

**Ganap na Awtomatiko**
- Walang kinakailangang configuration
- Na-trigger lamang kung kinakailangan
- Standard na pag-uugali sa lahat ng Bitcoin-PoCX node

### Mga Trade-off

**Minimal na Pagtaas ng Orphan Rate**
- Sinadya - ang mga attack block ay nagiging orphan
- Nangyayari lamang sa panahon ng mga aktwal na pagtatangka ng clock manipulation
- Likas na resulta ng quality-based fork resolution

**Maikling Kompetisyon ng Network**
- Sandaling nakakakita ang network ng dalawang nakikipagkumpitensyang block
- Naresolba sa ilang segundo sa pamamagitan ng standard validation
- Parehong pag-uugali sa sabay-sabay na mining sa Bitcoin

### Mga Teknikal na Detalye

**Epekto sa Performance:** Minimal
- Na-trigger lamang sa kompetisyon sa parehong taas
- Gumagamit ng in-memory data (walang disk I/O)
- Ang validation ay nagkukumpleto sa loob ng mga millisecond

**Paggamit ng Mapagkukunan:** Minimal
- ~20 linya ng core logic
- Ginagamit ulit ang kasalukuyang validation infrastructure
- Isang lock acquisition

**Compatibility:** Buo
- Walang mga pagbabago sa consensus rule
- Gumagana sa lahat ng mga tampok ng Bitcoin Core
- Opsyonal na pagsubaybay sa pamamagitan ng mga debug log

**Katayuan**: Aktibo sa lahat ng Bitcoin-PoCX release
**Unang Ipinakilala**: 2025-10-10

---

## Pagsusuri ng Banta sa Seguridad

### Fast Clock Attack (Na-mitigate ng Defensive Forging)

**Attack Vector**:
Ang isang miner na may orasang **+14s nang maaga** ay maaaring:
1. Makatanggap ng mga block nang normal (mukhang luma sa kanila)
2. Mag-forge ng mga block kaagad kapag lumipas ang deadline
3. Mag-broadcast ng mga block na mukhang 14s "maaga" sa network
4. **Tinatanggap ang mga block** (sa loob ng 15s tolerance)
5. **Panalong mga karera** laban sa mga matapat na miner

**Epekto Nang Walang Defensive Forging**:
Ang kalamangan ay limitado sa 14.9 segundo (hindi sapat upang laktawan ang makabuluhang PoC work), ngunit nagbibigay ng consistent na edge sa mga block race.

**Mitigation (Defensive Forging)**:
- Nakita ng mga matapat na miner ang kompetisyon sa parehong taas
- Inihambing ang mga quality value
- Agad na nag-forge kung mas mabuti ang kalidad
- **Resulta**: Ang mabilis na orasan ay tumutulong lamang kung mayroon ka na ng pinakamahusay na kalidad
- **Insentibo**: Zero - ang clock manipulation ay nagiging walang saysay sa ekonomiya

### Slow Clock Failure (Kritikal)

**Failure Mode**:
Ang isang node na **>15s huli** ay katastropiko:
- Hindi ma-validate ang mga incoming block (nabigo ang future check)
- Nagiging isolated mula sa network
- Hindi makakapag-mine o makakapag-sync

**Mitigation**:
- Ang malakas na babala sa 10s drift ay nagbibigay ng 5-segundong buffer bago ang kritikal na pagkabigo
- Maaaring ayusin ng mga operator ang mga isyu sa orasan nang proactive
- Ang malinaw na mga error message ay gumagabay sa troubleshooting

---

## Mga Pinakamahusay na Kasanayan para sa mga Tagapagpatakbo ng Node

### Pag-setup ng Sinkronisasyon ng Oras

**Inirerekomendang Configuration**:
1. **I-enable ang NTP**: Gamitin ang Network Time Protocol para sa awtomatikong sinkronisasyon
   ```bash
   # Linux (systemd-timesyncd)
   sudo timedatectl set-ntp true

   # Suriin ang katayuan
   timedatectl status
   ```

2. **I-verify ang Katumpakan ng Orasan**: Regular na suriin ang time offset
   ```bash
   # Suriin ang katayuan ng NTP sync
   ntpq -p

   # O gamit ang chrony
   chronyc tracking
   ```

3. **Subaybayan ang mga Babala**: Bantayan ang mga babala sa clock drift ng Bitcoin-PoCX sa mga log

### Para sa mga Miner

**Walang Kinakailangang Aksyon**:
- Ang tampok ay laging aktibo
- Gumagana nang awtomatiko
- Panatilihin lang ang iyong system clock na tumpak

**Mga Pinakamahusay na Kasanayan**:
- Gamitin ang NTP time synchronization
- Subaybayan ang mga babala sa clock drift
- Agad na tugunan ang mga babala kung lumitaw

**Inaasahang Pag-uugali**:
- Solo mining: Bihirang ma-trigger ang defensive forging (walang kompetisyon)
- Network mining: Pinoprotektahan laban sa mga pagtatangka ng clock manipulation
- Transparent na operasyon: Karamihan ng mga miner ay hindi napapansin ito

### Troubleshooting

**Babala: "10 segundo ang layo sa sync"**
- Aksyon: Suriin at ayusin ang sinkronisasyon ng system clock
- Epekto: 5-segundong buffer bago ang kritikal na pagkabigo
- Mga Tool: NTP, chrony, systemd-timesyncd

**Error: "time-too-new" sa mga incoming block**
- Sanhi: Ang iyong orasan ay >15 segundo mabagal
- Epekto: Hindi ma-validate ang mga block, isolated ang node
- Ayos: I-sync kaagad ang system clock

**Error: Hindi makapag-propagate ng mga forged block**
- Sanhi: Ang iyong orasan ay >15 segundo mabilis
- Epekto: Ni-reject ng network ang mga block
- Ayos: I-sync kaagad ang system clock

---

## Mga Desisyon sa Disenyo at Rasyonal

### Bakit 15-Segundong Toleransya?

**Rasyonal**:
- Ang variable deadline timing ng Bitcoin-PoCX ay hindi gaanong kritikal sa oras kaysa sa fixed-timing consensus
- Ang 15s ay nagbibigay ng sapat na proteksyon habang pinipigilan ang network fragmentation

**Mga Trade-off**:
- Mas mahigpit na toleransya = mas maraming network fragmentation mula sa menor na drift
- Mas maluwag na toleransya = mas maraming pagkakataon para sa mga timing attack
- 15s ang nagbabalanse ng seguridad at tibay

### Bakit 10-Segundong Babala?

**Rasyonal**:
- Nagbibigay ng 5-segundong safety buffer
- Mas angkop para sa PoC kaysa sa 10-minutong default ng Bitcoin
- Pinapayagan ang mga proactive na pag-aayos bago ang kritikal na pagkabigo

### Bakit Defensive Forging?

**Problemang Tinutugunan**:
- Ang 15-segundong toleransya ay nagpapagana ng fast-clock advantage
- Ang quality-based consensus ay maaaring sirain ng timing manipulation

**Mga Benepisyo ng Solusyon**:
- Zero-cost defense (walang mga pagbabago sa consensus)
- Awtomatikong operasyon
- Inaalis ang attack incentive
- Pinapanatili ang mga prinsipyo ng proof-of-capacity

### Bakit Walang Intra-Network Time Synchronization?

**Rasyonal ng Seguridad**:
- Inalis ng modernong Bitcoin Core ang peer-based time adjustment
- Vulnerable sa mga Sybil attack sa perceived network time
- Sinasadyang iwasan ng PoCX ang pag-asa sa mga network-internal time source
- Ang system clock ay mas mapagkakatiwalaan kaysa sa peer consensus
- Dapat mag-synchronize ang mga operator gamit ang NTP o katumbas na external time source
- Sinusubaybayan ng mga node ang kanilang sariling drift at naglalabas ng mga babala kung ang lokal na orasan ay lumilihis mula sa mga kamakailang block timestamp

---

## Mga Sanggunian ng Implementasyon

**Mga Core File**:
- Time validation: `src/validation.cpp:4547-4561`
- Future tolerance constant: `src/chain.h:31`
- Warning threshold: `src/node/timeoffsets.h:27`
- Time offset monitoring: `src/node/timeoffsets.cpp`
- Defensive forging: `src/pocx/mining/scheduler.cpp`

**Mga Kaugnay na Dokumentasyon**:
- Time Bending algorithm: [Kabanata 3: Consensus at Mining](3-consensus-and-mining.md#time-bending-calculation)
- Block validation: [Kabanata 3: Block Validation](3-consensus-and-mining.md#block-validation)

---

**Nabuo**: 2025-10-10
**Katayuan**: Kumpletong Implementasyon
**Saklaw**: Mga kinakailangan sa sinkronisasyon ng oras, paghawak ng clock drift, defensive forging

---

[← Nakaraan: Mga Forging Assignment](4-forging-assignments.md) | [📘 Talaan ng mga Nilalaman](index.md) | [Susunod: Mga Parameter ng Network →](6-network-parameters.md)
