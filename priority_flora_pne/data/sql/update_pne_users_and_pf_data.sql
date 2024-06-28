BEGIN;

\echo '----------------------------------------------------------------------------'
\echo 'Update uuid of users in common with PNE'

UPDATE utilisateurs.t_roles AS tr
SET 
	groupe = ptr.groupe,
	uuid_role = ptr.uuid_role,
	identifiant = ptr.identifiant,
	nom_role = ptr.nom_role,
	prenom_role = ptr.prenom_role,
	desc_role = ptr.desc_role,
	pass = ptr.pass,
	pass_plus = ptr.pass_plus,
	id_organisme = ptr.id_organisme,
	remarques = ptr.remarques,
	active = ptr.active,
	champs_addi = ptr.champs_addi 
FROM 
	utilisateurs.pne_t_roles ptr
WHERE ptr.email = tr.email
;


\echo '----------------------------------------------------------------------------'
\echo 'Insert PNE users missing in CBNA base'

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
	champs_addi
)
SELECT
	ptr.groupe,
	ptr.uuid_role,
	ptr.identifiant,
	ptr.nom_role,
	ptr.prenom_role,
	ptr.desc_role,
	ptr.pass,
	ptr.pass_plus,
	ptr.email,
	ptr.id_organisme,
	ptr.remarques,
	ptr.active,
	ptr.champs_addi
FROM
	utilisateurs.pne_t_roles ptr
WHERE ptr.uuid_role NOT IN (
	SELECT uuid_role FROM utilisateurs.t_roles
)
;


\echo '----------------------------------------------------------------------------'
\echo 'Update ZP in common with PNE'

UPDATE pr_priority_flora.t_zprospect AS tz
SET
	uuid_zp = ptz.uuid_zp,
	cd_nom = ptz.cd_nom,
	date_min = ptz.date_min,
	date_max = ptz.date_max,
	geom_local = ptz.geom_local,
	geom_4326 = ptz.geom_4326,
	geom_point_4326 = ptz.geom_point_4326,
	area = ptz.area,
	initial_insert = ptz.initial_insert,
	topo_valid = ptz.topo_valid,
	additional_data = ptz.additional_data,
	meta_create_date = ptz.meta_create_date,
	meta_update_date = ptz.meta_update_date
FROM pr_priority_flora.pne_t_zprospect AS ptz
WHERE tz.additional_data->'migrateOriginalInfos'->'indexZp' = ptz.additional_data->'migrateOriginalInfos'->'indexZp'
	AND tz.additional_data->'migrateOriginalInfos'->>'nomOrganisme' = 'PN Ecrins'
;


\echo '----------------------------------------------------------------------------'
\echo 'Insert PNE ZP missing in CBNA'

