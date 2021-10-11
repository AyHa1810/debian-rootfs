#!/bin/bash

dir=$(dirname $0)
mkdir ./temp
cd ./temp
sudo apt-get -y build-dep multistrap gettext
wget -O pkg.tar.xz http://deb.debian.org/debian/pool/main/m/multistrap/multistrap_2.2.11.tar.xz
tar -xvf pkg.tar.xz
cd multistrap-2.2.11
patch -p1 < ../../fix.patch multistrap
make
make -i install
cd $dir
