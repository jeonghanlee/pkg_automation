#!/bin/bash
#
#  Copyright (c) 2014 - 2017 Jeong Han Lee
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
#  Date    : Saturday, January 27 00:09:17 CET 2018
#  version : 0.9.7
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
#
declare -gr SC_SCRIPT="$(realpath "$0")"
declare -gr SC_SCRIPTNAME=${0##*/}
declare -gr SC_TOP="$(dirname "$SC_SCRIPT")"

declare -gr SUDO_CMD="sudo"


. ${SC_TOP}/functions


function find_dist() {

    local dist_id dist_cn dist_rs PRETTY_NAME
    
    if [[ -f /usr/bin/lsb_release ]] ; then
     	dist_id=$(lsb_release -is)
     	dist_cn=$(lsb_release -cs)
     	dist_rs=$(lsb_release -rs)
     	echo $dist_id ${dist_cn} ${dist_rs}
    else
     	eval $(cat /etc/os-release | grep -E "^(PRETTY_NAME)=")
	echo ${PRETTY_NAME}
    fi

 
}


function pkg_list()
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
    done < $1
    echo ${packagelist[@]}
}


function install_pkg_deb()
{
    declare -a pkg_list=${1}
    printf "\n\n";
    printf "$pkg_list\n";
    printf "\n\n"

    ${SUDO_CMD} apt-get update
    ${SUDO_CMD} apt-get -y install ${pkg_list};
}


function install_pkg_dnf()
{
    declare -a pkg_list=${1}
    printf "\n";
    printf "$pkg_list\n";
    printf "\n\n\n"
    declare -r yum_pid="/var/run/yum.pid"

    ${SUDO_CMD} systemctl stop packagekit
    ${SUDO_CMD} systemctl disable packagekit
    
    # Somehow, yum is running due to PackageKit, so if so, kill it
    #
    if [[ -e ${yum_pid} ]]; then
	${SUDO_CMD} kill -9 $(cat ${yum_pid})
	if [ $? -ne 0 ]; then
	    printf "Remove the orphan yum pid\n";
	    ${SUDO_CMD} rm -rf ${yum_pid}
	fi
    fi

    ${SUDO_CMD} dnf -y remove PackageKit motif-devel;
    ${SUDO_CMD} dnf update;
    ${SUDO_CMD} dnf -y groupinstall "Development tools"
    ${SUDO_CMD} dnf -y install ${1};
}



function install_pkg_rpm()
{
    declare -a pkg_list=${1}
    printf "\n";
    printf "$pkg_list\n";
    printf "\n\n\n"
    declare -r yum_pid="/var/run/yum.pid"

    ${SUDO_CMD} systemctl stop packagekit
    ${SUDO_CMD} systemctl disable packagekit
    
    # Somehow, yum is running due to PackageKit, so if so, kill it
    #
    if [[ -e ${yum_pid} ]]; then
	${SUDO_CMD} kill -9 $(cat ${yum_pid})
	if [ $? -ne 0 ]; then
	    printf "Remove the orphan yum pid\n";
	    ${SUDO_CMD} rm -rf ${yum_pid}
	fi
    fi

    ${SUDO_CMD} yum -y remove PackageKit motif-devel;
    ${SUDO_CMD} yum update;
    ${SUDO_CMD} yum -y groupinstall "Development tools"
    ${SUDO_CMD} yum -y install "epel-release"
    ${SUDO_CMD} yum update;
    ${SUDO_CMD} yum -y install ${1};
}

function yes_or_no_to_go() {

    printf "\n";
    printf  ">>>> $1\n";
    read -p ">>>> Do you want to continue (y/n)? " answer
    case ${answer:0:1} in
	y|Y )
	    printf ">>>> The following pakcages will be installed ...... ";
	    ;;
	* )
            printf "Stop here.\n";
	    exit;
    ;;
    esac

}

declare -a PKG_DEB_ARRAY
declare -a PKG_DEB9_ARRAY
declare -a PKG_UBU16_ARRAY
declare -a PKG_RPM_ARRAY
declare -a PKG_DNF_ARRAY

declare -g COM_PATH=${SC_TOP}/pkg-common
declare -g DEB_PATH=${SC_TOP}/pkg-deb
declare -g DEB9_PATH=${SC_TOP}/pkg-deb9
declare -g UBU16_PATH=${SC_TOP}/pkg-ubu16
declare -g RPM_PATH=${SC_TOP}/pkg-rpm
declare -g DNF_PATH=${SC_TOP}/pkg-dnf


declare -ga pkg_deb_list
declare -ga pkg_deb9_list
declare -ga pkg_ubu16_list
declare -ga pkg_rpm_list
declare -ga pkg_dnf_list

pkg_deb_list=("epics" "ess")
pkg_deb9_list=("epics" "ess")
pkg_ubu16_list=("epics" "ess")
pkg_rpm_list=("epics" "ess")
pkg_dnf_list=("epics" "ess")

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

PKG_UBU16_ARRAY=$(pkg_list ${COM_PATH}/common)

for deb_file in ${pkg_ubu16_list[@]}; do
    PKG_UBU16_ARRAY+=" ";
    PKG_UBU16_ARRAY+=$(pkg_list "${UBU16_PATH}/${deb_file}");
done


PKG_RPM_ARRAY=$(pkg_list ${COM_PATH}/common)

for rpm_file in ${pkg_rpm_list[@]}; do
    PKG_RPM_ARRAY+=" ";
    PKG_RPM_ARRAY+=$(pkg_list "${RPM_PATH}/${rpm_file}");
done



PKG_DNF_ARRAY=$(pkg_list ${COM_PATH}/common)

for dnf_file in ${pkg_dnf_list[@]}; do
    PKG_DNF_ARRAY+=" ";
    PKG_DNF_ARRAY+=$(pkg_list "${DNF_PATH}/${dnf_file}");
done



dist=$(find_dist)

case "$dist" in
    *jessie*)
	yes_or_no_to_go "Debian jessie is detected as $dist"
	install_pkg_deb "${PKG_DEB_ARRAY[@]}"
	;;
    *stretch*)
	yes_or_no_to_go "Debian stretch is detected as $dist"
	install_pkg_deb "${PKG_DEB9_ARRAY[@]}"
	;;
    *CentOS*)
	yes_or_no_to_go "CentOS is detected as $dist";
	install_pkg_rpm "${PKG_RPM_ARRAY[@]}"
	;;
    *xenial*)
	yes_or_no_to_go "Ubuntu xenial is detected as $dist";
	install_pkg_deb "${PKG_UBU16_ARRAY[@]}"
	;;
    *artful*)
	yes_or_no_to_go "Ubuntu artful is detected as $dist";
	install_pkg_deb "${PKG_UBU16_ARRAY[@]}"
	;;
    *sylvia*)
	yes_or_no_to_go "Linux Mint sylvia is detected as $dist";
	install_pkg_deb "${PKG_UBU16_ARRAY[@]}"
	;;
    *Fedora*)
	yes_or_no_to_go "Linux Fedora is detected as $dist";
	install_pkg_dnf "${PKG_DNF_ARRAY[@]}";
	;;
    *)
	printf "\n";
	printf "Doesn't support the detected $dist\n";
	printf "Please contact jeonghan.lee@gmail.com\n";
	printf "\n";
	;;
esac

exit 0;
