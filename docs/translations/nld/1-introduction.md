[Inhoudsopgave](index.md) | [Volgende: Plotformaat](2-plot-format.md)

---

# Hoofdstuk 1: Inleiding en overzicht

## Wat is Bitcoin-PoCX?

Bitcoin-PoCX is een Bitcoin Core-integratie die **Proof of Capacity neXt generation (PoCX)**-consensusondersteuning toevoegt. Het behoudt de bestaande architectuur van Bitcoin Core terwijl het een energie-efficiente Proof of Capacity-miningalternatief mogelijk maakt als volledige vervanging voor Proof of Work.

**Belangrijk onderscheid**: Dit is een **nieuwe keten** zonder achterwaartse compatibiliteit met Bitcoin PoW. PoCX-blokken zijn ontworpen om incompatibel te zijn met PoW-nodes.

---

## Projectidentiteit

- **Organisatie**: Proof of Capacity Consortium
- **Projectnaam**: Bitcoin-PoCX
- **Volledige naam**: Bitcoin Core met PoCX-integratie
- **Status**: Testnetfase

---

## Wat is Proof of Capacity?

Proof of Capacity (PoC) is een consensusmechanisme waarbij miningkracht evenredig is met **schijfruimte** in plaats van rekenkracht. Miners genereren vooraf grote plotbestanden met cryptografische hashes en gebruiken deze plots vervolgens om geldige blokoplossingen te vinden.

**Energie-efficientie**: Plotbestanden worden eenmalig gegenereerd en onbeperkt hergebruikt. Mining verbruikt minimale CPU-kracht - voornamelijk schijf-I/O.

**PoCX-verbeteringen**:
- Gerepareerde XOR-transpose compressie-aanval (50% tijd-geheugen-afweging in POC2)
- 16-nonce-uitgelijnde layout voor moderne hardware
- Schaalbare proof-of-work in plotgeneratie (Xn-schaalniveaus)
- Native C++-integratie rechtstreeks in Bitcoin Core
- Time Bending-algoritme voor verbeterde bloktijddistributie

---

## Architectuuroverzicht

### Repositorystructuur

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + PoCX-integratie
│   └── src/pocx/        # PoCX-implementatie
├── pocx/                # PoCX core framework (submodule, alleen-lezen)
└── docs/                # Deze documentatie
```

### Integratiefilosofie

**Minimaal integratieoppervlak**: Wijzigingen geïsoleerd in de `/src/pocx/`-map met schone hooks in de Bitcoin Core validatie-, mining- en RPC-lagen.

**Functievlaggen**: Alle wijzigingen onder `#ifdef ENABLE_POCX` preprocessor-guards. Bitcoin Core bouwt normaal wanneer uitgeschakeld.

**Upstream-compatibiliteit**: Regelmatige synchronisatie met Bitcoin Core-updates onderhouden door geïsoleerde integratiepunten.

**Native C++-implementatie**: Scalaire cryptografische algoritmen (Shabal256, scoop-berekening, compressie) rechtstreeks geïntegreerd in Bitcoin Core voor consensusvalidatie.

---

## Kernfuncties

### 1. Volledige consensusvervanging

- **Blokstructuur**: PoCX-specifieke velden vervangen PoW-nonce en difficulty bits
  - Generatiehandtekening (deterministische mining-entropie)
  - Base target (inverse van difficulty)
  - PoCX-bewijs (account-ID, seed, nonce)
  - Blokhandtekening (bewijst ploteigenaarschap)

- **Validatie**: 5-fasen validatiepijplijn van headercontrole tot blokverbinding

- **Moeilijkheidsaanpassing**: Aanpassing bij elk blok met voortschrijdend gemiddelde van recente base targets

### 2. Time Bending-algoritme

**Probleem**: Traditionele PoC-bloktijden volgen een exponentiele verdeling, wat leidt tot lange blokken wanneer geen miner een goede oplossing vindt.

**Oplossing**: Distributietransformatie van exponentieel naar chi-kwadraat met kubuswortel: `Y = schaal × (X^(1/3))`.

**Effect**: Zeer goede oplossingen forgen later (netwerk heeft tijd om alle schijven te scannen, vermindert snelle blokken), slechte oplossingen worden verbeterd. Gemiddelde bloktijd blijft 120 seconden, lange blokken worden verminderd.

**Details**: [Hoofdstuk 3: Consensus en mining](3-consensus-and-mining.md)

### 3. Forging-toewijzingssysteem

**Mogelijkheid**: Ploteigenaren kunnen forgingrechten delegeren aan andere adressen terwijl ze ploteigenaarschap behouden.

**Gebruiksscenario's**:
- Pool-mining (plots worden toegewezen aan pooladres)
- Cold storage (mining-sleutel gescheiden van ploteigenaarschap)
- Multi-party mining (gedeelde infrastructuur)

