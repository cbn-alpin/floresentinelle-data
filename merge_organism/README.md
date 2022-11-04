# Fusion d'organismes

Contient un script Bash permettant la fusion de plusieurs organismes
de GeoNature afin de supprimer les doublons.

## Synchronisation serveur
Pour transférer uniquement le dossier `merge_organism/` sur le serveur, utiliser `rsync`
en testant avec l'option `--dry-run` (à supprimer quand tout est ok):

```bash
rsync -av \
    --exclude var \
    --exclude .gitignore \
    --exclude settings.ini \
    --exclude "data/raw/*" \
    ./ geonat@floresentinelle:~/data/merge_organism/ --dry-run
```

## Procédures

  * Déployer ce dossier sur le serveur hébergeant floresentinelle.fr à l'aide de `rsync` (voir ci-dessus).
  * Se placer à la racine du dossier `merge_organism/` à l'aide de la commande `cd` : `cd ~/data/merge_organism/`
  * Les scripts de migrations sont présent dans le dossier `bin/`. Pour afficher les options de chaque script
  utiliser l'option `-h`. Exemple : `./bin/merge_organisms.sh -h`
  * L'ensemble des scripts utilisent les fichiers de configuration présent dans le dossier `config/`. Le fichier `settings.default.ini` est chargé en premier lieu. Ses valeurs de paramètres peuvent être écrasé par celles
    présentes dans un fichier `settings.ini`.
  * Si vous souhaitez modifier des valeurs de configuration par défaut, créer et éditer les valeurs du fichier `settings.ini` avec :
    ```bash
    vi config/settings.ini
    ```
  * Lancer le scripts Bash :
    * à partir d'une liste dans un fichier CSV : `./bin/merge_organisms.sh -v -f <chemin-fichier-csv>`
    * pour un organisme à fusionner : `./bin/merge_organisms.sh -v -n <id-organisme-à-garder> -o <ids-organismes-à-remplacer>`

