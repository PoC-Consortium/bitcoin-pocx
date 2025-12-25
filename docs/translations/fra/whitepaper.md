# Bitcoin-PoCX : Consensus écoénergétique pour Bitcoin Core

**Version** : 2.0 Brouillon
**Date** : Décembre 2025
**Organisation** : Proof of Capacity Consortium

---

## Résumé

Le consensus par preuve de travail (PoW) de Bitcoin offre une sécurité robuste mais consomme une énergie substantielle en raison du calcul continu de hachages en temps réel. Nous présentons Bitcoin-PoCX, un fork de Bitcoin qui remplace le PoW par la preuve de capacité (PoC), où les mineurs pré-calculent et stockent de grands ensembles de hachages sur disque lors du plotting, puis minent en effectuant des consultations légères au lieu du hachage continu. En déplaçant le calcul de la phase de minage vers une phase de plotting unique, Bitcoin-PoCX réduit drastiquement la consommation d'énergie tout en permettant le minage sur du matériel standard, abaissant la barrière à l'entrée et atténuant les pressions de centralisation inhérentes au PoW dominé par les ASICs, le tout en préservant les hypothèses de sécurité et le comportement économique de Bitcoin.

Notre implémentation introduit plusieurs innovations clés :
(1) Un format de plot renforcé qui élimine toutes les attaques par compromis temps-mémoire connues dans les systèmes PoC existants, garantissant que la puissance de minage effective reste strictement proportionnelle à la capacité de stockage engagée ;
(2) L'algorithme Time Bending, qui transforme les distributions de deadline de l'exponentielle vers le chi-carré, réduisant la variance du temps de bloc sans modifier la moyenne ;
(3) Un mécanisme d'assignation de forge basé sur OP_RETURN permettant le minage en pool non-custodial ; et
(4) Une mise à l'échelle dynamique de la compression, qui augmente la difficulté de génération de plot en alignement avec les calendriers de halving pour maintenir les marges de sécurité à long terme à mesure que le matériel s'améliore.

Bitcoin-PoCX maintient l'architecture de Bitcoin Core grâce à des modifications minimales et conditionnées, isolant la logique PoC du code de consensus existant. Le système préserve la politique monétaire de Bitcoin en ciblant un intervalle de bloc de 120 secondes et en ajustant la subvention de bloc à 10 BTC. La subvention réduite compense l'augmentation quintuple de la fréquence des blocs, maintenant le taux d'émission à long terme aligné avec le calendrier original de Bitcoin et conservant l'offre maximale de ~21 millions.

---

## 1. Introduction

### 1.1 Motivation

Le consensus par preuve de travail (PoW) de Bitcoin s'est avéré sécurisé pendant plus d'une décennie, mais à un coût significatif : les mineurs doivent continuellement dépenser des ressources computationnelles, entraînant une consommation d'énergie élevée. Au-delà des préoccupations d'efficacité, il existe une motivation plus large : explorer des mécanismes de consensus alternatifs qui maintiennent la sécurité tout en abaissant la barrière à la participation. Le PoC permet à pratiquement quiconque possédant du matériel de stockage standard de miner efficacement, réduisant les pressions de centralisation observées dans le minage PoW dominé par les ASICs.

La preuve de capacité (PoC) y parvient en dérivant la puissance de minage de l'engagement de stockage plutôt que du calcul continu. Les mineurs pré-calculent de grands ensembles de hachages stockés sur disque — les plots — lors d'une phase de plotting unique. Le minage consiste ensuite en des consultations légères, réduisant drastiquement la consommation d'énergie tout en préservant les hypothèses de sécurité du consensus basé sur les ressources.

### 1.2 Intégration avec Bitcoin Core

Bitcoin-PoCX intègre le consensus PoC dans Bitcoin Core plutôt que de créer une nouvelle blockchain. Cette approche exploite la sécurité éprouvée de Bitcoin Core, sa pile réseau mature et son outillage largement adopté, tout en maintenant des modifications minimales et conditionnées. La logique PoC est isolée du code de consensus existant, garantissant que les fonctionnalités principales — validation des blocs, opérations de portefeuille, formats de transaction — restent largement inchangées.

### 1.3 Objectifs de conception

**Sécurité** : Maintenir une robustesse équivalente à Bitcoin ; les attaques nécessitent une capacité de stockage majoritaire.

**Efficacité** : Réduire la charge computationnelle continue aux niveaux d'E/S disque.

**Accessibilité** : Permettre le minage avec du matériel standard, abaissant les barrières à l'entrée.

**Intégration minimale** : Introduire le consensus PoC avec une empreinte de modification minimale.

---

## 2. Contexte : Preuve de capacité

### 2.1 Historique

La preuve de capacité (PoC) a été introduite par Burstcoin en 2014 comme une alternative écoénergétique à la preuve de travail (PoW). Burstcoin a démontré que la puissance de minage pouvait être dérivée du stockage engagé plutôt que du hachage continu en temps réel : les mineurs pré-calculaient de grands jeux de données (« plots ») une seule fois puis minaient en lisant de petites portions fixes de ceux-ci.

Les premières implémentations PoC ont prouvé la viabilité du concept mais ont également révélé que le format de plot et la structure cryptographique sont critiques pour la sécurité. Plusieurs compromis temps-mémoire permettaient aux attaquants de miner efficacement avec moins de stockage que les participants honnêtes. Cela a mis en évidence que la sécurité PoC dépend de la conception du plot — pas simplement de l'utilisation du stockage comme ressource.

L'héritage de Burstcoin a établi le PoC comme un mécanisme de consensus pratique et a fourni la base sur laquelle PoCX s'appuie.

### 2.2 Concepts fondamentaux

Le minage PoC est basé sur de grands fichiers plot pré-calculés stockés sur disque. Ces plots contiennent du « calcul gelé » : le hachage coûteux est effectué une seule fois lors du plotting, et le minage consiste ensuite en des lectures de disque légères et une vérification simple. Les éléments fondamentaux comprennent :

**Nonce :**
L'unité de base des données de plot. Chaque nonce contient 4096 scoops (256 Kio au total) générés via Shabal256 à partir de l'adresse du mineur et de l'index du nonce.

**Scoop :**
Un segment de 64 octets à l'intérieur d'un nonce. Pour chaque bloc, le réseau sélectionne de manière déterministe un index de scoop (0-4095) basé sur la signature de génération du bloc précédent. Seul ce scoop par nonce doit être lu.

