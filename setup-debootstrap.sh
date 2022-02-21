#!/bin/bash

# Step 1: Setting up required env

dependencies=( debootstrap binfmt-support qemu-user-static )
ssh_packages=( ssh openssh-server )
debpkg_default='kmod dbus apt apt-utils xz-utils dialog net-tools locales iproute2 iputils-ping ifupdown ssh nano pciutils i2c-tools dosfstools wget man-db'
debpkg_powerpcspe='systemd-sysv udev kmod dbus apt apt-utils xz-utils dialog locales debian-ports-archive-keyring net-tools iproute2 iputils-ping ifupdown ssh nano pciutils i2c-tools dosfstools wget man-db'
debpkg_s390x='kmod dbus apt apt-utils xz-utils dialog locales net-tools iproute2 iputils-ping ifupdown openssh-client nano pciutils i2c-tools dosfstools wget man-db'
rootfs_suffix=debian-rootfs

# Available architectures with their associated qemu
declare -A qemu_static
#qemu_static[amd64]=qemu-x86_64-static #=> see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=703825
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

# Prints the archs list
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
case $host_arch in
    aarch64) host_arch=arm64 ;;
    *) host_arch=$host_arch
esac

# Print usage
function show_usage (){
    running_script=`[[ $caller_script != NULL ]] && echo $caller_script ||\
    echo "source \`basename ${BASH_SOURCE[0]}\`"`

    echo "usage: $running_script [-harRiev?]"
    echo ""
    echo "Arguments:"
    echo " -h, --help    : Shows this help menu."
    echo " -a, --arch    : Sets the architecture to make the rootfs of."
    echo " -r, --release : Sets the Debian rootfs release. (default: stable)"
    echo " -R, --repo    : Gets packages from the given repository."
    echo " -i, --include : Includes the packages to be installed in the rootfs."
    echo " -e, --exclude : Excludes the packages to be not installed. (It is dangerous to exclude important packages.)"
    echo " -v, --variant : Sets the variant of debian to install."
    echo ""
    echo "  arch can be:"
    print_archs
$exit_or_return 0
}

# Set command arguments
while [[ $# -gt 0 ]]; do
    opt="$1"
    shift;
    current_arg="$1"
    if [[ "$current_arg" =~ ^-{1,2}.* ]]; then
        echo "WARNING: You may have left an argument blank. Double check your command." 
    fi
    case "$opt" in
        "-h"|"--help"|"?" ) show_usage
                            $exit_or_return 0;;
        "-a"|"--arch"     ) arch="$1"; shift;;
             "--arch=*"   ) arch="${0/--arch=/''}"; shift;;
        "-r"|"--release"  ) release="$1"; shift;;
        "-R"|"--repo"     ) repo="$1"; shift;;
        "-i"|"--include"  ) include="$1"; shift;;
        "-e"|"--exclude"  ) exclude="$1"; shift;;
	"-v"|"--variant"  ) variant="$1"; shift;;
        *                 ) show_usage >&2
                            $exit_or_return 1;;
    esac
done

# we can also do this 
# (I'm jus including this line for my learning experience :P)
#while (( "$#" )); do
#    case "${1}"  in
#        --help   ) show_usage && exit 0;;
#         -h      ) show_usage && exit 0;;
#        --zip    ) make_dry=1; shift;;
#        --arch=* ) arch=${1/--arch=/''}; shift;;
#        --arch*  ) arch=${2}; shift; shift;;
#        --repo=* ) repo=${1/--repo=/''}; shift;;
#        --repo*  ) repo=${2}; shift; shift;;
#          *      ) show_usage >&2; $exit_or_return 1;;
#    esac
#done

if [[ ! $arch ]]; then
    arch=$host_arch
fi

if [[ ! $release ]]; then
    release=stable
fi

if [[ ! $repo ]]; then
    repo=http://ftp.debian.org/debian/
fi

if [[ ! $variant ]]; then
    variant=minbase
fi

# Default packages
case $arch in
    powerpcspe) instpkgs=$debpkg_powerpcspe ;;
    s390x) instpkgs=$debpkg_s390x ;;
    *) instpkgs=$debpkg_default
esac

if [[ ! $include ]]; then
    includepkg="$instpkgs"
