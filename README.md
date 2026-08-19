# ImproveAI

**Advanced AI behaviour and command system for Cortex Command Community Project**

ImproveAI est un mod pour **Cortex Command Community Project (CCCP)** visant à enrichir les comportements des unités contrôlées par l'IA et à proposer des commandes plus précises via le menu radial.

Le projet cherche à rester aussi largement que possible **compatible avec l'IA et les AIModes natifs du CCCP**, en ajoutant une couche de comportement plutôt qu'en remplaçant inutilement les mécanismes existants.

---

## Fonctionnalités prévues

### Sentry

ImproveAI propose plusieurs profils de comportement pour les unités en mode Sentry.

```text
Sentry
├── ⚪ Hold
├── 🔵 Passive Defence
└── 🔴 Active Defence
```

Les couleurs sont uniquement des **repères visuels dans le menu radial**. Elles ne correspondent pas à des états internes du moteur.

#### ⚪ Hold

L'unité reste immobile et conserve le comportement de sentinelle standard.

#### 🔵 Passive Defence

L'unité reste en position et n'engage pas activement les ennemis.

Elle ne se défend que lorsqu'elle est elle-même attaquée.

#### 🔴 Active Defence

L'unité recherche activement des cibles ennemies situées dans sa zone d'engagement.

Le comportement prévu comprend notamment :

* prise en compte de la portée effective de l'arme ;
* utilisation d'une marge de sécurité avant la portée maximale ;
* vérification de la ligne de tir ;
* sélection prioritaire de la tête lorsqu'elle est exploitable ;
* recours aux jambes ou à une autre partie du corps lorsque la tête n'est pas exploitable ;
* adaptation de la posture pour améliorer la ligne de tir ;
* utilisation de la position accroupie lorsque cela présente un avantage défensif ou tactique.

Le système de ciblage sera développé progressivement afin de tenir compte des obstacles, équipements, constructions et éléments du terrain.

---

## Miner

Deux profils de minage sont prévus :

```text
Miner
├── Classic
└── Optimized
```

### ⛏ Classic Mining

Utilise le comportement de minage natif du CCCP.

### 🏗 Optimized Mining

L'objectif est de proposer une méthode de minage structurée lorsque l'unité dispose d'un outil de construction compatible, tel qu'un Constructor.

Le principe prévu est de créer un réseau de galeries plutôt que de simplement creuser progressivement dans une direction.

Caractéristiques envisagées :

* galeries d'environ 20 blocs de largeur ;
* hauteur d'environ 6 blocs ;
* utilisation des structures verticales existantes comme références lorsque cela est possible ;
* conservation d'un passage sécurisé vers les zones précédemment exploitées ;
* connexions entre les différents niveaux ;
* ouvertures verticales contrôlées ;
* escaliers ou passages facilitant les déplacements ;
* conservation permanente d'un chemin permettant à l'unité de revenir vers les zones précédentes.

L'objectif est de permettre un minage pouvant se poursuivre sur une longue durée sans produire un réseau de galeries impossible à parcourir ou une unité incapable de remonter.

Les dimensions et paramètres pourront être rendus configurables.

---

## Menu radial

ImproveAI utilise le système de **Pie Menu** existant du CCCP.

L'objectif est d'organiser les commandes sous forme de catégories et de sous-menus afin de permettre une lecture rapide en situation de jeu.

Exemple :

```text
Change AI Mode
│
├── Sentry
│   ├── ⚪ Hold
│   ├── 🔵 Passive Defence
│   └── 🔴 Active Defence
│
├── Patrol
│
├── Brain Hunt
│
├── Miner
│   ├── Classic
│   └── Optimized
│
└── Go To
```

Les couleurs utilisées dans les icônes ont pour seul objectif d'améliorer l'identification visuelle des ordres.

---

## Philosophie technique

ImproveAI cherche à éviter autant que possible la création de nouveaux `AIMode` dans le moteur C++.

Le projet utilise les modes natifs du CCCP comme base :

```text
AIMODE_SENTRY
AIMODE_GOLDDIG
AIMODE_PATROL
AIMODE_GOTO
...
```

Les profils propres à ImproveAI sont stockés séparément du mode d'IA natif.

Conceptuellement :