**Signature de génération :**
Une valeur de 256 bits dérivée du bloc précédent. Elle fournit l'entropie pour la sélection du scoop et empêche les mineurs d'anticiper les futurs indices de scoop.

**Warp :**
Un groupe structurel de 4096 nonces (1 Gio). Les warps sont l'unité pertinente pour les formats de plot résistants à la compression.

### 2.3 Processus de minage et pipeline de qualité

Le minage PoC consiste en une étape de plotting unique et une routine légère par bloc :

**Configuration unique :**
- Génération de plot : Calculer les nonces via Shabal256 et les écrire sur disque.

**Minage par bloc :**
- Sélection du scoop : Déterminer l'index du scoop à partir de la signature de génération.
- Scan du plot : Lire ce scoop de tous les nonces dans les plots du mineur.

**Pipeline de qualité :**
- Qualité brute : Hacher chaque scoop avec la signature de génération en utilisant Shabal256Lite pour obtenir une valeur de qualité de 64 bits (plus bas est meilleur).
- Deadline : Convertir la qualité en deadline en utilisant la cible de base (un paramètre ajusté à la difficulté assurant que le réseau atteint son intervalle de bloc cible) : `deadline = quality / base_target`
- Deadline bendée : Appliquer la transformation Time Bending pour réduire la variance tout en préservant le temps de bloc attendu.

**Forge de bloc :**
Le mineur avec la deadline (bendée) la plus courte forge le prochain bloc une fois que ce temps est écoulé.

Contrairement au PoW, presque tout le calcul se fait pendant le plotting ; le minage actif est principalement limité par les E/S disque et consomme très peu d'énergie.

### 2.4 Vulnérabilités connues des systèmes antérieurs

**Défaut de distribution POC1 :**
Le format POC1 original de Burstcoin présentait un biais structurel : les scoops à index bas étaient significativement moins coûteux à recalculer à la volée que les scoops à index élevés. Cela introduisait un compromis temps-mémoire non uniforme, permettant aux attaquants de réduire le stockage requis pour ces scoops et brisant l'hypothèse que toutes les données pré-calculées étaient également coûteuses.

**Attaque par compression XOR (POC2) :**
Dans POC2, un attaquant peut prendre n'importe quel ensemble de 8192 nonces et les partitionner en deux blocs de 4096 nonces (A et B). Au lieu de stocker les deux blocs, l'attaquant stocke uniquement une structure dérivée : `A ⊕ transpose(B)`, où la transposition échange les indices de scoop et de nonce — le scoop S du nonce N dans le bloc B devient le scoop N du nonce S.

Pendant le minage, quand le scoop S du nonce N est nécessaire, l'attaquant le reconstruit en :
1. Lisant la valeur XOR stockée à la position (S, N)
2. Calculant le nonce N du bloc A pour obtenir le scoop S
3. Calculant le nonce S du bloc B pour obtenir le scoop transposé N
4. XORant les trois valeurs pour récupérer le scoop original de 64 octets

Cela réduit le stockage de 50 %, tout en ne nécessitant que deux calculs de nonce par consultation — un coût bien en dessous du seuil nécessaire pour appliquer le pré-calcul complet. L'attaque est viable car calculer une ligne (un nonce, 4096 scoops) est peu coûteux, alors que calculer une colonne (un seul scoop à travers 4096 nonces) nécessiterait de régénérer tous les nonces. La structure de transposition expose ce déséquilibre.

Cela a démontré le besoin d'un format de plot qui empêche une telle recombinaison structurée et supprime le compromis temps-mémoire sous-jacent. La section 3.3 décrit comment PoCX adresse et résout cette faiblesse.

### 2.5 Transition vers PoCX

Les limitations des systèmes PoC antérieurs ont clairement montré qu'un minage de stockage sécurisé, équitable et décentralisé dépend de structures de plot soigneusement conçues. Bitcoin-PoCX adresse ces problèmes avec un format de plot renforcé, une distribution de deadline améliorée et des mécanismes pour le minage en pool décentralisé — décrits dans la section suivante.

---

## 3. Format de plot PoCX

### 3.1 Construction du nonce de base

Un nonce est une structure de données de 256 Kio dérivée de manière déterministe à partir de trois paramètres : un payload d'adresse de 20 octets, un seed de 32 octets et un index de nonce de 64 bits.

La construction commence par combiner ces entrées et les hacher avec Shabal256 pour produire un hachage initial. Ce hachage sert de point de départ pour un processus d'expansion itératif : Shabal256 est appliqué de manière répétée, chaque étape dépendant des données générées précédemment, jusqu'à ce que le tampon entier de 256 Kio soit rempli. Ce processus chaîné représente le travail computationnel effectué pendant le plotting.

Une étape de diffusion finale hache le tampon complété et XOR le résultat à travers tous les octets. Cela garantit que le tampon complet a été calculé et que les mineurs ne peuvent pas court-circuiter le calcul. Le shuffle POC2 est ensuite appliqué, échangeant les moitiés inférieure et supérieure de chaque scoop pour garantir que tous les scoops nécessitent un effort computationnel équivalent.

Le nonce final consiste en 4096 scoops de 64 octets chacun et forme l'unité fondamentale utilisée dans le minage.

### 3.2 Disposition de plot alignée SIMD

Pour maximiser le débit sur le matériel moderne, PoCX organise les données de nonce sur disque pour faciliter le traitement vectorisé. Au lieu de stocker chaque nonce séquentiellement, PoCX aligne les mots de 4 octets correspondants à travers plusieurs nonces consécutifs de manière contiguë. Cela permet à une seule récupération mémoire de fournir des données pour toutes les voies SIMD, minimisant les défauts de cache et éliminant la surcharge de scatter-gather.

```
Disposition traditionnelle :
Nonce0 : [M0][M1][M2][M3]...
Nonce1 : [M0][M1][M2][M3]...
Nonce2 : [M0][M1][M2][M3]...

Disposition SIMD PoCX :
Mot0 : [N0][N1][N2]...[N15]
Mot1 : [N0][N1][N2]...[N15]
Mot2 : [N0][N1][N2]...[N15]
```

Cette disposition bénéficie aux mineurs CPU et GPU, permettant une évaluation de scoop parallélisée à haut débit tout en conservant un motif d'accès scalaire simple pour la vérification de consensus. Elle garantit que le minage est limité par la bande passante de stockage plutôt que par le calcul CPU, maintenant la nature basse consommation de la preuve de capacité.

