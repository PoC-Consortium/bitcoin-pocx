# Bitcoin-PoCX: Energieeffizienter Konsens für Bitcoin Core

**Version**: 2.0 Entwurf
**Datum**: Dezember 2025
**Organisation**: Proof of Capacity Consortium

---

## Zusammenfassung

Bitcoins Proof-of-Work (PoW)-Konsens bietet robuste Sicherheit, verbraucht jedoch aufgrund kontinuierlicher Echtzeit-Hash-Berechnungen erhebliche Energie. Wir stellen Bitcoin-PoCX vor, einen Bitcoin-Fork, der PoW durch Proof of Capacity (PoC) ersetzt. Dabei berechnen Miner während des Plottens große Mengen festplattengespeicherter Hashes vor und speichern diese, um anschließend durch leichtgewichtige Suchabfragen zu minen statt durch fortlaufendes Hashen. Durch die Verlagerung der Berechnung von der Mining-Phase in eine einmalige Plotting-Phase reduziert Bitcoin-PoCX den Energieverbrauch drastisch, ermöglicht gleichzeitig Mining auf handelsüblicher Hardware, senkt die Einstiegshürden und mindert die bei ASIC-dominiertem PoW inhärenten Zentralisierungstendenzen – all dies unter Beibehaltung der Sicherheitsannahmen und des wirtschaftlichen Verhaltens von Bitcoin.

Unsere Implementierung führt mehrere wichtige Innovationen ein:
(1) Ein gehärtetes Plot-Format, das alle bekannten Zeit-Speicher-Kompromiss-Angriffe in bestehenden PoC-Systemen eliminiert und sicherstellt, dass die effektive Mining-Leistung strikt proportional zur zugewiesenen Speicherkapazität bleibt;
(2) Den Time-Bending-Algorithmus, der Deadline-Verteilungen von exponentiell zu Chi-Quadrat transformiert und so die Blockzeit-Varianz ohne Änderung des Mittelwerts reduziert;
(3) Einen OP_RETURN-basierten Forging-Zuweisungsmechanismus für nicht-verwahrtes Pool-Mining; und
(4) Dynamische Kompressionsskalierung, die die Plot-Generierungsschwierigkeit entsprechend der Halving-Zeitpläne erhöht, um langfristige Sicherheitsmargen bei fortschreitender Hardware-Entwicklung zu erhalten.

Bitcoin-PoCX behält die Architektur von Bitcoin Core durch minimale, feature-gekennzeichnete Modifikationen bei und isoliert die PoC-Logik vom bestehenden Konsenscode. Das System bewahrt Bitcoins Geldpolitik durch ein Ziel-Blockintervall von 120 Sekunden und passt die Blocksubvention auf 10 BTC an. Die reduzierte Subvention gleicht die fünffache Erhöhung der Blockfrequenz aus, hält die langfristige Emissionsrate im Einklang mit Bitcoins ursprünglichem Zeitplan und erhält das Maximum von ca. 21 Millionen Einheiten.

---

## 1. Einleitung

### 1.1 Motivation

Bitcoins Proof-of-Work (PoW)-Konsens hat sich über mehr als ein Jahrzehnt als sicher erwiesen, jedoch zu erheblichen Kosten: Miner müssen kontinuierlich Rechenressourcen aufwenden, was zu hohem Energieverbrauch führt. Über Effizienzbedenken hinaus gibt es eine umfassendere Motivation: die Erforschung alternativer Konsensmechanismen, die Sicherheit gewährleisten und gleichzeitig die Teilnahmehürden senken. PoC ermöglicht praktisch jedem mit handelsüblicher Speicherhardware effektiv zu minen, was die bei ASIC-dominiertem PoW-Mining beobachteten Zentralisierungstendenzen reduziert.

Proof of Capacity (PoC) erreicht dies, indem Mining-Leistung von Speicherzusage statt laufender Berechnung abgeleitet wird. Miner berechnen große Mengen festplattengespeicherter Hashes – Plots – während einer einmaligen Plotting-Phase vor. Mining besteht dann aus leichtgewichtigen Suchabfragen, was den Energieverbrauch drastisch reduziert und gleichzeitig die Sicherheitsannahmen eines ressourcenbasierten Konsenses bewahrt.

### 1.2 Integration mit Bitcoin Core

Bitcoin-PoCX integriert PoC-Konsens in Bitcoin Core, anstatt eine neue Blockchain zu erstellen. Dieser Ansatz nutzt die bewiesene Sicherheit von Bitcoin Core, den ausgereiften Netzwerk-Stack und weit verbreitete Werkzeuge, während Modifikationen minimal und feature-gekennzeichnet bleiben. Die PoC-Logik ist vom bestehenden Konsenscode isoliert, sodass Kernfunktionalität – Blockvalidierung, Wallet-Operationen, Transaktionsformate – weitgehend unverändert bleibt.

### 1.3 Designziele

**Sicherheit**: Beibehaltung Bitcoin-äquivalenter Robustheit; Angriffe erfordern Mehrheits-Speicherkapazität.

**Effizienz**: Reduzierung der laufenden Rechenlast auf Festplatten-I/O-Niveau.

**Zugänglichkeit**: Ermöglichung von Mining mit handelsüblicher Hardware, Senkung der Einstiegshürden.

**Minimale Integration**: Einführung von PoC-Konsens mit minimalem Modifikationsumfang.

---

## 2. Hintergrund: Proof of Capacity

### 2.1 Geschichte

