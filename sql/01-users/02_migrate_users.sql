BEGIN;

\echo '----------------------------------------------------------------------------'
\echo 'Cleaning "utilisateurs" schema --> truncate tables'
TRUNCATE utilisateurs.t_roles CASCADE ;
--NOTICE:  truncate cascades to table "cor_roles"
--NOTICE:  truncate cascades to table "cor_role_droit_application"
--NOTICE:  truncate cascades to table "cor_acquisition_framework_actor"
--NOTICE:  truncate cascades to table "cor_dataset_actor"
--NOTICE:  truncate cascades to table "t_validations"
--NOTICE:  truncate cascades to table "synthese"
--NOTICE:  truncate cascades to table "t_base_sites"
--NOTICE:  truncate cascades to table "t_base_visits"
--NOTICE:  truncate cascades to table "cor_visit_observer"
--NOTICE:  truncate cascades to table "t_releves_occtax"
--NOTICE:  truncate cascades to table "cor_role_releves_occtax"
--NOTICE:  truncate cascades to table "cor_area_synthese"
--NOTICE:  truncate cascades to table "cor_site_application"
--NOTICE:  truncate cascades to table "cor_site_area"
--NOTICE:  truncate cascades to table "t_occurrences_occtax"
--NOTICE:  truncate cascades to table "cor_counting_occtax"

TRUNCATE utilisateurs.t_listes CASCADE ;
--NOTICE:  truncate cascades to table "cor_role_liste"

TRUNCATE utilisateurs.t_applications CASCADE ;
--NOTICE:  truncate cascades to table "cor_profil_for_app"
--NOTICE:  truncate cascades to table "cor_role_app_profil"
--NOTICE:  truncate cascades to table "cor_application_nomenclature"

TRUNCATE utilisateurs.cor_role_app_profil CASCADE ;

DELETE FROM utilisateurs.bib_organismes WHERE id_organisme != 0 ;

TRUNCATE utilisateurs.cor_profil_for_app CASCADE ;

TRUNCATE utilisateurs.cor_role_liste CASCADE ;

TRUNCATE utilisateurs.cor_roles CASCADE ;


\echo '----------------------------------------------------------------------------'
\echo 'Insert organisms'
INSERT INTO utilisateurs.bib_organismes (
        id_organisme,
        nom_organisme,
        adresse_organisme,
        cp_organisme,
        ville_organisme,
        tel_organisme,
        fax_organisme,
        email_organisme
    )
    SELECT DISTINCT
        o.id_organisme,
        o.nom_organisme,
        nullif(o.adresse_organisme, ''),
        nullif(o.cp_organisme, ''),
        nullif(upper(o.ville_organisme), ''),
        regexp_replace(
            replace(
                nullif(
                    trim(both from o.tel_organisme),
                    ''
                ),
                '.',
                ' '
            ),
            '^([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})$',
            '\1 \2 \3 \4 \5'
        ),
        regexp_replace(
            replace(
                nullif(
                    trim(both from o.fax_organisme),
                    ''
                ),
                '.',
                ' '
            ),
            '^([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})$',
            '\1 \2 \3 \4 \5'
        ),
        nullif(o.email_organisme, '')
    FROM migrate_v1_utilisateurs.bib_organismes AS o
        JOIN migrate_v1_utilisateurs.t_roles AS tr
            ON (tr.id_organisme = o.id_organisme)
        JOIN migrate_v1_utilisateurs.cor_roles AS cr
            ON (tr.id_role = cr.id_role_utilisateur)
    WHERE cr.id_role_groupe IN (10000, 10001)
        AND NOT EXISTS (
            SELECT 'X'
            FROM utilisateurs.bib_organismes AS bo
            WHERE upper(bo.nom_organisme) = upper(o.nom_organisme)
                OR bo.id_organisme = o.id_organisme
        )
    ORDER BY o.id_organisme ASC ;


\echo '----------------------------------------------------------------------------'
\echo 'Clean email column in "bib_organismes" table'
UPDATE utilisateurs.bib_organismes
SET url_organisme = email_organisme,
    email_organisme = NULL
WHERE id_organisme = 41 ;


