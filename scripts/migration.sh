#!/bin/bash

# Aide
# 0. Ouvrir une Console et se placer dans le dossier "scripts" contenant le fichier "migration.sh" : cd <path>/floresentinelle-migrate/scripts
# 1. Créer le fichier settings.ini à partir du fichier settings.example.ini
# 2. Adapter à votre installation les paramètres du fichier settings.ini
# 3. Donner les droits d'éxécution à ce fichier : chmod +x ./migration.sh
# 3. Lancer le script migration.sh : ./migration.sh
# 4. Voir les résultats de la migration dans le fichier de log

# Chargements des paramètres de configuration
. settings.ini

# Création du fichier de log
rm -f $log_file
touch $log_file
sudo chmod 777 $log_file

#Sur le serveur de GeoNature V2 : création du lien FDW avec la base GeoNature1 
sudo -n -u $pg_admin_name -s psql -d $db_name -c \
    "CREATE EXTENSION IF NOT EXISTS postgres_fdw;" >> $log_file
sudo -n -u $pg_admin_name -s psql -d $db_name -c \
    "DROP SERVER IF EXISTS geonaturev1server CASCADE;" >> $log_file
sudo -n -u $pg_admin_name -s psql -d $db_name -c \
    "CREATE SERVER geonaturev1server FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '$gn1_db_host', dbname '$gn1_db_name', port '$gn1_db_port');" >> $log_file
sudo -n -u $pg_admin_name -s psql -d $db_name -c \
    "CREATE USER MAPPING FOR $db_user SERVER geonaturev1server OPTIONS (user '$gn1_db_user', password '$gn1_db_pass');" >> $log_file
sudo -n -u $pg_admin_name -s psql -d $db_name -c \
    "ALTER SERVER geonaturev1server OWNER TO $db_user;" >> $log_file

sudo -n -u $pg_admin_name -s psql -d $db_name -c \
    "DROP SCHEMA IF EXISTS migrate_v1_florepatri;" >> $log_file
sudo -n -u $pg_admin_name -s psql -d $db_name -c \
    "CREATE SCHEMA migrate_v1_florepatri;" >> $log_file
sudo -n -u $pg_admin_name -s psql -d $db_name -c \
    "IMPORT FOREIGN SCHEMA florepatri FROM SERVER geonaturev1server INTO migrate_v1_florepatri;" >> $log_file

sudo -n -u $pg_admin_name -s psql -d $db_name -c \
    "DROP SCHEMA IF EXISTS migrate_v1_utilisateurs;" >> $log_file
sudo -n -u $pg_admin_name -s psql -d $db_name -c \
    "CREATE SCHEMA migrate_v1_utilisateurs;" >> $log_file
sudo -n -u $pg_admin_name -s psql -d $db_name -c \
    "IMPORT FOREIGN SCHEMA utilisateurs FROM SERVER geonaturev1server INTO migrate_v1_utilisateurs;" >> $log_file

# Example pour lancer un script SQL :
#export PGPASSWORD='$db_pass';psql -h $db_host -U $db_user -d $db_name -f '01-users/01-t_roles.sql' >> $log_file
