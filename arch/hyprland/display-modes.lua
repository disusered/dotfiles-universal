-- Use the Samsung work displays' supported 75 Hz mode.
-- Full EDID descriptions keep modes independent of connector numbering.
hl.monitor({
    output = "desc:Samsung Electric Company LS24D31x H9PXB00674",
    mode = "1920x1080@75", position = "auto", scale = 1,
})
hl.monitor({
    output = "desc:Samsung Electric Company LS24D31x H9PXB00679",
    mode = "1920x1080@75", position = "auto-right", scale = 1,
})

-- The Dell moves between DisplayPort connectors.
hl.monitor({
    output = "desc:Dell Inc. DELL S3422DWG G1C4KK3",
    mode = "3440x1440@143.97", position = "0x0", scale = 1,
})