\echo '----------------------------------------------------------------------------'
\echo 'Refresh "bib_organismes" table sequence (=auto-increment)'
SELECT setval(
    'utilisateurs.bib_organismes_id_organisme_seq',
    (SELECT max(id_organisme) + 1 FROM utilisateurs.bib_organismes),
    true
) ;


\echo '----------------------------------------------------------------------------'
\echo 'Insert roles'
INSERT INTO utilisateurs.t_roles (
        id_role,
        groupe,
        identifiant,
        nom_role,
        prenom_role,
        desc_role,
        pass,
        email,
        id_organisme,
        remarques,
        active
    )
    SELECT DISTINCT
        r.id_role,
        r.groupe,
        nullif(r.identifiant, ''),
        nullif(upper(r.nom_role), ''),
        nullif(r.prenom_role, ''),
        nullif(r.desc_role, ''),
        nullif(r.pass, ''),
        nullif(r.email, ''),
        r.id_organisme,
        'Imported from GeoNature v1.',
        True
    FROM migrate_v1_utilisateurs.t_roles AS r
        LEFT JOIN migrate_v1_utilisateurs.cor_roles AS cr
            ON (r.id_role = cr.id_role_utilisateur)
    WHERE ( cr.id_role_groupe IN (10000, 10001) OR r.id_role IN (10000,10001) )
        AND NOT EXISTS (
            SELECT 'X'
            FROM utilisateurs.t_roles AS u
            WHERE (
                    upper(u.nom_role) = upper(r.nom_role)
                    AND upper(u.prenom_role) = upper(r.prenom_role)
                ) OR u.id_role = r.id_role
        )
    ORDER BY r.id_role ASC ;


\echo '----------------------------------------------------------------------------'
\echo 'Insert more infos in t_roles JSON column'
UPDATE utilisateurs.t_roles AS r
SET champs_addi = json_build_object(
        'migrateOriginalInfos', json_build_object(
            'dateInsert', mr.date_insert,
            'dateUpdate', mr.date_update,
            'lastAccess', mr.dernieracces,
            'roleId', mr.id_role,
            'organismId', mr.id_organisme,
            'organismName', mbo.nom_organisme
        )
    )
FROM migrate_v1_utilisateurs.t_roles AS mr
	LEFT JOIN migrate_v1_utilisateurs.bib_organismes AS mbo
            ON (mr.id_organisme = mbo.id_organisme)
WHERE r.id_role = mr.id_role ;


\echo '----------------------------------------------------------------------------'
\echo 'Create users UUID if not set'
UPDATE utilisateurs.t_roles
SET uuid_role = uuid_generate_v4()
WHERE uuid_role IS NULL ;


\echo '----------------------------------------------------------------------------'
\echo 'Refresh "t_roles" table sequence (=auto-increment)'
SELECT setval(
    'utilisateurs.t_roles_id_role_seq',
    (SELECT max(id_role) + 1 FROM utilisateurs.t_roles),
    true
) ;


\echo '----------------------------------------------------------------------------'
\echo 'Create list "Observateurs Flore Sentinelle"'
INSERT INTO utilisateurs.t_listes (id_liste, code_liste, nom_liste, desc_liste)
VALUES (
    1,
    'OFS',
    'Observateurs Flore Sentinelle',
    'Liste des personnes ayant participées ou succeptibles de participer aux suivis dans le cadre de Flore Sentinelle.'
) ;


\echo '----------------------------------------------------------------------------'
\echo 'Link observers to list "Observateurs Flore Sentinelle"'
INSERT INTO utilisateurs.cor_role_liste (id_role, id_liste)
VALUES
    (10000, 1),
    (10001, 1)
;


\echo '----------------------------------------------------------------------------'
\echo 'Link users with password to group 10000/GP_ACCES_APPLICATION'
INSERT INTO utilisateurs.cor_roles (id_role_groupe, id_role_utilisateur)
    SELECT 10000, id_role
    FROM utilisateurs.t_roles
    WHERE groupe = False
        AND ( pass IS NOT NULL OR pass != '' ) ;