```text
AIMode
    │
    └── ordre moteur courant

ImproveAI Profile
    │
    └── manière dont ImproveAI exécute cet ordre
```

Par exemple :

```text
AIMODE_SENTRY
    +
ImproveAI.Profile = SENTRY_ACTIVE
```

Cette séparation doit permettre de limiter les interactions indésirables avec les mécanismes natifs du jeu.

Elle est particulièrement importante pour les systèmes tels que les **Squads**, qui peuvent temporairement modifier le comportement ou le mode d'une unité.

---

## Compatibilité avec les Squads

ImproveAI doit tenir compte du fait que les unités peuvent être intégrées à un Squad puis en être retirées.

Le profil ImproveAI ne doit donc pas être déduit uniquement de `Actor.AIMode`.

Par exemple :

```text
SENTRY_ACTIVE
      │
      ▼
    Squad
      │
      ▼
ordre temporaire du Squad
      │
      ▼
Squad annulé
      │
      ▼
reprise du comportement précédent
```

L'objectif est que les commandes de groupe et les commandes ImproveAI puissent coexister sans qu'une annulation de Squad transforme ou efface involontairement le profil choisi par le joueur.

---

## Architecture du projet

La structure prévue est volontairement séparée entre le code, les interfaces et les ressources :

```text
ImproveAI.rte/
│
├── Index.ini
│
├── README.md
├── CHANGELOG.md
├── CREDITS.md
├── LICENSE
├── Preview.png
│
├── Icons/
│   ├── Module.png
│   └── Pie/
│       ├── SentryHold.png
│       ├── SentryPassive.png
│       ├── SentryActive.png
│       ├── MinerClassic.png
│       └── MinerOptimized.png
│
├── AI/
│   ├── Main.lua
│   ├── Sentry.lua
│   ├── SentryTargeting.lua
│   ├── Miner.lua
│   └── MinerOptimized.lua
│
├── GUI/
│   ├── PieMenus.ini
│   └── PieIcons.ini
│
└── Config/
    └── ImproveAI.ini
```

Cette organisation est une convention propre au projet. Elle ne prétend pas constituer une norme officielle du CCCP.

---

## Configuration

Les paramètres susceptibles d'être ajustés par l'utilisateur seront progressivement déplacés vers des fichiers `.ini`.

Les paramètres envisagés comprennent notamment :

```text
Sentry effective range
Targeting preferences
Crouch behaviour
Mining tunnel width
Mining tunnel height
Vertical opening size
Wall clearance
Stair dimensions
```

L'objectif est de pouvoir modifier le comportement sans devoir modifier directement le code Lua.

---

## Développement

ImproveAI est développé pour **Cortex Command Community Project**.

Le projet privilégie :

* Lua lorsque cela est possible ;
* les fichiers INI pour la configuration et la déclaration des ressources ;
* les mécanismes natifs du CCCP ;
* les modifications C++ uniquement lorsqu'elles sont réellement nécessaires.

Le projet ne cherche pas à remplacer l'IA native dans son ensemble, mais à lui ajouter des comportements spécialisés.

---

## État du projet

**Work in Progress**

Les fonctionnalités décrites dans ce document représentent l'objectif et la conception actuelle du projet. Elles peuvent changer pendant le développement.

Certaines fonctionnalités décrites peuvent ne pas encore être implémentées.

---

## Crédits

### ImproveAI

**Fr_Dae** — conception et développement.

### Cortex Command Community Project

ImproveAI est développé pour être utilisé avec le **Cortex Command Community Project**.

Les éléments appartenant au CCCP et à ses contributeurs restent la propriété de leurs auteurs respectifs et sont soumis à leurs propres conditions de licence.

### Contributions

Les contributions, corrections, suggestions et améliorations sont les bienvenues.

---

## Licence

Les éléments originaux d'ImproveAI sont distribués sous :

**Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)**

Voir [`LICENSE`](LICENSE) pour les détails.

Les éléments provenant de tiers ne sont pas nécessairement couverts par cette licence.

---

## Liens

* Cortex Command Community Project : https://github.com/cortex-command-community/Cortex-Command-Community-Project
* Documentation / Wiki CCCP : https://github.com/cortex-command-community/Cortex-Command-Community-Project/wiki
* Licence CC BY-SA 4.0 : https://creativecommons.org/licenses/by-sa/4.0/
