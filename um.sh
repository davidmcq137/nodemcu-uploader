set -e
set -x
sudo python nodemcu-uploader.py  --port /dev/ttyUSB0 --baud 115200 upload medido_nopump.lua:mn.lua
