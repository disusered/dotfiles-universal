use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::path::Path;
use std::process::Command;
use std::time::UNIX_EPOCH;

/// Compute a cache key for a processed wallpaper.
/// Includes source path, gravity, layout dimensions, and source file mtime.
pub fn cache_key(source: &str, gravity: &str, width: u32, height: u32) -> u64 {
    let mut hasher = DefaultHasher::new();
    source.hash(&mut hasher);
    gravity.hash(&mut hasher);
    width.hash(&mut hasher);
    height.hash(&mut hasher);

    // Include mtime so that changing the source file invalidates the cache
    if let Ok(meta) = std::fs::metadata(source) {
        if let Ok(mtime) = meta.modified() {
            if let Ok(dur) = mtime.duration_since(UNIX_EPOCH) {
                dur.as_secs().hash(&mut hasher);
            }
        }
    }

    hasher.finish()
}

/// Resize and crop a single-monitor wallpaper using ImageMagick.
/// Returns the path to the cached output file.
pub fn resize_and_crop(
    source: &str,
    width: u32,
    height: u32,
    gravity: &str,
    cache_dir: &str,
) -> Result<String, String> {
    std::fs::create_dir_all(cache_dir)
        .map_err(|e| format!("Failed to create cache dir: {}", e))?;

    let key = cache_key(source, gravity, width, height);
    let ext = Path::new(source)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("png");
    let output = format!("{}/{:016x}.{}", cache_dir, key, ext);

    if Path::new(&output).exists() {
        return Ok(output);
    }

    let geometry = format!("{}x{}", width, height);
    let status = Command::new("magick")
        .args([
            source,
            "-gravity", gravity,
            "-resize", &format!("{}^", geometry),
            "-extent", &geometry,
            "+repage",
            &output,
        ])
        .status()
        .map_err(|e| format!("Failed to run magick: {}", e))?;

    if status.success() {
        Ok(output)
    } else {
        Err(format!("magick exited with status {}", status))
    }
}

/// Create a spanning image covering the combined canvas of all monitors.
/// Returns the path to the cached output file.
pub fn create_spanning_image(
    source: &str,
    total_width: u32,
    max_height: u32,
    gravity: &str,
    cache_dir: &str,
) -> Result<String, String> {
    resize_and_crop(source, total_width, max_height, gravity, cache_dir)
}

/// Crop a per-monitor slice from a spanning image.
/// Returns the path to the cached slice file.
pub fn extract_slice(
    spanning: &str,
    width: u32,
    height: u32,
    x_offset: i32,
    cache_dir: &str,
) -> Result<String, String> {
    std::fs::create_dir_all(cache_dir)
        .map_err(|e| format!("Failed to create cache dir: {}", e))?;

    let key = cache_key(spanning, "crop", width, height);
    let ext = Path::new(spanning)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("png");
    let output = format!("{}/{:016x}_slice.{}", cache_dir, key, ext);

    if Path::new(&output).exists() {
        return Ok(output);
    }

    let crop_arg = format!("{}x{}+{}+0", width, height, x_offset);
    let status = Command::new("magick")
        .args([
            spanning,
            "-crop", &crop_arg,
            "+repage",
            &output,
        ])
        .status()
        .map_err(|e| format!("Failed to run magick: {}", e))?;

    if status.success() {
        Ok(output)
    } else {
        Err(format!("magick exited with status {}", status))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cache_key_determinism() {
        // Same inputs produce same key
        let k1 = cache_key("/tmp/wall.png", "Center", 1920, 1080);
        let k2 = cache_key("/tmp/wall.png", "Center", 1920, 1080);
        assert_eq!(k1, k2);
    }

    #[test]
    fn test_cache_key_variance() {
        // Different inputs produce different keys
        let k1 = cache_key("/tmp/wall.png", "Center", 1920, 1080);
        let k2 = cache_key("/tmp/wall.png", "NorthWest", 1920, 1080);
        let k3 = cache_key("/tmp/wall.png", "Center", 3840, 1080);
        assert_ne!(k1, k2);
        assert_ne!(k1, k3);
        assert_ne!(k2, k3);
    }

    #[test]
    fn test_cached_path_shortcut() {
        // If the output file already exists, resize_and_crop returns it without calling magick
        let dir = std::env::temp_dir();
        let cache_dir = dir.to_str().unwrap();

        // Compute expected output path
        let key = cache_key("/nonexistent/source.png", "Center", 100, 100);
        let expected = format!("{}/{:016x}.png", cache_dir, key);

        // Create the file so the cache hit path is taken
        std::fs::write(&expected, b"fake").unwrap();

        let result = resize_and_crop("/nonexistent/source.png", 100, 100, "Center", cache_dir);
        assert_eq!(result.unwrap(), expected);

        // Clean up
        let _ = std::fs::remove_file(&expected);
    }
}
