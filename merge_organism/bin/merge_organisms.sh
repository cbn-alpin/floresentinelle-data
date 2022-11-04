#!/bin/bash
# Encoding : UTF-8
# Merge DB GeoNature organisms ids


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
     -f | --file: path to organisms CSV file. Columns : id (=new_id_organism), id_duplicates (=old_id_organism).
     -o | --old: comma separated string of old id_organism. Ex. : 12,125. Use with --new.
     -n | --new: string of id_organism to keep. Id organism used to replace all old id_organism. Ex. 54. Use with --old.
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
            "f") organisms_csv_path="$(realpath ${OPTARG})" ;;
            "o") old_id_organism="${OPTARG}" ;;
            "n") new_id_organism="${OPTARG}" ;;
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
    redirectOutput "${mgno_log_file}"

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

    if [[ -n ${organisms_csv_path-} ]]; then
        mergeOrganismsFromCsv
    elif [[ -n ${new_id_organism-} ]] && [[ -n ${old_id_organism-} ]] ; then
        executeMergeOrganismSql "${new_id_organism}" "${old_id_organism}"
    else
        parseScriptOptions
    fi

    #+----------------------------------------------------------------------------------------------------------+
    # Display script execution infos
    displayTimeElapsed
}

function mergeOrganismsFromCsv() {
    local head="$(csvtool -t TAB head 1 "${organisms_csv_path}")"

    printMsg "Merging organisms from ${organisms_csv_path}"
    local tasks_done=0
    local tasks_count="$(($(csvtool height "${organisms_csv_path}") - 1))"
    while IFS= read -r line; do
        local id="$(printf "$head\n$line" | csvtool namedcol id - | sed 1d | sed -e 's/^"//' -e 's/"$//')"
        local id_duplicates="$(printf "$head\n$line" | csvtool namedcol id_duplicates - | sed 1d | sed -e 's/^"//' -e 's/"$//')"

        executeMergeOrganismSql "${id}" "${id_duplicates}"

        if ! [[ -n ${verbose-} ]]; then
            (( tasks_done += 1 ))
            displayProgressBar $tasks_count $tasks_done "merging"
        fi
    done < <(stdbuf -oL csvtool -t TAB drop 1 "${organisms_csv_path}")
    echo
}

function executeMergeOrganismSql() {
    if [[ $# -lt 2 ]]; then
        exitScript "Missing required argument to ${FUNCNAME[0]}()!" 2
    fi

    local readonly new_id_organism="${1}"
    local readonly old_ids_organisms="${2}"

    printMsg "Replacing ${old_ids_organisms} by ${new_id_organism} ..."

    if [[ -n ${new_id_organism-} ]] && [[ -n ${old_ids_organisms-} ]] ; then
        oldIFS="${IFS}"
        export IFS=","
        for old_id_organism in ${old_ids_organisms}; do
            export PGPASSWORD="${db_pass}"; \
            sed "s/\${oldIdOrganism}/${old_id_organism}/g" "${sql_dir}/01_merge_organism.sql" | \
            sed -e "s/\${newIdOrganism}/${new_id_organism}/g" | \
            psql -h "${db_host}" -U "${db_user}" -d "${db_name}" ${psql_verbosity} \
                -v "newIdOrganism=${new_id_organism}" \
                -v "oldIdOrganism=${old_id_organism}" \
                -f -
        done
        IFS="${oldIFS}"
    else
        printError "Empty id: new_id_organism=${new_id_organism} ; old_id_organism=${old_ids_organisms}"
    fi
}

main "${@}"