else
    includepkg="$instpkgs $include"
fi

if [[ ! $exclude ]]; then
    excludepkg=""
else
    excludepkg="--exclude $exclude"
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
main_dir=build
build_dir=$main_dir/$arch
mkdir -p $build_dir 2>/dev/null
mkdir -p $main_dir/logs 2>/dev/null

# Set rootfs directory
rootfs_dir=$rootfs_suffix\-$arch


# Step 2: Installing and configuring the rootfs

# Get current UTC time
utc_time=`date -u -d"$(wget -qO- --save-headers http://www.debian.org |\
            sed '/^Date: /!d;s///;q')" +%Y%m%dT%H%M%SZ`
rootfs_dir_utc=$rootfs_dir-$utc_time

# Log the output into a file (best one I tried yet)
#LOG_FILE=build/logs/$rootfs_dir_utc.log
#if [[ -f "./log4bash.sh" ]]; then
#    source ./log4bash.sh
#    exec > >(
#        while read -r line 
#        do 
#            if echo "$line" | grep -wq 'W:\|warning:'; then 
#                log_warning "$line" 
#            elif echo "$line" | grep -wq 'E:\|error:'; then 
#                log_error "$line"
#            else 
#                log "$line"
#            fi | tee -a $LOG_FILE 
#        done
#    )
#    exec 2> >(while read -r line; do log_error "$line" | tee -a $LOG_FILE; done >&2)
#fi

#exec > >(while read -r line; do printf '%s %s\n' "$(date --utc +"%Y-%m-%d %H:%M:%S")" "[INFO]:" "$line" | tee -a $LOG_FILE; done)
#exec 2> >(while read -r line; do printf '%s %s\n' "$(date --utc +"%Y-%m-%d %H:%M:%S")" "[ERROR]:" "$line" | tee -a $LOG_FILE; done >&2)

# Previous ones I tried :P
#exec 3>&1 4>&2
#trap 'exec 2>&4 1>&3' 0 1 2 3
#exec 1>$LOG_FILE 2>&1 

#exec > >(tee -a ${LOG_FILE} )
#exec 2> >(tee -a ${LOG_FILE} >&2)

# Cleanup when interrupt signal is received
trap 'exumount; $exit_or_return 1' SIGINT

function exumount() {
    if mount | grep $build_dir/$rootfs_dir_utc/dev > /dev/null; then
        umount $build_dir/$rootfs_dir_utc/dev
    else
        :
    fi
}

if [[ $arch == $host_arch ]]; then
    # Create /dev in rootfs
    #mkdir -p $build_dir/$rootfs_dir_utc/dev 2>/dev/null

    # Mount /dev in rootfs
    #mount --bind /dev $build_dir/$rootfs_dir_utc/dev

    # Create root file system and configure debian packages
    if debootstrap --verbose --arch $arch $excludepkg "$release" "$build_dir/$rootfs_dir_utc" "$repo"
    then
        echo "I: debootstrap successfully finished"
    else
    #if [[ $? != 0 ]]; then
        echo "E: debootstrap failed" >&2
        #umount "$build_dir/$rootfs_dir_utc/dev"
        exumount
        rm -rf "$build_dir/$rootfs_dir_utc"
        exit 1
    fi
else
    # Create root file system
    if debootstrap --verbose --variant=$variant --foreign --arch $arch $excludepkg "$release" "$build_dir/$rootfs_dir_utc" "$repo"
    then
        echo "I: Debootstrap successfully finished"
    else
    #if [[ $? != 0 ]]; then
        echo "E: Debootstrap failed" >&2
        rm -rf "$build_dir/$rootfs_dir_utc"
        exit 1
    fi

    # Set environment variables
    export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
    export LC_ALL=C LANGUAGE=C LANG=C

    # Copy qemu binary to rootfs
    cp $qemu_path $build_dir/$rootfs_dir_utc$qemu_path

    # Mount /dev in rootfs
    mount --bind /dev "$build_dir/$rootfs_dir_utc/dev"

    # Complete the configure of dash
    chroot "$build_dir/$rootfs_dir_utc" /var/lib/dpkg/info/dash.preinst install

    # Configure debian packages
    chroot "$build_dir/$rootfs_dir_utc" dpkg --configure -a
