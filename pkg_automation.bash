#!/usr/bin/env bash
# shellcheck disable=SC2317
#
#  Copyright (c) 2014 - 2024    Jeong Han Lee
#
#  The program is free software: you can redistribute
#  it and/or modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation, either version 2 of the
#  License, or any newer version.
#
#  This program is distributed in the hope that it will be useful, but WITHOUT
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
#  more details.
#
#  You should have received a copy of the GNU General Public License along with
#  this program. If not, see https://www.gnu.org/licenses/gpl-2.0.txt
#
#
#  Author  : Jeong Han Lee
#  email   : jeonghan.lee@gmail.com
#  Date    : Sat 14 Aug 2021 07:40:41 PM PDT
#  version : 1.1.0
#
#   - 0.0.1  December 1 00:01 KST 2014, jhlee
#           * created
#   - 0.9.0  Monday, September 25 22:28:18 CEST 2017, jhlee
#           * completely rewrite...
#   - 0.9.1  Tuesday, September 26 09:49:56 CEST 2017, jhlee
#           * first release
#   - 0.9.2
#           * added Development tools for CentOS
#   - 0.9.3
#           * add tclx for require
#   - 0.9.4
#           * Debian 9  support
#   - 0.9.5
#           * tune CentOS pkgs - first epel-release
#   - 0.9.6
#           * add Ubuntu 16/17 supports
#   - 0.9.7
#           * add Linux Mint 18 support
#   - 0.9.8
#           * add Fedor 27
#   - 0.9.9
#           * add linux-headers-$(uname -r) in this script for Debian
#
#   - 0.9.10
#           * fix linux-headers-$(uname -r) in this script for Debian
#           * add Yes options to skip yes_or_no
#
#   - 0.9.11
#           * add Ubuntu 18 support
#
#   - 0.9.12
#          * seperate rpi from debian
#
#   - 1.0.0
#          * Updated messgages
#   - 1.0.1
#          * use N as default
#   - 1.0.2
#          * add Mint tessa
#   - 1.0.3
#          * added the systemd functions which stop, disable, and mask the service
#
#   - 1.0.4
#          * remove motif-devel in the removal list in dnf
#
#   - 1.0.5
#          * Debian 10
#
#   - 1.0.6
#          * CentOS 8 (missing darcs, tclx, blosc-devel)
#          * CentOS 8 (improved to handle CentOS8 case)
#
#   - 1.0.7
#          * Ubuntu 20
#
#   - 1.0.8
#          * Rocky 8
#
#   - 1.0.9 * CentOS7/Rocky8 switch Python 2 -> Python 3
#
#   - 1.1.0 * Debian 11
#
#   - 1.2.0 * Rocky 9
#   - 1.3.0 * Ubuntu 22
#   - 1.4.0 * Rocky 10
#

set -Eeuo pipefail

# shellcheck disable=SC2317
trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR

function error_handler {
  local exit_code="$1"
  local line_number="$2"
  local command="$3"
  printf "%s\n" "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  printf "[ERROR] Script failed at line %s\n" "$line_number"
  printf "Command: %s\n" "$command"
  printf "Exit Code: %s\n" "$exit_code"
  printf "%s\n" "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  exit "$exit_code"
}

declare -g SC_SCRIPT;
#declare -g SC_SCRIPTNAME;
declare -g SC_TOP;
declare -g SUDO_CMD;
#declare -g KERNEL_VER;


SC_SCRIPT=${BASH_SOURCE[0]:-${0}}
#SC_SCRIPTNAME=${0##*/};
SC_TOP="$( cd -P "$( dirname "$SC_SCRIPT" )" && pwd )"
#"${SC_SCRIPT%/*}"

function pushd { builtin pushd "$@" > /dev/null || exit; }
function popd  { builtin popd  > /dev/null || exit; }

if [[ ${EUID} -eq 0 ]]; then
    SUDO_CMD=""
else
    SUDO_CMD="sudo"
fi
#KERNEL_VER=$(uname -r)

. "${SC_TOP}/functions"

function sudo_exist
{
    if [[ -z "${SUDO_CMD}" ]]; then
        return 0
    fi
    if ! command -v "${SUDO_CMD}" &> /dev/null
    then
        printf "\n"
        printf ">>>>>>>>>> %s is required. Please install it first.\n" "${SUDO_CMD}"
        printf "\n"
        exit 1
    fi
}

