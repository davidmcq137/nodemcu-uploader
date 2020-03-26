set -e
set -x
echo "This version does first setup upload .. assumes OTA updates"
#
~/NodeMCU/nodemcu-firmware/luac.cross -o ./HLFS.img -f HTTP_OTA.lua LFS_dummy_strings.lua
#
python nodemcu-uploader.py --port /dev/ttyUSB0 --baud 115200 upload HLFS.img:HLFS.img
python nodemcu-uploader.py --port /dev/ttyUSB0 --baud 115200 upload _xinitH.lua:init.lua
python nodemcu-uploader.py --port /dev/ttyUSB0 --baud 115200 upload start1HTTP.lua:start1HTTP.lua
python nodemcu-uploader.py --port /dev/ttyUSB0 --baud 115200 upload reloadH.lua:reloadH.lua
python nodemcu-uploader.py --port /dev/ttyUSB0 --baud 115200 exec reloadH.lua
#
putty /dev/ttyUSB0 -serial -sercfg 115200 -geometry 120x80