### 3.3 Structure de warp et encodage XOR-Transpose

Un warp est l'unité de stockage fondamentale dans PoCX, consistant en 4096 nonces (1 Gio). Le format non compressé, appelé X0, contient les nonces de base exactement tels que produits par la construction de la section 3.1.

**Encodage XOR-Transpose (X1)**

Pour supprimer les compromis temps-mémoire structurels présents dans les systèmes PoC antérieurs, PoCX dérive un format de minage renforcé, X1, en appliquant un encodage XOR-transpose à des paires de warps X0.

Pour construire le scoop S du nonce N dans un warp X1 :

1. Prendre le scoop S du nonce N du premier warp X0 (position directe)
2. Prendre le scoop N du nonce S du second warp X0 (position transposée)
3. XOR les deux valeurs de 64 octets pour obtenir le scoop X1

L'étape de transposition échange les indices de scoop et de nonce. En termes matriciels — où les lignes représentent les scoops et les colonnes représentent les nonces — elle combine l'élément à la position (S, N) dans le premier warp avec l'élément à (N, S) dans le second.

**Pourquoi cela élimine la surface d'attaque par compression**

Le XOR-transpose verrouille chaque scoop avec une ligne entière et une colonne entière des données X0 sous-jacentes. Récupérer un seul scoop X1 nécessite donc l'accès à des données couvrant les 4096 indices de scoop. Toute tentative de calcul des données manquantes nécessiterait de régénérer 4096 nonces complets, plutôt qu'un seul nonce — supprimant la structure de coût asymétrique exploitée par l'attaque XOR pour POC2 (Section 2.4).

En conséquence, stocker le warp X1 complet devient la seule stratégie computationnellement viable pour les mineurs, fermant le compromis temps-mémoire exploité dans les conceptions antérieures.

### 3.4 Disposition sur disque

Les fichiers plot PoCX consistent en de nombreux warps X1 consécutifs. Pour maximiser l'efficacité opérationnelle pendant le minage, les données à l'intérieur de chaque fichier sont organisées par scoop : toutes les données du scoop 0 de chaque warp sont stockées séquentiellement, suivies de toutes les données du scoop 1, et ainsi de suite, jusqu'au scoop 4095.

Cet **ordonnancement séquentiel par scoop** permet aux mineurs de lire les données complètes requises pour un scoop sélectionné en un seul accès disque séquentiel, minimisant les temps de recherche et maximisant le débit sur les dispositifs de stockage standard.

Combinée avec l'encodage XOR-transpose de la section 3.3, cette disposition garantit que le fichier est à la fois **structurellement renforcé** et **opérationnellement efficace** : l'ordonnancement séquentiel par scoop supporte des E/S disque optimales, tandis que les dispositions mémoire alignées SIMD (voir Section 3.2) permettent une évaluation de scoop parallélisée à haut débit.

### 3.5 Mise à l'échelle de la preuve de travail (Xn)

PoCX implémente un pré-calcul évolutif via le concept de niveaux de mise à l'échelle, notés Xn, pour s'adapter à l'évolution des performances matérielles. Le format X1 de base représente la première structure de warp renforcée par XOR-transpose.

Chaque niveau de mise à l'échelle Xn augmente la preuve de travail intégrée dans chaque warp de manière exponentielle par rapport à X1 : le travail requis au niveau Xn est 2^(n-1) fois celui de X1. La transition de Xn à Xn+1 est opérationnellement équivalente à l'application d'un XOR à travers des paires de warps adjacents, intégrant progressivement plus de preuve de travail sans changer la taille de plot sous-jacente.

Les fichiers plot existants créés à des niveaux de mise à l'échelle inférieurs peuvent toujours être utilisés pour le minage, mais ils contribuent proportionnellement moins de travail à la génération de blocs, reflétant leur preuve de travail intégrée plus faible. Ce mécanisme garantit que les plots PoCX restent sécurisés, flexibles et économiquement équilibrés au fil du temps.

### 3.6 Fonctionnalité seed

Le paramètre seed permet plusieurs plots non chevauchants par adresse sans coordination manuelle.

**Problème (POC2)** : Les mineurs devaient suivre manuellement les plages de nonce à travers les fichiers plot pour éviter les chevauchements. Les nonces chevauchants gaspillent du stockage sans augmenter la puissance de minage.

**Solution** : Chaque paire `(adresse, seed)` définit un espace de clés indépendant. Les plots avec différents seeds ne se chevauchent jamais, quelles que soient les plages de nonce. Les mineurs peuvent créer des plots librement sans coordination.

---

## 4. Consensus de preuve de capacité

PoCX étend le consensus de Nakamoto de Bitcoin avec un mécanisme de preuve lié au stockage. Au lieu de dépenser de l'énergie en hachage répété, les mineurs engagent de grandes quantités de données pré-calculées — les plots — sur disque. Pendant la génération de bloc, ils doivent localiser une petite portion imprévisible de ces données et la transformer en preuve. Le mineur qui fournit la meilleure preuve dans la fenêtre de temps attendue gagne le droit de forger le prochain bloc.

Ce chapitre décrit comment PoCX structure les métadonnées de bloc, dérive l'imprévisibilité et transforme le stockage statique en un mécanisme de consensus sécurisé et à faible variance.

### 4.1 Structure de bloc

PoCX conserve l'en-tête de bloc familier de style Bitcoin mais introduit des champs de consensus supplémentaires requis pour le minage basé sur la capacité. Ces champs lient collectivement le bloc au plot stocké du mineur, à la difficulté du réseau et à l'entropie cryptographique qui définit chaque défi de minage.

À un haut niveau, un bloc PoCX contient : la hauteur de bloc, enregistrée explicitement pour simplifier la validation contextuelle ; la signature de génération, une source d'entropie fraîche liant chaque bloc à son prédécesseur ; la cible de base, représentant la difficulté réseau sous forme inverse (des valeurs plus élevées correspondent à un minage plus facile) ; la preuve PoCX, identifiant le plot du mineur, le niveau de compression utilisé pendant le plotting, le nonce sélectionné et la qualité qui en dérive ; et une clé de signature et une signature, prouvant le contrôle de la capacité utilisée pour forger le bloc (ou d'une clé de forge assignée).

La preuve intègre toutes les informations pertinentes au consensus nécessaires aux validateurs pour recalculer le défi, vérifier le scoop choisi et confirmer la qualité résultante. En étendant plutôt qu'en redessinant la structure de bloc, PoCX reste conceptuellement aligné avec Bitcoin tout en permettant une source fondamentalement différente de travail de minage.

