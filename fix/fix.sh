#!/bin/bash

dir=$(dirname $0)
mkdir ./temp
cd ./temp
sudo apt-get install -y gettext checkinstall
wget -O pkg.tar.xz https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/multistrap/2.2.9/multistrap_2.2.9.tar.xz
tar -xvf pkg.tar.xz
cd multistrap-2.2.9
patch -p1 < ../../fix.patch multistrap
make
sudo checkinstall
cd $dir
