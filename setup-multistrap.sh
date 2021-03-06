#!/bin/bash

# Step 1: Setting up required env

dependencies=( multistrap binfmt-support qemu-user-static )
ssh_packages=( ssh openssh-server )
conf_default=multistrap.conf
conf_powerpcspe=multistrap_debian-ports.conf
conf_s390x=multistrap_no-sshd.conf
rootfs_suffix=debian-rootfs

# Available architectures with their associated qemu
declare -A qemu_static
#qemu_static[amd64]=qemu-x86_64-static => see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=703825
qemu_static[arm64]=qemu-aarch64-static
qemu_static[armel]=qemu-arm-static
qemu_static[armhf]=qemu-arm-static
qemu_static[i386]=qemu-i386-static
qemu_static[mips]=qemu-mips-static
qemu_static[mipsel]=qemu-mipsel-static
qemu_static[powerpc]=qemu-ppc-static
qemu_static[powerpcspe]=qemu-ppc-static
qemu_static[ppc64el]=qemu-ppc64le-static
qemu_static[s390x]=qemu-s390x-static

print_archs() {
    echo "    - $host_arch"
    for i in ${!qemu_static[@]}; do
	if [[ $i != $host_arch ]]; then
            echo "    - $i"
        fi
    done
}

# Check script is sourced
#if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#    echo "`basename $0` needs to be sourced"
#    exit 1
#fi

# Get caller script
caller_script=`basename $(caller | awk '{print $2}')`
exit_or_return=`[[ $caller_script != NULL ]] && echo exit|| echo return`

# Make sure only root can run our script
if [[ $(id -u) != 0 ]]; then
   echo "This script must be run as root"
   $exit_or_return 1
fi

# Required packages to build rootfs
for i in ${build_packages[@]}; do
    if ! dpkg -s $i 2>/dev/null | grep -q "Status: install ok installed"; then
        echo "$i package is required, please install it"
        $exit_or_return 1
    fi
done

# Get host architecture
host_arch=`dpkg --print-architecture`

# Print usage
if [[ ! $1 || $1 == "-h" || $1 == "--help" ]]; then
    running_script=`[[ $caller_script != NULL ]] && echo $caller_script ||\
    echo "source \`basename ${BASH_SOURCE[0]}\`"`

    echo "usage: $running_script ARCHITECTURE [MULTISTRAP_CONF]"
    echo "  ARCHITECTURE can be:"
    print_archs
    echo "  MULTISTRAP_CONF is a multistrap configuration file"
    echo "                  defaults to $conf_default"
    echo "                  defaults to $conf_s390x for s390x"
    echo "                  defaults to $conf_powerpcspe for powerpcspe"
    $exit_or_return 1
fi
arch=$1

# Default multistrap configuration file
case $arch in
    powerpcspe) conf_file=$conf_powerpcspe ;;
    s390x) conf_file=$conf_s390x ;;
    *) conf_file=$conf_default
esac

# User defined multistrap configuration file
if [[ $2 ]]; then
    conf_file=$2
    if [[ ! -f $conf_file ]]; then
        echo "$conf_file file does not exist"
        $exit_or_return 1
    fi
fi

# Check architecture is suppported
if [[ $arch != $host_arch ]]; then
    if [[ ! ${qemu_static[$arch]} ]]; then
        echo "$arch not valid, architectures supported are:"
        print_archs
        $exit_or_return 1
    fi
    
    # Find qemu binary
    qemu_path=`which ${qemu_static[$arch]}`

    case $arch in
        powerpcspe)
            # Set qemu-ppc-static to support powerpcspe
            export QEMU_CPU=e500v2
            ;;
        s390x)
            # qemu-s390x-static cannot install openssh-server
            for i in ${ssh_packages[@]}; do
	        if grep -q "\b$i\b" $conf_file; then
                    echo "$i package in $conf_file cannot be installed for s390x"
                    $exit_or_return 1
                fi
            done
            ;;
    esac
fi

# Create build directory
build_dir=build/$arch
mkdir -p $build_dir 2>/dev/null

# Set rootfs directory
rootfs_dir=$rootfs_suffix\-$arch


# Step 2: Installing and configuring the rootfs

# Get current UTC time
utc_time=`date -u -d"$(wget -qO- --save-headers http://www.debian.org |\
            sed '/^Date: /!d;s///;q')" +%Y%m%dT%H%M%SZ`