**Architectuur**: Alleen-OP_RETURN-ontwerp - geen speciale UTXO's, toewijzingen worden apart bijgehouden in de chainstate-database.

**Details**: [Hoofdstuk 4: Forging-toewijzingen](4-forging-assignments.md)

### 4. Defensief forgen

**Probleem**: Snelle klokken kunnen timingvoordelen bieden binnen de 15-seconden toekomsttolerantie.

**Oplossing**: Bij ontvangst van een concurrerend blok op dezelfde hoogte, automatisch lokale kwaliteit controleren. Indien beter, onmiddellijk forgen.

**Effect**: Elimineert prikkel voor klokmanipulatie - snelle klokken helpen alleen als je al de beste oplossing hebt.

**Details**: [Hoofdstuk 5: Timingbeveiliging](5-timing-security.md)

### 5. Dynamische compressieschaling

**Economische afstemming**: Vereisten voor schaalniveau nemen toe volgens een exponentieel schema (Jaren 4, 12, 28, 60, 124 = halveringen 1, 3, 7, 15, 31).

**Effect**: Naarmate blokbeloningen afnemen, neemt de moeilijkheid van plotgeneratie toe. Behoudt veiligheidsmarge tussen plotcreatie- en opzoekkosten.

**Voorkomt**: Capaciteitsinflatie door snellere hardware na verloop van tijd.

**Details**: [Hoofdstuk 6: Netwerkparameters](6-network-parameters.md)

---

## Ontwerpfilosofie

### Codeveiligheid

- Defensieve programmeerpraktijken overal
- Uitgebreide foutafhandeling in validatiepaden
- Geen geneste locks (deadlock-preventie)
- Atomische database-operaties (UTXO + toewijzingen samen)

### Modulaire architectuur

- Schone scheiding tussen Bitcoin Core-infrastructuur en PoCX-consensus
- PoCX core framework biedt cryptografische primitieven
- Bitcoin Core biedt validatieframework, database, netwerken

### Prestatie-optimalisaties

- Fast-fail validatievolgorde (goedkope controles eerst)
- Enkele contextophaling per inzending (geen herhaalde cs_main-acquisities)
- Atomische database-operaties voor consistentie

### Reorg-veiligheid

- Volledige undo-gegevens voor toewijzingsstatuswijzigingen
- Forgingstatus-reset bij ketentip-wijzigingen
- Verouderingsdetectie op alle validatiepunten

---

## Hoe PoCX verschilt van Proof of Work

| Aspect | Bitcoin (PoW) | Bitcoin-PoCX |
|--------|---------------|--------------|
| **Miningresource** | Rekenkracht (hashrate) | Schijfruimte (capaciteit) |
| **Energieverbruik** | Hoog (continu hashen) | Laag (alleen schijf-I/O) |
| **Miningproces** | Vind nonce met hash < target | Vind nonce met deadline < verstreken tijd |
| **Moeilijkheid** | `bits`-veld, aangepast elke 2016 blokken | `base_target`-veld, aangepast elk blok |
| **Bloktijd** | ~10 minuten (exponentiele verdeling) | 120 seconden (time-bended, verminderde variantie) |
| **Subsidie** | 50 BTC -> 25 -> 12,5 -> ... | 10 BTC -> 5 -> 2,5 -> ... |
| **Hardware** | ASIC's (gespecialiseerd) | HDD's (standaardhardware) |
| **Miningidentiteit** | Anoniem | Ploteigenaar of gedelegeerde |

---

## Systeemvereisten

### Node-operatie

**Zelfde als Bitcoin Core**:
- **CPU**: Moderne x86_64-processor
- **Geheugen**: 4-8 GB RAM
- **Opslag**: Nieuwe keten, momenteel leeg (kan ~4x sneller groeien dan Bitcoin door 2-minuten blokken en toewijzingsdatabase)
- **Netwerk**: Stabiele internetverbinding
- **Klok**: NTP-synchronisatie aanbevolen voor optimale werking

**Opmerking**: Plotbestanden zijn NIET vereist voor node-operatie.

### Miningvereisten

**Aanvullende vereisten voor mining**:
- **Plotbestanden**: Vooraf gegenereerd met `pocx_plotter` (referentie-implementatie)
- **Minersoftware**: `pocx_miner` (referentie-implementatie) maakt verbinding via RPC
- **Wallet**: `bitcoind` of `bitcoin-qt` met privesleutels voor miningadres. Pool-mining vereist geen lokale wallet.

---

## Aan de slag

### 1. Bouw Bitcoin-PoCX

