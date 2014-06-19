#!/bin/sh
apt-get install git
git clone https://github.com/karelzak/util-linux.git util-linux
apt-get install libncurses5-dev libslang2-dev gettext zlib1g-dev libselinux1-dev debhelper lsb-release pkg-config po-debconf autoconf automake autopoint libtool
cd util-linux && ./autogen.sh && ./configure && make
cp ./nsenter /usr/bin/nsenter
cd .. && rm -r util-linux/
