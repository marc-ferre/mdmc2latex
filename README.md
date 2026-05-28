# mdmc2latex

Convertisseur de fichiers Markdown QCM (.mdmc) vers LaTeX pour AMC (Auto Multiple Choice).

## Description

Ce script Perl convertit des fichiers QCM au format Markdown personnalisé (.mdmc) en fichiers LaTeX compatibles avec AMC. Il utilise le binaire `pandoc` pour la conversion Markdown -> LaTeX et génère des blocs `questionmult`/`question` utilisables dans AMC.

## Installation

1. Assurez-vous que Perl est installé sur votre système.
2. Installez Pandoc (>= 1.12) : `brew install pandoc` (sur macOS) ou via votre gestionnaire de paquets.
3. Clonez le dépôt.

## Utilisation

```bash
perl mdmc2latex.pl <fichier.mdmc> [--fid <numéro de première question>]
```

### Options

- `--fid=i` : Numéro de la première question (par défaut 1, non implémenté)
- `--keep` : Garder le fichier Markdown intermédiaire (non implémenté)
- `--help` : Afficher l'aide
- `--ltcaptype=<table|figure|relax|none>` : Valeur utilisée pour `\def\LTcaptype{...}` dans le LaTeX généré (par défaut `table`). `none` équivaut à `relax` et peut provoquer des erreurs LaTeX selon le modèle ; utilisez avec précaution.

### Exemple

```bash
perl mdmc2latex.pl sujet.mdmc --fid 10
```

### Exemple d'utilisation de --ltcaptype

```sh
perl mdmc2latex.pl --ltcaptype=relax sujet.mdmc   # utilise \relax (évite incrémentation, peut provoquer des erreurs selon le modèle)
perl mdmc2latex.pl --ltcaptype=figure sujet.mdmc  # utilise 'figure'
```

Le script affiche des statistiques colorées à la fin de la conversion pour un meilleur suivi.

## Format du fichier Markdown (.mdmc)

Le fichier d'entrée doit suivre un format simple :

- **Titre de la question** : `## [ID de la question]`
- **Texte de la question** : `### Texte de la question`
- **Réponses** : `+ Bonne réponse` ou `- Mauvaise réponse`
- **Séparation** : Ligne vide pour finir une question

### Règle harmonisée sur les propositions

- **4 propositions** : le script ajoute automatiquement `Aucune de ces réponses n'est correcte.`
- **5 propositions** : aucune proposition supplémentaire n'est ajoutée
- **Moins de 4 ou plus de 5 propositions** : erreur explicite

Si les 4 propositions initiales sont toutes fausses, l'option `Aucune de ces réponses n'est correcte.` devient elle-même la bonne réponse.

### Exemple d'un fichier .mdmc

```markdown
## [Q1]
### Quelle est la capitale de la France ?
+ Paris
- Lyon
- Marseille
- Toulouse

## [Q2]
### 2 + 2 = ?
+ 4
- 3
- 5
- 6
```

Le script génère un fichier `.tex` compatible avec AMC.

## Dépendances

- Perl
- Pandoc (>= 1.12)
- Module Perl : Term::ANSIColor (pour la sortie colorée)

## Tests

Pour exécuter les tests :

```bash
perl test_mdmc2latex.pl
```

Un petit corpus de spec est aussi fourni dans `tests/corpus/` pour verrouiller les cas `4 propositions` et `5 propositions`.

Un outil de sanitization est disponible : `tools/sanitize_tex.pl`.
Il permet de normaliser les fichiers `.tex` existants (remplacement de `\\def\\LTcaptype{...}`, ajustement automatique des `\\includegraphics` pour limiter la largeur, et wrapper `longtable`).

Par défaut, la sanitation n'agrandira pas les images plus petites que la largeur maximale ; `tools/sanitize_tex.pl` enveloppe les images avec `\adjustbox{max width=\linewidth}{...}` afin de réduire les images sur-dimensionnées sans agrandir les plus petites.
Le script injecte automatiquement `\\usepackage{adjustbox}` dans le préambule si le package n'est pas déjà chargé, ce qui permet l'usage de `\\adjustbox`.

Exemples :

```sh
# Sanitise everything recursively in current directory
perl tools/sanitize_tex.pl --ltcaptype=table .

# Dry-run (preview) sanitize
perl tools/sanitize_tex.pl --ltcaptype=table --dry-run path/to/dir
```

Des exemples de fichiers `.mdmc` sont disponibles dans le dossier `examples/` pour tester le script.

### Sanitization via `mdmc2latex`

Vous pouvez exécuter le sanitization automatiquement après la génération du `.tex` via `mdmc2latex.pl` :

```bash
perl mdmc2latex.pl --sanitize --ltcaptype=table examples/sujet.mdmc
```

Si vous souhaitez **prévisualiser** l’action de la sanitation sans modifier les fichiers, utilisez le flag `--sanitize-dry-run` :

```bash
perl mdmc2latex.pl --sanitize --sanitize-dry-run --ltcaptype=table examples/sujet.mdmc
```

## Correctifs récents

- Le script remplace désormais `\\def\\LTcaptype{none}` (ou `0`) par la valeur choisie via l'option `--ltcaptype` (par défaut `table`). Avant, il utilisait `0`, ce qui provoquait une erreur LaTeX "No counter '0' defined". Cette modification évite la génération d'identifiants de compteur numériques invalides et les erreurs de compilation.

## Auteur

Marc FERRE

## Licence

Ce projet est sous licence CeCILL v2.1. Voir [LICENSE](LICENSE) pour plus de détails.
