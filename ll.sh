set -e
set -x
#
~/NodeMCU/nodemcu-firmware/luac.cross -o ./lfs.img -f medido.lua espWebServer.lua LFS_dummy_strings.lua HTTP_OTA.lua
echo 'compiled lfs.img from medido.lua, espWebServer.lua, LFS_dummy_strings.lua HTTP_OTA.lua'
python nodemcu-uploader.py upload lfs.img:lfs.img
#
sudo python nodemcu-uploader.py exec reload.lua
#
sh pp.sh
