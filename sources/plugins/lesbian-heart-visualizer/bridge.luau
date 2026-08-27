--!nonstrict

-- Noctalia exposes its native PipeWire spectrum to bar-widget entries.  This
-- invisible bridge keeps the native listener alive and forwards its frames to
-- the desktop-widget entry through the plugin's shared state.

local activeFrameReported = false

function update()
  noctalia.setUpdateInterval(1000)
  -- Reading the declared values also makes their fixed bridge contract visible
  -- to Noctalia's plugin linter; the host consumes them when it creates the
  -- native spectrum listener.
  local spectrumEnabled = noctalia.getConfig("audio_spectrum")
  local spectrumBands = noctalia.getConfig("audio_spectrum_bands")
  if spectrumEnabled ~= true or spectrumBands ~= 40 then
    noctalia.log("Lesbian Heart Visualizer: native spectrum bridge settings changed")
  end
  barWidget.setVisible(false)
end

function onAudioSpectrum(valuesCsv, stateCsv)
  if string.sub(stateCsv, 1, 1) == "1" and not activeFrameReported then
    activeFrameReported = true
    noctalia.log("Lesbian Heart Visualizer bridge: active native spectrum received")
  end
  noctalia.state.set("heart-spectrum", valuesCsv .. "|" .. stateCsv)
end
