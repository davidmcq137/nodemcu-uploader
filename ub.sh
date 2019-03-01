set -e
set -x
~/NodeMCU/nodemcu-firmware/luac.cross -o ./lfs.img -f bluefruitspi.lua LFS_dummy_strings.lua
python nodemcu-uploader.py --port /dev/ttyUSB0 --baud 115200 upload lfs.img:lfs.img
sudo python nodemcu-uploader.py --port /dev/ttyUSB0 --baud 115200 exec reload2.lua
#
putty /dev/ttyUSB0 -serial -sercfg 115200 -geometry 120x80

