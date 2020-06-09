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
    checkSuperuser

    #+----------------------------------------------------------------------------------------------------------+
    # Start script
    printInfo "Install GeoNature script started at: ${fmt_time_start}"

    commands=("wget")
    checkBinary "${commands[@]}"

    createDirectoriesArchitecture
    stepToNext

    stopSupervisorctl
    stepToNext

    backupPostgres
    stepToNext
    installPostgres11
    stepToNext
    checkPostgresqlStatus
    stepToNext
    copyPostgresConf
    upgradePostgresData
    stepToNext
    removeOldPostgres
    stepToNext

    updatePython
    stepToNext
    installWeazyPrintDependencies
    stepToNext

    installNvm
    stepToNext

    backupOldGeoNature
    stepToNext
    prepareNewGeoNature
    stepToNext
    runGeoNatureInstallDb
    stepToNext
    runGeoNatureInstallApp
    stepToNext

    prepareNewTaxhub
    stepToNext
    runTaxhubInstall
    stepToNext

    prepareNewUsershub
    stepToNext
    runUsershubInstall

    #+----------------------------------------------------------------------------------------------------------+
    displayTimeElapsed
}

function stepToNext() {
    printPretty "${Yel}Go to the next step (y/n) ?"
    read -r reply
    echo # Move to a new line
    if [[ ! "${reply}" =~ ^[Yy]$ ]];then
        [[ "${0}" = "${BASH_SOURCE}" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
    fi
}

function createDirectoriesArchitecture() {
    printMsg "Creating Flore Sentinelle geonaturadmin directories architectures..."

    gn_dir="${HOME}/geonature"
    taxhub_dir="${HOME}/taxhub"
    usershub_dir="${HOME}/usershub"
    db_backup_dir="${HOME}/backup-db"
    mg_backup_dir="${HOME}/backup-geonature-v${mg_geonature_version_old}"
    gn_backup_dir="${mg_backup_dir}/geonature"
    taxhub_backup_dir="${mg_backup_dir}/taxhub"
    usershub_backup_dir="${mg_backup_dir}/usershub"
    dwl_dir="${HOME}/dwl"

    if [[ ! -d "${db_backup_dir}" ]]; then
        mkdir -p "${db_backup_dir}"
    fi

    if [[ ! -d "${mg_backup_dir}" ]]; then
        mkdir -p "${mg_backup_dir}"
    fi

    if [[ ! -d "${dwl_dir}" ]]; then
        mkdir -p "${dwl_dir}"
    fi
}

function stopSupervisorctl() {
    printMsg "Stoping Supervisorctl..."
    sudo supervisorctl stop all
    sudo supervisorctl status
}

function backupPostgres() {
    printMsg "Backuping Postgres (can take several minutes)..."
    local dumpfile="${db_backup_dir}/$(date +'%F')_dumpall_pg-10.13.dump"
    if [[ ! -f "${dumpfile}" ]]; then
        sudo -u postgres pg_dumpall > "${dumpfile}"
    else
        printVerbose "Postgresql already dumped in ${dumpfile}"
    fi
    du -hs "${dumpfile}"
    printPretty "${Gra}If needed, restore Postgres DB with :${RCol} ${Whi}psql -f \"${dumpfile}\" postgres ${RCol}"
}

function installPostgres11() {
    printMsg "Installing Postgres 11 in parallel of Postgres 10 ..."
    sudo apt-get install -y postgresql-server-dev-11
    sudo apt-get install -y postgis postgis-2.5 postgresql-11-postgis-2.5
}

function checkPostgresqlStatus() {
    printMsg "You shoud see Postgres 10 & 11 running (if not, script exit):"

    printPretty "${Gra}Stoping all Postgres services..."
    sudo systemctl stop postgresql*

    printPretty "${Gra}Reverting port for Postgres 11, if this script already runned"
    sudo sed -e "s/^port = 5432.*$/port = 5433 # (change requires restart)/" -i "/etc/postgresql/11/main/postgresql.conf"

    printPretty "${Gra}Restarting all Postgres services..."
    sudo systemctl restart postgresql*

    printPretty "${Gra}Showing all Postgres services status..."
    sudo systemctl status postgresql*
}

function copyPostgresConf() {
    printPretty "${Red}Now, transfert manually your conf from /etc/postgresql/10/* to /etc/postgresql/11/*. After that, go to the next step (y/n) ?"
    read -r reply
    echo # Move to a new line
    if [[ ! "${reply}" =~ ^[Yy]$ ]];then
        [[ "${0}" = "${BASH_SOURCE}" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
    fi
    sudo sed -e "s/datestyle =.*$/datestyle = 'iso, dmy'/g" -i /etc/postgresql/11/main/postgresql.conf
}

function upgradePostgresData() {
    local new_version="11"
    local new_service="postgresql@${new_version}-main"
    local old_version="10"
    local old_service="postgresql@${old_version}-main"
    local old_data_size=$(sudo du -hs "/var/lib/postgresql/${old_version}")

    printMsg "Upgrading Postgresql data (size: ${old_data_size})..."

    printPretty "${Gra}Stoping service ${new_service}..."
    sudo systemctl stop "${new_service}"

    printPretty "${Gra}Droping cluster ${new_version} main..."
    sudo -u postgres pg_dropcluster "${new_version}" main
    sudo systemctl daemon-reload

    printPretty "${Gra}Upgrading data from old cluster ${old_version} main to new cluster ${new_version} main..."
    sudo -u postgres pg_upgradecluster -v "${new_version}" -m upgrade "${old_version}" main --no-start
    sudo systemctl daemon-reload

    printPretty "${Gra}Stoping old cluster ${old_version} main..."
    sudo systemctl stop "${old_service}"

    printPretty "Change new Postgres server port to default (=5432)..."
    sudo sed -e "s/^port = 5433.*$/port = 5432 # (change requires restart)/" -i "/etc/postgresql/${new_version}/main/postgresql.conf"

    printPretty "${Gra}Starting service ${new_service}..."
    sudo systemctl start "${new_service}"


    printPretty "${Gra}Show service ${new_service} status (exit script if not started)..."
    sudo systemctl status "${new_service}"

    local new_data_size=$(sudo du -hs "/var/lib/postgresql/${new_version}")
    printPretty "${Gra}Check data size (old/new):${RCol} ${old_data_size} / ${new_data_size}"
}

function removeOldPostgres() {
    printMsg "Removing old Postgresql server..."
    local cmd="sudo apt-get remove --purge postgresql-10"
    printPretty "${Gra}When you are sure about new data upgrading, remode old Postgres with:${RCol} ${cmd}"
}

function updatePython() {
    printMsg "Installing Python dependencies added between v${mg_geonature_version_old} and v${mg_geonature_version}..."
    sudo apt-get remove -y python3-virtualenv virtualenv python-pip python-qt4

    sudo apt-get install -y python3-pip python3-wheel python3-cffi

    python3 -m pip install "pip==${mg_pip_version}"
    pip3 install "virtualenv==${mg_virtualenv_version}"
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
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
    printInfo "Nvm version: $(nvm --version)"
}

function backupOldGeoNature() {
    printMsg "Backuping old GeoNature, Taxhub, Usershub and modules...}"
    cd "${HOME}"
    if [[ $(du -s -B1 "${mg_backup_dir}" | cut -f1) -gt "500000000" ]]; then
        printPretty "${Red} WARNING: check if the old version of GeoNature has already been correctly saved in ${mg_backup_dir} !"
    else
        local directories=("geonature" "bcf" "log" "sft" "shs" "sht" "src" "taxhub" "usershub")
        local files=("install_all.ini" "install_all.sh")
        for dir in "${directories[@]}"; do
            if [[ -d "${HOME}/${dir}" ]]; then
                mv "${HOME}/${dir}" "${mg_backup_dir}"
            fi
        done
        for file in "${files[@]}"; do
            if [[ -f "${HOME}/${file}" ]]; then
                mv "${HOME}/${file}" "${mg_backup_dir}"
            fi
        done
    fi
    printPretty "${Gra}Saved data size:${RCol} $(du -hs ${mg_backup_dir})"
    printPretty "${Gra}You can retrieve backup in:${RCol} ${mg_backup_dir}"
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
    rm -fR "${gn_dir}"
    mv "${repo}-${mg_geonature_archive}" "${gn_dir}"
    cp "${gn_backup_dir}/config/settings.ini" "${gn_dir}/config/settings.ini"
    sudo chown $(whoami) "${gn_dir}/"
}

function runGeoNatureInstallDb() {
    printMsg "Installing GeoNature database..."
    printPretty "${Gra}Update config to set 'drop_apps_db' to TRUE !${RCol}"
    sed -i "s/^drop_apps_db=.*$/drop_apps_db=true/g" "${gn_dir}/config/settings.ini"

    printPretty "${Gra}Running GeoNature install DB script...${RCol}"
    cd "${gn_dir}/install"
    set +e
    ./install_db.sh
    set -e

    printPretty "${Gra}Update config to revert 'drop_apps_db' to FALSE !${RCol}"
    sed -i "s/^drop_apps_db=.*$/drop_apps_db=false/g" "${gn_dir}/config/settings.ini"
}

function runGeoNatureInstallApp() {
    printMsg "Installing GeoNature application..."
    cd "${gn_dir}/install"
    set +e
    [ -s "install_app.sh" ] && \. "install_app.sh"
    set -e
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
    rm -fR "${taxhub_dir}"
    mv "${repo}-${mg_taxhub_archive}" "${taxhub_dir}"
    cp "${taxhub_backup_dir}/config/settings.ini" "${taxhub_dir}/config/settings.ini"
    sudo chown $(whoami) "${taxhub_dir}/"
}

function runTaxhubInstall() {
    printMsg "Installing TaxHub application..."
    cd "${taxhub_dir}/"
    set +e
    . create_sys_dir.sh
    create_sys_dir

    ./install_app.sh
    set -e
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
    rm -fR "${usershub_dir}"
    mv "${repo}-${mg_usershub_archive}" "${usershub_dir}"
    cp "${usershub_backup_dir}/config/settings.ini" "${usershub_dir}/config/settings.ini"
    sudo chown $(whoami) "${usershub_dir}/"
}

function runUsershubInstall() {
    printMsg "Installing UsersHub application..."
    cd "${usershub_dir}/"
    set +e
    ./install_app.sh
    set -e
}

main "${@}"
