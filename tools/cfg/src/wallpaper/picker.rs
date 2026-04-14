use std::collections::HashMap;
use std::fs;
use std::io::IsTerminal;
use std::path::Path;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::mpsc;
use std::thread;
use std::time::UNIX_EPOCH;

use rand::seq::SliceRandom;
use rayon::prelude::*;

use crate::color::Color;
use crate::config::Config;
use crate::palette::Palette;
use crate::wallpaper::analysis::{self, DominantColor};
use crate::wallpaper::tags::{TagCache, TagEntry};

/// RGB Euclidean distance cutoff for a wallpaper to be considered a match for
/// a target color. Max possible distance is ~441.67 (sqrt(3 * 255^2)); 60 is
/// roughly 14% of that range.
pub const MATCH_THRESHOLD: f32 = 60.0;

/// Persist the cache after every N new analyses so a Ctrl-C mid-run keeps
/// most of the work.
const SAVE_EVERY: usize = 50;

/// Minimum Euclidean RGB distance from any of `dominants` to `target`.
///
/// Lower is a better match. Weight is intentionally ignored: we only care
/// whether *any* dominant color in the image is close to the target.
pub fn score_wallpaper(dominants: &[DominantColor], target: &Color) -> f32 {
    dominants
        .iter()
        .map(|d| color_distance(&d.color, target))
        .fold(f32::INFINITY, f32::min)
}

fn color_distance(a: &Color, b: &Color) -> f32 {
    let dr = a.r as f32 - b.r as f32;
    let dg = a.g as f32 - b.g as f32;
    let db = a.b as f32 - b.b as f32;
    (dr * dr + dg * dg + db * db).sqrt()
}

/// Keep the paths whose score is strictly below `threshold`.
pub fn filter_pool(scored: &[(String, f32)], threshold: f32) -> Vec<String> {
    scored
        .iter()
        .filter(|(_, score)| *score < threshold)
        .map(|(path, _)| path.clone())
        .collect()
}

/// Rank `pool` by their secondary-color scores ascending and keep the top half
/// (minimum one). Paths missing from `scores_by_secondary` sort last.
pub fn tiebreak(pool: &[String], scores_by_secondary: &HashMap<String, f32>) -> Vec<String> {
    let mut ranked: Vec<(String, f32)> = pool
        .iter()
        .map(|p| {
            let s = scores_by_secondary
                .get(p)
                .copied()
                .unwrap_or(f32::INFINITY);
            (p.clone(), s)
        })
        .collect();
    ranked.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap_or(std::cmp::Ordering::Equal));
    let keep = (ranked.len() / 2).max(1);
    ranked.truncate(keep);
    ranked.into_iter().map(|(p, _)| p).collect()
}

/// Pick a wallpaper from `config.wallpaper.source_dir` whose dominant colors
/// best match the current `config.primary`, with `config.secondary` as
/// tiebreaker and random choice within the matching pool.
///
/// Returns the absolute path of the chosen wallpaper.
pub fn pick(config: &Config, cfg_dir: &str) -> Result<String, String> {
    let palette_path = format!("{}/palettes/{}.toml", cfg_dir, config.flavor);
    let palette = Palette::load(&palette_path)?;

    let primary_color = *palette
        .get(&config.primary)
        .ok_or_else(|| format!("primary color '{}' not found in palette", config.primary))?;
    let secondary_color = palette.get(&config.secondary).copied();

    let source_dir = super::expand_tilde(&config.wallpaper.source_dir);
    let files = enumerate_wallpapers(&source_dir)?;
    if files.is_empty() {
        return Err(format!("no wallpapers found in '{}'", source_dir));
    }

    let cache_dir = super::resolve_cache_dir(&config.wallpaper);
    let tags_path = format!("{}/tags.json", cache_dir);
    let cache = TagCache::load(&tags_path)?;

    // Partition into cache hits (fill dominants_by_path directly) and misses
    // (analyze in parallel below).
    let mut dominants_by_path: HashMap<String, Vec<DominantColor>> = HashMap::new();
    let mut to_analyze: Vec<String> = Vec::new();
    for path in &files {
        if let Some(entry) = cache.get_fresh(path) {
            dominants_by_path.insert(path.clone(), entry.dominants.clone());
        } else {
            to_analyze.push(path.clone());
        }
    }

    if !to_analyze.is_empty() {
        let analyzed = analyze_and_cache(to_analyze, cache, &tags_path)?;
        dominants_by_path.extend(analyzed);
    }

    // Score against primary.
    let scored_primary: Vec<(String, f32)> = files
        .iter()
        .map(|p| {
            let d = dominants_by_path.get(p).map(|v| v.as_slice()).unwrap_or(&[]);
            (p.clone(), score_wallpaper(d, &primary_color))
        })
        .collect();

    let mut pool = filter_pool(&scored_primary, MATCH_THRESHOLD);

    // Fallback: retry against secondary.
    if pool.is_empty() {
        if let Some(sec) = secondary_color {
            let scored_secondary: Vec<(String, f32)> = files
                .iter()
                .map(|p| {
                    let d = dominants_by_path.get(p).map(|v| v.as_slice()).unwrap_or(&[]);
                    (p.clone(), score_wallpaper(d, &sec))
                })
                .collect();
            pool = filter_pool(&scored_secondary, MATCH_THRESHOLD);
        }
    }

    // Last resort: random from all files.
    if pool.is_empty() {
        eprintln!(
            "no wallpapers matched primary='{}' or secondary='{}', picking at random",
            config.primary, config.secondary
        );
        pool = files.clone();
    } else if pool.len() > 1 {
        // Tiebreak by secondary when we have a multi-way match.
        if let Some(sec) = secondary_color {
            let secondary_scores: HashMap<String, f32> = pool
                .iter()
                .map(|p| {
                    let d = dominants_by_path.get(p).map(|v| v.as_slice()).unwrap_or(&[]);
                    (p.clone(), score_wallpaper(d, &sec))
                })
                .collect();
            pool = tiebreak(&pool, &secondary_scores);
        }
    }

    let mut rng = rand::thread_rng();
    pool.choose(&mut rng)
        .cloned()
        .ok_or_else(|| "internal error: empty pool after selection".to_string())
}

