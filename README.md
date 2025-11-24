# mdmc2latex

Convertisseur de fichiers Markdown QCM (.mdmc) vers LaTeX pour AMC (Auto Multiple Choice).

## Description

Ce script Perl convertit des fichiers QCM au format Markdown personnalisé (.mdmc) en fichiers LaTeX compatibles avec AMC.

## Utilisation

```bash
perl mdmc2latex.pl <fichier.mdmc> [--fid <numéro de première question>]
```

## Options

- `--fid=i` : Numéro de la première question (par défaut 1)
- `--keep` : Garder le fichier Markdown intermédiaire (non implémenté)
- `--help` : Afficher l'aide

## Exemple

```bash
perl mdmc2latex.pl sujet.mdmc --fid 10
```

## Dépendances

- Perl
- Pandoc (>= 1.12)

## Auteur

Marc FERRE

## Licence

Ce projet est sous licence MIT. Voir [LICENSE](LICENSE) pour plus de détails.

ALL RIGHTS RESERVED.
