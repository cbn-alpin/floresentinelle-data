BEGIN;


\echo '----------------------------------------------------------------------------'
\echo 'Utils functions'

CREATE OR REPLACE FUNCTION utilisateurs.get_id_organism_by_name(oname character varying)
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
    -- Function which return the id_organisme from an nom_organisme
    DECLARE idOrganism integer;

    BEGIN
        SELECT INTO idOrganism id_organisme
        FROM utilisateurs.bib_organismes AS bo
        WHERE bo.nom_organisme = oName ;

        RETURN idOrganism ;
    END;
$function$
;

CREATE OR REPLACE FUNCTION utilisateurs.get_id_organism_by_uuid(ouuid uuid)
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
    -- Function which return the id_organisme from an uuid_organisme
    DECLARE idOrganism integer;

    BEGIN
        SELECT INTO idOrganism id_organisme
        FROM utilisateurs.bib_organismes AS bo
        WHERE bo.uuid_organisme = oUuid ;

        RETURN idOrganism ;
    END;
$function$
;


CREATE OR REPLACE FUNCTION utilisateurs.get_id_group_by_name(groupname character varying)
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
    -- Function which return the id_role of a group by its name
    DECLARE idRole integer;

    BEGIN
        SELECT INTO idRole tr.id_role
        FROM utilisateurs.t_roles AS tr
        WHERE tr.nom_role = groupName
            AND tr.groupe = true ;

        RETURN idRole ;
    END;
$function$
;


\echo '----------------------------------------------------------------------------'
\echo 'Update uuid of users in common with PNE'

ALTER TABLE utilisateurs.t_roles DISABLE TRIGGER tri_modify_date_update_t_roles;

UPDATE utilisateurs.t_roles AS tr SET
    groupe = ptr.groupe,
    uuid_role = ptr.uuid_role,
    identifiant = ptr.identifiant,
    nom_role = ptr.nom_role,
    prenom_role = ptr.prenom_role,
    desc_role = ptr.desc_role,
    pass = ptr.pass,
    pass_plus = ptr.pass_plus,
    id_organisme = utilisateurs.get_id_organism_by_name('PNE'),
    remarques = ptr.remarques,
    active = ptr.active,
    champs_addi = json_build_object(
        'migrateOriginalInfos', json_build_object(
            'idRolePne', ptr.id_role
        )
    )::jsonb
FROM utilisateurs.pne_t_roles AS ptr
WHERE ptr.email = tr.email ;


\echo '----------------------------------------------------------------------------'
\echo 'Insert PNE users missing in Flore Sentinelle database'

-- Add missing PNE observers in pne_t_roles (not in Flore Sentinelle database)
INSERT INTO utilisateurs.pne_t_roles (
    uuid_role,
    groupe,
    identifiant,
    nom_role,
    prenom_role,
    champs_addi
)
VALUES (
    uuid_generate_v4(),
    FALSE,
    'am.lanquetuit',
    'Lanquetuit',
    'Anne-Marie',
    json_build_object(
        'migrateOriginalInfos', json_build_object(
            'idRolePne', '1145'
        )
    )::jsonb
)
;

-- Update 4 observers missing in pne_t_roles (already in cbna base) to get the 'idRolePne'
-- when adding data in 'cor_zp_ops'
UPDATE utilisateurs.t_roles AS tr
SET champs_addi = jsonb_set(
        champs_addi, '{migrateOriginalInfos}',
        jsonb_build_object('idRolePne', missing_observers.id_role),
        TRUE
    )
FROM (
        WITH pne_id_role AS (
            SELECT
                id_zp,
                UNNEST(string_to_array(ids_role,','))::int AS id_role,
                trim(UNNEST(string_to_array(nom_obs,','))) AS nom_obs,
                additional_data->'migrateOriginalInfos'->'indexZp' AS index_zp
            FROM pr_priority_flora.pne_t_zprospect
        )
        SELECT DISTINCT
            pir.id_role,
            pir.nom_obs
        FROM pne_id_role AS pir
            LEFT JOIN utilisateurs.pne_t_roles AS ptr
                ON ptr.id_role = pir.id_role
            LEFT JOIN pr_priority_flora.t_zprospect AS tz
                ON (
                    tz.additional_data->'migrateOriginalInfos'->'indexZp' = pir.index_zp
                    AND tz.additional_data->'migrateOriginalInfos'->>'nomOrganisme' = 'PN Ecrins'
                )
        WHERE tz.id_zp IS NULL
            AND ptr.id_role IS NULL
    ) AS missing_observers
