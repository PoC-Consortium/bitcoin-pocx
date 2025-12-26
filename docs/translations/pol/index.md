# Dokumentacja techniczna Bitcoin-PoCX

**Wersja**: 1.0
**Baza Bitcoin Core**: v30.0
**Status**: Faza testowa (Testnet)
**Ostatnia aktualizacja**: 25.12.2025

---

## O tej dokumentacji

Jest to kompletna dokumentacja techniczna Bitcoin-PoCX, integracji Bitcoin Core dodającej wsparcie dla konsensusu Proof of Capacity neXt generation (PoCX). Dokumentacja jest zorganizowana jako przewodnik z wzajemnie powiązanymi rozdziałami obejmującymi wszystkie aspekty systemu.

**Grupy docelowe**:
- **Operatorzy węzłów**: Rozdziały 1, 5, 6, 8
- **Górnicy**: Rozdziały 2, 3, 7
- **Deweloperzy**: Wszystkie rozdziały
- **Badacze**: Rozdziały 3, 4, 5




## Tłumaczenia

| | | | | | |
|---|---|---|---|---|---|
| [🇸🇦 Arabski](../ara/index.md) | [🇧🇬 Bułgarski](../bul/index.md) | [🇨🇳 Chiński](../zho/index.md) | [🇨🇿 Czeski](../ces/index.md) | [🇩🇰 Duński](../dan/index.md) | [🇪🇪 Estoński](../est/index.md) |
| [🇵🇭 Filipiński](../fil/index.md) | [🇫🇮 Fiński](../fin/index.md) | [🇫🇷 Francuski](../fra/index.md) | [🇬🇷 Grecki](../ell/index.md) | [🇮🇱 Hebrajski](../heb/index.md) | [🇮🇳 Hindi](../hin/index.md) |
| [🇪🇸 Hiszpański](../spa/index.md) | [🇳🇱 Holenderski](../nld/index.md) | [🇮🇩 Indonezyjski](../ind/index.md) | [🇯🇵 Japoński](../jpn/index.md) | [🇰🇷 Koreański](../kor/index.md) | [🇱🇹 Litewski](../lit/index.md) |
| [🇱🇻 Łotewski](../lav/index.md) | [🇩🇪 Niemiecki](../deu/index.md) | [🇳🇴 Norweski](../nor/index.md) | [🇵🇹 Portugalski](../por/index.md) | [🇷🇴 Rumuński](../ron/index.md) | [🇷🇺 Rosyjski](../rus/index.md) |
| [🇷🇸 Serbski](../srp/index.md) | [🇰🇪 Suahili](../swa/index.md) | [🇸🇪 Szwedzki](../swe/index.md) | [🇹🇷 Turecki](../tur/index.md) | [🇺🇦 Ukraiński](../ukr/index.md) | [🇭🇺 Węgierski](../hun/index.md) |
| [🇻🇳 Wietnamski](../vie/index.md) | [🇮🇹 Włoski](../ita/index.md) | | | | |


---

## Spis treści

### Część I: Podstawy

**[Rozdział 1: Wprowadzenie i przegląd](1-introduction.md)**
Przegląd projektu, architektura, filozofia projektowa, kluczowe funkcje oraz różnice między PoCX a Proof of Work.

**[Rozdział 2: Format plików plot](2-plot-format.md)**
Kompletna specyfikacja formatu plot PoCX, w tym optymalizacja SIMD, skalowanie proof-of-work oraz ewolucja z formatów POC1/POC2.

**[Rozdział 3: Konsensus i wydobycie](3-consensus-and-mining.md)**
Pełna specyfikacja techniczna mechanizmu konsensusu PoCX: struktura bloku, sygnatury generacji, dostosowanie base target, proces wydobycia, potok walidacji oraz algorytm Time Bending.

---

### Część II: Zaawansowane funkcje

**[Rozdział 4: System przydziału kucia](4-forging-assignments.md)**
Architektura oparta wyłącznie na OP_RETURN do delegowania praw kucia: struktura transakcji, projekt bazy danych, maszyna stanów, obsługa reorganizacji łańcucha oraz interfejs RPC.

**[Rozdział 5: Synchronizacja czasu i bezpieczeństwo](5-timing-security.md)**
Tolerancja dryfu zegara, mechanizm kucia obronnego, ochrona przed manipulacją zegarem oraz kwestie bezpieczeństwa związane z czasem.

**[Rozdział 6: Parametry sieci](6-network-parameters.md)**
Konfiguracja chainparams, blok genesis, parametry konsensusu, zasady coinbase, dynamiczne skalowanie oraz model ekonomiczny.

---

### Część III: Użytkowanie i integracja

**[Rozdział 7: Dokumentacja interfejsu RPC](7-rpc-reference.md)**
Kompletna dokumentacja poleceń RPC dla wydobycia, przydziałów i zapytań o blockchain. Niezbędna dla integracji górników i pul.

