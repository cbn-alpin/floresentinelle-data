'''
Usage:
 1. Go to sql directory: cd floresentinelle-srv/home/geonat/www/modules/monitorings/veg_rec_n3/data
 2. Run SQL script :
psql -U <dbuser> -h <dbhost> -p <dbport> -d <dbname> -f <path/to/file.sql>
'''

BEGIN;

\echo '----------------------------------------------------------------------------'
\echo 'Add taxon list for veg_rec_n3 module'

INSERT INTO taxonomie.bib_listes(
    code_liste,
    nom_liste,
    desc_liste,
    picto,
    regne,
    group2_inpn
    )
VALUES(
    'plantae',
    'Taxon Plantes',
    'Tous les taxons du règne Plantae',
    'images/pictos/nopicto.gif',
    'Plantae',
    NULL
;

\echo '----------------------------------------------------------------------------'
\echo 'Add taxons from plantae regne in VEG_REC list'

INSERT INTO taxonomie.cor_nom_liste
SELECT
    (SELECT id_liste
    FROM taxonomie.bib_listes
    WHERE code_liste = 'plantae'),
    t.cd_nom
FROM taxonomie.taxref t
WHERE t.regne ILIKE 'Plantae'

\echo '----------------------------------------------------------------------------'
\echo 'COMMIT if it all goes well !'
COMMIT;