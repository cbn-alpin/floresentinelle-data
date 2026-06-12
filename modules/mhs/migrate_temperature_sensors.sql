-- Temperature sensor migration script.
--
-- Migrate sensor data from base_site_description to temperature sensors.

BEGIN;

\echo '----------------------------------------------------------------------------'
\echo 'Extract temperature sensors data from base_site_description...'

INSERT INTO pr_monitoring_habitat_station.t_temperature_sensors (id_transect, serial_number, install_date)
    SELECT
        t.id_transect,
        coalesce(
            regexp_substr(
                bs.base_site_description,
                'Capteur(?:\s+de)?\s+temp[eé]rature\s+n°([^\s(]+)\s*\(',
                1, 1, 'i', 1
            ),
            '..?..'
        ) AS serial_number,
        to_date(
            regexp_replace(
                regexp_substr(
                    bs.base_site_description,
                    '\((\d{4}[-/]\d{2}[-/]\d{2})\)',
                    1, 1, 'i', 1
                ),
                '/', '-', 'g'
            ),
            'YYYY-MM-DD'
        ) AS install_date
    FROM gn_monitoring.t_base_sites AS bs
        JOIN pr_monitoring_habitat_station.t_transects AS t
            ON t.id_base_site = bs.id_base_site
    WHERE bs.base_site_description 
        ~ 'Capteur(?:\s+de)?\s+temp[eé]rature\s+n°[^(]+\(\d{4}[-/]\d{2}[-/]\d{2}\)' ;


\echo '----------------------------------------------------------------------------'
\echo 'Commit if all good !'
COMMIT;
