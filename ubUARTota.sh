set -e
set -x
~/NodeMCU/nodemcu-firmware/luac.cross -o ./MedP.img -f medidoUARTPololu.lua adc1115.lua httpOTA.lua LFS_dummy_strings.lua
