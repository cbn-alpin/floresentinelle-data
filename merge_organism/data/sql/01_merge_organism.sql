-- Delete properly duplicate organisms.
-- Required rights: DB OWNER
-- GeoNature database compatibility : v2.9.2
--
-- This file contain variables "${newIdOrganism}" and "${oldIdOrganism}" which must be replaced
-- with "sed" before passing the updated content to Psql.
--
-- Use this script this way:
--    sed "s/\${oldIdOrganism}/<old_id_organism>/g" "~/data/merge_organism/data/sql/01_merge_organism.sql" | \
--    sed -e "s/\${newIdOrganism}/<new_id_organism>/g"  | \
--    psql -h localhost -U geonatadmin -d geonature2db \
--      -v 'oldIdOrganism=<old_id_organism>' -v 'newIdOrganism=<new_id_organism>' \
--      -f -
--
-- Lister les tables à traiter en ouvrant la liste des dépendances de la table bib_organismes avec
-- un éditeur de base de données.


BEGIN;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_parent in "utilisateurs.bib_organismes"'
UPDATE utilisateurs.bib_organismes  SET
    id_parent = :newIdOrganism
WHERE id_parent IN (:oldIdOrganism) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_organisme in "utilisateurs.t_roles"'
UPDATE utilisateurs.t_roles SET
    id_organisme = :newIdOrganism
WHERE id_organisme IN (:oldIdOrganism) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_organisme in "utilisateurs.temp_users"'
UPDATE utilisateurs.temp_users SET
    id_organisme = :newIdOrganism
WHERE id_organisme IN (:oldIdOrganism) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_organism in "gn_commons.t_parameters"'
UPDATE gn_commons.t_parameters SET
    id_organism = :newIdOrganism
WHERE id_organism IN (:oldIdOrganism) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_organism in "gn_synthese.defaults_nomenclatures_value"'
UPDATE gn_synthese.defaults_nomenclatures_value SET
    id_organism = :newIdOrganism
WHERE id_organism IN (:oldIdOrganism) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_organism in "ref_nomenclatures.defaults_nomenclatures_value"'
UPDATE ref_nomenclatures.defaults_nomenclatures_value SET
    id_organism = :newIdOrganism
WHERE id_organism IN (:oldIdOrganism) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_organism in "gn_meta.cor_dataset_actor"'
UPDATE gn_meta.cor_dataset_actor AS cda SET
    id_organism = :newIdOrganism
WHERE cda.id_organism IN (:oldIdOrganism)
    AND NOT EXISTS (
        SELECT 'x'
        FROM gn_meta.cor_dataset_actor AS cda1
        WHERE cda1.id_organism = :newIdOrganism
            AND cda1.id_dataset = cda.id_dataset
            AND cda1.id_nomenclature_actor_role = cda.id_nomenclature_actor_role
    ) ;

\echo 'Delete old id_organism in "gn_meta.cor_dataset_actor" when new id_organism already exists'
DELETE FROM gn_meta.cor_dataset_actor
WHERE id_organism IN (:oldIdOrganism) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_organism in "gn_meta.cor_acquisition_framework_actor"'
UPDATE gn_meta.cor_acquisition_framework_actor AS cafa SET
    id_organism = :newIdOrganism
WHERE cafa.id_organism IN (:oldIdOrganism)
    AND NOT EXISTS (
        SELECT 'x'
        FROM gn_meta.cor_acquisition_framework_actor AS cafa1
        WHERE cafa1.id_organism = :newIdOrganism
            AND cafa1.id_acquisition_framework = cafa.id_acquisition_framework
            AND cafa1.id_nomenclature_actor_role = cafa.id_nomenclature_actor_role
    ) ;

\echo 'Delete old id_organism in "gn_meta.cor_acquisition_framework_actor" when new id_organism already exists'
DELETE FROM gn_meta.cor_acquisition_framework_actor
WHERE id_organism IN (:oldIdOrganism) ;


\echo '-------------------------------------------------------------------------------'
\echo 'Replace old id_organism in "pr_conservation_strategy.cor_action_organism" if module exits'
DO $$
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'pr_conservation_strategy'
                AND table_name = 'cor_action_organism'
        ) IS TRUE THEN
            RAISE NOTICE ' Replace old id_organism' ;
            UPDATE pr_conservation_strategy.cor_action_organism AS cao0 SET
                id_organism = ${newIdOrganism}
            WHERE cao0.id_organism IN (${oldIdOrganism})
                AND NOT EXISTS (
                    SELECT 'x'
                    FROM pr_conservation_strategy.cor_action_organism AS cao1
                    WHERE cao1.id_organism = ${newIdOrganism}
                        AND cao1.id_action = cao0.id_action
                ) ;

            RAISE NOTICE ' Delete old id_organism when new id_organism already exists' ;
            DELETE FROM pr_conservation_strategy.cor_action_organism
            WHERE id_organism IN (${oldIdOrganism}) ;
        ELSE
      		RAISE NOTICE ' Table "pr_conservation_strategy.cor_action_organism" not exists !' ;
        END IF ;
    END
$$ ;


\echo '-------------------------------------------------------------------------------'
\echo 'Delete old bib_organismes entry'
DELETE FROM utilisateurs.bib_organismes
WHERE id_organisme IN (:oldIdOrganism) ;


\echo '-------------------------------------------------------------------------------'
\echo 'COMMIT if all is ok:'
COMMIT;