**[Rozdział 8: Przewodnik po portfelu i GUI](8-wallet-guide.md)**
Przewodnik użytkownika portfela Bitcoin-PoCX Qt: dialog przydziału kucia, historia transakcji, konfiguracja wydobycia oraz rozwiązywanie problemów.

---

## Szybka nawigacja

### Dla operatorów węzłów
→ Zacznij od [Rozdziału 1: Wprowadzenie](1-introduction.md)
→ Następnie przejrzyj [Rozdział 6: Parametry sieci](6-network-parameters.md)
→ Skonfiguruj wydobycie za pomocą [Rozdziału 8: Przewodnik po portfelu](8-wallet-guide.md)

### Dla górników
→ Zrozum [Rozdział 2: Format plot](2-plot-format.md)
→ Poznaj proces w [Rozdziale 3: Konsensus i wydobycie](3-consensus-and-mining.md)
→ Zintegruj używając [Rozdziału 7: Dokumentacja RPC](7-rpc-reference.md)

### Dla operatorów pul
→ Przejrzyj [Rozdział 4: Przydziały kucia](4-forging-assignments.md)
→ Przestudiuj [Rozdział 7: Dokumentacja RPC](7-rpc-reference.md)
→ Zaimplementuj używając RPC przydziałów i submit_nonce

### Dla deweloperów
→ Przeczytaj wszystkie rozdziały po kolei
→ Korzystaj z odniesień do plików implementacji umieszczonych w całej dokumentacji
→ Zbadaj strukturę katalogu `src/pocx/`
→ Buduj wydania przy użyciu [GUIX](../bitcoin/contrib/guix/README.md)

---

## Konwencje dokumentacji

**Odniesienia do plików**: Szczegóły implementacji odwołują się do plików źródłowych jako `ścieżka/do/pliku.cpp:linia`

**Integracja kodu**: Wszystkie zmiany są oznaczone flagą funkcji `#ifdef ENABLE_POCX`

**Odnośniki wewnętrzne**: Rozdziały łączą się z powiązanymi sekcjami za pomocą względnych linków markdown

**Poziom techniczny**: Dokumentacja zakłada znajomość Bitcoin Core i programowania w C++

---

## Budowanie

### Kompilacja deweloperska

```bash
# Klonowanie z submodułami
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Konfiguracja z włączonym PoCX
cmake -B build -DENABLE_POCX=ON

# Kompilacja
cmake --build build -j$(nproc)
```

**Warianty kompilacji**:
```bash
# Z interfejsem Qt GUI
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Kompilacja debugowa
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Zależności**: Standardowe zależności kompilacji Bitcoin Core. Zobacz [dokumentację kompilacji Bitcoin Core](https://github.com/bitcoin/bitcoin/tree/master/doc#building) dla wymagań specyficznych dla platformy.

### Kompilacje wydaniowe

Dla reprodukowalnych plików binarnych wydania użyj systemu kompilacji GUIX: Zobacz [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Dodatkowe zasoby

**Repozytorium**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**Framework PoCX Core**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Powiązane projekty**:
- Plotter: Oparty na [engraver](https://github.com/PoC-Consortium/engraver)
- Miner: Oparty na [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Jak czytać tę dokumentację

**Czytanie sekwencyjne**: Rozdziały są zaprojektowane do czytania po kolei, budując na poprzednich koncepcjach.

**Czytanie referencyjne**: Użyj spisu treści, aby przejść bezpośrednio do konkretnych tematów. Każdy rozdział jest samodzielny z odnośnikami do powiązanych materiałów.

**Nawigacja w przeglądarce**: Otwórz `index.md` w przeglądarce markdown lub przeglądarce internetowej. Wszystkie wewnętrzne linki są względne i działają offline.

**Eksport PDF**: Tę dokumentację można połączyć w pojedynczy plik PDF do czytania offline.

---

## Status projektu

**Funkcje ukończone**: Wszystkie reguły konsensusu, wydobycie, przydziały i funkcje portfela zaimplementowane.

**Dokumentacja ukończona**: Wszystkie 8 rozdziałów ukończonych i zweryfikowanych względem bazy kodu.

**Testnet aktywny**: Obecnie w fazie testnet dla testów społeczności.

---

## Współpraca

Wkład w dokumentację jest mile widziany. Prosimy o utrzymanie:
- Dokładności technicznej nad rozwlekłością
- Krótkich, rzeczowych wyjaśnień
- Brak kodu lub pseudokodu w dokumentacji (zamiast tego odniesienia do plików źródłowych)
- Tylko zaimplementowane funkcje (bez spekulacyjnych funkcji)

---

## Licencja

Bitcoin-PoCX dziedziczy licencję MIT Bitcoin Core. Zobacz `COPYING` w katalogu głównym repozytorium.

Atrybucja frameworka PoCX core udokumentowana w [Rozdziale 2: Format plot](2-plot-format.md).

---

**Rozpocznij czytanie**: [Rozdział 1: Wprowadzenie i przegląd →](1-introduction.md)
