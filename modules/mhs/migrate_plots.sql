-- Plots migration script.
-- Creates parent plots from existing subplots
-- and associates the subplots with their parent via id_parent.

BEGIN;

\echo '----------------------------------------------------------------------------'
\echo 'Create parents plots...'

WITH parent_plots AS (
    SELECT DISTINCT
        id_transect,
        split_part(code_plot, '.', 1) AS code_plot_parent,
        distance_plot
    FROM pr_monitoring_habitat_station.t_plots
    WHERE code_plot LIKE '%.%'
)
INSERT INTO pr_monitoring_habitat_station.t_plots (id_transect, code_plot, distance_plot)
    SELECT
        id_transect,
        code_plot_parent,
        distance_plot
    FROM parent_plots
    ORDER BY id_transect, code_plot_parent ;


\echo '----------------------------------------------------------------------------'
\echo 'Link the subplots to their parent plot...'

UPDATE pr_monitoring_habitat_station.t_plots AS subplots SET
    id_parent = parent_plots.id_plot,
    distance_plot = NULL
FROM pr_monitoring_habitat_station.t_plots AS parent_plots
WHERE subplots.code_plot LIKE '%.%'
    AND parent_plots.code_plot = split_part(subplots.code_plot, '.', 1)
    AND parent_plots.id_transect = subplots.id_transect
    AND parent_plots.id_parent IS NULL;


\echo '----------------------------------------------------------------------------'
\echo 'Commit if all good !'
COMMIT;
