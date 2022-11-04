# Scripts SQL, Bash et données pour floresentinelle.fr


## Migrate RCFAA

Contient des scripts de migration dans le cadre de Flore Sentinelle du site
http://reseau-conservation-alpes-ain.fr/ vers https://geonature.floresentinelle.fr/.

### Procédures

  * Déployer ce dépôt sur le serveur hébergeant floresentinelle.fr à l'aide de `git clone` ou `rsync`.
  * Se placer à la racine du dossier `migrate_rcfaa/` à l'aide de la commande `cd`
  * Les scripts de migrations sont présent dans le dossier `bin/`. Pour afficher les options de chaque script
  utiliser l'option `-h`. Exemple : `./bin/migrate_users.sh -h`
  * L'ensemble des scripts utilisent les fichiers de configuration présent dans le dossier `config/`. Le fichier `settings.default.ini` est chargé en premier lieu. Ses valeurs de paramètres peuvent être écrasé par celles
    présentes dans un fichier `settings.ini`.
  * Si vous souhaitez modifier des valeurs de configuration par défaut :
    * Créer le fichier `settings.ini` à l'aide du fichier `settings.sample.ini` avec :
      ```bash
      cp migrate_rcfaa/config/settings.sample.ini migrate_rcfaa/config/settings.ini
      ```
    * Éditer les valeurs du fichier `settings.ini` avec :
      ```bash
      vi migrate_rcfaa/config/settings.ini
      ```
  * Se placer à la racine du dossier `migrate_rcfaa/` et lancer les scripts Bash dans cet ordre :
    * `./bin/migrate_users.sh -v`

