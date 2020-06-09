#!/usr/bin/env bash
# Encoding : UTF-8
# Rsync Flore Sentinelle migrate scripts to server
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
     -t | --dry-run: run Rsync with '--dry-run' option
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
            "--dry-run") set --"${@}" "-t" ;;
            "--"*) exitScript "ERROR : parameter '${arg}' invalid ! Use -h option to know more." 1 ;;
            *) set -- "${@}" "${arg}"
        esac
    done

    while getopts "hvxtc:" option; do
        case "${option}" in
            "h") printScriptUsage ;;
            "v") readonly verbose=true ;;
            "x") readonly debug=true; set -x ;;
            "c") setting_file_path="${OPTARG}" ;;
            "t") readonly dry_run="--dry-run" ;;
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

    #+----------------------------------------------------------------------------------------------------------+
    # Start script
    printInfo "Rsync Floresentinelle-Migrate to server script started at: ${fmt_time_start}"

    rsync \
        -av \
        --exclude=".*" \
        --exclude="var/" \
        --exclude="config/settings.ini" \
        --exclude="bin/rsync.sh" \
        "${root_dir}/" \
        geonatureadmin@floresent-srv:/home/geonatureadmin/bin/migrate/ \
        ${dry_run-}

    #+----------------------------------------------------------------------------------------------------------+
    displayTimeElapsed
}

main "${@}"