rootfs_dir_utc=$rootfs_dir-$utc_time

# Cleanup when interrupt signal is received
trap "umount $build_dir/$rootfs_dir_utc/dev; exit 1" SIGINT


if [[ $arch == $host_arch ]]; then
    # Create /dev in rootfs
    mkdir -p $build_dir/$rootfs_dir_utc/dev 2>/dev/null

    # Mount /dev in rootfs
    mount --bind /dev $build_dir/$rootfs_dir_utc/dev

    # Create root file system and configure debian packages
    multistrap -d $build_dir/$rootfs_dir_utc -a $arch -f $conf_file
    if [[ $? != 0 ]]; then
        echo "mutltistrap with configuration file $conf_file failed"
        umount $build_dir/$rootfs_dir_utc/dev
        rm -rf $build_dir/$rootfs_dir_utc
        exit 1
    fi
else
    # Create root file system
    multistrap -d $build_dir/$rootfs_dir_utc -a $arch -f $conf_file
    if [[ $? != 0 ]]; then
        echo "mutltistrap with configuration file $conf_file failed"
        rm -rf $build_dir/$rootfs_dir_utc
        exit 1
    fi

    # Set environment variables
    export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
    export LC_ALL=C LANGUAGE=C LANG=C

    # Copy qemu binary to rootfs
    cp $qemu_path $build_dir/$rootfs_dir_utc$qemu_path

    # Mount /dev in rootfs
    mount --bind /dev $build_dir/$rootfs_dir_utc/dev

    # Complete the configure of dash
    chroot $build_dir/$rootfs_dir_utc /var/lib/dpkg/info/dash.preinst install

    # Configure debian packages
    chroot $build_dir/$rootfs_dir_utc dpkg --configure -a
fi

# Empty root password
chroot $build_dir/$rootfs_dir_utc passwd -d root

# Get packages installed
chroot $build_dir/$rootfs_dir_utc dpkg -l | awk '{if (NR>3) {print $2" "$3}}' > $build_dir/$rootfs_dir_utc\-packages

# Kill processes running in rootfs
fuser -sk $build_dir/$rootfs_dir_utc

# Remove qemu binary from rootfs
rm $build_dir/$rootfs_dir_utc$qemu_path 2>/dev/null

# Umount /dev in rootfs
umount $build_dir/$rootfs_dir_utc/dev

# Latest rootfs is the current one
ln -sfn $rootfs_dir_utc $build_dir/$rootfs_dir


# Step 3: Configure debian rootfs

# Set hostname
filename=$build_dir/$rootfs_dir/etc/hostname
echo $arch > $filename

# DNS.WATCH servers
filename=$build_dir/$rootfs_dir/etc/resolv.conf
echo "# DNS.WATCH servers" > $filename
echo "nameserver 84.200.69.80" >> $filename
echo "nameserver 84.200.70.40" >> $filename

# Enable root autologin
filename=$build_dir/$rootfs_dir/lib/systemd/system/serial-getty@.service
autologin='--autologin root'
execstart='ExecStart=-\/sbin\/agetty'
if [[ ! $(grep -e "$autologin" $filename) ]]; then
    sed -i "s/$execstart/$execstart $autologin/" $filename
fi

# Set systemd logging
filename=$build_dir/$rootfs_dir/etc/systemd/system.conf
for i in 'LogLevel=warning'\
         'LogTarget=journal'\
; do
    sed -i "/${i%=*}/c\\$i" $filename
done

# Enable root to connect to ssh with empty password
filename=$build_dir/$rootfs_dir/etc/ssh/sshd_config
if [[ -f $filename ]]; then
    for i in 'PermitRootLogin yes'\
             'PermitEmptyPasswords yes'\
             'UsePAM no'\
    ; do
        sed -ri "/^#?${i% *}/c\\$i" $filename
    done
fi

echo
echo "$build_dir/`readlink $build_dir/$rootfs_dir` configured"


 # Step 4: Archive the rootfs
 
 TAR_EXTENSION=.tar.gz

rootfs_dir_utc=`readlink $build_dir/$rootfs_dir`
tar_name=$rootfs_dir_utc$TAR_EXTENSION

cd $build_dir
tar cpfz $tar_name $rootfs_dir_utc
cd - >/dev/null

echo
echo "$build_dir/$tar_name created"
