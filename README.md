# Scripts de migration des données pour floresentinelle.fr

Scripts de migration dans le cadre de Flore Sentinelle du site http://reseau-conservation-alpes-ain.fr/ vers https://geonature.floresentinelle.fr/


## Procédures

  * Déployer ce dépôt sur le serveur hébergeant floresentinelle.fr à l'aide de `git clone` ou `rsync`.
  * Se placer à la racine du dépot à l'aide de la commande `cd`
  * Les scripts de migrations sont présent dans le dossier `bin/`. Pour afficher les options de chaque script 
  utiliser l'option `-h`. Exemple : `./bin/migrate_users.sh -h`
  * L'ensemble des scripts utilisent les fichiers de configuration présent dans le dossier `config/`. Le fichier
    `settings.default.ini` est chargé en premier lieu. Ses valeurs de paramètres peuvent être écrasé par celles
    présentes dans un fichier `settings.ini`.
  * Si vous souhaitez modifier des valeurs de configuration par défaut :
    * Créer le fichier `settings.ini` à l'aide du fichier `settings.sample.ini` : `cp config/settings.sample.ini config/settings.ini`
    * Éditer les valeurs du fichier `settings.ini` : `vi config/settings.ini`
  * Se placer à la racine du dépot et lancer les scripts Bash dans cet ordre :
    * `./bin/migrate_users.sh -v`

