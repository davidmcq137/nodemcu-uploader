set -e
set -x
#
~/NodeMCU/nodemcu-firmware/luac.cross -o ./lfs.img -f medido.lua espWebServer.lua LFS_dummy_strings.lua HTTP_OTA.lua
python nodemcu-uploader.py upload lfs.img:lfs.img
#
#echo '~/NodeMCU/nodemcu-firmware/luac.cross -o ./medido.lc  ./medido.lua'
#~/NodeMCU/nodemcu-firmware/luac.cross -o ./medido.lc  ./medido.lua
#
#echo 'python nodemcu-uploader.py upload medido.lc:medido.lc'
#sudo python nodemcu-uploader.py upload medido.lc:medido.lc
#
#echo '~/NodeMCU/nodemcu-firmware/luac.cross -o ./espWebServer.lc  ./espWebServer.lua'
#~/NodeMCU/nodemcu-firmware/luac.cross -o ./espWebServer.lc  ./espWebServer.lua
#echo 'sudo python nodemcu-uploader.py upload espWebServer.lc:espWebServer.lc'
#sudo python nodemcu-uploader.py upload espWebServer.lc:espWebServer.lc
#
#echo 'sudo python nodemcu-uploader.py upload medido.html:index.html'
rm -f medido.html.gz
gzip --keep medido.html
sudo python nodemcu-uploader.py upload medido.html.gz:index.html.gz
#
#echo 'sudo python nodemcu-uploader.py upload medido.js:medido.js'
rm -f medido.js.gz
gzip --keep medido.js
sudo python nodemcu-uploader.py upload medido.js.gz:medido.js.gz
#
#echo 'sudo python nodemcu-uploader.py upload medido.css:medido.css'
rm -f medido.css.gz
gzip --keep medido.css
sudo python nodemcu-uploader.py upload medido.css.gz:medido.css.gz
#
#echo 'sudo python nodemcu-uploader.py exec reload.lua'
sudo python nodemcu-uploader.py exec reload.lua
#
echo 'starting Putty'
sh pp.sh