WHERE trim(concat(
        lower(unaccent(tr.prenom_role)),
        lower(unaccent(
            regexp_replace(regexp_replace(tr.nom_role, '\s', '', 'g'), '\([^\(]*\)', '')
        ))
    )) = lower(unaccent(regexp_replace(missing_observers.nom_obs, '\s', '', 'g'))) ;

ALTER TABLE utilisateurs.t_roles DISABLE TRIGGER tri_modify_date_insert_t_roles ;

INSERT INTO utilisateurs.t_roles (
    groupe,
    uuid_role,
    identifiant,
    nom_role,
    prenom_role,
    desc_role,
    pass,
    pass_plus,
    email,
    id_organisme,
    remarques,
    active,
    champs_addi,
    date_insert,
    date_update
)
SELECT
    FALSE,
    ptr.uuid_role,
    ptr.identifiant,
    ptr.nom_role,
    ptr.prenom_role,
    ptr.desc_role,
    ptr.pass,
    ptr.pass_plus,
    ptr.email,
    utilisateurs.get_id_organism_by_name('PNE'),
    ptr.remarques,
    ptr.active,
    json_build_object(
        'migrateOriginalInfos', json_build_object(
            'idRolePne', ptr.id_role
        )
    )::jsonb,
    ptr.date_insert,
    ptr.date_update
FROM utilisateurs.pne_t_roles AS ptr
WHERE ptr.uuid_role NOT IN (
    SELECT uuid_role FROM utilisateurs.t_roles
) AND groupe = FALSE ;

ALTER TABLE utilisateurs.t_roles ENABLE TRIGGER tri_modify_date_update_t_roles ;
ALTER TABLE utilisateurs.t_roles ENABLE TRIGGER tri_modify_date_insert_t_roles ;


\echo '----------------------------------------------------------------------------'
\echo 'Insert PNE ZP missing in Flore Sentinelle database'

ALTER TABLE pr_priority_flora.t_zprospect DISABLE TRIGGER tri_change_meta_dates_zp;

INSERT INTO pr_priority_flora.t_zprospect (
    uuid_zp,
    cd_nom,
    date_min,
    date_max,
    geom_4326,
    initial_insert,
    topo_valid,
    additional_data,
    meta_create_date,
    meta_update_date
)
SELECT
    ptz.uuid_zp,
    ptz.cd_nom,
    ptz.date_min,
    ptz.date_max,
    ptz.geom_4326,
    ptz.initial_insert,
    ptz.topo_valid,
    ptz.additional_data,
    ptz.meta_create_date,
    ptz.meta_update_date
FROM pr_priority_flora.pne_t_zprospect AS ptz
    LEFT JOIN pr_priority_flora.t_zprospect AS tz
        ON (
            tz.additional_data->'migrateOriginalInfos'->'indexZp' =
                ptz.additional_data->'migrateOriginalInfos'->'indexZp'
            AND tz.additional_data->'migrateOriginalInfos'->>'nomOrganisme' = 'PN Ecrins'
        )
WHERE tz.id_zp IS NULL
;

ALTER TABLE pr_priority_flora.t_zprospect ENABLE TRIGGER tri_change_meta_dates_zp;


\echo '----------------------------------------------------------------------------'
\echo 'Insert PNE AP missing in Flore Sentinelle database'

ALTER TABLE pr_priority_flora.t_apresence DISABLE TRIGGER tri_change_meta_dates_ap;

