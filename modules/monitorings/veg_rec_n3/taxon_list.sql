'''
Usage:
 1. Go to sql directory: cd floresentinelle-srv/home/geonat/www/modules/monitorings/veg_rec_n3/data
 2. Run SQL script :
psql -U <dbuser> -h <dbhost> -p <dbport> -d <dbname> -f <path/to/file.sql>
'''

BEGIN;


\echo '----------------------------------------------------------------------------'
\echo 'Add taxon list for veg_rec_n3 module'

INSERT INTO taxonomie.bib_listes (
    code_liste,
    nom_liste,
    desc_liste,
    picto,
    regne,
    group2_inpn
) VALUES (
    'PLANTAE',
    'Taxon Plantes',
    'Tous les taxons du règne Plantae',
    'images/pictos/nopicto.gif',
    'Plantae',
    NULL
) ON CONFLICT DO NOTHING ;

\echo '----------------------------------------------------------------------------'
\echo 'Add taxons from plantae regne in bib_noms'

INSERT INTO taxonomie.bib_noms (
    cd_nom,
    cd_ref,
    comments
)
    SELECT
        t.cd_nom,
        t.cd_ref,
        'Added for PLANTAE list - ' || CURRENT_DATE
    FROM taxonomie.taxref AS t
    WHERE t.regne = 'Plantae'
        AND NOT EXISTS (
            SELECT 'TRUE'
            FROM taxonomie.bib_noms AS bn
            WHERE bn.cd_nom = t.cd_nom
                AND bn.cd_ref = t.cd_ref
        )
ON CONFLICT DO NOTHING ;

\echo '----------------------------------------------------------------------------'
\echo 'Add taxons from plantae regne in PLANTAE list'

INSERT INTO taxonomie.cor_nom_liste
    SELECT
        (
            SELECT id_liste
            FROM taxonomie.bib_listes
            WHERE code_liste = 'PLANTAE'
        ) AS id_liste,
        bn.id_nom
    FROM taxonomie.taxref AS t
        JOIN taxonomie.bib_noms AS bn
            ON (bn.cd_nom = t.cd_nom AND bn.cd_ref = t.cd_ref)
    WHERE t.regne = 'Plantae'
ON CONFLICT DO NOTHING ;


\echo '----------------------------------------------------------------------------'
\echo 'COMMIT if it all goes well !'
COMMIT;
