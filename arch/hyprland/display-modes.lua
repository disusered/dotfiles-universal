-- Samsung work displays prefer 60 Hz even though they support 75 Hz.
-- Full EDID descriptions leave unrelated displays and the ultrawide untouched.
hl.monitor({
    output = "desc:Samsung Electric Company LS24D31x H9PXB00674",
    mode = "1920x1080@75", position = "auto", scale = 1,
})
hl.monitor({
    output = "desc:Samsung Electric Company LS24D31x H9PXB00679",
    mode = "1920x1080@75", position = "auto-right", scale = 1,
})
