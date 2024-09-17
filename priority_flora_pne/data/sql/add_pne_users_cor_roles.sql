BEGIN;


\echo '----------------------------------------------------------------------------'
\echo 'Utils functions'

CREATE OR REPLACE FUNCTION utilisateurs.get_id_role_by_name(rolename character varying)
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
        BEGIN
            RETURN (
                SELECT id_role
                FROM utilisateurs.t_roles
                WHERE nom_role = roleName
            );
        END;
    $function$
;

\echo '----------------------------------------------------------------------------'
\echo 'Insert PNE users in cor_roles'

INSERT INTO utilisateurs.cor_roles
SELECT
	utilisateurs.get_id_role_by_name('Utilisateurs Flore Sentinelle'),
	tr.id_role
FROM utilisateurs.t_roles tr 
LEFT JOIN utilisateurs.cor_roles cr ON cr.id_role_utilisateur = tr.id_role 
WHERE email ilike '%@ecrins-parcnational.fr%'
AND cr.id_role_groupe IS NULL 
AND COALESCE(tr.pass,tr.pass_plus) IS NOT NULL  
AND tr.active IS TRUE 

\echo '----------------------------------------------------------------------------'
\echo 'Insert PNE observers in cor_roles'

INSERT INTO utilisateurs.cor_roles
SELECT
	utilisateurs.get_id_role_by_name('Observateurs Flore Sentinelle'),
	tr.id_role
FROM utilisateurs.t_roles tr 
LEFT JOIN utilisateurs.cor_roles cr ON cr.id_role_utilisateur = tr.id_role 
WHERE email ilike '%@ecrins-parcnational.fr%'
AND cr.id_role_groupe IS NULL 
AND COALESCE(tr.pass,tr.pass_plus) IS NULL  
AND tr.active IS TRUE

\echo '-------------------------------------------------------------------------------'
\echo 'COMMIT if all is ok:'
COMMIT ;
