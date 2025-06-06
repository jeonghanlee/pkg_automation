#!/usr/bin/env bash
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
#
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

SUDO_CMD="sudo"
#KERNEL_VER=$(uname -r)

. ${SC_TOP}/functions

function sudo_exist
{
    if ! command -v ${SUDO_CMD} &> /dev/null
    then
        echo ""
        echo ">>>>>>>>>> ${SUDO_CMD} is required. Please install it first."
        echo ""
        exit 1
    fi
}

function centos_dist
{
    local VERSION_ID
    eval $(cat /etc/os-release | grep -E "^(VERSION_ID)=")
    echo ${VERSION_ID}
}

function ubuntu_dist
{
    local VERSION_ID
    eval $(cat /etc/os-release | grep -E "^(VERSION_ID)=")
    echo ${VERSION_ID}
}

function macos_dist
{
    local VERSION
    VERSION=$(sw_vers -productVersion)
    echo "$VERSION"
}

function find_dist
{

    local dist_id dist_cn dist_rs PRETTY_NAME
    local name version

    if [[ $OSTYPE == 'darwin'* ]]; then
        name=$(sw_vers -productName)
        version=$(sw_vers -productVersion)
        echo "$name" "$version"
    else
        if [[ -f /usr/bin/lsb_release ]] ; then
     	    dist_id=$(lsb_release -is)
     	    dist_cn=$(lsb_release -cs)
     	    dist_rs=$(lsb_release -rs)
     	    echo "$dist_id" "${dist_cn}" "${dist_rs}"
        else 
            # shellcheck disable=SC2046 disable=SC2002
     	    eval $(cat /etc/os-release | grep -E "^(PRETTY_NAME)=")
            # shellcheck disable=SC2086
            echo "${PRETTY_NAME}"
        fi
    fi
}

function disable_system_service
{
    local disable_services=$1; shift
    
    printf "Disable service ... %s\n" "${disable_services}"
    ${SUDO_CMD} systemctl stop    ${disable_services} | echo ">>> Stop    : $disable_services do not exist"
    ${SUDO_CMD} systemctl disable ${disable_services} | echo ">>> Disalbe : $disable_services do not exist"
    ${SUDO_CMD} systemctl mask    ${disable_services} | echo ">>> Mask    : $disable_services do not exist"

}

function install_tclx_centos8
{
    ${SUDO_CMD} yum install tcl-devel tk-devel

    local tclx_path=/usr/share/tcl8.6/tclx8.6

    if [[ -d $tclx_path ]]; then
	printf "tclx was detected, skip it\n";
    else
	mkdir -p ${HOME}/.tclx
	pushd ${HOME}/.tclx
	${SUDO_CMD} rm -rf *
	git clone https://github.com/flightaware/tclx
	pushd tclx
	git checkout tags/v8.4.3
	./configure
	make
	${SUDO_CMD} make install
	${SUDO_CMD} ln -sf /usr/lib/tclx8.6/ /usr/share/tcl8.6/tclx8.6
	popd
	
	popd
    fi

}