### 4.2 Chaîne de signatures de génération

La signature de génération fournit l'imprévisibilité requise pour un minage de preuve de capacité sécurisé. Chaque bloc dérive sa signature de génération de la signature et du signataire du bloc précédent, garantissant que les mineurs ne peuvent pas anticiper les défis futurs ou pré-calculer des régions de plot avantageuses :

`generationSignature[n] = SHA256(generationSignature[n-1] || miner_pubkey[n-1])`

Cela produit une séquence de valeurs d'entropie cryptographiquement fortes et dépendantes du mineur. Parce que la clé publique d'un mineur est inconnue jusqu'à la publication du bloc précédent, aucun participant ne peut prédire les futures sélections de scoop. Cela empêche le pré-calcul sélectif ou le plotting stratégique et garantit que chaque bloc introduit un travail de minage véritablement nouveau.

### 4.3 Processus de forge

Le minage dans PoCX consiste à transformer des données stockées en preuve entièrement pilotée par la signature de génération. Bien que le processus soit déterministe, l'imprévisibilité de la signature garantit que les mineurs ne peuvent pas se préparer à l'avance et doivent accéder de manière répétée à leurs plots stockés.

**Dérivation du défi (sélection du scoop) :** Le mineur hache la signature de génération actuelle avec la hauteur de bloc pour obtenir un index de scoop dans la plage 0-4095. Cet index détermine quel segment de 64 octets de chaque nonce stocké participe à la preuve. Parce que la signature de génération dépend du signataire du bloc précédent, la sélection du scoop ne devient connue qu'au moment de la publication du bloc.

**Évaluation de la preuve (calcul de qualité) :** Pour chaque nonce dans un plot, le mineur récupère le scoop sélectionné et le hache avec la signature de génération pour obtenir une qualité — une valeur de 64 bits dont la magnitude détermine la compétitivité du mineur. Une qualité plus basse correspond à une meilleure preuve.

**Formation de la deadline (Time Bending) :** La deadline brute est proportionnelle à la qualité et inversement proportionnelle à la cible de base. Dans les conceptions PoC héritées, ces deadlines suivaient une distribution exponentielle très asymétrique, produisant de longs retards en queue qui n'apportaient aucune sécurité supplémentaire. PoCX transforme la deadline brute en utilisant le Time Bending (Section 4.4), réduisant la variance et assurant des intervalles de bloc prévisibles. Une fois que la deadline bendée est écoulée, le mineur forge un bloc en intégrant la preuve et en le signant avec la clé de forge effective.

### 4.4 Time Bending

La preuve de capacité produit des deadlines distribuées exponentiellement. Après une courte période — typiquement quelques dizaines de secondes — chaque mineur a déjà identifié sa meilleure preuve, et tout temps d'attente supplémentaire ne contribue qu'à la latence, pas à la sécurité.

Le Time Bending remodèle la distribution en appliquant une transformation par racine cubique :

`deadline_bendée = échelle × (quality / base_target)^(1/3)`

Le facteur d'échelle préserve le temps de bloc attendu (120 secondes) tout en réduisant dramatiquement la variance. Les deadlines courtes sont étendues, améliorant la propagation des blocs et la sécurité du réseau. Les deadlines longues sont compressées, empêchant les valeurs aberrantes de retarder la chaîne.

![Distributions des temps de bloc](blocktime_distributions.svg)

Le Time Bending maintient le contenu informationnel de la preuve sous-jacente. Il ne modifie pas la compétitivité entre les mineurs ; il réalloue seulement le temps d'attente pour produire des intervalles de bloc plus lisses et plus prévisibles. L'implémentation utilise l'arithmétique en virgule fixe (format Q42) et des entiers de 256 bits pour assurer des résultats déterministes sur toutes les plateformes.

### 4.5 Ajustement de difficulté

PoCX régule la production de blocs en utilisant la cible de base, une mesure de difficulté inverse. Le temps de bloc attendu est proportionnel au ratio `quality / base_target`, donc augmenter la cible de base accélère la création de blocs tandis que la diminuer ralentit la chaîne.

La difficulté s'ajuste à chaque bloc en utilisant le temps mesuré entre les blocs récents par rapport à l'intervalle cible. Cet ajustement fréquent est nécessaire car la capacité de stockage peut être ajoutée ou retirée rapidement — contrairement à la puissance de hachage de Bitcoin, qui change plus lentement.

L'ajustement suit deux contraintes directrices : **Progressivité** — les changements par bloc sont limités (maximum ±20 %) pour éviter les oscillations ou la manipulation ; **Renforcement** — la cible de base ne peut pas dépasser sa valeur genesis, empêchant le réseau de jamais abaisser la difficulté en dessous des hypothèses de sécurité originales.

### 4.6 Validité des blocs

Un bloc dans PoCX est valide quand il présente une preuve vérifiable dérivée du stockage cohérente avec l'état du consensus. Les validateurs recalculent indépendamment la sélection du scoop, dérivent la qualité attendue du nonce soumis et des métadonnées du plot, appliquent la transformation Time Bending et confirment que le mineur était éligible pour forger le bloc au moment déclaré.

Spécifiquement, un bloc valide requiert : la deadline a expiré depuis le bloc parent ; la qualité soumise correspond à la qualité calculée pour la preuve ; le niveau de mise à l'échelle atteint le minimum réseau ; la signature de génération correspond à la valeur attendue ; la cible de base correspond à la valeur attendue ; la signature de bloc provient du signataire effectif ; et le coinbase paie à l'adresse du signataire effectif.

---

## 5. Assignations de forge

### 5.1 Motivation

Les assignations de forge permettent aux propriétaires de plots de déléguer l'autorité de forge de blocs sans jamais céder la propriété de leurs plots. Ce mécanisme permet le minage en pool et les configurations de stockage à froid tout en préservant les garanties de sécurité de PoCX.

Dans le minage en pool, les propriétaires de plots peuvent autoriser un pool à forger des blocs en leur nom. Le pool assemble les blocs et distribue les récompenses, mais il n'obtient jamais la garde des plots eux-mêmes. La délégation est réversible à tout moment, et les propriétaires de plots restent libres de quitter un pool ou de changer de configuration sans refaire le plotting.

