#!/usr/bin/env bash
# Encoding : UTF-8
# Migrate GeoNature from v2.1.2 to v2.4.0
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
    redirectOutput "${log_migrate_gn}"

    #+----------------------------------------------------------------------------------------------------------+
    # Start script
    printInfo "Install GeoNature script started at: ${fmt_time_start}"

    checkSuperuser

    commands=("wget")
    checkBinary "${commands[@]}"

    createDirectoriesArchitecture

    stopSupervisorctl
    backupPostgres
    installPostgres11
    copyPostgresConf
    upgradePostgresData
    removeOldPostgres

    updatePython
    installWeazyPrintDependencies

    installNvm

    backupOldGeoNature
    prepareNewGeoNature
    runGeoNatureInstallDb
    runGeoNatureInstallApp

    prepareNewTaxhub
    runTaxhubInstall

    prepareNewUsershub
    runUsershubInstall
    #+----------------------------------------------------------------------------------------------------------+
    displayTimeElapsed
}

function createDirectoriesArchitecture() {
    gn_dir="${HOME}/geonature"
    taxhub_dir="${HOME}/taxhub"
    usershub_dir="${HOME}/usershub"

    db_backup_dir="${HOME}/backup-db"
    if [[ ! -d "${db_backup_dir}" ]]; then
        mdkir -p "${db_backup_dir}"
    fi

    mg_backup_dir="${HOME}/backup-geonature-v${mg_geonature_version_old}"
    if [[ ! -d "${db_backup_dir}" ]]; then
        mdkir -p "${db_backup_dir}"
    fi
    gn_backup_dir="${mg_backup_dir}/geonature"
    taxhub_backup_dir="${mg_backup_dir}/taxhub"
    usershub_backup_dir="${mg_backup_dir}/usershub"

    dwl_dir="${HOME}/dwl"
    if [[ ! -d "${dwl_dir}" ]]; then
        mdkir -p "${dwl_dir}"
    fi
}

function stopSupervisorctl() {
    printMsg "Stoping Supervisorctl..."
    sudo supervisorctl stop all
    sudo supervisorctl status
}

function backupPostgres() {
    printMsg "Backuping Postgres..."
    local dumpfile="${db_backup_dir}/$(date +'%F')_dumpall_pg-10.13.dump"
    sudo pg_dumpall > "${dumpfile}"
    printMsg "If needed, restore Postgres DB with : psql -f \"${dumpfile}\" postgres"
    du -hs "${dumpfile}"
}

function installPostgres11() {
    printMsg "Installing Postgres 11 in parallel of Postgres 10 ..."
    sudo apt-get install -y postgresql-server-dev-11
    sudo apt-get install -y postgis postgis-2.5 postgresql-11-postgis-2.5
    printMsg "You shoud see Postgres 10 & 11 running:"
    sudo systemctl status postgresql*
}

