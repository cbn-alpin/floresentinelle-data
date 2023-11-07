-- Migrate Liparis Project data from old rcfaa appli_flore database to new GeoNature v2 database.

BEGIN;


\echo '----------------------------------------------------------------------------'
\echo 'Migrate Liparis project zoning...'
UPDATE pr_priority_flora.t_zprospect AS zp SET
    additional_data = jsonb_set(
        	zp.additional_data,
            '{migrateOriginalInfos,liparisProject}',
            jsonb_build_object('zonages', z.zonings),
            true -- create the field if missing
    	)
FROM (
        SELECT
            zozp.indexzp AS id_zp,
            jsonb_agg(jsonb_build_object(zo.idzonage, zo.libelle)) AS zonings
        FROM liparis.zonages_zp AS zozp
            JOIN liparis.zonages AS zo
                ON zozp.idzonage = zo.idzonage
        GROUP BY zozp.indexzp
    ) AS z
WHERE (zp.additional_data #>> '{migrateOriginalInfos,indexZp}')::int = z.id_zp ;


\echo '----------------------------------------------------------------------------'
\echo 'Migrate Liparis project management actions...'
UPDATE pr_priority_flora.t_zprospect AS zp SET
    additional_data = jsonb_set(
        	zp.additional_data,
            '{migrateOriginalInfos,liparisProject}',
            (
                additional_data #> '{migrateOriginalInfos,liparisProject}'
                || jsonb_build_object('actionsGestion', ma.management_actions)
            ),
            true -- create the field if missing
    	)
FROM (
        SELECT
            tagz.indexzp AS id_zp,
            jsonb_agg(jsonb_build_object(tag.idtypeaction, tag.libelle)) AS management_actions
        FROM liparis.types_actions_gestion_zp AS tagz
            JOIN liparis.types_actions_gestion AS tag
                ON tagz.idtypeaction = tag.idtypeaction
        GROUP BY tagz.indexzp
    )  AS ma
WHERE (zp.additional_data #>> '{migrateOriginalInfos,indexZp}')::int = ma.id_zp ;


\echo '----------------------------------------------------------------------------'
\echo 'COMMIT if all goes well !'
COMMIT;
