BEGIN;

\echo '----------------------------------------------------------------------------'
\echo 'Add FDW extension if necessary'
CREATE EXTENSION IF NOT EXISTS postgres_fdw;


\echo '----------------------------------------------------------------------------'
\echo 'Create FDW server'
DROP SERVER IF EXISTS geonaturev1server CASCADE;

CREATE SERVER geonaturev1server
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (
        host :'gn1DbHost',
        dbname :'gn1DbName',
        port :'gn1DbPort'
    );

ALTER SERVER geonaturev1server OWNER TO :dbUser;


\echo '----------------------------------------------------------------------------'
\echo 'Create user mapping'
DROP USER MAPPING IF EXISTS FOR :dbUser SERVER geonaturev1server;

CREATE USER MAPPING FOR :dbUser
    SERVER geonaturev1server
    OPTIONS (user :'gn1DbUser', password :'gn1DbPass');


\echo '----------------------------------------------------------------------------'
\echo 'Drop FDW schema if exists'
DROP SCHEMA IF EXISTS migrate_v1_florepatri;

DROP SCHEMA IF EXISTS migrate_v1_utilisateurs;


\echo '----------------------------------------------------------------------------'
\echo 'Change role from superuser to local user'
SET ROLE :dbUser;


\echo '----------------------------------------------------------------------------'
\echo 'Create FDW "migrate_v1_florepatri" schema'
CREATE SCHEMA migrate_v1_florepatri;

IMPORT FOREIGN SCHEMA florepatri
FROM SERVER geonaturev1server
INTO migrate_v1_florepatri;


\echo '----------------------------------------------------------------------------'
\echo 'Create FDW "migrate_v1_utilisateurs" schema'
CREATE SCHEMA migrate_v1_utilisateurs;

IMPORT FOREIGN SCHEMA utilisateurs
FROM SERVER geonaturev1server
INTO migrate_v1_utilisateurs;


-- ----------------------------------------------------------------------------
COMMIT;
