use assert_cmd::Command;
use predicates::prelude::*;

#[allow(deprecated)]
fn cfg() -> Command {
    Command::cargo_bin("cfg").unwrap()
}

// =============================================================================
// UPDATE command - invalid flag combinations
// =============================================================================
//
// These combinations should be rejected by clap:
// - `--list` conflicts with positional names
// - `--list` conflicts with `--dry-run`

#[test]
fn update_list_with_names_rejected() {
    cfg()
        .args(["update", "--list", "mako"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn update_list_with_dry_run_rejected() {
    cfg()
        .args(["update", "--list", "--dry-run"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn update_list_with_dry_run_and_names_rejected() {
    cfg()
        .args(["update", "--list", "--dry-run", "mako"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

// =============================================================================
// UPDATE command - valid flag combinations
// =============================================================================

#[test]
fn update_list_alone_accepted() {
    // May fail at runtime if config not found, but clap accepts the flags
    let result = cfg().args(["update", "--list"]).assert();
    let output = result.get_output();
    let stderr = String::from_utf8_lossy(&output.stderr);

    // Should NOT contain clap conflict errors
    assert!(
        !stderr.contains("cannot be used with"),
        "unexpected clap conflict error"
    );
}

#[test]
fn update_dry_run_alone_accepted() {
    // May fail at runtime if config not found, but clap accepts the flags
    let result = cfg().args(["update", "--dry-run"]).assert();
    let output = result.get_output();
    let stderr = String::from_utf8_lossy(&output.stderr);

    // Should NOT contain clap conflict errors
    assert!(
        !stderr.contains("cannot be used with"),
        "unexpected clap conflict error"
    );
}

// =============================================================================
// FONT command tests
// =============================================================================

#[test]
fn font_get_rejects_set() {
    cfg()
        .args(["font", "--get", "mono", "--set", "mono=JetBrainsMono Nerd Font"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn font_get_rejects_list() {
    cfg()
        .args(["font", "--get", "mono", "--list"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn font_set_rejects_list() {
    cfg()
        .args(["font", "--set", "mono=JetBrainsMono Nerd Font", "--list"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn font_preview_rejects_get() {
    cfg()
        .args(["font", "--preview", "--get", "mono"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn font_preview_rejects_set() {
    cfg()
        .args(["font", "--preview", "--set", "mono=JetBrainsMono Nerd Font"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn font_preview_rejects_list() {
    cfg()
        .args(["font", "--preview", "--list"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn font_scratchpad_rejects_get() {
    cfg()
        .args(["font", "--scratchpad", "--get", "mono"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn font_scratchpad_rejects_set() {
    cfg()
        .args(["font", "--scratchpad", "--set", "mono=JetBrainsMono Nerd Font"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn font_scratchpad_rejects_list() {
    cfg()
        .args(["font", "--scratchpad", "--list"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn font_scratchpad_rejects_preview() {
    cfg()
        .args(["font", "--scratchpad", "--preview"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn font_interactive_rejects_get() {
    cfg()
        .args(["font", "--interactive", "--get", "mono"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn font_interactive_rejects_set() {
    cfg()
        .args(["font", "--interactive", "--set", "mono=JetBrainsMono Nerd Font"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn font_interactive_rejects_list() {
    cfg()
        .args(["font", "--interactive", "--list"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn font_interactive_rejects_preview() {
    cfg()
        .args(["font", "--interactive", "--preview"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn font_interactive_rejects_scratchpad() {
    cfg()
        .args(["font", "--interactive", "--scratchpad"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn font_list_json_outputs_valid_structure() {
    cfg()
        .args(["font", "--list", "--json"])
        .assert()
        .success()
        .stdout(predicate::str::contains("\"mono\""))
        .stdout(predicate::str::contains("\"sans\""))
        .stdout(predicate::str::contains("\"name\""))
        .stdout(predicate::str::contains("\"description\""))
        .stdout(predicate::str::contains("\"installed\""))
        .stdout(predicate::str::contains("\"ligatures\""))
        .stdout(predicate::str::contains("\"nerd_font\""));
}

// =============================================================================
// THEME command tests
// =============================================================================

#[test]
fn theme_shows_current() {
    cfg()
        .arg("theme")
        .assert()
        .success();
}

#[test]
fn theme_get_accent() {
    cfg()
        .args(["theme", "--get", "primary"])
        .assert()
        .success();
}

#[test]
fn theme_list() {
    cfg()
        .args(["theme", "--list"])
        .assert()
        .success();
}

#[test]
fn theme_list_json() {
    cfg()
        .args(["theme", "--list", "--json"])
        .assert()
        .success();
}

#[test]
fn theme_get_rejects_set() {
    cfg()
        .args(["theme", "--get", "primary", "--set", "accent=blue"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn theme_get_rejects_list() {
    cfg()
        .args(["theme", "--get", "primary", "--list"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn theme_set_rejects_list() {
    cfg()
        .args(["theme", "--set", "accent=blue", "--list"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn theme_get_set_list_all_conflict() {
    cfg()
        .args(["theme", "--get", "primary", "--set", "accent=blue", "--list"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn theme_interactive_rejects_get() {
    cfg()
        .args(["theme", "--interactive", "--get", "primary"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn theme_interactive_rejects_set() {
    cfg()
        .args(["theme", "--interactive", "--set", "accent=blue"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn theme_interactive_rejects_list() {
    cfg()
        .args(["theme", "--interactive", "--list"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

// =============================================================================
// WALLPAPER command tests
// =============================================================================

// Invalid combinations
#[test]
fn wallpaper_get_rejects_set() {
    cfg()
        .args(["wallpaper", "--get", "path", "--set", "path=/tmp/wall.png"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

// Valid combinations
#[test]
fn wallpaper_shows_current() {
    cfg().arg("wallpaper").assert().success();
}

#[test]
fn wallpaper_get_path() {
    cfg()
        .args(["wallpaper", "--get", "path"])
        .assert()
        .success();
}

/// Create a throwaway CFG_DIR so --apply tests don't mutate the user's real
/// `cfg/config.toml`. Each caller passes a unique name so parallel tests don't
/// stomp on each other.
fn isolated_cfg_dir(name: &str) -> String {
    let dir = std::env::temp_dir().join(format!("cfg-cli-test-{}", name));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    dir.to_string_lossy().into_owned()
}

#[test]
fn wallpaper_apply_standalone_accepted() {
    // Clap-level sanity: --apply alone must not produce a "cannot be used with" error.
    let dir = isolated_cfg_dir("apply-standalone-accepted");
    let output = cfg()
        .env("CFG_DIR", &dir)
        .args(["wallpaper", "--apply"])
        .output()
        .unwrap();
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(!stderr.contains("cannot be used with"));
}

#[test]
fn wallpaper_set_with_apply_accepted() {
    // Clap-level sanity: --set + --apply must not produce a "cannot be used with" error.
    let dir = isolated_cfg_dir("set-with-apply-accepted");
    let output = cfg()
        .env("CFG_DIR", &dir)
        .args(["wallpaper", "--set", "gravity=North", "--apply"])
        .output()
        .unwrap();
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(!stderr.contains("cannot be used with"));
}

#[test]
fn wallpaper_apply_empty_path_errors() {
    // Fresh config has wallpaper.path = "" → --apply must fail with a clear message.
    let dir = isolated_cfg_dir("apply-empty-path");
    let output = cfg()
        .env("CFG_DIR", &dir)
        .args(["wallpaper", "--apply"])
        .output()
        .unwrap();
    assert!(!output.status.success(), "expected non-zero exit");
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        stderr.contains("wallpaper path not set"),
        "stderr was: {}",
        stderr
    );
}

#[test]
fn wallpaper_apply_missing_file_errors() {
    // Set path to a file that doesn't exist, then --apply must fail with "does not exist".
    let dir = isolated_cfg_dir("apply-missing-file");
    cfg()
        .env("CFG_DIR", &dir)
        .args(["wallpaper", "--set", "path=/nonexistent/definitely/nope.png"])
        .assert()
        .success();
    let output = cfg()
        .env("CFG_DIR", &dir)
        .args(["wallpaper", "--apply"])
        .output()
        .unwrap();
    assert!(!output.status.success(), "expected non-zero exit");
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        stderr.contains("does not exist or is not a file"),
        "stderr was: {}",
        stderr
    );
}

#[test]
fn wallpaper_set_source_dir_persists() {
    let dir = isolated_cfg_dir("set-source-dir");
    cfg()
        .env("CFG_DIR", &dir)
        .args(["wallpaper", "--set", "source_dir=/tmp/wallpapers"])
        .assert()
        .success();

    cfg()
        .env("CFG_DIR", &dir)
        .args(["wallpaper", "--get", "source_dir"])
        .assert()
        .success()
        .stdout(predicate::str::contains("/tmp/wallpapers"));
}

#[test]
fn wallpaper_unknown_set_key_mentions_source_dir() {
    let dir = isolated_cfg_dir("unknown-key-source-dir");
    let output = cfg()
        .env("CFG_DIR", &dir)
        .args(["wallpaper", "--set", "bogus=x"])
        .output()
        .unwrap();
    assert!(!output.status.success());
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        stderr.contains("source_dir"),
        "error message should advertise source_dir; got: {}",
        stderr
    );
}

#[test]
fn wallpaper_default_listing_shows_source_dir() {
    let dir = isolated_cfg_dir("default-list-source-dir");
    let output = cfg()
        .env("CFG_DIR", &dir)
        .arg("wallpaper")
        .output()
        .unwrap();
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(
        stdout.contains("source_dir="),
        "default listing should include source_dir=; got: {}",
        stdout
    );
}

#[test]
fn wallpaper_apply_errors_when_both_path_and_source_dir_empty() {
    let dir = isolated_cfg_dir("apply-both-empty");
    // Fresh config — both path and source_dir empty by default.
    let output = cfg()
        .env("CFG_DIR", &dir)
        .args(["wallpaper", "--apply"])
        .output()
        .unwrap();
    assert!(!output.status.success());
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        stderr.contains("wallpaper path not set"),
        "stderr was: {}",
        stderr
    );
}

// --- interactive + scratchpad flag tests (bd_.dotfiles-a2h) ---

#[test]
fn wallpaper_scratchpad_rejects_get() {
    cfg()
        .args(["wallpaper", "--scratchpad", "/tmp/x.jpg", "--get", "path"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn wallpaper_scratchpad_rejects_set() {
    cfg()
        .args(["wallpaper", "--scratchpad", "/tmp/x.jpg", "--set", "path=/tmp/y.jpg"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn wallpaper_scratchpad_rejects_interactive() {
    cfg()
        .args(["wallpaper", "--scratchpad", "/tmp/x.jpg", "-i"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn wallpaper_scratchpad_rejects_apply() {
    cfg()
        .args(["wallpaper", "--scratchpad", "/tmp/x.jpg", "--apply"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn wallpaper_scratchpad_missing_file_errors() {
    let output = cfg()
        .args(["wallpaper", "--scratchpad", "/nonexistent/definitely/nope.png"])
        .output()
        .unwrap();
    assert!(!output.status.success(), "expected non-zero exit");
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        stderr.contains("does not exist"),
        "stderr was: {}",
        stderr
    );
}

#[test]
fn wallpaper_interactive_rejects_get() {
    cfg()
        .args(["wallpaper", "-i", "--get", "path"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn wallpaper_interactive_rejects_set() {
    cfg()
        .args(["wallpaper", "-i", "--set", "path=/tmp/x.jpg"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}
