#!/usr/bin/bash
#cd $(dirname $0)
unset LD_PRELOAD
command="proot"
command+=" -0"
command+=" -r debian-fs"
#if [ -n "$(ls -A debian-binds)" ]; then
#    for f in debian-binds/* ;do
#      . $f
#    done
#fi
command+=" -b /dev"
command+=" -b /proc"
command+=" -b debian-fs/root:/dev/shm"
command+=" -w /root"
command+=" /usr/bin/env -i"
command+=" HOME=/root"
command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
command+=" TERM=$TERM"
command+=" LANG=C.UTF-8"
command+=" /bin/bash --login"
com="$@"
if [ -z "$1" ];then
    exec $command
else
    $command -c "$com"
fi
