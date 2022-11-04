#!/bin/bash
# Encoding : UTF-8
# Merge DB GeoNature users ids


#+----------------------------------------------------------------------------------------------------------+
# Configure script execute options
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
     -f | --file: path to users CSV file. Columns : id (=new_id_role), id_duplicates (=old_id_role).
     -o | --old: comma separated string of old id_role. Ex. : 12,125. Use with --new.
     -n | --new: string of new id_role. Id role used to replace all old id_role. Ex. 54. Use with --old.
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
            "--file") set -- "${@}" "-f" ;;
            "--old") set -- "${@}" "-o" ;;
            "--new") set -- "${@}" "-n" ;;
            "--"*) exitScript "ERROR : parameter '${arg}' invalid ! Use -h option to know more." 1 ;;
            *) set -- "${@}" "${arg}"
        esac
    done

    while getopts "hvxc:f:o:n:" option; do
        case "${option}" in
            "h") printScriptUsage ;;
            "v") readonly verbose=true ;;
            "x") readonly debug=true; set -x ;;
            "c") setting_file_path="${OPTARG}" ;;
            "f") users_csv_path="$(realpath ${OPTARG})" ;;
            "o") old_id_role="${OPTARG}" ;;
            "n") new_id_role="${OPTARG}" ;;
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
    source "$(dirname "${BASH_SOURCE[0]}")/../../shared/lib/utils.bash"

    #+----------------------------------------------------------------------------------------------------------+
    # Init script
    initScript "${@}"
    parseScriptOptions "${@}"
    loadScriptConfig "${setting_file_path-}"
    redirectOutput "${mgnu_log_file}"

    commands=("psql" "csvtool")
    checkBinary "${commands[@]}"

    # Manage verbosity
    if [[ -n ${verbose-} ]]; then
        readonly psql_verbosity="${psql_verbose_opts-}"
    else
        readonly psql_verbosity="${psql_quiet_opts-}"
    fi

    #+----------------------------------------------------------------------------------------------------------+
    # Start script
    printInfo "${app_name} import script started at: ${fmt_time_start}"

    if [[ -n ${users_csv_path-} ]]; then
        mergeUsersFromCsv
    elif [[ -n ${new_id_role-} ]] && [[ -n ${old_id_role-} ]] ; then
        executeMergeUserSql "${new_id_role}" "${old_id_role}"
    else
        parseScriptOptions
    fi

    #+----------------------------------------------------------------------------------------------------------+
    # Display script execution infos
    displayTimeElapsed
}

function mergeUsersFromCsv() {
    local head="$(csvtool -t TAB head 1 "${users_csv_path}")"

    printMsg "Merging users from ${users_csv_path}"
    local tasks_done=0
    local tasks_count="$(($(csvtool height "${users_csv_path}") - 1))"
    while IFS= read -r line; do
        local id="$(printf "$head\n$line" | csvtool namedcol id - | sed 1d | sed -e 's/^"//' -e 's/"$//')"
        local id_duplicates="$(printf "$head\n$line" | csvtool namedcol id_duplicates - | sed 1d | sed -e 's/^"//' -e 's/"$//')"

        executeMergeUserSql "${id}" "${id_duplicates}"

        if ! [[ -n ${verbose-} ]]; then
            (( tasks_done += 1 ))
            displayProgressBar $tasks_count $tasks_done "merging"
        fi
    done < <(stdbuf -oL csvtool -t TAB drop 1 "${users_csv_path}")
    echo
}

function executeMergeUserSql() {
    if [[ $# -lt 2 ]]; then
        exitScript "Missing required argument to ${FUNCNAME[0]}()!" 2
    fi

    local readonly new_id_role="${1}"
    local readonly old_ids_roles="${2}"

    printMsg "Replacing ${old_ids_roles} by ${new_id_role} ..."

    if [[ -n ${new_id_role-} ]] && [[ -n ${old_ids_roles-} ]] ; then
        oldIFS="${IFS}"
        export IFS=","
        for old_id_role in ${old_ids_roles}; do
            export PGPASSWORD="${db_pass}"; \
            sed "s/\${oldIdRole}/${old_id_role}/g" "${sql_dir}/01_merge_user.sql" | \
            sed -e "s/\${newIdRole}/${new_id_role}/g" | \
            psql -h "${db_host}" -U "${db_user}" -d "${db_name}" ${psql_verbosity} \
                -v "newIdRole=${new_id_role}" \
                -v "oldIdRole=${old_id_role}" \
                -f -
        done
        IFS="${oldIFS}"
    else
        printError "Empty id: new_id_role=${new_id_role} ; old_id_role=${old_ids_roles}"
    fi
}

main "${@}"
