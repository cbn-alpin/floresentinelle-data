\echo 'Insert utils functions'
\echo 'Required rights: db owner'
\echo 'GeoNature database compatibility : v2.3.0+'
BEGIN;


\echo '-------------------------------------------------------------------------------'
\echo 'Set function "computeImportTotal()"'
CREATE OR REPLACE FUNCTION gn_imports.computeImportTotal(
    tableImport VARCHAR, actionImport VARCHAR, OUT total integer
)
LANGUAGE plpgsql AS $$
DECLARE
	schemaImport VARCHAR ;
	parsed_ident VARCHAR[] ;
    parsed_count INT ;
BEGIN
    parsed_ident := parse_ident(tableImport) ;
    parsed_count := array_length(parsed_ident, 1) ;

    IF parsed_count = 2 THEN
        SELECT parsed_ident[1] INTO schemaImport ;
        SELECT parsed_ident[2] INTO tableImport ;
    ELSIF parsed_count = 1 THEN
        schemaImport := 'gn_imports' ;
        SELECT parsed_ident[1] INTO tableImport ;
    END IF;

    --RAISE NOTICE 'Schema %, table %', schemaImport, tableImport ;
    EXECUTE format(
        'SELECT COUNT(*) FROM %I.%I WHERE meta_last_action = $1 ',
        schemaImport, tableImport
    ) USING actionImport INTO total ;
END;
$$;


\echo '-------------------------------------------------------------------------------'
\echo 'Set function "computeImportStep()"'
CREATE OR REPLACE FUNCTION gn_imports.computeImportStep(total INT)
RETURNS INT
LANGUAGE plpgsql AS $$
BEGIN
    IF total <= 100000 THEN
        RETURN 10000;
    ELSIF total > 100000 AND total <= 2500000 THEN
        RETURN 100000;
    ELSIF total > 2500000 THEN
        RETURN 500000;
    END IF;
END;
$$;

\echo '----------------------------------------------------------------------------'
\echo 'COMMIT if all is ok:'
COMMIT;
