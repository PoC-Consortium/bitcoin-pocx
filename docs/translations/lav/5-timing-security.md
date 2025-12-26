[← Iepriekšējā: Kalšanas piešķīrumi](4-forging-assignments.md) | [📘 Satura rādītājs](index.md) | [Nākamā: Tīkla parametri →](6-network-parameters.md)

---

# 5. nodaļa: Laika sinhronizācija un drošība

## Pārskats

PoCX konsensam nepieciešama precīza laika sinhronizācija visā tīklā. Šī nodaļa dokumentē ar laiku saistītos drošības mehānismus, pulksteņa nobīdes toleranci un aizsardzības kalšanas uzvedību.

**Galvenie mehānismi**:
- 15 sekunžu nākotnes tolerance bloku laikspiedogiem
- 10 sekunžu pulksteņa nobīdes brīdinājuma sistēma
- Aizsardzības kalšana (pretpulksteņa manipulācija)
- Laika līkumo algoritma integrācija

---

## Satura rādītājs

1. [Laika sinhronizācijas prasības](#laika-sinhronizācijas-prasības)
2. [Pulksteņa nobīdes noteikšana un brīdinājumi](#pulksteņa-nobīdes-noteikšana-un-brīdinājumi)
3. [Aizsardzības kalšanas mehānisms](#aizsardzības-kalšanas-mehānisms)
4. [Drošības draudu analīze](#drošības-draudu-analīze)
5. [Labākā prakse mezglu operatoriem](#labākā-prakse-mezglu-operatoriem)

---

## Laika sinhronizācijas prasības

### Konstantes un parametri

**Bitcoin-PoCX konfigurācija:**
```cpp
// src/chain.h:31
static constexpr int64_t MAX_FUTURE_BLOCK_TIME = 15;  // 15 sekundes

// src/node/timeoffsets.h:27
static constexpr std::chrono::seconds WARN_THRESHOLD{10};  // 10 sekundes
```

### Validācijas pārbaudes

**Bloka laikspiedoga validācija** (`src/validation.cpp:4547-4561`):
```cpp
// 1. Monotonā pārbaude: laikspiedogs >= iepriekšējā bloka laikspiedogs
if (block.nTime < pindexPrev->nTime) {
    return state.Invalid("time-too-old");
}

// 2. Nākotnes pārbaude: laikspiedogs <= tagad + 15 sekundes
if (block.Time() > NodeClock::now() + std::chrono::seconds{MAX_FUTURE_BLOCK_TIME}) {
    return state.Invalid("time-too-new");
}

// 3. Termiņa pārbaude: pagājušais laiks >= termiņš
uint32_t elapsed_time = block.nTime - pindexPrev->nTime;
if (result.deadline > elapsed_time) {
    return state.Invalid("bad-pocx-timing");
}
```

### Pulksteņa nobīdes ietekmes tabula

| Pulksteņa nobīde | Var sinhronizēties? | Var kalnrūpniecībā? | Validācijas statuss | Konkurences efekts |
|--------------|-----------|-----------|-------------------|-------------------|
| -30s lēns | ❌ NĒ - Nākotnes pārbaude neizdodas | Nav piemerots | **MIRIS MEZGLS** | Nevar piedalīties |
| -14s lēns | ✅ Jā | ✅ Jā | Vēla kalšana, iziet validāciju | Zaudē sacensībās |
| 0s perfekts | ✅ Jā | ✅ Jā | Optimāls | Optimāls |
| +14s ātrs | ✅ Jā | ✅ Jā | Agrīna kalšana, iziet validāciju | Uzvar sacensībās ⚠️ |
| +16s ātrs | ✅ Jā | ❌ Nākotnes pārbaude neizdodas | Nevar izplatīt blokus | Var sinhronizēties, nevar kalnrūpniecībā |

**Galvenā atziņa**: 15 sekunžu logs ir simetrisks dalībai (±14.9s), bet ātri pulksteņi nodrošina negodīgu konkurences priekšrocību tolerances ietvaros.

### Laika līkumo integrācija

Laika līkumo algoritms (detalizēts [3. nodaļā](3-consensus-and-mining.md#laika-līkumo-aprēķins)) transformē neapstrādātos termiņus, izmantojot kubsakni:

```
time_bended_deadline = skala × (deadline_seconds)^(1/3)
```

**Mijiedarbība ar pulksteņa nobīdi**:
- Labāki risinājumi tiek kalti ātrāk (kubsakne pastiprina kvalitātes atšķirības)
- Pulksteņa nobīde ietekmē kalšanas laiku attiecībā pret tīklu
- Aizsardzības kalšana nodrošina uz kvalitāti balstītu konkurenci, neskatoties uz laika dispersiju

---

## Pulksteņa nobīdes noteikšana un brīdinājumi

### Brīdinājumu sistēma

Bitcoin-PoCX uzrauga laika nobīdi starp lokālo mezglu un tīkla vienaudžiem.

**Brīdinājuma ziņojums** (kad nobīde pārsniedz 10 sekundes):
> "Jūsu datora datums un laiks šķiet vairāk nekā 10 sekundes ārpus sinhronizācijas ar tīklu, tas var novest pie PoCX konsensa kļūmes. Lūdzu, pārbaudiet savu sistēmas pulksteni."

**Implementācija**: `src/node/timeoffsets.cpp`

### Dizaina pamatojums

**Kāpēc 10 sekundes?**
- Nodrošina 5 sekunžu drošības buferi pirms 15 sekunžu tolerances robežas
- Stingrāks nekā Bitcoin Core noklusējums (10 minūtes)
- Piemērots PoC laika prasībām

**Preventīvā pieeja**:
- Agrīns brīdinājums pirms kritiskas kļūmes
- Ļauj operatoriem proaktīvi novērst problēmas
- Samazina tīkla fragmentāciju no ar laiku saistītām kļūmēm

---

## Aizsardzības kalšanas mehānisms

### Kas tas ir

Aizsardzības kalšana ir standarta kalnraču uzvedība Bitcoin-PoCX, kas novērš uz laiku balstītas priekšrocības bloku ražošanā. Kad jūsu kalnracis saņem konkurējošu bloku tajā pašā augstumā, tas automātiski pārbauda, vai jums ir labāks risinājums. Ja tā, tas nekavējoties kalš jūsu bloku, nodrošinot uz kvalitāti balstītu konkurenci, nevis uz pulksteņa manipulāciju balstītu konkurenci.

### Problēma

PoCX konsensus ļauj blokus ar laikspiedogiem līdz 15 sekundēm nākotnē. Šī tolerance ir nepieciešama globālai tīkla sinhronizācijai. Tomēr tā rada iespēju pulksteņa manipulācijai:

**Bez aizsardzības kalšanas:**
- Kalnracis A: Pareizs laiks, kvalitāte 800 (labāka), gaida pienācīgu termiņu
- Kalnracis B: Ātrs pulkstenis (+14s), kvalitāte 1000 (sliktāka), kalš 14 sekundes agrāk
- Rezultāts: Kalnracis B uzvar sacensībās, neraugoties uz zemāku jaudas pierādījuma darbu

**Problēma:** Pulksteņa manipulācija nodrošina priekšrocību pat ar sliktāku kvalitāti, graujot jaudas pierādījuma principu.

### Risinājums: Divslāņu aizsardzība

#### 1. slānis: Pulksteņa nobīdes brīdinājums (preventīvs)

Bitcoin-PoCX uzrauga laika nobīdi starp jūsu mezglu un tīkla vienaudžiem. Ja jūsu pulkstenis novirzās vairāk nekā 10 sekundes no tīkla konsensa, jūs saņemat brīdinājumu, kas brīdina labot pulksteņa problēmas pirms tās izraisa problēmas.

#### 2. slānis: Aizsardzības kalšana (reaktīva)

Kad cits kalnracis publicē bloku tajā pašā augstumā, kuru jūs iegūstat:

1. **Noteikšana**: Jūsu mezgls identificē tā paša augstuma konkurenci
2. **Validācija**: Iegūst un validē konkurējošā bloka kvalitāti
3. **Salīdzināšana**: Pārbauda, vai jūsu kvalitāte ir labāka
4. **Reakcija**: Ja labāka, nekavējoties kalš jūsu bloku

**Rezultāts:** Tīkls saņem abus blokus un izvēlas to ar labāku kvalitāti caur standarta dakšas atrisināšanu.

### Kā tas darbojas

#### Scenārijs: Tā paša augstuma konkurence

```
Laiks 150s: Kalnracis B (pulkstenis +10s) kalš ar kvalitāti 1000
           → Bloka laikspiedogs rāda 160s (10s nākotnē)

Laiks 150s: Jūsu mezgls saņem kalnrača B bloku
           → Nosaka: tas pats augstums, kvalitāte 1000
           → Jums ir: kvalitāte 800 (labāka!)
           → Darbība: Nekavējoties kalst ar pareizu laikspiedogu (150s)

Laiks 152s: Tīkls validē abus blokus
           → Abi derīgi (15s tolerances ietvaros)
           → Kvalitāte 800 uzvar (zemāka = labāka)
           → Jūsu bloks kļūst par ķēdes virsotni
```

#### Scenārijs: Īsta reorganizācija

```
Jūsu kalnrūpniecības augstums 100, konkurents publicē bloku 99
→ Nav tā paša augstuma konkurence
→ Aizsardzības kalšana NEAKTIVIZĒJAS
→ Normāla reorganizācijas apstrāde turpinās
```

### Ieguvumi

**Nulles stimuls pulksteņa manipulācijai**
- Ātri pulksteņi palīdz tikai tad, ja jums jau ir labākā kvalitāte
- Pulksteņa manipulācija kļūst ekonomiski bezjēdzīga

**Uz kvalitāti balstīta konkurence tiek nodrošināta**
- Piespiež kalnračus konkurēt ar faktisko jaudas pierādījuma darbu
- Saglabā PoCX konsensa integritāti

**Tīkla drošība**
- Izturīgs pret uz laiku balstītām spēlēšanas stratēģijām
- Nav nepieciešamas konsensa izmaiņas - tīra kalnraču uzvedība

**Pilnībā automātisks**
- Nav nepieciešama konfigurācija
- Aktivizējas tikai nepieciešamības gadījumā
- Standarta uzvedība visos Bitcoin-PoCX mezglos

### Kompromisi

**Minimāls bāreņu līmeņa pieaugums**
- Apzināts - uzbrukuma bloki kļūst par bāreņiem
- Notiek tikai faktiskas pulksteņa manipulācijas mēģinājumu laikā
- Dabisks uz kvalitāti balstītas dakšas atrisināšanas rezultāts

**Īsa tīkla konkurence**
- Tīkls īslaicīgi redz divus konkurējošus blokus
- Atrisinājas sekundēs caur standarta validāciju
- Tāda pati uzvedība kā vienlaicīga kalnrūpniecība Bitcoin

### Tehniskās detaļas

**Veiktspējas ietekme:** Nenozīmīga
- Aktivizējas tikai tā paša augstuma konkurencē
- Izmanto atmiņas datus (nav diska I/O)
- Validācija pabeidzas milisekundēs

**Resursu lietojums:** Minimāls
- ~20 rindas pamata loģikas
- Atkārtoti izmanto esošo validācijas infrastruktūru
- Viena bloķēšanas iegūšana

**Saderība:** Pilna
- Nav konsensa noteikumu izmaiņu
- Darbojas ar visām Bitcoin Core funkcijām
- Neobligāta uzraudzība caur atkļūdošanas žurnāliem

**Statuss**: Aktīvs visos Bitcoin-PoCX laidienos
**Pirmoreiz ieviests**: 2025-10-10

---

## Drošības draudu analīze

### Ātrā pulksteņa uzbrukums (mazināts ar aizsardzības kalšanu)

**Uzbrukuma vektors**:
Kalnracis ar pulksteni **+14s uz priekšu** var:
1. Saņemt blokus normāli (tie izskatās veci viņiem)
2. Kalst blokus nekavējoties, kad termiņš iziet
3. Pārraidīt blokus, kas izskatās 14s "agri" tīklam
4. **Bloki tiek pieņemti** (15s tolerances ietvaros)
5. **Uzvar sacensībās** pret godīgiem kalnračiem

**Ietekme bez aizsardzības kalšanas**:
Priekšrocība ir ierobežota līdz 14.9 sekundēm (nepietiekami, lai izlaistu ievērojamu PoC darbu), bet nodrošina konsekventu priekšrocību bloku sacensībās.

**Mazināšana (aizsardzības kalšana)**:
- Godīgi kalnrači nosaka tā paša augstuma konkurenci
- Salīdzina kvalitātes vērtības
- Nekavējoties kalš, ja kvalitāte ir labāka
- **Rezultāts**: Ātrs pulkstenis palīdz tikai tad, ja jums jau ir labākā kvalitāte
- **Stimuls**: Nulle - pulksteņa manipulācija kļūst ekonomiski bezjēdzīga

### Lēnā pulksteņa kļūme (kritiska)

**Kļūmes režīms**:
Mezgls **>15s aiz** ir katastrofāls:
- Nevar validēt ienākošos blokus (nākotnes pārbaude neizdodas)
- Kļūst izolēts no tīkla
- Nevar kalnrūpniecībā vai sinhronizēties

**Mazināšana**:
- Stingrs brīdinājums pie 10s nobīdes dod 5 sekunžu buferi pirms kritiskas kļūmes
- Operatori var proaktīvi labot pulksteņa problēmas
- Skaidri kļūdu ziņojumi vada problēmu novēršanu

---

## Labākā prakse mezglu operatoriem

### Laika sinhronizācijas iestatīšana

**Ieteicamā konfigurācija**:
1. **Iespējot NTP**: Izmantojiet tīkla laika protokolu automātiskai sinhronizācijai
   ```bash
   # Linux (systemd-timesyncd)
   sudo timedatectl set-ntp true

   # Pārbaudīt statusu
   timedatectl status
   ```

2. **Pārbaudīt pulksteņa precizitāti**: Regulāri pārbaudiet laika nobīdi
   ```bash
   # Pārbaudīt NTP sinhronizācijas statusu
   ntpq -p

   # Vai ar chrony
   chronyc tracking
   ```

3. **Uzraudzīt brīdinājumus**: Sekojiet Bitcoin-PoCX pulksteņa nobīdes brīdinājumiem žurnālos

### Kalnračiem

**Nav nepieciešama darbība**:
- Funkcija vienmēr ir aktīva
- Darbojas automātiski
- Vienkārši uzturiet precīzu sistēmas pulksteni

**Labākā prakse**:
- Izmantojiet NTP laika sinhronizāciju
- Uzraugiet pulksteņa nobīdes brīdinājumus
- Nekavējoties risiniet brīdinājumus, ja tie parādās

**Paredzamā uzvedība**:
- Solo kalnrūpniecība: Aizsardzības kalšana reti aktivizējas (nav konkurences)
- Tīkla kalnrūpniecība: Aizsargā pret pulksteņa manipulācijas mēģinājumiem
- Caurspīdīga darbība: Lielākā daļa kalnraču to nekad nepamana

### Problēmu novēršana

**Brīdinājums: "10 sekundes ārpus sinhronizācijas"**
- Darbība: Pārbaudiet un labojiet sistēmas pulksteņa sinhronizāciju
- Ietekme: 5 sekunžu buferis pirms kritiskas kļūmes
- Rīki: NTP, chrony, systemd-timesyncd

**Kļūda: "time-too-new" ienākošajiem blokiem**
- Cēlonis: Jūsu pulkstenis ir >15 sekundes lēns
- Ietekme: Nevar validēt blokus, mezgls izolēts
- Labojums: Nekavējoties sinhronizējiet sistēmas pulksteni

**Kļūda: Nevar izplatīt kaltus blokus**
- Cēlonis: Jūsu pulkstenis ir >15 sekundes ātrs
- Ietekme: Bloki noraidīti tīklā
- Labojums: Nekavējoties sinhronizējiet sistēmas pulksteni

---

## Dizaina lēmumi un pamatojums

### Kāpēc 15 sekunžu tolerance?

**Pamatojums**:
- Bitcoin-PoCX mainīgā termiņa laiks ir mazāk laika kritisks nekā fiksēta laika konsensuss
- 15s nodrošina adekvātu aizsardzību, vienlaikus novēršot tīkla fragmentāciju

**Kompromisi**:
- Stingrāka tolerance = vairāk tīkla fragmentācijas no nelielas nobīdes
- Vaļīgāka tolerance = vairāk iespēju laika uzbrukumiem
- 15s līdzsvaro drošību un izturību

### Kāpēc 10 sekunžu brīdinājums?

**Pamatojums**:
- Nodrošina 5 sekunžu drošības buferi
- Piemērotāks PoC nekā Bitcoin 10 minūšu noklusējums
- Ļauj proaktīvus labojumus pirms kritiskas kļūmes

### Kāpēc aizsardzības kalšana?

**Risināmā problēma**:
- 15 sekunžu tolerance iespējo ātra pulksteņa priekšrocību
- Uz kvalitāti balstīts konsensuss varētu tikt apgrauts ar laika manipulāciju

**Risinājuma ieguvumi**:
- Nulles izmaksu aizsardzība (nav konsensa izmaiņu)
- Automātiska darbība
- Novērš uzbrukuma stimulu
- Saglabā jaudas pierādījuma principus

### Kāpēc nav iekštīkla laika sinhronizācijas?

**Drošības pamatojums**:
- Mūsdienu Bitcoin Core noņēma uz vienaudžiem balstītu laika pielāgošanu
- Ievainojams pret Sybil uzbrukumiem uztvertajam tīkla laikam
- PoCX apzināti izvairās paļauties uz tīkla iekšējiem laika avotiem
- Sistēmas pulkstenis ir uzticamāks nekā vienaudžu konsensuss
- Operatoriem jāsinhronizē, izmantojot NTP vai līdzvērtīgu ārēju laika avotu
- Mezgli uzrauga savu nobīdi un izdod brīdinājumus, ja lokālais pulkstenis atšķiras no nesenajiem bloku laikspiedogiem

---

## Implementācijas atsauces

**Pamata faili**:
- Laika validācija: `src/validation.cpp:4547-4561`
- Nākotnes tolerances konstante: `src/chain.h:31`
- Brīdinājuma slieksnis: `src/node/timeoffsets.h:27`
- Laika nobīdes uzraudzība: `src/node/timeoffsets.cpp`
- Aizsardzības kalšana: `src/pocx/mining/scheduler.cpp`

**Saistītā dokumentācija**:
- Laika līkumo algoritms: [3. nodaļa: Konsensa un kalnrūpniecības process](3-consensus-and-mining.md#laika-līkumo-aprēķins)
- Bloku validācija: [3. nodaļa: Bloku validācija](3-consensus-and-mining.md#bloku-validācija)

---

**Ģenerēts**: 2025-10-10
**Statuss**: Pilnīga implementācija
**Pārklājums**: Laika sinhronizācijas prasības, pulksteņa nobīdes apstrāde, aizsardzības kalšana

---

[← Iepriekšējā: Kalšanas piešķīrumi](4-forging-assignments.md) | [📘 Satura rādītājs](index.md) | [Nākamā: Tīkla parametri →](6-network-parameters.md)
