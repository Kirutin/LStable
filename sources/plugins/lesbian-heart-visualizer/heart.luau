--!nonstrict

local BAND_COUNT = 40
local CANVAS_WIDTH = 408
local CANVAS_HEIGHT = 216
local HEART_WIDTH = 396
local HEART_HEIGHT = 204
local BAR_GAP = 2
local BAR_WIDTH = (HEART_WIDTH - (BAND_COUNT - 1) * BAR_GAP) / BAND_COUNT

local values = {}
local previousValues = {}
local envelope = {}
local audioActive = false
local watchRegistered = false
local lastRenderAt = 0
local activeFrameReported = false
local lastSpectrumAt = 0
local lastOnsetAt = -1000
local pulseHoldUntil = 0
local rhythmPulse = 0.0
local fluxAverage = 0.0
local fluxDeviation = 0.0

for index = 1, BAND_COUNT do
  values[index] = 0.0
  previousValues[index] = 0.0
end

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function cubic(value)
  return value * value * value
end

local function buildEnvelope()
  local globalTop = 1.25
  local globalBottom = -1.10
  local yRange = globalTop - globalBottom

  for index = 1, BAND_COUNT do
    local x = -1.15 + 2.30 * ((index - 0.5) / BAND_COUNT)
    local bottom = nil
    local top = nil
    for step = 0, 260 do
      local y = globalBottom + yRange * step / 260
      local sum = x * x + y * y - 1.0
      local implicit = cubic(sum) - x * x * cubic(y)
      if implicit <= 0.0 then
        if bottom == nil then bottom = y end
        top = y
      end
    end
    bottom = bottom or 0.0
    top = top or 0.0
    envelope[index] = {
      top = (globalTop - top) / yRange * HEART_HEIGHT,
      bottom = (globalTop - bottom) / yRange * HEART_HEIGHT,
    }
  end
end

local function colorBetween(first, second, amount)
  local red = math.floor(first[1] + (second[1] - first[1]) * amount + 0.5)
  local green = math.floor(first[2] + (second[2] - first[2]) * amount + 0.5)
  local blue = math.floor(first[3] + (second[3] - first[3]) * amount + 0.5)
  return string.format("#%02x%02x%02x", red, green, blue)
end

local function bandColor(index)
  local progress = (index - 1) / (BAND_COUNT - 1)
  local pink = { 255, 15, 84 }
  local magenta = { 240, 24, 169 }
  local violet = { 124, 85, 255 }
  if progress <= 0.56 then
    return colorBetween(pink, magenta, progress / 0.56)
  end
  return colorBetween(magenta, violet, (progress - 0.56) / 0.44)
end

local function render()
  local energy = 0.0
  for index = 1, BAND_COUNT do
    energy = math.max(energy, values[index])
  end
  local visible = audioActive or energy > 0.012
  local baseline = HEART_HEIGHT * (1.25 / 2.35)
  local bars = {}

  for index = 1, BAND_COUNT do
    local shape = envelope[index]
    local color = bandColor(index)
    -- Each frequency remains a free bar.  The shared pulse is detected from
    -- changes across all 40 bands (not from bass), so every rhythmic onset can
    -- briefly expand the tips into the complete heart silhouette.
    local level = clamp(values[index] * 0.35 + rhythmPulse * 0.95, 0.0, 1.0)
    local topLength = math.max(0.0, baseline - shape.top) * level
    local bottomLength = math.max(0.0, shape.bottom - baseline) * level
    local liveHeight = math.max(2.0, topLength + bottomLength)
    table.insert(bars, ui.column({
      key = `heart-column-{index}`,
      width = BAR_WIDTH,
      height = HEART_HEIGHT,
      gap = 0,
      align = "stretch",
    }, {
      ui.box({
        key = `heart-offset-{index}`,
        width = BAR_WIDTH,
        height = math.max(0.0, baseline - topLength),
        fill = "#00000000",
      }),
      ui.box({
        key = `heart-live-{index}`,
        width = BAR_WIDTH,
        height = liveHeight,
        fill = color,
        radius = BAR_WIDTH / 2,
        softness = 10,
      }),
    }))
  end

  desktopWidget.render(ui.column({
    width = CANVAS_WIDTH,
    height = CANVAS_HEIGHT,
    align = "center",
    justify = "center",
    visible = visible,
  }, {
    ui.row({
      width = HEART_WIDTH,
      height = HEART_HEIGHT,
      gap = BAR_GAP,
      align = "start",
      justify = "center",
    }, bars),
  }))
end

local function receiveSpectrum(frame)
  if type(frame) ~= "string" then return end
  local payload, state = string.match(frame, "^([^|]+)|(.+)$")
  if payload == nil or state == nil then return end

  local received = {}
  for token in string.gmatch(payload, "[^,]+") do
    local number = tonumber(token)
    if number == nil then return end
    table.insert(received, clamp(number, 0.0, 1.0))
  end
  if #received ~= BAND_COUNT then return end

  local now = noctalia.nowMs()
  local deltaMs = 33
  if lastSpectrumAt > 0 then
    deltaMs = clamp(now - lastSpectrumAt, 1, 120)
  end
  lastSpectrumAt = now

  -- Broadband spectral flux treats every frequency equally.  Its adaptive
  -- threshold follows quiet and loud tracks alike and reacts to rhythmic
  -- changes from percussion, voices or melody instead of requiring bass.
  local flux = 0.0
  for index = 1, BAND_COUNT do
    flux += math.abs(received[index] - previousValues[index]) / BAND_COUNT
    previousValues[index] = received[index]
  end

  local threshold = fluxAverage + math.max(0.0035, fluxDeviation * 1.35)
  local active = string.sub(state, 1, 1) == "1"
  local onset = active and flux > threshold and now - lastOnsetAt >= 220

  fluxAverage = fluxAverage * 0.94 + flux * 0.06
  fluxDeviation = fluxDeviation * 0.94 + math.abs(flux - fluxAverage) * 0.06

  if onset then
    lastOnsetAt = now
    pulseHoldUntil = now + 70
    rhythmPulse = 1.0
  elseif active then
    if now <= pulseHoldUntil then
      rhythmPulse = 1.0
    else
      rhythmPulse *= math.exp(-deltaMs / 190.0)
    end
  else
    rhythmPulse = 0.0
  end

  values = received
  audioActive = active
  if audioActive and not activeFrameReported then
    activeFrameReported = true
    noctalia.log("Lesbian Heart Visualizer: active 40-band spectrum received")
  end
  if now - lastRenderAt < 30 then return end
  lastRenderAt = now
  render()
end

function update()
  noctalia.setUpdateInterval(1000)
  if not watchRegistered then
    watchRegistered = true
    noctalia.state.watch("heart-spectrum", receiveSpectrum)
    noctalia.log("Lesbian Heart Visualizer: shared spectrum listener registered")
    receiveSpectrum(noctalia.state.get("heart-spectrum"))
  end
  render()
end

buildEnvelope()