Les assignations supportent également une séparation nette entre clés froides et chaudes. La clé privée contrôlant le plot peut rester hors ligne, tandis qu'une clé de forge séparée — stockée sur une machine en ligne — produit les blocs. Une compromission de la clé de forge ne compromet donc que l'autorité de forge, pas la propriété. Le plot reste en sécurité et l'assignation peut être révoquée, fermant immédiatement la brèche de sécurité.

Les assignations de forge fournissent ainsi une flexibilité opérationnelle tout en maintenant le principe que le contrôle sur la capacité stockée ne doit jamais être transféré à des intermédiaires.

### 5.2 Protocole d'assignation

Les assignations sont déclarées via des transactions OP_RETURN pour éviter la croissance inutile de l'ensemble UTXO. Une transaction d'assignation spécifie l'adresse de plot et l'adresse de forge qui est autorisée à produire des blocs en utilisant la capacité de ce plot. Une transaction de révocation contient uniquement l'adresse de plot. Dans les deux cas, le propriétaire du plot prouve le contrôle en signant l'entrée dépensée de la transaction.

Chaque assignation progresse à travers une séquence d'états bien définis (UNASSIGNED, ASSIGNING, ASSIGNED, REVOKING, REVOKED). Après qu'une transaction d'assignation soit confirmée, le système entre dans une courte phase d'activation. Ce délai — 30 blocs, environ une heure — assure la stabilité pendant les courses de blocs et empêche le changement rapide adversaire des identités de forge. Une fois cette période d'activation expirée, l'assignation devient active et le reste jusqu'à ce que le propriétaire du plot émette une révocation.

Les révocations passent à une période de délai plus longue de 720 blocs, environ un jour. Pendant ce temps, l'adresse de forge précédente reste active. Ce délai plus long fournit une stabilité opérationnelle pour les pools, empêchant le « saut d'assignation » stratégique et donnant aux fournisseurs d'infrastructure suffisamment de certitude pour opérer efficacement. Après l'expiration du délai de révocation, la révocation se termine et le propriétaire du plot est libre de désigner une nouvelle clé de forge.

L'état d'assignation est maintenu dans une structure de couche consensus parallèle à l'ensemble UTXO et supporte les données d'annulation pour une gestion sûre des réorganisations de chaîne.

### 5.3 Règles de validation

Pour chaque bloc, les validateurs déterminent le signataire effectif — l'adresse qui doit signer le bloc et recevoir la récompense coinbase. Ce signataire dépend uniquement de l'état d'assignation à la hauteur du bloc.

Si aucune assignation n'existe ou si l'assignation n'a pas encore terminé sa phase d'activation, le propriétaire du plot reste le signataire effectif. Une fois qu'une assignation devient active, l'adresse de forge assignée doit signer. Pendant la révocation, l'adresse de forge continue de signer jusqu'à l'expiration du délai de révocation. Ce n'est qu'à ce moment que l'autorité retourne au propriétaire du plot.

Les validateurs appliquent que la signature de bloc est produite par le signataire effectif, que le coinbase paie à la même adresse et que toutes les transitions suivent les délais d'activation et de révocation prescrits. Seul le propriétaire du plot peut créer ou révoquer des assignations ; les clés de forge ne peuvent pas modifier ou étendre leurs propres permissions.

Les assignations de forge introduisent donc une délégation flexible sans introduire de confiance. La propriété de la capacité sous-jacente reste toujours cryptographiquement ancrée au propriétaire du plot, tandis que l'autorité de forge peut être déléguée, alternée ou révoquée selon les besoins opérationnels.

---

## 6. Mise à l'échelle dynamique

À mesure que le matériel évolue, le coût du calcul des plots diminue par rapport à la lecture du travail pré-calculé depuis le disque. Sans contre-mesures, les attaquants pourraient éventuellement générer des preuves à la volée plus rapidement que les mineurs lisant le travail stocké, compromettant le modèle de sécurité de la preuve de capacité.

Pour préserver la marge de sécurité prévue, PoCX implémente un calendrier de mise à l'échelle : le niveau de mise à l'échelle minimum requis pour les plots augmente au fil du temps. Chaque niveau de mise à l'échelle Xn, tel que décrit dans la section 3.5, intègre exponentiellement plus de preuve de travail dans la structure du plot, garantissant que les mineurs continuent d'engager des ressources de stockage substantielles même si le calcul devient moins cher.

Le calendrier s'aligne avec les incitations économiques du réseau, particulièrement les halvings des récompenses de bloc. À mesure que la récompense par bloc diminue, le niveau minimum augmente graduellement, préservant l'équilibre entre l'effort de plotting et le potentiel de minage :

| Période | Années | Halvings | Mise à l'échelle min | Multiplicateur de travail de plot |
|---------|--------|----------|----------------------|-----------------------------------|
| Époque 0 | 0-4 | 0 | X1 | 2× ligne de base |
| Époque 1 | 4-12 | 1-2 | X2 | 4× ligne de base |
| Époque 2 | 12-28 | 3-6 | X3 | 8× ligne de base |
| Époque 3 | 28-60 | 7-14 | X4 | 16× ligne de base |
| Époque 4 | 60-124 | 15-30 | X5 | 32× ligne de base |
| Époque 5 | 124+ | 31+ | X6 | 64× ligne de base |

Les mineurs peuvent optionnellement préparer des plots dépassant le minimum actuel d'un niveau, leur permettant de planifier à l'avance et d'éviter les mises à niveau immédiates quand le réseau passe à l'époque suivante. Cette étape optionnelle ne confère aucun avantage supplémentaire en termes de probabilité de bloc — elle permet simplement une transition opérationnelle plus douce.

Les blocs contenant des preuves en dessous du niveau de mise à l'échelle minimum pour leur hauteur sont considérés invalides. Les validateurs vérifient le niveau de mise à l'échelle déclaré dans la preuve par rapport à l'exigence réseau actuelle lors de la validation de consensus, garantissant que tous les mineurs participants respectent les attentes de sécurité évolutives.

---

## 7. Architecture de minage

PoCX sépare les opérations critiques pour le consensus des tâches intensives en ressources du minage, permettant à la fois sécurité et efficacité. Le nœud maintient la blockchain, valide les blocs, gère le mempool et expose une interface RPC. Les mineurs externes gèrent le stockage des plots, la lecture des scoops, le calcul de qualité et la gestion des deadlines. Cette séparation garde la logique de consensus simple et auditable tout en permettant aux mineurs d'optimiser pour le débit disque.

### 7.1 Interface RPC de minage

