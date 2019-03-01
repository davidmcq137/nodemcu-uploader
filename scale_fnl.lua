local function display_create()
  i2c.setup(0, 2, 1, i2c.SLOW)
  return u8g2.ssd1306_i2c_128x64_noname(0, 60)
end
local function u8g2_setup(display)
  display:setFontRefHeightExtendedText()
  display:setDrawColor(1)
  display:setFontPosBottom()
  return display:setFontDirection(0)
end
local function moving_averager(window_size)
  local points = {}
  local index = 1
  local function _0_(this, v)
    print("add-reading ", v)
    points[index] = v
    index = (index + 1)
    if (index == window_size) then
      index = 0
      return nil
    end
  end
  local function _1_(this)
    local acc = 0
    for i, v in ipairs(points) do
      acc = (acc + v)
    end
    print("acc", acc, " n.points", #points)
    return (acc / #points)
  end
  return {["add-reading"] = _0_, ["get-average"] = _1_}
end
local function read_scale()
  return ((hx711.read() + -17800) / 11010.799999999999)
end
display = display_create()
u8g2_setup(display)
hx711.init(4, 0)
do
  local ma = moving_averager(10)
  while true do
    ma["add-reading"](ma, read_scale())
    print(ma["get-average"](ma))
  end
  return nil
end
