# Documentazione Tecnica di Bitcoin-PoCX

**Versione**: 1.0
**Base Bitcoin Core**: v30.0
**Stato**: Fase Testnet
**Ultimo aggiornamento**: 25-12-2025

---

## Informazioni su questa documentazione

Questa è la documentazione tecnica completa di Bitcoin-PoCX, un'integrazione di Bitcoin Core che aggiunge il supporto al consenso Proof of Capacity neXt generation (PoCX). La documentazione è organizzata come una guida navigabile con capitoli interconnessi che coprono tutti gli aspetti del sistema.

**Destinatari**:
- **Operatori di nodi**: Capitoli 1, 5, 6, 8
- **Miner**: Capitoli 2, 3, 7
- **Sviluppatori**: Tutti i capitoli
- **Ricercatori**: Capitoli 3, 4, 5

## Traduzioni

| | | | | | |
|---|---|---|---|---|---|
| [🇸🇦 Arabo](../ara/index.md) | [🇧🇬 Bulgaro](../bul/index.md) | [🇨🇿 Ceco](../ces/index.md) | [🇨🇳 Cinese](../zho/index.md) | [🇰🇷 Coreano](../kor/index.md) | [🇩🇰 Danese](../dan/index.md) |
| [🇮🇱 Ebraico](../heb/index.md) | [🇪🇪 Estone](../est/index.md) | [🇵🇭 Filippino](../fil/index.md) | [🇫🇮 Finlandese](../fin/index.md) | [🇫🇷 Francese](../fra/index.md) | [🇯🇵 Giapponese](../jpn/index.md) |
| [🇬🇷 Greco](../ell/index.md) | [🇮🇳 Hindi](../hin/index.md) | [🇮🇩 Indonesiano](../ind/index.md) | [🇮🇹 Italiano](../ita/index.md) | [🇱🇻 Lettone](../lav/index.md) | [🇱🇹 Lituano](../lit/index.md) |
| [🇳🇴 Norvegese](../nor/index.md) | [🇳🇱 Olandese](../nld/index.md) | [🇵🇱 Polacco](../pol/index.md) | [🇵🇹 Portoghese](../por/index.md) | [🇷🇴 Rumeno](../ron/index.md) | [🇷🇺 Russo](../rus/index.md) |
| [🇷🇸 Serbo](../srp/index.md) | [🇪🇸 Spagnolo](../spa/index.md) | [🇸🇪 Svedese](../swe/index.md) | [🇰🇪 Swahili](../swa/index.md) | [🇩🇪 Tedesco](../deu/index.md) | [🇹🇷 Turco](../tur/index.md) |
| [🇺🇦 Ucraino](../ukr/index.md) | [🇭🇺 Ungherese](../hun/index.md) | [🇻🇳 Vietnamita](../vie/index.md) | | | |

---

## Indice

### Parte I: Fondamenti

**[Capitolo 1: Introduzione e panoramica](1-introduction.md)**
Panoramica del progetto, architettura, filosofia di progettazione, caratteristiche principali e differenze tra PoCX e Proof of Work.

**[Capitolo 2: Formato dei file plot](2-plot-format.md)**
Specifica completa del formato plot PoCX, inclusa l'ottimizzazione SIMD, lo scaling del proof-of-work e l'evoluzione del formato da POC1/POC2.

**[Capitolo 3: Consenso e mining](3-consensus-and-mining.md)**
Specifica tecnica completa del meccanismo di consenso PoCX: struttura dei blocchi, generation signature, regolazione del base target, processo di mining, pipeline di validazione e algoritmo Time Bending.

---

### Parte II: Funzionalità avanzate

**[Capitolo 4: Sistema di assegnazione del forging](4-forging-assignments.md)**
Architettura basata esclusivamente su OP_RETURN per la delega dei diritti di forging: struttura delle transazioni, progettazione del database, macchina a stati, gestione delle riorganizzazioni e interfaccia RPC.

**[Capitolo 5: Sincronizzazione temporale e sicurezza](5-timing-security.md)**
Tolleranza alla deriva dell'orologio, meccanismo di forging difensivo, protezione anti-manipolazione dell'orologio e considerazioni sulla sicurezza relative al timing.

**[Capitolo 6: Parametri di rete](6-network-parameters.md)**
Configurazione chainparams, blocco genesis, parametri di consenso, regole coinbase, scaling dinamico e modello economico.

---

### Parte III: Utilizzo e integrazione

**[Capitolo 7: Riferimento interfaccia RPC](7-rpc-reference.md)**
Riferimento completo dei comandi RPC per mining, assegnazioni e interrogazioni della blockchain. Essenziale per l'integrazione di miner e pool.