/// Analyze `to_analyze` in parallel via rayon while a merger thread owns the
/// `TagCache`, inserts each completed entry, and saves to `tags_path` every
/// [`SAVE_EVERY`] analyses (plus once at the end). Progress lines are printed
/// to stderr only when stderr is a TTY so silent callers like the theme
/// re-pick path don't spam unrelated invocations.
///
/// Returns the newly-analyzed dominants keyed by path. On analysis error,
/// whatever has already been sent to the merger still gets persisted before
/// this function returns with the error.
fn analyze_and_cache(
    to_analyze: Vec<String>,
    mut cache: TagCache,
    tags_path: &str,
) -> Result<HashMap<String, Vec<DominantColor>>, String> {
    let total = to_analyze.len();
    let show_progress = std::io::stderr().is_terminal();
    let counter = AtomicUsize::new(0);

    let (tx, rx) = mpsc::channel::<(String, Vec<DominantColor>, u64)>();
    let tags_path_owned = tags_path.to_string();
    let merger: thread::JoinHandle<HashMap<String, Vec<DominantColor>>> =
        thread::spawn(move || {
            let mut analyzed: HashMap<String, Vec<DominantColor>> = HashMap::new();
            let mut since_save = 0usize;
            while let Ok((path, dominants, mtime)) = rx.recv() {
                cache.insert(
                    &path,
                    TagEntry {
                        mtime,
                        dominants: dominants.clone(),
                    },
                );
                analyzed.insert(path, dominants);
                since_save += 1;
                if since_save >= SAVE_EVERY {
                    if let Err(e) = cache.save(&tags_path_owned) {
                        eprintln!("warning: failed to save tag cache: {}", e);
                    }
                    since_save = 0;
                }
            }
            if let Err(e) = cache.save(&tags_path_owned) {
                eprintln!("warning: failed to save tag cache: {}", e);
            }
            analyzed
        });

    let analyze_result: Result<(), String> = to_analyze
        .par_iter()
        .try_for_each_with(tx.clone(), |tx, path| {
            let n = counter.fetch_add(1, Ordering::Relaxed) + 1;
            if show_progress {
                eprintln!("{}", format_progress_line(n, total, path));
            }
            let dominants = analysis::analyze(path)?;
            let mtime = file_mtime_secs(path).unwrap_or(0);
            tx.send((path.clone(), dominants, mtime))
                .map_err(|e| format!("tag cache merger channel closed: {}", e))?;
            Ok(())
        });

    // Close the outer sender so the merger can finish draining; wait for it.
    drop(tx);
    let analyzed = merger
        .join()
        .map_err(|_| "tag cache merger thread panicked".to_string())?;
    analyze_result?;
    Ok(analyzed)
}

fn format_progress_line(n: usize, total: usize, path: &str) -> String {
    let basename = Path::new(path)
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or(path);
    format!("[{}/{}] analyzing {}", n, total, basename)
}

fn enumerate_wallpapers(dir: &str) -> Result<Vec<String>, String> {
    let entries = fs::read_dir(dir)
        .map_err(|e| format!("failed to read source_dir '{}': {}", dir, e))?;
    let mut out = Vec::new();
    for entry in entries {
        let entry = entry.map_err(|e| format!("failed to read entry in '{}': {}", dir, e))?;
        let path = entry.path();
        if !path.is_file() {
            continue;
        }
        if let Some(ext) = path.extension().and_then(|s| s.to_str()) {
            let lower = ext.to_ascii_lowercase();
            if matches!(lower.as_str(), "jpg" | "jpeg" | "png") {
                out.push(path.to_string_lossy().into_owned());
            }
        }
    }
    out.sort();
    Ok(out)
}

