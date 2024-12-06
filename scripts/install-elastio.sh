#!/bin/bash

me="./install-elastio.sh"
default_branch=release

MAX_LINUX_VER=6
MAX_LINUX_MAJOR_REV=4

cent_fedora_kernel_devel_install()
{
    kernel_devel="kernel-devel"
    # This is for Oracle Linux support. Oracle Linux may use UEK kernel or regular CentOS's kernel.
    # We'll install appropriate kernel devel package depending on the currently loaded kernel.
    uname -r | grep -q uek && kernel_devel="kernel-uek-devel"
    if ! yum install -y $kernel_devel-$(uname -r) $kernel_devel ; then
        echo
        echo "Failed to install package $kernel_devel-$(uname -r) for the current running kernel."
        echo "This package is dependency of the Elastio-Snap kernel driver."
        echo "Please update current kernel to the most recent version, reboot machine into it and try again."
        [[ "$1" == "CentOS" ]] &&  echo "Or enable Vault repo and try again."
        exit 1
    fi

    # Kernel devel package on the old UEK kernels may not create 'build' dir in 'modules'.
    if [ ! -d /usr/lib/modules/$(uname -r)/build/ ]; then
        ln -sn /usr/src/kernels/$(uname -r) /usr/lib/modules/$(uname -r)/build
    fi
}

cent7_amazon_install()
{
    if [ ! -z "$driver" ]; then
        cent_fedora_kernel_devel_install $1
        # Hack around zlib package updae on OL7 with versionlock in Oracle Cloud.
        # dkms-elastio-snap depends on dkms. And dkms depends on zlib-1.2.7-21 which may be necessary to update.
        zlib_locked=0
        rpm -qa | grep -q versionlock && yum versionlock list | grep -q zlib && zlib_locked=1
        [ $zlib_locked -ne 0 ] && yum versionlock delete zlib || true
        yum install -y dkms-elastio-snap elastio-snap-utils
        [ $zlib_locked -ne 0 ] && yum versionlock zlib || true
    fi
    if [ ! -z "$cli" ]; then
        yum install -y elastio
    fi
}

cent8_fedora_install()
{
    if [ ! -z "$driver" ] && [ ! -z "$cli" ]; then
        # Install elastio and driver as dependency
        cent_fedora_kernel_devel_install $1
        yum install -y elastio
    elif [ ! -z "$driver" ]; then
        # Install just driver
        cent_fedora_kernel_devel_install $1
        yum install -y dkms-elastio-snap elastio-snap-utils
    elif [ ! -z "$cli" ]; then
        # Install just elastio w/o driver as dependency
        yum --setopt=install_weak_deps=False install -y elastio
    fi
}

cent_fedora_install()
{
    if [ "$1" = "CentOS" ] && grep "Red Hat" -q /etc/redhat-release 2>/dev/null && ! rpm -qa | grep -q epel-release ; then
        rpm --import http://download.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-$2
        yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$2.noarch.rpm
    elif [ "$1" = "Amazon" ]; then
        case $2 in
            2 )    amazon-linux-extras install -y epel
                   yum install -y nbd
            ;;
            2023 ) arch=$(uname -m)
                   yum localinstall -y https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/38/Everything/$arch/os/Packages/n/nbd-3.24-3.fc38.$arch.rpm
            ;;
        esac
    fi

    # Looking for the latest version of the elastio-repo package from 0.0.3 to 0.0.1
    for pkg_version in $(seq 3 -1 1); do
        repo_package_url=$repo_url/rpm/$1/$2/noarch/Packages/elastio-repo-0.0.$pkg_version-1.$3$2.noarch.rpm

        if (($(curl -sIL -m 2 "$repo_package_url" -w "%{http_code}" | tail -1) == 200)) ; then
            break
        fi
    done

    rpm --import https://$repo_host/GPG-KEY-elastio
    yum localinstall -y $repo_package_url
    which dnf >/dev/null 2>&1 &&
        cent8_fedora_install $1 $2 $3 ||
        cent7_amazon_install $1 $2 $3

    # Install ntfs-3g to any RPM-based distro except Fedora 35+ with the kernel 5.15+
    [ $2 -lt 35 ] && yum install -y ntfs-3g
    # Install nbd to any RPM-based distro except Amazon Linux 2 and 2023
    [ "$1" != "Amazon" ] && yum install -y nbd
}

