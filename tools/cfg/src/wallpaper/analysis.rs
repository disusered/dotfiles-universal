use serde::{Deserialize, Serialize};
use std::process::Command;

use crate::color::Color;

/// Maximum number of dominant colors returned per image.
const TOP_N: usize = 5;

/// HSL saturation cutoff. Anything below this is treated as a grey and
/// dropped — greys carry no accent information and tend to dominate
/// histograms of real photographs.
const GREY_SATURATION_THRESHOLD: f32 = 0.20;

/// A single dominant color entry produced by [`analyze`].
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DominantColor {
    pub color: Color,
    /// Proportion of sampled pixels this color accounts for *after* the
    /// grey filter, in `0.0..=1.0`.
    pub weight: f32,
}

/// Analyze an image at `path` and return its top dominant colors.
///
/// Pipeline: shell out to `magick` to produce a small histogram, parse the
/// output, filter out near-grey colors (HSL saturation < 0.20), re-normalize
/// weights, and return the top [`TOP_N`] entries sorted descending by weight.
///
/// Returns an empty `Vec` (not an error) if the grey filter removes every
/// color — the caller decides what fallback, if any, makes sense.
pub fn analyze(path: &str) -> Result<Vec<DominantColor>, String> {
    let output = Command::new("magick")
        .args([
            path,
            "-resize",
            "100x100",
            "-colors",
            "8",
            "-format",
            "%c",
            "histogram:info:",
        ])
        .output()
        .map_err(|e| {
            if e.kind() == std::io::ErrorKind::NotFound {
                "magick binary not found — install imagemagick".to_string()
            } else {
                format!("Failed to run magick: {}", e)
            }
        })?;

    if !output.status.success() {
        return Err(format!(
            "magick exited with status {}: {}",
            output.status,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    if stdout.trim().is_empty() {
        return Err("no histogram output from magick".to_string());
    }

    Ok(select_dominants(&parse_histogram(&stdout)))
}

/// Parse `magick ... histogram:info:` stdout into `(color, count)` pairs.
///
/// Each histogram line looks like:
/// ```text
///      1234: (255,  0,  0) #FF0000 srgb(255,0,0)
/// ```
/// Lines we can't make sense of (no colon, no hex token, malformed count)
/// are skipped silently so stray status lines from `magick` don't break
/// analysis.
fn parse_histogram(stdout: &str) -> Vec<(Color, u32)> {
    let mut out = Vec::new();
    for line in stdout.lines() {
        let trimmed = line.trim_start();
        let colon = match trimmed.find(':') {
            Some(i) => i,
            None => continue,
        };
        let count: u32 = match trimmed[..colon].trim().parse() {
            Ok(n) => n,
            Err(_) => continue,
        };
        let hex_token = trimmed
            .split_whitespace()
            .find(|t| t.starts_with('#') && t.len() >= 7);
        let hex = match hex_token {
            Some(t) => &t[..7],
            None => continue,
        };
        let color = match Color::from_hex(hex) {
            Ok(c) => c,
            Err(_) => continue,
        };
        out.push((color, count));
    }
    out
}

/// Apply the grey filter, normalize weights, sort descending, truncate to
/// `TOP_N`.
fn select_dominants(entries: &[(Color, u32)]) -> Vec<DominantColor> {
    let filtered: Vec<(Color, u32)> = entries
        .iter()
        .copied()
        .filter(|(c, _)| rgb_saturation(c.r, c.g, c.b) >= GREY_SATURATION_THRESHOLD)
        .collect();

    let total: u32 = filtered.iter().map(|(_, c)| *c).sum();
    if total == 0 {
        return Vec::new();
    }

    let mut dominants: Vec<DominantColor> = filtered
        .into_iter()
        .map(|(color, count)| DominantColor {
            color,
            weight: count as f32 / total as f32,
        })
        .collect();

    dominants.sort_by(|a, b| {
        b.weight
            .partial_cmp(&a.weight)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    dominants.truncate(TOP_N);
    dominants
}

/// HSL saturation for a given RGB triple, as a ratio in `0.0..=1.0`.
///
/// Pure greys (R=G=B) have saturation 0; pure primaries have saturation 1.
fn rgb_saturation(r: u8, g: u8, b: u8) -> f32 {
    let rf = r as f32 / 255.0;
    let gf = g as f32 / 255.0;
    let bf = b as f32 / 255.0;
    let max = rf.max(gf).max(bf);
    let min = rf.min(gf).min(bf);
    let delta = max - min;
    if delta == 0.0 {
        return 0.0;
    }
    let lightness = (max + min) / 2.0;
    if lightness > 0.5 {
        delta / (2.0 - max - min)
    } else {
        delta / (max + min)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_sample_histogram_line() {
        let sample = "     42: (255,  0,  0) #FF0000 srgb(255,0,0)\n\
                      13: (128,128,128) #808080 srgb(128,128,128)\n";
        let out = parse_histogram(sample);
        assert_eq!(out.len(), 2);
        assert_eq!(out[0].0.to_hex_lower(), "ff0000");
        assert_eq!(out[0].1, 42);
        assert_eq!(out[1].0.to_hex_lower(), "808080");
        assert_eq!(out[1].1, 13);
    }

    #[test]
    fn parse_histogram_skips_unparseable_lines() {
        let sample = "garbage line without colon\n\
                      10: missing hex token\n\
                      20: (0,0,0) #000000 srgb(0,0,0)\n";
        let out = parse_histogram(sample);
        assert_eq!(out.len(), 1);
        assert_eq!(out[0].1, 20);
        assert_eq!(out[0].0.to_hex_lower(), "000000");
    }

    #[test]
    fn filters_grey_colors() {
        // 3 greys (saturation 0) + 2 saturated primaries
        let entries = vec![
            (Color::from_hex("808080").unwrap(), 100),
            (Color::from_hex("404040").unwrap(), 50),
            (Color::from_hex("c0c0c0").unwrap(), 25),
            (Color::from_hex("ff0000").unwrap(), 30),
            (Color::from_hex("0000ff").unwrap(), 20),
        ];
        let dominants = select_dominants(&entries);
        assert_eq!(dominants.len(), 2);
        assert_eq!(dominants[0].color.to_hex_lower(), "ff0000");
        assert_eq!(dominants[1].color.to_hex_lower(), "0000ff");
    }

    #[test]
    fn weight_sums_to_one_after_filter() {
        let entries = vec![
            (Color::from_hex("ff0000").unwrap(), 30),
            (Color::from_hex("00ff00").unwrap(), 20),
            (Color::from_hex("808080").unwrap(), 999), // dropped
        ];
        let dominants = select_dominants(&entries);
        let sum: f32 = dominants.iter().map(|d| d.weight).sum();
        assert!((sum - 1.0).abs() < 1e-4, "sum = {}", sum);
    }

    #[test]
    fn all_grey_returns_empty() {
        let entries = vec![
            (Color::from_hex("808080").unwrap(), 100),
            (Color::from_hex("404040").unwrap(), 50),
        ];
        assert!(select_dominants(&entries).is_empty());
    }

    #[test]
    fn rgb_saturation_pure_grey_is_zero() {
        assert_eq!(rgb_saturation(128, 128, 128), 0.0);
        assert_eq!(rgb_saturation(0, 0, 0), 0.0);
        assert_eq!(rgb_saturation(255, 255, 255), 0.0);
    }

    #[test]
    fn rgb_saturation_pure_red_is_one() {
        assert!((rgb_saturation(255, 0, 0) - 1.0).abs() < 1e-5);
        assert!((rgb_saturation(0, 255, 0) - 1.0).abs() < 1e-5);
        assert!((rgb_saturation(0, 0, 255) - 1.0).abs() < 1e-5);
    }

    #[test]
    fn rgb_saturation_midtone_is_between() {
        let s = rgb_saturation(200, 100, 50);
        assert!(s > 0.0 && s < 1.0, "s = {}", s);
    }

    #[test]
    fn dominants_sorted_descending_by_weight() {
        let entries = vec![
            (Color::from_hex("ff0000").unwrap(), 10),
            (Color::from_hex("00ff00").unwrap(), 50),
            (Color::from_hex("0000ff").unwrap(), 30),
        ];
        let dominants = select_dominants(&entries);
        assert_eq!(dominants.len(), 3);
        assert!(dominants[0].weight >= dominants[1].weight);
        assert!(dominants[1].weight >= dominants[2].weight);
        assert_eq!(dominants[0].color.to_hex_lower(), "00ff00");
    }

    #[test]
    fn top_n_truncates_to_five() {
        // 10 strongly-saturated entries — all r=255, g varies, b=0 → saturation 1
        let hexes = [
            "ff0000", "ff1000", "ff2000", "ff3000", "ff4000", "ff5000", "ff6000", "ff7000",
            "ff8000", "ff9000",
        ];
        let entries: Vec<(Color, u32)> = hexes
            .iter()
            .enumerate()
            .map(|(i, h)| (Color::from_hex(h).unwrap(), 100 - i as u32 * 5))
            .collect();
        let dominants = select_dominants(&entries);
        assert_eq!(dominants.len(), TOP_N);
    }

    /// Integration check against a real wallpaper. `#[ignore]` keeps the
    /// default test run hermetic; run explicitly via
    /// `cargo test -- --ignored analyze_real_wallpaper`.
    #[test]
    #[ignore]
    fn analyze_real_wallpaper() {
        let home = match std::env::var("HOME") {
            Ok(h) => h,
            Err(_) => {
                eprintln!("skipping: HOME unset");
                return;
            }
        };
        let path = format!("{}/Pictures/Wallpapers/catppuccin-mocha/orange.jpg", home);
        if std::fs::metadata(&path).is_err() {
            eprintln!("skipping: fixture not present at {}", path);
            return;
        }
        let dominants = analyze(&path).expect("analyze succeeds");
        assert!(!dominants.is_empty());
        assert!(dominants.len() <= TOP_N);
        let sum: f32 = dominants.iter().map(|d| d.weight).sum();
        assert!((sum - 1.0).abs() < 1e-4);
    }
}
