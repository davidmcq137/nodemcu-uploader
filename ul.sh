set -e
set -x
~/NodeMCU/nodemcu-firmware/luac.cross -o ./delta_scale.lc  ./delta_scale.lua
sudo python nodemcu-uploader.py  --port /dev/ttyUSB0 --baud 115200 upload s_init.lua:init.lua
sudo python nodemcu-uploader.py  --port /dev/ttyUSB0 --baud 115200 upload delta_scale.lc:s.lc