Les mineurs interagissent avec le nœud via un ensemble minimal d'appels RPC. Le RPC get_mining_info fournit la hauteur de bloc actuelle, la signature de génération, la cible de base, la deadline cible et la plage acceptable de niveaux de mise à l'échelle de plot. En utilisant ces informations, les mineurs calculent les nonces candidats. Le RPC submit_nonce permet aux mineurs de soumettre une solution proposée, incluant l'identifiant de plot, l'index de nonce, le niveau de mise à l'échelle et le compte du mineur. Le nœud évalue la soumission et répond avec la deadline calculée si la preuve est valide.

### 7.2 Planificateur de forge

Le nœud maintient un planificateur de forge, qui suit les soumissions entrantes et ne conserve que la meilleure solution pour chaque hauteur de bloc. Les nonces soumis sont mis en file d'attente avec des protections intégrées contre les inondations de soumissions ou les attaques par déni de service. Le planificateur attend jusqu'à ce que la deadline calculée expire ou qu'une solution supérieure arrive, moment auquel il assemble un bloc, le signe en utilisant la clé de forge effective et le publie sur le réseau.

### 7.3 Forge défensive

Pour empêcher les attaques de timing ou les incitations à la manipulation d'horloge, PoCX implémente la forge défensive. Si un bloc concurrent arrive pour la même hauteur, le planificateur compare la solution locale avec le nouveau bloc. Si la qualité locale est supérieure, le nœud forge immédiatement plutôt que d'attendre la deadline originale. Cela garantit que les mineurs ne peuvent pas obtenir d'avantage simplement en ajustant leurs horloges locales ; la meilleure solution prévaut toujours, préservant l'équité et la sécurité du réseau.

---

## 8. Analyse de sécurité

### 8.1 Modèle de menace

PoCX modélise des adversaires avec des capacités substantielles mais limitées. Les attaquants peuvent tenter de surcharger le réseau avec des transactions invalides, des blocs malformés ou des preuves fabriquées pour stresser les chemins de validation. Ils peuvent librement manipuler leurs horloges locales et peuvent essayer d'exploiter des cas limites dans le comportement du consensus tels que la gestion des horodatages, la dynamique d'ajustement de difficulté ou les règles de réorganisation. Les adversaires sont également attendus pour sonder les opportunités de réécrire l'historique via des forks de chaîne ciblés.

Le modèle suppose qu'aucune partie unique ne contrôle une majorité de la capacité de stockage totale du réseau. Comme avec tout mécanisme de consensus basé sur les ressources, un attaquant à 51 % de capacité peut unilatéralement réorganiser la chaîne ; cette limitation fondamentale n'est pas spécifique à PoCX. PoCX suppose également que les attaquants ne peuvent pas calculer les données de plot plus rapidement que les mineurs honnêtes peuvent les lire depuis le disque. Le calendrier de mise à l'échelle (Section 6) garantit que l'écart computationnel requis pour la sécurité croît au fil du temps à mesure que le matériel s'améliore.

Les sections suivantes examinent chaque classe d'attaque majeure en détail et décrivent les contre-mesures intégrées dans PoCX.

### 8.2 Attaques de capacité

Comme le PoW, un attaquant avec une capacité majoritaire peut réécrire l'historique (une attaque à 51 %). Réaliser cela nécessite d'acquérir une empreinte de stockage physique plus grande que le réseau honnête — une entreprise coûteuse et logistiquement exigeante. Une fois le matériel obtenu, les coûts d'exploitation sont bas, mais l'investissement initial crée une forte incitation économique à se comporter honnêtement : compromettre la chaîne endommagerait la valeur de la propre base d'actifs de l'attaquant.

Le PoC évite également le problème du « nothing-at-stake » associé au PoS. Bien que les mineurs puissent scanner les plots contre plusieurs forks concurrents, chaque scan consomme du temps réel — typiquement de l'ordre de dizaines de secondes par chaîne. Avec un intervalle de bloc de 120 secondes, cela limite intrinsèquement le minage multi-fork, et tenter de miner de nombreux forks simultanément dégrade les performances sur tous. Le minage de forks n'est donc pas gratuit ; il est fondamentalement contraint par le débit d'E/S.

Même si le matériel futur permettait un scan de plot quasi-instantané (par ex., SSDs haute vitesse), un attaquant ferait toujours face à une exigence substantielle de ressources physiques pour contrôler une majorité de la capacité réseau, rendant une attaque de type 51 % coûteuse et logistiquement difficile.

Enfin, les attaques de capacité sont bien plus difficiles à louer que les attaques de puissance de hachage. La puissance de calcul GPU peut être acquise à la demande et redirigée vers n'importe quelle chaîne PoW instantanément. En revanche, le PoC nécessite du matériel physique, un plotting intensif en temps et des opérations d'E/S continues. Ces contraintes rendent les attaques opportunistes à court terme bien moins faisables.

### 8.3 Attaques de timing

Le timing joue un rôle plus critique dans la preuve de capacité que dans la preuve de travail. Dans le PoW, les horodatages influencent principalement l'ajustement de difficulté ; dans le PoC, ils déterminent si la deadline d'un mineur a expiré et donc si un bloc est éligible pour la forge. Les deadlines sont mesurées par rapport à l'horodatage du bloc parent, mais l'horloge locale d'un nœud est utilisée pour juger si un bloc entrant est trop loin dans le futur. Pour cette raison, PoCX applique une tolérance d'horodatage stricte : les blocs ne peuvent pas dévier de plus de 15 secondes de l'horloge locale du nœud (comparé à la fenêtre de 2 heures de Bitcoin). Cette limite fonctionne dans les deux directions — les blocs trop loin dans le futur sont rejetés, et les nœuds avec des horloges lentes peuvent rejeter incorrectement des blocs entrants valides.

Les nœuds devraient donc synchroniser leurs horloges en utilisant NTP ou une source de temps équivalente. PoCX évite délibérément de s'appuyer sur des sources de temps internes au réseau pour empêcher les attaquants de manipuler le temps réseau perçu. Les nœuds surveillent leur propre dérive et émettent des avertissements si l'horloge locale commence à diverger des horodatages de blocs récents.

L'accélération d'horloge — faire tourner une horloge locale rapide pour forger légèrement plus tôt — ne fournit qu'un bénéfice marginal. Dans la tolérance autorisée, la forge défensive (Section 7.3) garantit qu'un mineur avec une meilleure solution publiera immédiatement en voyant un bloc précoce inférieur. Une horloge rapide n'aide un mineur qu'à publier une solution déjà gagnante quelques secondes plus tôt ; elle ne peut pas convertir une preuve inférieure en une gagnante.

