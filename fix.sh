#!/bin/bash

dir=$(dirname $0)
mkdir ./temp
cd ./temp
sudo apt-get -y build-dep multistrap
apt-get source multistrap
dir