**[Capitolo 8: Guida al wallet e alla GUI](8-wallet-guide.md)**
Guida utente per il wallet Qt di Bitcoin-PoCX: finestra di dialogo per l'assegnazione del forging, cronologia delle transazioni, configurazione del mining e risoluzione dei problemi.

---

## Navigazione rapida

### Per gli operatori di nodi
→ Iniziare con il [Capitolo 1: Introduzione](1-introduction.md)
→ Poi consultare il [Capitolo 6: Parametri di rete](6-network-parameters.md)
→ Configurare il mining con il [Capitolo 8: Guida al wallet](8-wallet-guide.md)

### Per i miner
→ Comprendere il [Capitolo 2: Formato dei plot](2-plot-format.md)
→ Apprendere il processo nel [Capitolo 3: Consenso e mining](3-consensus-and-mining.md)
→ Integrare usando il [Capitolo 7: Riferimento RPC](7-rpc-reference.md)

### Per gli operatori di pool
→ Consultare il [Capitolo 4: Assegnazioni di forging](4-forging-assignments.md)
→ Studiare il [Capitolo 7: Riferimento RPC](7-rpc-reference.md)
→ Implementare usando le RPC per le assegnazioni e submit_nonce

### Per gli sviluppatori
→ Leggere tutti i capitoli in sequenza
→ Fare riferimenti incrociati ai file di implementazione indicati nel testo
→ Esaminare la struttura della directory `src/pocx/`
→ Creare release con [GUIX](../bitcoin/contrib/guix/README.md)

---

## Convenzioni della documentazione

**Riferimenti ai file**: I dettagli implementativi fanno riferimento ai file sorgente come `percorso/del/file.cpp:riga`

**Integrazione del codice**: Tutte le modifiche sono contrassegnate con `#ifdef ENABLE_POCX`

**Riferimenti incrociati**: I capitoli rimandano alle sezioni correlate tramite link markdown relativi

**Livello tecnico**: La documentazione presuppone familiarità con Bitcoin Core e lo sviluppo in C++

---

## Compilazione

### Build di sviluppo

```bash
# Clonare con i sottomoduli
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Configurare con PoCX abilitato
cmake -B build -DENABLE_POCX=ON

# Compilare
cmake --build build -j$(nproc)
```

**Varianti di build**:
```bash
# Con interfaccia grafica Qt
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Build di debug
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Dipendenze**: Dipendenze standard per la compilazione di Bitcoin Core. Consultare la [documentazione di compilazione di Bitcoin Core](https://github.com/bitcoin/bitcoin/tree/master/doc#building) per i requisiti specifici della piattaforma.

### Build di release

Per binari di release riproducibili, utilizzare il sistema di build GUIX: Vedere [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Risorse aggiuntive

**Repository**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**Framework PoCX Core**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Progetti correlati**:
- Plotter: Basato su [engraver](https://github.com/PoC-Consortium/engraver)
- Miner: Basato su [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Come leggere questa documentazione

**Lettura sequenziale**: I capitoli sono progettati per essere letti in ordine, costruendo sui concetti precedenti.

**Lettura di riferimento**: Usare l'indice per accedere direttamente ad argomenti specifici. Ogni capitolo è autonomo con riferimenti incrociati al materiale correlato.

**Navigazione nel browser**: Aprire `index.md` in un visualizzatore markdown o nel browser. Tutti i link interni sono relativi e funzionano offline.

**Esportazione PDF**: Questa documentazione può essere concatenata in un singolo PDF per la lettura offline.

---

## Stato del progetto

**Funzionalità complete**: Tutte le regole di consenso, mining, assegnazioni e funzionalità del wallet sono implementate.

**Documentazione completa**: Tutti gli 8 capitoli sono completi e verificati rispetto al codice sorgente.

**Testnet attiva**: Attualmente in fase testnet per test della community.

---

## Contribuire

I contributi alla documentazione sono benvenuti. Si prega di mantenere:
- Accuratezza tecnica prima della verbosità
- Spiegazioni brevi e concise
- Nessun codice o pseudo-codice nella documentazione (fare riferimento ai file sorgente)
- Solo funzionalità implementate (nessuna caratteristica speculativa)

---

## Licenza

Bitcoin-PoCX eredita la licenza MIT di Bitcoin Core. Vedere `COPYING` nella directory principale del repository.

Attribuzione del framework PoCX core documentata nel [Capitolo 2: Formato dei plot](2-plot-format.md).

---

**Iniziare a leggere**: [Capitolo 1: Introduzione e panoramica →](1-introduction.md)
