set -e
set -x
sudo python nodemcu-uploader.py  --port /dev/ttyUSB1 --baud 115200 upload spi.lua
sudo python nodemcu-uploader.py  --port /dev/ttyUSB1 --baud 115200 exec spi.lua
sudo putty /dev/ttyUSB1 -serial -sercfg 115200

