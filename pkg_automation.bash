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
#  Date    : Monday, September 25 22:00:02 CEST 2017
#  version : 0.9.0
#
#   - 0.0.1  December 1 00:01 KST 2014, jhlee
#           * created
#   - 0.9.0  Monday, September 25 22:28:18 CEST 2017, jhlee
#           * completely rewrite... 
#

declare -gr SC_SCRIPT="$(realpath "$0")"
declare -gr SC_SCRIPTNAME=${0##*/}
declare -gr SC_TOP="$(dirname "$SC_SCRIPT")"


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


declare -a PKG_DEB_ARRAY
declare -a PKG_RPM_ARRAY

declare -g COM_PATH=${SC_TOP}/pkg-common
declare -g DEB_PATH=${SC_TOP}/pkg-deb
declare -g RPM_PATH=${SC_TOP}/pkg-rpm

declare -ga pkg_deb_list
declare -ga pkg_rpm_list

pkg_deb_list=("epics")
pkg_rpm_list=("common" "epics")

PKG_DEB_ARRAY=$(pkg_list ${COM_PATH}/common)

for pkg_file in ${pkg_deb_list[@]}; do
    PKG_DEB_ARRAY+=$(pkg_list "${DEB_PATH}/${pkg_file}");
done

PKG_RPM_ARRAY=$(pkg_list ${COM_PATH}/common)

for pkg_file in ${pkg_rpm_list[@]}; do
    PKG_RPM_ARRAY+=$(pkg_list "${RPM_PATH}/${pkg_file}");
done


dist=$(find_dist)

case "$dist" in
    *Debian*)
	echo "Debian is detected">&2
	echo $PKG_DEB_ARRAY
	;;
    *CentOS*)
	echo "CentOS is detected">&2
	echo $PKG_RPM_ARRAY
	;;
    *)
	echo >&2
	echo "Doesn't support $dist" >&2
	echo >&2
	exit 0
	;;
esac