function kill_stale_pkgmgr_pid
{
    local pid_file="$1"
    local pid_str
    local pid
    local comm

    if [[ ! -e "${pid_file}" ]]; then
        return 0
    fi

    pid_str=$(cat "${pid_file}" 2>/dev/null || true)
    if [[ ! "${pid_str}" =~ ^[1-9][0-9]*$ ]]; then
        printf "Invalid PID in %s: removing stale file\n" "${pid_file}"
        ${SUDO_CMD} rm -f -- "${pid_file}"
        return 0
    fi
    pid="${pid_str}"

    if [[ ! -r "/proc/${pid}/comm" ]]; then
        printf "PID %s no longer alive: removing stale %s\n" "${pid}" "${pid_file}"
        ${SUDO_CMD} rm -f -- "${pid_file}"
        return 0
    fi

    comm=$(cat "/proc/${pid}/comm" 2>/dev/null || true)
    case "${comm}" in
        yum|dnf|dnf-3|dnf-4|dnf-5|microdnf|PackageKit|packagekitd)
            printf "\n"
            printf ">>> Live package manager detected (PID %s, comm %s).\n" "${pid}" "${comm}"
            printf ">>> Refusing to kill. Please wait for it to finish or stop it manually,\n"
            printf ">>> then remove %s before re-running.\n" "${pid_file}"
            printf "\n"
            return 1
            ;;
        *)
            printf "PID %s runs %s (not yum/dnf): removing stale %s\n" "${pid}" "${comm}" "${pid_file}"
            ${SUDO_CMD} rm -f -- "${pid_file}"
            ;;
    esac
}

function os_release_value
{
    local target_key="$1"
    local key=""
    local value=""

    while IFS='=' read -r key value || [[ -n "${key:-}" ]]; do
        key="${key//$'\r'/}"
        value="${value//$'\r'/}"
        if [[ "${key}" != "${target_key}" ]]; then
            continue
        fi
        value="${value%\"}"
        value="${value#\"}"
        printf "%s\n" "${value}"
        return 0
    done < /etc/os-release

    return 1
}

function centos_dist
{
    os_release_value "VERSION_ID"
}

function ubuntu_dist
{
    os_release_value "VERSION_ID"
}

function macos_dist
{
    local VERSION
    VERSION=$(sw_vers -productVersion)
    printf "%s\n" "$VERSION"
}

function find_dist
{

    local dist_id dist_cn dist_rs
    local name version

    if [[ $OSTYPE == 'darwin'* ]]; then
        name=$(sw_vers -productName)
        version=$(sw_vers -productVersion)
        printf "%s %s\n" "$name" "$version"
    else
        if [[ -f /usr/bin/lsb_release ]] ; then
     	    dist_id=$(lsb_release -is)
     	    dist_cn=$(lsb_release -cs)
     	    dist_rs=$(lsb_release -rs)
            printf "%s %s %s\n" "$dist_id" "${dist_cn}" "${dist_rs}"
        else
            os_release_value "PRETTY_NAME"
        fi
    fi
}

function disable_system_service
{
    local disable_services=$1; shift

    printf "Disable service ... %s\n" "${disable_services}"
    ${SUDO_CMD} systemctl stop    "${disable_services}" 2>/dev/null || printf ">>> Stop    : %s do not exist/failed\n" "${disable_services}"
    ${SUDO_CMD} systemctl disable "${disable_services}" 2>/dev/null || printf ">>> Disable : %s do not exist/failed\n" "${disable_services}"
    ${SUDO_CMD} systemctl mask    "${disable_services}" 2>/dev/null || printf ">>> Mask    : %s do not exist/failed\n" "${disable_services}"
}

function install_tclx_centos8
{
    ${SUDO_CMD} yum install tcl-devel tk-devel

    local tclx_path=/usr/share/tcl8.6/tclx8.6

    if [[ -d "${tclx_path}" ]]; then
	printf "tclx was detected, skip it\n";
    else
	mkdir -p "${HOME}/.tclx"
	pushd "${HOME}/.tclx"
	find . -mindepth 1 -maxdepth 1 -exec "${SUDO_CMD}" rm -rf -- {} +
	git clone https://github.com/flightaware/tclx
	pushd tclx
	git checkout tags/v8.4.3
	./configure
	make
	${SUDO_CMD} make install
	${SUDO_CMD} ln -sf /usr/lib/tclx8.6/ /usr/share/tcl8.6/tclx8.6
	builtin popd > /dev/null || exit

	builtin popd > /dev/null || exit
    fi

}

