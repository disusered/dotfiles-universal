use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::Path;
use std::time::UNIX_EPOCH;

use crate::wallpaper::analysis::DominantColor;

/// A cached analysis for a single wallpaper file.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TagEntry {
    /// Source file mtime at the time of analysis, seconds since UNIX epoch.
    /// Used by [`TagCache::get_fresh`] to detect staleness.
    pub mtime: u64,
    pub dominants: Vec<DominantColor>,
}

/// On-disk cache of wallpaper color analyses, keyed by absolute path.
///
/// Serializes as `{ "entries": { "<path>": TagEntry, ... } }`.
#[derive(Debug, Default, Serialize, Deserialize)]
pub struct TagCache {
    entries: HashMap<String, TagEntry>,
}

impl TagCache {
    /// Load the cache from `path`. A missing file is not an error — returns
    /// an empty cache. Parse errors on existing files *are* errors.
    pub fn load(path: &str) -> Result<Self, String> {
        let content = match fs::read_to_string(path) {
            Ok(s) => s,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
                return Ok(Self::default());
            }
            Err(e) => return Err(format!("failed to read tag cache '{}': {}", path, e)),
        };
        serde_json::from_str(&content)
            .map_err(|e| format!("failed to parse tag cache '{}': {}", path, e))
    }

    /// Save the cache to `path`, creating parent dirs if needed. Writes are
    /// atomic: serialize to `<path>.tmp`, then rename over `path`, so a crash
    /// mid-write can't leave a half-written JSON file.
    pub fn save(&self, path: &str) -> Result<(), String> {
        let p = Path::new(path);
        if let Some(parent) = p.parent() {
            if !parent.as_os_str().is_empty() {
                fs::create_dir_all(parent).map_err(|e| {
                    format!("failed to create cache dir '{}': {}", parent.display(), e)
                })?;
            }
        }
        let tmp = format!("{}.tmp", path);
        let json = serde_json::to_string_pretty(self)
            .map_err(|e| format!("failed to serialize tag cache: {}", e))?;
        fs::write(&tmp, json)
            .map_err(|e| format!("failed to write tag cache '{}': {}", tmp, e))?;
        fs::rename(&tmp, path)
            .map_err(|e| format!("failed to rename tag cache to '{}': {}", path, e))?;
        Ok(())
    }

    /// Return the cached entry for `wallpaper_path` if-and-only-if the file's
    /// current mtime matches the cached mtime. Any error reading the file
    /// (missing, permission denied, etc.) returns `None`, forcing the caller
    /// to re-analyze.
    pub fn get_fresh(&self, wallpaper_path: &str) -> Option<&TagEntry> {
        let entry = self.entries.get(wallpaper_path)?;
        let current = fs::metadata(wallpaper_path)
            .ok()?
            .modified()
            .ok()?
            .duration_since(UNIX_EPOCH)
            .ok()?
            .as_secs();
        if current == entry.mtime {
            Some(entry)
        } else {
            None
        }
    }

    /// Insert or replace an entry for `wallpaper_path`.
    pub fn insert(&mut self, wallpaper_path: &str, entry: TagEntry) {
        self.entries.insert(wallpaper_path.to_string(), entry);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::color::Color;
    use std::time::SystemTime;

    fn temp_path(name: &str) -> String {
        let pid = std::process::id();
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let dir = std::env::temp_dir();
        format!("{}/cfg-tag-test-{}-{}-{}", dir.display(), pid, nanos, name)
    }

    fn sample_entry(mtime: u64) -> TagEntry {
        TagEntry {
            mtime,
            dominants: vec![
                DominantColor {
                    color: Color::from_hex("ff0000").unwrap(),
                    weight: 0.6,
                },
                DominantColor {
                    color: Color::from_hex("00ff00").unwrap(),
                    weight: 0.4,
                },
            ],
        }
    }

    #[test]
    fn load_missing_returns_empty() {
        let path = temp_path("missing.json");
        let cache = TagCache::load(&path).unwrap();
        assert!(cache.entries.is_empty());
    }

    #[test]
    fn roundtrip_json_preserves_entries() {
        let path = temp_path("roundtrip.json");
        let mut cache = TagCache::default();
        cache.insert("/tmp/fake-wallpaper.jpg", sample_entry(12345));
        cache.save(&path).unwrap();

        let loaded = TagCache::load(&path).unwrap();
        assert_eq!(loaded.entries.len(), 1);
        let entry = loaded.entries.get("/tmp/fake-wallpaper.jpg").unwrap();
        assert_eq!(entry.mtime, 12345);
        assert_eq!(entry.dominants.len(), 2);
        assert_eq!(entry.dominants[0].color.to_hex_lower(), "ff0000");
        assert!((entry.dominants[0].weight - 0.6).abs() < 1e-5);

        fs::remove_file(&path).ok();
    }

    #[test]
    fn save_creates_parent_dirs() {
        let dir = temp_path("nested-dir");
        let path = format!("{}/deeper/tags.json", dir);
        let cache = TagCache::default();
        cache.save(&path).unwrap();
        assert!(fs::metadata(&path).is_ok());
        fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn get_fresh_matching_mtime_returns_entry() {
        let wp_path = temp_path("wallpaper.jpg");
        fs::write(&wp_path, b"fake").unwrap();
        let mtime = fs::metadata(&wp_path)
            .unwrap()
            .modified()
            .unwrap()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let mut cache = TagCache::default();
        cache.insert(&wp_path, sample_entry(mtime));
        assert!(cache.get_fresh(&wp_path).is_some());

        fs::remove_file(&wp_path).ok();
    }

    #[test]
    fn get_fresh_stale_mtime_returns_none() {
        let wp_path = temp_path("stale.jpg");
        fs::write(&wp_path, b"fake").unwrap();

        let mut cache = TagCache::default();
        cache.insert(&wp_path, sample_entry(1));
        assert!(cache.get_fresh(&wp_path).is_none());

        fs::remove_file(&wp_path).ok();
    }

    #[test]
    fn get_fresh_missing_file_returns_none() {
        let mut cache = TagCache::default();
        cache.insert("/nonexistent/fake.jpg", sample_entry(1));
        assert!(cache.get_fresh("/nonexistent/fake.jpg").is_none());
    }

    #[test]
    fn get_fresh_unknown_path_returns_none() {
        let cache = TagCache::default();
        assert!(cache.get_fresh("/anything").is_none());
    }
}