fn file_mtime_secs(path: &str) -> Option<u64> {
    fs::metadata(Path::new(path))
        .ok()?
        .modified()
        .ok()?
        .duration_since(UNIX_EPOCH)
        .ok()?
        .as_secs()
        .into()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn c(r: u8, g: u8, b: u8) -> Color {
        Color { r, g, b }
    }

    fn dom(r: u8, g: u8, b: u8, weight: f32) -> DominantColor {
        DominantColor {
            color: c(r, g, b),
            weight,
        }
    }

    #[test]
    fn score_wallpaper_returns_min_distance_across_dominants() {
        let dominants = vec![
            dom(255, 0, 0, 0.5),   // red — far from peach
            dom(250, 179, 135, 0.3), // peach — close to peach
            dom(0, 255, 0, 0.2),   // green — far
        ];
        let peach = c(250, 179, 135);
        let score = score_wallpaper(&dominants, &peach);
        assert!(score < 1.0, "expected near-zero min distance, got {}", score);
    }

    #[test]
    fn score_wallpaper_ignores_weight_uses_distance_only() {
        // A tiny-weight exact match still wins over a heavy-weight distant match.
        let dominants = vec![
            dom(0, 0, 0, 0.99),      // almost all pixels — black
            dom(250, 179, 135, 0.01), // tiny sliver — peach
        ];
        let peach = c(250, 179, 135);
        let score = score_wallpaper(&dominants, &peach);
        assert!(score < 1.0, "weight should not mask the close match; got {}", score);
    }

    #[test]
    fn score_wallpaper_empty_dominants_returns_infinity() {
        let score = score_wallpaper(&[], &c(0, 0, 0));
        assert!(score.is_infinite());
    }

    #[test]
    fn filter_pool_includes_under_threshold() {
        let scored = vec![
            ("a.jpg".to_string(), 10.0),
            ("b.jpg".to_string(), 59.9),
            ("c.jpg".to_string(), 60.0), // exactly threshold — excluded
            ("d.jpg".to_string(), 120.0),
        ];
        let pool = filter_pool(&scored, 60.0);
        assert_eq!(pool, vec!["a.jpg".to_string(), "b.jpg".to_string()]);
    }

    #[test]
    fn filter_pool_empty_when_all_over_threshold() {
        let scored = vec![
            ("a.jpg".to_string(), 100.0),
            ("b.jpg".to_string(), 200.0),
        ];
        assert!(filter_pool(&scored, 60.0).is_empty());
    }

    #[test]
    fn tiebreak_ranks_by_secondary_score_ascending() {
        let pool = vec![
            "a.jpg".to_string(),
            "b.jpg".to_string(),
            "c.jpg".to_string(),
            "d.jpg".to_string(),
        ];
        let mut scores = HashMap::new();
        scores.insert("a.jpg".to_string(), 100.0);
        scores.insert("b.jpg".to_string(), 10.0);
        scores.insert("c.jpg".to_string(), 50.0);
        scores.insert("d.jpg".to_string(), 200.0);
        let top = tiebreak(&pool, &scores);
        // Top half of 4 = 2. Ascending by score: b (10), c (50).
        assert_eq!(top, vec!["b.jpg".to_string(), "c.jpg".to_string()]);
    }

    #[test]
    fn tiebreak_keeps_at_least_one_for_small_pool() {
        let pool = vec!["only.jpg".to_string()];
        let mut scores = HashMap::new();
        scores.insert("only.jpg".to_string(), 5.0);
        let top = tiebreak(&pool, &scores);
        assert_eq!(top, vec!["only.jpg".to_string()]);
    }

    #[test]
    fn format_progress_line_uses_basename() {
        let line = format_progress_line(42, 335, "/home/user/pics/catppuccin/foo.jpg");
        assert_eq!(line, "[42/335] analyzing foo.jpg");
    }

    #[test]
    fn format_progress_line_falls_back_when_no_basename() {
        // Root "/" has no file_name() — fall back to the full input.
        let line = format_progress_line(1, 1, "/");
        assert_eq!(line, "[1/1] analyzing /");
    }

    #[test]
    fn tiebreak_missing_secondary_score_sorts_last() {
        let pool = vec!["a.jpg".to_string(), "b.jpg".to_string()];
        let mut scores = HashMap::new();
        scores.insert("b.jpg".to_string(), 99.0);
        // 'a.jpg' missing → treated as infinity → sorts after b.
        let top = tiebreak(&pool, &scores);
        assert_eq!(top, vec!["b.jpg".to_string()]);
    }
}