function pkg_list
{
    local -a packagelist=()
    local line_data=""
    if [[ ! -f "${1}" ]]; then
        printf "WARNING: File '%s' not found.\n" "${1}" >&2
        return 0
    fi

    local i=0

    while IFS= read -r line_data || [[ -n "${line_data:-}" ]]; do
        line_data="${line_data//$'\r'/}"
        if [ "$line_data" ]; then
            if [[ "$line_data" =~ ^#.*$ ]]; then
                continue
            fi
            packagelist[i]="${line_data}"
            ((++i))
        fi
    done < "${1}"

    if (( ${#packagelist[@]} == 0 )); then
        return 0
    fi
    printf "%s\n" "${packagelist[@]}"
}

function append_pkg_file
{
    local -n target_array="$1"
    local pkg_file="$2"
    local -a file_packages=()

    mapfile -t file_packages < <(pkg_list "${pkg_file}")
    target_array+=("${file_packages[@]}")
}

function install_pkg_deb
{
    local -a pkg_list=("$@")

    sudo_exist;
    # Debian Docker, we cannot find the linux-headers,
    # Unable to locate package linux-headers-5.8.0-1033-azure
    # linux-headers are not necessary for a common application.
    # We ignore within Docker image
    ${SUDO_CMD} apt update;
    printf "\n\n";
    printf "The following package list will be installed:\n\n"
    #    if [[ ! ${KERNEL_VER} =~ "azure" ]]; then
    #        printf "%s linux-headers-%s\n\n" "${pkg_list}" "$KERNEL_VER";
    #        ${SUDO_CMD} apt -y install ${pkg_list} linux-headers-${KERNEL_VER};
    #    else
     printf "%s\n" "${pkg_list[@]}";
     printf "\n"
    ${SUDO_CMD} apt -y install "${pkg_list[@]}"
    #    fi
}

function install_pkg_ubu22
{
    local -a pkg_list=("$@")

    # Debian Docker, we cannot find the linux-headers,
    # Unable to locate package linux-headers-5.8.0-1033-azure
    # linux-headers are not necessary for a common application.
    # We ignore within Docker image
    sudo_exist;

    ${SUDO_CMD} apt -y update;
    ${SUDO_CMD} apt -y remove python2 libpython2-stdlib libpython2.7-minimal libpython2.7-stdlib python2-minimal python2.7 python2.7-minimal;
    printf "\n\n";
    printf "The following package list will be installed:\n\n"
    #    if [[ ! ${KERNEL_VER} =~ "azure" ]]; then
    #        printf "%s linux-headers-%s\n\n" "${pkg_list}" "$KERNEL_VER";
    #        ${SUDO_CMD} apt -y install ${pkg_list} linux-headers-${KERNEL_VER};
    #    else
     printf "%s\n" "${pkg_list[@]}";
     printf "\n"
    ${SUDO_CMD} apt -y install "${pkg_list[@]}"
    ${SUDO_CMD} update-alternatives --install /usr/bin/python python /usr/bin/python3  1
}

function install_pkg_ubu24
{
    local -a pkg_list=("$@")

    sudo_exist;

    ${SUDO_CMD} apt -y update;
    printf "\n\n";
    printf "The following package list will be installed:\n\n"
    printf "%s\n" "${pkg_list[@]}";
    printf "\n"
    ${SUDO_CMD} apt -y install "${pkg_list[@]}"
    ${SUDO_CMD} update-alternatives --install /usr/bin/python python /usr/bin/python3  1
}

function install_pkg_deb10
{
    local -a pkg_list=("$@")
    sudo_exist;

    # Debian Docker, we cannot find the linux-headers,
    # Unable to locate package linux-headers-5.8.0-1033-azure
    # linux-headers are not necessary for a common application.
    # We ignore within Docker image
    ${SUDO_CMD} apt -y update;
    printf "\n\n";
    printf "The following package list will be installed:\n\n"
    #    if [[ ! ${KERNEL_VER} =~ "azure" ]]; then
    #        printf "%s linux-headers-%s\n\n" "${pkg_list}" "$KERNEL_VER";
    #        ${SUDO_CMD} apt -y install ${pkg_list} linux-headers-${KERNEL_VER};
    #    else
     printf "%s\n" "${pkg_list[@]}";
     printf "\n"
    ${SUDO_CMD} apt -y install "${pkg_list[@]}"
    #    fi
    ${SUDO_CMD} update-alternatives --install /usr/bin/python python /usr/bin/python3 3
}

function install_pkg_deb11
{
    local -a pkg_list=("$@")
    sudo_exist;
    # Debian Docker, we cannot find the linux-headers,
    # Unable to locate package linux-headers-5.8.0-1033-azure
    # linux-headers are not necessary for a common application.
    # We ignore within Docker image

    ${SUDO_CMD} apt -y update;
    ${SUDO_CMD} apt -y remove python2 libpython2-stdlib libpython2.7-minimal libpython2.7-stdlib python2-minimal python2.7 python2.7-minimal;
    printf "\n\n";
    printf "The following package list will be installed:\n\n"
    #    if [[ ! ${KERNEL_VER} =~ "azure" ]]; then
    #        printf "%s linux-headers-%s\n\n" "${pkg_list}" "$KERNEL_VER";
    #        ${SUDO_CMD} apt -y install ${pkg_list} linux-headers-${KERNEL_VER};
    #    else
    printf "%s\n" "${pkg_list[@]}";
    printf "\n"
    ${SUDO_CMD} apt -y install "${pkg_list[@]}"
    ${SUDO_CMD} update-alternatives --install /usr/bin/python python /usr/bin/python3  1
}

function install_pkg_deb12
{
    local -a pkg_list=("$@")
    sudo_exist;
    # Debian Docker, we cannot find the linux-headers,
    # Unable to locate package linux-headers-5.8.0-1033-azure
    # linux-headers are not necessary for a common application.
    # We ignore within Docker image

    ${SUDO_CMD} apt -y update;
    printf "\n\n";
    printf "The following package list will be installed:\n\n"
    #    if [[ ! ${KERNEL_VER} =~ "azure" ]]; then
    #        printf "%s linux-headers-%s\n\n" "${pkg_list}" "$KERNEL_VER";
    #        ${SUDO_CMD} apt -y install ${pkg_list} linux-headers-${KERNEL_VER};
    #    else
     printf "%s\n" "${pkg_list[@]}";
     printf "\n"
    ${SUDO_CMD} apt -y install "${pkg_list[@]}"
    ${SUDO_CMD} update-alternatives --install /usr/bin/python python /usr/bin/python3  1
}

function install_pkg_deb13
{
    local -a pkg_list=("$@")
    sudo_exist;
    ${SUDO_CMD} apt -y update;
    if dpkg -s exuberant-ctags >/dev/null 2>&1; then
        ${SUDO_CMD} apt -y remove exuberant-ctags;
    fi
    printf "\n\n";
    printf "The following package list will be installed:\n\n"
    printf "%s\n" "${pkg_list[@]}";
    printf "\n"
    ${SUDO_CMD} apt -y install "${pkg_list[@]}"
}

function install_pkg_rpi
{
    local -a pkg_list=("$@")
    sudo_exist;
    printf "\n\n";
    printf "The following package list will be installed:\n\n"
    printf "%s\n" "${pkg_list[@]}" "raspberrypi-kernel-headers";
    printf "\n\n"

    ${SUDO_CMD} apt-get update
    ${SUDO_CMD} apt-get -y install "${pkg_list[@]}" raspberrypi-kernel-headers
}

function install_pkg_dnf
{
    local -a pkg_list=("$@")
    printf "\n";
    printf "%s\n" "${pkg_list[@]}";
    printf "\n\n\n"
    declare -r yum_pid="/var/run/yum.pid"
    sudo_exist;

    disable_system_service packagekit
    disable_system_service firewalld

    # PackageKit may leave a stale yum/dnf pid; validate before killing.
    kill_stale_pkgmgr_pid "${yum_pid}"

    ${SUDO_CMD} dnf -y remove PackageKit firewalld;
    ${SUDO_CMD} dnf -y update;
    ${SUDO_CMD} dnf -y groupinstall "Development tools"
    ${SUDO_CMD} dnf -y install "${pkg_list[@]}";
}

# CentOS8 yum is the same as dnf
# ls -ltar /usr/bin/{dnf,yum}
# lrwxrwxrwx. 1 root root 5 May 13 21:34 /usr/bin/yum -> dnf-3
# lrwxrwxrwx. 1 root root 5 May 13 21:34 /usr/bin/dnf -> dnf-3
# so, it may be possible to merge them together with dnf
#
function install_pkg_rpm
{
    local -a pkg_list=("${@:1:$(($# - 1))}")
    local version="${!#}"
    printf "\n";
    printf "%s\n" "${pkg_list[@]}";
    printf "\n\n\n"

    declare -r yum_pid="/var/run/yum.pid"

    local -a pkgs_should_be_removed=("PackageKit" "firewalld")
    sudo_exist;
    disable_system_service packagekit
    disable_system_service firewalld

    # PackageKit may leave a stale yum/dnf pid; validate before killing.
    kill_stale_pkgmgr_pid "${yum_pid}"

    if [ "$version" == "8" ]; then
	    ${SUDO_CMD} yum -y install dnf-plugins-core;
        ${SUDO_CMD} yum -y update;
        ${SUDO_CMD} yum config-manager --set-enabled powertools;
    else
	pkgs_should_be_removed+=("motif-devel")

    fi
    printf "The following packages are being removed ....\n"
    ${SUDO_CMD} yum -y remove "${pkgs_should_be_removed[@]}"
    ${SUDO_CMD} yum -y update;
    ${SUDO_CMD} yum -y upgrade ca-certificates
    ${SUDO_CMD} yum -y groupinstall "Development tools"
    ${SUDO_CMD} yum -y install "epel-release"
    ${SUDO_CMD} yum -y update;
    ${SUDO_CMD} yum -y install "${pkg_list[@]}";
    # Set Python3 as default
    #
    if [[ "$version" == "7" || "$version" == *"7."* ]]; then
    	${SUDO_CMD} yum -y install python3;
    	${SUDO_CMD} alternatives --install /usr/bin/python python /usr/bin/python2 50
    	${SUDO_CMD} alternatives --install /usr/bin/python python /usr/bin/python3.6 60
    	${SUDO_CMD} alternatives --auto python
    	${SUDO_CMD} sed -i '1!b;s/python/python2.7/' /usr/bin/yum
    	${SUDO_CMD} sed -i '1!b;s/python/python2.7/' /usr/libexec/urlgrabber-ext-down
    fi
}

function install_ctags_from_source
{
    local build_dir
    local ctags_repo="https://github.com/universal-ctags/ctags.git"

    printf "Universal-ctags not found. Starting source build...\n"

    ${SUDO_CMD} dnf -y install autoconf automake pkgconfig gcc make libtool

    build_dir="$(mktemp -d -t ctags_build.XXXXXXXX)"

    git clone "${ctags_repo}" "${build_dir}"
    cd "${build_dir}"

    ./autogen.sh
    ./configure --prefix=/usr/local
    make
    ${SUDO_CMD} make install

    cd - > /dev/null
    rm -rf -- "${build_dir}"
}

function install_pkg_rocky8
{
    local -a pkg_list=("$@")
    printf "\n";
    printf "%s\n" "${pkg_list[@]}";
    printf "\n\n\n"
    declare -r yum_pid="/var/run/yum.pid"

    sudo_exist;

    disable_system_service packagekit
    disable_system_service firewalld

    # PackageKit may leave a stale yum/dnf pid; validate before killing.
    kill_stale_pkgmgr_pid "${yum_pid}"
    ${SUDO_CMD} dnf -y install dnf-plugins-core;
    ${SUDO_CMD} dnf -y update;
    ${SUDO_CMD} dnf -y config-manager --set-enabled powertools
    ${SUDO_CMD} dnf -y update;
    ${SUDO_CMD} dnf -y remove PackageKit firewalld;
    ${SUDO_CMD} dnf -y update;
    ${SUDO_CMD} dnf -y groupinstall "Development tools"
    ${SUDO_CMD} dnf -y install "epel-release"
    ${SUDO_CMD} dnf -y update;
    ${SUDO_CMD} dnf -y install "${pkg_list[@]}";
    if ! command -v ctags >/dev/null 2>&1; then
        install_ctags_from_source
    fi
}

function install_pkg_rocky9
{
    local -a pkg_list=("$@")
    printf "\n";
    printf "%s\n" "${pkg_list[@]}";
    printf "\n\n\n"
    declare -r yum_pid="/var/run/yum.pid"

    sudo_exist;

    disable_system_service packagekit
    disable_system_service firewalld

    # PackageKit may leave a stale yum/dnf pid; validate before killing.
    kill_stale_pkgmgr_pid "${yum_pid}"
    ${SUDO_CMD} dnf -y install dnf-plugins-core;
    ${SUDO_CMD} dnf -y update;
## https://wiki.rockylinux.org/rocky/repo/#extra-repositories
## PowerTools does not exist, so we have to find out several packages
## I think, it needs some time to show up in somewhere, that is always the Redhat does
##

    ${SUDO_CMD} dnf -y config-manager --set-enabled crb
    ${SUDO_CMD} dnf -y update;
    ${SUDO_CMD} dnf -y remove PackageKit firewalld;
    ${SUDO_CMD} dnf -y update;
    ${SUDO_CMD} dnf -y groupinstall "Development tools"
    ${SUDO_CMD} dnf -y install "epel-release"
    ${SUDO_CMD} dnf -y update;
    ${SUDO_CMD} dnf -y install "${pkg_list[@]}";
}

function install_pkg_rocky10
{
    local -a pkg_list=("$@")
    printf "\n";
    printf "%s\n" "${pkg_list[@]}";
    printf "\n\n\n"
    declare -r yum_pid="/var/run/yum.pid"

    sudo_exist;

    disable_system_service packagekit
    disable_system_service firewalld

    # PackageKit may leave a stale yum/dnf pid; validate before killing.
    kill_stale_pkgmgr_pid "${yum_pid}"
    ${SUDO_CMD} dnf -y install dnf-plugins-core;
    ${SUDO_CMD} dnf -y update;
## https://wiki.rockylinux.org/rocky/repo/#extra-repositories
## PowerTools does not exist, so we have to find out several packages
## I think, it needs some time to show up in somewhere, that is always the Redhat does
##
    ${SUDO_CMD} dnf -y config-manager --set-enabled crb
    ${SUDO_CMD} dnf -y update;
    ${SUDO_CMD} dnf -y remove PackageKit firewalld;
    ${SUDO_CMD} dnf -y update;
    ${SUDO_CMD} dnf -y groupinstall "Development tools"
    ${SUDO_CMD} dnf -y install "epel-release"
    ${SUDO_CMD} dnf -y update;
    ${SUDO_CMD} dnf -y install "${pkg_list[@]}";
}

function install_pkg_macos11
{
    local -a pkg_list=("$@")
    printf "\n";
    printf "%s\n" "${pkg_list[@]}";
    printf "\n\n\n"

    local command="brew"
    ${command} install "${pkg_list[@]}";
    #
    # net-snmp-config in /usr/bin has very strange codes, so we have to overwrite it with brew net-snmp
    # 2023-08-21
    printf "\n";
    printf ">>> brew upgrade, and reconfigure net-snmp\n"
    ${command} upgrade
    ${command} reinstall net-snmp
    ${command} link --force --overwrite net-snmp
    net-snmp-config --cflags
}

function warn_unsupported_target
{
    local label="$1"
    printf "\n"
    printf ">>> WARNING: %s is not in the supported-target list (see README).\n" "${label}"
    printf ">>> This installation path is not actively maintained.\n"
    printf "\n"
}

function yes_or_no_to_go
{
    local answer=""

    printf  "> \n";
    printf  "> This procedure could help to install    \n"
    printf  "> required packages for EPICS installation\n"
    printf  "> and others.\n";
    printf  "> \n";
    printf  "> %s\n" "$1";
    printf ">> Do you want to continue (y/N)? "
    if ! read -r answer; then
        printf "\n>> Non-interactive stdin detected. Use -y to bypass the prompt.\n";
        exit 1;
    fi
    case ${answer:0:1} in
	y|Y )
	    printf ">> The following packages will be installed ...... ";
	    ;;
	* )
        printf ">> One should install all required packages by oneself. Stop here.\n";
	    exit;
    ;;
    esac
}

declare -a PKG_DEB_ARRAY
declare -a PKG_DEB9_ARRAY
declare -a PKG_DEB10_ARRAY
declare -a PKG_DEB11_ARRAY
declare -a PKG_DEB12_ARRAY
declare -a PKG_DEB13_ARRAY
#
declare -a PKG_RPI_ARRAY
#
declare -a PKG_UBU16_ARRAY
declare -a PKG_UBU20_ARRAY
declare -a PKG_UBU22_ARRAY
declare -a PKG_UBU24_ARRAY
#
declare -a PKG_RPM_ARRAY
declare -a PKG_CENTOS8_ARRAY
declare -a PKG_DNF_ARRAY
declare -a PKG_ROCKY8_ARRAY
declare -a PKG_ROCKY9_ARRAY
declare -a PKG_ROCKY10_ARRAY
#
declare -a PKG_MACOS11_ARRAY

declare -g COM_PATH="${SC_TOP}/pkg-common"
#
declare -g DEB_PATH="${SC_TOP}/pkg-deb"
declare -g DEB9_PATH="${SC_TOP}/pkg-deb9"
declare -g DEB10_PATH="${SC_TOP}/pkg-deb10"
declare -g DEB11_PATH="${SC_TOP}/pkg-deb11"
declare -g DEB12_PATH="${SC_TOP}/pkg-deb12"
declare -g DEB13_PATH="${SC_TOP}/pkg-deb13"
#
declare -g RPI_PATH="${SC_TOP}/pkg-rpi"
#
declare -g UBU16_PATH="${SC_TOP}/pkg-ubu16"
declare -g UBU20_PATH="${SC_TOP}/pkg-ubu20"
declare -g UBU22_PATH="${SC_TOP}/pkg-ubu22"
declare -g UBU24_PATH="${SC_TOP}/pkg-ubu24"
#
declare -g RPM_PATH="${SC_TOP}/pkg-rpm"
declare -g CENTOS8_PATH="${SC_TOP}/pkg-centos8"
declare -g DNF_PATH="${SC_TOP}/pkg-dnf"
declare -g ROCKY8_PATH="${SC_TOP}/pkg-rocky8"
declare -g ROCKY9_PATH="${SC_TOP}/pkg-rocky9"
declare -g ROCKY10_PATH="${SC_TOP}/pkg-rocky10"
#
declare -g MACOS11_PATH="${SC_TOP}/pkg-macos11"
#
declare -ga pkg_deb_list
declare -ga pkg_deb9_list
declare -ga pkg_deb10_list
declare -ga pkg_deb11_list
declare -ga pkg_deb12_list
declare -ga pkg_deb13_list
#
declare -ga pkg_rpi_list
#
declare -ga pkg_ubu16_list
declare -ga pkg_ubu20_list
declare -ga pkg_ubu22_list
declare -ga pkg_ubu24_list
#
declare -ga pkg_rpm_list
declare -ga pkg_centos8_list
#
declare -ga pkg_dnf_list
declare -ga pkg_rocky8_list
declare -ga pkg_rocky9_list
declare -ga pkg_rocky10_list
#
declare -ga pkg_macos11_list

#
pkg_deb_list=("epics" "extra")
pkg_deb9_list=("epics" "extra")
pkg_deb10_list=("common" "epics" "extra")
pkg_deb11_list=("common" "epics" "extra")
pkg_deb12_list=("common" "epics" "extra")
pkg_deb13_list=("common" "epics" "extra")
#
pkg_rpi_list=("epics" "extra")
#
pkg_ubu16_list=("epics" "extra")
pkg_ubu20_list=("epics" "extra")
pkg_ubu22_list=("epics" "extra")
pkg_ubu24_list=("common" "epics" "extra")
#
pkg_rpm_list=("epics" "extra")
pkg_centos8_list=("common" "epics" "extra")
pkg_dnf_list=("epics" "extra")
pkg_rocky8_list=("common" "epics" "extra")
pkg_rocky9_list=("common" "epics" "extra")
pkg_rocky10_list=("common" "epics" "extra")
#
pkg_macos11_list=("epics")
#
append_pkg_file PKG_DEB_ARRAY "${COM_PATH}/common"

for deb_file in "${pkg_deb_list[@]}"; do
    append_pkg_file PKG_DEB_ARRAY "${DEB_PATH}/${deb_file}"
done

append_pkg_file PKG_DEB9_ARRAY "${COM_PATH}/common"
for deb_file in "${pkg_deb9_list[@]}"; do
    append_pkg_file PKG_DEB9_ARRAY "${DEB9_PATH}/${deb_file}"
done
# Debian 10 (Buster)
for deb_file in "${pkg_deb10_list[@]}"; do
    append_pkg_file PKG_DEB10_ARRAY "${DEB10_PATH}/${deb_file}"
done
# Debian 11 (Bullseye)
for deb_file in "${pkg_deb11_list[@]}"; do
    append_pkg_file PKG_DEB11_ARRAY "${DEB11_PATH}/${deb_file}"
done
# Debian 12 (bookworm)
for deb_file in "${pkg_deb12_list[@]}"; do
    append_pkg_file PKG_DEB12_ARRAY "${DEB12_PATH}/${deb_file}"
done
# Debian 13 (trixie)
append_pkg_file PKG_DEB13_ARRAY "${COM_PATH}/common"
for deb_file in "${pkg_deb13_list[@]}"; do
    append_pkg_file PKG_DEB13_ARRAY "${DEB13_PATH}/${deb_file}"
done
#
append_pkg_file PKG_RPI_ARRAY "${COM_PATH}/common"
for deb_file in "${pkg_rpi_list[@]}"; do
    append_pkg_file PKG_RPI_ARRAY "${RPI_PATH}/${deb_file}"
done
#
append_pkg_file PKG_UBU16_ARRAY "${COM_PATH}/common"
for deb_file in "${pkg_ubu16_list[@]}"; do
    append_pkg_file PKG_UBU16_ARRAY "${UBU16_PATH}/${deb_file}"
done
#
append_pkg_file PKG_UBU20_ARRAY "${COM_PATH}/common"
for deb_file in "${pkg_ubu20_list[@]}"; do
    append_pkg_file PKG_UBU20_ARRAY "${UBU20_PATH}/${deb_file}"
done
#
append_pkg_file PKG_UBU22_ARRAY "${COM_PATH}/common"
for deb_file in "${pkg_ubu22_list[@]}"; do
    append_pkg_file PKG_UBU22_ARRAY "${UBU22_PATH}/${deb_file}"
done

append_pkg_file PKG_UBU24_ARRAY "${COM_PATH}/common"
for deb_file in "${pkg_ubu24_list[@]}"; do
    append_pkg_file PKG_UBU24_ARRAY "${UBU24_PATH}/${deb_file}"
done

append_pkg_file PKG_RPM_ARRAY "${COM_PATH}/common"
for rpm_file in "${pkg_rpm_list[@]}"; do
    append_pkg_file PKG_RPM_ARRAY "${RPM_PATH}/${rpm_file}"
done
#
for rpm_file in "${pkg_centos8_list[@]}"; do
    append_pkg_file PKG_CENTOS8_ARRAY "${CENTOS8_PATH}/${rpm_file}"
done
#
append_pkg_file PKG_DNF_ARRAY "${COM_PATH}/common"
for dnf_file in "${pkg_dnf_list[@]}"; do
    append_pkg_file PKG_DNF_ARRAY "${DNF_PATH}/${dnf_file}"
done

# Rocky 8.4
for rocky_file in "${pkg_rocky8_list[@]}"; do
    append_pkg_file PKG_ROCKY8_ARRAY "${ROCKY8_PATH}/${rocky_file}"
done
# Rocky 9.0
for rocky9_file in "${pkg_rocky9_list[@]}"; do
    append_pkg_file PKG_ROCKY9_ARRAY "${ROCKY9_PATH}/${rocky9_file}"
done
# Rocky 10.0
for rocky10_file in "${pkg_rocky10_list[@]}"; do
    append_pkg_file PKG_ROCKY10_ARRAY "${ROCKY10_PATH}/${rocky10_file}"
done
#
for brew_file in "${pkg_macos11_list[@]}"; do
    append_pkg_file PKG_MACOS11_ARRAY "${MACOS11_PATH}/${brew_file}"
done

ANSWER="NO"

while getopts ":y" opt; do
    case ${opt} in
	y)
	    ANSWER="YES"
	    ;;
	\?)
	    printf "Invalid option: -%s\n" "${OPTARG}" >&2
	    exit;
	    ;;
    esac
done
dist=$(find_dist)

printf "Distribution is >>>%s<<<\n" "${dist}"

case "$dist" in
    Raspbian*)
	warn_unsupported_target "$dist"
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Raspbian is detected as $dist"
	fi
	install_pkg_rpi "${PKG_RPI_ARRAY[@]}"
	;;
    *jessie*)
	warn_unsupported_target "$dist"
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Debian jessie is detected as $dist"
	fi
	install_pkg_deb "${PKG_DEB_ARRAY[@]}"
	;;
    *stretch*)
	warn_unsupported_target "$dist"
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Debian stretch is detected as $dist"
	fi
	install_pkg_deb "${PKG_DEB9_ARRAY[@]}"
	;;
    *buster*)
	warn_unsupported_target "$dist"
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Debian 10 (Buster) is detected as $dist"
	fi
	install_pkg_deb10 "${PKG_DEB10_ARRAY[@]}"
	;;
    *bullseye*)
        warn_unsupported_target "$dist"
        if [ "$ANSWER" == "NO" ]; then
            yes_or_no_to_go "Debian 11 (Bullseye) is detected as $dist"
        fi
        install_pkg_deb11 "${PKG_DEB11_ARRAY[@]}"
        ;;
    *bookworm*)
        if [ "$ANSWER" == "NO" ]; then
            yes_or_no_to_go "Debian 12 (bookworm) is detected as $dist"
        fi
        install_pkg_deb12 "${PKG_DEB12_ARRAY[@]}"
        ;;
    *trixie*)
        if [ "$ANSWER" == "NO" ]; then
            yes_or_no_to_go "Debian 13 (trixie) is detected as $dist"
        fi
        install_pkg_deb13 "${PKG_DEB13_ARRAY[@]}"
        ;;
    *CentOS* | *Scientific* )
	warn_unsupported_target "$dist"
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "CentOS or Scientific is detected as $dist";
	fi
	centos_version=$(centos_dist)
	if [ "$centos_version" == "8" ]; then
	    printf "%s\n" "$centos_version"
	    install_pkg_rpm "${PKG_CENTOS8_ARRAY[@]}" "${centos_version}"
