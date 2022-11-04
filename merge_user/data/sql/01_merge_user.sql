-- Delete properly duplicate users.
-- Required rights: DB OWNER
-- GeoNature database compatibility : v2.6.0+
-- Use this script this way: psql -h localhost -U geonatadmin -d geonature2db \
--      -v 'oldIdRole=<old_id_role>' -v 'newIdRole=<new_id_role>' \
--      -f ~/data/merge_users/data/sql/01_merge_user.sql
--
-- Tables qui ne seront pas traitées :
--      utilisateurs.cor_roles_app_profil => ne semble gérer que des groupes !
--      utilisateurs.cor_role_token => uniquement pour les utilisateurs temporaire (création de compte)
--
-- Lister les tables à traiter en ouvrant la liste des dépendances de la table t_roles avec
-- éditeur de base de données.
--
-- Tables restant à traiter :
--      pr_occtax.t_releves_occtax
--      pr_occtax.cor_role_releves_occtax
--      pr_occhab.t_stations
--      pr_occhab.cor_station_observer



BEGIN;

-- Tables à mettre à jour :

\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_role in "utilisateurs.cor_roles"'
UPDATE utilisateurs.cor_roles AS cr SET
    id_role_utilisateur = :newIdRole
WHERE cr.id_role_utilisateur IN (:oldIdRole)
    AND NOT EXISTS (
        SELECT 'x'
        FROM utilisateurs.cor_roles AS cr1
        WHERE cr1.id_role_utilisateur = :newIdRole
            AND cr1.id_role_groupe = cr.id_role_groupe
    ) ;

\echo 'Delete old id_role in "utilisateurs.cor_roles" when new id_role already exists'
DELETE FROM utilisateurs.cor_roles
WHERE id_role_utilisateur IN (:oldIdRole) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_role in "utilisateurs.cor_role_liste"'
UPDATE utilisateurs.cor_role_liste AS crl SET
    id_role = :newIdRole
WHERE crl.id_role IN (:oldIdRole)
    AND NOT EXISTS (
        SELECT 'x'
        FROM utilisateurs.cor_role_liste AS crl1
        WHERE crl1.id_role = :newIdRole
            AND crl1.id_liste = crl.id_liste
    ) ;

\echo 'Delete old id_role in "utilisateurs.cor_role_liste" when new id_role already exists'
DELETE FROM utilisateurs.cor_role_liste
WHERE id_role IN (:oldIdRole) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_role in "gn_commons.t_validations"'
UPDATE gn_commons.t_validations AS tv SET
    id_validator = :newIdRole
WHERE tv.id_validator IN (:oldIdRole)
    AND NOT EXISTS (
        SELECT 'x'
        FROM gn_commons.t_validations AS tv1
        WHERE tv1.id_validator = :newIdRole
            AND tv1.uuid_attached_row = tv.uuid_attached_row
            AND tv1.id_nomenclature_valid_status = tv.id_nomenclature_valid_status
            AND tv1.validation_auto = tv.validation_auto
            AND tv1.validation_comment = tv.validation_comment
            AND tv1.validation_date = tv.validation_date
    ) ;

\echo 'Delete old id_role in "gn_commons.t_validations" when new id_role already exists'
DELETE FROM gn_commons.t_validations
WHERE id_validator IN (:oldIdRole) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_role in "gn_commons.t_places"'
UPDATE gn_commons.t_places AS tp SET
    id_role = :newIdRole
WHERE tp.id_role IN (:oldIdRole)
    AND NOT EXISTS (
        SELECT 'x'
        FROM gn_commons.t_places AS tp1
        WHERE tp1.id_role = :newIdRole
            AND tp1.place_name = tp.place_name
            AND tp1.place_geom = tp.place_geom
    ) ;

\echo 'Delete old id_role in "gn_commons.t_places" when new id_role already exists'
DELETE FROM gn_commons.t_places
WHERE id_role IN (:oldIdRole) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_role in "gn_meta.t_acquisition_frameworks"'
UPDATE gn_meta.t_acquisition_frameworks AS taf SET
    id_digitizer = :newIdRole
WHERE taf.id_digitizer IN (:oldIdRole) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_role in "gn_meta.cor_acquisition_framework_actor"'
UPDATE gn_meta.cor_acquisition_framework_actor AS cafa SET
    id_role = :newIdRole
WHERE cafa.id_role IN (:oldIdRole)
    AND NOT EXISTS (
        SELECT 'x'
        FROM gn_meta.cor_acquisition_framework_actor AS cafa1
        WHERE cafa1.id_role = :newIdRole
            AND cafa1.id_acquisition_framework = cafa.id_acquisition_framework
            AND cafa1.id_nomenclature_actor_role = cafa.id_nomenclature_actor_role
    ) ;

\echo 'Delete old id_role in "gn_meta.cor_acquisition_framework_actor" when new id_role already exists'
DELETE FROM gn_meta.cor_acquisition_framework_actor
WHERE id_role IN (:oldIdRole) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_role in "gn_meta.t_datasets"'
UPDATE gn_meta.t_datasets AS td SET
    id_digitizer = :newIdRole
WHERE td.id_digitizer IN (:oldIdRole) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_role in "gn_meta.cor_dataset_actor"'
UPDATE gn_meta.cor_dataset_actor AS cda SET
    id_role = :newIdRole
WHERE cda.id_role IN (:oldIdRole)
    AND NOT EXISTS (
        SELECT 'x'
        FROM gn_meta.cor_dataset_actor AS cda1
        WHERE cda1.id_role = :newIdRole
            AND cda1.id_dataset = cda.id_dataset
            AND cda1.id_nomenclature_actor_role = cda.id_nomenclature_actor_role
    ) ;

