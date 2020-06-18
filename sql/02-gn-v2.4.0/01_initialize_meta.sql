BEGIN;

\echo '----------------------------------------------------------------------------'
\echo 'Disable OccTax module'
UPDATE gn_commons.t_modules
SET
    module_label = 'OccTax',
    module_picto = 'fa-map-marker',
    module_desc = 'Module de saisie d''observations faune et flore.'
    active_frontend = False,
    active_backend = False
WHERE module_code = 'OCCTAX' ;

\echo '----------------------------------------------------------------------------'
\echo 'Update SFT module'
UPDATE gn_commons.t_modules
SET
    module_label = 'S. Flore Territoire',
    module_picto = 'fa-leaf',
    module_desc = 'Module de Suivi de la Flore d''un Territoire',
WHERE module_code = 'SFT' ;

\echo '----------------------------------------------------------------------------'
\echo 'Update SHT module'
UPDATE gn_commons.t_modules
SET
    module_label = 'S. Habitat Territoire',
    module_picto = 'fa-map',
    module_desc = 'Module de Suivi des Habitats d''un Territoire',
WHERE module_code = 'SHT' ;

\echo '----------------------------------------------------------------------------'
\echo 'Create acquisition framework for Flore Sentinelle Network'
INSERT INTO gn_meta.t_acquisition_frameworks (
    unique_acquisition_framework_id,
    acquisition_framework_name,
    acquisition_framework_desc,
    id_nomenclature_territorial_level,
    territory_desc,
    keywords,
    id_nomenclature_financing_type,
    target_description,
    ecologic_or_geologic_target,
    acquisition_framework_parent_id,
    is_parent,
    acquisition_framework_start_date,
    acquisition_framework_end_date
) VALUES (
    '28917b9b-2e17-4bbe-8207-1254a9748844',
    'Suivis Réseau Flore Sentinelle',
    'Ensemble des suivis réalisés dans les Alpes françaises dans le cadre du réseau Flore Sentinelle.',
    357,
    'Alpes française.',
    'Suivi, Alpes, France, Flore, Réseau.',
    393,
    'Identifier et comprendre les dynamiques démographiques des espèces végétales et des habitats, sentinelles pour le suivi des changements globaux dans les Alpes françaises.',
    'Flore',
    NULL,
    false,
    '2009-01-01',
    NULL
) ;

\echo '----------------------------------------------------------------------------'
\echo 'Insert link between acquisition framework and actor'
INSERT INTO gn_meta.cor_acquisition_framework_actor (
    id_acquisition_framework,
    id_role,
    id_organism,
    id_nomenclature_actor_role
) VALUES (
    1,
    NULL,
    1,
    367
) ;

\echo '----------------------------------------------------------------------------'
\echo 'Insert link between acquisition framework and objectifs'
INSERT INTO gn_meta.cor_acquisition_framework_objectif (
    id_acquisition_framework,
    id_nomenclature_objectif
) VALUES
    (1, 363),
    (1, 364),
    (1, 365) ;

\echo '----------------------------------------------------------------------------'
\echo 'Insert link between acquisition framework and SINP "volet"'
INSERT INTO gn_meta.cor_acquisition_framework_voletsinp (
    id_acquisition_framework,
    id_nomenclature_voletsinp
) VALUES
    (1, 400) ;

\echo '----------------------------------------------------------------------------'
\echo 'Create datasets in Flore Sentinelle acquisition framework'
INSERT INTO gn_meta.t_datasets (
    unique_dataset_id,
    id_acquisition_framework,
    dataset_name,
    dataset_shortname,
    dataset_desc,
    id_nomenclature_data_type,
    keywords,
    marine_domain,
    terrestrial_domain,
    id_nomenclature_dataset_objectif,
    bbox_west,
    bbox_east,
    bbox_south,
    bbox_north,
    id_nomenclature_collecting_method,
    id_nomenclature_data_origin,
    id_nomenclature_source_status,
    id_nomenclature_resource_type,
    active,
    validable
) VALUES (
    'b5359d75-6ea8-4487-a3e2-24090599704a',
    1,
    'Suivis Habitat Territoire',
    'SHT',
    'Données acquises dans le cadre du protocole Suivi Habitat Territoire.',
    325,
    NULL,
    false,
    true,
    438,
    NULL,
    NULL,
    NULL,
    NULL,
    404,
    78,
    75,
    323,
    true,
    true
),(
    'e4af0284-740d-42d3-8052-fd2912f07d5b',
    1,
    'Suivis Flore Territoire',
    'SFT',
    'Données acquises dans le cadre du protocole Suivi Flore Territoire.',
    325,
    NULL,
    false,
    true,
    436,
    NULL,
    NULL,
    NULL,
    NULL,
    404,
    78,
    75,
    323,
    true,
    true
) ;

\echo '----------------------------------------------------------------------------'
\echo 'Insert link between datasets and actors'
INSERT INTO gn_meta.cor_dataset_actor (
    id_dataset,
    id_role,
    id_organism,
    id_nomenclature_actor_role
) VALUES
    (1, NULL, 1, 367),
    (2, NULL, 1, 367) ;

\echo '----------------------------------------------------------------------------'
\echo 'Insert link between datasets and modules'
INSERT INTO gn_commons.cor_module_dataset (
    id_module,id_dataset
) VALUES
    (5, 1),
    (6, 2) ;

-- ----------------------------------------------------------------------------
COMMIT;
