set -e
set -x
~/NodeMCU/nodemcu-firmware/luac.cross -o ./LFS.img -f medidoSPI.lua bleSPI.lua adc1115.lua mcp23008.lua LFS_dummy_strings.lua
#
python nodemcu-uploader.py --port /dev/ttyUSB0 --baud 115200 upload LFS.img:LFS.img
# in case no init.lua already there put one there so file remove does not fail
python nodemcu-uploader.py --port /dev/ttyUSB0 --baud 115200 upload _xinit.lua:init.lua
python nodemcu-uploader.py --port /dev/ttyUSB0 --baud 115200 file remove init.lua
python nodemcu-uploader.py --port /dev/ttyUSB0 --baud 115200 node restart
python nodemcu-uploader.py --port /dev/ttyUSB0 --baud 115200 upload _xinit.lua:init.lua
python nodemcu-uploader.py --port /dev/ttyUSB0 --baud 115200 upload reload2.lua:reload2.lua
python nodemcu-uploader.py --port /dev/ttyUSB0 --baud 115200 upload start1.lua:start1.lua
python nodemcu-uploader.py --port /dev/ttyUSB0 --baud 115200 exec reload2.lua
#
putty /dev/ttyUSB0 -serial -sercfg 115200 -geometry 120x80