\echo 'Delete old id_role in "gn_meta.cor_dataset_actor" when new id_role already exists'
DELETE FROM gn_meta.cor_dataset_actor
WHERE id_role IN (:oldIdRole) ;

\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_role in "gn_permissions.cor_role_action_filter_module_object"'
UPDATE gn_permissions.cor_role_action_filter_module_object AS crafmo SET
    id_role = :newIdRole
WHERE crafmo.id_role IN (:oldIdRole)
    AND NOT EXISTS (
        SELECT 'x'
        FROM gn_permissions.cor_role_action_filter_module_object AS crafmo1
        WHERE crafmo1.id_role = :newIdRole
            AND crafmo1.id_module = crafmo.id_module
            AND crafmo1.id_action = crafmo.id_action
            AND crafmo1.id_object = crafmo.id_object
            AND crafmo1.id_filter = crafmo.id_filter
    ) ;

\echo 'Delete old id_role in "gn_permissions.cor_role_action_filter_module_object" when new id_role already exists'
DELETE FROM gn_permissions.cor_role_action_filter_module_object
WHERE id_role IN (:oldIdRole) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_digitiser in "gn_synthese.synthese"'
UPDATE gn_synthese.synthese AS s SET
    id_digitiser = :newIdRole
WHERE s.id_digitiser IN (:oldIdRole) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_role in "gn_synthese.cor_observer_synthese"'
UPDATE gn_synthese.cor_observer_synthese AS cos0 SET
    id_role = :newIdRole
WHERE cos0.id_role IN (:oldIdRole)
    AND NOT EXISTS (
        SELECT 'x'
        FROM gn_synthese.cor_observer_synthese AS cos1
        WHERE cos1.id_role = :newIdRole
            AND cos1.id_synthese = cos0.id_synthese
    ) ;

\echo 'Delete old id_role in "gn_synthese.cor_observer_synthese" when new id_role already exists'
DELETE FROM gn_synthese.cor_observer_synthese
WHERE id_role IN (:oldIdRole) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_inventor, id_digitiser in "gn_monitoring.t_base_sites"'

\echo '--> id_inventor'
UPDATE gn_monitoring.t_base_sites AS tbs0 SET
    id_inventor = :newIdRole
WHERE tbs0.id_inventor IN (:oldIdRole) ;

\echo '--> id_digitiser'
UPDATE gn_monitoring.t_base_sites AS tbs0 SET
    id_digitiser = :newIdRole
WHERE tbs0.id_digitiser IN (:oldIdRole) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_digitiser in "gn_monitoring.t_base_visits"'

UPDATE gn_monitoring.t_base_visits AS tbv0 SET
    id_digitiser = :newIdRole
WHERE tbv0.id_digitiser IN (:oldIdRole) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_role in "gn_monitoring.cor_visit_observer"'
UPDATE gn_monitoring.cor_visit_observer AS cvo0 SET
    id_role = :newIdRole
WHERE cvo0.id_role IN (:oldIdRole)
    AND NOT EXISTS (
        SELECT 'x'
        FROM gn_monitoring.cor_visit_observer AS cvo1
        WHERE cvo1.id_role = :newIdRole
            AND cvo1.id_base_visit = cvo0.id_base_visit
    ) ;

\echo 'Delete old id_role in "gn_monitoring.cor_visit_observer" when new id_role already exists'
DELETE FROM gn_monitoring.cor_visit_observer
WHERE id_role IN (:oldIdRole) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_role in "pr_conservation_strategy.t_assessment" if module exits'
DO $$
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'pr_conservation_strategy'
                AND table_name = 't_assessment'
        ) IS TRUE THEN
            RAISE NOTICE ' --> meta_create_by'
            UPDATE pr_conservation_strategy.t_assessment SET
                meta_create_by = :newIdRole
            WHERE meta_create_by IN (:oldIdRole) ;

            RAISE NOTICE ' --> meta_update_by'
            UPDATE pr_conservation_strategy.t_assessment SET
                meta_update_by = :newIdRole
            WHERE meta_update_by IN (:oldIdRole) ;
        ELSE
      		RAISE NOTICE ' Table "pr_conservation_strategy.t_assessment" not exists !' ;
        END IF ;
    END
$$ ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_role in "pr_priority_flora.cor_zp_obs" if module exits'
DO $$
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'pr_priority_flora'
                AND table_name = 'cor_zp_obs'
        ) IS TRUE THEN
            RAISE NOTICE ' Replace old id_role'
            UPDATE pr_priority_flora.cor_zp_obs AS czo0 SET
                id_role = :newIdRole
            WHERE czo0.id_role IN (:oldIdRole)
                AND NOT EXISTS (
                    SELECT 'x'
                    FROM pr_priority_flora.cor_zp_obs AS czo1
                    WHERE czo1.id_role = :newIdRole
                        AND czo1.id_zp = czo0.id_zp
                ) ;

            RAISE NOTICE ' Delete old id_role when new id_role already exists'
            DELETE FROM pr_priority_flora.cor_zp_obs
            WHERE id_role IN (:oldIdRole) ;
        ELSE
      		RAISE NOTICE ' Table "pr_priority_flora.cor_zp_obs" not exists !' ;
        END IF ;
    END
$$ ;


\echo '-------------------------------------------------------------------------------'
\echo 'Delete old t_roles entry'
DELETE FROM utilisateurs.t_roles
WHERE id_role IN (:oldIdRole) ;


\echo '-------------------------------------------------------------------------------'
\echo 'COMMIT if all is ok:'
COMMIT;
