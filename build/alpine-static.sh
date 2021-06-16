#!/bin/sh
set -ex

cd /

apk add alpine-sdk openssl-dev openssl-libs-static

git clone https://github.com/vlang/v
cd v && make

cd /
export PATH=/v:$PATH

mkdir /root/.vmodules/despiegk
mkdir /root/.vmodules/threefoldtech

git clone https://github.com/threefoldtech/vgrid /root/.vmodules/threefoldtech/vgrid
git clone https://github.com/threefoldtech/rmb /root/.vmodules/threefoldtech/rmb
git clone https://github.com/crystaluniverse/crystallib /root/.vmodules/despiegk/crystallib

cd /root/.vmodules/threefoldtech/rmb/msgbusd
v -cc gcc -cflags -static msgbusd.v
strip -s msgbusd