#	    install_tclx_centos8
	else
	    install_pkg_rpm "${PKG_RPM_ARRAY[@]}"  "${centos_version}"
	fi
	;;

    *Rocky* | *Alma* )
    if [[ "${dist}" == *Alma* ]]; then
        warn_unsupported_target "$dist"
    fi
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Rocky or Alma is detected as $dist";
    fi

    rocky_version=$(centos_dist)

	if [[ "$rocky_version" =~ .*"8.".* ]]; then
        install_pkg_rocky8 "${PKG_ROCKY8_ARRAY[@]}"
	elif [[ "$rocky_version" =~ .*"9.".* ]]; then
        install_pkg_rocky9 "${PKG_ROCKY9_ARRAY[@]}"
  elif [[ "$rocky_version" =~ .*"10.".* ]]; then
    install_pkg_rocky10 "${PKG_ROCKY10_ARRAY[@]}"
	else
        printf "\n";
	    printf "Doesn't support %s\n" "$dist";
        printf "\n";
        exit 1;
    fi
	;;

    *xenial*)
	warn_unsupported_target "$dist"
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Ubuntu xenial is detected as $dist";
	fi
	install_pkg_deb "${PKG_UBU16_ARRAY[@]}"
	;;

    *artful*)
	warn_unsupported_target "$dist"
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Ubuntu artful is detected as $dist";
	fi
	install_pkg_deb "${PKG_UBU16_ARRAY[@]}"
	;;
    *bionic*)
	warn_unsupported_target "$dist"
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Ubuntu bionic is detected as $dist";
	fi
	install_pkg_deb "${PKG_UBU16_ARRAY[@]}"
	;;

    *focal*)
	warn_unsupported_target "$dist"
	if [ "$ANSWER" == "NO" ]; then
        	yes_or_no_to_go "Ubuntu focal is detected as $dist";
    fi
    install_pkg_deb "${PKG_UBU20_ARRAY[@]}"
    ;;

    *Ubuntu*)
    ubuntu_version=$(ubuntu_dist)
    if [ "$ANSWER" == "NO" ]; then
        yes_or_no_to_go "Ubuntu is detected as $dist"
    fi
    if [[ "$ubuntu_version" =~ .*"22.".* ]]; then
    install_pkg_ubu22 "${PKG_UBU22_ARRAY[@]}"
    elif [[ "$ubuntu_version" =~ .*"24.".* ]]; then
    install_pkg_ubu24 "${PKG_UBU24_ARRAY[@]}"
    else
        printf "\n";
        printf "Doesn't support %s : %s\n" "$dist" "$ubuntu_version";
        printf "\n";
        exit 1;
    fi
    ;;
    *sylvia*)
	warn_unsupported_target "$dist"
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Linux Mint sylvia is detected as $dist";
	fi
	install_pkg_deb "${PKG_UBU16_ARRAY[@]}"
	;;

    *tara*)
	warn_unsupported_target "$dist"
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Linux Mint tara is detected as $dist";
	fi
	install_pkg_deb "${PKG_UBU16_ARRAY[@]}"
	;;

    *tessa*)
	warn_unsupported_target "$dist"
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Linux Mint tessa is detected as $dist";
	fi
	install_pkg_deb "${PKG_UBU16_ARRAY[@]}"
	;;

    *Fedora*)
	warn_unsupported_target "$dist"
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Linux Fedora is detected as $dist";
	fi
	install_pkg_dnf "${PKG_DNF_ARRAY[@]}";
	;;

    *macOS*)
	warn_unsupported_target "$dist"
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "macOS is detected as $dist";
	fi