check_installed()
{
    dpkg -l | grep ^ii | awk '{ print $2}' | grep -q -E ^$1$
}

deb_ubu_install()
{
    dist_name=$1                                    # debian or ubuntu
    dist_ver_dot=$2                                 # 11, 22.04 etc
    dist_ver=$(echo $dist_ver_dot | tr -cd '[0-9]') # 11, 2204 etc
    if ! check_installed wget || ! check_installed gnupg ; then
        apt-get update
        check_installed wget  || apt-get install -y wget
        check_installed gnupg || apt-get install -y gnupg
    fi

    # For Ubuntu 16.04 - 21.10 we are insatlling Debian packages:
    # Debian 9 for Ubuntu 18.XX, Debian 10 for Ubuntu 20.XX and 21.XX etc.
    # And Ubuntu 22.04 and newer have own repository.
    if [ "$dist_name" == "ubuntu" ] && [ "$dist_ver" -le 2110 ]; then
        inst_ver=$(($dist_ver/200))
        dist_ver_dot=$inst_ver
        inst_name=Debian
        dist_name=debian
    else
        # Ubuntu 22.04, PopOS 22.04 and all Debians - no need to change version and
        # distro name just with the 1st capital letter.
        inst_ver=$dist_ver
        inst_name=${dist_name^}
    fi

    # Looking for the latest version of elastio-repo package from 0.0.3 to 0.0.1
    for pkg_version in $(seq 3 -1 1); do
        repo_package=elastio-repo_0.0.${pkg_version}-1${dist_name}${dist_ver_dot}_all.deb
        repo_package_url=$repo_url/deb/${inst_name}/${inst_ver}/pool/$repo_package

        if (($(curl -sIL -m 2 "$repo_package_url" -w "%{http_code}" | tail -1) == 200)) ; then
            break
        fi
    done

    wget $repo_package_url
    dpkg -i $repo_package && rm -f $repo_package
    apt-get update
    # Maybe new kernel was installed recently but machine was not yet booted into it.
    # In this case dkms will install as dependency linux-headers-[latest kernel version].
    # But we need to have driver built and loaded right now without reboot, that's why
    # installing linux-headers package for the current kernel.
    [ ! -z "$driver" ] && apt-get install -y linux-headers-$(uname -r)
    if [ ! -z "$driver" ] && [ ! -z "$cli" ]; then
        # Install elastio and driver
        apt-get -o apt::install-recommends=true install -y elastio elastio-snap-utils
    elif [ ! -z "$driver" ]; then
        # Install just driver
        apt-get -o apt::install-recommends=true install -y elastio-snap-utils
    elif [ ! -z "$cli" ]; then
        # Install just elastio w/o driver as dependency
        apt-get --no-install-recommends install -y elastio ntfs-3g nbd-client
    fi
}

uninstall_all()
{
    if which apt-get >/dev/null 2>&1; then
        snap="elastio-snap-dkms libelastio-snap1"
        query_cmd="dpkg -l"
        uninst_cmd="apt-get remove --purge -y"
    elif which yum >/dev/null 2>&1; then
        snap="dkms-elastio-snap libelastio-snap"
        query_cmd="rpm -q"
        uninst_cmd="yum remove -y"
    else
        echo "Unknown package manager."
    fi

    packages="elastio elastio-repo $snap elastio-snap-utils elastio-s0 elastio-infra"
    rm_packages=
    for package in ${packages[@]}; do
        $query_cmd $package >/dev/null 2>&1 && rm_packages="$rm_packages $package"
    done

    if [ -n "$rm_packages" ]; then
        echo "Uninstalling packages:$rm_packages!"
        echo
        $uninst_cmd $rm_packages
        ret=$?
        # Remove cache (mirror files) in case if no elastio packages remain for sure
        [ $ret -eq 0 ] && which yum >/dev/null 2>&1 && rm -rf /var/cache/yum/*/*/Elastio/
        echo
        [ $ret -eq 0 ] &&
            echo "All Elastio packages have been uninstalled!" ||
            echo "Failed to uninstall some Elastio packages."
    else
        echo "No Elastio packages were found."
    fi
}

