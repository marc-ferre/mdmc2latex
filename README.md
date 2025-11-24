# mdmc2latex

Convertisseur de fichiers Markdown QCM (.mdmc) vers LaTeX pour AMC (Auto Multiple Choice).

## Description

Ce script Perl convertit des fichiers QCM au format Markdown personnalisé (.mdmc) en fichiers LaTeX compatibles avec AMC. Il utilise Pandoc pour la conversion Markdown vers LaTeX et génère des questions multiples avec réponses bonnes ou mauvaises.

## Installation

1. Assurez-vous que Perl est installé sur votre système.
2. Installez Pandoc (>= 1.12) : `brew install pandoc` (sur macOS) ou via votre gestionnaire de paquets.
3. Installez le module Perl Pandoc : `cpan install Pandoc`.
4. Téléchargez ou clonez ce dépôt.

## Utilisation

```bash
perl mdmc2latex.pl <fichier.mdmc> [--fid <numéro de première question>]
```

### Options

- `--fid=i` : Numéro de la première question (par défaut 1, non implémenté)
- `--keep` : Garder le fichier Markdown intermédiaire (non implémenté)
- `--help` : Afficher l'aide

### Exemple

```bash
perl mdmc2latex.pl sujet.mdmc --fid 10
```

Le script affiche des statistiques colorées à la fin de la conversion pour un meilleur suivi.

## Format du fichier Markdown (.mdmc)

Le fichier d'entrée doit suivre un format spécifique :

- **Titre de la question** : `## [ID de la question]`
- **Texte de la question** : `### Texte de la question`
- **Réponses** : `+ Bonne réponse` ou `- Mauvaise réponse`
- **Séparation** : Ligne vide pour finir une question

### Exemple de fichier .mdmc

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

Le script génère un fichier .tex compatible avec AMC.

## Dépendances

- Perl
- Pandoc (>= 1.12)
- Module Perl : Pandoc
- Module Perl : Term::ANSIColor (pour la sortie colorée)

## Tests

Pour exécuter les tests :

```bash
perl test_mdmc2latex.pl
```

Des exemples de fichiers .mdmc sont disponibles dans le dossier `examples/` pour tester le script.

## Auteur

Marc FERRE

## Licence

Ce projet est sous licence CeCILL v2.1. Voir [LICENSE](LICENSE) pour plus de détails.
