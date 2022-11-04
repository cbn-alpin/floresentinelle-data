# Fusion d'utilisateur

Contient un script Bash permettant la fusion de plusieurs utilisateurs
de GeoNature afin de supprimer les doublons.

## Synchronisation serveur
Pour transférer uniquement le dossier `merge_user/` sur le serveur, utiliser `rsync`
en testant avec l'option `--dry-run` (à supprimer quand tout est ok):

```bash
rsync -av \
    --exclude var \
    --exclude .gitignore \
    --exclude settings.ini \
    --exclude "data/raw/*" \
    ./ geonat@floresentinelle:~/data/merge_user/ --dry-run
```

## Procédures

  * Déployer ce dossier sur le serveur hébergeant floresentinelle.fr à l'aide de `rsync` (voir ci-dessus).
  * Se placer à la racine du dossier `merge_user/` à l'aide de la commande `cd` : `cd ~/data/merge_user/`
  * Les scripts de migrations sont présent dans le dossier `bin/`. Pour afficher les options de chaque script
  utiliser l'option `-h`. Exemple : `./bin/migrate_users.sh -h`
  * L'ensemble des scripts utilisent les fichiers de configuration présent dans le dossier `config/`. Le fichier `settings.default.ini` est chargé en premier lieu. Ses valeurs de paramètres peuvent être écrasé par celles
    présentes dans un fichier `settings.ini`.
  * Si vous souhaitez modifier des valeurs de configuration par défaut :
    * Créer le fichier `settings.ini` avec :
      ```bash
      touch config/settings.ini
      ```
    * Éditer les valeurs du fichier `settings.ini` avec :
      ```bash
      vi config/settings.ini
      ```
  * Lancer le scripts Bash :
    * à partir d'une liste dans un fichier CSV : `./bin/migrate_users.sh -v -f <chemin-fichier-csv>`
    * pour un utilisateur à fusionner : `./bin/migrate_users.sh -v -n <id-role-à-garder> -o <ids-roles-à-remplacer>`

