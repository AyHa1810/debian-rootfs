#!/bin/bash

# Make sure only root can run our script
if [[ $(id -u) != 0 ]]; then
   echo "This script must be run as root"
   $exit_or_return 1
fi

build_packages=( multistrap binfmt-support qemu-user-static )
sshd_packages=( ssh openssh-server )
conf_default=multistrap.conf
conf_powerpcspe=multistrap_debian-ports.conf
conf_s390x=multistrap_no-sshd.conf
rootfs_suffix=rootfs