-- Only AP of new PNE ZP will join by UUID ZP !
INSERT INTO pr_priority_flora.t_apresence (
    uuid_ap,
    id_zp,
    geom_4326,
    area,
    altitude_min,
    altitude_max,
    id_nomenclature_incline,
    id_nomenclature_habitat,
    favorable_status_percent,
    id_nomenclature_threat_level,
    id_nomenclature_phenology,
    id_nomenclature_frequency_method,
    frequency,
    id_nomenclature_counting,
    total_min,
    total_max,
    comment,
    topo_valid,
    additional_data,
    meta_create_date,
    meta_update_date
)
SELECT
    pta.uuid_ap,
    tz.id_zp,
    pta.geom_4326,
    pta.area,
    pta.altitude_min,
    pta.altitude_max,
    ref_nomenclatures.get_id_nomenclature('INCLINE_TYPE', pta.code_nomenc_incline::varchar)
        AS id_nomenclature_incline,
    ref_nomenclatures.get_id_nomenclature('HABITAT_STATUS', pta.code_nomenc_habitat::varchar)
        AS id_nomenclature_habitat,
    pta.favorable_status_percent,
    ref_nomenclatures.get_id_nomenclature('THREAT_LEVEL', pta.code_nomenc_threat_level::varchar)
        AS id_nomenclature_threat_level,
    ref_nomenclatures.get_id_nomenclature('PHENOLOGY_TYPE', pta.code_nomenc_phenology::varchar)
        AS id_nomenclature_phenology,
    ref_nomenclatures.get_id_nomenclature('FREQUENCY_METHOD', pta.code_nomenc_frequency_method::varchar)
        AS id_nomenclature_frequency_method,
    pta.frequency,
    ref_nomenclatures.get_id_nomenclature('COUNTING_TYPE', pta.code_nomenc_counting::varchar)
        AS id_nomenclature_counting,
    pta.total_min,
    pta.total_max,
    pta.comment,
    pta.topo_valid,
    pta.additional_data,
    pta.meta_create_date,
    pta.meta_update_date
FROM pr_priority_flora.pne_t_apresence AS pta
    JOIN pr_priority_flora.pne_t_zprospect AS ptz
        ON ptz.id_zp = pta.id_zp
    JOIN pr_priority_flora.t_zprospect AS tz
        ON tz.uuid_zp = ptz.uuid_zp ;

ALTER TABLE pr_priority_flora.t_apresence ENABLE TRIGGER tri_change_meta_dates_ap ;


\echo '----------------------------------------------------------------------------'
\echo 'Insert missing data in cor_zp_obs for PNE ZP in common with Flore Sentinelle database'

WITH missing_links AS (
    SELECT
        tz.id_zp,
        UNNEST(string_to_array(lower(unaccent(regexp_replace(ptz.nom_obs, '\s', '', 'g'))),','))
            AS nom_obs
    FROM pr_priority_flora.pne_t_zprospect AS ptz
        JOIN pr_priority_flora.t_zprospect AS tz
            ON (
                tz.additional_data->'migrateOriginalInfos'->'indexZp' =
                    ptz.additional_data->'migrateOriginalInfos'->'indexZp'
                AND tz.additional_data->'migrateOriginalInfos'->>'nomOrganisme' = 'PN Ecrins'
            )
    EXCEPT
    SELECT
        id_zp,
        trim(concat(
            lower(unaccent(tr.prenom_role)),
            lower(unaccent(
                regexp_replace(regexp_replace(tr.nom_role, '\s', '', 'g'), '\([^\(]*\)', '')
            ))
        ))
    FROM pr_priority_flora.cor_zp_obs AS czo
        JOIN utilisateurs.t_roles AS tr
            ON tr.id_role = czo.id_role
)
INSERT INTO pr_priority_flora.cor_zp_obs (
    id_zp,
    id_role
)
SELECT
    ml.id_zp,
    tr.id_role
FROM missing_links AS ml
    JOIN utilisateurs.t_roles AS tr
        ON trim(concat(
            lower(unaccent(tr.prenom_role)),
            lower(unaccent(
                regexp_replace(regexp_replace(tr.nom_role, '\s', '', 'g'), '\([^\(]*\)', '')
            ))
        )) = ml.nom_obs
;


\echo '----------------------------------------------------------------------------'
\echo 'Insert data in cor_zp_obs for new ZP added from PNE database'

 WITH pne_zp_role AS (
    SELECT
        uuid_zp,
        trim(UNNEST(string_to_array(ids_role,','))) AS id_role
    FROM pr_priority_flora.pne_t_zprospect
 )
INSERT INTO pr_priority_flora.cor_zp_obs (
    id_zp,
    id_role
)
SELECT
    tz.id_zp,
    tr.id_role::int
FROM pr_priority_flora.t_zprospect AS tz
    JOIN pne_zp_role AS pzr
        ON pzr.uuid_zp = tz.uuid_zp
    JOIN utilisateurs.t_roles AS tr
        ON tr.champs_addi->'migrateOriginalInfos'->>'idRolePne' = pzr.id_role ;


