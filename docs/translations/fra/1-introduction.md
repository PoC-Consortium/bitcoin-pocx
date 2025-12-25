[📘 Table des matières](index.md) | [Suivant : Format Plot →](2-plot-format.md)

---

# Chapitre 1 : Introduction et présentation

## Qu'est-ce que Bitcoin-PoCX ?

Bitcoin-PoCX est une intégration de Bitcoin Core qui ajoute la prise en charge du consensus **Proof of Capacity neXt generation (PoCX)**. Elle maintient l'architecture existante de Bitcoin Core tout en permettant une alternative de minage écoénergétique basée sur la preuve de capacité en remplacement complet de la preuve de travail.

**Distinction clé** : Il s'agit d'une **nouvelle chaîne** sans rétrocompatibilité avec Bitcoin PoW. Les blocs PoCX sont incompatibles avec les nœuds PoW par conception.

---

## Identité du projet

- **Organisation** : Proof of Capacity Consortium
- **Nom du projet** : Bitcoin-PoCX
- **Nom complet** : Bitcoin Core avec intégration PoCX
- **Statut** : Phase Testnet

---

## Qu'est-ce que la preuve de capacité ?

La preuve de capacité (PoC) est un mécanisme de consensus où la puissance de minage est proportionnelle à l'**espace disque** plutôt qu'à la puissance de calcul. Les mineurs pré-génèrent de grands fichiers plot contenant des hachages cryptographiques, puis utilisent ces plots pour trouver des solutions de bloc valides.

**Efficacité énergétique** : Les fichiers plot sont générés une seule fois et réutilisés indéfiniment. Le minage consomme une puissance CPU minimale — principalement des E/S disque.

