# Gestion des modules de GeoNature

Contient des scripts spécifiques aux modules GeoNature.

## Synchronisation serveur

Pour transférer uniquement le dossier `modules/` sur le serveur, utiliser `rsync`
en testant avec l'option `--dry-run` (à supprimer quand tout est ok):

```
rsync -av --copy-unsafe-links ./ geonat@floresentinelle:~/data/modules/ --dry-run
```

## Exécution du SQL

Fichier SQL à éxecuter sur l'instance `floresentinelle`, se placer dans le dossier `modules/`
et utiliser les commandes :
```
source ../shared/config/settings.default.ini
source ../shared/config/settings.ini
psql -h "${db_host}" -U "${db_user}" -d "${db_name}" -f ./<nom-modul>/<nom-script>.sql
```