fi

# Run debootstrap second stage if it exists
if [[ -f "$build_dir/$rootfs_dir_utc/debootstrap/debootstrap" ]]; then
    chroot "$build_dir/$rootfs_dir_utc" /debootstrap/debootstrap --second-stage
fi

# Empty root password
chroot $build_dir/$rootfs_dir_utc passwd -d root

# Get packages installed
chroot $build_dir/$rootfs_dir_utc dpkg -l | awk '{if (NR>3) {print $2" "$3}}' > $build_dir/$rootfs_dir_utc\-packages

# Install packages
chroot $build_dir/$rootfs_dir_utc /bin/bash -c "apt-get update && apt-get upgrade -y && apt-get install -y $includepkg"

# Generate locale
chroot $build_dir/$rootfs_dir_utc locale-gen en_US.UTF-8

# Kill processes running in rootfs
#fuser -sk $build_dir/$rootfs_dir_utc

# Remove qemu binary from rootfs
rm $build_dir/$rootfs_dir_utc$qemu_path 2>/dev/null

# Umount /dev in rootfs
if mount | grep $build_dir/$rootfs_dir_utc/dev > /dev/null; then
  umount $build_dir/$rootfs_dir_utc/dev
fi

# Latest rootfs is the current one
ln -sfn $rootfs_dir_utc $build_dir/$rootfs_dir


# Step 3: Configure debian rootfs

# Set hostname
filename=$build_dir/$rootfs_dir/etc/hostname
echo "debian" > $filename

# Set hosts
filename=$build_dir/$rootfs_dir/etc/hosts
echo "127.0.0.1 localhost" > $filename
echo "127.0.1.1 debian" >> $filename
echo >> $filename
echo "# The following lines are desirable for IPv6 capable hosts" >> $filename
echo "::1 ip6-localhost ip6-loopback" >> $filename
echo "fe00::0 ip6-localnet" >> $filename
echo "ff00::0 ip6-mcastprefix" >> $filename
echo "ff02::1 ip6-allnodes" >> $filename
echo "ff02::2 ip6-allrouters" >> $filename
echo "ff02::3 ip6-allhosts" >> $filename

# DNS.WATCH servers
filename=$build_dir/$rootfs_dir/etc/resolv.conf
echo "# DNS.WATCH servers" > $filename
echo "nameserver 84.200.69.80" >> $filename
echo "nameserver 84.200.70.40" >> $filename

# Set default locale
filename=$build_dir/$rootfs_dir/etc/default/locale
echo "LANG=en_US.UTF-8" > $filename

# Set apt repository
filename=$build_dir/$rootfs_dir/etc/apt/sources.list
echo "deb http://deb.debian.org/debian stable main contrib non-free" > $filename
echo "deb-src http://deb.debian.org/debian stable main contrib non-free" >> $filename
echo "" >> $filename
echo "deb http://deb.debian.org/debian-security/ stable-security main contrib non-free" >> $filename
echo "deb-src http://deb.debian.org/debian-security/ stable-security main contrib non-free" >> $filename
echo "" >> $filename
echo "deb http://deb.debian.org/debian stable-updates main contrib non-free" >> $filename
echo "deb-src http://deb.debian.org/debian stable-updates main contrib non-free" >> $filename

# Keep the rootfs up-to-date with the repos
chroot $build_dir/$rootfs_dir_utc /bin/bash -c "apt-get update && apt-get upgrade -y && apt autoremove -y"

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

# Clean apt cache
chroot $build_dir/$rootfs_dir_utc /bin/bash -c "apt clean"

# Clean bash history
chroot $build_dir/$rootfs_dir_utc /bin/bash -c "history -c && history -w"

echo
echo "$build_dir/`readlink $build_dir/$rootfs_dir` configured"


 # Step 4: Archive the rootfs
 
 TAR_EXTENSION=.tar.gz

rootfs_dir_utc=`readlink $build_dir/$rootfs_dir`
tar_name=$rootfs_dir_utc$TAR_EXTENSION

cd $build_dir
#tar cpfz $tar_name $rootfs_dir_utc
tar cpfz $tar_name -C $rootfs_dir_utc/ .

cd - >/dev/null

echo
echo "$build_dir/$tar_name created"
