#!/bin/bash

me="./install-elastio.sh"
default_branch=release

MAX_LINUX_VER=5
MAX_LINUX_MAJOR_REV=15

cent_fedora_kernel_devel_install()
{
    if ! yum install -y kernel-devel-$(uname -r) kernel-devel ; then
        echo
        echo "Failed to install package kernel-devel-$(uname -r) for the current running kernel."
        echo "This package is dependency of the Elastio-Snap kernel driver."
        echo "Please update current kernel to the most recent version, reboot machine into it and try again."
        [[ "$1" == "CentOS" ]] &&  echo "Or enable Vault repo and try again."
        exit 1
    fi
}

cent7_amazon_install()
{
    if [ ! -z "$driver" ]; then
        cent_fedora_kernel_devel_install $1
        yum install -y dkms-elastio-snap elastio-snap-utils
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
    if [ "$1" = "CentOS" ] && grep "Red Hat" -q /etc/redhat-release 2>/dev/null ; then
        yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$2.noarch.rpm
    elif [ "$1" = "Amazon" ]; then
        amazon-linux-extras install -y epel
        yum install -y nbd
    fi

    # The elastio-repo package is going to be moved from the x86_64/Packages to the noarch/Packages
    # This process can take some time and the package location can be different between branches for
    # some period of time. That's why trying both paths.
    url=$repo_url/rpm/$1/$2/noarch/Packages/elastio-repo-0.0.2-1.$3$2.noarch.rpm
    if (($(curl -s -I -L -m 2 "$url" | grep -E "^HTTP" | awk '{ print $2 }' | tail -1) != 200)) ; then
        url=$repo_url/rpm/$1/$2/x86_64/Packages/elastio-repo-0.0.2-1.$3$2.noarch.rpm
    fi
    yum localinstall -y $url
    which dnf >/dev/null 2>&1 &&
        cent8_fedora_install $1 $2 $3 ||
        cent7_amazon_install $1 $2 $3

    # Install ntfs-3g to any RPM-based distro except Fedora 35 with the kernel 5.15
    [ $2 -lt 35 ] && yum install -y ntfs-3g
}

check_installed()
{
    dpkg -l | grep ^ii | awk '{ print $2}' | grep -q -E ^$1$
}

deb_ubu_install()
{
    debian_ver=$1
    if ! check_installed wget || ! check_installed gnupg ; then
        apt-get update
        check_installed wget  || apt-get install -y wget
        check_installed gnupg || apt-get install -y gnupg
    fi

    pkg=elastio-repo_0.0.2-1debian${debian_ver}_all.deb
    wget $repo_url/deb/Debian/${debian_ver}/pool/$pkg
    dpkg -i $pkg && rm -f $pkg
    apt-get update
    # Maybe new kernel was installed recently but machine was not yet booted into it.
    # In this case dkms will install as dependency linux-headers-[latest kernel version].
    # But we need to have driver built and loaded right now without reboot, that's why
    # installing linux-headers package for the current kernel.
    [ ! -z "$driver" ] && apt-get install -y linux-headers-$(uname -r)
    if [ ! -z "$driver" ] && [ ! -z "$cli" ]; then
        # Install elastio and driver as dependency
        apt-get install -y elastio
    elif [ ! -z "$driver" ]; then
        # Install just driver
        apt-get install -y elastio-snap-utils
    elif [ ! -z "$cli" ]; then
        # Install just elastio w/o driver as dependency
        apt-get --no-install-recommends install -y elastio ntfs-3g
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
    echo "   $me --cli-only"
    echo "   $me --driver-only"
    echo
    echo "  -c | --cli-only       : Install Elastio CLI only, without change tracking driver elastio-snap."
    echo
    echo "  -d | --driver-only    : Install change tracking driver elastio-snap only, without Elastio CLI."
    echo "                          NOTES:"
    echo "                            - There are no elastio-snap packages for Fedora (kernel versions newer than $MAX_LINUX_VER.$MAX_LINUX_MAJOR_REV) as of yet."
    echo "                              So, temporarily this option does nothing on the latest Fedora with the latest Linux kernel versions."
    echo "                            - elastio-snap change tracking driver does not support ARM64 architecture."
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

if [ "$EUID" -ne 0 ]; then
	echo "Run as sudo or root."
	exit 1
fi

set -e

[ -z "$branch" ] && branch=$default_branch
repo_url=https://repo.assur.io/$branch/linux

if [ ! -z "$uninstall" ]; then
    uninstall_all
    exit
fi

# Detect distro name and version
if [ -f /etc/os-release ]; then
    dist_name=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
    dist_ver=$(grep VERSION_ID /etc/os-release | tr -cd '[0-9].' | cut -d'.' -f1)
else
    dist_name=$(cat /etc/system-release 2>/dev/null | cut -d' ' -f1)
    dist_ver=$(cat /etc/system-release 2>/dev/null | tr -cd '[0-9.]' | cut -d'.' -f1)
fi

# Lowercase dist_name
dist_name=$(echo ${dist_name,,})

if [ -z "$cli" ] && [ -z "$driver" ]; then
    cli=1
    [ $(uname -m) != "aarch64" ] && driver=1
fi

if [ ! -z "$driver" ]; then
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

case ${dist_name} in
    amazon | amzn )
        if [ $dist_ver -ne 2 ]; then
            echo "The Amazon Linux 2 is only supported. Current Amazon Linux $dist_ver isn't supported."
            exit 1
        fi
        cent_fedora_install Amazon $(rpm -E %amzn) amzn
    ;;

    scientific | sl | oracle | ol )
        echo "Warning: Oracle Linix and Scientific Linux are not officially supported!"
        if [ -z $force ]; then
            echo "We can try to install packages for CentOS on your system."
            echo "Add '--force' to insist on the installation. But beware this isn't officially supported!"
            exit 1
        fi
    ;;&

    centos | almalinux | rocky | el | rhel | red | scientific | sl | oracle | ol )
        case ${dist_ver} in
            7 | 8 ) cent_fedora_install CentOS $(rpm -E %rhel) el ;;
            * )
                echo "CentOS/RHEL versions 7 and 8 are supported. Current distro version $dist_ver isn't supported."
                exit 1
            ;;
        esac
    ;;

    fedora | fc )
        case ${dist_ver} in
            31 | 34 | 35 ) cent_fedora_install Fedora $(rpm -E %fedora) fc ;;
            * )
                echo "Fedora versions 31 and 34, 35 are supported. Current distro version $dist_ver isn't supported."
                exit 1
            ;;
        esac
    ;;

    debian | ubuntu )
        factor=1
        [ "$dist_name" == "ubuntu" ] && factor=2
        min_ver=$((9*$factor))
        max_ver=$((11*$factor))
        # Let's do not support Ubuntu 22 yet ))
        [ $max_ver -gt 20 ] && max_ver=20
        if [ $dist_ver -ge $min_ver ] && [ $dist_ver -le $max_ver ]; then
            deb_ubu_install $(($dist_ver/$factor))
        else
            echo "${dist_name^} versions $min_ver-$max_ver are supported. Current distro version $dist_ver isn't supported."
            exit 1
        fi
    ;;

    opensuse | sles )
        echo "OpenSUSE and SLES aren't currently supported."
        exit 1
    ;;

    *)
        echo "The Linux distributive \"$dist_name $dist_ver\" isn't currently supported."
        exit 1
    ;;
esac

set -e
inst_comps="CLI and driver have"
[ -z "$driver" ] && inst_comps="CLI has"
[ -z "$cli" ]    && inst_comps="driver has"
echo
echo "The Elastio $inst_comps been installed successfully!"
