# Aide

## TODO
  * [] Ajouter la réinitialisation de la base `geonature2db` (relancer le script d'install db de GeoNature ?).

## Pré-requis
1. Ouvrir une Console et se placer dans le dossier "scripts" contenant le fichier "migration.sh" : `cd <path>/migration-v1-to-v2/scripts`
1. Créer le fichier settings.ini à partir du fichier settings.ini.example : ` cp settings.ini.example settings.ini`
1. Adapter à votre installation les paramètres du fichier settings.ini
1. Donner les droits d'éxécution à ce fichier : `chmod +x ./migration.sh`

## Principes
Le script `migration.sh` va éxecuter successivement des scripts SQL présens dans les sous-dossiers.\\
La migration peut être relancer à tout moment et va réinitialiser la base (BIENTÖT).

## Exécution de la migration
1. Lancer le script migration.sh : `./migration.sh`
1. Voir les résultats de la migration dans le fichier de log : `vi migration-v1-to-v2.log`