INSERT INTO pr_priority_flora.t_zprospect (
	uuid_zp,
	cd_nom,
	date_min,
	date_max,
	geom_local,
	geom_4326,
	geom_point_4326,
	area,
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
	ptz.geom_local,
	ptz.geom_4326,
	ptz.geom_point_4326,
	ptz.area,
	ptz.initial_insert,
	ptz.topo_valid,
	ptz.additional_data,
    ptz.meta_create_date,
    ptz.meta_update_date
FROM pr_priority_flora.pne_t_zprospect AS ptz
WHERE ptz.uuid_zp NOT IN (SELECT uuid_zp FROM pr_priority_flora.t_zprospect)
;


\echo '----------------------------------------------------------------------------'
\echo 'Update AP in common with PNE'

UPDATE pr_priority_flora.t_apresence AS ta
SET 
	uuid_ap = pta.uuid_ap,
	id_zp = tz.id_zp,
	geom_local = pta.geom_local,
	geom_4326 = pta.geom_4326,
	geom_point_4326 = pta.geom_point_4326,
	area = pta.area,
	altitude_min = pta.altitude_min,
	altitude_max = pta.altitude_max,
	id_nomenclature_incline = ref_nomenclatures.get_id_nomenclature('INCLINE_TYPE', pta.code_nomenc_incline::varchar),
	id_nomenclature_habitat = ref_nomenclatures.get_id_nomenclature('HABITAT_STATUS', pta.code_nomenc_habitat::varchar),
	favorable_status_percent = pta.favorable_status_percent,
	id_nomenclature_threat_level = ref_nomenclatures.get_id_nomenclature('THREAT_LEVEL', pta.code_nomenc_threat_level::varchar),
	id_nomenclature_phenology = ref_nomenclatures.get_id_nomenclature('PHENOLOGY_TYPE', pta.code_nomenc_phenology::varchar),
	id_nomenclature_frequency_method = ref_nomenclatures.get_id_nomenclature('FREQUENCY_METHOD', pta.code_nomenc_frequency_method::varchar), 
	frequency = pta.frequency,
	id_nomenclature_counting = ref_nomenclatures.get_id_nomenclature('COUNTING_TYPE', pta.code_nomenc_counting::varchar),
	total_min = pta.total_min,
	total_max = pta.total_max,
	comment = pta.comment,
	topo_valid = pta.topo_valid,
	additional_data = pta.additional_data,
	meta_create_date = pta.meta_create_date,
	meta_update_date = pta.meta_update_date
FROM pr_priority_flora.pne_t_zprospect AS ptz
	JOIN pr_priority_flora.pne_t_apresence AS pta
			ON ptz.id_zp = pta.id_zp
	LEFT JOIN pr_priority_flora.t_zprospect AS tz
		ON tz.uuid_zp = ptz.uuid_zp
WHERE ta.additional_data->'migrateOriginalInfos'->'indexAp' = pta.additional_data->'migrateOriginalInfos'->'indexAp'
;


\echo '----------------------------------------------------------------------------'
\echo 'Insert PNE AP missing in CBNA'

INSERT INTO pr_priority_flora.t_apresence (
	uuid_ap,
	id_zp,
	geom_local,
	geom_4326,
	geom_point_4326,
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
	pta.geom_local,
	pta.geom_4326,
	pta.geom_point_4326,
	pta.area,
	pta.altitude_min,
	pta.altitude_max,
	ref_nomenclatures.get_id_nomenclature('INCLINE_TYPE', pta.code_nomenc_incline::varchar) AS id_nomenclature_incline ,
	ref_nomenclatures.get_id_nomenclature('HABITAT_STATUS', pta.code_nomenc_habitat::varchar) AS id_nomenclature_habitat ,
	pta.favorable_status_percent,
	ref_nomenclatures.get_id_nomenclature('THREAT_LEVEL', pta.code_nomenc_threat_level::varchar) AS id_nomenclature_threat_level,
	ref_nomenclatures.get_id_nomenclature('PHENOLOGY_TYPE', pta.code_nomenc_phenology::varchar) AS id_nomenclature_phenology,
	ref_nomenclatures.get_id_nomenclature('FREQUENCY_METHOD', pta.code_nomenc_frequency_method::varchar) AS id_nomenclature_frequency_method,
	pta.frequency ,
	ref_nomenclatures.get_id_nomenclature('COUNTING_TYPE', pta.code_nomenc_counting::varchar) AS id_nomenclature_counting,
	pta.total_min ,
	pta.total_max ,
	pta.comment ,
	pta.topo_valid ,
	pta.additional_data,
    pta.meta_create_date,
    pta.meta_update_date
FROM pr_priority_flora.pne_t_apresence pta
JOIN pr_priority_flora.pne_t_zprospect ptz
	ON ptz.id_zp = pta.id_zp
JOIN pr_priority_flora.t_zprospect AS tz
	ON tz.uuid_zp = ptz.uuid_zp
WHERE pta.uuid_ap NOT IN (SELECT uuid_ap FROM pr_priority_flora.t_apresence)
;


\echo '----------------------------------------------------------------------------'
\echo 'Insert data in cor_zp_obs for new ZP added from PNE database'

-- With pne_t_roles link
WITH pne_id_role AS (
	SELECT 
		ptz.uuid_zp,
		tz.id_zp,
		UNNEST(string_to_array(ptz.ids_role,','))::int AS id_role
	FROM pr_priority_flora.pne_t_zprospect ptz
	JOIN pr_priority_flora.t_zprospect tz 
		ON ptz.uuid_zp = tz.uuid_zp
)
INSERT INTO pr_priority_flora.cor_zp_obs (
	id_zp,
	id_role
)
SELECT 
	tz.id_zp,
	tr.id_role
FROM pr_priority_flora.pne_t_zprospect ptz 
JOIN pr_priority_flora.t_zprospect tz 
	ON tz.uuid_zp = ptz.uuid_zp
JOIN pne_id_role pir
	ON pir.id_zp = tz.id_zp
JOIN utilisateurs.pne_t_roles ptr 
	ON ptr.id_role = pir.id_role
JOIN utilisateurs.t_roles tr 
	ON tr.uuid_role = ptr.uuid_role 
WHERE tz.id_zp NOT IN (SELECT id_zp FROM pr_priority_flora.cor_zp_obs czo)
;

-- Without pne_t_roles link
WITH pne_obs AS (
	SELECT 
		ptz.uuid_zp,
		UNNEST(string_to_array(ptz.nom_obs,',')) AS nom_obs
	FROM pr_priority_flora.pne_t_zprospect ptz 
)
INSERT INTO pr_priority_flora.cor_zp_obs (
	id_zp,
	id_role
)
SELECT 
	tz.id_zp,
	tr.id_role
FROM pr_priority_flora.t_zprospect tz 
JOIN pne_obs po
	ON po.uuid_zp = tz.uuid_zp
JOIN utilisateurs.t_roles tr 
	ON concat(lower(tr.prenom_role), ' ',lower(tr.nom_role)) = lower(po.nom_obs)
WHERE tz.id_zp NOT IN (SELECT id_zp FROM pr_priority_flora.cor_zp_obs)
	AND tz.uuid_zp IN (SELECT uuid_zp FROM pr_priority_flora.pne_t_zprospect)

;

COMMIT ;