function pkg_list
{
    local i
    let i=0
    while IFS= read -r line_data; do
	if [ "$line_data" ]; then
	    # Skip command #
	    [[ "$line_data" =~ ^#.*$ ]] && continue
	    packagelist[i]="${line_data}"
	    ((++i))
	fi
    done < ${1}
    echo ${packagelist[@]}
}

function install_pkg_deb
{
    declare -a pkg_list=${1}

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
     printf "%s\n\n" "${pkg_list}";
    ${SUDO_CMD} apt -y install ${pkg_list}
    #    fi
}

function install_pkg_ubu22
{
    declare -a pkg_list=${1}

    # Debian Docker, we cannot find the linux-headers,
    # Unable to locate package linux-headers-5.8.0-1033-azure
    # linux-headers are not necessary for a common application.
    # We ignore within Docker image
    sudo_exist;

    ${SUOD_CMD} apt -y update;
    ${SUDO_CMD} apt -y remove python2 libpython2-stdlib libpython2.7-minimal libpython2.7-stdlib python2-minimal python2.7 python2.7-minimal;
    printf "\n\n";   
    printf "The following package list will be installed:\n\n"
    #    if [[ ! ${KERNEL_VER} =~ "azure" ]]; then
    #        printf "%s linux-headers-%s\n\n" "${pkg_list}" "$KERNEL_VER";
    #        ${SUDO_CMD} apt -y install ${pkg_list} linux-headers-${KERNEL_VER};
    #    else
     printf "%s\n\n" "${pkg_list}";
    ${SUDO_CMD} apt -y install ${pkg_list}
    ${SUDO_CMD} update-alternatives --install /usr/bin/python python /usr/bin/python3  1
}

function install_pkg_ubu24
{
    declare -a pkg_list=${1}

    sudo_exist;

    ${SUOD_CMD} apt -y update;
    printf "\n\n";   
    printf "The following package list will be installed:\n\n"
    printf "%s\n\n" "${pkg_list}";
    ${SUDO_CMD} apt -y install ${pkg_list}
    ${SUDO_CMD} update-alternatives --install /usr/bin/python python /usr/bin/python3  1
}

function install_pkg_deb10
{
    declare -a pkg_list=${1}
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
     printf "%s\n\n" "${pkg_list}";
    ${SUDO_CMD} apt -y install ${pkg_list}
    #    fi
    ${SUDO_CMD} update-alternatives --install /usr/bin/python python /usr/bin/python3 3
}

function install_pkg_deb11
{
    declare -a pkg_list=${1}
    sudo_exist;
    # Debian Docker, we cannot find the linux-headers,
    # Unable to locate package linux-headers-5.8.0-1033-azure
    # linux-headers are not necessary for a common application.
    # We ignore within Docker image

    ${SUOD_CMD} apt -y update;
    ${SUDO_CMD} apt -y remove python2 libpython2-stdlib libpython2.7-minimal libpython2.7-stdlib python2-minimal python2.7 python2.7-minimal;
    printf "\n\n";   
    printf "The following package list will be installed:\n\n"
    #    if [[ ! ${KERNEL_VER} =~ "azure" ]]; then
    #        printf "%s linux-headers-%s\n\n" "${pkg_list}" "$KERNEL_VER";
    #        ${SUDO_CMD} apt -y install ${pkg_list} linux-headers-${KERNEL_VER};
    #    else
    printf "%s\n\n" "${pkg_list}";
    ${SUDO_CMD} apt -y install ${pkg_list}
    ${SUDO_CMD} update-alternatives --install /usr/bin/python python /usr/bin/python3  1
}

function install_pkg_deb12
{
    declare -a pkg_list=${1}
    sudo_exist;
    # Debian Docker, we cannot find the linux-headers,
    # Unable to locate package linux-headers-5.8.0-1033-azure
    # linux-headers are not necessary for a common application.
    # We ignore within Docker image

    ${SUOD_CMD} apt -y update;
    printf "\n\n";   
    printf "The following package list will be installed:\n\n"
    #    if [[ ! ${KERNEL_VER} =~ "azure" ]]; then
    #        printf "%s linux-headers-%s\n\n" "${pkg_list}" "$KERNEL_VER";
    #        ${SUDO_CMD} apt -y install ${pkg_list} linux-headers-${KERNEL_VER};
    #    else
     printf "%s\n\n" "${pkg_list}";
    ${SUDO_CMD} apt -y install ${pkg_list}
    ${SUDO_CMD} update-alternatives --install /usr/bin/python python /usr/bin/python3  1
}

function install_pkg_deb13
{
    declare -a pkg_list=${1}
    sudo_exist;
    ${SUOD_CMD} apt -y update;
    printf "\n\n";   
    printf "The following package list will be installed:\n\n"
    printf "%s\n\n" "${pkg_list}";
    ${SUDO_CMD} apt -y install ${pkg_list}
}

function install_pkg_rpi()
{
    declare -a pkg_list=${1}
    sudo_exist;
    printf "\n\n";
    printf "The following package list will be installed:\n\n"
    printf "$pkg_list raspberrypi-kernel-headers\n";
    printf "\n\n"

    ${SUDO_CMD} apt-get update
    ${SUDO_CMD} apt-get -y install ${pkg_list}  raspberrypi-kernel-headers
}

function install_pkg_dnf
{
    declare -a pkg_list=${1}
    printf "\n";
    printf "$pkg_list\n";
    printf "\n\n\n"
    declare -r yum_pid="/var/run/yum.pid"
    sudo_exist;

    disable_system_service packagekit
    disable_system_service firewalld
    
    # Somehow, yum is running due to PackageKit, so if so, kill it
    #
    if [[ -e ${yum_pid} ]]; then
	${SUDO_CMD} kill -9 $(cat ${yum_pid})
	if [ $? -ne 0 ]; then
	    printf "Remove the orphan yum pid\n";
	    ${SUDO_CMD} rm -rf ${yum_pid}
	fi
    fi

    ${SUDO_CMD} dnf -y remove PackageKit firewalld;
    ${SUDO_CMD} dnf -y update;
    ${SUDO_CMD} dnf -y groupinstall "Development tools"
    ${SUDO_CMD} dnf -y install ${pkg_list};
}

# CentOS8 yum is the same as dnf
# ls -ltar /usr/bin/{dnf,yum}
# lrwxrwxrwx. 1 root root 5 May 13 21:34 /usr/bin/yum -> dnf-3
# lrwxrwxrwx. 1 root root 5 May 13 21:34 /usr/bin/dnf -> dnf-3
# so, it may be possible to merge them together with dnf
# 
function install_pkg_rpm
{
    declare -a pkg_list=${1}
    local version="${2}"
    printf "\n";
    printf "$pkg_list\n";
    printf "\n\n\n"

    declare -r yum_pid="/var/run/yum.pid"

    local pkgs_should_be_removed="PackageKit firewalld"
    sudo_exist;
    disable_system_service packagekit
    disable_system_service firewalld
    
    # Somehow, yum is running due to PackageKit, so if so, kill it
    #
    if [[ -e ${yum_pid} ]]; then
	${SUDO_CMD} kill -9 $(cat ${yum_pid})
	if [ $? -ne 0 ]; then
	    printf "Remove the orphan yum pid\n";
	    ${SUDO_CMD} rm -rf ${yum_pid}
	fi
    fi
    
    if [ "$version" == "8" ]; then
	pkgs_should_be_removed+=" "
	    ${SUDO_CMD} yum -y install dnf-plugins-core;
        ${SUDO_CMD} yum -y update;
        ${SUDO_CMD} yum config-manager --set-enabled powertools;
    else
	pkgs_should_be_removed+=" "
	pkgs_should_be_removed+="motif-devel"
	
    fi
    printf "The following packages are being removed ....\n"
    ${SUDO_CMD} yum -y remove ${pkgs_should_be_removed}
    ${SUDO_CMD} yum -y update;
    ${SUDO_CMD} yum -y upgarde ca-certificates
    ${SUDO_CMD} yum -y groupinstall "Development tools"
    ${SUDO_CMD} yum -y install "epel-release"
    ${SUDO_CMD} yum -y update;
    ${SUDO_CMD} yum -y install ${pkg_list};
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

function install_pkg_rocky8
{
    declare -a pkg_list=${1}
    printf "\n";
    printf "$pkg_list\n";
    printf "\n\n\n"
    declare -r yum_pid="/var/run/yum.pid"

    local pkgs_should_be_removed="PackageKit firewalld coreutils-single"
    sudo_exist;

    disable_system_service packagekit
    disable_system_service firewalld
    
    # Somehow, yum is running due to PackageKit, so if so, kill it
    #
    if [[ -e ${yum_pid} ]]; then
	    ${SUDO_CMD} kill -9 $(cat ${yum_pid})
	    if [ $? -ne 0 ]; then
	        printf "Remove the orphan yum pid\n";
	        ${SUDO_CMD} rm -rf ${yum_pid}
	    fi
    fi
    ${SUDO_CMD} dnf -y install dnf-plugins-core;
    ${SUDO_CMD} dnf -y update;
    ${SUDO_CMD} dnf -y config-manager --set-enabled powertools
    ${SUDO_CMD} dnf -y update;
    ${SUDO_CMD} dnf -y remove PackageKit firewalld;
    ${SUDO_CMD} dnf -y update;
    ${SUDO_CMD} dnf -y groupinstall "Development tools"
    ${SUDO_CMD} dnf -y install "epel-release"
    ${SUDO_CMD} dnf -y update;
    ${SUDO_CMD} dnf -y install ${pkg_list};
    # 3.6 is the rocky default
    ${SUDO_CMD} alternatives --set python /usr/bin/python3
}

function install_pkg_rocky9
{
    declare -a pkg_list=${1}
    printf "\n";
    printf "$pkg_list\n";
    printf "\n\n\n"
    declare -r yum_pid="/var/run/yum.pid"

    local pkgs_should_be_removed="PackageKit firewalld coreutils-single"
    sudo_exist;

    disable_system_service packagekit
    disable_system_service firewalld
    
    # Somehow, yum is running due to PackageKit, so if so, kill it
    #
    if [[ -e ${yum_pid} ]]; then
	${SUDO_CMD} kill -9 $(cat ${yum_pid})
	if [ $? -ne 0 ]; then
	    printf "Remove the orphan yum pid\n";
	    ${SUDO_CMD} rm -rf ${yum_pid}
	fi
    fi
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
    ${SUDO_CMD} dnf -y install ${pkg_list};
    # 3.9 is the rocky 9 default and there is no alternatives python
    #
    ${SUDO_CMD} alternatives --install /usr/bin/python python /usr/bin/python3 1 
}

function install_pkg_macos11
{
    declare -a pkg_list=${1}
    printf "\n";
    printf "$pkg_list\n";
    printf "\n\n\n"

    local command="brew"
    ${command} install ${pkg_list};
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

function yes_or_no_to_go
{

    printf  "> \n";
    printf  "> This procedure could help to install    \n"
    printf  "> required packages for EPICS installation\n"
    printf  "> and others.\n";
    printf  "> \n";
    printf  "> $1\n";
    read -p ">> Do you want to continue (y/N)? " answer
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
declare -a PKG_UBU24_ARRAY
#
declare -a PKG_RPM_ARRAY
declare -a PKG_CENTOS8_ARRAY
declare -a PKG_DNF_ARRAY
declare -a PKG_ROCKY8_ARRAY
declare -a PKG_ROCKY9_ARRAY
#
declare -a PKG_MACOS11_ARRAY

declare -g COM_PATH=${SC_TOP}/pkg-common
#
declare -g DEB_PATH=${SC_TOP}/pkg-deb
declare -g DEB9_PATH=${SC_TOP}/pkg-deb9
declare -g DEB10_PATH=${SC_TOP}/pkg-deb10
declare -g DEB11_PATH=${SC_TOP}/pkg-deb11
declare -g DEB12_PATH=${SC_TOP}/pkg-deb12
declare -g DEB13_PATH=${SC_TOP}/pkg-deb13
#
declare -g RPI_PATH=${SC_TOP}/pkg-rpi
#
declare -g UBU16_PATH=${SC_TOP}/pkg-ubu16
declare -g UBU20_PATH=${SC_TOP}/pkg-ubu20
declare -g UBU22_PATH=${SC_TOP}/pkg-ubu22
declare -g UBU24_PATH=${SC_TOP}/pkg-ubu24
#
declare -g RPM_PATH=${SC_TOP}/pkg-rpm
declare -a CENTOS8_PATH=${SC_TOP}/pkg-centos8
declare -g DNF_PATH=${SC_TOP}/pkg-dnf
declare -g ROCKY8_PATH=${SC_TOP}/pkg-rocky8
declare -g ROCKY9_PATH=${SC_TOP}/pkg-rocky9
#
declare -g MACOS11_PATH=${SC_TOP}/pkg-macos11
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
declare -ga pgk_ubu22_list
declare -ga pgk_ubu24_list
#
declare -ga pkg_rpm_list
declare -ga pkg_centos8_list
declare -ga pkg_dnf_list
declare -ga pkg_rocky8_list
declare -ga pkg_rocky9_list
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
#
pkg_macos11_list=("epics")
#
PKG_DEB_ARRAY=$(pkg_list ${COM_PATH}/common)

for deb_file in ${pkg_deb_list[@]}; do
    PKG_DEB_ARRAY+=" ";
    PKG_DEB_ARRAY+=$(pkg_list "${DEB_PATH}/${deb_file}");
done

PKG_DEB9_ARRAY=$(pkg_list ${COM_PATH}/common)
for deb_file in ${pkg_deb9_list[@]}; do
    PKG_DEB9_ARRAY+=" ";
    PKG_DEB9_ARRAY+=$(pkg_list "${DEB9_PATH}/${deb_file}");
done
# Debian 10 (Buster)
for deb_file in ${pkg_deb10_list[@]}; do
    PKG_DEB10_ARRAY+=" ";
    PKG_DEB10_ARRAY+=$(pkg_list "${DEB10_PATH}/${deb_file}");
done
# Debian 11 (Bullseye)
for deb_file in ${pkg_deb11_list[@]}; do
    PKG_DEB11_ARRAY+=" ";
    PKG_DEB11_ARRAY+=$(pkg_list "${DEB11_PATH}/${deb_file}");
done
# Debian 12 (bookworm)
for deb_file in ${pkg_deb12_list[@]}; do
    PKG_DEB12_ARRAY+=" ";
    PKG_DEB12_ARRAY+=$(pkg_list "${DEB12_PATH}/${deb_file}");
done
# Debian 13 (trixie)
PKG_DEB13_ARRAY=$(pkg_list ${COM_PATH}/common)
for deb_file in ${pkg_deb13_list[@]}; do
    PKG_DEB13_ARRAY+=" ";
    PKG_DEB13_ARRAY+=$(pkg_list "${DEB13_PATH}/${deb_file}");
done
#
PKG_RPI_ARRAY=$(pkg_list ${COM_PATH}/common)
for deb_file in ${pkg_rpi_list[@]}; do
    PKG_RPI_ARRAY+=" ";
    PKG_RPI_ARRAY+=$(pkg_list "${RPI_PATH}/${deb_file}");
done
#
PKG_UBU16_ARRAY=$(pkg_list ${COM_PATH}/common)
for deb_file in ${pkg_ubu16_list[@]}; do
    PKG_UBU16_ARRAY+=" ";
    PKG_UBU16_ARRAY+=$(pkg_list "${UBU16_PATH}/${deb_file}");
done
#
PKG_UBU20_ARRAY=$(pkg_list ${COM_PATH}/common)
for deb_file in ${pkg_ubu20_list[@]}; do
    PKG_UBU20_ARRAY+=" ";
    PKG_UBU20_ARRAY+=$(pkg_list "${UBU20_PATH}/${deb_file}");
done
#
PKG_UBU22_ARRAY=$(pkg_list ${COM_PATH}/common)
for deb_file in ${pkg_ubu22_list[@]}; do
    PKG_UBU22_ARRAY+=" ";
    PKG_UBU22_ARRAY+=$(pkg_list "${UBU22_PATH}/${deb_file}");
done

PKG_UBU2i4_ARRAY=$(pkg_list ${COM_PATH}/common)
for deb_file in ${pkg_ubu24_list[@]}; do
    PKG_UBU24_ARRAY+=" ";
    PKG_UBU24_ARRAY+=$(pkg_list "${UBU24_PATH}/${deb_file}");
done

PKG_RPM_ARRAY=$(pkg_list ${COM_PATH}/common)
for rpm_file in ${pkg_rpm_list[@]}; do
    PKG_RPM_ARRAY+=" ";
    PKG_RPM_ARRAY+=$(pkg_list "${RPM_PATH}/${rpm_file}");
done
#
for rpm_file in ${pkg_centos8_list[@]}; do
    PKG_CENTOS8_ARRAY+=" ";
    PKG_CENTOS8_ARRAY+=$(pkg_list "${CENTOS8_PATH}/${rpm_file}");
done
#
PKG_DNF_ARRAY=$(pkg_list ${COM_PATH}/common)
for dnf_file in ${pkg_dnf_list[@]}; do
    PKG_DNF_ARRAY+=" ";
    PKG_DNF_ARRAY+=$(pkg_list "${DNF_PATH}/${dnf_file}");
done

# Rocky 8.4
for rocky_file in ${pkg_rocky8_list[@]}; do
    PKG_ROCKY8_ARRAY+=" ";
    PKG_ROCKY8_ARRAY+=$(pkg_list "${ROCKY8_PATH}/${rocky_file}");
done
# Rocky 9.0
for rocky9_file in ${pkg_rocky9_list[@]}; do
    PKG_ROCKY9_ARRAY+=" ";
    PKG_ROCKY9_ARRAY+=$(pkg_list "${ROCKY9_PATH}/${rocky9_file}");
done
#
for brew_file in ${pkg_macos11_list[@]}; do
    PKG_MACOS11_ARRAY+=" ";
    PKG_MACOS11_ARRAY+=$(pkg_list "${MACOS11_PATH}/${brew_file}");
done

ANSWER="NO"

while getopts ":y" opt; do
    case ${opt} in
	y)
	    ANSWER="YES"
	    ;;
	\?)
	    echo "Invalid option: -${OPTARG}" >&2
	    exit;
	    ;;
    esac
done
dist=$(find_dist)

echo "Distriution is >>>${dist}<<"

case "$dist" in
    Raspbian*)
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Raspbian is detected as $dist"
	fi
	install_pkg_rpi "${PKG_RPI_ARRAY[@]}"
	;;
    *jessie*)
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Debian jessie is detected as $dist"
	fi
	install_pkg_deb "${PKG_DEB_ARRAY[@]}"
	;;
    *stretch*)
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Debian stretch is detected as $dist"
	fi
	install_pkg_deb "${PKG_DEB9_ARRAY[@]}"
	;;
    *buster*)
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Debian 10 (Buster) is detected as $dist"
	fi
	install_pkg_deb10 "${PKG_DEB10_ARRAY[@]}"
	;;
    *bullseye*)
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
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "CentOS or Scientific is detected as $dist";
	fi
	centos_version=$(centos_dist)
	if [ "$centos_version" == "8" ]; then
	    echo $centos_version
	    install_pkg_rpm "${PKG_CENTOS8_ARRAY[@]}" "${centos_version}"