```bash
# Kloon met submodules
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Bouw met PoCX ingeschakeld
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Details**: Zie `CLAUDE.md` in de repository-root

### 2. Voer node uit

**Alleen node**:
```bash
./build/bin/bitcoind
# of
./build/bin/bitcoin-qt
```

**Voor mining** (schakelt RPC-toegang in voor externe miners):
```bash
./build/bin/bitcoind -miningserver
# of
./build/bin/bitcoin-qt -server -miningserver
```

**Details**: [Hoofdstuk 6: Netwerkparameters](6-network-parameters.md)

### 3. Genereer plotbestanden

Gebruik `pocx_plotter` (referentie-implementatie) om PoCX-formaatplotbestanden te genereren.

**Details**: [Hoofdstuk 2: Plotformaat](2-plot-format.md)

### 4. Mining instellen

Gebruik `pocx_miner` (referentie-implementatie) om verbinding te maken met de RPC-interface van uw node.

**Details**: [Hoofdstuk 7: RPC-referentie](7-rpc-reference.md) en [Hoofdstuk 8: Wallet-handleiding](8-wallet-guide.md)

---

## Attributie

### Plotformaat

Gebaseerd op POC2-formaat (Burstcoin) met verbeteringen:
- Gerepareerd beveiligingslek (XOR-transpose compressie-aanval)
- Schaalbare proof-of-work
- SIMD-geoptimaliseerde layout
- Seed-functionaliteit

### Bronprojecten

- **pocx_miner**: Referentie-implementatie gebaseerd op [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter**: Referentie-implementatie gebaseerd op [engraver](https://github.com/PoC-Consortium/engraver)

**Volledige attributie**: [Hoofdstuk 2: Plotformaat](2-plot-format.md)

---

## Samenvatting technische specificaties

- **Bloktijd**: 120 seconden (mainnet), 1 seconde (regtest)
- **Bloksubsidie**: 10 BTC initieel, halvering elke 1050000 blokken (~4 jaar)
- **Totale voorraad**: ~21 miljoen BTC (zelfde als Bitcoin)
- **Toekomsttolerantie**: 15 seconden (blokken tot 15s vooruit worden geaccepteerd)
- **Klokwaarschuwing**: 10 seconden (waarschuwt operators voor tijdsverschuiving)
- **Toewijzingsvertraging**: 30 blokken (~1 uur)
- **Intrekkingsvertraging**: 720 blokken (~24 uur)
- **Adresformaat**: Alleen P2WPKH (bech32, pocx1q...) voor PoCX-miningoperaties en forging-toewijzingen

---

## Code-organisatie

**Bitcoin Core-wijzigingen**: Minimale wijzigingen aan corebestanden, voorzien van functievlaggen met `#ifdef ENABLE_POCX`

**Nieuwe PoCX-implementatie**: Geïsoleerd in de `src/pocx/`-map

---

## Beveiligingsoverwegingen

### Timingbeveiliging

- 15-seconden toekomsttolerantie voorkomt netwerkfragmentatie
- 10-seconden waarschuwingsdrempel waarschuwt operators voor klokverschuiving
- Defensief forgen elimineert prikkel voor klokmanipulatie
- Time Bending vermindert impact van timingvariantie

**Details**: [Hoofdstuk 5: Timingbeveiliging](5-timing-security.md)

### Toewijzingsbeveiliging

- Alleen-OP_RETURN-ontwerp (geen UTXO-manipulatie)
- Transactiehandtekening bewijst ploteigenaarschap
- Activeringsvertragingen voorkomen snelle statusmanipulatie
- Reorg-veilige undo-gegevens voor alle statuswijzigingen

**Details**: [Hoofdstuk 4: Forging-toewijzingen](4-forging-assignments.md)

### Consensusbeveiliging

- Handtekening uitgesloten van blokhash (voorkomt malleability)
- Begrensde handtekeninggroottes (voorkomt DoS)
- Compressiegrenzenvalidatie (voorkomt zwakke bewijzen)
- Moeilijkheidsaanpassing bij elk blok (reageert op capaciteitswijzigingen)

**Details**: [Hoofdstuk 3: Consensus en mining](3-consensus-and-mining.md)

---

## Netwerkstatus

**Mainnet**: Nog niet gelanceerd
**Testnet**: Beschikbaar voor testen
**Regtest**: Volledig functioneel voor ontwikkeling

**Genesisblokparameters**: [Hoofdstuk 6: Netwerkparameters](6-network-parameters.md)

---

## Volgende stappen

**Voor begrip van PoCX**: Ga verder naar [Hoofdstuk 2: Plotformaat](2-plot-format.md) om te leren over plotbestandsstructuur en formaat-evolutie.

**Voor mining-setup**: Ga naar [Hoofdstuk 7: RPC-referentie](7-rpc-reference.md) voor integratiedetails.

**Voor het draaien van een node**: Bekijk [Hoofdstuk 6: Netwerkparameters](6-network-parameters.md) voor configuratie-opties.

---

[Inhoudsopgave](index.md) | [Volgende: Plotformaat](2-plot-format.md)
