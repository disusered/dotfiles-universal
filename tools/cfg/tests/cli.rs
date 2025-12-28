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
        .args(["theme", "--get", "accent"])
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
        .args(["theme", "--get", "accent", "--set", "accent=blue"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}

#[test]
fn theme_get_rejects_list() {
    cfg()
        .args(["theme", "--get", "accent", "--list"])
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
        .args(["theme", "--get", "accent", "--set", "accent=blue", "--list"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("cannot be used with"));
}