#	install_pkg_macos11 "${PKG_MACOS11_ARRAY[@]}";
	macos_version=$(macos_dist)
	if [[ "$macos_version" =~ .*"11.".* ]]; then
	    printf "%s\n" "$macos_version"
	    install_pkg_macos11 "${PKG_MACOS11_ARRAY[@]}";
	elif [[ "$macos_version" =~ .*"12.".* ]]; then
        printf "%s\n" "$macos_version"
		install_pkg_macos11 "${PKG_MACOS11_ARRAY[@]}";
	elif [[ "$macos_version" =~ .*"13.".* ]]; then
        printf "%s\n" "$macos_version"
		install_pkg_macos11 "${PKG_MACOS11_ARRAY[@]}";
	elif [[ "$macos_version" =~ .*"14.".* ]]; then
        printf "%s\n" "$macos_version"
		install_pkg_macos11 "${PKG_MACOS11_ARRAY[@]}";
	else
        printf "\n";
	    printf "Doesn't support yet %s\n" "$dist";
        printf "\n";
        exit 1;
	fi
	;;

    *)
	printf "----------------------------------\n";
	printf ">> Doesn't support the detected %s\n" "$dist";
	printf ">> Please contact jeonghan.lee@gmail.com or feel free to do pull requests.\n";
	printf "\n";
	exit 1;
	;;
esac

exit 0