**Améliorations PoCX** :
- Correction de l'attaque par compression XOR-transpose (compromis temps-mémoire de 50 % dans POC2)
- Disposition alignée sur 16 nonces pour le matériel moderne
- Preuve de travail évolutive dans la génération de plot (niveaux de mise à l'échelle Xn)
- Intégration C++ native directement dans Bitcoin Core
- Algorithme Time Bending pour une meilleure distribution du temps de bloc

---

## Aperçu de l'architecture

### Structure du dépôt

```
bitcoin-pocx/
├── bitcoin/             # Bitcoin Core v30.0 + intégration PoCX
│   └── src/pocx/        # Implémentation PoCX
├── pocx/                # Framework PoCX core (sous-module, lecture seule)
└── docs/                # Cette documentation
```

### Philosophie d'intégration

**Surface d'intégration minimale** : Modifications isolées dans le répertoire `/src/pocx/` avec des points d'accroche propres dans les couches de validation, minage et RPC de Bitcoin Core.

**Conditionnement par fonctionnalité** : Toutes les modifications sous les gardes préprocesseur `#ifdef ENABLE_POCX`. Bitcoin Core se compile normalement lorsque désactivé.

**Compatibilité amont** : Synchronisation régulière avec les mises à jour de Bitcoin Core maintenue grâce à des points d'intégration isolés.

**Implémentation C++ native** : Algorithmes cryptographiques scalaires (Shabal256, calcul de scoop, compression) intégrés directement dans Bitcoin Core pour la validation du consensus.

---

## Fonctionnalités clés

### 1. Remplacement complet du consensus

- **Structure de bloc** : Les champs spécifiques PoCX remplacent le nonce PoW et les bits de difficulté
  - Signature de génération (entropie de minage déterministe)
  - Cible de base (inverse de la difficulté)
  - Preuve PoCX (ID de compte, seed, nonce)
  - Signature de bloc (prouve la propriété du plot)

- **Validation** : Pipeline de validation en 5 étapes de la vérification d'en-tête à la connexion du bloc

- **Ajustement de difficulté** : Ajustement à chaque bloc utilisant une moyenne mobile des cibles de base récentes

### 2. Algorithme Time Bending

**Problème** : Les temps de bloc PoC traditionnels suivent une distribution exponentielle, entraînant de longs blocs quand aucun mineur ne trouve une bonne solution.

**Solution** : Transformation de distribution de l'exponentielle vers chi-carré en utilisant la racine cubique : `Y = échelle × (X^(1/3))`.

**Effet** : Les très bonnes solutions forgent plus tard (le réseau a le temps de scanner tous les disques, réduit les blocs rapides), les solutions médiocres sont améliorées. Temps de bloc moyen maintenu à 120 secondes, longs blocs réduits.

**Détails** : [Chapitre 3 : Consensus et minage](3-consensus-and-mining.md)

### 3. Système d'assignation de forge

**Capacité** : Les propriétaires de plots peuvent déléguer les droits de forge à d'autres adresses tout en conservant la propriété du plot.

**Cas d'utilisation** :
- Minage en pool (les plots s'assignent à l'adresse du pool)
- Stockage à froid (clé de minage séparée de la propriété du plot)
- Minage multi-parties (infrastructure partagée)

**Architecture** : Conception OP_RETURN uniquement — pas d'UTXOs spéciaux, les assignations sont suivies séparément dans la base de données chainstate.

**Détails** : [Chapitre 4 : Assignations de forge](4-forging-assignments.md)

### 4. Forge défensive

**Problème** : Des horloges rapides pourraient fournir des avantages de timing dans la tolérance future de 15 secondes.

**Solution** : Lors de la réception d'un bloc concurrent à la même hauteur, vérifier automatiquement la qualité locale. Si meilleure, forger immédiatement.

**Effet** : Élimine l'incitation à la manipulation d'horloge — les horloges rapides n'aident que si vous avez déjà la meilleure solution.

**Détails** : [Chapitre 5 : Sécurité temporelle](5-timing-security.md)

### 5. Mise à l'échelle dynamique de la compression

**Alignement économique** : Les exigences de niveau de mise à l'échelle augmentent selon un calendrier exponentiel (Années 4, 12, 28, 60, 124 = halvings 1, 3, 7, 15, 31).

**Effet** : À mesure que les récompenses de bloc diminuent, la difficulté de génération de plot augmente. Maintient une marge de sécurité entre les coûts de création et de consultation de plot.

**Empêche** : L'inflation de capacité due à un matériel plus rapide au fil du temps.

**Détails** : [Chapitre 6 : Paramètres réseau](6-network-parameters.md)

---

## Philosophie de conception

### Sécurité du code

- Pratiques de programmation défensive partout
- Gestion complète des erreurs dans les chemins de validation
- Pas de verrous imbriqués (prévention des interblocages)
- Opérations de base de données atomiques (UTXO + assignations ensemble)

### Architecture modulaire

- Séparation nette entre l'infrastructure Bitcoin Core et le consensus PoCX
- Le framework PoCX core fournit les primitives cryptographiques
- Bitcoin Core fournit le cadre de validation, la base de données, la mise en réseau

### Optimisations de performance

- Ordonnancement de validation en échec rapide (vérifications peu coûteuses en premier)
- Récupération de contexte unique par soumission (pas d'acquisitions répétées de cs_main)
- Opérations de base de données atomiques pour la cohérence

### Sécurité des réorganisations

- Données d'annulation complètes pour les changements d'état d'assignation
- Réinitialisation de l'état de forge lors des changements de pointe de chaîne
- Détection d'obsolescence à tous les points de validation

---

## Différences entre PoCX et Proof of Work

| Aspect | Bitcoin (PoW) | Bitcoin-PoCX |
|--------|---------------|--------------|
| **Ressource de minage** | Puissance de calcul (taux de hachage) | Espace disque (capacité) |
| **Consommation énergétique** | Élevée (hachage continu) | Faible (E/S disque uniquement) |
| **Processus de minage** | Trouver un nonce avec hachage < cible | Trouver un nonce avec deadline < temps écoulé |
| **Difficulté** | Champ `bits`, ajusté tous les 2016 blocs | Champ `base_target`, ajusté à chaque bloc |
| **Temps de bloc** | ~10 minutes (distribution exponentielle) | 120 secondes (time-bended, variance réduite) |
| **Subvention** | 50 BTC → 25 → 12,5 → ... | 10 BTC → 5 → 2,5 → ... |
| **Matériel** | ASICs (spécialisé) | Disques durs (matériel standard) |
| **Identité de minage** | Anonyme | Propriétaire de plot ou délégué |

---

## Configuration requise

### Fonctionnement du nœud

**Identique à Bitcoin Core** :
- **CPU** : Processeur x86_64 moderne
- **Mémoire** : 4-8 Go de RAM
- **Stockage** : Nouvelle chaîne, actuellement vide (peut croître ~4× plus vite que Bitcoin en raison des blocs de 2 minutes et de la base de données d'assignations)
- **Réseau** : Connexion internet stable
- **Horloge** : Synchronisation NTP recommandée pour un fonctionnement optimal

**Note** : Les fichiers plot ne sont PAS requis pour le fonctionnement du nœud.

### Exigences de minage

**Exigences supplémentaires pour le minage** :
- **Fichiers Plot** : Pré-générés en utilisant `pocx_plotter` (implémentation de référence)
- **Logiciel de minage** : `pocx_miner` (implémentation de référence) se connecte via RPC
- **Portefeuille** : `bitcoind` ou `bitcoin-qt` avec clés privées pour l'adresse de minage. Le minage en pool ne nécessite pas de portefeuille local.

---

## Démarrage

### 1. Compiler Bitcoin-PoCX

```bash
# Cloner avec les sous-modules
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Compiler avec PoCX activé
cmake -B build -DENABLE_POCX=ON
cmake --build build
```

**Détails** : Voir `CLAUDE.md` à la racine du dépôt

### 2. Exécuter le nœud

**Nœud uniquement** :
```bash
./build/bin/bitcoind
# ou
./build/bin/bitcoin-qt
```

**Pour le minage** (active l'accès RPC pour les mineurs externes) :
```bash
./build/bin/bitcoind -miningserver
# ou
./build/bin/bitcoin-qt -server -miningserver
```

**Détails** : [Chapitre 6 : Paramètres réseau](6-network-parameters.md)

### 3. Générer les fichiers Plot

Utilisez `pocx_plotter` (implémentation de référence) pour générer des fichiers plot au format PoCX.

**Détails** : [Chapitre 2 : Format Plot](2-plot-format.md)

### 4. Configurer le minage

Utilisez `pocx_miner` (implémentation de référence) pour vous connecter à l'interface RPC de votre nœud.

**Détails** : [Chapitre 7 : Référence RPC](7-rpc-reference.md) et [Chapitre 8 : Guide du portefeuille](8-wallet-guide.md)

---

## Attribution

### Format Plot

Basé sur le format POC2 (Burstcoin) avec des améliorations :
- Correction de la faille de sécurité (attaque par compression XOR-transpose)
- Preuve de travail évolutive
- Disposition optimisée SIMD
- Fonctionnalité seed

### Projets sources

- **pocx_miner** : Implémentation de référence basée sur [scavenger](https://github.com/PoC-Consortium/scavenger)
- **pocx_plotter** : Implémentation de référence basée sur [engraver](https://github.com/PoC-Consortium/engraver)

**Attribution complète** : [Chapitre 2 : Format Plot](2-plot-format.md)

---

## Résumé des spécifications techniques

- **Temps de bloc** : 120 secondes (mainnet), 1 seconde (regtest)
- **Subvention de bloc** : 10 BTC initial, halving tous les 1050000 blocs (~4 ans)
- **Offre totale** : ~21 millions BTC (identique à Bitcoin)
- **Tolérance future** : 15 secondes (blocs jusqu'à 15s d'avance acceptés)
- **Avertissement d'horloge** : 10 secondes (avertit les opérateurs de la dérive temporelle)
- **Délai d'assignation** : 30 blocs (~1 heure)
- **Délai de révocation** : 720 blocs (~24 heures)
- **Format d'adresse** : P2WPKH (bech32, pocx1q...) uniquement pour les opérations de minage PoCX et les assignations de forge

---

## Organisation du code

**Modifications Bitcoin Core** : Changements minimaux aux fichiers core, conditionnés par `#ifdef ENABLE_POCX`

**Nouvelle implémentation PoCX** : Isolée dans le répertoire `src/pocx/`

---

## Considérations de sécurité

### Sécurité temporelle

- Tolérance future de 15 secondes empêche la fragmentation du réseau
- Seuil d'avertissement de 10 secondes alerte les opérateurs sur la dérive d'horloge
- La forge défensive élimine l'incitation à la manipulation d'horloge
- Le Time Bending réduit l'impact de la variance temporelle

**Détails** : [Chapitre 5 : Sécurité temporelle](5-timing-security.md)

### Sécurité des assignations

- Conception OP_RETURN uniquement (pas de manipulation d'UTXO)
- La signature de transaction prouve la propriété du plot
- Les délais d'activation empêchent la manipulation rapide de l'état
- Données d'annulation sécurisées pour les réorganisations pour tous les changements d'état

**Détails** : [Chapitre 4 : Assignations de forge](4-forging-assignments.md)

### Sécurité du consensus

- Signature exclue du hachage de bloc (empêche la malléabilité)
- Tailles de signature bornées (empêche les DoS)
- Validation des bornes de compression (empêche les preuves faibles)
- Ajustement de difficulté à chaque bloc (réactif aux changements de capacité)

**Détails** : [Chapitre 3 : Consensus et minage](3-consensus-and-mining.md)

---

## Statut du réseau

**Mainnet** : Pas encore lancé
**Testnet** : Disponible pour les tests
**Regtest** : Entièrement fonctionnel pour le développement

**Paramètres du bloc Genesis** : [Chapitre 6 : Paramètres réseau](6-network-parameters.md)

---

## Prochaines étapes

**Pour comprendre PoCX** : Continuez vers le [Chapitre 2 : Format Plot](2-plot-format.md) pour découvrir la structure des fichiers plot et l'évolution du format.

**Pour la configuration du minage** : Passez au [Chapitre 7 : Référence RPC](7-rpc-reference.md) pour les détails d'intégration.

**Pour exécuter un nœud** : Consultez le [Chapitre 6 : Paramètres réseau](6-network-parameters.md) pour les options de configuration.

---

[📘 Table des matières](index.md) | [Suivant : Format Plot →](2-plot-format.md)
