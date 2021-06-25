#!/bin/bash
#
#  Copyright (c) 2014 - 2021    Jeong Han Lee
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
#  Date    : Fri 25 Jun 2021 10:55:26 AM PDT
#  version : 1.0.9
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
declare -g SC_SCRIPT;
#declare -g SC_SCRIPTNAME;
declare -g SC_TOP;
declare -g SUDO_CMD;
declare -g KERNEL_VER;

SC_SCRIPT=${BASH_SOURCE[0]:-${0}}
#SC_SCRIPTNAME=${0##*/};
SC_TOP="$( cd -P "$( dirname "$SC_SCRIPT" )" && pwd )"
#"${SC_SCRIPT%/*}"

function pushd { builtin pushd "$@" > /dev/null || exit; }
function popd  { builtin popd  > /dev/null || exit; }

SUDO_CMD="sudo"
KERNEL_VER=$(uname -r)

. ${SC_TOP}/functions


function centos_dist
{

    local VERSION_ID
    eval $(cat /etc/os-release | grep -E "^(VERSION_ID)=")
    echo ${VERSION_ID}
}


function find_dist
{

    local dist_id dist_cn dist_rs PRETTY_NAME
    
    if [[ -f /usr/bin/lsb_release ]] ; then
     	dist_id=$(lsb_release -is)
     	dist_cn=$(lsb_release -cs)
     	dist_rs=$(lsb_release -rs)
     	echo "$dist_id ${dist_cn} ${dist_rs}"
    else
     	eval $(cat /etc/os-release | grep -E "^(PRETTY_NAME)=")
	echo "${PRETTY_NAME}"
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


funcition install_pkg_deb
{
    declare -a pkg_list=${1}

    # Debian Docker, we cannot find the linux-headers,
    # Unable to locate package linux-headers-5.8.0-1033-azure
    # linux-headers are not necessary for a commom application.
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


function install_pkg_deb10
{
    declare -a pkg_list=${1}

    # Debian Docker, we cannot find the linux-headers,
    # Unable to locate package linux-headers-5.8.0-1033-azure
    # linux-headers are not necessary for a commom application.
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
    update-alternatives --install /usr/bin/python python /usr/bin/python3 2
}

function install_pkg_rpi()
{
    declare -a pkg_list=${1}
    
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
    ${SUDO_CMD} dnf update;
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
        ${SUDO_CMD} yum update;
        ${SUDO_CMD} yum config-manager --set-enabled powertools;
    else
	pkgs_should_be_removed+=" "
	pkgs_should_be_removed+="motif-devel"
	
    fi
    printf "The following packages are being removed ....\n"
    ${SUDO_CMD} yum -y remove ${pkgs_should_be_removed}
    ${SUDO_CMD} yum update;
    ${SUDO_CMD} yum -y upgarde ca-certificates
    ${SUDO_CMD} yum -y groupinstall "Development tools"
    ${SUDO_CMD} yum -y install "epel-release"
    ${SUDO_CMD} yum update;
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
    ${SUDO_CMD} dnf update;
    ${SUDO_CMD} dnf config-manager --set-enabled powertools
    ${SUDO_CMD} dnf update;
    ${SUDO_CMD} dnf -y remove PackageKit firewalld;
    ${SUDO_CMD} dnf update;
    ${SUDO_CMD} dnf -y groupinstall "Development tools"
    ${SUDO_CMD} dnf -y install "epel-release"
    ${SUDO_CMD} dnf update;
    ${SUDO_CMD} dnf -y install ${pkg_list};
    # 3.6 is the rocky default
    ${SUDO_CMD} alternatives --set python /usr/bin/python3
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
	    printf ">> The following pakcages will be installed ...... ";
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
declare -a PKG_RPI_ARRAY
declare -a PKG_UBU16_ARRAY
declare -a PKG_UBU20_ARRAY
declare -a PKG_RPM_ARRAY
declare -a PKG_CENTOS8_ARRAY
declare -a PKG_DNF_ARRAY
declare -a PKG_ROCLY8_ARRAY

declare -g COM_PATH=${SC_TOP}/pkg-common
#
declare -g DEB_PATH=${SC_TOP}/pkg-deb
declare -g DEB9_PATH=${SC_TOP}/pkg-deb9
declare -g DEB10_PATH=${SC_TOP}/pkg-deb10
#
declare -g RPI_PATH=${SC_TOP}/pkg-rpi
declare -g UBU16_PATH=${SC_TOP}/pkg-ubu16
declare -g UBU20_PATH=${SC_TOP}/pkg-ubu20
declare -g RPM_PATH=${SC_TOP}/pkg-rpm
declare -a CENTOS8_PATH=${SC_TOP}/pkg-centos8
declare -g DNF_PATH=${SC_TOP}/pkg-dnf
declare -g ROCKY8_PATH=${SC_TOP}/pkg-rocky8

declare -ga pkg_deb_list
declare -ga pkg_deb9_list
declare -ga pkg_deb10_list
declare -ga pkg_rpi_list
declare -ga pkg_ubu16_list
declare -ga pkg_ubu20_list
declare -ga pkg_rpm_list
declare -ga pkg_centos8_list
declare -ga pkg_dnf_list
declare -ga pkg_rocky8_list


pkg_deb_list=("epics" "extra")
pkg_deb9_list=("epics" "extra")
pkg_deb10_list=("common" "epics" "extra")
pkg_rpi_list=("epics" "extra")
pkg_ubu16_list=("epics" "extra")
pkg_ubu20_list=("epics" "extra")
pkg_rpm_list=("epics" "extra")
pkg_centos8_list=("common" "epics" "extra")
pkg_dnf_list=("epics" "extra")
pkg_rocky8_list=("common" "epics" "extra")


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


PKG_RPI_ARRAY=$(pkg_list ${COM_PATH}/common)

for deb_file in ${pkg_rpi_list[@]}; do
    PKG_RPI_ARRAY+=" ";
    PKG_RPI_ARRAY+=$(pkg_list "${RPI_PATH}/${deb_file}");
done


PKG_UBU16_ARRAY=$(pkg_list ${COM_PATH}/common)

for deb_file in ${pkg_ubu16_list[@]}; do
    PKG_UBU16_ARRAY+=" ";
    PKG_UBU16_ARRAY+=$(pkg_list "${UBU16_PATH}/${deb_file}");
done


PKG_UBU20_ARRAY=$(pkg_list ${COM_PATH}/common)

for deb_file in ${pkg_ubu20_list[@]}; do
    PKG_UBU20_ARRAY+=" ";
    PKG_UBU20_ARRAY+=$(pkg_list "${UBU20_PATH}/${deb_file}");
done


PKG_RPM_ARRAY=$(pkg_list ${COM_PATH}/common)

for rpm_file in ${pkg_rpm_list[@]}; do
    PKG_RPM_ARRAY+=" ";
    PKG_RPM_ARRAY+=$(pkg_list "${RPM_PATH}/${rpm_file}");
done


for rpm_file in ${pkg_centos8_list[@]}; do
    PKG_CENTOS8_ARRAY+=" ";
    PKG_CENTOS8_ARRAY+=$(pkg_list "${CENTOS8_PATH}/${rpm_file}");
done


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
    *Rocky*)
	if [ "$ANSWER" == "NO" ]; then
	    yes_or_no_to_go "Rocky is detected as $dist";
	fi
        install_pkg_rocky8 "${PKG_ROCKY8_ARRAY[@]}"
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
    *)
	printf "\n";
	printf "Doesn't support the detected %s\n" "$dist";
	printf "Please contact jeonghan.lee@gmail.com\n";
	printf "\n";
	;;
esac

exit;
