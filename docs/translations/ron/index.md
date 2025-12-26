# Documentație Tehnică Bitcoin-PoCX

**Versiune**: 1.0
**Baza Bitcoin Core**: v30.0
**Stare**: Fază Testnet
**Ultima actualizare**: 2025-12-25

---

## Despre această documentație

Aceasta este documentația tehnică completă pentru Bitcoin-PoCX, o integrare Bitcoin Core care adaugă suport pentru consensul Proof of Capacity neXt generation (PoCX). Documentația este organizată ca un ghid navigabil cu capitole interconectate care acoperă toate aspectele sistemului.

**Audiențe țintă**:
- **Operatori de noduri**: Capitolele 1, 5, 6, 8
- **Mineri**: Capitolele 2, 3, 7
- **Dezvoltatori**: Toate capitolele
- **Cercetători**: Capitolele 3, 4, 5




## Traduceri

| | | | | | |
|---|---|---|---|---|---|
| [🇸🇦 Arabă](../ara/index.md) | [🇧🇬 Bulgară](../bul/index.md) | [🇨🇿 Cehă](../ces/index.md) | [🇨🇳 Chineză](../zho/index.md) | [🇰🇷 Coreeană](../kor/index.md) | [🇩🇰 Daneză](../dan/index.md) |
| [🇮🇱 Ebraică](../heb/index.md) | [🇬🇧 Engleză](../../index.md) | [🇪🇪 Estonă](../est/index.md) | [🇵🇭 Filipineză](../fil/index.md) | [🇫🇮 Finlandeză](../fin/index.md) | [🇫🇷 Franceză](../fra/index.md) |
| [🇩🇪 Germană](../deu/index.md) | [🇬🇷 Greacă](../ell/index.md) | [🇮🇳 Hindi](../hin/index.md) | [🇮🇩 Indoneziană](../ind/index.md) | [🇮🇹 Italiană](../ita/index.md) | [🇯🇵 Japoneză](../jpn/index.md) |
| [🇱🇻 Letonă](../lav/index.md) | [🇱🇹 Lituaniană](../lit/index.md) | [🇭🇺 Maghiară](../hun/index.md) | [🇳🇴 Norvegiană](../nor/index.md) | [🇳🇱 Olandeză](../nld/index.md) | [🇵🇱 Poloneză](../pol/index.md) |
| [🇵🇹 Portugheză](../por/index.md) | [🇷🇺 Rusă](../rus/index.md) | [🇷🇸 Sârbă](../srp/index.md) | [🇪🇸 Spaniolă](../spa/index.md) | [🇸🇪 Suedeză](../swe/index.md) | [🇰🇪 Swahili](../swa/index.md) |
| [🇹🇷 Turcă](../tur/index.md) | [🇺🇦 Ucraineană](../ukr/index.md) | [🇻🇳 Vietnameză](../vie/index.md) | | | |


---

## Cuprins

### Partea I: Fundamente

**[Capitolul 1: Introducere și prezentare generală](1-introduction.md)**
Prezentare generală a proiectului, arhitectură, filosofie de design, caracteristici principale și modul în care PoCX diferă de Proof of Work.

**[Capitolul 2: Formatul fișierelor plot](2-plot-format.md)**
Specificația completă a formatului plot PoCX, incluzând optimizarea SIMD, scalarea proof-of-work și evoluția formatului din POC1/POC2.

**[Capitolul 3: Consens și minerit](3-consensus-and-mining.md)**
Specificația tehnică completă a mecanismului de consens PoCX: structura blocurilor, semnături de generare, ajustarea țintei de bază, procesul de minerit, fluxul de validare și algoritmul Time Bending.

---

### Partea II: Funcționalități avansate

**[Capitolul 4: Sistemul de atribuire a forjării](4-forging-assignments.md)**
Arhitectură bazată exclusiv pe OP_RETURN pentru delegarea drepturilor de forjare: structura tranzacțiilor, design-ul bazei de date, mașina de stări, gestionarea reorganizărilor și interfața RPC.

**[Capitolul 5: Sincronizare temporală și securitate](5-timing-security.md)**
Toleranța la deriva ceasului, mecanismul de forjare defensivă, protecția împotriva manipulării ceasului și considerații de securitate legate de sincronizarea temporală.

**[Capitolul 6: Parametri de rețea](6-network-parameters.md)**
Configurarea chainparams, blocul genesis, parametri de consens, reguli coinbase, scalare dinamică și modelul economic.

---

### Partea III: Utilizare și integrare

**[Capitolul 7: Referință interfață RPC](7-rpc-reference.md)**
Referință completă a comenzilor RPC pentru minerit, atribuiri și interogări blockchain. Esențial pentru integrarea minerilor și pool-urilor.