Proof of Capacity (PoC) wurde 2014 von Burstcoin als energieeffiziente Alternative zu Proof-of-Work (PoW) eingeführt. Burstcoin demonstrierte, dass Mining-Leistung von zugewiesenem Speicher statt kontinuierlichem Echtzeit-Hashen abgeleitet werden kann: Miner berechneten einmalig große Datensätze („Plots") vor und minten dann, indem sie kleine, festgelegte Teile davon lasen.

Frühe PoC-Implementierungen bewiesen die Machbarkeit des Konzepts, zeigten aber auch, dass Plot-Format und kryptografische Struktur entscheidend für die Sicherheit sind. Mehrere Zeit-Speicher-Kompromisse ermöglichten Angreifern, effektiv mit weniger Speicher zu minen als ehrliche Teilnehmer. Dies verdeutlichte, dass PoC-Sicherheit vom Plot-Design abhängt – nicht nur davon, Speicher als Ressource zu verwenden.

Burstcoins Vermächtnis etablierte PoC als praktikablen Konsensmechanismus und legte das Fundament, auf dem PoCX aufbaut.

### 2.2 Kernkonzepte

PoC-Mining basiert auf großen, vorberechneten Plot-Dateien, die auf der Festplatte gespeichert sind. Diese Plots enthalten „eingefrorene Berechnung": Aufwendiges Hashen wird einmal während des Plottens durchgeführt, und Mining besteht dann aus leichtgewichtigen Festplattenlesevorgängen und einfacher Verifikation. Kernelemente umfassen:

**Nonce:**
Die grundlegende Einheit der Plot-Daten. Jede Nonce enthält 4096 Scoops (insgesamt 256 KiB), die via Shabal256 aus der Miner-Adresse und dem Nonce-Index generiert werden.

**Scoop:**
Ein 64-Byte-Segment innerhalb einer Nonce. Für jeden Block wählt das Netzwerk deterministisch einen Scoop-Index (0–4095) basierend auf der Generierungssignatur des vorherigen Blocks. Nur dieser Scoop pro Nonce muss gelesen werden.

**Generierungssignatur:**
Ein 256-Bit-Wert, der vom vorherigen Block abgeleitet wird. Er liefert Entropie für die Scoop-Auswahl und verhindert, dass Miner zukünftige Scoop-Indizes vorhersagen können.

**Warp:**
Eine strukturelle Gruppe von 4096 Nonces (1 GiB). Warps sind die relevante Einheit für kompressionsresistente Plot-Formate.

### 2.3 Mining-Prozess und Qualitätspipeline

PoC-Mining besteht aus einem einmaligen Plotting-Schritt und einer leichtgewichtigen pro-Block-Routine:

**Einmalige Einrichtung:**
- Plot-Generierung: Berechnung von Nonces via Shabal256 und Schreiben auf die Festplatte.

**Pro-Block-Mining:**
- Scoop-Auswahl: Bestimmung des Scoop-Index aus der Generierungssignatur.
- Plot-Scanning: Lesen dieses Scoops von allen Nonces in den Miner-Plots.

**Qualitätspipeline:**
- Rohqualität: Hashen jedes Scoops mit der Generierungssignatur mittels Shabal256Lite ergibt einen 64-Bit-Qualitätswert (niedriger ist besser).
- Deadline: Umwandlung der Qualität in eine Deadline unter Verwendung des Basisziels (ein schwierigkeitsangepasster Parameter, der sicherstellt, dass das Netzwerk sein Ziel-Blockintervall erreicht): `deadline = quality / base_target`
- Gebogene Deadline: Anwendung der Time-Bending-Transformation zur Varianzreduzierung bei Beibehaltung der erwarteten Blockzeit.

**Block-Forging:**
Der Miner mit der kürzesten (gebogenen) Deadline schmiedet den nächsten Block, sobald diese Zeit verstrichen ist.

Anders als bei PoW findet praktisch alle Berechnung während des Plottens statt; aktives Mining ist primär festplattengebunden und sehr energiesparend.

### 2.4 Bekannte Schwachstellen in früheren Systemen

**POC1-Verteilungsfehler:**
Das ursprüngliche Burstcoin POC1-Format wies eine strukturelle Verzerrung auf: Scoops mit niedrigem Index waren deutlich günstiger spontan nachzuberechnen als Scoops mit hohem Index. Dies führte zu einem ungleichmäßigen Zeit-Speicher-Kompromiss, der Angreifern ermöglichte, den erforderlichen Speicher für diese Scoops zu reduzieren und die Annahme zu brechen, dass alle vorberechneten Daten gleich teuer waren.

**XOR-Kompressionsangriff (POC2):**
Bei POC2 kann ein Angreifer beliebige 8192 Nonces nehmen und in zwei Blöcke von je 4096 Nonces (A und B) aufteilen. Anstatt beide Blöcke zu speichern, speichert der Angreifer nur eine abgeleitete Struktur: `A XOR transpose(B)`, wobei die Transponierung Scoop- und Nonce-Indizes vertauscht – Scoop S von Nonce N in Block B wird zu Scoop N von Nonce S.

Beim Mining, wenn Scoop S von Nonce N benötigt wird, rekonstruiert der Angreifer ihn durch:
1. Lesen des gespeicherten XOR-Werts an Position (S, N)
2. Berechnung von Nonce N aus Block A zur Ermittlung von Scoop S
3. Berechnung von Nonce S aus Block B zur Ermittlung des transponierten Scoops N
4. XOR-Verknüpfung aller drei Werte zur Wiederherstellung des ursprünglichen 64-Byte-Scoops

Dies reduziert den Speicher um 50%, während nur zwei Nonce-Berechnungen pro Abfrage erforderlich sind – ein Aufwand weit unter der Schwelle, die zur Durchsetzung vollständiger Vorberechnung nötig wäre. Der Angriff ist praktikabel, weil die Berechnung einer Zeile (eine Nonce, 4096 Scoops) günstig ist, während die Berechnung einer Spalte (ein einzelner Scoop über 4096 Nonces) die Neugenerierung aller Nonces erfordern würde. Die Transpose-Struktur legt dieses Ungleichgewicht offen.

Dies demonstrierte die Notwendigkeit eines Plot-Formats, das solche strukturierte Rekombination verhindert und den zugrundeliegenden Zeit-Speicher-Kompromiss beseitigt. Abschnitt 3.3 beschreibt, wie PoCX diese Schwachstelle adressiert und behebt.

### 2.5 Übergang zu PoCX

Die Einschränkungen früherer PoC-Systeme machten deutlich, dass sicheres, faires und dezentrales Speicher-Mining von sorgfältig entwickelten Plot-Strukturen abhängt. Bitcoin-PoCX adressiert diese Probleme mit einem gehärteten Plot-Format, verbesserter Deadline-Verteilung und Mechanismen für dezentrales Pool-Mining – beschrieben im nächsten Abschnitt.

---

## 3. PoCX Plot-Format

### 3.1 Basis-Nonce-Konstruktion

Eine Nonce ist eine 256-KiB-Datenstruktur, die deterministisch aus drei Parametern abgeleitet wird: einer 20-Byte-Adress-Nutzlast, einem 32-Byte-Seed und einem 64-Bit-Nonce-Index.

Die Konstruktion beginnt mit der Kombination dieser Eingaben und deren Hashen mit Shabal256 zur Erzeugung eines initialen Hashs. Dieser Hash dient als Ausgangspunkt für einen iterativen Erweiterungsprozess: Shabal256 wird wiederholt angewendet, wobei jeder Schritt von zuvor generierten Daten abhängt, bis der gesamte 256-KiB-Puffer gefüllt ist. Dieser verkettete Prozess repräsentiert die während des Plottens geleistete Rechenarbeit.

Ein abschließender Diffusionsschritt hasht den fertiggestellten Puffer und verknüpft das Ergebnis mit XOR über alle Bytes. Dies stellt sicher, dass der gesamte Puffer berechnet wurde und Miner die Kalkulation nicht abkürzen können. Anschließend wird der PoC2-Shuffle angewendet, der die untere und obere Hälfte jedes Scoops vertauscht, um zu garantieren, dass alle Scoops äquivalenten Rechenaufwand erfordern.

Die fertige Nonce besteht aus 4096 Scoops von je 64 Bytes und bildet die fundamentale Einheit im Mining.

### 3.2 SIMD-ausgerichtetes Plot-Layout

Um den Durchsatz auf moderner Hardware zu maximieren, organisiert PoCX Nonce-Daten auf der Festplatte so, dass vektorisierte Verarbeitung erleichtert wird. Anstatt jede Nonce sequenziell zu speichern, richtet PoCX entsprechende 4-Byte-Wörter über mehrere aufeinanderfolgende Nonces zusammenhängend aus. Dies ermöglicht einem einzelnen Speicherabruf, Daten für alle SIMD-Lanes bereitzustellen, minimiert Cache-Misses und eliminiert Scatter-Gather-Overhead.

```
Traditionelles Layout:
Nonce0: [W0][W1][W2][W3]...
Nonce1: [W0][W1][W2][W3]...
Nonce2: [W0][W1][W2][W3]...

PoCX SIMD-Layout:
Wort0: [N0][N1][N2]...[N15]
Wort1: [N0][N1][N2]...[N15]
Wort2: [N0][N1][N2]...[N15]
```

Dieses Layout profitiert sowohl CPU- als auch GPU-Miner und ermöglicht hochdurchsatzfähige, parallelisierte Scoop-Auswertung bei Beibehaltung eines einfachen skalaren Zugriffsmusters für Konsensverifikation. Es stellt sicher, dass Mining durch Speicherbandbreite begrenzt wird statt durch CPU-Berechnung, was den energiesparenden Charakter von Proof of Capacity erhält.

### 3.3 Warp-Struktur und XOR-Transpose-Kodierung

Ein Warp ist die fundamentale Speichereinheit in PoCX, bestehend aus 4096 Nonces (1 GiB). Das unkomprimierte Format, bezeichnet als X0, enthält Basis-Nonces genau so, wie sie durch die Konstruktion in Abschnitt 3.1 erzeugt wurden.

**XOR-Transpose-Kodierung (X1)**

Um die strukturellen Zeit-Speicher-Kompromisse früherer PoC-Systeme zu beseitigen, leitet PoCX ein gehärtetes Mining-Format, X1, ab, indem es XOR-Transpose-Kodierung auf Paare von X0-Warps anwendet.

Um Scoop S von Nonce N in einem X1-Warp zu konstruieren:

1. Nimm Scoop S von Nonce N vom ersten X0-Warp (direkte Position)
2. Nimm Scoop N von Nonce S vom zweiten X0-Warp (transponierte Position)
3. Verknüpfe die beiden 64-Byte-Werte mit XOR, um den X1-Scoop zu erhalten

Der Transpose-Schritt vertauscht Scoop- und Nonce-Indizes. In Matrixbegriffen – wobei Zeilen Scoops und Spalten Nonces darstellen – kombiniert er das Element an Position (S, N) im ersten Warp mit dem Element an (N, S) im zweiten.

**Warum dies die Kompressionsangriffsfläche eliminiert**

Die XOR-Transpose-Kodierung verknüpft jeden Scoop mit einer gesamten Zeile und einer gesamten Spalte der zugrundeliegenden X0-Daten. Die Wiederherstellung eines einzelnen X1-Scoops erfordert daher Zugriff auf Daten, die alle 4096 Scoop-Indizes umfassen. Jeder Versuch, fehlende Daten zu berechnen, würde die Neugenerierung von 4096 vollständigen Nonces erfordern statt einer einzelnen Nonce – was die asymmetrische Kostenstruktur beseitigt, die beim XOR-Angriff auf POC2 (Abschnitt 2.4) ausgenutzt wurde.

Folglich wird das Speichern des vollständigen X1-Warps zur einzigen rechnerisch tragfähigen Strategie für Miner, was den Zeit-Speicher-Kompromiss schließt, der in früheren Designs ausgenutzt wurde.

### 3.4 Festplatten-Layout

PoCX-Plot-Dateien bestehen aus vielen aufeinanderfolgenden X1-Warps. Um die betriebliche Effizienz beim Mining zu maximieren, sind die Daten innerhalb jeder Datei nach Scoop organisiert: Alle Scoop-0-Daten von jedem Warp werden sequenziell gespeichert, gefolgt von allen Scoop-1-Daten usw. bis Scoop 4095.

Diese **scoop-sequenzielle Ordnung** ermöglicht Minern, die vollständigen Daten für einen ausgewählten Scoop in einem einzigen sequenziellen Festplattenzugriff zu lesen, minimiert Suchzeiten und maximiert den Durchsatz auf handelsüblichen Speichergeräten.

Kombiniert mit der XOR-Transpose-Kodierung aus Abschnitt 3.3 stellt dieses Layout sicher, dass die Datei sowohl **strukturell gehärtet** als auch **betrieblich effizient** ist: Sequenzielle Scoop-Ordnung unterstützt optimale Festplatten-I/O, während SIMD-ausgerichtete Speicherlayouts (siehe Abschnitt 3.2) hochdurchsatzfähige, parallelisierte Scoop-Auswertung ermöglichen.

### 3.5 Proof-of-Work-Skalierung (Xn)

PoCX implementiert skalierbare Vorberechnung durch das Konzept der Skalierungsstufen, bezeichnet als Xn, um sich an sich entwickelnde Hardware-Leistung anzupassen. Das Basis-X1-Format repräsentiert die erste XOR-Transpose-gehärtete Warp-Struktur.

Jede Skalierungsstufe Xn erhöht die in jedem Warp eingebettete Proof-of-Work exponentiell relativ zu X1: Die erforderliche Arbeit auf Stufe Xn ist 2^(n-1) mal die von X1. Der Übergang von Xn zu Xn+1 entspricht operativ der Anwendung eines XOR über Paare benachbarter Warps, wobei inkrementell mehr Proof-of-Work eingebettet wird, ohne die zugrundeliegende Plot-Größe zu ändern.

Bestehende Plot-Dateien, die auf niedrigeren Skalierungsstufen erstellt wurden, können weiterhin für Mining verwendet werden, tragen jedoch proportional weniger Arbeit zur Blockgenerierung bei, was ihre niedrigere eingebettete Proof-of-Work widerspiegelt. Dieser Mechanismus stellt sicher, dass PoCX-Plots im Laufe der Zeit sicher, flexibel und wirtschaftlich ausgewogen bleiben.

### 3.6 Seed-Funktionalität

Der Seed-Parameter ermöglicht mehrere nicht überlappende Plots pro Adresse ohne manuelle Koordination.

**Problem (POC2)**: Miner mussten Nonce-Bereiche über Plot-Dateien manuell verfolgen, um Überlappungen zu vermeiden. Überlappende Nonces verschwenden Speicher, ohne die Mining-Leistung zu erhöhen.

**Lösung**: Jedes `(Adresse, Seed)`-Paar definiert einen unabhängigen Schlüsselraum. Plots mit verschiedenen Seeds überlappen sich nie, unabhängig von Nonce-Bereichen. Miner können Plots frei ohne Koordination erstellen.

---

## 4. Proof of Capacity Konsens

PoCX erweitert Bitcoins Nakamoto-Konsens mit einem speichergebundenen Beweismechanismus. Anstatt Energie für wiederholtes Hashen aufzuwenden, committen Miner große Mengen vorberechneter Daten – Plots – auf Festplatte. Während der Blockgenerierung müssen sie einen kleinen, unvorhersagbaren Teil dieser Daten finden und in einen Beweis transformieren. Der Miner, der den besten Beweis innerhalb des erwarteten Zeitfensters liefert, erhält das Recht, den nächsten Block zu schmieden.

Dieses Kapitel beschreibt, wie PoCX Block-Metadaten strukturiert, Unvorhersagbarkeit ableitet und statischen Speicher in einen sicheren, varianzarmen Konsensmechanismus transformiert.

### 4.1 Blockstruktur

PoCX behält den vertrauten Bitcoin-artigen Block-Header bei, führt aber zusätzliche Konsensfelder ein, die für kapazitätsbasiertes Mining erforderlich sind. Diese Felder binden den Block gemeinsam an den gespeicherten Plot des Miners, die Netzwerkschwierigkeit und die kryptografische Entropie, die jede Mining-Herausforderung definiert.

Auf hoher Ebene enthält ein PoCX-Block: die Blockhöhe, explizit aufgezeichnet zur Vereinfachung der kontextuellen Validierung; die Generierungssignatur, eine Quelle frischer Entropie, die jeden Block mit seinem Vorgänger verknüpft; das Basisziel, das die Netzwerkschwierigkeit in inverser Form repräsentiert (höhere Werte entsprechen einfacherem Mining); den PoCX-Beweis, der den Plot des Miners identifiziert, die während des Plottens verwendete Kompressionsstufe, die ausgewählte Nonce und die daraus abgeleitete Qualität; sowie einen Signaturschlüssel und eine Signatur, die die Kontrolle über die zum Schmieden des Blocks verwendete Kapazität beweisen (oder eines zugewiesenen Forging-Schlüssels).

Der Beweis bettet alle konsensrelevanten Informationen ein, die Validatoren benötigen, um die Herausforderung neu zu berechnen, den gewählten Scoop zu verifizieren und die resultierende Qualität zu bestätigen. Durch Erweiterung statt Neugestaltung der Blockstruktur bleibt PoCX konzeptionell mit Bitcoin ausgerichtet, während es eine fundamental andere Quelle für Mining-Arbeit ermöglicht.

### 4.2 Generierungssignaturkette

Die Generierungssignatur liefert die für sicheres Proof of Capacity Mining erforderliche Unvorhersagbarkeit. Jeder Block leitet seine Generierungssignatur von der Signatur und dem Unterzeichner des vorherigen Blocks ab, sodass Miner zukünftige Herausforderungen nicht voraussehen oder vorteilhafte Plot-Regionen vorberechnen können:

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

Dies erzeugt eine Sequenz kryptografisch starker, minerabhängiger Entropiewerte. Da der öffentliche Schlüssel eines Miners erst bei Veröffentlichung des vorherigen Blocks bekannt wird, kann kein Teilnehmer zukünftige Scoop-Auswahlen vorhersagen. Dies verhindert selektive Vorberechnung oder strategisches Plotten und stellt sicher, dass jeder Block wirklich frische Mining-Arbeit einführt.

### 4.3 Forging-Prozess

Mining in PoCX besteht aus der Transformation gespeicherter Daten in einen Beweis, der vollständig durch die Generierungssignatur gesteuert wird. Obwohl der Prozess deterministisch ist, stellt die Unvorhersagbarkeit der Signatur sicher, dass Miner sich nicht im Voraus vorbereiten können und wiederholt auf ihre gespeicherten Plots zugreifen müssen.

**Herausforderungsableitung (Scoop-Auswahl):** Der Miner hasht die aktuelle Generierungssignatur mit der Blockhöhe, um einen Scoop-Index im Bereich 0–4095 zu erhalten. Dieser Index bestimmt, welches 64-Byte-Segment jeder gespeicherten Nonce am Beweis teilnimmt. Da die Generierungssignatur vom Unterzeichner des vorherigen Blocks abhängt, wird die Scoop-Auswahl erst zum Zeitpunkt der Blockveröffentlichung bekannt.

**Beweisauswertung (Qualitätsberechnung):** Für jede Nonce in einem Plot ruft der Miner den ausgewählten Scoop ab und hasht ihn zusammen mit der Generierungssignatur, um eine Qualität zu erhalten – einen 64-Bit-Wert, dessen Größe die Wettbewerbsfähigkeit des Miners bestimmt. Niedrigere Qualität entspricht einem besseren Beweis.

**Deadline-Bildung (Time Bending):** Die rohe Deadline ist proportional zur Qualität und umgekehrt proportional zum Basisziel. Bei Legacy-PoC-Designs folgten diese Deadlines einer stark verzerrten Exponentialverteilung, die lange Verzögerungen am Ende erzeugte, die keine zusätzliche Sicherheit boten. PoCX transformiert die rohe Deadline mittels Time Bending (Abschnitt 4.4), reduziert die Varianz und stellt vorhersagbare Blockintervalle sicher. Sobald die gebogene Deadline verstrichen ist, schmiedet der Miner einen Block, indem er den Beweis einbettet und ihn mit dem effektiven Forging-Schlüssel signiert.

### 4.4 Time Bending

Proof of Capacity erzeugt exponentiell verteilte Deadlines. Nach einer kurzen Zeitspanne – typischerweise einige Dutzend Sekunden – hat jeder Miner bereits seinen besten Beweis identifiziert, und jede zusätzliche Wartezeit trägt nur Latenz bei, keine Sicherheit.

Time Bending formt die Verteilung um, indem es eine Kubikwurzel-Transformation anwendet:

`deadline_bended = scale × (quality / base_target)^(1/3)`

Der Skalierungsfaktor bewahrt die erwartete Blockzeit (120 Sekunden) bei dramatischer Varianzreduzierung. Kurze Deadlines werden erweitert, was die Blockpropagation und Netzwerksicherheit verbessert. Lange Deadlines werden komprimiert, um zu verhindern, dass Ausreißer die Chain verzögern.

![Blockzeit-Verteilungen](blocktime_distributions.svg)

Time Bending erhält den Informationsgehalt des zugrundeliegenden Beweises. Es modifiziert nicht die Wettbewerbsfähigkeit zwischen Minern; es verteilt nur Wartezeit um, um glattere, vorhersagbarere Blockintervalle zu erzeugen. Die Implementierung verwendet Festkomma-Arithmetik (Q42-Format) und 256-Bit-Integer, um deterministische Ergebnisse auf allen Plattformen sicherzustellen.

### 4.5 Schwierigkeitsanpassung

PoCX reguliert die Blockproduktion mittels des Basisziels, einem inversen Schwierigkeitsmaß. Die erwartete Blockzeit ist proportional zum Verhältnis `quality / base_target`, sodass eine Erhöhung des Basisziels die Blockerstellung beschleunigt, während eine Verringerung die Chain verlangsamt.

Die Schwierigkeit wird bei jedem Block angepasst, basierend auf der gemessenen Zeit zwischen den letzten Blöcken im Vergleich zum Zielintervall. Diese häufige Anpassung ist notwendig, weil Speicherkapazität schnell hinzugefügt oder entfernt werden kann – anders als Bitcoins Hashpower, die sich langsamer ändert.

Die Anpassung folgt zwei leitenden Beschränkungen: **Gradualität** – Änderungen pro Block sind begrenzt (maximal ±20%), um Oszillationen oder Manipulation zu vermeiden; **Härtung** – das Basisziel kann seinen Genesis-Wert nicht überschreiten, was verhindert, dass das Netzwerk die Schwierigkeit jemals unter die ursprünglichen Sicherheitsannahmen senkt.

### 4.6 Blockgültigkeit

Ein Block in PoCX ist gültig, wenn er einen verifizierbaren speicherabgeleiteten Beweis präsentiert, der mit dem Konsenszustand konsistent ist. Validatoren berechnen unabhängig die Scoop-Auswahl nach, leiten die erwartete Qualität aus der übermittelten Nonce und den Plot-Metadaten ab, wenden die Time-Bending-Transformation an und bestätigen, dass der Miner berechtigt war, den Block zur deklarierten Zeit zu schmieden.

Konkret erfordert ein gültiger Block: die Deadline ist seit dem Elternblock verstrichen; die übermittelte Qualität entspricht der berechneten Qualität für den Beweis; die Skalierungsstufe erfüllt das Netzwerk-Minimum; die Generierungssignatur entspricht dem erwarteten Wert; das Basisziel entspricht dem erwarteten Wert; die Blocksignatur stammt vom effektiven Unterzeichner; und die Coinbase zahlt an die Adresse des effektiven Unterzeichners.

---

## 5. Forging-Zuweisungen

### 5.1 Motivation

Forging-Zuweisungen ermöglichen Plotbesitzern, Block-Schmiedeautorität zu delegieren, ohne jemals das Eigentum an ihren Plots aufzugeben. Dieser Mechanismus ermöglicht Pool-Mining und Cold-Storage-Konfigurationen bei Beibehaltung der Sicherheitsgarantien von PoCX.

Beim Pool-Mining können Plotbesitzer einen Pool autorisieren, in ihrem Namen Blöcke zu schmieden. Der Pool assembliert Blöcke und verteilt Belohnungen, erlangt aber niemals Verwahrung über die Plots selbst. Die Delegation ist jederzeit widerrufbar, und Plotbesitzer bleiben frei, einen Pool zu verlassen oder Konfigurationen zu ändern, ohne neu zu plotten.

Zuweisungen unterstützen auch eine saubere Trennung zwischen Cold- und Hot-Keys. Der private Schlüssel, der den Plot kontrolliert, kann offline bleiben, während ein separater Forging-Schlüssel – auf einer Online-Maschine gespeichert – Blöcke produziert. Ein Kompromiss des Forging-Schlüssels kompromittiert daher nur Forging-Autorität, nicht Eigentum. Der Plot bleibt sicher und die Zuweisung kann widerrufen werden, was die Sicherheitslücke sofort schließt.

Forging-Zuweisungen bieten somit betriebliche Flexibilität bei Beibehaltung des Prinzips, dass Kontrolle über gespeicherte Kapazität niemals an Intermediäre übertragen werden darf.

### 5.2 Zuweisungsprotokoll

Zuweisungen werden durch OP_RETURN-Transaktionen deklariert, um unnötiges Wachstum des UTXO-Sets zu vermeiden. Eine Zuweisungstransaktion spezifiziert die Plot-Adresse und die Forging-Adresse, die autorisiert ist, Blöcke unter Verwendung der Kapazität dieses Plots zu produzieren. Eine Widerrufstransaktion enthält nur die Plot-Adresse. In beiden Fällen beweist der Plotbesitzer die Kontrolle durch Signieren der Ausgabeeingabe der Transaktion.

Jede Zuweisung durchläuft eine Sequenz wohldefinierter Zustände (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Nach Bestätigung einer Zuweisungstransaktion tritt das System in eine kurze Aktivierungsphase ein. Diese Verzögerung – 30 Blöcke, etwa eine Stunde – gewährleistet Stabilität während Block-Races und verhindert feindliches schnelles Wechseln von Forging-Identitäten. Sobald diese Aktivierungsperiode abläuft, wird die Zuweisung aktiv und bleibt es, bis der Plotbesitzer einen Widerruf ausstellt.

Widerrufe gehen in eine längere Verzögerungsperiode von 720 Blöcken über, ungefähr ein Tag. Während dieser Zeit bleibt die vorherige Forging-Adresse aktiv. Diese längere Verzögerung bietet betriebliche Stabilität für Pools, verhindert strategisches „Zuweisungs-Hopping" und gibt Infrastrukturanbietern genügend Sicherheit für effizienten Betrieb. Nach Ablauf der Widerrufsverzögerung wird der Widerruf abgeschlossen, und der Plotbesitzer kann einen neuen Forging-Schlüssel benennen.

Der Zuweisungszustand wird in einer Konsensschicht-Struktur parallel zum UTXO-Set gepflegt und unterstützt Undo-Daten für sichere Behandlung von Chain-Reorganisationen.

### 5.3 Validierungsregeln

Für jeden Block bestimmen Validatoren den effektiven Unterzeichner – die Adresse, die den Block signieren und die Coinbase-Belohnung erhalten muss. Dieser Unterzeichner hängt ausschließlich vom Zuweisungszustand bei der Blockhöhe ab.

Wenn keine Zuweisung existiert oder die Zuweisung ihre Aktivierungsphase noch nicht abgeschlossen hat, bleibt der Plotbesitzer der effektive Unterzeichner. Sobald eine Zuweisung aktiv wird, muss die zugewiesene Forging-Adresse signieren. Während des Widerrufs signiert die Forging-Adresse weiterhin, bis die Widerrufsverzögerung abläuft. Erst dann kehrt die Autorität zum Plotbesitzer zurück.

Validatoren erzwingen, dass die Blocksignatur vom effektiven Unterzeichner produziert wird, dass die Coinbase an dieselbe Adresse zahlt und dass alle Übergänge die vorgeschriebenen Aktivierungs- und Widerrufsverzögerungen befolgen. Nur der Plotbesitzer kann Zuweisungen erstellen oder widerrufen; Forging-Schlüssel können ihre eigenen Berechtigungen nicht modifizieren oder erweitern.

Forging-Zuweisungen führen somit flexible Delegation ohne Vertrauen ein. Eigentum an der zugrundeliegenden Kapazität bleibt immer kryptografisch beim Plotbesitzer verankert, während Forging-Autorität delegiert, rotiert oder widerrufen werden kann, wie es die betrieblichen Bedürfnisse erfordern.

---

## 6. Dynamische Skalierung

Mit der Entwicklung der Hardware sinken die Kosten für die Berechnung von Plots relativ zum Lesen vorberechneter Arbeit von der Festplatte. Ohne Gegenmaßnahmen könnten Angreifer schließlich Beweise schneller spontan generieren als Miner gespeicherte Arbeit lesen, was das Sicherheitsmodell von Proof of Capacity untergraben würde.

Um die beabsichtigte Sicherheitsmarge zu erhalten, implementiert PoCX einen Skalierungsplan: Die minimal erforderliche Skalierungsstufe für Plots steigt im Laufe der Zeit. Jede Skalierungsstufe Xn, wie in Abschnitt 3.5 beschrieben, bettet exponentiell mehr Proof-of-Work in die Plot-Struktur ein und stellt sicher, dass Miner weiterhin erhebliche Speicherressourcen committen, auch wenn Berechnung billiger wird.

Der Zeitplan richtet sich nach den wirtschaftlichen Anreizen des Netzwerks, insbesondere Blockbelohnungs-Halvings. Mit abnehmender Belohnung pro Block steigt das Mindestlevel allmählich und bewahrt die Balance zwischen Plotting-Aufwand und Mining-Potenzial:

| Periode | Jahre | Halvings | Min-Skalierung | Plot-Arbeitsmultiplikator |
|---------|-------|----------|----------------|---------------------------|
| Epoche 0 | 0-4 | 0 | X1 | 2× Baseline |
| Epoche 1 | 4-12 | 1-2 | X2 | 4× Baseline |
| Epoche 2 | 12-28 | 3-6 | X3 | 8× Baseline |
| Epoche 3 | 28-60 | 7-14 | X4 | 16× Baseline |
| Epoche 4 | 60-124 | 15-30 | X5 | 32× Baseline |
| Epoche 5 | 124+ | 31+ | X6 | 64× Baseline |

Miner können optional Plots vorbereiten, die das aktuelle Minimum um eine Stufe überschreiten, was ihnen ermöglicht, vorauszuplanen und sofortige Upgrades zu vermeiden, wenn das Netzwerk zur nächsten Epoche wechselt. Dieser optionale Schritt bietet keinen zusätzlichen Vorteil in Bezug auf Blockwahrscheinlichkeit – er ermöglicht lediglich einen reibungsloseren betrieblichen Übergang.

Blöcke mit Beweisen unterhalb der minimalen Skalierungsstufe für ihre Höhe gelten als ungültig. Validatoren prüfen die deklarierte Skalierungsstufe im Beweis gegen die aktuelle Netzwerkanforderung während der Konsensvalidierung und stellen sicher, dass alle teilnehmenden Miner die sich entwickelnden Sicherheitserwartungen erfüllen.

---

## 7. Mining-Architektur

PoCX trennt konsenskritische Operationen von den ressourcenintensiven Aufgaben des Minings, was sowohl Sicherheit als auch Effizienz ermöglicht. Der Node pflegt die Blockchain, validiert Blöcke, verwaltet den Mempool und stellt eine RPC-Schnittstelle bereit. Externe Miner übernehmen Plot-Speicherung, Scoop-Lesen, Qualitätsberechnung und Deadline-Verwaltung. Diese Trennung hält die Konsenslogik einfach und auditierbar, während Miner für Festplattendurchsatz optimieren können.

### 7.1 Mining-RPC-Schnittstelle

Miner interagieren mit dem Node über einen minimalen Satz von RPC-Aufrufen. Der get_mining_info-RPC liefert die aktuelle Blockhöhe, Generierungssignatur, Basisziel, Ziel-Deadline und den akzeptablen Bereich von Plot-Skalierungsstufen. Mit diesen Informationen berechnen Miner Kandidaten-Nonces. Der submit_nonce-RPC ermöglicht Minern, eine vorgeschlagene Lösung einzureichen, einschließlich Plot-Identifikator, Nonce-Index, Skalierungsstufe und Miner-Konto. Der Node wertet die Einreichung aus und antwortet mit der berechneten Deadline, wenn der Beweis gültig ist.

### 7.2 Forging-Scheduler

Der Node pflegt einen Forging-Scheduler, der eingehende Einreichungen verfolgt und nur die beste Lösung für jede Blockhöhe behält. Eingereichte Nonces werden mit eingebauten Schutzmaßnahmen gegen Einreichungsflutung oder Denial-of-Service-Angriffe in die Warteschlange gestellt. Der Scheduler wartet, bis die berechnete Deadline abläuft oder eine überlegene Lösung eintrifft, woraufhin er einen Block assembliert, ihn mit dem effektiven Forging-Schlüssel signiert und im Netzwerk veröffentlicht.

### 7.3 Defensives Forging

Um Timing-Angriffe oder Anreize zur Uhrzeitmanipulation zu verhindern, implementiert PoCX defensives Forging. Wenn ein konkurrierender Block für dieselbe Höhe eintrifft, vergleicht der Scheduler die lokale Lösung mit dem neuen Block. Wenn die lokale Qualität überlegen ist, schmiedet der Node sofort, anstatt auf die ursprüngliche Deadline zu warten. Dies stellt sicher, dass Miner keinen Vorteil erlangen können, indem sie lediglich lokale Uhren anpassen; die beste Lösung gewinnt immer, was Fairness und Netzwerksicherheit bewahrt.

---

## 8. Sicherheitsanalyse

### 8.1 Bedrohungsmodell

PoCX modelliert Angreifer mit erheblichen, aber begrenzten Fähigkeiten. Angreifer können versuchen, das Netzwerk mit ungültigen Transaktionen, fehlerhaften Blöcken oder gefälschten Beweisen zu überlasten, um Validierungspfade zu testen. Sie können ihre lokalen Uhren frei manipulieren und versuchen, Grenzfälle im Konsensverhalten wie Zeitstempelbehandlung, Dynamik der Schwierigkeitsanpassung oder Reorganisationsregeln auszunutzen. Angreifer werden auch erwartet, nach Möglichkeiten zu suchen, die Historie durch gezielte Chain-Forks umzuschreiben.

Das Modell nimmt an, dass keine einzelne Partei eine Mehrheit der gesamten Netzwerk-Speicherkapazität kontrolliert. Wie bei jedem ressourcenbasierten Konsensmechanismus kann ein 51%-Kapazitäts-Angreifer die Chain einseitig reorganisieren; diese fundamentale Einschränkung ist nicht spezifisch für PoCX. PoCX nimmt auch an, dass Angreifer Plot-Daten nicht schneller berechnen können als ehrliche Miner sie von der Festplatte lesen können. Der Skalierungsplan (Abschnitt 6) stellt sicher, dass die für Sicherheit erforderliche Berechnungslücke im Laufe der Zeit mit der Hardware-Entwicklung wächst.

Die folgenden Abschnitte untersuchen jede Hauptangriffsklasse im Detail und beschreiben die in PoCX eingebauten Gegenmaßnahmen.

### 8.2 Kapazitätsangriffe

Wie bei PoW kann ein Angreifer mit Mehrheitskapazität die Historie umschreiben (ein 51%-Angriff). Dies zu erreichen erfordert den Erwerb eines physischen Speicherplatzes, der größer ist als das ehrliche Netzwerk – ein teures und logistisch anspruchsvolles Unterfangen. Sobald die Hardware beschafft ist, sind die Betriebskosten niedrig, aber die Anfangsinvestition schafft einen starken wirtschaftlichen Anreiz, sich ehrlich zu verhalten: Die Untergrabung der Chain würde den Wert der eigenen Vermögensbasis des Angreifers beschädigen.

PoC vermeidet auch das Nothing-at-Stake-Problem, das mit PoS verbunden ist. Obwohl Miner Plots gegen mehrere konkurrierende Forks scannen können, verbraucht jeder Scan echte Zeit – typischerweise in der Größenordnung von Zehn Sekunden pro Chain. Mit einem 120-Sekunden-Blockintervall begrenzt dies inhärent Multi-Fork-Mining, und der Versuch, viele Forks gleichzeitig zu minen, verschlechtert die Leistung bei allen. Fork-Mining ist daher nicht kostenlos; es ist fundamental durch I/O-Durchsatz begrenzt.

Selbst wenn zukünftige Hardware nahezu instantanes Plot-Scanning ermöglichen würde (z.B. Hochgeschwindigkeits-SSDs), würde ein Angreifer immer noch eine erhebliche physische Ressourcenanforderung haben, um eine Mehrheit der Netzwerkkapazität zu kontrollieren, was einen 51%-artigen Angriff teuer und logistisch herausfordernd macht.

Schließlich sind Kapazitätsangriffe weit schwieriger zu mieten als Hashpower-Angriffe. GPU-Rechenleistung kann bei Bedarf beschafft und sofort auf jede PoW-Chain umgeleitet werden. Im Gegensatz dazu erfordert PoC physische Hardware, zeitintensives Plotten und fortlaufende I/O-Operationen. Diese Beschränkungen machen kurzfristige, opportunistische Angriffe weit weniger durchführbar.

### 8.3 Timing-Angriffe

Timing spielt bei Proof of Capacity eine kritischere Rolle als bei Proof of Work. Bei PoW beeinflussen Zeitstempel primär die Schwierigkeitsanpassung; bei PoC bestimmen sie, ob die Deadline eines Miners abgelaufen ist und ob ein Block somit zum Schmieden berechtigt ist. Deadlines werden relativ zum Zeitstempel des Elternblocks gemessen, aber die lokale Uhr eines Nodes wird verwendet, um zu beurteilen, ob ein eingehender Block zu weit in der Zukunft liegt. Aus diesem Grund erzwingt PoCX eine enge Zeitstempeltoleranz: Blöcke dürfen nicht mehr als 15 Sekunden von der lokalen Uhr des Nodes abweichen (im Vergleich zu Bitcoins 2-Stunden-Fenster). Dieses Limit wirkt in beide Richtungen – Blöcke zu weit in der Zukunft werden abgelehnt, und Nodes mit langsamen Uhren können gültige eingehende Blöcke fälschlicherweise ablehnen.

Nodes sollten daher ihre Uhren mittels NTP oder einer gleichwertigen Zeitquelle synchronisieren. PoCX vermeidet bewusst die Abhängigkeit von netzwerkinternen Zeitquellen, um zu verhindern, dass Angreifer die wahrgenommene Netzwerkzeit manipulieren. Nodes überwachen ihre eigene Drift und geben Warnungen aus, wenn die lokale Uhr beginnt, von den letzten Blockzeitstempeln abzuweichen.

Uhrenbeschleunigung – eine schnelle lokale Uhr zu betreiben, um etwas früher zu schmieden – bietet nur marginalen Vorteil. Innerhalb der erlaubten Toleranz stellt defensives Forging (Abschnitt 7.3) sicher, dass ein Miner mit einer besseren Lösung sofort veröffentlicht, wenn er einen unterlegenen frühen Block sieht. Eine schnelle Uhr hilft einem Miner nur, eine bereits gewinnende Lösung einige Sekunden früher zu veröffentlichen; sie kann einen unterlegenen Beweis nicht in einen gewinnenden verwandeln.

Versuche, die Schwierigkeit über Zeitstempel zu manipulieren, sind durch eine ±20%-pro-Block-Anpassungsgrenze und ein 24-Block-rollendes-Fenster begrenzt, was verhindert, dass Miner die Schwierigkeit durch kurzfristige Timing-Spiele bedeutend beeinflussen.

### 8.4 Zeit-Speicher-Kompromiss-Angriffe

Zeit-Speicher-Kompromisse versuchen, Speicheranforderungen zu reduzieren, indem Teile des Plots bei Bedarf neu berechnet werden. Frühere Proof of Capacity Systeme waren für solche Angriffe anfällig, vor allem der POC1-Scoop-Ungleichgewichts-Fehler und der POC2-XOR-Transpose-Kompressionsangriff (Abschnitt 2.4). Beide nutzten Asymmetrien darin aus, wie teuer es war, bestimmte Teile von Plot-Daten zu regenerieren, was Angreifern ermöglichte, Speicher zu sparen bei nur geringem Berechnungsaufwand. Auch alternative Plot-Formate zu PoC2 leiden unter ähnlichen TMTO-Schwächen; ein prominentes Beispiel ist Chia, dessen Plot-Format um einen Faktor größer als 4 beliebig reduziert werden kann.

PoCX beseitigt diese Angriffsflächen vollständig durch seine Nonce-Konstruktion und sein Warp-Format. Innerhalb jeder Nonce hasht der finale Diffusionsschritt den vollständig berechneten Puffer und verknüpft das Ergebnis mit XOR über alle Bytes, was sicherstellt, dass jeder Teil des Puffers von jedem anderen Teil abhängt und nicht abgekürzt werden kann. Danach vertauscht der PoC2-Shuffle die unteren und oberen Hälften jedes Scoops und egalisiert so den Rechenaufwand für die Wiederherstellung jedes Scoops.

PoCX eliminiert ferner den POC2-XOR-Transpose-Kompressionsangriff durch Ableitung seines gehärteten X1-Formats, bei dem jeder Scoop das XOR einer direkten und einer transponierten Position über gepaarte Warps ist; dies verknüpft jeden Scoop mit einer gesamten Zeile und einer gesamten Spalte der zugrundeliegenden X0-Daten, macht die Rekonstruktion so, dass sie Tausende vollständiger Nonces erfordert und beseitigt damit den asymmetrischen Zeit-Speicher-Kompromiss vollständig.

Als Ergebnis ist das Speichern des vollständigen Plots die einzige rechnerisch tragfähige Strategie für Miner. Keine bekannte Abkürzung – sei es partielles Plotten, selektive Regeneration, strukturierte Kompression oder hybride Berechnungs-Speicher-Ansätze – bietet einen bedeutenden Vorteil. PoCX stellt sicher, dass Mining strikt speichergebunden bleibt und Kapazität echte, physische Zusage widerspiegelt.

### 8.5 Zuweisungsangriffe

PoCX verwendet einen deterministischen Zustandsautomaten zur Steuerung aller Plot-zu-Forger-Zuweisungen. Jede Zuweisung durchläuft wohldefinierte Zustände – UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED – mit erzwungenen Aktivierungs- und Widerrufsverzögerungen. Dies stellt sicher, dass ein Miner nicht instantan Zuweisungen ändern kann, um das System zu betrügen oder schnell Forging-Autorität zu wechseln.

Da alle Übergänge kryptografische Beweise erfordern – konkret Signaturen des Plotbesitzers, die gegen das Eingabe-UTXO verifizierbar sind – kann das Netzwerk der Legitimität jeder Zuweisung vertrauen. Versuche, den Zustandsautomaten zu umgehen oder Zuweisungen zu fälschen, werden automatisch während der Konsensvalidierung abgelehnt. Replay-Angriffe werden ebenfalls durch Standard-Bitcoin-artige Transaktions-Replay-Schutzmaßnahmen verhindert, die sicherstellen, dass jede Zuweisungsaktion eindeutig an eine gültige, unausgegebene Eingabe gebunden ist.

Die Kombination aus Zustandsautomaten-Steuerung, erzwungenen Verzögerungen und kryptografischem Beweis macht zuweisungsbasiertes Betrügen praktisch unmöglich: Miner können keine Zuweisungen kapern, schnelle Neuzuweisung während Block-Races durchführen oder Widerrufszeitpläne umgehen.

### 8.6 Signatursicherheit

Blocksignaturen in PoCX dienen als kritische Verbindung zwischen einem Beweis und dem effektiven Forging-Schlüssel und stellen sicher, dass nur autorisierte Miner gültige Blöcke produzieren können.

Um Veränderbarkeitsangriffe zu verhindern, werden Signaturen von der Block-Hash-Berechnung ausgeschlossen. Dies eliminiert Risiken veränderbarer Signaturen, die die Validierung untergraben oder Block-Ersetzungsangriffe ermöglichen könnten.

Um Denial-of-Service-Vektoren zu mindern, sind Signatur- und Public-Key-Größen fixiert – 65 Bytes für kompakte Signaturen und 33 Bytes für komprimierte Public Keys – was verhindert, dass Angreifer Blöcke aufblähen, um Ressourcenerschöpfung auszulösen oder Netzwerkpropagation zu verlangsamen.

---

## 9. Implementierung

PoCX ist als modulare Erweiterung von Bitcoin Core implementiert, wobei der gesamte relevante Code in einem eigenen dedizierten Unterverzeichnis enthalten und durch ein Feature-Flag aktiviert wird. Dieses Design bewahrt die Integrität des Originalcodes und ermöglicht, PoCX sauber zu aktivieren oder zu deaktivieren, was Testen, Auditieren und Synchronhalten mit Upstream-Änderungen vereinfacht.

Die Integration berührt nur die wesentlichen Punkte, die zur Unterstützung von Proof of Capacity notwendig sind. Der Block-Header wurde um PoCX-spezifische Felder erweitert, und die Konsensvalidierung wurde angepasst, um speicherbasierte Beweise neben traditionellen Bitcoin-Prüfungen zu verarbeiten. Das Forging-System, verantwortlich für Deadline-Verwaltung, Scheduling und Miner-Einreichungen, ist vollständig in den PoCX-Modulen enthalten, während RPC-Erweiterungen Mining- und Zuweisungsfunktionalität für externe Clients bereitstellen. Für Benutzer wurde die Wallet-Oberfläche erweitert, um Zuweisungen durch OP_RETURN-Transaktionen zu verwalten, was nahtlose Interaktion mit den neuen Konsensfunktionen ermöglicht.

Alle konsenskritischen Operationen sind in deterministischem C++ ohne externe Abhängigkeiten implementiert, was plattformübergreifende Konsistenz gewährleistet. Shabal256 wird für Hashing verwendet, während Time Bending und Qualitätsberechnung auf Festkomma-Arithmetik und 256-Bit-Operationen setzen. Kryptografische Operationen wie Signaturverifikation nutzen Bitcoin Cores bestehende secp256k1-Bibliothek.

Durch diese Isolierung der PoCX-Funktionalität bleibt die Implementierung auditierbar, wartbar und vollständig kompatibel mit der laufenden Bitcoin Core Entwicklung, was demonstriert, dass ein fundamental neuer speichergebundener Konsensmechanismus mit einer ausgereiften Proof-of-Work-Codebasis koexistieren kann, ohne deren Integrität oder Nutzbarkeit zu beeinträchtigen.

---

## 10. Netzwerkparameter

PoCX baut auf Bitcoins Netzwerkinfrastruktur auf und verwendet dessen Chain-Parameter-Framework wieder. Zur Unterstützung von kapazitätsbasiertem Mining, Blockintervallen, Zuweisungsbehandlung und Plot-Skalierung wurden mehrere Parameter erweitert oder überschrieben. Dies umfasst das Blockzeit-Ziel, die initiale Subvention, den Halving-Zeitplan, Zuweisungs-Aktivierungs- und Widerrufsverzögerungen sowie Netzwerkidentifikatoren wie Magic Bytes, Ports und Bech32-Präfixe. Testnet- und Regtest-Umgebungen passen diese Parameter weiter an, um schnelle Iteration und Low-Capacity-Tests zu ermöglichen.

Die folgenden Tabellen fassen die resultierenden Mainnet-, Testnet- und Regtest-Einstellungen zusammen und zeigen, wie PoCX Bitcoins Kernparameter an ein speichergebundenes Konsensmodell anpasst.

### 10.1 Mainnet

| Parameter | Wert |
|-----------|------|
| Magic Bytes | `0xa7 0x3c 0x91 0x5e` |
| Standardport | 8888 |
| Bech32 HRP | `pocx` |
| Blockzeit-Ziel | 120 Sekunden |
| Initiale Subvention | 10 BTC |
| Halving-Intervall | 1050000 Blöcke (~4 Jahre) |
| Gesamtangebot | ~21 Millionen BTC |
| Zuweisungsaktivierung | 30 Blöcke |
| Zuweisungswiderruf | 720 Blöcke |
| Rollierendes Fenster | 24 Blöcke |

### 10.2 Testnet

| Parameter | Wert |
|-----------|------|
| Magic Bytes | `0x6d 0xf2 0x48 0xb3` |
| Standardport | 18888 |
| Bech32 HRP | `tpocx` |
| Blockzeit-Ziel | 120 Sekunden |
| Andere Parameter | Wie Mainnet |

### 10.3 Regtest

| Parameter | Wert |
|-----------|------|
| Magic Bytes | `0xfa 0xbf 0xb5 0xda` |
| Standardport | 18444 |
| Bech32 HRP | `rpocx` |
| Blockzeit-Ziel | 1 Sekunde |
| Halving-Intervall | 500 Blöcke |
| Zuweisungsaktivierung | 4 Blöcke |
| Zuweisungswiderruf | 8 Blöcke |
| Low-Capacity-Modus | Aktiviert (~4 MB Plots) |

---

## 11. Verwandte Arbeiten

Im Laufe der Jahre haben mehrere Blockchain- und Konsensprojekte speicherbasierte oder hybride Mining-Modelle erforscht. PoCX baut auf diesem Erbe auf und führt gleichzeitig Verbesserungen in Sicherheit, Effizienz und Kompatibilität ein.

**Burstcoin / Signum.** Burstcoin führte 2014 das erste praktische Proof-of-Capacity (PoC)-System ein und definierte Kernkonzepte wie Plots, Nonces, Scoops und deadline-basiertes Mining. Seine Nachfolger, insbesondere Signum (ehemals Burstcoin), erweiterten das Ökosystem und entwickelten sich schließlich zu dem weiter, was als Proof-of-Commitment (PoC+) bekannt ist, das Speicherzusage mit optionalem Staking kombiniert, um effektive Kapazität zu beeinflussen. PoCX erbt die speicherbasierte Mining-Grundlage von diesen Projekten, divergiert aber erheblich durch ein gehärtetes Plot-Format (XOR-Transpose-Kodierung), dynamische Plot-Arbeit-Skalierung, Deadline-Glättung („Time Bending") und ein flexibles Zuweisungssystem – alles bei Verankerung in der Bitcoin Core Codebasis statt Pflege eines eigenständigen Netzwerk-Forks.

**Chia.** Chia implementiert Proof of Space and Time und kombiniert festplattenbasierte Speicherbeweise mit einer Zeitkomponente, die via Verifiable Delay Functions (VDFs) erzwungen wird. Sein Design adressiert bestimmte Bedenken bezüglich Beweiswiederverwendung und frischer Herausforderungsgenerierung, unterschiedlich vom klassischen PoC. PoCX übernimmt dieses zeitverankerte Beweismodell nicht; stattdessen behält es einen speichergebundenen Konsens mit vorhersagbaren Intervallen bei, optimiert für langfristige Kompatibilität mit UTXO-Ökonomie und Bitcoin-abgeleiteten Werkzeugen.

**Spacemesh.** Spacemesh schlägt ein Proof-of-Space-Time (PoST)-Schema vor, das eine DAG-basierte (Mesh-) Netzwerktopologie verwendet. In diesem Modell müssen Teilnehmer periodisch beweisen, dass zugewiesener Speicher über Zeit intakt bleibt, anstatt sich auf einen einzelnen vorberechneten Datensatz zu verlassen. PoCX hingegen verifiziert Speicherzusage nur zur Blockzeit – mit gehärteten Plot-Formaten und rigoroser Beweisvalidierung – und vermeidet den Overhead kontinuierlicher Speicherbeweise bei Beibehaltung von Effizienz und Dezentralisierung.

---

## 12. Fazit

Bitcoin-PoCX demonstriert, dass energieeffizienter Konsens in Bitcoin Core integriert werden kann, während Sicherheitseigenschaften und Wirtschaftsmodell erhalten bleiben. Wichtige Beiträge umfassen die XOR-Transpose-Kodierung (zwingt Angreifer zur Berechnung von 4096 Nonces pro Abfrage, eliminiert den Kompressionsangriff), den Time-Bending-Algorithmus (Verteilungstransformation reduziert Blockzeit-Varianz), das Forging-Zuweisungssystem (OP_RETURN-basierte Delegation ermöglicht nicht-verwahrtes Pool-Mining), dynamische Skalierung (ausgerichtet an Halvings zur Erhaltung von Sicherheitsmargen) und minimale Integration (feature-gekennzeichneter Code isoliert in einem dedizierten Verzeichnis).

Das System befindet sich derzeit in der Testnet-Phase. Mining-Leistung leitet sich von Speicherkapazität statt Hash-Rate ab, was den Energieverbrauch um Größenordnungen reduziert bei Beibehaltung von Bitcoins bewährtem Wirtschaftsmodell.

---

## Referenzen

Bitcoin Core. *Bitcoin Core Repository.* https://github.com/bitcoin/bitcoin

Burstcoin. *Proof of Capacity Technical Documentation.* 2014.

NIST. *SHA-3 Competition: Shabal.* 2008.

Cohen, B., Pietrzak, K. *The Chia Network Blockchain.* 2019.

Spacemesh. *Spacemesh Protocol Documentation.* 2021.

PoC Consortium. *PoCX Framework.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Bitcoin-PoCX Integration.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Lizenz**: MIT
**Organisation**: Proof of Capacity Consortium
**Status**: Testnet-Phase