function copyPostgresConf() {
    printPretty "${Red}Now, transfert manually your conf from /etc/postgresql/10/* to /etc/postgresql/11/*, then enter 'Y'"
    read -r reply
    echo # Move to a new line
    if [[ ! "${reply}" =~ ^[Yy]$ ]];then
        [[ "${0}" = "${BASH_SOURCE}" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
    fi
    sudo sed -e "s/datestyle =.*$/datestyle = 'ISO, DMY'/g" -i /etc/postgresql/11/main/postgresql.conf
}

function upgradePostgresData() {
    printMsg "Upgrading Postgresql data..."
    sudo -u postgres pg_dropcluster --stop 11 main
    sudo -u postgres pg_upgradecluster -m upgrade 10 main
    #sudo -H -u postgres /usr/lib/postgresql/11/bin/pg_upgrade \
        # -b /usr/lib/postgresql/10/bin \
        # -B /usr/lib/postgresql/11/bin \
        # -d /var/lib/postgresql/10/main \
        # -D /var/lib/postgresql/11/main \
        # -p 5432 \
        # -P 5433
    sudo -u pg_dropcluster --stop 10 main
}

function removeOldPostgres() {
    printMsg "Removing old Postgresql server..."
    sudo apt-get autoremove postgresql-10
}

function updatePython() {
    printMsg "Installing Python dependencies added between v${mg_geonature_version_old} and v${mg_geonature_version}..."
    sudo apt-get remove -y python3-virtualenv virtualenv python-pip python-qt4

    sudo apt-get install -y python3-pip python3-wheel python3-cffi

    python3 -m pip install pip==20.0.2
    pip3 install virtualenv==20.0.1
}

function installWeazyPrintDependencies() {
    printMsg "Installing Weazy Print dependencies (lib Python)..."
    sudo apt-get install -y \
        libcairo2 \
        libpango-1.0-0 \
        libpangocairo-1.0-0 \
        libgdk-pixbuf2.0-0 \
        libffi-dev \
        shared-mime-info
}

function installNvm() {
    printMsg "Installing Nvm (=> Node and NPM)..."
    wget -qO- "https://raw.githubusercontent.com/creationix/nvm/${mg_nvm_version}/install.sh" | bash
    source "${HOME}/.bashrc"
    printInfo "Nvm version: $(nvm --version)"
}

function backupOldGeoNature() {
    printMsg "Backuping old GeoNature, Taxhub, Usershub and modules...}"
    cd "${HOME}"
    mv geonature "${gn_backup_dir}"
    mv bcf "${mg_backup_dir}"
    mv install_all.ini "${mg_backup_dir}"
    mv install_all.sh "${mg_backup_dir}"
    mv log "${mg_backup_dir}"
    mv sft "${mg_backup_dir}"
    mv shs "${mg_backup_dir}"
    mv sht "${mg_backup_dir}"
    mv src "${mg_backup_dir}"
    mv taxhub "${taxhub_backup_dir}"
    mv usershub "${usershub_backup_dir}"
    printMsg "You can retrieve backup in ${mg_backup_dir}"
}

function prepareNewGeoNature() {
    local repo="GeoNature"
    printMsg "Downlading and prepare ${repo} version/archive : v${mg_geonature_version} / ${mg_geonature_archive} ..."
    local archive_file="${dwl_dir}/geonature_v${mg_geonature_version}.zip"
    if [[ ! -f "${archive_file}" ]]; then
        wget "https://github.com/PnX-SI/${repo}/archive/${mg_geonature_archive}.zip" -O "${archive_file}"
    fi
    cd "${dwl_dir}/"
    unzip "${archive_file}"
    mv "${repo}-${mg_geonature_archive}" "${gn_dir}"
    cp "${geonature_backup_dir}/config/settings.ini" "${geonature_dir}/config/settings.ini"
    sudo chown $(whoami) "${gn_dir}/"
}

function runGeoNatureInstallDb() {
    printMsg "Installing GeoNature database..."
    cd "${gn_dir}/install"
    ./install_db.sh
}

function runGeoNatureInstallApp() {
    printMsg "Installing GeoNature application..."
    cd "${gn_dir}/install"
    [ -s "install_app.sh" ] && \. "install_app.sh"
}

function prepareNewTaxhub() {
    local repo="TaxHub"
    printMsg "Downlading and prepare ${repo} version/archive : v${mg_taxhub_version} / ${mg_taxhub_archive} ..."
    local archive_file="${dwl_dir}/taxhub_v${mg_taxhub_version}.zip"
    if [[ ! -f "${archive_file}" ]]; then
        wget "https://github.com/PnX-SI/${repo}/archive/${mg_taxhub_archive}.zip" -O "${archive_file}"
    fi
    cd "${dwl_dir}/"
    unzip "${archive_file}"
    mv "${repo}-${mg_taxhub_archive}" "${taxhub_dir}"
    cp "${taxhub_backup_dir}/config/settings.ini" "${taxhub_dir}/config/settings.ini"
    sudo chown $(whoami) "${taxhub_dir}/"
}

function runTaxhubInstall() {
    printMsg "Installing TaxHub application..."
    cd "${taxhub_dir}/"
    . create_sys_dir.sh
    create_sys_dir

    ./install_app.sh
}

function prepareNewUsershub() {
    local repo="UsersHub"
    printMsg "Downlading and prepare ${repo} version/archive : v${mg_usershub_version} / ${mg_usershub_archive} ..."
    local archive_file="${dwl_dir}/taxhub_v${mg_usershub_version}.zip"
    if [[ ! -f "${archive_file}" ]]; then
        wget "https://github.com/PnX-SI/${repo}/archive/${mg_usershub_archive}.zip" -O "${archive_file}"
    fi
    cd "${dwl_dir}/"
    unzip "${archive_file}"
    mv "${repo}-${mg_usershub_archive}" "${usershub_dir}"
    cp "${usershub_backup_dir}/config/settings.ini" "${usershub_dir}/config/settings.ini"
    sudo chown $(whoami) "${usershub_dir}/"
}

function runUsershubInstall() {
    printMsg "Installing UsersHub application..."
    cd "${usershub_dir}/"

    ./install_app.sh
}

main "${@}"
