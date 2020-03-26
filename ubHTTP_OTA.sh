set -e
set -x
echo "This version compiles only in prep for OTA"
#
~/NodeMCU/nodemcu-firmware/luac.cross -o ./HLFS.img -f HTTP_OTA.lua LFS_dummy_strings.lua
#
#putty /dev/ttyUSB0 -serial -sercfg 115200 -geometry 120x80