Les tentatives de manipulation de la difficulté via les horodatages sont limitées par un plafond d'ajustement par bloc de ±20 % et une fenêtre glissante de 24 blocs, empêchant les mineurs d'influencer significativement la difficulté par des jeux de timing à court terme.

### 8.4 Attaques par compromis temps-mémoire

Les compromis temps-mémoire tentent de réduire les exigences de stockage en recalculant des parties du plot à la demande. Les systèmes de preuve de capacité antérieurs étaient vulnérables à de telles attaques, notamment le défaut de déséquilibre de scoop POC1 et l'attaque par compression XOR-transpose POC2 (Section 2.4). Les deux exploitaient des asymétries dans la coût de régénération de certaines portions des données de plot, permettant aux adversaires de réduire le stockage tout en ne payant qu'une petite pénalité computationnelle. De plus, les formats de plot alternatifs à POC2 souffrent de faiblesses TMTO similaires ; un exemple proéminent est Chia, dont le format de plot peut être arbitrairement réduit d'un facteur supérieur à 4.

PoCX supprime entièrement ces surfaces d'attaque par sa construction de nonce et son format de warp. À l'intérieur de chaque nonce, l'étape de diffusion finale hache le tampon entièrement calculé et XOR le résultat à travers tous les octets, garantissant que chaque partie du tampon dépend de toutes les autres parties et ne peut pas être court-circuitée. Ensuite, le shuffle POC2 échange les moitiés inférieure et supérieure de chaque scoop, égalisant le coût computationnel de récupération de n'importe quel scoop.

PoCX élimine davantage l'attaque par compression XOR-transpose POC2 en dérivant son format X1 renforcé, où chaque scoop est le XOR d'une position directe et transposée à travers des warps appariés ; cela verrouille chaque scoop avec une ligne entière et une colonne entière des données X0 sous-jacentes, rendant la reconstruction nécessitant des milliers de nonces complets et supprimant ainsi entièrement le compromis temps-mémoire asymétrique.

En conséquence, stocker le plot complet est la seule stratégie computationnellement viable pour les mineurs. Aucun raccourci connu — qu'il s'agisse de plotting partiel, de régénération sélective, de compression structurée ou d'approches hybrides calcul-stockage — ne fournit d'avantage significatif. PoCX garantit que le minage reste strictement lié au stockage et que la capacité reflète un engagement physique réel.

### 8.5 Attaques d'assignation

PoCX utilise une machine à états déterministe pour gouverner toutes les assignations plot-vers-forgeur. Chaque assignation progresse à travers des états bien définis — UNASSIGNED → ASSIGNING → ASSIGNED → REVOKING → REVOKED — avec des délais d'activation et de révocation appliqués. Cela garantit qu'un mineur ne peut pas changer instantanément les assignations pour tricher le système ou changer rapidement l'autorité de forge.

Parce que toutes les transitions nécessitent des preuves cryptographiques — spécifiquement, des signatures par le propriétaire du plot qui sont vérifiables contre l'UTXO d'entrée — le réseau peut faire confiance à la légitimité de chaque assignation. Les tentatives de contourner la machine à états ou de forger des assignations sont automatiquement rejetées lors de la validation de consensus. Les attaques par rejeu sont également empêchées par les protections standard de Bitcoin contre le rejeu de transaction, garantissant que chaque action d'assignation est uniquement liée à une entrée valide non dépensée.

La combinaison de la gouvernance par machine à états, des délais appliqués et de la preuve cryptographique rend la triche basée sur les assignations pratiquement impossible : les mineurs ne peuvent pas détourner les assignations, effectuer des réassignations rapides pendant les courses de blocs ou contourner les calendriers de révocation.

### 8.6 Sécurité des signatures

Les signatures de bloc dans PoCX servent de lien critique entre une preuve et la clé de forge effective, garantissant que seuls les mineurs autorisés peuvent produire des blocs valides.

Pour empêcher les attaques de malléabilité, les signatures sont exclues du calcul du hachage de bloc. Cela élimine les risques de signatures malléables qui pourraient compromettre la validation ou permettre des attaques de remplacement de bloc.

Pour atténuer les vecteurs de déni de service, les tailles de signature et de clé publique sont fixes — 65 octets pour les signatures compactes et 33 octets pour les clés publiques compressées — empêchant les attaquants de gonfler les blocs pour déclencher l'épuisement des ressources ou ralentir la propagation réseau.

---

## 9. Implémentation

PoCX est implémenté comme une extension modulaire de Bitcoin Core, avec tout le code pertinent contenu dans son propre sous-répertoire dédié et activé via un drapeau de fonctionnalité. Cette conception préserve l'intégrité du code original, permettant à PoCX d'être activé ou désactivé proprement, ce qui simplifie les tests, l'audit et le maintien de la synchronisation avec les changements amont.

L'intégration touche uniquement les points essentiels nécessaires pour supporter la preuve de capacité. L'en-tête de bloc a été étendu pour inclure des champs spécifiques à PoCX, et la validation de consensus a été adaptée pour traiter les preuves basées sur le stockage aux côtés des vérifications Bitcoin traditionnelles. Le système de forge, responsable de la gestion des deadlines, de la planification et des soumissions des mineurs, est entièrement contenu dans les modules PoCX, tandis que les extensions RPC exposent les fonctionnalités de minage et d'assignation aux clients externes. Pour les utilisateurs, l'interface de portefeuille a été améliorée pour gérer les assignations via des transactions OP_RETURN, permettant une interaction transparente avec les nouvelles fonctionnalités de consensus.

Toutes les opérations critiques pour le consensus sont implémentées en C++ déterministe sans dépendances externes, assurant la cohérence multiplateforme. Shabal256 est utilisé pour le hachage, tandis que le Time Bending et le calcul de qualité reposent sur l'arithmétique en virgule fixe et les opérations sur 256 bits. Les opérations cryptographiques telles que la vérification de signature exploitent la bibliothèque secp256k1 existante de Bitcoin Core.

En isolant ainsi la fonctionnalité PoCX, l'implémentation reste auditable, maintenable et entièrement compatible avec le développement continu de Bitcoin Core, démontrant qu'un mécanisme de consensus lié au stockage fondamentalement nouveau peut coexister avec une base de code de preuve de travail mature sans perturber son intégrité ou son utilisabilité.