usage()
{
    echo "This script installs latest Elastio CLI and Elastio-Snap packages if executed without arguments, or re-installs them, if they are already installed."
    echo "All commandline arguments are optional."
    echo "Usage examples:"
    echo "   $me"
    echo "   $me -u"
    echo "   $me -c | --cli-only"
    echo "   $me -d | --driver-only"
    echo
    echo "  -c | --cli-only       : Install Elastio CLI, without change tracking driver elastio-snap. (Default)"
    echo
    echo "  -d | --driver-only    : Install change tracking driver elastio-snap."
    echo "                          WARNING:"
    echo "                            - elastio-snap change tracking driver is not supported anymore and could be unavailable for new distros."
    echo
    echo "  -u | --uninstall      : Uninstall all Elastio packages."
    echo
    echo "  -b | --branch         : Use non-default unstable channel of Elastio packages. It's equal to the branch name. For developer use only!"
    echo
    echo "  -h | --help           : Show this usage help."
}

while [ "$1" != "" ]; do
    case $1 in
        -c | --cli-only)        cli=1 ;;
        -d | --driver-only)     driver=1 ;;
        -u | --uninstall)       uninstall=1 ;;
        -f | --force)           force=1 ;;
        -b | --branch)          shift && branch=$1 ;;
        -h | --help)            usage && exit ;;
        *)                      echo "Wrong arguments!"
                                usage && exit 15 ;;
    esac
        shift
done

if [ -z "$cli" ] && [ -z "$driver" ]; then
    cli=1
fi

if [ "$EUID" -ne 0 ]; then
	echo "Run as sudo or root."
	exit 1
fi

set -e

[ -z "$branch" ] && branch=$default_branch

repo_host="repo.elastio.us"
case "$branch" in
    "nightly"|"release-candidate"|"release")
        repo_host="repo.elastio.com"
        ;;
esac

repo_url="https://$repo_host/$branch/linux"

if [ ! -z "$uninstall" ]; then
    uninstall_all
    exit
fi

# Detect distro name and version
if which apt-get >/dev/null 2>&1 ; then
    dist_name=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
    # 9, 10 or 11 for Debian, but 22.04 for Ubuntu. It's used in the package name like
    # elastio-repo_0.0.2-1ubuntu22.04_all.deb
    dist_ver_dot=$(grep VERSION_ID /etc/os-release | tr -cd '[0-9].')
else
    dist_name=$(cat /etc/system-release 2>/dev/null | cut -d' ' -f1)
    dist_ver=$(cat /etc/system-release 2>/dev/null | tr -cd '[0-9.]' | cut -d'.' -f1)
fi

# Lowercase dist_name
dist_name=$(echo ${dist_name,,})

if [ -n "$driver" ]; then
    if [ $(uname -m) == "aarch64" ]; then
        echo "The change tracking driver is not yet available for ARM64 processors. Ignoring driver installation..."
        unset driver
    else
        linux_ver=$(uname -r | cut -d. -f1)
        linux_major_rev=$(uname -r | cut -d. -f2)
        if [[ $linux_ver -gt $MAX_LINUX_VER || $linux_ver -eq $MAX_LINUX_VER && $linux_major_rev -gt $MAX_LINUX_MAJOR_REV ]]; then
            echo "The newest supported Linux kernel is ${MAX_LINUX_VER}.${MAX_LINUX_MAJOR_REV}. Current Linux kernel ${linux_ver}.${linux_major_rev} is not yet supported. Ignoring driver installation..."
            unset driver
        fi
    fi

    [ -z "$driver" ] && [ -z "$cli" ] && exit 1
fi

case $(uname -m) in
    x86_64 | aarch64 ) ;;
    * )
        echo "Unsupported CPU architecture $(uname -m)."
        exit 1
    ;;
esac

