# see ff0.sh for just these top commands
set -e
set -x
cat zepto.min.js smoothieMod.js sprintf.js gauge.min.js > utils.js
rm -f utils.js.gz
gzip --keep utils.js
#
sudo python nodemcu-uploader.py upload utils.js.gz
#
sudo python nodemcu-uploader.py upload lfs_init.lua:init.lua
#
sudo python nodemcu-uploader.py upload dir.lua
#
sudo python nodemcu-uploader.py upload sta_init.lua
#
sudo python nodemcu-uploader.py upload start.lua
#
sudo python nodemcu-uploader.py upload _init.lua
#
sudo python nodemcu-uploader.py upload stop.lua
#
sudo python nodemcu-uploader.py upload reload.lua
#
sudo python nodemcu-uploader.py upload ROMstrings.lua
#
sudo python nodemcu-uploader.py upload RAMstrings.lua
#
sudo python nodemcu-uploader.py upload dummyStrings.lua