\echo '----------------------------------------------------------------------------'
\echo 'Link users with no password to group 10001/GP_MENUS_DEROULANT'
INSERT INTO utilisateurs.cor_roles (id_role_groupe, id_role_utilisateur)
    SELECT 10001, id_role
    FROM utilisateurs.t_roles
    WHERE groupe = False
        AND ( pass IS NULL OR pass = '' ) ;

\echo '----------------------------------------------------------------------------'
\echo 'Update Flore Sentinelle users groups (=10000/GP_ACCES_APPLICATION)'
UPDATE utilisateurs.t_roles
SET
    nom_role = 'Utilisateurs Flore Sentinelle',
    identifiant = 'group_fs_users',
    desc_role = 'Les utilisateurs placés dans ce groupe peuvent utiliser les modules de suivi avec ' ||
        'le statut de « rédacteur ». Ils peuvent consulter toutes les données saisies et en ajouter de ' ||
        'nouvelles, modifier ou supprimer celles qu''ils ont créées. Ils peuvent aussi exporter les données.'
WHERE id_role = 10000 ;


\echo '----------------------------------------------------------------------------'
\echo 'Update Flore Sentinelle observers group (=10001/GP_MENUS_DEROULANT)'
UPDATE utilisateurs.t_roles
SET
    nom_role = 'Observateurs Flore Sentinelle',
    identifiant = 'group_fs_observers',
    desc_role = 'Les personnes placées dans ce groupe ne peuvent pas utiliser les modules de suivi. ' ||
        'Ce sont les ayant relevé des données ou qui sont susceptibles de le faire.'
WHERE id_role = 10001 ;


\echo '----------------------------------------------------------------------------'
\echo 'Create default generic user Admin'
INSERT INTO utilisateurs.t_roles (
    groupe,
    id_role,
    identifiant,
    nom_role,
    prenom_role,
    desc_role,
    pass,
    email,
    id_organisme,
    remarques,
    pass_plus
) VALUES (
    false,
    1,
    'admin',
    'ADMINISTRATEUR',
    'Générique',
    'Administrateur générique de GeoNature',
    '21232f297a57a5a743894a0e4a801fc3',
    'jp.milcent@cbn-alpin.fr',
    1,
    'Modifier le mot de passe !',
    '$2y$13$TMuRXgvIg6/aAez0lXLLFu0lyPk4m8N55NDhvLoUHh/Ar3rFzjFT.'
) ;


\echo '----------------------------------------------------------------------------'
\echo 'Create group Admin'
INSERT INTO utilisateurs.t_roles
    (id_role, groupe, identifiant, nom_role, remarques)
VALUES
    (10, true, 'group_admin', 'Tous les administrateurs', 'Groupe avec tous les droits.') ;


\echo '----------------------------------------------------------------------------'
\echo 'Add users to group Admin'
INSERT INTO utilisateurs.cor_roles
    (id_role_groupe, id_role_utilisateur)
VALUES
    (10, 1), -- ADMINISTRATEUR (utilisateur admin générique)
    (10, 10209), -- J-P. MILCENT
    (10, 1053), -- N. FORT
    (10, 10002) -- P. SEGURA
;


\echo '----------------------------------------------------------------------------'
\echo 'Insert applications : UsersHub, TaxHub, GeoNature'
INSERT INTO utilisateurs.t_applications
    (id_application, code_application, nom_application, desc_application)
VALUES
    (1, 'UH','UsersHub','Application permettant d''administrer la présente base de données.'),
    (2, 'TH','TaxHub','Application permettant d''administrer les taxons.'),
    (3, 'GN','GeoNature','Application permettant la consultation et la gestion des relevés faune et flore') ;


\echo '----------------------------------------------------------------------------'
\echo 'Refresh "t_applications" table sequence (=auto-increment)'
SELECT setval(
    'utilisateurs.t_applications_id_application_seq',
    (SELECT max(id_application) + 1 FROM utilisateurs.t_applications),
    false
);

\echo '----------------------------------------------------------------------------'
\echo 'Link group Admin to profil Admin for applications UsersHub, TaxHub and GeoNature'
INSERT INTO utilisateurs.cor_role_app_profil
    (id_role, id_application, id_profil)