case ${dist_name} in
    amazon | amzn )
        case $dist_ver in
            2 | 2023 ) cent_fedora_install Amazon $(rpm -E %amzn) amzn ;;
            * )  echo "Only Amazon Linux versions 2 and 2023 are supported. Current Amazon Linux $dist_ver isn't supported."
                 exit 1
            ;;
        esac
    ;;

    scientific | sl | oracle | ol )
        echo "Warning: Oracle Linux and Scientific Linux are not officially supported!"
        if [ -z $force ]; then
            echo "We can try to install packages for CentOS on your system."
            echo "Add '--force' to insist on the installation. But beware this isn't officially supported!"
            exit 1
        fi
    ;;&

    centos | almalinux | rocky | el | rhel | red | scientific | sl | oracle | ol )
        case ${dist_ver}-$(uname -m) in
            8-* | 9-* ) cent_fedora_install CentOS $(rpm -E %rhel) el ;;
            *-x86_64  )
                echo "CentOS/RHEL versions 8 and 9 are supported on x86_64 processors. Current distro version $dist_ver isn't supported."
                exit 1
            ;;
            *-aarch64 )
                echo "CentOS/RHEL versions 8 and 9 are supported on aarch64 processors. Current distro version $dist_ver isn't supported."
                exit 1
            ;;
        esac
    ;;

    fedora | fc )
        case ${dist_ver}-$(uname -m) in
            39-* | 40-* ) cent_fedora_install Fedora $(rpm -E %fedora) fc ;;
            * )
                echo "Only Fedora versions 39 and 40 are supported. Current distro version $dist_ver isn't supported."
                exit 1
            ;;
        esac
    ;;

    debian | ubuntu | pop )
        min_ver=10
        max_ver=12
        case ${dist_name} in
            ubuntu )
                min_ver=20
                max_ver=24
            ;;
            pop )
                min_ver=22
                max_ver=22
            ;;
        esac

        # Ubuntu supported versions are 20.XX - 24.XX,
        # Debian supported versions are 10    - 12
        # on both amd64 and arm64.
        # Pop!OS is equal to Ubuntu 22.04 and exists just of the single version 22.04.
        dist_ver=$(echo $dist_ver_dot | cut -d'.' -f1)
        if [ $dist_ver -ge $min_ver ] && [ $dist_ver -le $max_ver ]; then
            # We don't have separate repo for Pop!OS.
            [ "$dist_name" == "pop" ] && dist_name=ubuntu
            deb_ubu_install $dist_name $dist_ver_dot
        else
            echo "${dist_name^} versions $min_ver-$max_ver are supported on $(uname -m) processors. Current distro version $dist_ver_dot isn't supported."
            exit 1
        fi
    ;;

    # The Linux Mint versioning scheme is a bit hard to understand and a bit discrete.
    # They have LTS version 5 based on Debian 11 (Bullseye) and versions 20.X - 21.X
    # based on Ubuntu 20.04 (Focal), 22.04 (Jammy) respectively.
    # See more here https://www.linuxmint.com/download_all.php
    # That's why we'll use discrete version "transformer" from Mint versions to Deian/Ubuntu versions.
    linuxmint )
        case $dist_ver_dot in
            5 ) deb_ubu_install debian 11 ;;
            20* ) deb_ubu_install debian 10 ;;
            21* ) deb_ubu_install ubuntu "22.04" ;;
            *)
                echo "The Linux Mint version $dist_ver_dot is not supported."
                exit 1
            ;;
        esac
    ;;

    opensuse | sles )
        echo "OpenSUSE and SLES aren't currently supported."
        exit 1
    ;;

    *)
        if [ -z "$dist_name" ]; then
            echo "The Linux distribution is not determined."
            exit 1
        fi
        dist_full_name=$dist_name
        if [ -n "$dist_ver_dot" ]; then
            dist_full_name="$dist_name $dist_ver_dot"
        elif [ -n "$dist_ver" ]; then
            dist_full_name="$dist_name $dist_ver"
        fi
        echo "The Linux distribution \"${dist_full_name^}\" isn't currently supported."
        exit 1
    ;;
esac

set -e
inst_comps="CLI and driver have"
[ -z "$driver" ] && inst_comps="CLI has"
[ -z "$cli" ]    && inst_comps="driver has"
echo
echo "The Elastio $inst_comps been installed successfully!"
