-- Script to add priority taxa from Conservation Strategy module.

BEGIN;


INSERT INTO
    taxonomie.bib_noms (cd_nom, cd_ref, nom_francais, "comments")
SELECT
    DISTINCT ON (pt.cd_nom) t.cd_nom,
    t.cd_ref,
    t.nom_vern,
    'Priority Flora - Import for Flore Sentinelle' AS "comments"
FROM
    pr_conservation_strategy.t_priority_taxon AS pt
    JOIN taxonomie.taxref AS t ON pt.cd_nom = t.cd_nom ON CONFLICT (cd_nom) DO NOTHING;


INSERT INTO
    taxonomie.cor_nom_liste (id_liste, id_nom) WITH sciname_list AS (
        SELECT
            id_liste AS id_list
        FROM
            taxonomie.bib_listes
        WHERE
            code_liste = 'PRIORITY_FLORA'
    )
SELECT
    sl.id_list,
    n.id_nom
FROM
    sciname_list AS sl,
    taxonomie.bib_noms AS n
WHERE
    n."comments" = 'Priority Flora - Import for Flore Sentinelle';


COMMIT;