**[Capitolul 8: Ghid portofel și GUI](8-wallet-guide.md)**
Ghid de utilizare pentru portofelul Qt Bitcoin-PoCX: dialogul de atribuire a forjării, istoricul tranzacțiilor, configurarea mineritului și depanarea problemelor.

---

## Navigare rapidă

### Pentru operatorii de noduri
→ Începeți cu [Capitolul 1: Introducere](1-introduction.md)
→ Apoi consultați [Capitolul 6: Parametri de rețea](6-network-parameters.md)
→ Configurați mineritul cu [Capitolul 8: Ghid portofel](8-wallet-guide.md)

### Pentru mineri
→ Înțelegeți [Capitolul 2: Formatul plot](2-plot-format.md)
→ Învățați procesul în [Capitolul 3: Consens și minerit](3-consensus-and-mining.md)
→ Integrați folosind [Capitolul 7: Referință RPC](7-rpc-reference.md)

### Pentru operatorii de pool-uri
→ Consultați [Capitolul 4: Atribuiri de forjare](4-forging-assignments.md)
→ Studiați [Capitolul 7: Referință RPC](7-rpc-reference.md)
→ Implementați folosind RPC-urile de atribuire și submit_nonce

### Pentru dezvoltatori
→ Citiți toate capitolele în ordine
→ Faceți referințe încrucișate la fișierele de implementare menționate pe parcurs
→ Examinați structura directorului `src/pocx/`
→ Compilați versiunile cu [GUIX](../bitcoin/contrib/guix/README.md)

---

## Convenții în documentație

**Referințe la fișiere**: Detaliile de implementare fac referire la fișierele sursă ca `cale/către/fișier.cpp:linie`

**Integrare cod**: Toate modificările sunt marcate cu flag-ul `#ifdef ENABLE_POCX`

**Referințe încrucișate**: Capitolele conțin link-uri către secțiuni conexe folosind link-uri markdown relative

**Nivel tehnic**: Documentația presupune familiaritate cu Bitcoin Core și dezvoltarea C++

---

## Compilare

### Compilare pentru dezvoltare

```bash
# Clonare cu submodule
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Configurare cu PoCX activat
cmake -B build -DENABLE_POCX=ON

# Compilare
cmake --build build -j$(nproc)
```

**Variante de compilare**:
```bash
# Cu interfață Qt GUI
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Compilare pentru depanare
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Dependențe**: Dependențele standard pentru compilarea Bitcoin Core. Consultați [documentația de compilare Bitcoin Core](https://github.com/bitcoin/bitcoin/tree/master/doc#building) pentru cerințele specifice fiecărei platforme.

### Compilări pentru lansare

Pentru binare de lansare reproductibile, folosiți sistemul de compilare GUIX: Consultați [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Resurse suplimentare

**Depozit**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**Framework PoCX Core**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Proiecte conexe**:
- Plotter: Bazat pe [engraver](https://github.com/PoC-Consortium/engraver)
- Miner: Bazat pe [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Cum să citiți această documentație

**Citire secvențială**: Capitolele sunt concepute pentru a fi citite în ordine, fiecare construind pe baza conceptelor anterioare.

**Citire ca referință**: Folosiți cuprinsul pentru a sări direct la subiecte specifice. Fiecare capitol este autonom și conține referințe încrucișate către materiale conexe.

**Navigare în browser**: Deschideți `index.md` într-un vizualizator markdown sau browser. Toate link-urile interne sunt relative și funcționează offline.

**Export PDF**: Această documentație poate fi concatenată într-un singur PDF pentru citire offline.

---

## Starea proiectului

**✅ Funcționalități complete**: Toate regulile de consens, mineritul, atribuirile și funcționalitățile portofelului sunt implementate.

**✅ Documentație completă**: Toate cele 8 capitole sunt finalizate și verificate în raport cu codul sursă.

**🔬 Testnet activ**: Momentan în faza testnet pentru testare de către comunitate.

---

## Contribuții

Contribuțiile la documentație sunt binevenite. Vă rugăm să mențineți:
- Acuratețe tehnică în locul prolixității
- Explicații scurte și la obiect
- Fără cod sau pseudo-cod în documentație (faceți referire la fișierele sursă)
- Doar funcționalități implementate (fără funcționalități speculative)

---

## Licență

Bitcoin-PoCX moștenește licența MIT de la Bitcoin Core. Consultați `COPYING` în rădăcina depozitului.

Atribuirea framework-ului PoCX core este documentată în [Capitolul 2: Formatul plot](2-plot-format.md).

---

**Începeți lectura**: [Capitolul 1: Introducere și prezentare generală →](1-introduction.md)
