#!/usr/bin/env bash
# Encoding : UTF-8
# Migrate users/organisms from https://reseau-conservation-alpes-ain.fr/ to https://geonature.floresentinelle.fr/
#
# Documentation : https://github.com/jpm-cbna/floresentinelle-migrate
set -euo pipefail

# DESC: Usage help
# ARGS: None
# OUTS: None
function printScriptUsage() {
    cat << EOF
Usage: ./$(basename $BASH_SOURCE)[options]
     -h | --help: display this help
     -v | --verbose: display more infos
     -x | --debug: display debug script infos
     -c | --config: path to config file to use (default : config/settings.ini)
EOF
    exit 0
}

# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: Variables indicating command-line parameters and options
function parseScriptOptions() {
    # Transform long options to short ones
    for arg in "${@}"; do
        shift
        case "${arg}" in
            "--help") set -- "${@}" "-h" ;;
            "--verbose") set -- "${@}" "-v" ;;
            "--debug") set -- "${@}" "-x" ;;
            "--config") set -- "${@}" "-c" ;;
            "--"*) exitScript "ERROR : parameter '${arg}' invalid ! Use -h option to know more." 1 ;;
            *) set -- "${@}" "${arg}"
        esac
    done

    while getopts "hvxc:" option; do
        case "${option}" in
            "h") printScriptUsage ;;
            "v") readonly verbose=true ;;
            "x") readonly debug=true; set -x ;;
            "c") setting_file_path="${OPTARG}" ;;
            *) exitScript "ERROR : parameter invalid ! Use -h option to know more." 1 ;;
        esac
    done
}

# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
function main() {
    #+----------------------------------------------------------------------------------------------------------+
    # Load utils
    source "$(dirname "${BASH_SOURCE[0]}")/utils.bash"

    #+----------------------------------------------------------------------------------------------------------+
    # Init script
    initScript "${@}"
    parseScriptOptions "${@}"
    loadScriptConfig "${setting_file_path-}"
    redirectOutput "${log_migrate_users}"
    checkSuperuser

    #+----------------------------------------------------------------------------------------------------------+
    # Start script
    printInfo "Migrate users/organisms script started at: ${fmt_time_start}"

    #+----------------------------------------------------------------------------------------------------------+
    # Manage verbosity
    if [[ -n ${verbose-} ]]; then
        readonly psql_verbosity="${psql_verbose_opts-}"
    else
        readonly psql_verbosity="${psql_quiet_opts-}"
    fi

    #+----------------------------------------------------------------------------------------------------------+
    createFdwLinks
    migrateUsersOrganisms

    #+----------------------------------------------------------------------------------------------------------+
    displayTimeElapsed
}

function createFdwLinks() {
    printMsg "Create GeoNature v1 FDW links in local GeoNature v2 database"

    sudo -n -u ${pg_admin_name} -s \
        psql -d "${db_name}" ${psql_verbosity} \
            -v gn1DbHost="${gn1_db_host}" \
            -v gn1DbName="${gn1_db_name}" \
            -v gn1DbPort="${gn1_db_port}" \
            -v gn1DbUser="${gn1_db_user}" \
            -v gn1DbPass="${gn1_db_pass}" \
            -v dbUser="${db_user}" \
            -f "${sql_dir}/01-users/01_create_fdw.sql"
}

function migrateUsersOrganisms() {
    printMsg "Migrate users and organisms"
    export PGPASSWORD="${db_pass}"; \
        psql -h "${db_host}" -U "${db_user}" -d "${db_name}" ${psql_verbosity} \
            -f "${sql_dir}/01-users/02_migrate_users.sql"
}

main "${@}"