\echo '----------------------------------------------------------------------------'
\echo 'Insert data in cor_ap_perturbation for new AP added from PNE database'

 CREATE TEMP TABLE corresponding_perturbations (
     pne_perturbation varchar,
     sinp_nomenclature varchar
 )
 ;

 INSERT INTO corresponding_perturbations (
     pne_perturbation,
     sinp_nomenclature
 )
 VALUES
     ('Aval','Aam'),
     ('AvalAp','Aam'),
     ('Béto','Beg'),
     ('Bois','Bcl'),
     ('Cura','Cur'),
     ('Elag','Ela'),
     ('Eros','Evs'),
     ('Pâtu','Pat'),
     ('Piét','Psa'),
     ('Prod','Prp'),
     ('Sang','San'),
     ('Sape','Sbe'),
     ('Terr','Ter'),
     ('Véhi','Veh')
 ;

WITH pne_ap_perturbation AS (
    SELECT
        ta.id_ap,
        trim(UNNEST(string_to_array(pta.perturbation,','))) AS perturbation
    FROM pr_priority_flora.t_apresence AS ta
        JOIN pr_priority_flora.pne_t_apresence AS pta
            ON pta.uuid_ap = ta.uuid_ap
)
INSERT INTO pr_priority_flora.cor_ap_perturbation (
    id_ap,
    id_nomenclature
)
SELECT
     pap.id_ap,
     tn.id_nomenclature
FROM pne_ap_perturbation AS pap
    JOIN ref_nomenclatures.t_nomenclatures AS tn
        ON tn.cd_nomenclature = pap.perturbation
UNION
SELECT
     pap.id_ap,
     tn.id_nomenclature
FROM pne_ap_perturbation AS pap
    JOIN corresponding_perturbations AS cp
        ON cp.pne_perturbation = pap.perturbation
    JOIN ref_nomenclatures.t_nomenclatures AS tn
        ON tn.cd_nomenclature = cp.sinp_nomenclature ;


\echo '----------------------------------------------------------------------------'
\echo 'Insert data in cor_ap_physiognomy for new AP added from PNE database'

WITH pne_ap_physiognomy AS (
    SELECT
        ta.id_ap,
        trim(UNNEST(string_to_array(pta.physionomy,','))) AS physiognomy
    FROM pr_priority_flora.t_apresence AS ta
        JOIN pr_priority_flora.pne_t_apresence AS pta
            ON pta.uuid_ap = ta.uuid_ap
)
INSERT INTO pr_priority_flora.cor_ap_physiognomy (
    id_ap,
    id_nomenclature
)
SELECT DISTINCT
    pap.id_ap,
    tn.id_nomenclature
FROM pne_ap_physiognomy AS pap
    JOIN ref_nomenclatures.t_nomenclatures AS tn
        ON tn.cd_nomenclature = pap.physiognomy ;

\echo '----------------------------------------------------------------------------'
\echo 'Insert PNE users in cor_roles'

INSERT INTO utilisateurs.cor_roles
    SELECT
        utilisateurs.get_id_group_by_name('Utilisateurs Flore Sentinelle'),
        tr.id_role
    FROM utilisateurs.t_roles AS tr
        LEFT JOIN utilisateurs.cor_roles AS cr
            ON cr.id_role_utilisateur = tr.id_role
    WHERE id_organisme = utilisateurs.get_id_organism_by_name('PNE')
        AND cr.id_role_groupe IS NULL
        AND COALESCE(tr.pass, tr.pass_plus) IS NOT NULL
        AND tr.active IS TRUE ;

\echo '----------------------------------------------------------------------------'
\echo 'Insert PNE observers in cor_roles'

INSERT INTO utilisateurs.cor_roles
    SELECT
        utilisateurs.get_id_group_by_name('Observateurs Flore Sentinelle'),
        tr.id_role
    FROM utilisateurs.t_roles AS tr
        LEFT JOIN utilisateurs.cor_roles AS cr
            ON cr.id_role_utilisateur = tr.id_role
    WHERE id_organisme = utilisateurs.get_id_organism_by_name('PNE')
        AND cr.id_role_groupe IS NULL
        AND COALESCE(tr.pass, tr.pass_plus) IS NULL
        AND tr.active IS TRUE ;

\echo '-------------------------------------------------------------------------------'
\echo 'COMMIT if all is ok:'
COMMIT ;
