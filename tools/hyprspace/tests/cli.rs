use assert_cmd::Command;
use predicates::prelude::*;

fn hyprspace() -> Command {
    Command::cargo_bin("hyprspace").unwrap()
}

#[test]
fn bare_hyprspace_fails() {
    hyprspace().assert().failure();
}

#[test]
fn toggle_requires_workspace() {
    hyprspace().arg("toggle").assert().failure();
}

#[test]
fn spawn_requires_workspace() {
    hyprspace().arg("spawn").assert().failure();
}

#[test]
fn raw_requires_workspace() {
    hyprspace().arg("raw").assert().failure();
}

#[test]
fn dismiss_scratchpads_takes_no_args() {
    // clap parsing succeeds; the handler will panic with unimplemented
    hyprspace()
        .arg("dismiss-scratchpads")
        .assert()
        .failure()
        .stderr(predicate::str::contains("not implemented"));
}

#[test]
fn help_shows_all_subcommands() {
    hyprspace()
        .arg("--help")
        .assert()
        .success()
        .stdout(predicate::str::contains("toggle"))
        .stdout(predicate::str::contains("spawn"))
        .stdout(predicate::str::contains("raw"))
        .stdout(predicate::str::contains("dismiss-scratchpads"));
}