VALUES
    (10, (SELECT id_application FROM utilisateurs.t_applications WHERE code_application = 'UH'), 6), --admin UsersHub
    (10, (SELECT id_application FROM utilisateurs.t_applications WHERE code_application = 'TH'), 6), --admin TaxHub
    (10, (SELECT id_application FROM utilisateurs.t_applications WHERE code_application = 'GN'), 6)  --admin GeoNature
;

\echo '----------------------------------------------------------------------------'
\echo 'Set profils for applications'
--Définir les profils utilisables pour TaxHub
INSERT INTO utilisateurs.cor_profil_for_app (id_profil, id_application)
VALUES
    (6, (SELECT id_application FROM utilisateurs.t_applications WHERE code_application = 'UH')),
    (3, (SELECT id_application FROM utilisateurs.t_applications WHERE code_application = 'UH')),
    (2, (SELECT id_application FROM utilisateurs.t_applications WHERE code_application = 'TH')),
    (3, (SELECT id_application FROM utilisateurs.t_applications WHERE code_application = 'TH')),
    (4, (SELECT id_application FROM utilisateurs.t_applications WHERE code_application = 'TH')),
    (6, (SELECT id_application FROM utilisateurs.t_applications WHERE code_application = 'TH')),
    (1, (SELECT id_application FROM utilisateurs.t_applications WHERE code_application = 'GN'))
;

\echo '----------------------------------------------------------------------------'
\echo 'Set permissions to group Admin and Flore Sentinelle users'
INSERT INTO gn_permissions.cor_role_action_filter_module_object
    (id_role, id_action, id_filter, id_module, id_object)
VALUES
    -- Groupe Admin (id = 1)
    (10, 1, 4, 0, 1),
    (10, 2, 4, 0, 1),
    (10, 3, 4, 0, 1),
    (10, 4, 4, 0, 1),
    (10, 5, 4, 0, 1),
    (10, 6, 4, 0, 1),
    --CRUVED du groupe en poste (id=10000) sur tout GeoNature
    (10000, 1, 4, 0, 1),
    (10000, 2, 3, 0, 1),
    (10000, 3, 2, 0, 1),
    (10000, 4, 1, 0, 1),
    (10000, 5, 3, 0, 1),
    (10000, 6, 2, 0, 1),
    -- Groupe admin a tous les droit dans METADATA
    (10, 1, 4, 2, 1),
    (10, 2, 4, 2, 1),
    (10, 3, 4, 2, 1),
    (10, 4, 4, 2, 1),
    (10, 5, 4, 2, 1),
    (10, 6, 4, 2, 1),
    -- Groupe en poste acces limité a dans METADATA
    (10000, 1, 1, 2, 1),
    (10000, 2, 3, 2, 1),
    (10000, 3, 1, 2, 1),
    (10000, 4, 1, 2, 1),
    (10000, 5, 3, 2, 1),
    (10000, 6, 1, 2, 1),
    -- Groupe en poste, n'a pas accès à l'admin
    (10000, 1, 1, 1, 1),
    (10000, 2, 1, 1, 1),
    (10000, 3, 1, 1, 1),
    (10000, 4, 1, 1, 1),
    (10000, 5, 1, 1, 1),
    (10000, 6, 1, 1, 1),
    -- Groupe en admin a tous les droits sur l'admin
    (10, 1, 4, 1, 1),
    (10, 2, 4, 1, 1),
    (10, 3, 4, 1, 1),
    (10, 4, 4, 1, 1),
    (10, 5, 4, 1, 1),
    (10, 6, 4, 1, 1),
    -- Groupe ADMIN peut gérer les permissions depuis le backoffice
    (10, 1, 4, 1, 2),
    (10, 2, 4, 1, 2),
    (10, 3, 4, 1, 2),
    (10, 4, 4, 1, 2),
    (10, 5, 4, 1, 2),
    (10, 6, 4, 1, 2),
    -- Groupe ADMIN peut gérer les nomenclatures depuis le backoffice
    (10, 1, 4, 1, 3),
    (10, 2, 4, 1, 3),
    (10, 3, 4, 1, 3),
    (10, 4, 4, 1, 3),
    (10, 5, 4, 1, 3),
    (10, 6, 4, 1, 3)
;

\echo '----------------------------------------------------------------------------'
\echo 'Commit if all good !'
COMMIT;