#	    install_tclx_centos8
	else
	    install_pkg_rpm "${PKG_RPM_ARRAY[@]}"  "${centos_version}"
	fi
	;;

    *Rocky* | *Alma* )
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Rocky or Alma is detected as $dist";
    fi

    rocky_version=$(centos_dist)

	if [[ "$rocky_version" =~ .*"8.".* ]]; then
        install_pkg_rocky8 "${PKG_ROCKY8_ARRAY[@]}"
	elif [[ "$rocky_version" =~ .*"9.".* ]]; then
        install_pkg_rocky9 "${PKG_ROCKY9_ARRAY[@]}"
	else
        printf "\n";
	    printf "Doesn't support %s\n" "$dist";
        printf "\n";
    fi
	;;

    *xenial*)
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Ubuntu xenial is detected as $dist";
	fi
	install_pkg_deb "${PKG_UBU16_ARRAY[@]}"
	;;

    *artful*)
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Ubuntu artful is detected as $dist";
	fi
	install_pkg_deb "${PKG_UBU16_ARRAY[@]}"
	;;
    *bionic*)
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Ubuntu bionic is detected as $dist";
	fi
	install_pkg_deb "${PKG_UBU16_ARRAY[@]}"
	;;

    *focal*)
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
    fi
    ;;
    *sylvia*)
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Linux Mint sylvia is detected as $dist";
	fi
	install_pkg_deb "${PKG_UBU16_ARRAY[@]}"
	;;

    *tara*)
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Linux Mint tara is detected as $dist";
	fi
	install_pkg_deb "${PKG_UBU16_ARRAY[@]}"
	;;

    *tessa*)
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Linux Mint tessa is detected as $dist";
	fi
	install_pkg_deb "${PKG_UBU16_ARRAY[@]}"
	;;

    *Fedora*)
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Linux Fedora is detected as $dist";
	fi
	install_pkg_dnf "${PKG_DNF_ARRAY[@]}";
	;;

    *macOS*)
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "macOS is detected as $dist";
	fi
#	install_pkg_macos11 "${PKG_MACOS11_ARRAY[@]}";
	macos_version=$(macos_dist)
	if [[ "$macos_version" =~ .*"11.".* ]]; then
	    echo $macos_version
	    install_pkg_macos11 "${PKG_MACOS11_ARRAY[@]}";
	elif [[ "$macos_version" =~ .*"12.".* ]]; then
 		echo $macos_version
		install_pkg_macos11 "${PKG_MACOS11_ARRAY[@]}";
	elif [[ "$macos_version" =~ .*"13.".* ]]; then
 		echo $macos_version
		install_pkg_macos11 "${PKG_MACOS11_ARRAY[@]}";
	elif [[ "$macos_version" =~ .*"14.".* ]]; then
 		echo $macos_version
		install_pkg_macos11 "${PKG_MACOS11_ARRAY[@]}";
	else
        printf "\n";
	    printf "Doesn't support yet %s\n" "$dist";
        printf "\n";
	fi
	;;

    *)
	printf "----------------------------------\n";
	printf ">> Doesn't support the detected %s\n" "$dist";
	printf ">> Please contact jeonghan.lee@gmail.com or feel free to do pull requests.\n";
	printf "\n";
	;;
esac

exit;
