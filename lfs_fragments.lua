-- First time image boot to discover the confuration
--
-- If you want to use absolute address LFS load or SPIFFS imaging, then boot the
-- image for the first time bare, that is without either LFS or SPIFFS preloaded
-- then enter the following commands interactively through the UART:
--
do
  local _,ma,fa=node.flashindex()
  for n,v in pairs{LFS_MAPPED=ma, LFS_BASE=fa, SPIFFS_BASE=sa} do
    print(('export %s=""0x%x"'):format(n, v))
  end
end
--
-- This will print out 3 hex constants: the absolute address used in the 
-- 'luac.cross -a' options and the flash adresses of the LFS and SPIFFS.
--
--[[  So you would need these commands to image your ESP module:
USB=/dev/ttyUSB0         # or whatever the device of your USB is
NODEMCU=~/nodemcu        # The root of your NodeMCU file hierarchy
SRC=$NODEMCU/local/lua   # your source directory for your LFS Lua files.
BIN=$NODEMCU/bin
ESPTOOL=$NODEMCU/tools/esptool.py
$ESPTOOL --port $USB erase_flash   # Do this is you are having load funnies
$ESPTOOL --port $USB --baud 460800  write_flash -fm dio 0x00000 \
  $BIN/0x00000.bin 0x10000 $BIN/0x10000.bin
#
# Now restart your module and use whatever your intective tool is to do the above 
# cmds, so if this outputs 0x4027b000, -0x7b000, 0x100000 then you can do
#
$NODEMCU/luac.cross -a 0x4027b000 -o $BIN/0x7b000-flash.img $SRC/*.lua
$ESPTOOL --port $USB --baud 460800  write_flash -fm dio 0x7b000 \
                                                   $BIN/0x7b000-flash.img
# and if you've setup a SPIFFS then
$ESPTOOL --port $USB --baud 460800  write_flash -fm dio 0x100000 \
                                                   $BIN/0x100000-0x10000.img
# and now you are good to go
]]
