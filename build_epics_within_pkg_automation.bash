#!/usr/bin/env bash
#
#  author  : Jeong Han Lee
#  email   : jeonghan.lee@gmail.com
#  version : 0.0.3

set -Eeuo pipefail

# shellcheck disable=SC2317
trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR

function error_handler {
    local exit_code="$1"
    local line_number="$2"
    local command="$3"
    printf "%s\n" "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    printf "[ERROR] build helper failed at line %s\n" "${line_number}"
    printf "Command: %s\n" "${command}"
    printf "Exit Code: %s\n" "${exit_code}"
    printf "%s\n" "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit "${exit_code}"
}

function pushd { builtin pushd "$@" > /dev/null || exit; }
function popd  { builtin popd  > /dev/null || exit; }

INSTALL_LOCATION="${1:-/usr/local}"

# this script must be called where Dockerfile exists
#
pushd "${PWD}" || exit 1

if [[ -e EPICS-env ]]; then
    printf "EPICS-env already present in %s; refusing to overwrite\n" "${PWD}" >&2
    exit 1
fi

git clone https://github.com/jeonghanlee/EPICS-env
printf "INSTALL_LOCATION:=%s\n" "${INSTALL_LOCATION}" > CONFIG_SITE.local
make -s -C EPICS-env/ init
make -s -C EPICS-env/ conf
make -s -C EPICS-env/ patch

epics_path=$(make -s -C EPICS-env/ print-INSTALL_LOCATION_EPICS)
base_path=$(make -s -C EPICS-env/ print-INSTALL_LOCATION_BASE)
modules_path=$(make -s -C EPICS-env/ print-INSTALL_LOCATION_MODS)
epics_vers=$(make -s -C EPICS-env/ print-PATH_NAME_EPICSVERS)

for v in epics_path base_path modules_path epics_vers; do
    if [[ -z "${!v}" ]]; then
        printf "EPICS-env make print returned empty for %s\n" "${v}" >&2
        exit 1
    fi
done

symlink_epics_path="${INSTALL_LOCATION}/epics/R${epics_vers}"

make -s -C EPICS-env/ build
make -s -C EPICS-env/ install
make -s -C EPICS-env/ symlinks.modules

mkdir -p "${symlink_epics_path}"
pushd "${symlink_epics_path}" || exit 1
ln -snf "${epics_path}/setEpicsEnv.bash" setEpicsEnv.bash
ln -snf "${base_path}" base
ln -snf "${modules_path}" module
popd || exit 1
popd || exit 1
