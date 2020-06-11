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

    definePathesVariables

    stepToNext createDirectoriesArchitecture
    stepToNext backupSupervisorConf
    stepToNext stopSupervisorctl

    stepToNext backupPostgres
    stepToNext installPostgresNewVersion
    stepToNext checkPostgresqlStatus
    stepToNext copyPostgresConf
    stepToNext upgradePostgresData
    stepToNext removeOldPostgres

    stepToNext updatePython
    stepToNext installWeazyPrintDependencies

    stepToNext installNvm

    stepToNext backupOldGeoNature
    stepToNext prepareGeoNature
    stepToNext updateGeoNatureSettings
    stepToNext runGeoNatureInstallDb
    stepToNext runGeoNatureInstallApp

    stepToNext prepareTaxhub
    stepToNext updateTaxhubSettings
    stepToNext runTaxhubInstall

    stepToNext prepareUsershub
    stepToNext updateUsershubSettings
    stepToNext runUsershubInstall

    stepToNext prepareModuleSft
    stepToNext updateModuleSftSettings
    stepToNext runModuleSftInstall

    stepToNext prepareModuleSht
    stepToNext updateModuleShtSettings
    stepToNext runModuleShtInstall
    stepToNext updateModuleShtSettingsAfterInstall

    #+----------------------------------------------------------------------------------------------------------+
    displayTimeElapsed
}

function definePathesVariables() {
    gn_dir="${HOME}/geonature"
    taxhub_dir="${HOME}/taxhub"
    usershub_dir="${HOME}/usershub"
    modules_dir="${HOME}/modules"
    db_backup_dir="${HOME}/backup-db"
    mg_backup_dir="${HOME}/backup-geonature-v${mg_geonature_version_old}"
    supervisor_backup_dir="${mg_backup_dir}/supervisor-conf"
    gn_backup_dir="${mg_backup_dir}/geonature"
    taxhub_backup_dir="${mg_backup_dir}/taxhub"
    usershub_backup_dir="${mg_backup_dir}/usershub"
    dwl_dir="${HOME}/dwl"
}