---

## 10. Paramètres réseau

PoCX s'appuie sur l'infrastructure réseau de Bitcoin et réutilise son framework de paramètres de chaîne. Pour supporter le minage basé sur la capacité, les intervalles de bloc, la gestion des assignations et la mise à l'échelle des plots, plusieurs paramètres ont été étendus ou remplacés. Cela inclut le temps de bloc cible, la subvention initiale, le calendrier de halving, les délais d'activation et de révocation d'assignation, ainsi que les identifiants réseau tels que les octets magiques, les ports et les préfixes Bech32. Les environnements testnet et regtest ajustent davantage ces paramètres pour permettre une itération rapide et des tests à basse capacité.

Les tableaux ci-dessous résument les paramètres mainnet, testnet et regtest résultants, mettant en évidence comment PoCX adapte les paramètres fondamentaux de Bitcoin à un modèle de consensus lié au stockage.

### 10.1 Mainnet

| Paramètre | Valeur |
|-----------|--------|
| Octets magiques | `0xa7 0x3c 0x91 0x5e` |
| Port par défaut | 8888 |
| HRP Bech32 | `pocx` |
| Temps de bloc cible | 120 secondes |
| Subvention initiale | 10 BTC |
| Intervalle de halving | 1050000 blocs (~4 ans) |
| Offre totale | ~21 millions BTC |
| Activation d'assignation | 30 blocs |
| Révocation d'assignation | 720 blocs |
| Fenêtre glissante | 24 blocs |

### 10.2 Testnet

| Paramètre | Valeur |
|-----------|--------|
| Octets magiques | `0x6d 0xf2 0x48 0xb3` |
| Port par défaut | 18888 |
| HRP Bech32 | `tpocx` |
| Temps de bloc cible | 120 secondes |
| Autres paramètres | Identiques au mainnet |

### 10.3 Regtest

| Paramètre | Valeur |
|-----------|--------|
| Octets magiques | `0xfa 0xbf 0xb5 0xda` |
| Port par défaut | 18444 |
| HRP Bech32 | `rpocx` |
| Temps de bloc cible | 1 seconde |
| Intervalle de halving | 500 blocs |
| Activation d'assignation | 4 blocs |
| Révocation d'assignation | 8 blocs |
| Mode basse capacité | Activé (~4 Mo de plots) |

---

## 11. Travaux connexes

Au fil des années, plusieurs projets de blockchain et de consensus ont exploré des modèles de minage basés sur le stockage ou hybrides. PoCX s'appuie sur cette lignée tout en introduisant des améliorations en matière de sécurité, d'efficacité et de compatibilité.

**Burstcoin / Signum.** Burstcoin a introduit le premier système pratique de preuve de capacité (PoC) en 2014, définissant des concepts fondamentaux tels que les plots, les nonces, les scoops et le minage basé sur les deadlines. Ses successeurs, notamment Signum (anciennement Burstcoin), ont étendu l'écosystème et ont finalement évolué vers ce qui est connu sous le nom de Proof-of-Commitment (PoC+), combinant l'engagement de stockage avec un staking optionnel pour influencer la capacité effective. PoCX hérite de la base de minage basé sur le stockage de ces projets, mais diverge significativement par un format de plot renforcé (encodage XOR-transpose), une mise à l'échelle dynamique du travail de plot, un lissage de deadline (« Time Bending ») et un système d'assignation flexible — le tout en s'ancrant dans la base de code Bitcoin Core plutôt que de maintenir un fork de réseau autonome.

**Chia.** Chia implémente la preuve d'espace et de temps, combinant des preuves de stockage basées sur le disque avec une composante temporelle appliquée via des fonctions de délai vérifiables (VDFs). Sa conception adresse certaines préoccupations concernant la réutilisation des preuves et la génération de défis frais, distinctes du PoC classique. PoCX n'adopte pas ce modèle de preuve ancré dans le temps ; au lieu de cela, il maintient un consensus lié au stockage avec des intervalles prévisibles, optimisé pour une compatibilité à long terme avec l'économie UTXO et l'outillage dérivé de Bitcoin.

**Spacemesh.** Spacemesh propose un schéma de preuve d'espace-temps (PoST) utilisant une topologie réseau basée sur un DAG (mesh). Dans ce modèle, les participants doivent périodiquement prouver que le stockage alloué reste intact au fil du temps, plutôt que de s'appuyer sur un seul jeu de données pré-calculé. PoCX, en revanche, vérifie l'engagement de stockage uniquement au moment du bloc — avec des formats de plot renforcés et une validation de preuve rigoureuse — évitant la surcharge des preuves de stockage continues tout en préservant l'efficacité et la décentralisation.

---

## 12. Conclusion

Bitcoin-PoCX démontre qu'un consensus écoénergétique peut être intégré dans Bitcoin Core tout en préservant les propriétés de sécurité et le modèle économique. Les contributions clés incluent l'encodage XOR-transpose (force les attaquants à calculer 4096 nonces par consultation, éliminant l'attaque par compression), l'algorithme Time Bending (la transformation de distribution réduit la variance du temps de bloc), le système d'assignation de forge (la délégation basée sur OP_RETURN permet le minage en pool non-custodial), la mise à l'échelle dynamique (alignée avec les halvings pour maintenir les marges de sécurité) et l'intégration minimale (code conditionné isolé dans un répertoire dédié).

Le système est actuellement en phase testnet. La puissance de minage dérive de la capacité de stockage plutôt que du taux de hachage, réduisant la consommation d'énergie de plusieurs ordres de grandeur tout en maintenant le modèle économique éprouvé de Bitcoin.

---

## Références

Bitcoin Core. *Bitcoin Core Repository.* https://github.com/bitcoin/bitcoin

Burstcoin. *Proof of Capacity Technical Documentation.* 2014.

NIST. *SHA-3 Competition: Shabal.* 2008.

Cohen, B., Pietrzak, K. *The Chia Network Blockchain.* 2019.

Spacemesh. *Spacemesh Protocol Documentation.* 2021.

PoC Consortium. *PoCX Framework.* https://github.com/PoC-Consortium/pocx

PoC Consortium. *Bitcoin-PoCX Integration.* https://github.com/PoC-Consortium/bitcoin-pocx

---

**Licence** : MIT
**Organisation** : Proof of Capacity Consortium
**Statut** : Phase Testnet
