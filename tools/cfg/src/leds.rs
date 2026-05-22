use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

use crate::color::Color;
use crate::config::{Config, LedDeviceConfig};
use crate::palette::Palette;

pub const LEDS_UPDATE_TARGET: &str = "leds";
const QMK_RAW_USAGE_PAGE: u32 = 0xff60;
const QMK_RAW_USAGE: u32 = 0x61;
const VIA_QMK_RGB_MATRIX_CHANNEL: u8 = 3;
const REPORT_LEN: usize = 32;
const HID_READ_TIMEOUT: Duration = Duration::from_millis(700);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct HsvColor {
    pub h: u8,
    pub s: u8,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RgbMatrixValue {
    Brightness,
    Effect,
    EffectSpeed,
    Color,
}

impl RgbMatrixValue {
    fn id(self) -> u8 {
        match self {
            RgbMatrixValue::Brightness => 1,
            RgbMatrixValue::Effect => 2,
            RgbMatrixValue::EffectSpeed => 3,
            RgbMatrixValue::Color => 4,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct LedEffect {
    pub id: u8,
    pub name: &'static str,
    pub aliases: &'static [&'static str],
}

pub const SUPPORTED_EFFECTS: &[LedEffect] = &[
    LedEffect {
        id: 0,
        name: "off",
        aliases: &["none"],
    },
    LedEffect {
        id: 1,
        name: "solid",
        aliases: &["solid_color"],
    },
    LedEffect {
        id: 2,
        name: "breathing",
        aliases: &[],
    },
    LedEffect {
        id: 3,
        name: "band_spiral_val",
        aliases: &[],
    },
    LedEffect {
        id: 4,
        name: "cycle_all",
        aliases: &[],
    },
    LedEffect {
        id: 5,
        name: "cycle_left_right",
        aliases: &[],
    },
    LedEffect {
        id: 6,
        name: "cycle_up_down",
        aliases: &[],
    },
    LedEffect {
        id: 7,
        name: "rainbow_moving_chevron",
        aliases: &[],
    },
    LedEffect {
        id: 8,
        name: "cycle_out_in",
        aliases: &[],
    },
    LedEffect {
        id: 9,
        name: "cycle_out_in_dual",
        aliases: &[],
    },
    LedEffect {
        id: 10,
        name: "cycle_pinwheel",
        aliases: &[],
    },
    LedEffect {
        id: 11,
        name: "cycle_spiral",
        aliases: &[],
    },
    LedEffect {
        id: 12,
        name: "dual_beacon",
        aliases: &[],
    },
    LedEffect {
        id: 13,
        name: "rainbow_beacon",
        aliases: &[],
    },
    LedEffect {
        id: 14,
        name: "jellybean_raindrops",
        aliases: &[],
    },
    LedEffect {
        id: 15,
        name: "pixel_rain",
        aliases: &[],
    },
    LedEffect {
        id: 16,
        name: "typing_heatmap",
        aliases: &[],
    },
    LedEffect {
        id: 17,
        name: "digital_rain",
        aliases: &[],
    },
    LedEffect {
        id: 18,
        name: "reactive_simple",
        aliases: &["solid_reactive_simple"],
    },
    LedEffect {
        id: 19,
        name: "reactive_multiwide",
        aliases: &["solid_reactive_multiwide"],
    },
    LedEffect {
        id: 20,
        name: "reactive_multinexus",
        aliases: &["solid_reactive_multinexus"],
    },
    LedEffect {
        id: 21,
        name: "splash",
        aliases: &[],
    },
    LedEffect {
        id: 22,
        name: "solid_splash",
        aliases: &[],
    },
];

pub struct ViaPacket;

impl ViaPacket {
    pub fn protocol_query() -> [u8; REPORT_LEN] {
        let mut packet = [0; REPORT_LEN];
        packet[0] = 0x01;
        packet
    }

    pub fn rgb_matrix_get(value: RgbMatrixValue) -> [u8; REPORT_LEN] {
        let mut packet = [0; REPORT_LEN];
        packet[0] = 0x08;
        packet[1] = VIA_QMK_RGB_MATRIX_CHANNEL;
        packet[2] = value.id();
        packet
    }

    pub fn rgb_matrix_set(value: RgbMatrixValue, data: &[u8]) -> [u8; REPORT_LEN] {
        let mut packet = [0; REPORT_LEN];
        packet[0] = 0x07;
        packet[1] = VIA_QMK_RGB_MATRIX_CHANNEL;
        packet[2] = value.id();
        for (i, byte) in data.iter().copied().take(REPORT_LEN - 3).enumerate() {
            packet[i + 3] = byte;
        }
        packet
    }

    pub fn rgb_matrix_save() -> [u8; REPORT_LEN] {
        let mut packet = [0; REPORT_LEN];
        packet[0] = 0x09;
        packet[1] = VIA_QMK_RGB_MATRIX_CHANNEL;
        packet
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LedStatus {
    pub target: String,
    pub device: PathBuf,
    pub protocol_version: u16,
    pub brightness: u8,
    pub effect: u8,
    pub speed: u8,
    pub color: HsvColor,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct LedValues {
    pub brightness: u8,
    pub effect: u8,
    pub speed: u8,
    pub color: HsvColor,
}

#[derive(Debug, Default, PartialEq, Eq)]
pub struct SetOptions {
    pub color: Option<String>,
    pub brightness: Option<u8>,
    pub effect: Option<u8>,
    pub speed: Option<u8>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DiscoveredDevice {
    pub name: String,
    pub path: PathBuf,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LedTargetStatus {
    pub name: String,
    pub devices: Vec<DiscoveredDevice>,
}

pub fn is_qmk_raw_hid_descriptor(descriptor: &[u8]) -> bool {
    let mut i = 0;
    let mut usage_page = None;

    while i < descriptor.len() {
        let prefix = descriptor[i];
        i += 1;

        if prefix == 0xfe {
            if i + 2 > descriptor.len() {
                break;
            }
            let size = descriptor[i] as usize;
            i += 2 + size;
            continue;
        }

        let size = match prefix & 0x03 {
            0 => 0,
            1 => 1,
            2 => 2,
            _ => 4,
        };
        if i + size > descriptor.len() {
            break;
        }

        let value = descriptor[i..i + size]
            .iter()
            .enumerate()
            .fold(0u32, |acc, (shift, byte)| {
                acc | ((*byte as u32) << (shift * 8))
            });

        let item_type = (prefix >> 2) & 0x03;
        let tag = (prefix >> 4) & 0x0f;

        if item_type == 1 && tag == 0 {
            usage_page = Some(value);
        }
        if item_type == 2
            && tag == 0
            && usage_page == Some(QMK_RAW_USAGE_PAGE)
            && value == QMK_RAW_USAGE
        {
            return true;
        }

        i += size;
    }

    false
}

pub fn parse_protocol_version(response: &[u8]) -> Result<u16, String> {
    require_response(response, 0x01)?;
    Ok(((response[1] as u16) << 8) | response[2] as u16)
}

pub fn parse_rgb_matrix_u8(response: &[u8], value: RgbMatrixValue) -> Result<u8, String> {
    require_rgb_matrix_response(response, value)?;
    Ok(response[3])
}

pub fn parse_rgb_matrix_color(response: &[u8]) -> Result<HsvColor, String> {
    require_rgb_matrix_response(response, RgbMatrixValue::Color)?;
    Ok(HsvColor {
        h: response[3],
        s: response[4],
    })
}

pub fn rgb_to_hsv(color: Color) -> HsvColor {
    let r = color.r as f32 / 255.0;
    let g = color.g as f32 / 255.0;
    let b = color.b as f32 / 255.0;
    let max = r.max(g).max(b);
    let min = r.min(g).min(b);
    let delta = max - min;

    let hue_degrees = if delta == 0.0 {
        0.0
    } else if max == r {
        60.0 * ((g - b) / delta).rem_euclid(6.0)
    } else if max == g {
        60.0 * (((b - r) / delta) + 2.0)
    } else {
        60.0 * (((r - g) / delta) + 4.0)
    };

    let saturation = if max == 0.0 {
        0
    } else {
        ((delta / max) * 255.0).round() as u8
    };

    HsvColor {
        h: ((hue_degrees * 255.0) / 360.0).round() as u8,
        s: saturation,
    }
}

pub fn parse_set_options(values: &[String]) -> Result<SetOptions, String> {
    let mut options = SetOptions::default();

    for value in values {
        let Some((key, raw_value)) = value.split_once('=') else {
            return Err(format!("Invalid leds setting '{}'. Use key=value", value));
        };

        match key {
            "color" => {
                if options.color.replace(raw_value.to_string()).is_some() {
                    return Err("Duplicate leds setting: color".to_string());
                }
            }
            "brightness" => {
                set_unique_u8(&mut options.brightness, key, raw_value)?;
            }
            "effect" => {
                let effect = resolve_effect(raw_value)?;
                if options.effect.replace(effect).is_some() {
                    return Err("Duplicate leds setting: effect".to_string());
                }
            }
            "speed" => {
                set_unique_u8(&mut options.speed, key, raw_value)?;
            }
            _ => return Err(format!("Unknown leds setting '{}'", key)),
        }
    }

    Ok(options)
}

pub fn read_status(
    config: &Config,
    target: Option<&str>,
    device: Option<&Path>,
) -> Result<Vec<LedStatus>, String> {
    let devices = resolve_devices(config, target, device)?;
    let mut statuses = Vec::new();

    for device in devices {
        let mut hid = HidConnection::open(&device.path)?;
        statuses.push(read_status_from_connection(
            &device.name,
            &device.path,
            &mut hid,
        )?);
    }

    Ok(statuses)
}

pub fn theme_values(config: &Config, palette: &Palette) -> Result<LedValues, String> {
    Ok(LedValues {
        brightness: config.leds.brightness,
        effect: resolve_effect(&config.leds.effect)?,
        speed: config.leds.speed,
        color: resolve_color(&config.primary, palette)?,
    })
}

pub fn apply_theme(
    config: &Config,
    palette: &Palette,
    save: bool,
    target: Option<&str>,
    device: Option<&Path>,
) -> Result<Vec<LedStatus>, String> {
    let values = theme_values(config, palette)?;
    apply_values(config, &values, save, target, device)
}

pub fn apply_values(
    config: &Config,
    values: &LedValues,
    save: bool,
    target: Option<&str>,
    device: Option<&Path>,
) -> Result<Vec<LedStatus>, String> {
    let devices = resolve_devices(config, target, device)?;
    let mut statuses = Vec::new();

    for device in devices {
        let mut hid = HidConnection::open(&device.path)?;
        let _current = read_status_from_connection(&device.name, &device.path, &mut hid)?;
        send_values(&mut hid, values)?;
        if save {
            send_save(&mut hid)?;
        }

        statuses.push(read_status_from_connection(
            &device.name,
            &device.path,
            &mut hid,
        )?);
    }

    Ok(statuses)
}

pub fn restore_statuses(statuses: &[LedStatus], save: bool) -> Result<Vec<LedStatus>, String> {
    let mut restored = Vec::new();

    for status in statuses {
        let mut hid = HidConnection::open(&status.device)?;
        let values = LedValues {
            brightness: status.brightness,
            effect: status.effect,
            speed: status.speed,
            color: status.color,
        };
        send_values(&mut hid, &values)?;
        if save {
            send_save(&mut hid)?;
        }
        restored.push(read_status_from_connection(
            &status.target,
            &status.device,
            &mut hid,
        )?);
    }

    Ok(restored)
}

pub fn apply_set_options(
    options: &SetOptions,
    config: &Config,
    palette: &Palette,
    save: bool,
    target: Option<&str>,
    device: Option<&Path>,
) -> Result<Vec<LedStatus>, String> {
    let devices = resolve_devices(config, target, device)?;
    let color = options
        .color
        .as_deref()
        .map(|color| resolve_named_or_hex_color(color, config, palette))
        .transpose()?;
    let mut statuses = Vec::new();

    for device in devices {
        let mut hid = HidConnection::open(&device.path)?;

        if let Some(brightness) = options.brightness {
            send_set(&mut hid, RgbMatrixValue::Brightness, &[brightness])?;
        }
        if let Some(effect) = options.effect {
            send_set(&mut hid, RgbMatrixValue::Effect, &[effect])?;
        }
        if let Some(speed) = options.speed {
            send_set(&mut hid, RgbMatrixValue::EffectSpeed, &[speed])?;
        }
        if let Some(hsv) = color {
            send_set(&mut hid, RgbMatrixValue::Color, &[hsv.h, hsv.s])?;
        }
        if save {
            send_save(&mut hid)?;
        }

        statuses.push(read_status_from_connection(
            &device.name,
            &device.path,
            &mut hid,
        )?);
    }

    Ok(statuses)
}

fn send_values(hid: &mut HidConnection, values: &LedValues) -> Result<(), String> {
    send_set(hid, RgbMatrixValue::Brightness, &[values.brightness])?;
    send_set(hid, RgbMatrixValue::Effect, &[values.effect])?;
    send_set(hid, RgbMatrixValue::EffectSpeed, &[values.speed])?;
    send_set(
        hid,
        RgbMatrixValue::Color,
        &[values.color.h, values.color.s],
    )
}

fn read_status_from_connection(
    target: &str,
    path: &Path,
    hid: &mut HidConnection,
) -> Result<LedStatus, String> {
    let protocol_version = parse_protocol_version(&hid.send(ViaPacket::protocol_query())?)?;
    let brightness = parse_rgb_matrix_u8(
        &hid.send(ViaPacket::rgb_matrix_get(RgbMatrixValue::Brightness))?,
        RgbMatrixValue::Brightness,
    )?;
    let effect = parse_rgb_matrix_u8(
        &hid.send(ViaPacket::rgb_matrix_get(RgbMatrixValue::Effect))?,
        RgbMatrixValue::Effect,
    )?;
    let speed = parse_rgb_matrix_u8(
        &hid.send(ViaPacket::rgb_matrix_get(RgbMatrixValue::EffectSpeed))?,
        RgbMatrixValue::EffectSpeed,
    )?;
    let color =
        parse_rgb_matrix_color(&hid.send(ViaPacket::rgb_matrix_get(RgbMatrixValue::Color))?)?;

    Ok(LedStatus {
        target: target.to_string(),
        device: path.to_path_buf(),
        protocol_version,
        brightness,
        effect,
        speed,
        color,
    })
}

fn send_set(hid: &mut HidConnection, value: RgbMatrixValue, data: &[u8]) -> Result<(), String> {
    let response = hid.send(ViaPacket::rgb_matrix_set(value, data))?;
    require_response(&response, 0x07)
}

fn send_save(hid: &mut HidConnection) -> Result<(), String> {
    let response = hid.send(ViaPacket::rgb_matrix_save())?;
    require_response(&response, 0x09)
}

fn resolve_color(name: &str, palette: &Palette) -> Result<HsvColor, String> {
    let color = palette
        .get(name)
        .copied()
        .ok_or_else(|| format!("palette color '{}' not found", name))?;
    Ok(rgb_to_hsv(color))
}

fn resolve_named_or_hex_color(
    value: &str,
    config: &Config,
    palette: &Palette,
) -> Result<HsvColor, String> {
    let name = match value {
        "primary" => config.primary.as_str(),
        "secondary" => config.secondary.as_str(),
        _ => value,
    };

    if let Some(color) = palette.get(name).copied() {
        return Ok(rgb_to_hsv(color));
    }

    Color::from_hex(value).map(rgb_to_hsv).map_err(|_| {
        format!(
            "Unknown color '{}'. Use a palette color name or rrggbb hex",
            value
        )
    })
}

fn resolve_devices(
    config: &Config,
    target: Option<&str>,
    device: Option<&Path>,
) -> Result<Vec<DiscoveredDevice>, String> {
    if let Some(path) = device {
        return Ok(vec![DiscoveredDevice {
            name: target.unwrap_or("device").to_string(),
            path: path.to_path_buf(),
        }]);
    }

    discover_devices(&config.leds.devices, target)
}

pub fn discover_target_statuses(
    config: &Config,
    target: Option<&str>,
    device: Option<&Path>,
) -> Result<Vec<LedTargetStatus>, String> {
    if let Some(path) = device {
        let name = target.unwrap_or("device").to_string();
        return Ok(vec![LedTargetStatus {
            name: name.clone(),
            devices: vec![DiscoveredDevice {
                name,
                path: path.to_path_buf(),
            }],
        }]);
    }

    discover_target_statuses_in(Path::new("/sys/class/hidraw"), &config.leds.devices, target)
}

fn discover_devices(
    targets: &[LedDeviceConfig],
    target: Option<&str>,
) -> Result<Vec<DiscoveredDevice>, String> {
    discover_devices_in(Path::new("/sys/class/hidraw"), targets, target)
}

pub fn discover_devices_in(
    hidraw_dir: &Path,
    targets: &[LedDeviceConfig],
    target: Option<&str>,
) -> Result<Vec<DiscoveredDevice>, String> {
    Ok(discover_target_statuses_in(hidraw_dir, targets, target)?
        .into_iter()
        .flat_map(|status| status.devices)
        .collect())
}

pub fn discover_target_statuses_in(
    hidraw_dir: &Path,
    targets: &[LedDeviceConfig],
    target: Option<&str>,
) -> Result<Vec<LedTargetStatus>, String> {
    let selected_targets = selected_targets(targets, target)?;
    let mut statuses = selected_targets
        .iter()
        .map(|target| LedTargetStatus {
            name: target.name.clone(),
            devices: Vec::new(),
        })
        .collect::<Vec<_>>();
    let mut entries = fs::read_dir(hidraw_dir)
        .map_err(|e| format!("Failed to read {}: {}", hidraw_dir.display(), e))?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| format!("Failed to read hidraw entry: {}", e))?;
    entries.sort_by_key(|entry| entry.file_name());

    for entry in entries {
        let sysfs_path = entry.path();
        let uevent_path = sysfs_path.join("device/uevent");
        let descriptor_path = sysfs_path.join("device/report_descriptor");
        let Ok(uevent) = fs::read_to_string(&uevent_path) else {
            continue;
        };
        let Some((vendor_id, product_id)) = parse_hid_ids(&uevent) else {
            continue;
        };

        let Ok(descriptor) = fs::read(&descriptor_path) else {
            continue;
        };
        if !is_qmk_raw_hid_descriptor(&descriptor) {
            continue;
        }

        for (target_index, selected_target) in selected_targets.iter().enumerate() {
            if vendor_id == selected_target.vendor_id && product_id == selected_target.product_id {
                statuses[target_index].devices.push(DiscoveredDevice {
                    name: selected_target.name.clone(),
                    path: PathBuf::from("/dev").join(entry.file_name()),
                });
            }
        }
    }

    if let Some(target) = target {
        if statuses.iter().all(|status| status.devices.is_empty()) {
            return Err(format!("No configured LED target '{}' found", target));
        }
    }

    Ok(statuses)
}

pub fn format_target_summary(statuses: &[LedTargetStatus]) -> Vec<String> {
    vec![
        format!(
            "connected_targets={}",
            join_target_names(statuses.iter().filter(|status| !status.devices.is_empty()))
        ),
        format!(
            "missing_targets={}",
            join_target_names(statuses.iter().filter(|status| status.devices.is_empty()))
        ),
    ]
}

pub fn format_target_summary_line(statuses: &[LedTargetStatus]) -> String {
    format!(
        "connected: {}  missing: {}",
        join_target_names(statuses.iter().filter(|status| !status.devices.is_empty())),
        join_target_names(statuses.iter().filter(|status| status.devices.is_empty()))
    )
}

fn join_target_names<'a>(statuses: impl Iterator<Item = &'a LedTargetStatus>) -> String {
    let names = statuses
        .map(|status| status.name.as_str())
        .collect::<Vec<_>>();
    if names.is_empty() {
        "none".to_string()
    } else {
        names.join(",")
    }
}

fn selected_targets<'a>(
    targets: &'a [LedDeviceConfig],
    target: Option<&str>,
) -> Result<Vec<&'a LedDeviceConfig>, String> {
    match target {
        Some(name) => targets
            .iter()
            .find(|target| target.name == name)
            .map(|target| vec![target])
            .ok_or_else(|| format!("Unknown LED target '{}'", name)),
        None => Ok(targets.iter().collect()),
    }
}

fn parse_hid_ids(uevent: &str) -> Option<(u16, u16)> {
    let line = uevent.lines().find(|line| line.starts_with("HID_ID="))?;
    let mut parts = line.trim_start_matches("HID_ID=").split(':');
    let _bus = parts.next()?;
    let vendor = u16::from_str_radix(parts.next()?, 16).ok()?;
    let product = u16::from_str_radix(parts.next()?, 16).ok()?;
    Some((vendor, product))
}

struct HidConnection {
    file: File,
}

impl HidConnection {
    fn open(path: &Path) -> Result<Self, String> {
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .custom_flags(libc::O_NONBLOCK)
            .open(path)
            .map_err(|e| format!("Failed to open {}: {}", path.display(), e))?;

        Ok(HidConnection { file })
    }

    fn send(&mut self, packet: [u8; REPORT_LEN]) -> Result<[u8; REPORT_LEN], String> {
        self.file
            .write_all(&packet)
            .map_err(|e| format!("Failed to write hidraw report: {}", e))?;

        let start = Instant::now();
        let mut response = [0; REPORT_LEN];
        loop {
            match self.file.read(&mut response) {
                Ok(REPORT_LEN) => return Ok(response),
                Ok(0) => {}
                Ok(n) => {
                    return Err(format!("Short hidraw response: {} bytes", n));
                }
                Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {}
                Err(e) => return Err(format!("Failed to read hidraw response: {}", e)),
            }

            if start.elapsed() >= HID_READ_TIMEOUT {
                return Err(format!(
                    "Timed out after {}ms waiting for VIA response",
                    HID_READ_TIMEOUT.as_millis()
                ));
            }
            std::thread::sleep(Duration::from_millis(10));
        }
    }
}

fn require_rgb_matrix_response(response: &[u8], value: RgbMatrixValue) -> Result<(), String> {
    require_response(response, 0x08)?;
    if response.get(1) != Some(&VIA_QMK_RGB_MATRIX_CHANNEL) || response.get(2) != Some(&value.id())
    {
        return Err(format!(
            "Unexpected VIA RGB matrix response: {}",
            hex_response(response)
        ));
    }
    Ok(())
}

fn require_response(response: &[u8], command: u8) -> Result<(), String> {
    if response.len() < REPORT_LEN {
        return Err(format!("Short VIA response: {} bytes", response.len()));
    }
    if response[0] == 0xff {
        return Err(format!(
            "VIA command was unhandled: {}",
            hex_response(response)
        ));
    }
    if response[0] != command {
        return Err(format!(
            "Unexpected VIA response: {}",
            hex_response(response)
        ));
    }
    Ok(())
}

pub fn resolve_effect(value: &str) -> Result<u8, String> {
    if let Ok(effect) = value.parse::<u8>() {
        return Ok(effect);
    }

    find_effect(value).map(|effect| effect.id).ok_or_else(|| {
        format!(
            "Unknown leds effect '{}'. Use a supported effect name or 0-255",
            value
        )
    })
}

#[cfg(test)]
pub fn supported_effect_names() -> Vec<&'static str> {
    SUPPORTED_EFFECTS.iter().map(|effect| effect.name).collect()
}

pub fn formatted_effects() -> Vec<String> {
    SUPPORTED_EFFECTS
        .iter()
        .map(|effect| {
            if effect.aliases.is_empty() {
                format!("{:<2} {}", effect.id, effect.name)
            } else {
                format!(
                    "{:<2} {} (aliases: {})",
                    effect.id,
                    effect.name,
                    effect.aliases.join(", ")
                )
            }
        })
        .collect()
}

fn find_effect(value: &str) -> Option<&'static LedEffect> {
    let normalized = normalize_effect_name(value);
    SUPPORTED_EFFECTS.iter().find(|effect| {
        normalize_effect_name(effect.name) == normalized
            || effect
                .aliases
                .iter()
                .any(|alias| normalize_effect_name(alias) == normalized)
    })
}

fn normalize_effect_name(value: &str) -> String {
    value
        .to_ascii_lowercase()
        .replace('-', "_")
        .replace(' ', "_")
}

fn parse_u8(key: &str, value: &str) -> Result<u8, String> {
    value
        .parse::<u8>()
        .map_err(|_| format!("Invalid leds {} '{}'. Expected 0-255", key, value))
}

fn set_unique_u8(slot: &mut Option<u8>, key: &str, value: &str) -> Result<(), String> {
    if slot.replace(parse_u8(key, value)?).is_some() {
        return Err(format!("Duplicate leds setting: {}", key));
    }
    Ok(())
}

fn hex_response(response: &[u8]) -> String {
    response
        .iter()
        .map(|byte| format!("{:02x}", byte))
        .collect::<String>()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::LedDeviceConfig;

    #[test]
    fn descriptor_match_finds_qmk_raw_hid_usage() {
        let descriptor =
            hex_bytes("0660ff0961a1010962150026ff009520750881020963150026ff00952075089102c0");

        assert!(is_qmk_raw_hid_descriptor(&descriptor));
    }

    #[test]
    fn descriptor_match_rejects_plain_keyboard_descriptor() {
        let descriptor = hex_bytes(
            "05010906a101050719e029e7150025019508750181029501750881010507190029ff150026ff00950675088100c0",
        );

        assert!(!is_qmk_raw_hid_descriptor(&descriptor));
    }

    #[test]
    fn protocol_query_packet_is_32_bytes() {
        let packet = ViaPacket::protocol_query();

        assert_eq!(packet.len(), 32);
        assert_eq!(packet[0], 0x01);
        assert!(packet[1..].iter().all(|b| *b == 0));
    }

    #[test]
    fn rgb_matrix_set_color_packet_uses_via_channel_three() {
        let packet = ViaPacket::rgb_matrix_set(RgbMatrixValue::Color, &[0x4c, 0xdb]);

        assert_eq!(&packet[..5], &[0x07, 0x03, 0x04, 0x4c, 0xdb]);
        assert!(packet[5..].iter().all(|b| *b == 0));
    }

    #[test]
    fn rgb_matrix_save_packet_targets_via_rgb_matrix_channel() {
        let packet = ViaPacket::rgb_matrix_save();

        assert_eq!(&packet[..3], &[0x09, 0x03, 0x00]);
        assert!(packet[3..].iter().all(|b| *b == 0));
    }

    #[test]
    fn parses_protocol_response() {
        let response =
            hex_bytes("01000b0000000000000000000000000000000000000000000000000000000000");

        assert_eq!(parse_protocol_version(&response).unwrap(), 0x000b);
    }

    #[test]
    fn parses_rgb_matrix_state_responses() {
        let brightness =
            hex_bytes("080301df00000000000000000000000000000000000000000000000000000000");
        let effect = hex_bytes("0803021300000000000000000000000000000000000000000000000000000000");
        let speed = hex_bytes("080303af00000000000000000000000000000000000000000000000000000000");
        let color = hex_bytes("0803044cdb000000000000000000000000000000000000000000000000000000");

        assert_eq!(
            parse_rgb_matrix_u8(&brightness, RgbMatrixValue::Brightness).unwrap(),
            0xdf
        );
        assert_eq!(
            parse_rgb_matrix_u8(&effect, RgbMatrixValue::Effect).unwrap(),
            0x13
        );
        assert_eq!(
            parse_rgb_matrix_u8(&speed, RgbMatrixValue::EffectSpeed).unwrap(),
            0xaf
        );
        assert_eq!(
            parse_rgb_matrix_color(&color).unwrap(),
            HsvColor { h: 0x4c, s: 0xdb }
        );
    }

    #[test]
    fn rgb_to_hsv_maps_primary_colors_to_qmk_hue_scale() {
        assert_eq!(
            rgb_to_hsv(Color { r: 255, g: 0, b: 0 }),
            HsvColor { h: 0, s: 255 }
        );
        assert_eq!(
            rgb_to_hsv(Color { r: 0, g: 255, b: 0 }),
            HsvColor { h: 85, s: 255 }
        );
        assert_eq!(
            rgb_to_hsv(Color { r: 0, g: 0, b: 255 }),
            HsvColor { h: 170, s: 255 }
        );
    }

    #[test]
    fn set_options_accept_palette_color_and_numbers() {
        let options = parse_set_options(&[
            "color=sapphire".to_string(),
            "effect=solid".to_string(),
            "brightness=223".to_string(),
            "speed=175".to_string(),
        ])
        .unwrap();

        assert_eq!(options.color.as_deref(), Some("sapphire"));
        assert_eq!(options.effect, Some(1));
        assert_eq!(options.brightness, Some(223));
        assert_eq!(options.speed, Some(175));
    }

    #[test]
    fn set_options_reject_unknown_keys() {
        let err = parse_set_options(&["banana=1".to_string()]).unwrap_err();

        assert!(err.contains("Unknown leds setting"));
    }

    #[test]
    fn effect_names_include_reactive_multiwide_for_keychron_v1() {
        assert_eq!(resolve_effect("solid").unwrap(), 1);
        assert_eq!(resolve_effect("reactive_multiwide").unwrap(), 19);
        assert_eq!(resolve_effect("reactive multiwide").unwrap(), 19);
        assert_eq!(resolve_effect("19").unwrap(), 19);

        let err = resolve_effect("bootloader").unwrap_err();
        assert!(err.contains("Unknown leds effect"));
    }

    #[test]
    fn supported_effects_expose_canonical_names_for_ui_and_help() {
        let names = supported_effect_names();

        assert!(names.contains(&"solid"));
        assert!(names.contains(&"reactive_multiwide"));
        assert!(names.contains(&"solid_splash"));
    }

    #[test]
    fn formatted_effects_include_ids_names_and_aliases() {
        let effects = formatted_effects().join("\n");

        assert!(effects.contains("1  solid"));
        assert!(effects.contains("19 reactive_multiwide"));
        assert!(effects.contains("aliases: solid_reactive_multiwide"));
    }

    #[test]
    fn discovery_matches_configured_raw_hid_targets() {
        let root = make_hidraw_tree("discovery-matches");
        write_hidraw(
            &root,
            "hidraw3",
            "0003:00003434:00000311",
            "Keychron Keychron V1",
            "0660ff0961a1010962150026ff009520750881020963150026ff00952075089102c0",
        );
        write_hidraw(
            &root,
            "hidraw4",
            "0003:00003434:00000311",
            "Keychron Keychron V1",
            "05010906a101050719e029e7150025019508750181029501750881010507190029ff150026ff00950675088100c0",
        );

        let discovered = discover_devices_in(
            &root,
            &[LedDeviceConfig {
                name: "keychron-v1".to_string(),
                vendor_id: 0x3434,
                product_id: 0x0311,
            }],
            None,
        )
        .unwrap();

        assert_eq!(discovered.len(), 1);
        assert_eq!(discovered[0].name, "keychron-v1");
        assert_eq!(discovered[0].path, PathBuf::from("/dev/hidraw3"));
    }

    #[test]
    fn discovery_matches_configured_keychron_q11_raw_hid_target() {
        let root = make_hidraw_tree("discovery-q11");
        write_hidraw(
            &root,
            "hidraw3",
            "0003:00003434:000001E0",
            "Keychron Keychron Q11",
            "0660ff0961a1010962150026ff009520750881020963150026ff00952075089102c0",
        );

        let discovered = discover_devices_in(
            &root,
            &[LedDeviceConfig {
                name: "keychron-q11".to_string(),
                vendor_id: 0x3434,
                product_id: 0x01e0,
            }],
            None,
        )
        .unwrap();

        assert_eq!(discovered.len(), 1);
        assert_eq!(discovered[0].name, "keychron-q11");
        assert_eq!(discovered[0].path, PathBuf::from("/dev/hidraw3"));
    }

    #[test]
    fn target_statuses_include_connected_and_missing_default_targets() {
        let root = make_hidraw_tree("target-statuses");
        write_hidraw(
            &root,
            "hidraw3",
            "0003:00003434:000001E0",
            "Keychron Keychron Q11",
            "0660ff0961a1010962150026ff009520750881020963150026ff00952075089102c0",
        );
        let targets = [
            LedDeviceConfig {
                name: "keychron-v1".to_string(),
                vendor_id: 0x3434,
                product_id: 0x0311,
            },
            LedDeviceConfig {
                name: "keychron-q11".to_string(),
                vendor_id: 0x3434,
                product_id: 0x01e0,
            },
        ];

        let statuses = discover_target_statuses_in(&root, &targets, None).unwrap();

        assert_eq!(statuses.len(), 2);
        assert_eq!(statuses[0].name, "keychron-v1");
        assert!(statuses[0].devices.is_empty());
        assert_eq!(statuses[1].name, "keychron-q11");
        assert_eq!(statuses[1].devices.len(), 1);
        assert_eq!(statuses[1].devices[0].path, PathBuf::from("/dev/hidraw3"));
    }

    #[test]
    fn target_summary_formats_connected_and_missing_names() {
        let statuses = [
            LedTargetStatus {
                name: "keychron-v1".to_string(),
                devices: Vec::new(),
            },
            LedTargetStatus {
                name: "keychron-q11".to_string(),
                devices: vec![DiscoveredDevice {
                    name: "keychron-q11".to_string(),
                    path: PathBuf::from("/dev/hidraw3"),
                }],
            },
        ];

        assert_eq!(
            format_target_summary(&statuses),
            vec![
                "connected_targets=keychron-q11".to_string(),
                "missing_targets=keychron-v1".to_string(),
            ]
        );
        assert_eq!(
            format_target_summary_line(&statuses),
            "connected: keychron-q11  missing: keychron-v1"
        );
    }

    #[test]
    fn discovery_skips_missing_default_targets_but_errors_on_explicit_target() {
        let root = make_hidraw_tree("discovery-missing");
        let targets = [LedDeviceConfig {
            name: "keychron-v1".to_string(),
            vendor_id: 0x3434,
            product_id: 0x0311,
        }];

        assert!(discover_devices_in(&root, &targets, None)
            .unwrap()
            .is_empty());

        let err = discover_devices_in(&root, &targets, Some("keychron-v1")).unwrap_err();
        assert!(err.contains("No configured LED target 'keychron-v1'"));
    }

    fn make_hidraw_tree(name: &str) -> PathBuf {
        let root = std::env::temp_dir().join(format!("cfg-leds-test-{}", name));
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&root).unwrap();
        root
    }

    fn write_hidraw(root: &Path, name: &str, hid_id: &str, hid_name: &str, descriptor_hex: &str) {
        let device = root.join(name).join("device");
        fs::create_dir_all(&device).unwrap();
        fs::write(
            device.join("uevent"),
            format!("HID_ID={}\nHID_NAME={}\n", hid_id, hid_name),
        )
        .unwrap();
        fs::write(device.join("report_descriptor"), hex_bytes(descriptor_hex)).unwrap();
    }

    fn hex_bytes(hex: &str) -> Vec<u8> {
        hex.as_bytes()
            .chunks(2)
            .map(|pair| {
                let s = std::str::from_utf8(pair).unwrap();
                u8::from_str_radix(s, 16).unwrap()
            })
            .collect()
    }
}