function stepToNext() {
    function_name="${1-}"
    step=${step:=0}
    step=$((step + 1))

    if [[ "${step}" = "1" ]]; then
        printPretty "${Blink}HELP:${RCol} ${Mag}y=yes, j=jump (not execute next function), c=cancel script (exit)" ${Mag}
    fi

    echo # Move to a new line
    printPretty "Step #${step} - Go to next step '${function_name}' (y/j/c) ?" ${Mag}
    read -r -n 1 key
    echo # Move to a new line
    if [[ ! "${key}" =~ ^[YyjJ]$ ]];then
        printPretty "Are you sure to exit script (y/n) ?" ${Mag}
        read -r -n 1 key
        echo # Move to a new line
        if [[ "${key}" =~ ^[Yy]$ ]];then
            [[ "${0}" = "${BASH_SOURCE}" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
        fi
    fi
    if [[ ! "${key}" =~ ^[Jj]$ ]];then
        "$@"
    fi
}

function createDirectoriesArchitecture() {
    printMsg "Creating Flore Sentinelle geonaturadmin directories architectures..."

    local directories=("${db_backup_dir}" "${supervisor_backup_dir}" "${dwl_dir}" "${modules_dir}")
    for dir in "${directories[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            mkdir -p "${dir}"
        fi
    done
}

function backupSupervisorConf() {
    printMsg "Saving Supervisor conf files..."
    if [[ $(du -s -B1 "${supervisor_backup_dir}" | cut -f1) -gt "4096" ]]; then
        printPretty "${Blink}${Red}WARNING: ${RCol}${Red}check if the old Supervisor conf of GeoNature has already been correctly saved in ${supervisor_backup_dir} !${RCol}"
    else
        local files=("geonature-service.conf" "taxhub-service.conf" "usershub-service.conf")
        for file in "${files[@]}"; do
            if [[ -f "/etc/supervisor/conf.d/${file}" ]]; then
                sudo mv "/etc/supervisor/conf.d/${file}" "${supervisor_backup_dir}/"
            fi
        done
    fi
    printInfo "Saved data size: $(du -hs ${supervisor_backup_dir})"
    printInfo "You can retrieve backup in: ${supervisor_backup_dir}"
}

function stopSupervisorctl() {
    printMsg "Stoping and cleaning Supervisor..."

    printPretty "Cleaning Supervisor conf files if necessary (when script already run)..." ${Gra}
    local files=("geonature-service.conf" "taxhub-service.conf" "usershub-service.conf")
    for file in "${files[@]}"; do
        if [[ -f "/etc/supervisor/conf.d/${file}" ]]; then
            sudo rm -f "/etc/supervisor/conf.d/${file}"
        fi
    done

    printPretty "Stoping all Supervisor services..." ${Gra}
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
    printInfo "If needed, restore Postgres DB with : psql -f \"${dumpfile}\" postgres"
}

function installPostgresNewVersion() {
    printMsg "Installing Postgres 11 in parallel of Postgres 10 ..."
    sudo apt-get install -y postgresql-server-dev-11
    sudo apt-get install -y postgis postgis-2.5 postgresql-11-postgis-2.5
}

function checkPostgresqlStatus() {
    printMsg "You shoud see Postgres 10 & 11 running (if not, script exit):"

    printPretty "Stoping all Postgres services..." ${Gra}
    sudo systemctl stop postgresql postgresql@10-main postgresql@11-main

    printPretty "Reseting port for Postgres 10 (=5432) & 11 (=5433), if this script already runned" ${Gra}
    sudo sed -e "s/^port = .*$/port = 5432 # (change requires restart)/" -i "/etc/postgresql/10/main/postgresql.conf"
    sudo sed -e "s/^port = .*$/port = 5433 # (change requires restart)/" -i "/etc/postgresql/11/main/postgresql.conf"
    sudo systemctl daemon-reload

    printPretty "Restarting all Postgres services..." ${Gra}
    sudo systemctl restart postgresql postgresql@10-main postgresql@11-main

    printPretty "Showing all Postgres services status..." ${Gra}
    sudo systemctl status postgresql postgresql@10-main postgresql@11-main
}

function copyPostgresConf() {
    printPretty "Now, transfert manually your conf from /etc/postgresql/10/* to /etc/postgresql/11/*. After that, go to the next step (y/n) ?" ${Red}
    read -r -n 1 key
    echo # Move to a new line
    if [[ ! "${key}" =~ ^[Yy]$ ]];then
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

    printPretty "Stoping service ${new_service}..." ${Gra}
    sudo systemctl stop "${new_service}"

    printPretty "Droping cluster ${new_version} main..." ${Gra}
    sudo -u postgres pg_dropcluster "${new_version}" main
    sudo systemctl daemon-reload

    printPretty "Upgrading data from old cluster ${old_version} main to new cluster ${new_version} main..." ${Gra}
    sudo -u postgres pg_upgradecluster -v "${new_version}" -m upgrade "${old_version}" main --no-start
    sudo systemctl daemon-reload

    printPretty "Stoping old cluster ${old_version} main..." ${Gra}
    sudo systemctl stop "${old_service}"

    printPretty "Change new Postgres server port to default (=5432)..." ${Gra}
    sudo sed -e "s/^port = .*$/port = 5432 # (change requires restart)/" -i "/etc/postgresql/${new_version}/main/postgresql.conf"

    printPretty "Starting service ${new_service}..." ${Gra}
    sudo systemctl start "${new_service}"


    printPretty "Show service ${new_service} status (exit script if not started)..." ${Gra}
    sudo systemctl status "${new_service}"

    local new_data_size=$(sudo du -hs "/var/lib/postgresql/${new_version}")
    printInfo "Check data size (old/new): ${old_data_size} / ${new_data_size}"
}

function removeOldPostgres() {
    printMsg "Removing old Postgresql server..."
    local cmd="sudo apt-get remove --purge postgresql-10"
    printInfo "When you are sure about new data upgrading, remode old Postgres with: ${cmd}"
}

function updatePython() {
    printMsg "Installing Python dependencies added between ${mg_geonature_version_old} and ${mg_geonature_version}..."
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
        printPretty "${Blink}${Red}WARNING: ${RCol}${Red}check if the old version of GeoNature has already been correctly saved in ${mg_backup_dir} !${RCol}"
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
    printInfo "Saved data size: $(du -hs ${mg_backup_dir})"
    printInfo "You can retrieve backup in: ${mg_backup_dir}"
}

function prepareGeoNature() {
    local repo="GeoNature"
    printMsg "Downlading and prepare ${repo} version/archive : ${mg_geonature_version} / ${mg_geonature_archive} ..."
    if [[ "${mg_geonature_version}" != ${mg_geonature_archive} ]]; then
        local archive_file="${dwl_dir}/geonature_v${mg_geonature_version}_${mg_geonature_archive:0:7}.zip"
    else
        local archive_file="${dwl_dir}/geonature_v${mg_geonature_version}.zip"
    fi

    if [[ ! -f "${archive_file}" ]]; then
        wget "https://github.com/PnX-SI/${repo}/archive/${mg_geonature_archive}.zip" -O "${archive_file}" -q --show-progress --progress=bar:force 2>&1
    fi
    cd "${dwl_dir}/"
    rm -fR "${repo}-${mg_geonature_archive}"
    unzip "${archive_file}"
    sudo chown -R $(whoami) "${gn_dir}/"
    rm -fR "${gn_dir}"
    mv "${repo}-${mg_geonature_archive}" "${gn_dir}"
    sudo chown $(whoami) "${gn_dir}/"
}

function updateGeoNatureSettings() {
    printMsg "Updating GeoNature settings..."

    printPretty "Copy 'settings.ini' from backup to new GeoNature" ${Gra}
    cp "${gn_backup_dir}/config/settings.ini" "${gn_dir}/config/settings.ini"

    printPretty "Copy 'geonature_config.toml' from backup to new GeoNature" ${Gra}
    cp "${gn_backup_dir}/config/geonature_config.toml" "${gn_dir}/config/geonature_config.toml"

    printPretty "Copy Flore Sentinelle custom files to new GeoNature" ${Gra}
    local logo_path="frontend/src/custom/images/logo_structure.png"
    cp "${gn_backup_dir}/${logo_path}" "${gn_dir}/${logo_path}"
    local intro_path="frontend/src/custom/components/introduction/introduction.component.html"
    cp "${gn_backup_dir}/${intro_path}" "${gn_dir}/${intro_path}"

    printPretty "Add new settings" ${Gra}
    new_param="# Installer le module Occurrence d'habitat\ninstall_module_occhab=false\n"
    sed -i "s/^\(install_module_validation=.*\)$/\1\n${new_param}/" "${gn_dir}/config/settings.ini"
    new_param="# Définir dans quelle version de Habref-api-module (release, branche ou tag) prendre le code SQL permettant la création du schéma ref_habitats de la base de données de GeoNature\nhabref_api_release=\"0.1.2\"\n"
    sed -i "s/^\(nomenclature_release=.*\)$/\1\n${new_param}/" "${gn_dir}/config/settings.ini"
    new_param="\n# Proxy - si le serveur sur lequel se trouve GeoNature se trouve derrière un proxy\n# laisser vide si vous n'avez pas de proxy\nproxy_http=\nproxy_https=\n"
    sed -i "s/^\(habref_api_release=.*\)$/\1\n${new_param}/" "${gn_dir}/config/settings.ini"
    new_param="gun_timeout=30"
    sed -i "s/^\(gun_port=.*\)$/\1\n${new_param}/" "${gn_dir}/config/settings.ini"

    printPretty "Update parameters" ${Gra}
    sed -i "s/^\(MODE\)=.*$/\1=\"prod\"/" "${gn_dir}/config/settings.ini"
    sed -i "s/^\(install_default_dem\)=.*$/\1=${mg_gn_dem_install}/" "${gn_dir}/config/settings.ini"

    printPretty "Define version releases of dependencies (UsersHub, TaxHub, Nomenclature, HabRef API)" ${Gra}
    sed -i "s/^\(usershub_release\)=.*$/\1=\"${mg_usershub_release}\"/" "${gn_dir}/config/settings.ini"
    sed -i "s/^\(taxhub_release\)=.*$/\1=\"${mg_taxhub_release}\"/" "${gn_dir}/config/settings.ini"
    sed -i "s/^\(nomenclature_release\)=.*$/\1=\"${mg_nomenclature_release}\"/" "${gn_dir}/config/settings.ini"
    sed -i "s/^\(habref_api_release\)=.*$/\1=\"${mg_habref_api_release}\"/" "${gn_dir}/config/settings.ini"

    printPretty "${Blink}${Red}WARNING: ${RCol}${Gra}update config to set 'drop_apps_db' to '${mg_gn_drop_db}' !${RCol}"
    sed -i "s/^\(drop_apps_db\)=.*$/\1=${mg_gn_drop_db}/" "${gn_dir}/config/settings.ini"
}

function runGeoNatureInstallDb() {
    printMsg "Installing GeoNature database..."

    printPretty "Restart Postgresql to remove all connexion to GeoNature database..." ${Gra}
    sudo systemctl restart postgresql@11-main

    printPretty "Running GeoNature install DB script..." ${Gra}
    cd "${gn_dir}/install"
    set +e
    ./install_db.sh
    set -e

    printPretty "Update config to force 'drop_apps_db' to FALSE !" ${Gra}
    sed -i "s/^drop_apps_db=.*$/drop_apps_db=false/g" "${gn_dir}/config/settings.ini"
}

function runGeoNatureInstallApp() {
    printMsg "Installing GeoNature application..."
    cd "${gn_dir}/install"
    set +e
    # Define not linked variables because they are not set in GeoNature
    export MODE="prod"
    export install_module_occhab=false
    [ -s "install_app.sh" ] && \. "install_app.sh"
    set -e
}

function prepareTaxhub() {
    local repo="TaxHub"
    printMsg "Downlading and prepare ${repo} version/archive : v${mg_taxhub_version} / ${mg_taxhub_archive} ..."
    if [[ "${mg_taxhub_version}" != ${mg_taxhub_archive} ]]; then
        local archive_file="${dwl_dir}/taxhub_v${mg_taxhub_version}_${mg_taxhub_archive:0:7}.zip"
    else
        local archive_file="${dwl_dir}/taxhub_v${mg_taxhub_version}.zip"
    fi
    if [[ ! -f "${archive_file}" ]]; then
        wget "https://github.com/PnX-SI/${repo}/archive/${mg_taxhub_archive}.zip" -O "${archive_file}"
    fi
    cd "${dwl_dir}/"
    rm -fR "${repo}-${mg_taxhub_archive}"
    unzip "${archive_file}"
    sudo chown -R $(whoami) "${taxhub_dir}/"
    rm -fR "${taxhub_dir}"
    mv "${repo}-${mg_taxhub_archive}" "${taxhub_dir}"
    sudo chown $(whoami) "${taxhub_dir}/"
}

function updateTaxhubSettings() {
    printMsg "Updating TaxHub settings..."

    printPretty "Copy 'settings.ini' from backup to new TaxHub" ${Gra}
    cp "${taxhub_backup_dir}/settings.ini" "${taxhub_dir}/settings.ini"

    printPretty "Copy 'config.py' from backup to new TaxHub" ${Gra}
    cp "${taxhub_backup_dir}/config.py" "${taxhub_dir}/config.py"

    printPretty "${Blink}${Red}WARNING: ${RCol}${Gra}update config to set 'drop_apps_db' to '${mg_gn_drop_db}' !${RCol}"
    sed -i "s/^\(drop_apps_db\)\s*=.*$/\1=${mg_gn_drop_db}/" "${taxhub_dir}/settings.ini"

    sed -i "s/^\(usershub_release\)\s*=.*$/\1=\"${mg_usershub_release}\"/" "${taxhub_dir}/settings.ini"
}

function runTaxhubInstall() {
    printMsg "Installing TaxHub application..."

    printPretty "Running TaxHub install scripts..." ${Gra}
    cd "${taxhub_dir}/"
    set +e
    . create_sys_dir.sh
    create_sys_dir

    ./install_app.sh
    set -e

    printPretty "Update 'settings.ini' to force 'drop_apps_db' to FALSE !" ${Gra}
    sed -i "s/^\(drop_apps_db\)=.*$/\1=false/" "${taxhub_dir}/settings.ini"
}

function prepareUsershub() {
    local repo="UsersHub"
    printMsg "Downlading and prepare ${repo} version/archive : v${mg_usershub_version} / ${mg_usershub_archive} ..."
    if [[ "${mg_usershub_version}" != ${mg_usershub_archive} ]]; then
        local archive_file="${dwl_dir}/usershub_v${mg_usershub_version}_${mg_usershub_archive:0:7}.zip"
    else
        local archive_file="${dwl_dir}/usershub_v${mg_usershub_version}.zip"
    fi
    if [[ ! -f "${archive_file}" ]]; then
        wget "https://github.com/PnX-SI/${repo}/archive/${mg_usershub_archive}.zip" -O "${archive_file}"
    fi
    cd "${dwl_dir}/"
    rm -fR "${repo}-${mg_usershub_archive}"
    unzip "${archive_file}"
    sudo chown -R $(whoami) "${usershub_dir}/"
    rm -fR "${usershub_dir}"
    mv "${repo}-${mg_usershub_archive}" "${usershub_dir}"
    sudo chown $(whoami) "${usershub_dir}/"
}

function updateUsershubSettings() {
    printMsg "Updating UsersHub settings..."

    printPretty "Copy 'settings.ini' from backup to new UsersHub" ${Gra}
    cp "${usershub_backup_dir}/config/settings.ini" "${usershub_dir}/config/settings.ini"

    printPretty "Copy 'config.py' from backup to new UsersHub" ${Gra}
    cp "${usershub_backup_dir}/config/config.py" "${usershub_dir}/config/config.py"

    printPretty "${Blink}${Red}WARNING: ${RCol}${Gra}Update config to set 'drop_apps_db' to '${mg_gn_drop_db}' !${RCol}"
    sed -i "s/^\(drop_apps_db\)\s*=.*$/\1=${mg_gn_drop_db}/" "${usershub_dir}/config/settings.ini"
}

function runUsershubInstall() {
    printMsg "Installing UsersHub application..."

    printPretty "Running UsersHub install scripts..." ${Gra}
    cd "${usershub_dir}/"
    set +e
    ./install_app.sh
    set -e

    printPretty "Update config to force 'drop_apps_db' to FALSE !" ${Gra}
    sed -i "s/^\(drop_apps_db\)\s*=.*$/\1=false/" "${usershub_dir}/config/settings.ini"
}

function prepareModuleSft() {
    local abr="sft"
    local repo="gn_module_suivi_flore_territoire"
    local module_dir="${modules_dir}/${abr}/"
    local module_version="${mg_sft_version}"
    local module_archive="${mg_sft_archive}"

    printMsg "Downlading and prepare ${repo} version/archive : v${module_version} / ${module_archive} ..."

    if [[ "${module_version}" != ${module_archive} ]]; then
        local archive_file="${dwl_dir}/gn-module-${abr}_v${module_version}_${module_archive:0:7}.zip"
    else
        local archive_file="${dwl_dir}/gn-module-${abr}_v${module_version}.zip"
    fi

    if [[ ! -f "${archive_file}" ]]; then
        wget "https://github.com/PnX-SI/${repo}/archive/${module_archive}.zip" -O "${archive_file}"
    fi

    cd "${dwl_dir}/"
    rm -fR "${repo}-${module_archive}"
    unzip "${archive_file}"
    sudo chown -R $(whoami) "${module_dir}/"
    rm -fR "${module_dir}"
    mv "${repo}-${module_archive}" "${module_dir}"
    sudo chown $(whoami) "${module_dir}/"
}

function updateModuleSftSettings() {
    printMsg "Updating module SFT settings..."
    local abr="sht"
    local module_dir="${modules_dir}/${abr}/"

    printPretty "Copy samples files to create new config files..."
    cp "${module_dir}/config/settings.sample.ini" "${module_dir}/config/settings.ini"
    cp "${module_dir}/config/conf_gn_module.sample.toml" "${module_dir}/config/conf_gn_module.toml"

    printPretty "Update 'conf_gn_module.toml' file parameters..."
    sed -i "s/^\(map_gpx_color\)\s*=.*$/\1 = \"magenta\"/" "${module_dir}/config/conf_gn_module.toml"

    printPretty "${Blink}${Red}WARNING: ${RCol}${Whi}update MANUALLY config files before run next step !${RCol}"
}

function runModuleSftInstall() {
    printMsg "Installing SFT module..."
    local abr="sft"
    local module_dir="${modules_dir}/${abr}/"

    cd "${gn_dir}/backend/"
    source venv/bin/activate
    geonature install_gn_module "${module_dir}" "${abr}"
}

function prepareModuleSht() {
    local abr="sht"
    local repo="gn_module_suivi_habitat_territoire"
    local module_dir="${modules_dir}/${abr}/"
    local module_version="${mg_sht_version}"
    local module_archive="${mg_sht_archive}"

    printMsg "Downlading and prepare ${repo} version/archive : v${module_version} / ${module_archive} ..."

    if [[ "${module_version}" != ${module_archive} ]]; then
        local archive_file="${dwl_dir}/gn-module-${abr}_v${module_version}_${module_archive:0:7}.zip"
    else
        local archive_file="${dwl_dir}/gn-module-${abr}_v${module_version}.zip"
    fi

    if [[ ! -f "${archive_file}" ]]; then
        wget "https://github.com/PnX-SI/${repo}/archive/${module_archive}.zip" -O "${archive_file}"
    fi

    cd "${dwl_dir}/"
    rm -fR "${repo}-${module_archive}"
    unzip "${archive_file}"
    sudo chown -R $(whoami) "${module_dir}/"
    rm -fR "${module_dir}"
    mv "${repo}-${module_archive}" "${module_dir}"
    sudo chown $(whoami) "${module_dir}/"
}

function updateModuleShtSettings() {
    printMsg "Updating module SHT settings..."
    local abr="sht"
    local module_dir="${modules_dir}/${abr}/"

    printPretty "Copy samples files to create new config files..."
    cp "${module_dir}/config/conf_gn_module.sample.toml" "${module_dir}/config/conf_gn_module.toml"
    cp "${module_dir}/config/imports_settings.sample.ini" "${module_dir}/config/imports_settings.ini"
    cp "${module_dir}/config/settings.sample.ini" "${module_dir}/config/settings.ini"

    printPretty "${Blink}${Red}WARNING: ${RCol}${Whi}update MANUALLY config files before run next step !${RCol}"
}

function runModuleShtInstall() {
    printMsg "Installing SHT module..."
    local abr="sht"
    local module_dir="${modules_dir}/${abr}/"

    cd "${gn_dir}/backend/"
    source venv/bin/activate
    geonature install_gn_module "${module_dir}" "${abr}"
}

function updateModuleShtSettingsAfterInstall() {
    printMsg "Updating'settings.ini' parameters..."

    sed -i "s/^\(insert_sample_data\)\s*=.*$/\1=\"false\"/" "${gn_dir}/config/settings.ini"
    sed -i "s/^\(db_superuser_name\)\s*=.*$/\1=\"postgres\"/" "${gn_dir}/config/settings.ini"
    sed -i "s/^\(db_superuser_pass\)\s*=.*$/\1=\"\"/" "${gn_dir}/config/settings.ini"
}

main "${@}"
