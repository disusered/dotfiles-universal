-- Toggle full-screen recording (with monitor selection on multi-monitor)
hl.bind("SUPER + R", hl.dsp.exec_cmd("app2unit -- ~/.config/hypr/scripts/recorder.sh"))

-- Toggle region recording
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("app2unit -- ~/.config/hypr/scripts/recorder.sh --region"))
